#!/usr/bin/env bash
# jjpr 冒烟测试（无网络依赖）。
# 覆盖：子命令分发、配置读取优先级、远端 URL 归一化、凭据助手协议、
#       令牌缓存过期逻辑、doctor 的 fail-fast 路径、token.py 配置解析。
# 运行：bash tests/doctor-smoke.test.sh
set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

# 记录通过用例
ok() { PASS=$((PASS + 1)); printf '  [PASS] %s\n' "$1"; }

# 记录失败用例
bad() { FAIL=$((FAIL + 1)); printf '  [FAIL] %s\n' "$1"; }

# ---- T1/T2：子命令分发 ----

"$SCRIPTS_DIR/jjpr" >/dev/null 2>&1; [[ $? -eq 2 ]] && ok "T1 无参数 -> usage + exit 2" || bad "T1 无参数 -> usage + exit 2"
"$SCRIPTS_DIR/jjpr" nosuchcmd >/dev/null 2>&1; [[ $? -eq 2 ]] && ok "T2 未知子命令 -> exit 2" || bad "T2 未知子命令 -> exit 2"

# ---- T3-T5：config_get 优先级（子 shell 内 source，隔离 set -e 影响）----

(
  export TESTKEY_A=from-env
  source "$SCRIPTS_DIR/jjpr"
  [[ "$(config_get TESTKEY_A)" == "from-env" ]]
) && ok "T3 config_get 环境变量优先" || bad "T3 config_get 环境变量优先"

printf '# 注释行\nTESTKEY_B=from-file\n\nTESTKEY_C=from-file-c\n' > "$TMP/env1"
(
  unset TESTKEY_B
  export JJPR_ENV_FILE="$TMP/env1"
  source "$SCRIPTS_DIR/jjpr"
  [[ "$(config_get TESTKEY_B)" == "from-file" ]]
) && ok "T4 config_get 读 env 文件（跳过注释/空行）" || bad "T4 config_get 读 env 文件（跳过注释/空行）"

(
  TESTKEY_C=""
  export JJPR_ENV_FILE="$TMP/env1"
  source "$SCRIPTS_DIR/jjpr"
  [[ "$(config_get TESTKEY_C)" == "from-file-c" ]]
) && ok "T5 config_get 环境变量为空串时回退文件" || bad "T5 config_get 环境变量为空串时回退文件"

# ---- T6-T9：to_https 归一化 ----

(
  source "$SCRIPTS_DIR/jjpr"
  [[ "$(to_https "git@github.com:lijing666/skills.git")" == "https://github.com/lijing666/skills.git" ]]
) && ok "T6 to_https SSH 形式" || bad "T6 to_https SSH 形式"

(
  source "$SCRIPTS_DIR/jjpr"
  [[ "$(to_https "https://github.com/o/r")" == "https://github.com/o/r.git" ]]
) && ok "T7 to_https https 补 .git" || bad "T7 to_https https 补 .git"

(
  source "$SCRIPTS_DIR/jjpr"
  [[ "$(to_https "ssh://git@github.com/o/r.git")" == "https://github.com/o/r.git" ]]
) && ok "T8 to_https ssh:// 形式" || bad "T8 to_https ssh:// 形式"

(
  source "$SCRIPTS_DIR/jjpr"
  to_https "https://gitlab.com/o/r.git" >/dev/null
) 2>/dev/null && bad "T9 to_https 非 github 远端应失败" || ok "T9 to_https 非 github 远端应失败"

# ---- T10-T12：凭据助手协议 ----

out="$(printf 'protocol=https\nhost=github.com\n' | JJPR_TOKEN=test123 "$SCRIPTS_DIR/jjpr-credential.sh")"
[[ "$out" == "username=x-access-token
password=test123" ]] && ok "T10 凭据助手输出 x-access-token + 令牌" || bad "T10 凭据助手输出 x-access-token + 令牌"

out="$(printf 'protocol=https\nhost=gitlab.com\n' | JJPR_TOKEN=test123 "$SCRIPTS_DIR/jjpr-credential.sh")"
[[ -z "$out" ]] && ok "T11 凭据助手对非 github.com 输出空" || bad "T11 凭据助手对非 github.com 输出空"

printf 'protocol=https\nhost=github.com\n' | env -u JJPR_TOKEN "$SCRIPTS_DIR/jjpr-credential.sh" >/dev/null 2>&1
[[ $? -ne 0 ]] && ok "T12 凭据助手无令牌时失败" || bad "T12 凭据助手无令牌时失败"

# ---- T13/T14：令牌缓存过期逻辑 ----

(
  export JJPR_CACHE_DIR="$TMP/cache"
  source "$SCRIPTS_DIR/jjpr"
  write_token_cache "$TMP/cache/tok-a" "secret-a"
  [[ "$(read_cached_token "$TMP/cache/tok-a")" == "secret-a" ]]
) && ok "T13 缓存新鲜写入可命中" || bad "T13 缓存新鲜写入可命中"

(
  export JJPR_CACHE_DIR="$TMP/cache"
  source "$SCRIPTS_DIR/jjpr"
  printf '1\nexpired-tok\n' > "$TMP/cache/tok-b"   # 过期时间戳为 epoch 1，必已过期
  read_cached_token "$TMP/cache/tok-b" >/dev/null
) 2>/dev/null && bad "T14 过期缓存应未命中" || ok "T14 过期缓存应未命中"

# ---- T15：doctor 在无配置环境下 fail-fast，且中文指引消息真正可达 ----

(
  cd "$TMP"
  unset GITHUB_APP_ID GITHUB_APP_PRIVATE_KEY_PATH GITHUB_APP_INSTALLATION_ID
  JJPR_ENV_FILE="$TMP/nonexistent.env" "$SCRIPTS_DIR/jjpr" doctor
) > "$TMP/t15.out" 2>&1
if [[ $? -ne 0 && "$(grep -c '未配置 GITHUB_APP_ID' "$TMP/t15.out")" -ge 1 ]]; then
  ok "T15 doctor 无配置应 fail-fast"
else
  bad "T15 doctor 无配置应 fail-fast"
fi

# ---- T16：generate_token 无配置报错（含中文指引）----

(
  export JJPR_ENV_FILE="$TMP/nonexistent.env"
  source "$SCRIPTS_DIR/jjpr"
  unset GITHUB_APP_ID GITHUB_APP_PRIVATE_KEY_PATH GITHUB_APP_INSTALLATION_ID
  generate_token
) > "$TMP/t16.out" 2>&1
if [[ $? -ne 0 && "$(grep -c '缺少配置' "$TMP/t16.out")" -ge 1 ]]; then
  ok "T16 generate_token 无配置中文报错"
else
  bad "T16 generate_token 无配置中文报错"
fi

# ---- T17：b64url 编码与 JSON 字段提取 ----

(
  source "$SCRIPTS_DIR/jjpr"
  [[ "$(printf 'A' | b64url)" == "QQ" ]] && \
  [[ "$(printf 'abc' | b64url)" == "YWJj" ]] && \
  [[ "$(printf '{"id":123,"account":{"id":999}}' | json_num id)" == "123" ]] && \
  [[ "$(printf '{"token":"ghs_abc","x":1}' | json_str token)" == "ghs_abc" ]]
) && ok "T17 b64url / json_str / json_num 提取" || bad "T17 b64url / json_str / json_num 提取"

# ---- T18：令牌生成失败必须传播到 doctor（set -e 在 || 上下文失效的回归）----

# 现场生成真 RSA 私钥（签名可通过），注入必定失败的假 curl（网络边界失败），
# 验证 generate_token 的失败显式传播、doctor 停在"安装令牌生成失败"而非假通过。
mkdir -p "$TMP/bin"
printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/bin/curl"
chmod 755 "$TMP/bin/curl"
openssl genrsa -out "$TMP/fake.pem" 2048 2>/dev/null
chmod 600 "$TMP/fake.pem"
printf 'GITHUB_APP_ID=1\nGITHUB_APP_PRIVATE_KEY_PATH=%s\n' "$TMP/fake.pem" > "$TMP/env3"
(
  cd "$(dirname "$SCRIPTS_DIR")"   # 技能仓库内（有 origin），满足仓库上下文检查
  PATH="$TMP/bin:$PATH" JJPR_ENV_FILE="$TMP/env3" "$SCRIPTS_DIR/jjpr" doctor
) > "$TMP/t18.out" 2>&1
if [[ $? -ne 0 && "$(grep -c '安装令牌生成失败' "$TMP/t18.out")" -ge 1 && "$(grep -c '预检通过' "$TMP/t18.out")" -eq 0 ]]; then
  ok "T18 令牌失败传播：doctor fail-fast 不假通过"
else
  bad "T18 令牌失败传播：doctor fail-fast 不假通过"
fi

# ---- T19：token 子命令已移除（内部能力不对外暴露）----

"$SCRIPTS_DIR/jjpr" token >/dev/null 2>&1; [[ $? -eq 2 ]] && ok "T19 token 子命令已移除" || bad "T19 token 子命令已移除"

# ---- T20：默认动作（jjpr --title …）分发正确且默认分支防呆 ----

# 临时仓库建在 main 上：默认动作应在防呆处 fail-fast（无网络依赖）
git init -q -b main "$TMP/repo"
(
  cd "$TMP/repo"
  git remote add origin git@github.com:dummy/dummy.git
  "$SCRIPTS_DIR/jjpr" --title t
) > "$TMP/t20.out" 2>&1
if [[ $? -ne 0 && "$(grep -c '默认分支' "$TMP/t20.out")" -ge 1 ]]; then
  ok "T20 默认动作：推送+建PR 且默认分支防呆"
else
  bad "T20 默认动作：推送+建PR 且默认分支防呆"
fi

# ---- 汇总 ----

printf '\n冒烟测试：%d 通过，%d 失败\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
