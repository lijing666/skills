#!/usr/bin/env bash
# task-done-gate.sh — done 语义门禁(jjspec 物料:任务卡状态机 执法层)
#
# 职责:校验 status=done 的卡真的满足 done 语义,禁止"我认为完成了"式降级。
#   背景(实战教训):AI 把 done 语义从"验收逐项有证据"降级为"测试全绿",高风险卡 100% 人审被越过
#   直接标 done、"31 页冒烟"先标 done 后补证据、验收被一行汇总 stamp 填平——done 书写权在 AI 手里,
#   且没有任何东西校验 done 意味着什么,本脚本补上这个校验。
#
# 裁决口径(全部 fail-closed;仅深查 status=done 的卡,其余状态为合法中间态跳过):
#   ① 「## 验收」节存在且非空
#   ② 验收逐条证据:每条 `- ` 条目须含"证据:"或"证据："标记——无证据条目逐一列出
#      (格式约定见 taskcard-template ## 验收 节:`- <验收项>(AC-x) → 证据:<命令/结果/引用>`)
#   ③ spec_ac 全覆盖:spec: 指向 Spec 声明的每个 AC 编号必须在验收节条目文本中出现
#      (防验收清单漏 AC——声明了要负责的验收对象,验收节里却找不到)
#   ④ risk: high 必须有人审通过记录(约定登记于验收证据:"人审通过 <日期> 批准人<X>")
#   ⑤ 页面卡(ui_source_page 非空)的执行进度 ui-gate 行必须非空且非"待执行"
#      (ui-gate:待执行 + status:done = 后门组合,直接拦截)
#
# 用法:
#   task-done-gate.sh <task卡路径>            # 单卡模式——置 done 前自查
#   task-done-gate.sh --diff <base_ref> [changes_dir]   # 批量模式——CI 在场卡对账打回
#
# 配套:taskcard-template.md(status 枚举含 review;## 验收 节格式;拆卡规则 5 高风险卡状态机)
# author: 李晶
set -euo pipefail

# ---------- 参数解析(与 page-excerpt-check 同构) ----------
DIFF_MODE=0
BASE=""
CHANGES="changes"
if [ "${1:-}" = "--diff" ]; then
  DIFF_MODE=1
  shift
  BASE="${1:?用法: task-done-gate.sh --diff <base_ref> [changes_dir]}"
  shift
  [ $# -gt 0 ] && CHANGES="${1}" && shift
  [ $# -gt 0 ] && { echo "❌ 未知参数:${1}" >&2; exit 1; }
else
  CARD_ARG="${1:?用法: task-done-gate.sh <task卡路径> | --diff <base_ref> [changes_dir]}"
fi

# ---------- 通用解析函数 ----------

# fm <卡文件> <frontmatter键> — 提取 YAML frontmatter 单值,去首尾空白
fm() {
  awk -v k="${2}" '
    /^---$/{c++; next}
    c==1 && index($0, k":") == 1 { sub("^" k ":[[:space:]]*", ""); print; exit }
    c>=2 { exit }
  ' "${1}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# section <文件> <##标题> — 提取指定二级节正文(至下一个 ## 为止)
section() {
  awk -v t="${2}" '
    $0 == "## " t { f=1; next }
    /^## / && f { exit }
    f { print }
  ' "${1}"
}

# list_items <节内容文件> — 输出节内平级列表条目(剥 "- " 前缀)
list_items() {
  grep "^- " "${1}" | sed 's/^- //' || true
}

# check_one_card <卡文件> — 单卡裁决;FAIL 输出明细并置 FAILED=1;非 done 状态合法跳过
check_one_card() {
  local card="${1}"

  # 仅深查 done;pending/in_progress/blocked/review 是合法中间态(review=待人审,不得越过)
  local status
  status="$(fm "${card}" status)"
  if [ "${status}" != "done" ]; then
    echo "  ↷ 跳过非 done 卡(status=${status:-<未声明>}):${card}"
    return 0
  fi

  local failed=0

  # ① 验收节存在且非空
  section "${card}" "验收" > "${SEC_TMP}"
  if [ ! -s "${SEC_TMP}" ] || [ -z "$(list_items "${SEC_TMP}")" ]; then
    echo "🚫 ${card}:status=done 但「## 验收」节缺失或无条目——done 语义=验收逐项有证据,fail-closed" >&2
    FAILED=1; return 0
  fi

  # ② 验收逐条证据:无"证据"标记的条目逐一列出
  local missing=""
  while IFS= read -r item; do
    [ -z "${item}" ] && continue
    if ! grep -qE "证据[::]" <<< "${item}"; then
      missing+=$'\n'"   无证据:${item}"
    fi
  done < <(list_items "${SEC_TMP}")
  if [ -n "${missing}" ]; then
    echo "🚫 ${card}:验收条目缺逐条证据(禁止'测试全绿'一行汇总替代逐条对照):${missing}" >&2
    failed=1
  fi

  # ③ spec_ac 全覆盖:Spec 声明的每个 AC 须在验收节出现(先核 Spec 文件存在,与 ac-coverage 同口径)
  local spec_rel spec_ac ac
  spec_rel="$(fm "${card}" spec)"
  spec_ac="$(fm "${card}" spec_ac)"
  spec_ac="${spec_ac//[/}"; spec_ac="${spec_ac//]/}"; spec_ac="${spec_ac// /}"
  if [ -n "${spec_ac}" ]; then
    if [ -z "${spec_rel}" ] || [ ! -f "${spec_rel}" ]; then
      echo "🚫 ${card}:status=done 但 spec: 缺失或文件不存在(当前:${spec_rel:-<未声明>})——AC 覆盖无从核验,fail-closed" >&2
      failed=1
    else
      IFS=',' read -r -a ACS <<< "${spec_ac}"
      for ac in "${ACS[@]}"; do
        [ -z "${ac}" ] && continue
        if ! grep -qF -- "${ac}" "${SEC_TMP}"; then
          echo "🚫 ${card}:spec_ac 声明的 ${ac} 未出现在「## 验收」节——验收清单漏 AC,fail-closed" >&2
          failed=1
        fi
      done
    fi
  fi

  # ④ risk: high → 人审通过记录(登记于验收证据:人审通过 <日期> 批准人<X>)
  local risk
  risk="$(fm "${card}" risk)"
  if [ "${risk}" = "high" ] && ! grep -q "人审通过" "${SEC_TMP}"; then
    echo "🚫 ${card}:risk: high 卡 status=done 但验收节无『人审通过 <日期> 批准人<X>』记录——100% 人审被越过,fail-closed" >&2
    failed=1
  fi

  # ⑤ 页面卡 ui-gate 内容判据:非待执行 + 视觉验收证据三要素 + 路线感知字样收紧
  #    (防两类漂移:①验收器漂移——以现成且必过的检查顶替视觉验收,如"目测检查通过/自查通过";
  #     ②路线谎报——HTML 路线卡谎报"结构化断言"绕过 pixel-diff 证据。路线由页面规格 source_anchor
  #     判定(.html→html;含 figma→figma;页面不可读→unknown 宽松双字样兜底),谎报从"人审兜"变机械拦截;
  #     格式正源 = taskcard-template ui-gate 行)
  local usp ugate
  usp="$(fm "${card}" ui_source_page)"
  if [ -n "${usp}" ]; then
    ugate="$(section "${card}" "执行进度" | grep "^- ui-gate:" | head -1 | sed 's/^- ui-gate:[[:space:]]*//')"
    if [ -z "${ugate}" ] || grep -q "待执行" <<< "${ugate}"; then
      echo "🚫 ${card}:页面卡 status=done 但 ui-gate 未执行(当前:${ugate:-<缺行>})——'待执行 + done'后门组合,拦截" >&2
      failed=1
    else
      # 路线判定:取首个页面规格的 source_anchor(页面文件存在性/指针有效性由 page-excerpt-check 执法,不重复)
      local route="unknown" first_page anchor
      first_page="${usp%%,*}"; first_page="${first_page//[[:space:]]/}"
      if [ -f "${first_page}" ]; then
        anchor="$(fm "${first_page}" source_anchor)"
        case "${anchor}" in
          *.html*|*.HTML*) route="html" ;;
          *figma*|*Figma*|*FIGMA*) route="figma" ;;
        esac
      fi
      local has_pd has_assert has_num has_pass
      has_pd="$(grep -qi "pixel-diff" <<< "${ugate}" && echo 1 || echo 0)"
      has_assert="$(grep -q "结构化断言" <<< "${ugate}" && echo 1 || echo 0)"
      has_num="$(grep -qE "[0-9]+(\.[0-9]+)?%|[0-9]+ */ *[0-9]+" <<< "${ugate}" && echo 1 || echo 0)"
      has_pass="$(grep -qi "PASS" <<< "${ugate}" && echo 1 || echo 0)"
      local route_ok=0 route_hint=""
      case "${route}" in
        html)  if [ "${has_pd}" = 1 ]; then route_ok=1; fi
               route_hint="HTML 路线(source_anchor 指向 .html 原型)须 pixel-diff 证据,结构化断言字样不适用——路线谎报拦截" ;;
        figma) if [ "${has_assert}" = 1 ]; then route_ok=1; fi
               route_hint="设计稿路线(source_anchor 指向 figma)须结构化断言证据,pixel-diff 字样不适用——路线谎报拦截" ;;
        *)     if [ "${has_pd}" = 1 ] || [ "${has_assert}" = 1 ]; then route_ok=1; fi
               route_hint="路线未判出(页面文件不可读),按双字样宽松判据" ;;
      esac
      if [ "${route_ok}" = 0 ] || [ "${has_num}" = 0 ] || [ "${has_pass}" = 0 ]; then
        echo "🚫 ${card}:ui-gate 视觉验收证据不合规——${route_hint}。" >&2
        echo "   当前:「${ugate}」。三要素 = 路线对应字样 + 差异或 n/m 数字 + PASS;禁止以摘录对账/测试绿/目测顶替,缺能力即停止上报" >&2
        failed=1
      fi
    fi
  fi

  [ "${failed}" -eq 1 ] && { FAILED=1; return 0; }
  echo "  ✅ ${card}:done 语义校验通过(逐条证据 + AC 覆盖 + 人审记录 + ui-gate)"
}

# ---------- 模式分派 ----------
FAILED=0
TMPDIR_WORK="$(mktemp -d)"
SEC_TMP="${TMPDIR_WORK}/sec"
trap 'rm -rf "${TMPDIR_WORK}"' EXIT

if [ "${DIFF_MODE}" -eq 0 ]; then
  if [ ! -f "${CARD_ARG}" ]; then
    echo "❌ 卡文件不存在:${CARD_ARG}" >&2; exit 1
  fi
  echo "── task-done-gate 单卡模式:${CARD_ARG}"
  check_one_card "${CARD_ARG}"
else
  DIFF_FILES="$(mktemp)"
  trap 'rm -rf "${TMPDIR_WORK}" "${DIFF_FILES}"' EXIT
  if ! git -c core.quotepath=off diff --name-only --no-renames -z "${BASE}"...HEAD > "${DIFF_FILES}" 2>/dev/null; then
    echo "❌ done 语义校验未能执行:git diff 失败(基准 ${BASE} 是否存在?)" >&2; exit 1
  fi
  n=0
  while IFS= read -r -d '' f || [ -n "${f}" ]; do
    if [[ "${f}" =~ ^changes/[^/]+/tasks/TASK-[^/]*\.md$ ]] && [[ "${f}" != */archive/* ]] && [ -f "${f}" ]; then
      n=$((n+1))
      check_one_card "${f}"
    fi
  done < "${DIFF_FILES}"
  [ "${n}" -eq 0 ] && echo "  ↷ diff 中无在场任务卡,无需 done 语义校验"
fi

if [ "${FAILED}" -eq 1 ]; then
  echo "❌ done 语义校验不通过:存在虚假 done——验收逐项有证据才算完成,'我认为完成了'不算" >&2
  exit 1
fi
echo "✅ done 语义校验通过(逐条证据 + AC 覆盖 + 人审记录 + 页面卡 ui-gate;语义定义见 taskcard-template status 行)"
