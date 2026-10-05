# jjpr 专用 git 凭据助手（PowerShell 版）：向 git 提供安装令牌，替代个人凭据
# （Windows 凭据管理器 / gh auth setup-git 挂载的个人助手等）。
# 协议：stdin 收到 "protocol=...\nhost=..."，stdout 输出 "username=...\npassword=..."。
# 令牌经环境变量 JJPR_TOKEN 注入，不落盘、不回显。
# 注意：git 无法直接执行 .ps1，本文件由 jjpr.ps1 以
#   powershell/pwsh -NoProfile -ExecutionPolicy Bypass -File <本文件>
# 形式挂载为凭据助手（git 经其内置 sh 执行 "!" 前缀的 shell 助手）。
#
# Author: 李晶

# 读取 git 传入的凭据请求描述（key=value 行集合，容忍 LF/CRLF 两种行尾）
$inputText = [Console]::In.ReadToEnd()
$hostOk = $false
$protoOk = $false
foreach ($line in @($inputText -split "`n")) {
  $l = $line.Trim("`r")
  if ($l -eq 'host=github.com') { $hostOk = $true }
  if ($l -eq 'protocol=https') { $protoOk = $true }
}

# 仅响应 github.com 的 HTTPS 凭据请求；其余输出空（git 视为无凭据可用）
if ($hostOk -and $protoOk) {
  $tok = $env:JJPR_TOKEN
  if (-not $tok) {
    [Console]::Error.WriteLine('jjpr: JJPR_TOKEN 未设置——请通过 jjpr 入口调用本脚本')
    exit 1
  }
  Write-Output 'username=x-access-token'
  Write-Output "password=$tok"
}
exit 0
