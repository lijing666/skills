#!/usr/bin/env bash
# doc-chain-check.sh —— 文档链正主门禁（宪法第八节「落点自检/正主唯一」+「修订与批准有效性」的机械执法）
# 封堵目标：嵌套落点（changes/x/x/）、复制正主（副本承载状态）、副本伪批准（悬空 approved）
# 校验清单（唯一口径；跨平台兜底自编校验时不得增删项，fail-closed 语义不变）：
#   1. 嵌套检测：changes/ 下任意目录路径出现连续同名目录段（如 changes/x/x/）即失败
#      —— 仅查目录段；文件名含需求 ID（如 x-notes.md）不受限
#   2. 副本检测：同一需求 ID 的核心文档（prd*.md / spec.md / hld.md）出现在多个目录即失败
#      —— 含「活跃 + 归档」双位置并存（归档 = 移动非复制，残留即副本）
#   3. 悬空批准（仅活跃区；archive 为历史快照跳过）：spec/hld status ∈ {approved, implemented}
#      且同级存在 prd.md 时，prd.md status ≠ 已定稿即失败（免 PRD 的修复 Spec 无 prd.md，天然跳过）
#   4. 状态自洽（仅活跃区）：
#      a) hld status=approved 时「方案批准记录」表残留「待批准」行即失败；
#         status=draft 但批准表存在生效批准行（有效性列非待批准）即失败（旧批准冒充）
#      b) prd status=已定稿 且存在版本表节时，版本表最后一个表格行须含「定稿」
# 用法：doc-chain-check.sh <项目根> [--diff <基准>]
#   --diff <基准>：仅校验基准以来 diff 涉及的需求目录（CI 批量模式）；无开关全量校验
# 存量违例处置：项目接入体检时对账清理，清零前本门禁保持拦截（fail-closed）
set -u

FAIL=0
detail=""

fail() { FAIL=1; detail="${detail}FAIL: $1
"; }

ROOT="${1:-}"
DIFF_BASE=""
[ "${2:-}" = "--diff" ] && DIFF_BASE="${3:-}"

if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "用法: $0 <项目根> [--diff <基准commit>]" >&2
  exit 2
fi
cd "$ROOT" || exit 2

if [ ! -d "changes" ]; then
  echo "DOC-CHAIN PASS（无 changes/ 目录，无文档链）"
  exit 0
fi

# ── 校验 1：嵌套同名目录段（含 archive——结构非法永久非法）──
nested="$(find changes -type d | awk -F/ '{for(i=2;i<NF;i++) if($i==$(i+1)){print;break}}')"
[ -n "$nested" ] && fail "嵌套同名目录段（合法路径禁止连续同名目录段）:
$nested"

# ── 校验 2：副本检测（核心文档按 需求ID/文件名 对账，重复即副本）──
dupes="$(find changes \( -name 'prd*.md' -o -name 'spec.md' -o -name 'hld.md' \) -type f | awk -F/ '
{
  id=$2; f=$NF
  if(id=="archive"){ id=$3; sub(/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-/,"",id) }
  key=id"/"f
  if(!(key in cnt)){ cnt[key]=0; paths[key]="" }
  cnt[key]++
  paths[key]=paths[key]"\n  "$0
}
END { for(k in cnt) if(cnt[k]>1) printf "副本 %s x%d:%s\n", k, cnt[k], paths[k] }')"
[ -n "$dupes" ] && fail "同一需求 ID 的核心文档出现多份（正主唯一，副本承载的状态/批准无效）:$dupes"

# ── 校验 3+4：状态校验（仅活跃区；archive 历史快照跳过；--diff 时仅限涉及的需求）──
get_status() { sed -n '1,15p' "$1" 2>/dev/null | sed -n 's/^status:[[:space:]]*//p' | head -1; }

diff_ids=""
if [ -n "$DIFF_BASE" ]; then
  diff_ids="$(git diff --name-only "$DIFF_BASE" -- changes/ 2>/dev/null | sed -n 's|^changes/\([^/]*\)/.*|\1|p' | sort -u)"
fi

for req_dir in changes/*/; do
  [ -d "$req_dir" ] || continue
  id="$(basename "$req_dir")"
  [ "$id" = "archive" ] && continue
  if [ -n "$diff_ids" ] && ! printf '%s\n' "$diff_ids" | grep -qx "$id"; then
    continue
  fi

  prd="${req_dir}prd.md"; spec="${req_dir}spec.md"; hld="${req_dir}hld.md"
  prd_status=""
  [ -f "$prd" ] && prd_status="$(get_status "$prd")"

  # 3. 悬空批准：spec/hld 已批但正主 PRD 未定稿
  for doc in "$spec" "$hld"; do
    [ -f "$doc" ] || continue
    st="$(get_status "$doc")"
    if [ "$st" = "approved" ] || [ "$st" = "implemented" ]; then
      if [ -f "$prd" ] && [ "$prd_status" != "已定稿" ]; then
        fail "悬空批准: ${doc#changes/} status=$st 但正主 prd.md status=${prd_status:-（无）}（副本/未定稿来源的批准无效）"
      fi
    fi
  done

  # 4a. hld 批准表自洽
  if [ -f "$hld" ]; then
    hst="$(get_status "$hld")"
    if [ "$hst" = "approved" ]; then
      if sed -n '/^## 方案批准记录/,/^## /p' "$hld" | grep -q '待批准'; then
        fail "状态不自洽: ${hld#changes/} status=approved 但方案批准记录残留「待批准」行"
      fi
    elif [ "$hst" = "draft" ]; then
      if sed -n '/^## 方案批准记录/,/^## /p' "$hld" | grep -qE '\|[[:space:]]*有效([^性]|$)'; then
        fail "状态不自洽: ${hld#changes/} status=draft 但批准表存在生效批准行（旧批准冒充，批准失效应清表）"
      fi
    fi
  fi

  # 4b. prd 定稿与版本表一致
  if [ -f "$prd" ] && [ "$prd_status" = "已定稿" ]; then
    if grep -q '^## 版本' "$prd"; then
      last_row="$(sed -n '/^## 版本/,$p' "$prd" | grep '^|' | tail -1)"
      case "$last_row" in
        *定稿*) : ;;
        "") fail "状态不自洽: ${prd#changes/} status=已定稿 但版本表无表格行" ;;
        *) fail "状态不自洽: ${prd#changes/} status=已定稿 但版本表最新行无「定稿」" ;;
      esac
    fi
  fi
done

if [ "$FAIL" -eq 1 ]; then
  printf '%s' "$detail"
  echo "DOC-CHAIN FAIL"
  exit 1
fi
echo "DOC-CHAIN PASS（嵌套/副本/悬空批准/状态自洽 四项全绿）"
exit 0
