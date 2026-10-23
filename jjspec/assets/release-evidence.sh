#!/usr/bin/env bash
# release-evidence.sh — 发布证据包聚合器(jjspec 物料:发布门/观测期拍板门的证据聚合 + 采集落点机械执法)
#
# 职责:把散落正源的机械证据聚合成一页,给人守发布门(⑧灰度开启前)与观测期拍板门(⑨到期)的人看。
#   全部从既有正源机械汇总,零新增填写:① AC 覆盖账本(spec+卡验收节) ② 高危卡强度(变异存活率行)
#   ③ 真实性(集成标记条目) ④ 观测声明对账(HLD 观测节完整性+采集落点认领=拆卡规则 10 机械对账)。
#   缺口显影:AC 无证据/无认领、高危卡缺变异行、观测节缺失或留白、落点无卡认领 → 进缺口清单。
#
# 落盘纪律:输出物是发布动作的一次性数据(贴 PR 描述/发布记录),不是台账——禁止长期登记(R0)。
#
# 用法:release-evidence.sh <需求目录> [--strict] [--out <文件>]
#   <需求目录>  必传;须含 spec.md(免 PRD 的修复 Spec 亦合法)与 tasks/(可选 hld.md)
#   --strict    门禁用法:有缺口 exit 1;缺省 = 报告工具,缺口显影但 exit 0
#   --out       写文件;缺省 stdout。退出码:0=成功且(非 strict 或无缺口);1=strict 有缺口;2=输入非法
# 配套:references/gates.md(发布证据包节);assets/AGENTS.md.template(integration-mark 块);
#       回归测试 release-evidence.test.sh
# author: 李晶
set -euo pipefail

DIR="${1:?用法: release-evidence.sh <需求目录> [--strict] [--out <文件>]}"
shift
STRICT=0 OUT=""
while [ $# -gt 0 ]; do
  case "${1}" in
    --strict) STRICT=1 ;;
    --out) shift; OUT="${1:?--out 需要文件参数}" ;;
    *) echo "❌ 未知参数:${1}" >&2; exit 2 ;;
  esac
  shift
done

if [ ! -d "${DIR}" ]; then echo "❌ 需求目录不存在:${DIR}" >&2; exit 2; fi
SPEC="${DIR}/spec.md"
if [ ! -f "${SPEC}" ]; then echo "❌ spec.md 缺失:${SPEC}——输入非法" >&2; exit 2; fi
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || ROOT="."
HLD="${DIR}/hld.md"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
section() { awk -v pat="${2}" '$0 ~ pat {f=1;next} /^## [^#]/ {f=0} f' "${1}"; }
fm() { awk -v k="${2}" '/^---$/{c++;next} c==1&&index($0,k":")==1{sub("^" k ":[[:space:]]*","");print;exit} c>=2{exit}' "${1}" | sed 's/[[:space:]]*$//'; }

find "${DIR}/tasks" -maxdepth 1 -name 'TASK-*.md' -type f 2>/dev/null | sort > "${WORK}/cards" || true
grep -oE 'AC-?[0-9]+' "${SPEC}" | sort -u > "${WORK}/acs" || true

INT_MARK=""
AGENTS_MD="${ROOT}/AGENTS.md"
if [ -f "${AGENTS_MD}" ]; then
  _ib="$(sed -n '/integration-mark-begin/,/integration-mark-end/p' "${AGENTS_MD}")"
  INT_MARK="$(sed -n 's/^mark:[[:space:]]*//p' <<<"${_ib}" | head -1)"
fi

# 全部卡边界并集(采集落点认领用:被至少一张卡认领 = 命中并集;glob 口径同 boundary-check)
: > "${WORK}/bounds"
while IFS= read -r card; do
  [ -z "${card}" ] && continue
  { sed -n '/^[[:space:]]*```boundary[[:space:]]*$/,/^[[:space:]]*```[[:space:]]*$/p' "${card}" | sed '1d;$d' || true
    awk '/^## 边界/{f=1;next} /^## /{f=0} f&&/^- /{sub(/^- /,"");print}' "${card}" || true
  } >> "${WORK}/bounds" || true
done < "${WORK}/cards"
_g="$(mktemp)"; grep -vE '^[[:space:]]*(#|$)' "${WORK}/bounds" > "${_g}" || true; mv "${_g}" "${WORK}/bounds"

GAPS=0
gap() { echo "- ${1}"; GAPS=$((GAPS+1)); }
EV="${WORK}/evidence"

# ── ① AC 覆盖账本 ──
{
echo "# 发布证据包 — $(basename "${DIR}")"
echo "生成:$(date +%Y-%m-%d) | 聚合视图,非台账(贴 PR 描述/发布记录)"
echo ""
echo "## ① AC 覆盖账本"
if [ ! -s "${WORK}/acs" ]; then
  echo "⚠️ spec.md 未提取到 AC 编号——AC 是证据链源头"
  gap "[spec] 无 AC 定义(AC-?编号格式)"
else
  echo "| AC | 认领卡 | 验收证据 |"
  echo "|---|---|---|"
  while IFS= read -r ac; do
    [ -z "${ac}" ] && continue
    claim="—"; evid="✗"
    while IFS= read -r card; do
      [ -z "${card}" ] && continue
      sa="$(fm "${card}" spec_ac | tr -d '[] ')"
      if [[ ",${sa}," == *",${ac},"* || "${sa}" == "${ac}" ]]; then
        claim="$(basename "${card}")"
        if section "${card}" '^## 验收' | grep -qF "${ac}"; then evid="✓"; fi
        break
      fi
    done < "${WORK}/cards"
    echo "| ${ac} | ${claim} | ${evid} |"
    if [ "${claim}" = "—" ]; then gap "[${ac}] 无卡认领(task-dag-check 亦拦)"; fi
    if [ "${evid}" = "✗" ] && [ "${claim}" != "—" ]; then gap "[${ac}] 认领卡验收节无对应证据行"; fi
  done < "${WORK}/acs"
fi
echo ""
} >> "${EV}"

# ── ② 高危卡强度 ──
{
echo "## ② 高危卡断言强度"
n_high=0
while IFS= read -r card; do
  [ -z "${card}" ] && continue
  if [ "$(fm "${card}" risk)" = "high" ]; then
    n_high=$((n_high+1))
    mut="$(section "${card}" '^## 执行进度' | { grep -E '存活率|mutation-gate' || true; } | head -1)"
    echo "- $(basename "${card}"):变异报告 ${mut:-<缺失>}"
    if [ -z "${mut}" ]; then gap "[$(basename "${card}")] risk: high 卡缺变异存活率行(mutation-gate 未跑或未登记)"; fi
  fi
done < "${WORK}/cards"
if [ "${n_high}" -eq 0 ]; then echo "- 无 risk: high 卡"; fi
echo ""
} >> "${EV}"

# ── ③ 真实性 ──
{
echo "## ③ 真实性(集成测试)"
if [ -z "${INT_MARK}" ]; then
  echo "- 集成标记未登记(AGENTS.md integration-mark 块)——真实性执法未启用,缺口显式留痕"
else
  echo "- 登记标记:${INT_MARK}"
  cat "${WORK}/cards" | while IFS= read -r c; do
    awk '/^## 测试文件清单/{f=1;next} /^## /{f=0} f&&/^- /{sub(/^- /,"");sub(/[[:space:]]+$/,"");print}' "${c}"
  done > "${WORK}/tentries" || true
  found=0
  while IFS= read -r entry; do
    [ -z "${entry}" ] && continue
    p="${entry%%::*}"
    if [ -f "${p}" ] && grep -qF -- "${INT_MARK}" "${p}"; then
      echo "- ${p}"
      found=$((found+1))
    fi
  done < "${WORK}/tentries"
  if [ "${found}" -eq 0 ]; then echo "- (无集成标记条目——risk: high 行为卡在场时 ac-coverage --integration-mark 会拦)"; fi
fi
echo ""
} >> "${EV}"

# ── ④ 观测声明对账 + 采集落点机械执法 ──
{
echo "## ④ 观测声明对账"
if [ ! -f "${HLD}" ]; then
  echo "- HLD 缺失"
  gap "[观测] hld.md 缺失——观测声明与开关策略无从对账"
else
  section "${HLD}" '观测与灰度声明' > "${WORK}/obs" || true
  if [ ! -s "${WORK}/obs" ]; then
    echo "- 观测与灰度声明节缺失"
    gap "[观测] HLD 无「观测与灰度声明」节"
  else
    _resp="$(sed -n 's/^- 负责人[：:]//p' "${WORK}/obs" | head -1)"
    _end="$(sed -n 's/^- 结束条件[：:]//p' "${WORK}/obs" | head -1)"
    echo "- 负责人:${_resp:-<缺失>}"
    echo "- 结束条件:${_end:-<缺失>}"
    if [ -z "${_resp}" ]; then gap "[观测] 缺「负责人」行(转正/回滚拍板人)"; fi
    if [ -z "${_end}" ]; then gap "[观测] 缺「结束条件」行(转正/回滚判据)"; fi
    # 采集落点列(指标表第 3 列),剔表头/占位/空
    awk -F'|' '/^\|/ {v=$4; gsub(/[[:space:]]/,"",v); if (v!="" && v!~/^(-+|—+|采集落点)$/) print v}' "${WORK}/obs" > "${WORK}/spots" || true
    while IFS= read -r spot; do
      [ -z "${spot}" ] && continue
      hit="未认领 ✗"
      while IFS= read -r g; do
        # shellcheck disable=SC2254
        case "${spot}" in ${g}) hit="✓"; break ;; esac
      done < "${WORK}/bounds"
      echo "- 采集落点 ${spot} → ${hit}"
      if [[ "${hit}" == 未认领* ]]; then gap "[观测] 采集落点 ${spot} 无卡边界认领(拆卡规则 10——埋点文件不在任何卡内 = 指标是装饰品)"; fi
    done < "${WORK}/spots"
  fi
fi
echo ""
} >> "${EV}"

# ── ⑤ 开关与灰度 + 缺口清单 ──
{
echo "## ⑤ 开关与灰度"
if [ -f "${HLD}" ]; then
  section "${HLD}" '开关与灰度策略' | head -3 | sed 's/^/  /' || true
else
  echo "  (HLD 缺失,见缺口)"
fi
echo ""
echo "## 缺口清单"
if [ "${GAPS}" -eq 0 ]; then
  echo "无——证据链完整(AC 覆盖/强度/真实性/观测声明对账均闭合)"
else
  echo "共 ${GAPS} 项缺口,逐条见上"
fi
} >> "${EV}"

# ── 输出与判定 ──
if [ -n "${OUT}" ]; then
  cp "${EV}" "${OUT}"
  echo "证据包已写入:${OUT}"
else
  cat "${EV}"
fi

if [ "${STRICT}" -eq 1 ] && [ "${GAPS}" -gt 0 ]; then
  echo "❌ 发布证据包存在 ${GAPS} 项缺口(--strict)——灰度开启前须闭合或显式豁免" >&2
  exit 1
fi
echo "✅ 证据包生成完成(缺口 ${GAPS} 项)"
