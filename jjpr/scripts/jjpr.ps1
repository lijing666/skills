# jjpr.ps1 —— jjpr 的 Windows 原生入口（Windows PowerShell 5.1+ / PowerShell 7 均可运行），
# 与 bash 版 scripts/jjpr 行为对齐：以 GitHub App（jj-ai-agent）安装身份执行
# git 推送与 GitHub 操作，不使用个人 OAuth/PAT 凭据。
#
# 对外只有一个动作：
#   jjpr.ps1 [gh pr create 参数]   推送当前分支并以 App 身份创建 PR（如 --title/--body-file）
#
# 内部编排命令（AI 按 references/workflow.md 使用，不对外）：
#   jjpr.ps1 doctor            预检：依赖、配置、私钥、令牌生成、仓库与 gh 访问
#   jjpr.ps1 gh <gh参数>       以 App 身份执行 gh（自动注入 GH_TOKEN）
#   jjpr.ps1 push [git参数]    以 App 身份推送当前分支（CI 修复后重推）
#
# 配置来源（优先级从高到低）：环境变量 > ~/.git-app/jjpr.env（JJPR_ENV_FILE 可改指）。
# 令牌缓存于 ~/.cache/jjpr（unix 下 600），55 分钟内复用。
# 依赖：Windows PowerShell 5.1（系统内置，无需装 pwsh 7）+ git + gh；
#       JWT 签名用 .NET RSA、API 请求用 Invoke-RestMethod，无 openssl/curl 依赖。
# Windows 调用（脚本受执行策略限制，统一经 -File + Bypass）：
#   powershell -NoProfile -ExecutionPolicy Bypass -File jjpr\scripts\jjpr.ps1 <命令>
#
# Author: 李晶

# ---------- 全局初始化 ----------

# gh/git 均输出 UTF-8：统一控制台与管道编码，防止 PS 5.1 按 GBK 解码导致中文/输出乱码
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

# PS 5.1 默认 TLS 版本可能不含 1.2，而 GitHub API 强制 TLS 1.2+
try {
  [Net.ServicePointManager]::SecurityProtocol = `
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

$script:JJPR_HOME = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$script:JJPR_ENV_FILE = if ($env:JJPR_ENV_FILE) { $env:JJPR_ENV_FILE } else { Join-Path (Join-Path $HOME '.git-app') 'jjpr.env' }
$script:JJPR_CACHE_DIR = if ($env:JJPR_CACHE_DIR) { $env:JJPR_CACHE_DIR } else { Join-Path (Join-Path $HOME '.cache') 'jjpr' }
$script:JJPR_CACHE_TTL = 3300  # 令牌缓存 55 分钟（官方有效期 1 小时，留安全余量）
# API 基址可用 JJPR_API_BASE 覆盖（测试注入 / GHES 适配；与 bash 版对齐）
$script:API_BASE = if ($env:JJPR_API_BASE) { $env:JJPR_API_BASE } else { 'https://api.github.com' }
# PS 5.1 无 $IsWindows 自动变量，用环境变量判定（pwsh 7 下同样成立）
$script:IsWin = ($env:OS -eq 'Windows_NT')
# Fail 是否已打印过消息：用于顶层 catch 区分受控失败与未预期异常
$script:Failed = $false

# ---------- 基础工具 ----------

# 直接失败退出：错误信息到 stderr，退出码 1（对齐 bash 版 die）
function Die([string]$Message) {
  [Console]::Error.WriteLine("jjpr: $Message")
  exit 1
}

# 受控失败：错误信息到 stderr 后抛异常，交由上层翻译为调用方语境的失败信息
# （对齐 bash 版"子 shell 内 die 打印消息 + 调用方再报语境化错误"的两层消息形态）
function Fail([string]$Message) {
  $script:Failed = $true
  [Console]::Error.WriteLine("jjpr: $Message")
  throw New-Object System.Management.Automation.RuntimeException $Message
}

# 读取配置项：环境变量优先，其次 jjpr.env（KEY=VALUE 行，# 为注释；容忍 CRLF 与首尾空白，
# 兼容 Windows 记事本编辑）。有值时输出该值，未配置时输出 $null。
function ConfigGet([string]$Key) {
  $value = [Environment]::GetEnvironmentVariable($Key)
  if ($value) { return $value }
  if (Test-Path -LiteralPath $script:JJPR_ENV_FILE) {
    foreach ($line in [System.IO.File]::ReadAllLines($script:JJPR_ENV_FILE)) {
      $t = $line.Trim()
      if ($t -and -not $t.StartsWith('#') -and $t.StartsWith("$Key=")) {
        $val = $t.Substring($Key.Length + 1).Trim()
        if ($val) { return $val }
      }
    }
  }
  return $null
}

# 归一化远端 URL 为 https://github.com/OWNER/REPO.git；非 github.com 远端报错。
# 支持 git@github.com:o/r.git、ssh://git@github.com/o/r.git、https://github.com/o/r[.git]。
function ToHttps([string]$Url) {
  if ($Url -like 'git@github.com:*') {
    $Url = 'https://github.com/' + $Url.Substring('git@github.com:'.Length)
  } elseif ($Url -like 'ssh://git@github.com/*') {
    $Url = 'https://github.com/' + $Url.Substring('ssh://git@github.com/'.Length)
  } elseif ($Url -like 'https://github.com/*') {
    # 已是目标形式
  } else {
    Fail "仅支持 github.com 远端，当前 origin 为：$Url"
  }
  if (-not $Url.EndsWith('.git')) { $Url = $Url + '.git' }
  return $Url
}

# 从 origin 远端解析 OWNER/REPO（如 lijing666/skills）；不在仓库或无 origin 时报错
function OriginRepo {
  $url = [string](& git remote get-url origin 2>$null)
  if ($LASTEXITCODE -ne 0 -or -not $url) {
    Fail '当前目录不是 git 仓库，或缺少 origin 远端'
  }
  $repo = ToHttps $url
  $repo = $repo.Substring('https://github.com/'.Length)
  if ($repo.EndsWith('.git')) { $repo = $repo.Substring(0, $repo.Length - 4) }
  return $repo
}

# ---------- 令牌生成（.NET 原生 RSA + Invoke-RestMethod，无 openssl/curl 依赖） ----------

# 字节数组编码为 base64url（URL 安全字母表、去填充），用于 JWT 头/负载/签名
function B64Url([byte[]]$Bytes) {
  return [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

# 读 DER 长度字段（短/长形式），返回 @(长度, 新游标)
function ReadDerLen([byte[]]$Der, [int]$Pos) {
  $b = $Der[$Pos]
  $Pos = $Pos + 1
  if ($b -band 0x80) {
    $n = $b -band 0x7F
    if ($n -gt 4) { Fail '私钥 DER 结构异常：长度字段超限' }
    $len = 0
    for ($i = 0; $i -lt $n; $i++) {
      $len = $len * 256 + $Der[$Pos]
      $Pos = $Pos + 1
    }
    return @($len, $Pos)
  }
  return @([int]$b, $Pos)
}

# 读一个 DER INTEGER，返回 @(内容字节[去 DER 正数前导零], 新游标)
function ReadDerInt([byte[]]$Der, [int]$Pos) {
  $tag = $Der[$Pos]
  $Pos = $Pos + 1
  if ($tag -ne 0x02) {
    Fail ('私钥 DER 结构异常：期望 INTEGER（0x02），实际 tag 0x{0:X2}' -f $tag)
  }
  $r = ReadDerLen $Der $Pos
  $len = $r[0]
  $Pos = $r[1]
  if (($Pos + $len) -gt $Der.Length) { Fail '私钥 DER 结构异常：INTEGER 长度越界' }
  # 去掉 DER 为正数补的前导 0x00（保留至少 1 字节）
  $s = $Pos
  while ($s -lt ($Pos + $len - 1) -and $Der[$s] -eq 0) { $s = $s + 1 }
  $content = New-Object byte[] ($Pos + $len - $s)
  [Array]::Copy($Der, $s, $content, 0, $content.Length)
  return @($content, ($Pos + $len))
}

# 字节数组左侧补零到指定长度（DER 整数去前导零后恢复 RSA 字段定长）
function PadLeftTo([byte[]]$Bytes, [int]$Size) {
  if ($Bytes.Length -ge $Size) { return ,$Bytes }
  $out = New-Object byte[] $Size
  [Array]::Copy($Bytes, 0, $out, $Size - $Bytes.Length, $Bytes.Length)
  return ,$out
}

# 解析 PEM 私钥（PKCS#1 BEGIN RSA PRIVATE KEY 或 PKCS#8 BEGIN PRIVATE KEY）为
# RSACryptoServiceProvider。PS 5.1 的 .NET Framework 无 ImportFromPem，
# 须手工解 DER 取出 (n,e,d,p,q,dp,dq,qinv) 再 ImportParameters。
function ImportRsaFromPem([string]$PemPath) {
  $text = [System.IO.File]::ReadAllText($PemPath)
  if ($text -notmatch '-----BEGIN (RSA )?PRIVATE KEY-----') {
    Fail "私钥格式不支持（须为 RSA PEM：BEGIN RSA PRIVATE KEY 或 BEGIN PRIVATE KEY）：$PemPath"
  }
  # 去 PEM 头尾与所有空白 → DER 字节
  $b64 = ($text -replace '-----[^-]+-----', '') -replace '\s+', ''
  $der = [Convert]::FromBase64String($b64)

  # 外层 SEQUENCE 头
  if ($der[0] -ne 0x30) { Fail '私钥 DER 结构异常：外层应为 SEQUENCE' }
  $r = ReadDerLen $der 1
  $pos = $r[1]
  # 第一个子元素：INTEGER version（PKCS#1 与 PKCS#8 均为 0）
  $r = ReadDerInt $der $pos
  $pos = $r[1]
  # 分派：PKCS#8（下一个是 AlgorithmIdentifier SEQUENCE）或 PKCS#1（下一个是模数 INTEGER）
  if ($der[$pos] -eq 0x30) {
    # 跳过 AlgorithmIdentifier（SEQ{OID rsaEncryption, NULL}）
    $r = ReadDerLen $der ($pos + 1)
    $pos = $r[1] + $r[0]
    # OCTET STRING 内嵌完整 PKCS#1 RSAPrivateKey
    if ($der[$pos] -ne 0x04) { Fail '私钥 DER 结构异常：PKCS#8 缺少 OCTET STRING' }
    $r = ReadDerLen $der ($pos + 1)
    $pos = $r[1]
    if ($der[$pos] -ne 0x30) { Fail '私钥 DER 结构异常：内嵌 PKCS#1 应为 SEQUENCE' }
    $r = ReadDerLen $der ($pos + 1)
    $pos = $r[1]
    $r = ReadDerInt $der $pos   # 内层 version
    $pos = $r[1]
  }
  # PKCS#1 九元组（version 已消费）：n e d p q dp dq qinv
  $r = ReadDerInt $der $pos; $n = $r[0];  $pos = $r[1]
  $r = ReadDerInt $der $pos; $e = $r[0];  $pos = $r[1]
  $r = ReadDerInt $der $pos; $d = $r[0];  $pos = $r[1]
  $r = ReadDerInt $der $pos; $p = $r[0];  $pos = $r[1]
  $r = ReadDerInt $der $pos; $q = $r[0];  $pos = $r[1]
  $r = ReadDerInt $der $pos; $dp = $r[0]; $pos = $r[1]
  $r = ReadDerInt $der $pos; $dq = $r[0]; $pos = $r[1]
  $r = ReadDerInt $der $pos; $qinv = $r[0]; $pos = $r[1]

  # 尺寸对齐：ImportParameters 对字段长度敏感，按模数长度（向上取整到 8 的倍数）补齐
  $kl = [int]([Math]::Ceiling($n.Length / 8.0) * 8)
  $hl = [int]($kl / 2)
  $rp = New-Object System.Security.Cryptography.RSAParameters
  $rp.Modulus = PadLeftTo $n $kl
  $rp.Exponent = PadLeftTo $e 3
  $rp.D = PadLeftTo $d $kl
  $rp.P = PadLeftTo $p $hl
  $rp.Q = PadLeftTo $q $hl
  $rp.DP = PadLeftTo $dp $hl
  $rp.DQ = PadLeftTo $dq $hl
  $rp.InverseQ = PadLeftTo $qinv $hl
  $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider
  $rsa.ImportParameters($rp)   # 参数不一致会抛异常，由上层转为中文报错
  return $rsa
}

# 调 GitHub API：成功返回解析后的 JSON 对象；4xx/网络错误按状态码转成中文修复指引。
# $FailContext 用于默认错误前缀（发现安装失败/获取令牌失败），$NotFoundHint 为 404 专属提示。
function InvokeGithub([string]$Method, [string]$Path, [string]$Jwt, [string]$Body, [string]$FailContext, [string]$NotFoundHint) {
  $headers = @{
    'Accept' = 'application/vnd.github+json'
    'Authorization' = "Bearer $Jwt"
    'X-GitHub-Api-Version' = '2026-03-10'
  }
  try {
    if ($Method -eq 'GET') {
      return Invoke-RestMethod -Method Get -Uri "$($script:API_BASE)$Path" `
        -Headers $headers -UserAgent 'jjpr-skill' -TimeoutSec 30 -ErrorAction Stop
    }
    return Invoke-RestMethod -Method Post -Uri "$($script:API_BASE)$Path" `
      -Headers $headers -UserAgent 'jjpr-skill' -ContentType 'application/json' `
      -Body $Body -TimeoutSec 30 -ErrorAction Stop
  } catch {
    # PS 5.1 抛 WebException（HttpWebResponse），pwsh 7 抛 HttpResponseException，取码方式一致
    $code = 0
    try { $code = [int]$_.Exception.Response.StatusCode } catch { $code = 0 }
    switch ($code) {
      401 { Fail 'JWT 认证失败（401）：私钥与 GITHUB_APP_ID 不匹配，或私钥已被轮换' }
      403 { Fail 'GitHub 拒绝访问（403）：App 权限或安装范围不足' }
      404 { Fail $NotFoundHint }
      default {
        if ($code -eq 0) {
          Fail "$FailContext——网络请求失败：检查网络或代理（整体 30 秒超时即报此错）"
        }
        Fail "${FailContext}：HTTP $code"
      }
    }
  }
}

# 生成 GitHub App 安装访问令牌并输出到 stdout。
# 流程：读配置 -> 签发 JWT（.NET RS256）-> 发现安装 ID（未显式配置时）-> 换取令牌。
# 失败一律 Fail（打印消息并抛出），由上层翻译为调用方语境的错误。
function GenerateToken {
  $appId = ConfigGet 'GITHUB_APP_ID'
  $keyPath = ConfigGet 'GITHUB_APP_PRIVATE_KEY_PATH'
  if (-not $appId -or -not $keyPath) {
    Fail "缺少配置：GITHUB_APP_ID / GITHUB_APP_PRIVATE_KEY_PATH（环境变量或 $($script:JJPR_ENV_FILE)）"
  }
  if ($appId -notmatch '^[0-9]+$') {
    Fail "GITHUB_APP_ID 须为数字，当前：$appId"
  }
  if ($keyPath.StartsWith('~')) { $keyPath = $HOME + $keyPath.Substring(1) }
  if (-not (Test-Path -LiteralPath $keyPath)) {
    Fail "私钥文件不存在：$keyPath"
  }

  # JWT 时窗：iat 回拨 60 秒容忍时钟偏差；exp 为 +540 秒，时窗在 GitHub 的 10 分钟上限内
  $epoch = [DateTime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
  $now = [int64]([DateTime]::UtcNow - $epoch).TotalSeconds
  $header = B64Url ([Text.Encoding]::ASCII.GetBytes('{"alg":"RS256","typ":"JWT"}'))
  $payloadJson = '{{"iat":{0},"exp":{1},"iss":{2}}}' -f ($now - 60), ($now + 540), $appId
  $payload = B64Url ([Text.Encoding]::ASCII.GetBytes($payloadJson))
  $signingInput = "$header.$payload"

  # RS256 签名（PKCS#1 v1.5 + SHA-256，.NET 原生）
  $rsa = $null
  try {
    $rsa = ImportRsaFromPem $keyPath
    $sigBytes = $rsa.SignData([Text.Encoding]::ASCII.GetBytes($signingInput), 'SHA256')
  } catch {
    if ($rsa) { $rsa.Dispose() }
    Fail "JWT 签名失败（.NET RSA）：私钥不可读或格式无效（$($_.Exception.Message)）"
  }
  $sig = B64Url $sigBytes
  $rsa.Dispose()
  $jwt = "$signingInput.$sig"

  # 安装 ID：显式配置优先；否则用仓库上下文向 GitHub 发现
  $installationId = ConfigGet 'GITHUB_APP_INSTALLATION_ID'
  if (-not $installationId) {
    $repository = $env:GITHUB_REPOSITORY
    if (-not $repository -or $repository -notlike '*/*') {
      Fail '缺少安装 ID：请配置 GITHUB_APP_INSTALLATION_ID，或在 git 仓库内运行（自动从 origin 解析 OWNER/REPO）'
    }
    $resp = InvokeGithub 'GET' "/repos/$repository/installation" $jwt '' `
      '发现安装失败' "未发现 App 安装（404）：App 尚未安装到 $repository，或仓库不存在"
    $installationId = "$($resp.id)"
    if (-not $installationId) { Fail '发现安装响应异常：未能解析 installation id' }
  }

  # 用安装 ID 换取 1 小时有效的安装访问令牌
  $resp = InvokeGithub 'POST' "/app/installations/$installationId/access_tokens" $jwt '{}' `
    '获取令牌失败' "安装 ID 不存在（404）：GITHUB_APP_INSTALLATION_ID=$installationId 无效"
  $token = $resp.token
  if (-not $token) { Fail '令牌响应异常：未能解析 token 字段' }
  return "$token"
}

# ---------- 令牌管理 ----------

# 确保安装上下文可用：无显式安装 ID 时，从 origin 解析仓库并注入环境变量（供 GenerateToken 读取）
function EnsureInstallationContext {
  if (-not (ConfigGet 'GITHUB_APP_INSTALLATION_ID')) {
    if (-not $env:GITHUB_REPOSITORY) {
      $env:GITHUB_REPOSITORY = OriginRepo
    }
  }
}

# 令牌缓存文件路径：按安装 ID（或仓库名）隔离，避免跨安装串用
function TokenCacheFile {
  $key = ConfigGet 'GITHUB_APP_INSTALLATION_ID'
  if (-not $key) {
    $key = if ($env:GITHUB_REPOSITORY) { $env:GITHUB_REPOSITORY } else { 'unknown' }
  }
  $key = $key.Replace('/', '--')
  return (Join-Path $script:JJPR_CACHE_DIR "token-$key")
}

# 读取未过期缓存令牌：文件两行（过期时间戳、令牌）；命中输出令牌，否则输出 $null
function ReadCachedToken([string]$CacheFile) {
  if (-not (Test-Path -LiteralPath $CacheFile)) { return $null }
  $lines = [System.IO.File]::ReadAllLines($CacheFile)
  if ($lines.Count -lt 2 -or -not $lines[1]) { return $null }
  $expiry = 0
  if (-not [int64]::TryParse($lines[0], [ref]$expiry)) { return $null }
  $epoch = [DateTime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
  $now = [int64]([DateTime]::UtcNow - $epoch).TotalSeconds
  if ($now -ge $expiry) { return $null }
  return $lines[1]
}

# 写入令牌缓存：unix 下目录 700 / 文件 600；Windows 依赖用户目录默认 NTFS ACL 隔离
function WriteTokenCache([string]$CacheFile, [string]$Token) {
  if (-not (Test-Path -LiteralPath $script:JJPR_CACHE_DIR)) {
    $null = New-Item -ItemType Directory -Path $script:JJPR_CACHE_DIR -Force
  }
  if (-not $script:IsWin) {
    try { & chmod 700 $script:JJPR_CACHE_DIR 2>$null } catch { }
  }
  $epoch = [DateTime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
  $expiry = [int64]([DateTime]::UtcNow - $epoch).TotalSeconds + $script:JJPR_CACHE_TTL
  [System.IO.File]::WriteAllLines($CacheFile, @("$expiry", $Token))
  if (-not $script:IsWin) {
    try { & chmod 600 $CacheFile 2>$null } catch { }
  }
}

# 获取安装令牌：优先读缓存（55 分钟内），过期或无缓存则生成。
# 任何失败（消息已由 Fail 打印）均返回 $null，由调用方输出语境化错误。
function GetToken {
  try {
    EnsureInstallationContext
    $cache = TokenCacheFile
    $tok = ReadCachedToken $cache
    if ($tok) { return $tok }
    $tok = GenerateToken
    if (-not $tok) { return $null }
    WriteTokenCache $cache $tok
    return $tok
  } catch {
    return $null
  }
}

# ---------- 子命令 ----------

# 当前 PowerShell 解释器可执行文件：凭据助手须用同一解释器拉起
# （Windows 上 git 无法直接执行 .ps1；5.1→powershell.exe，Core→pwsh）
function GetPsExe {
  if ($PSVersionTable.PSEdition -eq 'Core') {
    $name = if ($script:IsWin) { 'pwsh.exe' } else { 'pwsh' }
  } else {
    $name = 'powershell.exe'
  }
  return (Join-Path $PSHOME $name)
}

# 以 App 身份执行 gh 原生命令：令牌仅注入子进程环境，进程退出即销毁
function CmdGh {
  if ($args.Count -lt 1) { Die '用法：jjpr gh <gh参数>（如 jjpr gh pr view 12）' }
  $ghArgs = $args
  $tok = GetToken
  if (-not $tok) { Die '安装令牌获取失败（可先跑 jjpr doctor 定位）' }
  $env:GH_TOKEN = $tok
  & gh @ghArgs
  exit $LASTEXITCODE
}

# 以 App 身份推送当前分支：清空继承的凭据助手（钥匙串 / gh auth setup-git 等），
# 注入 jjpr 专用凭据助手（经当前解释器拉起 jjpr-credential.ps1），显式指定 HTTPS
# 推送地址——即使 origin 是 SSH 形式也不改配置、不走个人凭据。
function CmdPush {
  $gitArgs = $args
  $url = [string](& git remote get-url origin 2>$null)
  if ($LASTEXITCODE -ne 0 -or -not $url) { Die '当前目录不是 git 仓库，或缺少 origin 远端' }
  $url = ToHttps $url
  $branch = [string](& git branch --show-current 2>$null)
  if (-not $branch) { Die '当前处于 detached HEAD，无法推送' }
  $tok = GetToken
  if (-not $tok) { Die '安装令牌获取失败（可先跑 jjpr doctor 定位）' }
  $env:JJPR_TOKEN = $tok

  # git 经其内置 sh 执行 "!" 前缀的 shell 助手；路径转正斜杠并用 sh 单引号包裹
  # （容忍空格；避免 PS 5.1 原生传参不转义内嵌双引号、pwsh 7.3+ 又会二次转义的坑）
  $psExe = (GetPsExe).Replace('\', '/')
  $credScript = (Join-Path (Join-Path $script:JJPR_HOME 'scripts') 'jjpr-credential.ps1').Replace('\', '/')
  $helper = "!'$psExe' -NoProfile -ExecutionPolicy Bypass -File '$credScript'"

  & git -c 'credential.helper=' -c $helper push @gitArgs $url "HEAD:refs/heads/$branch"
  exit $LASTEXITCODE
}

# 推送当前分支后以 App 身份创建 PR：参数透传给 gh pr create。
# 防呆：拒绝在默认分支上直接工作。
function CmdPr {
  $prArgs = $args
  $cur = [string](& git branch --show-current 2>$null)
  if ($LASTEXITCODE -ne 0) { Die '当前目录不是 git 仓库' }
  if ($cur -eq 'main' -or $cur -eq 'master') {
    Die "不要直接在默认分支（$cur）上工作，请切到特性分支"
  }
  if (-not $cur) { Die '当前处于 detached HEAD，无法创建 PR' }
  CmdPush
  $tok = GetToken
  if (-not $tok) { Die '安装令牌获取失败（可先跑 jjpr doctor 定位）' }
  $env:GH_TOKEN = $tok
  & gh pr create @prArgs
  exit $LASTEXITCODE
}

# 预检：解释器/依赖 -> 配置 -> 私钥 -> 仓库上下文 -> 令牌 -> gh 访问，
# 第一处失败即停（fail-fast）并给出修复指引。
function CmdDoctor {
  Write-Output 'jjpr 预检'

  $psVer = $PSVersionTable.PSVersion.ToString()
  Write-Output "  [OK] PowerShell $psVer（$($PSVersionTable.PSEdition)）"

  # git 与 gh 在 Windows 上是相互独立的安装，须各自检查
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Die 'git 不可用（推送/仓库解析依赖）——请安装 Git for Windows'
  }
  Write-Output '  [OK] git 可用'

  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Die 'gh 不可用（GitHub CLI 操作依赖）——如 winget install GitHub.cli'
  }
  $ghFirst = (& gh --version | Select-Object -First 1)
  $ghVer = ($ghFirst -split '\s+')[2]
  Write-Output "  [OK] gh $ghVer"

  $appId = ConfigGet 'GITHUB_APP_ID'
  if (-not $appId) { Die "未配置 GITHUB_APP_ID（环境变量或 $($script:JJPR_ENV_FILE)）" }
  if ($appId -notmatch '^[0-9]+$') { Die "GITHUB_APP_ID 须为数字，当前：$appId" }
  Write-Output "  [OK] App ID = $appId"

  $keyPath = ConfigGet 'GITHUB_APP_PRIVATE_KEY_PATH'
  if (-not $keyPath) { Die "未配置 GITHUB_APP_PRIVATE_KEY_PATH（$($script:JJPR_ENV_FILE)）" }
  if ($keyPath.StartsWith('~')) { $keyPath = $HOME + $keyPath.Substring(1) }
  if (-not (Test-Path -LiteralPath $keyPath)) { Die "私钥不存在：$keyPath" }
  if ($script:IsWin) {
    Write-Output '  [i] Windows：私钥依赖用户目录 NTFS ACL 隔离，请勿置于共享/网络目录'
  } else {
    # 权限探测：GNU stat（Linux）优先，BSD stat（macOS）回退，与 bash 版一致
    $perm = ''
    try { $perm = [string](& stat -c '%a' $keyPath 2>$null) } catch { $perm = '' }
    if (-not $perm) { try { $perm = [string](& stat -f '%Lp' $keyPath 2>$null) } catch { $perm = '' } }
    if ($perm -and $perm -ne '600') {
      Write-Output "  [!] 私钥权限非 600，建议：chmod 600 $keyPath"
    }
  }
  Write-Output "  [OK] 私钥就绪：$keyPath"

  & git rev-parse --git-dir 2>$null | Out-Null
  $inGit = ($LASTEXITCODE -eq 0)
  $repoUrl = ''
  if ($inGit) { $repoUrl = [string](& git remote get-url origin 2>$null) }
  if ($inGit -and $LASTEXITCODE -eq 0 -and $repoUrl) {
    $env:GITHUB_REPOSITORY = OriginRepo
    Write-Output "  [OK] origin 仓库：$($env:GITHUB_REPOSITORY)"
  } else {
    Write-Output '  [!] 当前不在 git 仓库（或无 origin）——跳过仓库相关检查'
  }

  $tok = GetToken
  if (-not $tok) { Die '安装令牌生成失败（检查私钥/App ID/安装状态）' }
  Write-Output "  [OK] 安装令牌生成成功（缓存于 $($script:JJPR_CACHE_DIR)）"

  if ($env:GITHUB_REPOSITORY) {
    $env:GH_TOKEN = $tok
    & gh repo view $env:GITHUB_REPOSITORY --json nameWithOwner *> $null
    if ($LASTEXITCODE -eq 0) {
      Write-Output "  [OK] gh 以 App 身份访问 $($env:GITHUB_REPOSITORY) 成功"
    } else {
      Die "gh 访问 $($env:GITHUB_REPOSITORY) 失败：App 可能未安装到该仓库（404）或权限不足（403）"
    }
  }

  Write-Output '预检通过：可执行 jjpr push / jjpr pr。'
}

# ---------- 入口 ----------

# 输出用法说明文本（stdout 版供 -h；stderr 版由调用方自行 WriteLine）
function UsageText {
  return @'
用法：jjpr.ps1 [gh pr create 参数]   推送当前分支并以 App 身份创建 PR
示例：jjpr.ps1 --title "标题" --body-file pr.md

内部命令（AI 编排与排障用，见 references/workflow.md）：
  doctor            预检配置与身份链路
  gh <gh参数>       以 App 身份执行 gh
  push [git参数]    以 App 身份推送当前分支
'@
}

# 命令分发：- 开头的参数走默认动作（推送 + 建 PR）；
# doctor/gh/push 为内部编排命令；其余视为误用。
function Main {
  if ($args.Count -lt 1) {
    [Console]::Error.WriteLine((UsageText))
    exit 2
  }
  $cmd = [string]$args[0]
  $rest = @()
  if ($args.Count -gt 1) { $rest = @($args[1..($args.Count - 1)]) }
  switch ($cmd) {
    'doctor' { CmdDoctor }
    'gh'     { CmdGh @rest }
    'push'   { CmdPush @rest }
    '-h'     { Write-Output (UsageText) }
    '--help' { Write-Output (UsageText) }
    'help'   { Write-Output (UsageText) }
    default {
      if ($cmd.StartsWith('-')) {
        CmdPr @args
      } else {
        [Console]::Error.WriteLine((UsageText))
        exit 2
      }
    }
  }
}

# 直接执行时进入主流程；被 dot-source（测试加载函数）时仅暴露函数——
# 对齐 bash 版的 BASH_SOURCE 守卫。顶层 catch 兜底：受控失败（Fail 已打印
# 消息）静默退出 1，未预期异常补打一行错误后退出 1。
if ($MyInvocation.InvocationName -ne '.') {
  try {
    Main @args
  } catch {
    if (-not $script:Failed) {
      [Console]::Error.WriteLine("jjpr: 未预期错误：$($_.Exception.Message)")
    }
    exit 1
  }
}
