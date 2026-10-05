#!/usr/bin/env bash
# jjpr 专用 git 凭据助手：向 git 提供安装令牌，替代个人凭据（钥匙串/PAT）。
# 协议：stdin 收到 "protocol=...\nhost=..."，stdout 输出 "username=...\npassword=..."。
# 令牌经环境变量 JJPR_TOKEN 注入，不落盘、不回显。
set -euo pipefail

# 读取 git 传入的凭据请求描述
input="$(cat)"

# 仅响应 github.com 的 HTTPS 凭据请求；其余输出空（git 视为无凭据可用）
if grep -q '^host=github\.com$' <<<"$input" && grep -q '^protocol=https$' <<<"$input"; then
  : "${JJPR_TOKEN:?JJPR_TOKEN 未设置——请通过 jjpr 入口调用本脚本}"
  printf 'username=x-access-token\n'
  printf 'password=%s\n' "$JJPR_TOKEN"
fi
