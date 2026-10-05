#requires -Version 5.1
# jjpr 冒烟测试（PowerShell 版，无外部网络依赖）。
# 覆盖：加载守卫、子命令分发、配置读取优先级、远端 URL 归一化、凭据助手协议、
#       令牌缓存过期逻辑、doctor 的 fail-fast 路径、b64url、PEM 解析（PKCS#1/PKCS#8）
#       与 RSA 签名往返、令牌失败传播（回环地址模拟网络失败）、默认动作防呆。
# 网络边界：T18 用 JJPR_API_BASE=http://127.0.0.1:1（回环端口拒绝，瞬时失败，
#           不出本机），替代 bash 版的假 curl 注入。
# 运行：powershell/pwsh -NoProfile -ExecutionPolicy Bypass -File tests/doctor-smoke.test.ps1
#
# Author: 李晶

$ErrorActionPreference = 'Continue'

$TestsDir = Split-Path -Parent $PSCommandPath
$SkillDir = Split-Path -Parent $TestsDir
$ScriptsDir = Join-Path $SkillDir 'scripts'
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("jjpr-test-" + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $Tmp -Force

$Pass = 0
$Fail = 0

# 记录通过用例
function Ok([string]$Name) { $script:Pass = $script:Pass + 1; Write-Output "  [PASS] $Name" }

# 记录失败用例
function Bad([string]$Name) { $script:Fail = $script:Fail + 1; Write-Output "  [FAIL] $Name" }

# ---- T0：加载被测脚本（dot-source 仅暴露函数，不触发主流程）----

. (Join-Path $ScriptsDir 'jjpr.ps1')

# ---- 测试辅助：DER 构造（仅在测试内使用，用于生成一次性 RSA 测试私钥）----

# 把字节内容编码为 DER INTEGER TLV（正数：最高位为 1 时补前导 0x00）
function Test-DerIntBytes([byte[]]$Content) {
  if ($Content.Length -eq 0) { $Content = [byte[]]@(0) }
  $body = New-Object System.Collections.Generic.List[byte]
  if ($Content[0] -band 0x80) { [void]$body.Add(0) }
  foreach ($b in $Content) { [void]$body.Add($b) }
  return (Test-DerTlv 0x02 $body.ToArray())
}

# 把内容编码为指定 tag 的 DER TLV（含短/长形式长度）
function Test-DerTlv([int]$Tag, [byte[]]$Content) {
  $out = New-Object System.Collections.Generic.List[byte]
  [void]$out.Add($Tag)
  $len = $Content.Length
  if ($len -lt 128) {
    [void]$out.Add($len)
  } else {
    $lenBytes = New-Object System.Collections.Generic.List[byte]
    $v = $len
    # 用位右移而非 [int]($v/256)：PS 的 [int] 强转浮点是四舍五入而非截断，会把 129 编码成 385
    while ($v -gt 0) { [void]$lenBytes.Insert(0, ($v -band 0xFF)); $v = $v -shr 8 }
    [void]$out.Add(0x80 -bor $lenBytes.Count)
    foreach ($b in $lenBytes) { [void]$out.Add($b) }
  }
  foreach ($b in $Content) { [void]$out.Add($b) }
  return $out.ToArray()
}

# 由 RSAParameters 构造 PKCS#1 RSAPrivateKey DER 字节
function Test-BuildPkcs1Der([System.Security.Cryptography.RSAParameters]$Rp) {
  $body = New-Object System.Collections.Generic.List[byte]
  $parts = @([byte[]]@(0), $Rp.Modulus, $Rp.Exponent, $Rp.D, $Rp.P, $Rp.Q, $Rp.DP, $Rp.DQ, $Rp.InverseQ)
  foreach ($part in $parts) {
    foreach ($b in (Test-DerIntBytes $part)) { [void]$body.Add($b) }
  }
  return (Test-DerTlv 0x30 $body.ToArray())
}

# 由 RSAParameters 构造 PKCS#1（BEGIN RSA PRIVATE KEY）PEM 文本
function Test-BuildPkcs1Pem([System.Security.Cryptography.RSAParameters]$Rp) {
  $der = Test-BuildPkcs1Der $Rp
  return "-----BEGIN RSA PRIVATE KEY-----`n$([Convert]::ToBase64String($der))`n-----END RSA PRIVATE KEY-----`n"
}

# 以子进程运行 jjpr.ps1（隔离 exit 与环境），返回 @{Code; Out}。
# $EnvSet/$EnvUnset 仅影响本次子进程运行，结束后恢复。
function RunJjpr {
  param(
    [string[]]$JjprArgs = @(),
    [hashtable]$EnvSet = @{},
    [string[]]$EnvUnset = @(),
    [string]$Cwd = ''
  )
  $prev = @{}
  foreach ($k in $EnvSet.Keys) {
    $prev[$k] = [Environment]::GetEnvironmentVariable($k)
    Set-Item -Path "Env:$k" -Value $EnvSet[$k]
  }
  foreach ($k in $EnvUnset) {
    $prev[$k] = [Environment]::GetEnvironmentVariable($k)
    Remove-Item -Path "Env:$k" -ErrorAction SilentlyContinue
  }
  try {
    if ($Cwd) { Push-Location $Cwd }
    $out = & $script:PsExe -NoProfile -ExecutionPolicy Bypass -File $script:JjprScript @JjprArgs 2>&1
    $code = $LASTEXITCODE
    return @{ Code = $code; Out = [string]($out -join "`n") }
  } finally {
    if ($Cwd) { Pop-Location }
    foreach ($k in $prev.Keys) {
      if ($null -ne $prev[$k]) { Set-Item -Path "Env:$k" -Value $prev[$k] }
      else { Remove-Item -Path "Env:$k" -ErrorAction SilentlyContinue }
    }
  }
}

# 以子进程运行 jjpr-credential.ps1 并注入 stdin，返回 @{Code; Out}
function RunCredential {
  param([string]$Stdin, [hashtable]$EnvSet = @{}, [string[]]$EnvUnset = @())
  $prev = @{}
  foreach ($k in $EnvSet.Keys) {
    $prev[$k] = [Environment]::GetEnvironmentVariable($k)
    Set-Item -Path "Env:$k" -Value $EnvSet[$k]
  }
  foreach ($k in $EnvUnset) {
    $prev[$k] = [Environment]::GetEnvironmentVariable($k)
    Remove-Item -Path "Env:$k" -ErrorAction SilentlyContinue
  }
  try {
    $out = $Stdin | & $script:PsExe -NoProfile -ExecutionPolicy Bypass -File $script:CredScript 2>&1
    $code = $LASTEXITCODE
    return @{ Code = $code; Out = [string]($out -join "`n") }
  } finally {
    foreach ($k in $prev.Keys) {
      if ($null -ne $prev[$k]) { Set-Item -Path "Env:$k" -Value $prev[$k] }
      else { Remove-Item -Path "Env:$k" -ErrorAction SilentlyContinue }
    }
  }
}

# ---- T0：dot-source 守卫 + 解释器定位 ----

$script:PsExe = GetPsExe
$script:JjprScript = Join-Path $ScriptsDir 'jjpr.ps1'
$script:CredScript = Join-Path $ScriptsDir 'jjpr-credential.ps1'
if ((Get-Command ConfigGet -ErrorAction SilentlyContinue) -and
    (Get-Command GenerateToken -ErrorAction SilentlyContinue) -and
    (Test-Path $script:PsExe)) {
  Ok 'T0 dot-source 加载守卫：仅暴露函数未触发主流程'
} else {
  Bad 'T0 dot-source 加载守卫：仅暴露函数未触发主流程'
}

# ---- T1/T2：子命令分发 ----

$r = RunJjpr @()
if ($r.Code -eq 2 -and $r.Out -match '用法') { Ok 'T1 无参数 -> usage + exit 2' } else { Bad 'T1 无参数 -> usage + exit 2' }

$r = RunJjpr @('nosuchcmd')
if ($r.Code -eq 2) { Ok 'T2 未知子命令 -> exit 2' } else { Bad 'T2 未知子命令 -> exit 2' }

# ---- T3-T5：ConfigGet 优先级 ----

$env:TESTKEY_A = 'from-env'
if ((ConfigGet 'TESTKEY_A') -eq 'from-env') { Ok 'T3 ConfigGet 环境变量优先' } else { Bad 'T3 ConfigGet 环境变量优先' }
Remove-Item Env:TESTKEY_A -ErrorAction SilentlyContinue

# 文件含 CRLF/注释/空行——验证 Windows 记事本编辑容错
$origEnvFile = $script:JJPR_ENV_FILE
$script:JJPR_ENV_FILE = Join-Path $Tmp 'env1'
[System.IO.File]::WriteAllText($script:JJPR_ENV_FILE, "# 注释行`r`nTESTKEY_B=from-file`r`n`r`nTESTKEY_C=from-file-c`r`n")
if ((ConfigGet 'TESTKEY_B') -eq 'from-file') { Ok 'T4 ConfigGet 读 env 文件（CRLF/注释/空行容错）' } else { Bad 'T4 ConfigGet 读 env 文件（CRLF/注释/空行容错）' }

$env:TESTKEY_C = ''
if ((ConfigGet 'TESTKEY_C') -eq 'from-file-c') { Ok 'T5 ConfigGet 环境变量为空串时回退文件' } else { Bad 'T5 ConfigGet 环境变量为空串时回退文件' }
Remove-Item Env:TESTKEY_C -ErrorAction SilentlyContinue
$script:JJPR_ENV_FILE = $origEnvFile

# ---- T6-T9：ToHttps 归一化 ----

if ((ToHttps 'git@github.com:lijing666/skills.git') -eq 'https://github.com/lijing666/skills.git') { Ok 'T6 ToHttps SSH 形式' } else { Bad 'T6 ToHttps SSH 形式' }

if ((ToHttps 'https://github.com/o/r') -eq 'https://github.com/o/r.git') { Ok 'T7 ToHttps https 补 .git' } else { Bad 'T7 ToHttps https 补 .git' }

if ((ToHttps 'ssh://git@github.com/o/r.git') -eq 'https://github.com/o/r.git') { Ok 'T8 ToHttps ssh:// 形式' } else { Bad 'T8 ToHttps ssh:// 形式' }

$threw = $false
try { ToHttps 'https://gitlab.com/o/r.git' | Out-Null } catch { $threw = $true }
if ($threw) { Ok 'T9 ToHttps 非 github 远端应失败' } else { Bad 'T9 ToHttps 非 github 远端应失败' }

# ---- T10-T12：凭据助手协议 ----

$r = RunCredential "protocol=https`nhost=github.com" -EnvSet @{ JJPR_TOKEN = 'test123' }
if ($r.Code -eq 0 -and $r.Out -eq "username=x-access-token`npassword=test123") {
  Ok 'T10 凭据助手输出 x-access-token + 令牌'
} else {
  Bad 'T10 凭据助手输出 x-access-token + 令牌'
}

$r = RunCredential "protocol=https`nhost=gitlab.com" -EnvSet @{ JJPR_TOKEN = 'test123' }
if ($r.Code -eq 0 -and $r.Out -eq '') { Ok 'T11 凭据助手对非 github.com 输出空' } else { Bad 'T11 凭据助手对非 github.com 输出空' }

$r = RunCredential "protocol=https`nhost=github.com" -EnvUnset @('JJPR_TOKEN')
if ($r.Code -ne 0) { Ok 'T12 凭据助手无令牌时失败' } else { Bad 'T12 凭据助手无令牌时失败' }

# ---- T13/T14：令牌缓存过期逻辑 ----

$origCacheDir = $script:JJPR_CACHE_DIR
$script:JJPR_CACHE_DIR = Join-Path $Tmp 'cache'
WriteTokenCache (Join-Path $Tmp 'cache/tok-a') 'secret-a'
if ((ReadCachedToken (Join-Path $Tmp 'cache/tok-a')) -eq 'secret-a') {
  Ok 'T13 缓存新鲜写入可命中'
} else {
  Bad 'T13 缓存新鲜写入可命中'
}

[System.IO.File]::WriteAllLines((Join-Path $Tmp 'cache/tok-b'), @('1', 'expired-tok'))  # 过期时间戳为 epoch 1，必已过期
if ($null -eq (ReadCachedToken (Join-Path $Tmp 'cache/tok-b'))) {
  Ok 'T14 过期缓存应未命中'
} else {
  Bad 'T14 过期缓存应未命中'
}
$script:JJPR_CACHE_DIR = $origCacheDir

# ---- T15：doctor 在无配置环境下 fail-fast，且中文指引消息真正可达 ----

$r = RunJjpr @('doctor') -EnvSet @{ JJPR_ENV_FILE = (Join-Path $Tmp 'nonexistent.env') } `
  -EnvUnset @('GITHUB_APP_ID', 'GITHUB_APP_PRIVATE_KEY_PATH', 'GITHUB_APP_INSTALLATION_ID') -Cwd $Tmp
if ($r.Code -ne 0 -and $r.Out -match '未配置 GITHUB_APP_ID') { Ok 'T15 doctor 无配置应 fail-fast' } else { Bad 'T15 doctor 无配置应 fail-fast' }

# ---- T16：GenerateToken 无配置报错（含中文指引，stderr 捕获验证）----

$saveEnv = @{}
foreach ($k in @('GITHUB_APP_ID', 'GITHUB_APP_PRIVATE_KEY_PATH', 'GITHUB_APP_INSTALLATION_ID')) {
  $saveEnv[$k] = [Environment]::GetEnvironmentVariable($k)
  Remove-Item -Path "Env:$k" -ErrorAction SilentlyContinue
}
$origEnvFile = $script:JJPR_ENV_FILE
$script:JJPR_ENV_FILE = Join-Path $Tmp 'nonexistent.env'
$sw = New-Object System.IO.StringWriter
$origErr = [Console]::Error
[Console]::SetError($sw)
$threw = $false
try { GenerateToken | Out-Null } catch { $threw = $true }
[Console]::SetError($origErr)
$script:JJPR_ENV_FILE = $origEnvFile
foreach ($k in $saveEnv.Keys) {
  if ($null -ne $saveEnv[$k]) { Set-Item -Path "Env:$k" -Value $saveEnv[$k] }
}
if ($threw -and ($sw.ToString() -match '缺少配置')) { Ok 'T16 GenerateToken 无配置中文报错' } else { Bad 'T16 GenerateToken 无配置中文报错' }

# ---- T17：B64Url 编码 ----

if ((B64Url ([Text.Encoding]::ASCII.GetBytes('A'))) -eq 'QQ' -and
    (B64Url ([Text.Encoding]::ASCII.GetBytes('abc'))) -eq 'YWJj') {
  Ok 'T17 B64Url 编码'
} else {
  Bad 'T17 B64Url 编码'
}

# ---- T21/T22：PEM 解析 + RSA 签名往返（先于 T18 生成测试私钥）----

# T21：PKCS#1 往返——手工构造 DER-PEM，经 ImportRsaFromPem 解析后签名，
#      用原公钥验签通过即证明解析正确
$rsa = [System.Security.Cryptography.RSACryptoServiceProvider]::new(1024)
$rp = $rsa.ExportParameters($true)
$pemPath = Join-Path $Tmp 't21.pem'
[System.IO.File]::WriteAllText($pemPath, (Test-BuildPkcs1Pem $rp))
$rsa2 = $null
$verified = $false
try {
  $rsa2 = ImportRsaFromPem $pemPath
  $data = [Text.Encoding]::ASCII.GetBytes('jjpr-test')
  $sig = $rsa2.SignData($data, 'SHA256')
  # 验签用老式 VerifyHash(hash, 'SHA256', sig)：该重载在 PS 5.1 与 pwsh 7 均存在；
  # 三/四参数 VerifyData 的重载集在两个运行时不同（3 参 HashAlgorithmName 仅 .NET Framework，
  # 4 参 padding 版仅 .NET Core+），无法跨版本通用
  $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($data)
  $verified = $rsa.VerifyHash($hash, 'SHA256', $sig)
} catch { $verified = $false }
if ($rsa2 -and $verified) { Ok 'T21 PEM 解析（PKCS#1）+ RSA 签名往返' } else { Bad 'T21 PEM 解析（PKCS#1）+ RSA 签名往返' }

# T22：PKCS#8 包裹形式（BEGIN PRIVATE KEY）
$pkcs1Der = Test-BuildPkcs1Der $rp
$algSeq = Test-DerTlv 0x30 ([byte[]](0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00))
$octet = Test-DerTlv 0x04 $pkcs1Der
$body8 = New-Object System.Collections.Generic.List[byte]
foreach ($b in (Test-DerIntBytes ([byte[]]@(0)))) { [void]$body8.Add($b) }
foreach ($b in $algSeq) { [void]$body8.Add($b) }
foreach ($b in $octet) { [void]$body8.Add($b) }
$der8 = Test-DerTlv 0x30 $body8.ToArray()
$pem8Path = Join-Path $Tmp 't22.pem'
[System.IO.File]::WriteAllText($pem8Path, "-----BEGIN PRIVATE KEY-----`n$([Convert]::ToBase64String($der8))`n-----END PRIVATE KEY-----`n")
$rsa3 = $null
$verified8 = $false
try {
  $rsa3 = ImportRsaFromPem $pem8Path
  $data = [Text.Encoding]::ASCII.GetBytes('jjpr-test')
  $sig = $rsa3.SignData($data, 'SHA256')
  # 验签用老式 VerifyHash(hash, 'SHA256', sig)：该重载在 PS 5.1 与 pwsh 7 均存在（理由见 T21）
  $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($data)
  $verified8 = $rsa.VerifyHash($hash, 'SHA256', $sig)
} catch { $verified8 = $false }
if ($rsa3 -and $verified8) { Ok 'T22 PEM 解析（PKCS#8 包裹）' } else { Bad 'T22 PEM 解析（PKCS#8 包裹）' }
$rsa.Dispose()
if ($rsa2) { $rsa2.Dispose() }
if ($rsa3) { $rsa3.Dispose() }

# ---- T18：令牌失败传播（回环地址模拟网络失败，doctor 不假通过）----

# 现场生成一次性 RSA 私钥（签名可通过），API 基址指向必拒的回环端口，
# 验证 GenerateToken 失败显式传播、doctor 停在"安装令牌生成失败"而非假通过。
$rsa18 = [System.Security.Cryptography.RSACryptoServiceProvider]::new(1024)
$t18Pem = Join-Path $Tmp 't18.pem'
[System.IO.File]::WriteAllText($t18Pem, (Test-BuildPkcs1Pem ($rsa18.ExportParameters($true))))
$rsa18.Dispose()
$t18Env = Join-Path $Tmp 't18.env'
[System.IO.File]::WriteAllLines($t18Env, @('GITHUB_APP_ID=1', "GITHUB_APP_PRIVATE_KEY_PATH=$t18Pem"))
$r = RunJjpr @('doctor') -Cwd $SkillDir `
  -EnvSet @{ JJPR_ENV_FILE = $t18Env; JJPR_API_BASE = 'http://127.0.0.1:1'; JJPR_CACHE_DIR = (Join-Path $Tmp 'cache-t18') } `
  -EnvUnset @('GITHUB_APP_INSTALLATION_ID')
if ($r.Code -ne 0 -and $r.Out -match '安装令牌生成失败' -and $r.Out -notmatch '预检通过') {
  Ok 'T18 令牌失败传播：doctor fail-fast 不假通过'
} else {
  Bad 'T18 令牌失败传播：doctor fail-fast 不假通过'
}

# ---- T19：token 子命令已移除（内部能力不对外暴露）----

$r = RunJjpr @('token')
if ($r.Code -eq 2) { Ok 'T19 token 子命令已移除' } else { Bad 'T19 token 子命令已移除' }

# ---- T20：默认动作（--title …）分发正确且默认分支防呆 ----

$repoDir = Join-Path $Tmp 'repo'
$null = & git init -q -b main $repoDir
& git -C $repoDir remote add origin git@github.com:dummy/dummy.git
$r = RunJjpr @('--title', 't') -Cwd $repoDir
if ($r.Code -ne 0 -and $r.Out -match '默认分支') {
  Ok 'T20 默认动作：推送+建PR 且默认分支防呆'
} else {
  Bad 'T20 默认动作：推送+建PR 且默认分支防呆'
}

# ---- 汇总 ----

Write-Output ""
Write-Output "冒烟测试：$Pass 通过，$Fail 失败"
Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
if ($Fail -eq 0) { exit 0 } else { exit 1 }
