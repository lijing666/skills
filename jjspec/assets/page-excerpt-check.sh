#!/usr/bin/env bash
# page-excerpt-check.sh — UI 规格摘录门禁(jjspec 物料:页面卡厚规格对照开发 执法层)
#
# 职责:验证页面卡「## UI 规格摘录」节 = 真实转抄(执行动作),而非模板填空/规则文字占位。
#   背景(实战教训):执行 AI 把门槛②的规则文字原样抄进摘录节("开工门槛执行:两页全量摘录"),
#   实际未读页面规格自由发挥搭骨架,视觉保真被降级为后置验收——本脚本把"完成"从声明式改机械式。
#
# 裁决口径(全部 fail-closed:解析不了/对不上 = 不通过):
#   ① 页面卡(frontmatter 含 ui_source_page)必须有「## UI 规格摘录」节,缺失 = FAIL
#   ② 五个标签块齐全:节点样式摘录/布局语义摘录/静态文案摘录/九态映射/摘录覆盖率
#   ③ 占位检测:「摘录覆盖率」登记行 N/M 必须为纯数字(模板占位符 <摘录条数> 解析即失败)
#   ④ N=M 严格对账(核心):N_declared == N_actual == M_actual == M_declared
#      - N_actual = 摘录节「节点样式摘录」块下的条目行数(一行一节点)
#      - M_actual = ui_source_page 各页「## 节点样式量化表」数据行数之和(表格行 - 表头 - 分隔行)
#      - 一行说明句 vs 量化表数十节点 → 对账必穿帮,占位无处遁形
#   ⑤ 布局语义/静态文案/九态映射三块非空(全量性对账待文案清单格式稳定后扩展,见 TODO)
#   ⑥ ui_source_page 指向的页面文件必须存在(指针悬空 = FAIL);多页逗号/空格分隔,M 求和
#
# 转抄格式约定(与 taskcard-template 摘录节占位符一致,解析依赖此结构):
#   - 标签行保留作为分块锚点(- 节点样式摘录(逐节点全量): / - 布局语义摘录(逐条): /
#     - 静态文案摘录(逐条): / - 九态映射: / - 摘录覆盖率:N=<数字> / M=<数字>)
#   - 各标签行下平级 `- ` 条目,一行一节点/一条;登记行固定节尾
#
# 用法:
#   page-excerpt-check.sh <task卡路径>            # 单卡模式——开工前自查(不通过不得写第一行代码)
#   page-excerpt-check.sh --diff <base_ref> [changes_dir]  # 批量模式——CI 在场卡(diff 新建/修改)对账打回
#
# 配套:taskcard-template.md(## UI 规格摘录 转抄格式 + 门槛②);ui-pack-check.sh(--require-digest 管规范包侧)
# author: 李晶
set -euo pipefail

# ---------- 参数解析 ----------
DIFF_MODE=0
BASE=""
CHANGES="changes"
if [ "${1:-}" = "--diff" ]; then
  DIFF_MODE=1
  shift
  BASE="${1:?用法: page-excerpt-check.sh --diff <base_ref> [changes_dir]}"
  shift
  [ $# -gt 0 ] && CHANGES="${1}" && shift
  [ $# -gt 0 ] && { echo "❌ 未知参数:${1}" >&2; exit 1; }
else
  CARD_ARG="${1:?用法: page-excerpt-check.sh <task卡路径> | --diff <base_ref> [changes_dir]}"
fi

# ---------- 通用解析函数(带函数级注释) ----------

# fm <卡文件> <frontmatter键> — 提取 YAML frontmatter 单值(第一段 --- 内首个匹配键),去首尾空白
fm() {
  awk -v k="${2}" '
    /^---$/{c++; next}
    c==1 && index($0, k":") == 1 { sub("^" k ":[[:space:]]*", ""); print; exit }
    c>=2 { exit }
  ' "${1}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# section <文件> <##标题> — 提取指定二级节正文(至下一个 ## 为止),供块解析
section() {
  awk -v t="${2}" '
    $0 == "## " t { f=1; next }
    /^## / && f { exit }
    f { print }
  ' "${1}"
}

# count_quant_rows <页面文件> — 数「## 节点样式量化表」段的数据行数(表格行-表头-分隔行)
#   口径:仅 ^| 行;首行=表头,匹配 ^|[- :|]+|$ 的行为分隔行;其余 ^| 行均计数据行(容错缺分隔行)
count_quant_rows() {
  section "${1}" "节点样式量化表" | awk '
    /^\|/ {
      n++
      if (n == 1) next                     # 表头
      if ($0 ~ /^\|[- :|]+\|$/) next       # 分隔行
      c++
    }
    END { print c + 0 }
  '
}

# count_excerpt_items <摘录节文件> <块标签前缀> — 数指定块标签行之后的平级条目行数(- 开头,非标签行)
#   标签行即分块锚点;条目 = 进入该块后遇到的 - 行,遇下一个标签行切换归属
count_excerpt_items() {
  awk -v tag="${2}" '
    {
      line=$0
      is_tag = 0
      if (line ~ /^- 节点样式摘录/)      { cur="ns"; is_tag=1 }
      else if (line ~ /^- 布局语义摘录/) { cur="lay"; is_tag=1 }
      else if (line ~ /^- 静态文案摘录/) { cur="copy"; is_tag=1 }
      else if (line ~ /^- 九态映射/)     { cur="st"; is_tag=1 }
      else if (line ~ /^- 摘录覆盖率/)   { cur="cover"; is_tag=1 }
      if (is_tag) state = (line ~ ("^- " tag)) ? 1 : 0
      else if (state && line ~ /^- /) c++
    }
    END { print c + 0 }
  ' "${1}"
}

# block_nonempty <摘录节文件> <块标签前缀> — 判定块下是否至少 1 条条目
block_nonempty() {
  [ "$(count_excerpt_items "${1}" "${2}")" -ge 1 ]
}

# check_one_card <卡文件> — 单卡裁决;FAIL 时输出明细并置全局 FAILED=1
check_one_card() {
  local card="${1}"

  # 页面卡识别:非页面卡(ui_source_page 未声明)直接跳过,不算失败
  local usp
  usp="$(fm "${card}" ui_source_page)"
  if [ -z "${usp}" ]; then
    echo "  ↷ 跳过非页面卡(未声明 ui_source_page):${card}"
    return 0
  fi

  local failed=0
  local reason=""

  # ① 摘录节存在性
  section "${card}" "UI 规格摘录" > "${SEC_TMP}"
  if [ ! -s "${SEC_TMP}" ]; then
    echo "🚫 ${card}:页面卡缺「## UI 规格摘录」节——厚规格对照开发无载体,fail-closed" >&2
    FAILED=1; return 0
  fi

  # ② 五标签块齐全性
  for tag in "节点样式摘录" "布局语义摘录" "静态文案摘录" "九态映射" "摘录覆盖率"; do
    if ! grep -q "^- ${tag}" "${SEC_TMP}"; then
      reason+="\n   缺标签块「${tag}」(转抄格式见 taskcard-template 摘录节)"
    fi
  done
  if [ -n "${reason}" ]; then
    echo "🚫 ${card}:摘录节结构不完整:${reason}" >&2
    FAILED=1; return 0
  fi

  # ③ 登记行数值解析(占位符 <摘录条数> 在此暴露:非纯数字 = 模板填空)
  local decl
  decl="$(grep "^- 摘录覆盖率" "${SEC_TMP}" | head -1)"
  local nd md
  nd="$(grep -oE 'N=[0-9]+' <<< "${decl}" | head -1 | grep -oE '[0-9]+' || true)"
  md="$(grep -oE 'M=[0-9]+' <<< "${decl}" | head -1 | grep -oE '[0-9]+' || true)"
  if [ -z "${nd}" ] || [ -z "${md}" ]; then
    echo "🚫 ${card}:「摘录覆盖率」登记行非纯数字 N/M(当前:「${decl}」)——模板占位未替换/未真实转抄,fail-closed" >&2
    FAILED=1; return 0
  fi

  # ④ N=M 严格对账
  local n_actual m_actual page pages="${usp}" m_sum=0
  n_actual="$(count_excerpt_items "${SEC_TMP}" "节点样式摘录")"
  IFS=', ' read -r -a PGLIST <<< "${pages}"
  for page in "${PGLIST[@]}"; do
    [ -z "${page}" ] && continue
    if [ ! -f "${page}" ]; then
      echo "🚫 ${card}:ui_source_page 指向的页面文件不存在:${page}——指针悬空,fail-closed" >&2
      FAILED=1; return 0
    fi
    m_sum=$(( m_sum + $(count_quant_rows "${page}") ))
  done
  m_actual="${m_sum}"
  if [ "${nd}" -ne "${n_actual}" ] || [ "${md}" -ne "${m_actual}" ] || [ "${n_actual}" -ne "${m_actual}" ]; then
    echo "🚫 ${card}:N=M 严格对账失败——登记 N=${nd}/M=${md},实际节点样式条目 N=${n_actual},页面量化表节点 M=${m_actual}。" >&2
    echo "   摘录 = 执行动作非模板填空:必须实际转抄 ui_source_page 三表,禁止抄规则文字/说明句占位" >&2
    FAILED=1; return 0
  fi

  # ⑤ 其余三块非空(全量性对账 TODO:布局语义表/文案清单格式稳定后扩为逐段 N=M)
  for tag in "布局语义摘录" "静态文案摘录" "九态映射"; do
    if ! block_nonempty "${SEC_TMP}" "${tag}"; then
      echo "🚫 ${card}:「${tag}」块为空——逐条转抄要求落空,fail-closed" >&2
      failed=1
    fi
  done
  [ "${failed}" -eq 1 ] && { FAILED=1; return 0; }

  echo "  ✅ ${card}:摘录对账通过 N=${n_actual}=M=${m_actual}(登记一致,严格相等)"
}

# ---------- 模式分派 ----------

FAILED=0
TMPDIR_WORK="$(mktemp -d)"
SEC_TMP="${TMPDIR_WORK}/sec"
trap 'rm -rf "${TMPDIR_WORK}"' EXIT

if [ "${DIFF_MODE}" -eq 0 ]; then
  # 单卡模式:定位仓库根解析 ui_source_page 相对路径;卡必须存在于 git 仓库(fail-closed)
  if [ ! -f "${CARD_ARG}" ]; then
    echo "❌ 卡文件不存在:${CARD_ARG}" >&2; exit 1
  fi
  CARD_ABS="$(cd "$(dirname "${CARD_ARG}")" && pwd)/$(basename "${CARD_ARG}")"
  REPO_ROOT="$(git -C "$(dirname "${CARD_ABS}")" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "❌ 卡不在 git 仓库内,无法解析 ui_source_page 相对路径:${CARD_ARG}" >&2; exit 1
  }
  cd "${REPO_ROOT}"
  REL_CARD="$(python3 -c "import os,sys;print(os.path.relpath(sys.argv[1],sys.argv[2]))" "${CARD_ABS}" "${REPO_ROOT}")"
  echo "── page-excerpt-check 单卡模式:${REL_CARD}"
  check_one_card "${REL_CARD}"
else
  # 批量模式:diff 找在场卡(与 ac-coverage-check 同口径:changes/**/tasks/TASK-*.md,排除 archive)
  DIFF_FILES="$(mktemp)"
  trap 'rm -rf "${TMPDIR_WORK}" "${DIFF_FILES}"' EXIT
  if ! git -c core.quotepath=off diff --name-only --no-renames -z "${BASE}"...HEAD > "${DIFF_FILES}" 2>/dev/null; then
    echo "❌ 摘录对账未能执行:git diff 失败(基准 ${BASE} 是否存在?)" >&2; exit 1
  fi
  n=0
  while IFS= read -r -d '' f || [ -n "${f}" ]; do
    if [[ "${f}" =~ ^changes/[^/]+/tasks/TASK-[^/]*\.md$ ]] && [[ "${f}" != */archive/* ]] && [ -f "${f}" ]; then
      n=$((n+1))
      check_one_card "${f}"
    fi
  done < "${DIFF_FILES}"
  [ "${n}" -eq 0 ] && echo "  ↷ diff 中无在场页面卡,无需摘录对账"
fi

# ---------- 终裁 ----------
if [ "${FAILED}" -eq 1 ]; then
  echo "❌ UI 规格摘录对账不通过:存在占位/漏转抄/指针悬空——摘录完成 = 通过本检查,声明式完成不算完成" >&2
  exit 1
fi
echo "✅ UI 规格摘录对账通过(N=M 严格相等;对照开发纪律见 taskcard-template 门槛②)"
