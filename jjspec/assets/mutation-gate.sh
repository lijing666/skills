#!/usr/bin/env bash
# mutation-gate.sh — 断言强度门禁(jjspec 物料:变异测试采样执法层)
#
# 职责:治"空转绿"——单测全绿、测试对应性存在性契约全过,但断言可能只到
#   "assert result is not None" 级别。变异引擎自动对代码注入变体(改边界/反转条件),
#   跑测试套件:变体被杀死 = 断言真在干活;变体存活 = 测试对该破坏是瞎的。
#   存活率 = (survived + timeout) ÷ total,超阈值 = 断言大面积空转。
#
# 裁决口径(全部 fail-closed:证据不足/检查不了 = 不通过):
#   ① 作用域:仅 risk: high 在场卡,且其边界∩diff 含行为文件时执法(纯高危起步,
#      常规卡不跑——机器时间成本;范围扩展待基线数据积累后另行评估)
#   ② 在场卡缺 risk 行或值非 high/medium/low       → 失败(格式非法显式报,勿静默当低风险)
#   ③ AGENTS.md 无 mutation-engine 登记块而高危卡在场 → 失败(缺登记,同"确无风险区也须显式写 - 无")
#   ④ 登记块 engine: 无（理由）= 显式豁免            → 警告放行(豁免留痕,人审材料包附豁免声明)
#   ⑤ 引擎命令失败/超时/报告缺失/JSON 非法/零变体   → 失败(证据不足 = 不通过)
#   ⑥ 存活率 > threshold                            → 失败;
#      enforcement_date 未到                        → 只记录不阻断(冷启动攒基线)
#   ⑦ threshold 禁止"跑不过就放宽"(同 pixel-diff 阈值纪律)
#   附:纯资产(.md/图片等交付工件)不计入行为文件(见头注"纯资产"),规格资产变更不触发本门禁;
#      --exclude-glob 仍保留给不可变异的可执行文件类(如 *.sql)
#   断言语义真伪(断言很强但验证的不是 AC 说的那件事)仍归人审三焦点——本脚本只执法强度。
#
# 概念(与 extract-boundary.sh / ac-coverage-check.sh 同口径):
#   在场卡   = 本次 diff 中新建或修改的 changes/<需求ID>/tasks/TASK-*.md(归档件不算)
#   豁免文件 = README.md、AGENTS.md、docs/*、changes/*
#   测试文件 = 内置命名约定集(与 ac-coverage-check.sh 一致,见下方 is_test_file)
#   纯资产   = 非可执行交付工件(.md/图片/字体等)——归资产门禁,不计入行为文件(口径同 ac-coverage)
#   行为文件 = 非豁免 且 非测试文件 且 非纯资产(可执行行为代码与配置;
#              需求工件仓与实现仓分离的多仓架构下,三判据在实现仓 diff 上生效,工件仓内天然不触发)
#
# 执行时机:不进 AL2 秒级循环(变异为分钟级);置 review/done 前本地自跑一次
#   (--worktree 含工作区改动) + CI 兜底重放(本地 = 反馈,CI = 执法,防本地谎报)。
#
# 登记块(项目 AGENTS.md;标记行注释包裹、内容行明文,同风险区清单手法):
#   <!-- mutation-engine-begin -->
#   engine: mutmut                  # 引擎名;或"无（理由）"= 显式豁免
#   command: <跑变异到报告的完整命令模板,{targets} 替换为本卡行为文件(带引号空格分隔)>
#   report: <标准 JSON 报告路径,相对仓库根;须含 total/killed/survived,可选 timeout>
#   threshold: 30                   # 存活率警戒线(%)
#   timeout: 600                    # 秒,超时 = 证据不足
#   enforcement_date: <YYYY-MM-DD>  # 缺省 = 立即执法;未到只记录不阻断
#   <!-- mutation-engine-end -->
#
# 用法:mutation-gate.sh <base_ref> [changes_dir] [--worktree] [--exclude-glob <glob>...]
#   base_ref       比较基准,必传:PR 场景 origin/${{ github.base_ref }},push 场景 ${{ github.event.before }}
#                  (全零 sha 由 CI 层跳过)
#   changes_dir    任务卡根目录,默认仓库根 changes/
#   --worktree     diff 取 base..工作区(含未提交改动,本地自检用);默认 base...HEAD(已提交,CI 用)
#   --exclude-glob 从变异目标中显式排除的 glob(如 *.sql——引擎不可变异的文件类;
#                  排除后目标为空的卡跳过;显式登记优于静默 total=0)
# 配套:references/gates.md(断言强度门禁节);ci-snippets/github-actions-mutation-gate.yml;
#       回归测试 mutation-gate.test.sh
# author: 李晶
set -euo pipefail

BASE="${1:?用法: mutation-gate.sh <base_ref> [changes_dir] [--worktree] [--exclude-glob <glob>...](base_ref 必传——在场卡过滤与目标定位依赖它)}"
shift
CHANGES="changes"
WORKTREE=0
EXCLUDE_GLOBS=()
while [ $# -gt 0 ]; do
  case "${1}" in
    --worktree) WORKTREE=1 ;;
    --exclude-glob) shift; EXCLUDE_GLOBS+=("${1:?--exclude-glob 需要一个 glob 参数}") ;;
    *) if [ "${CHANGES}" = "changes" ] && [[ "${1}" != --* ]]; then
         CHANGES="${1}"
       else
         echo "❌ 未知参数:${1}(用法:mutation-gate.sh <base_ref> [changes_dir] [--worktree] [--exclude-glob <glob>...])" >&2
         exit 1
       fi ;;
  esac
  shift
done

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

# 0. git 仓库根(AGENTS.md 登记块与报告路径均以它为基准)
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "❌ 断言强度门禁未能执行:非 git 仓库——检查失败按不通过处理" >&2; exit 1; }

# 1. diff 文件清单——失败必须显式失败,禁止静默放行(fail-closed)
#    --no-renames:重命名拆成"删旧+增新",两侧都参与分类(防改名搬运)
#    -z + read -d '':NUL 分隔读取,特殊字符路径不做任何转义(防误判)
DIFF_FILES="$(mktemp)"
if [ "${WORKTREE}" -eq 1 ]; then
  DFLAGS=("${BASE}")
else
  DFLAGS=("${BASE}"...HEAD)
fi
if ! git -c core.quotepath=off diff --name-only --no-renames -z "${DFLAGS[@]}" > "${DIFF_FILES}" 2>/dev/null; then
  echo "❌ 断言强度门禁未能执行:git diff 失败(基准 ${BASE} 是否存在?仓库是否干净?——worktree 模式需基准已提交)——检查失败按不通过处理" >&2
  exit 1
fi

is_exempt() {
  case "${1}" in
    README.md|AGENTS.md|docs/*|changes/*) return 0 ;;
    *) return 1 ;;
  esac
}

is_asset() {  # 纯资产(口径同 ac-coverage-check.sh)——不计入行为文件
  case "${1}" in
    *.md|*.txt|*.pdf|*.svg|*.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.woff|*.woff2|*.ttf) return 0 ;;
    *) return 1 ;;
  esac
}

is_test_file() {  # 内置模式集与 ac-coverage-check.sh 一致(口径单源在 ac-coverage 头注)
  local f="${1}"
  case "${f}" in
    test_*.py|*_test.py|*_test.go|*Test.java|*Tests.java|*TestCase.java|*IT.java) return 0 ;;
    *Test.kt|*Tests.kt|*_test.kt|*_test.dart) return 0 ;;
    *Tests.swift|*Test.swift|*Tests.m|*Tests.mm) return 0 ;;
    *.test.js|*.test.mjs|*.test.cjs|*.test.jsx|*.test.ts|*.test.tsx|*.test.ets) return 0 ;;
    *.spec.js|*.spec.mjs|*.spec.cjs|*.spec.jsx|*.spec.ts|*.spec.tsx) return 0 ;;
    *.cy.js|*.cy.jsx|*.cy.ts|*.cy.tsx|*.test.sh) return 0 ;;
    */tests/*|tests/*|*/test/*|test/*|*/__tests__/*|__tests__/*) return 0 ;;
    */spec/*|spec/*|*/specs/*|specs/*|*/e2e/*|e2e/*) return 0 ;;
    */androidTest/*|androidTest/*|*/ohosTest/*|ohosTest/*) return 0 ;;
  esac
  return 1
}

fm() {  # fm <卡文件> <frontmatter键> — 取值并去尾随空白(与 ac-coverage-check.sh 同实现)
  awk -v k="${2}" '
    /^---$/{c++; next}
    c==1 && index($0, k":") == 1 { sub("^" k ":[[:space:]]*", ""); print; exit }
    c>=2 { exit }
  ' "${1}" | sed 's/[[:space:]]*$//'
}

# 2. 遍历 diff:收集在场卡 + 行为文件(同 ac-coverage 口径)
present=""
behavior=()
while IFS= read -r -d '' f || [ -n "${f}" ]; do
  if [[ "${f}" =~ ^${CHANGES}/[^/]+/tasks/TASK-[^/]*\.md$ ]] && [[ "${f}" != */archive/* ]]; then
    [ -f "${f}" ] && present+="${f}"$'\n'
  fi
  is_exempt "${f}" && continue
  is_test_file "${f}" && continue
  is_asset "${f}" && continue
  behavior+=("${f}")
done < "${DIFF_FILES}"

if [ -z "${present}" ]; then
  echo "✅ 断言强度门禁通过:本次变更无在场任务卡(纯文档/文档工件改动),无高危卡待检"
  exit 0
fi

# 3. 逐在场卡:risk 校验(fail-closed——缺行/非法显式报,勿静默当低风险)
#    高危卡计算变异目标 = 边界∩行为文件 - exclude-glob
match_any() {  # match_any <文件> <patterns文件> — case glob 匹配(* 可跨斜杠,与 boundary-check.sh 一致)
  local p
  while IFS= read -r p; do
    # shellcheck disable=SC2254
    case "${1}" in ${p}) return 0 ;; esac
  done < "${2}"
  return 1
}

is_excluded() {  # --exclude-glob 显式排除
  local g
  for g in ${EXCLUDE_GLOBS[@]+"${EXCLUDE_GLOBS[@]}"}; do
    # shellcheck disable=SC2254
    case "${1}" in ${g}) return 0 ;; esac
  done
  return 1
}

cards_meta=()   # 每元素: 卡路径
check_cards=()  # 高危且目标非空的卡
n_cards=0
while IFS= read -r card; do
  [ -z "${card}" ] && continue
  n_cards=$((n_cards+1))
  risk="$(fm "${card}" risk)"
  if [ -z "${risk}" ]; then
    echo "❌ 在场卡缺 risk 字段:${card}(taskcard-template frontmatter 必填)——fail-closed" >&2
    exit 1
  fi
  case "${risk}" in
    high) ;;
    medium|low) echo "ℹ️ 跳过:${card}(risk: ${risk},非高危,纯高危口径不检)" && continue ;;
    *) echo "❌ 在场卡 risk 值非法:${card}(risk: ${risk},应为 high/medium/low)——fail-closed" >&2; exit 1 ;;
  esac
  # 边界提取(双格式合并,与 extract-boundary.sh 同手法)
  bfile="${WORKDIR}/b-${n_cards}"
  { sed -n '/^[[:space:]]*```boundary[[:space:]]*$/,/^[[:space:]]*```[[:space:]]*$/p' "${card}" | sed '1d;$d' || true
    awk '/^## 边界/{f=1;next} /^## /{f=0} f&&/^- /{sub(/^- /,"");print}' "${card}" || true
  } | grep -vE '^[[:space:]]*(#|$)' > "${bfile}" || true
  # 变异目标 = 行为文件 ∩ 卡边界,再剔除 exclude-glob
  tfile="${WORKDIR}/t-${n_cards}"; : > "${tfile}"
  for f in ${behavior[@]+"${behavior[@]}"}; do
    is_excluded "${f}" && continue
    match_any "${f}" "${bfile}" && printf '%s\n' "${f}" >> "${tfile}"
  done
  if [ -s "${tfile}" ]; then
    check_cards+=("${card}|${tfile}")
  else
    echo "ℹ️ 跳过:${card}(risk: high 但边界∩diff 无行为文件——纯文档/配置卡,或目标全部被 exclude-glob 排除)"
  fi
done <<< "${present}"

if [ "${#check_cards[@]}" -eq 0 ]; then
  echo "✅ 断言强度门禁通过:${n_cards} 张在场卡中无高危行为卡待检(跳过明细见上)"
  exit 0
fi

# 4. AGENTS.md mutation-engine 登记块
AGENTS_MD="${ROOT}/AGENTS.md"
ENGINE="" COMMAND="" REPORT="" THRESHOLD="30" TIMEOUT="600" ENF=""
if [ -f "${AGENTS_MD}" ]; then
  block="$(sed -n '/mutation-engine-begin/,/mutation-engine-end/p' "${AGENTS_MD}")"
  if [ -n "${block}" ]; then
    ENGINE="$(sed -n 's/^engine:[[:space:]]*//p' <<<"${block}" | head -1)"
    COMMAND="$(sed -n 's/^command:[[:space:]]*//p' <<<"${block}" | head -1)"
    REPORT="$(sed -n 's/^report:[[:space:]]*//p' <<<"${block}" | head -1)"
    THRESHOLD="$(sed -n 's/^threshold:[[:space:]]*//p' <<<"${block}" | head -1)"
    TIMEOUT="$(sed -n 's/^timeout:[[:space:]]*//p' <<<"${block}" | head -1)"
    ENF="$(sed -n 's/^enforcement_date:[[:space:]]*//p' <<<"${block}" | head -1)"
  fi
fi

if [ -z "${ENGINE}" ]; then
  echo "❌ 断言强度门禁失败:存在高危行为卡在场,而 AGENTS.md 无 mutation-engine 登记块(或块内缺 engine 行)——fail-closed" >&2
  echo "   修正方式:① 登记 mutation-engine-begin/end 块(格式见 mutation-gate.sh 头注);"
  echo "             ② 冷启动项目可先写 engine: 无（理由）显式豁免(警告放行,人审材料包附豁免声明)。" >&2
  exit 1
fi

if [ "${ENGINE}" = "无" ] || [[ "${ENGINE}" == 无* ]]; then
  echo "⚠️ 变异采样显式豁免(engine: ${ENGINE})——${#check_cards[@]} 张高危行为卡未做断言强度验证,缺口留痕:"
  for c in "${check_cards[@]}"; do echo "   - ${c%%|*}"; done
  echo "✅ 断言强度门禁通过(豁免放行):高风险卡人审材料包须附本豁免声明——用现成必过的检查顶替 = 验收器漂移"
  exit 0
fi

if [ -z "${COMMAND}" ] || [ -z "${REPORT}" ]; then
  echo "❌ mutation-engine 登记块不完整(command/report 必填,engine: ${ENGINE})——检查失败按不通过处理" >&2
  exit 1
fi
case "${THRESHOLD}" in ''|*[!0-9]*) echo "❌ threshold 须为整数(当前: ${THRESHOLD})——fail-closed" >&2; exit 1 ;; esac
case "${TIMEOUT}" in ''|*[!0-9]*) echo "❌ timeout 须为整数秒(当前: ${TIMEOUT})——fail-closed" >&2; exit 1 ;; esac

# enforcement_date 缺省 = 立即执法;未到只记录(YYYY-MM-DD 字典序即时间序,零依赖比较)
TODAY="$(date +%Y-%m-%d)"
if [ -n "${ENF}" ] && [[ "${TODAY}" < "${ENF}" ]]; then
  echo "ℹ️ 基线期未满(enforcement_date: ${ENF},今天 ${TODAY}):本次只记录存活率不阻断,到期自动启用"
  ENFORCING=0
else
  ENFORCING=1
fi

# 5. 逐高危卡执行引擎并对账
run_timeout() {  # run_timeout <秒> <命令字符串> — 纯 bash 超时包装(跨平台零依赖);124 = 超时
  local secs="$1" cmd="$2" pid t=0
  bash -c "${cmd}" & pid=$!
  while kill -0 "${pid}" 2>/dev/null; do
    if [ "${t}" -ge "${secs}" ]; then
      kill -9 "${pid}" 2>/dev/null || true; wait "${pid}" 2>/dev/null || true
      return 124
    fi
    sleep 1; t=$((t+1))
  done
  wait "${pid}"
}

json_num() {  # json_num <json文本> <键> — 提取数值,缺失输出空
  printf '%s' "${1}" | grep -o "\"${2}\"[[:space:]]*:[[:space:]]*[0-9][0-9]*" | head -1 | grep -o '[0-9][0-9]*$' || true
}

FAILED=0
for entry in "${check_cards[@]}"; do
  card="${entry%%|*}"; tfile="${entry##*|}"
  targets_quoted=""
  while IFS= read -r tf; do targets_quoted+=" \"${tf}\""; done < "${tfile}"

  cmd="${COMMAND//\{targets\}/${targets_quoted}}"
  echo "── 变异采样:${card}"
  echo "   目标:$(tr '\n' ' ' < "${tfile}")"
  rc=0
  ( cd "${ROOT}" && run_timeout "${TIMEOUT}" "${cmd}" ) || rc=$?
  if [ "${rc}" -eq 124 ]; then
    echo "❌ 引擎命令超时(>${TIMEOUT}s,证据不足)——fail-closed" >&2; FAILED=1; continue
  elif [ "${rc}" -ne 0 ]; then
    echo "❌ 引擎命令失败(退出码 ${rc},证据不足)——fail-closed" >&2; FAILED=1; continue
  fi
  rf="${ROOT}/${REPORT}"
  if [ ! -f "${rf}" ]; then
    echo "❌ 变异报告缺失:${REPORT}(登记的 report 路径无产出,证据不足)——fail-closed" >&2; FAILED=1; continue
  fi
  json="$(cat "${rf}")"
  total="$(json_num "${json}" total)"
  killed="$(json_num "${json}" killed)"
  survived="$(json_num "${json}" survived)"
  timed="$(json_num "${json}" timeout)"
  [ -z "${timed}" ] && timed=0
  if [ -z "${total}" ] || [ -z "${killed}" ] || [ -z "${survived}" ]; then
    echo "❌ 报告 JSON 非法:缺 total/killed/survived(报告路径 ${REPORT})——fail-closed" >&2; FAILED=1; continue
  fi
  if [ "${total}" -le 0 ]; then
    echo "❌ 报告 total=0(零变体 = 证据不足;不可变异的文件类用 --exclude-glob 显式排除)——fail-closed" >&2; FAILED=1; continue
  fi
  alive=$((survived + timed))
  pct=$(( alive * 100 / total ))
  if [ "${alive}" -gt $(( total * THRESHOLD / 100 )) ]; then
    echo "   变体 total=${total} killed=${killed} survived=${survived} timeout=${timed} → 存活率 ${pct}% > 阈值 ${THRESHOLD}%"
    if [ "${ENFORCING}" -eq 1 ]; then
      echo "❌ 测试空转嫌疑:断言对 ${pct}% 的代码破坏是瞎的——加强断言(对照 spec_ac 的精确值断言)后重跑,禁止放宽阈值——fail-closed" >&2
      FAILED=1
    else
      echo "⚠️ 基线期:存活率超标只记录不阻断(登记 enforcement_date 到期后启用拦截)"
    fi
  else
    echo "   变体 total=${total} killed=${killed} survived=${survived} timeout=${timed} → 存活率 ${pct}% ≤ 阈值 ${THRESHOLD}%"
  fi
done

if [ "${FAILED}" -gt 0 ]; then
  echo ""
  echo "❌ 断言强度门禁失败:存在高危卡存活率超标或证据不足(逐卡明细见上)"
  exit 1
fi
echo "✅ 断言强度门禁通过:${#check_cards[@]} 张高危行为卡,存活率均未超阈值且证据完整(逐卡明细见上)"
