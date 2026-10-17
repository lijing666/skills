#!/usr/bin/env bash
# ui-pack-check.sh — UI 规范包资产完整性门禁（fail-closed）
# 执行前提：bash（macOS/Linux 原生；Windows 用 Git Bash 或 WSL 执行同一脚本，零改动）。
# 跨平台口径：下方「校验」清单是本门禁语义的唯一正源——确无 bash 环境时，可在会话内据此自编
#   一次性等价校验（不得增删检查项、fail-closed 语义不变、逐项对账输出、禁入库禁提交）。
# 用法：ui-pack-check.sh <ui-specs/<产品ID>-<业务大项>> [--require-digest [all | p-<两位序号>]]
#   --require-digest      页面消化门槛（页面卡开工前置，见 taskcard-template 拆卡规则 8）：
#                         不带值 = 全部页须 digest: quantified；带 p-<序号> = 仅校验指定页
#   （不带该开关时行为与旧版完全兼容）
# 校验（任一失败即退出 1 并逐条列明；全部通过输出 UI-PACK PASS）：
#   1. README.md 存在，且含「## 资产类别登记」节
#   2. 资产类别登记表 15 类封闭齐全：颜色/字号/字重/行高/字体族/间距/圆角/边框/阴影/透明度/渐变/布局/动效/图标/位图素材
#      处置 ∈ {token化, icons.json, assets, 无}；「无」必须写理由；「图标」必须为 icons.json；
#      「位图素材」∈ {assets, 无}；任何处置=assets 的类须 assets/assets.md 存在、assets/ 有文件、清单无未处置条目
#   3. tokens 文件恰好 1 个（css/scss/json）
#   4. icons/icons.json 存在且为合法 JSON（HTML 与设计稿路线均必须产出）
#   5. pages/p-<两位序号>-<短名>.md 存在：编号自 01 连续、无重号；短名须英文 kebab-case（宪法第九节第 10 条）；
#      每页含 source_anchor 视觉输入锚点
#   6. （启用 --require-digest 时）指定页面的 frontmatter 含 digest: quantified，
#      且页面含「## 节点样式量化表」段落（quantified 的强制载体，缺段按清单级拦截）
set -uo pipefail

DIR="${1:-}"
REQUIRE_DIGEST=""
if [ "${2:-}" = "--require-digest" ]; then
  REQUIRE_DIGEST="${3:-all}"
fi
FAILS=()
fail() { FAILS+=("$1"); }

[ -n "${DIR}" ] && [ -d "${DIR}" ] || { echo "用法: ui-pack-check.sh <ui-spec 目录>"; exit 2; }
[ -f "${DIR}/README.md" ] || fail "缺 README.md"

# ── 1) tokens 文件唯一 ──
tok_count=$(find "${DIR}" -maxdepth 1 -name 'tokens.*' -type f | grep -c . || true)
[ "${tok_count}" = "1" ] || fail "tokens 文件须恰好 1 个（css/scss/json），实得 ${tok_count} 个"

# ── 2) icons/icons.json 存在且合法 ──
if [ ! -f "${DIR}/icons/icons.json" ]; then
  fail "缺 icons/icons.json（HTML 与设计稿路线均必须产出图标封闭清单）"
elif ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "${DIR}/icons/icons.json" 2>/dev/null; then
  fail "icons/icons.json 不是合法 JSON"
fi

# ── 3) 资产类别登记表：15 类封闭，每类一行 ──
CATEGORIES=(颜色 字号 字重 行高 字体族 间距 圆角 边框 阴影 透明度 渐变 布局 动效 图标 位图素材)
if ! grep -q '^## 资产类别登记' "${DIR}/README.md" 2>/dev/null; then
  fail "README.md 缺「## 资产类别登记」节"
fi
for cat in "${CATEGORIES[@]}"; do
  row="$(grep -E "^\|[[:space:]]*${cat}[[:space:]]*\|" "${DIR}/README.md" 2>/dev/null | head -1)"
  if [ -z "${row}" ]; then
    fail "资产类别登记缺「${cat}」行（封闭清单禁止省略；无值填「无 + 理由」）"
    continue
  fi
  handle="$(printf '%s' "${row}" | awk -F'|' '{gsub(/[[:space:]]/,"",$3); print $3}')"
  note="$(printf '%s' "${row}" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$4); print $4}')"
  case "${handle}" in
    token化|icons.json|assets|无) ;;
    *) fail "「${cat}」处置非法: ${handle:-空}（允许 token化/icons.json/assets/无）" ;;
  esac
  if [ "${handle}" = "无" ] && [ -z "${note}" ]; then
    fail "「${cat}」处置为「无」但未写理由"
  fi
  if [ "${cat}" = "图标" ] && [ "${handle}" != "icons.json" ]; then
    fail "「图标」行处置须为 icons.json"
  fi
  if [ "${cat}" = "位图素材" ] && [ "${handle}" != "assets" ] && [ "${handle}" != "无" ]; then
    fail "「位图素材」处置仅允许 assets 或 无"
  fi
  # 处置=assets 的通用检查（位图素材、字体族等媒体资产）：assets.md 存在、清单无未终态条目、目录有资产文件
  if [ "${handle}" = "assets" ]; then
    [ -f "${DIR}/assets/assets.md" ] || fail "「${cat}」处置=assets 但缺 assets/assets.md 素材清单"
    if [ -f "${DIR}/assets/assets.md" ]; then
      bad="$(grep -E '^\|' "${DIR}/assets/assets.md" 2>/dev/null \
        | grep -vE '^\|[[:space:]]*文件[[:space:]]*\||^\|[[:space:]]*-' \
        | awk -F'|' '{v=$(NF-1); gsub(/[[:space:]]/,"",v); if(v!="" && v!="已导出" && v!="豁免" && v!="人工补录") print v}' \
        | sort -u | tr '\n' ' ')"
      [ -z "${bad}" ] || fail "assets.md 存在未终态处置条目: ${bad}（处置仅允许 已导出/豁免/人工补录）"
    fi
    if [ -z "$(find "${DIR}/assets" -type f ! -name 'assets.md' -print -quit 2>/dev/null)" ]; then
      fail "「${cat}」处置=assets 但 assets/ 无资产文件"
    fi
  fi
done

# ── 4) 页面规格：编号连续无重号；每页含 source_anchor ──
shopt -s nullglob
pages=("${DIR}"/pages/p-*.md)
shopt -u nullglob
[ ${#pages[@]} -gt 0 ] || fail "pages/ 无 p-*.md 页面规格"
nums=()
for p in "${pages[@]}"; do
  base="$(basename "${p}")"
  n="$(printf '%s' "${base}" | sed -E 's/^p-0*([0-9]+)-.*/\1/')"
  if [ "${n}" = "${base}" ]; then
    fail "页面文件名不符合 p-<序号>-<短名>.md: ${base}"
  else
    nums+=("${n}")
  fi
  if ! printf '%s' "${base}" | grep -qE '^p-[0-9]{2}-[a-z0-9][a-z0-9-]*\.md$'; then
    fail "页面短名须英文 kebab-case（p-<两位序号>-<英文短名>.md，宪法第九节第 10 条）: ${base}"
  fi
  grep -q 'source_anchor' "${p}" || fail "${base} 缺 source_anchor 视觉输入锚点"

  # ── 6) 页面消化门槛（仅 --require-digest 启用时）──
  if [ -n "${REQUIRE_DIGEST}" ]; then
    page_no="$(printf '%s' "${n}")"
    need_check=1
    if [ "${REQUIRE_DIGEST}" != "all" ]; then
      want_no="$(printf '%s' "${REQUIRE_DIGEST}" | sed -E 's/^p-0*([0-9]+)/\1/')"
      [ "${page_no}" = "${want_no}" ] || need_check=0
    fi
    if [ "${need_check}" -eq 1 ]; then
      digest="$(awk 'NR==1&&/^---[[:space:]]*\r?$/{fm=1;next} fm&&/^---[[:space:]]*\r?$/{exit} fm&&/^digest:/{sub(/^digest:[[:space:]]*/,"");gsub(/\r$/,"");print;exit}' "${p}")"
      if [ "${digest}" != "quantified" ]; then
        fail "${base} 页面消化门槛未过：digest=${digest:-<缺失>}（页面卡开工须 quantified；清单级页先补逐项量化）"
      elif ! grep -q '^## 节点样式量化表' "${p}"; then
        fail "${base} digest=quantified 但缺「## 节点样式量化表」段落（逐节点量化载体，见 ui-spec-guide）——按清单级处理，补量化后再标 quantified"
      fi
    fi
  fi
done
if [ ${#nums[@]} -gt 0 ]; then
  dups="$(printf '%s\n' "${nums[@]}" | sort -n | uniq -d)"
  [ -z "${dups}" ] || fail "页面编号重复: $(printf '%s ' ${dups})"
  gap="$(printf '%s\n' "${nums[@]}" | sort -n | awk 'NR!=$1{print "期望 "NR"，实得 "$1; exit}')"
  [ -z "${gap}" ] || fail "页面编号跳号: ${gap}"
fi

# ── 结果 ──
if [ ${#FAILS[@]} -gt 0 ]; then
  echo "UI-PACK FAIL（${#FAILS[@]} 项）:"
  printf '  - %s\n' "${FAILS[@]}"
  exit 1
fi
echo "UI-PACK PASS: ${DIR}"
exit 0
