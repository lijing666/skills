#!/usr/bin/env bash
# ac-coverage-check.sh — 测试对应性门禁(jjspec 物料:AC↔测试对应 执法层)
#
# 职责:改了行为代码必须有测试看护。与 extract-boundary.sh 分工——
#   boundary 管"改哪里"(白名单),本脚本管"改了行为必须有看护"(测试契约)。
#
# 裁决口径(全部 fail-closed:检查不了/对不上 = 不通过):
#   ① 在场卡 spec_ac 引用的每个 AC 必须存在于 spec: 指向的 Spec 文件(防幻觉/笔误)
#   ② 边界覆盖行为文件的在场卡必须声明 ## 测试文件清单(taskcard-template 定义)
#   ③ 清单条目必须是合法路径格式(非法明确报"格式非法",区别于"文件不存在")
#   ④ 清单条目指向的测试文件必须存在(合入时契约兑现;"待创建承诺"不许落空)
#   ⑤ 清单条目必须是测试文件(防把源码文件声明成自己的看护——存在性是必要条件,此为充分性兜底)
#   ⑥ (--integration-mark 启用时) risk: high 行为卡的清单须含 ≥1 个带集成标记的测试文件
#      (真实性执法:高危卡天生碰真依赖,全 mock 的绿是假的;标记测试内部是否 mock 掉主依赖
#      机械查不了——归人审三焦点,变异存活率交叉印证;AGENTS.md integration-mark 块未登记
#      而开关开启 → 失败(fail-closed);risk 缺失/非法的卡跳过本项——由 mutation-gate.sh 拦)
#   附:diff 只触碰豁免/测试文件 → 通过;触碰行为文件但无在场卡 → 失败(缺覆盖)
#   断言语义对应(测试是否真测了 AC)仍归人审三焦点——本脚本只执法存在性契约。
#
# 概念(与 extract-boundary.sh 同口径):
#   在场卡   = 本次 diff(BASE...HEAD)中新建或修改的 changes/<需求ID>/tasks/TASK-*.md(归档件不算)
#   豁免文件 = README.md、AGENTS.md、docs/*、changes/*
#   测试文件 = 匹配测试模式集(内置约定 + --test-glob 追加)
#   纯资产   = 非可执行的交付工件(.md/.txt/.pdf/.svg/.png/.jpg/.jpeg/.gif/.webp/.ico/字体)
#              ——归各自资产门禁(UI 管线对账/文档门禁),不计入行为文件:
#              测试对应性/变异采样/集成标记的执法对象是可执行行为代码,规格资产变更不触发
#   行为文件 = 非豁免 且 非测试文件 且 非纯资产
#
# 测试文件内置模式集(命名约定;识别不了按行为文件处理 = 宁可多要清单,不可漏要):
#   Python            test_*.py  *_test.py
#   Go                *_test.go
#   Java              *Test.java  *Tests.java  *TestCase.java  *IT.java
#   Kotlin(Android)   *Test.kt  *Tests.kt  *_test.kt
#   Swift/ObjC(iOS)   *Tests.swift  *Test.swift  *Tests.m  *Tests.mm
#   Dart(Flutter)     *_test.dart
#   ArkTS(鸿蒙)       *.test.ets(另含 ohosTest/ 目录段)
#   JS/TS(H5/小程序)  *.test.{js,mjs,cjs,jsx,ts,tsx}  *.spec.{js,mjs,cjs,jsx,ts,tsx}
#                     *.cy.{js,jsx,ts,tsx}(Cypress;Jest/Vitest/Playwright 由 .test/.spec 覆盖;
#                     小程序生态即 JS/TS 约定,无独立模式)
#   Shell             *.test.sh
#   目录段型          路径任一段 ∈ {tests, test, __tests__, spec, specs, e2e, androidTest, ohosTest}
#   项目布局非典型时用 --test-glob 追加,不替换内置集。
#
# 用法:ac-coverage-check.sh <base_ref> [changes_dir] [--test-glob <glob>...] [--integration-mark] [--worktree]
#   base_ref    比较基准,必传(在场卡过滤依赖它):PR 场景 origin/${{ github.base_ref }},
#               push 直推场景 ${{ github.event.before }}(全零 sha 由 CI 层跳过)
#   changes_dir 任务卡根目录,默认仓库根 changes/(卡路径匹配与 extract-boundary.sh 相同,固定 changes/ 前缀)
#   --test-glob 追加项目特有测试模式(fnmatch glob,可多次;注意 case 匹配中 * 可跨斜杠)
#   --integration-mark 开关型(无值):启用真实性执法,从 AGENTS.md integration-mark 块读标记串
#               (登记见 assets/AGENTS.md.template);默认关——不传对现有项目零影响
#   --worktree  预演口径(本地预演专用,开关型):diff 基准改为 merge-base(base_ref,HEAD)→工作区,
#               覆盖已提交+已暂存+未暂存变更,且不含 base 落后产生的反向假 diff(base 上本 PR 未
#               包含的变更不会被误报为删除);未跟踪文件不进任何 git diff,检出即拦(先 git add 再预演)。
#               默认(CI)口径 = base_ref...HEAD 不变——CI 工作区干净,两口径等价,CI 调用零改动;
#               默认模式下检出未提交变更仅打警告不拦截(防本地预演忘加开关的假绿)
# 路径解析基准:git 仓库根(与 taskcard-template「测试文件清单条目 = 仓库根相对路径」契约一致;
#   脚本内部统一切换到仓库根执行,从任意子目录调用行为一致——旧版按执行时 CWD 解析,子目录预演
#   会把「项目根相对」的错误路径误判为存在,推上 CI(仓库根执行)才报错)
# 配套:taskcard-template.md(## 测试文件清单 格式);ci-snippets/github-actions-ac-coverage.yml;
#       assets/AGENTS.md.template(integration-mark 登记块);references/gates.md 第二层(测试对应性检查)
# author: 李晶
set -euo pipefail

BASE="${1:?用法: ac-coverage-check.sh <base_ref> [changes_dir] [--test-glob <glob>...] [--integration-mark] [--worktree](base_ref 必传——在场卡过滤依赖它)}"
shift
CHANGES="changes"
WORKTREE=0
if [ $# -gt 0 ] && [[ "${1}" != --* ]]; then CHANGES="${1}"; shift; fi
TEST_GLOBS=()
CHECK_INT=0
while [ $# -gt 0 ]; do
  case "${1}" in
    --test-glob) shift; TEST_GLOBS+=("${1:?--test-glob 需要一个 glob 参数}") ;;
    --integration-mark) CHECK_INT=1 ;;
    --worktree) WORKTREE=1 ;;
    *) echo "❌ 未知参数:${1}(用法:ac-coverage-check.sh <base_ref> [changes_dir] [--test-glob <glob>...] [--worktree])" >&2; exit 1 ;;
  esac
  shift
done

# 0. 定位 git 仓库根并切换——所有相对路径(清单条目/spec:/changes_dir)统一按仓库根解析,从任意
#    子目录调用行为一致;CI 在仓库根执行,cd 为 no-op,行为不变(fail-closed:非 git 仓库即拦)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "❌ 测试对应性检查未能执行:不在 git 仓库内(路径契约 = 仓库根相对,无从解析)——检查失败按不通过处理" >&2
  exit 1
}
cd "${REPO_ROOT}"

DIFF_FILES="$(mktemp)"; WORKDIR="$(mktemp -d)"
trap 'rm -rf "${DIFF_FILES}" "${WORKDIR}"' EXIT

# 0.5 集成标记读取(--integration-mark 启用时;fail-closed:开关开而未登记 = 配置不一致)
INT_MARK=""
if [ "${CHECK_INT}" -eq 1 ]; then
  AGENTS_MD="$(git rev-parse --show-toplevel 2>/dev/null)/AGENTS.md"
  if [ -f "${AGENTS_MD}" ]; then
    _iblock="$(sed -n '/integration-mark-begin/,/integration-mark-end/p' "${AGENTS_MD}")"
    INT_MARK="$(sed -n 's/^mark:[[:space:]]*//p' <<<"${_iblock}" | head -1)"
  fi
  if [ -z "${INT_MARK}" ]; then
    echo "❌ --integration-mark 已启用但 AGENTS.md 无 integration-mark 登记块(或 mark 行为空)——配置不一致,fail-closed" >&2
    echo "   修正方式:AGENTS.md 登记 integration-mark-begin/end 块(格式见 assets/AGENTS.md.template),或 CI 去掉该开关。" >&2
    exit 1
  fi
fi

# 1. diff 文件清单——失败显式失败,禁止静默放行(fail-closed)
#    默认(CI)口径 = BASE...HEAD(仅已提交);--worktree 预演口径 = merge-base(BASE,HEAD)→工作区
#    (含已提交+已暂存+未暂存;不含 base 落后的反向假 diff)
#    --no-renames:重命名拆成"删旧+增新",两侧都参与分类(防改名搬运)
#    -z + read -d '':NUL 分隔读取,特殊字符路径不做任何转义(防误判)
if [ "${WORKTREE}" -eq 1 ]; then
  MB="$(git merge-base "${BASE}" HEAD 2>/dev/null)" || {
    echo "❌ 测试对应性检查未能执行:git merge-base 失败(基准 ${BASE} 与 HEAD 无共同祖先?)——检查失败按不通过处理" >&2
    exit 1
  }
  DIFF_TARGET=("${MB}")
else
  DIFF_TARGET=("${BASE}...HEAD")
  # 预演忘加 --worktree 的防呆:工作区有未提交变更时警告(不拦截——CI 干净工作区无感)
  _dirty="$(git -c core.quotepath=off status --porcelain 2>/dev/null | grep -c . || true)"
  if [ "${_dirty}" -gt 0 ]; then
    echo "⚠️ 检测到 ${_dirty} 个未提交变更未纳入本次检查——默认口径仅覆盖已提交 diff(${BASE}...HEAD);本地预演请加 --worktree" >&2
  fi
fi
if ! git -c core.quotepath=off diff --name-only --no-renames -z "${DIFF_TARGET[@]}" > "${DIFF_FILES}" 2>/dev/null; then
  echo "❌ 测试对应性检查未能执行:git diff 失败(基准 ${BASE} 是否存在?)——检查失败按不通过处理" >&2
  exit 1
fi
# 未跟踪文件任何 git diff 都不可见——预演模式 fail-closed(先 git add 使其进入工作区 diff);
# 默认模式不拦(CI 检出工作区干净,无未跟踪文件)
if [ "${WORKTREE}" -eq 1 ]; then
  _ut="$(git -c core.quotepath=off status --porcelain 2>/dev/null | grep -c '^??' || true)"
  if [ "${_ut}" -gt 0 ]; then
    echo "❌ 预演(--worktree)检出 ${_ut} 个未跟踪文件——未跟踪文件不进任何 git diff,预演覆盖不到;先 git add 再预演——fail-closed" >&2
    exit 1
  fi
fi

is_exempt() {
  case "${1}" in
    README.md|AGENTS.md|docs/*|changes/*) return 0 ;;
    *) return 1 ;;
  esac
}

is_asset() {  # 纯资产(交付工件,非可执行)——不计入行为文件(口径见头注"纯资产")
  case "${1}" in
    *.md|*.txt|*.pdf|*.svg|*.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.woff|*.woff2|*.ttf) return 0 ;;
    *) return 1 ;;
  esac
}

is_test_file() {
  local f="${1}" g
  case "${f}" in
    # 后缀型(命名约定;case 的 * 可跨斜杠——与 extract-boundary.sh 口径一致)
    test_*.py|*_test.py|*_test.go|*Test.java|*Tests.java|*TestCase.java|*IT.java) return 0 ;;
    *Test.kt|*Tests.kt|*_test.kt|*_test.dart) return 0 ;;
    *Tests.swift|*Test.swift|*Tests.m|*Tests.mm) return 0 ;;
    *.test.js|*.test.mjs|*.test.cjs|*.test.jsx|*.test.ts|*.test.tsx|*.test.ets) return 0 ;;
    *.spec.js|*.spec.mjs|*.spec.cjs|*.spec.jsx|*.spec.ts|*.spec.tsx) return 0 ;;
    *.cy.js|*.cy.jsx|*.cy.ts|*.cy.tsx|*.test.sh) return 0 ;;
    # 目录段型:路径任一段属于测试目录(单级严格匹配)
    */tests/*|tests/*|*/test/*|test/*|*/__tests__/*|__tests__/*) return 0 ;;
    */spec/*|spec/*|*/specs/*|specs/*|*/e2e/*|e2e/*) return 0 ;;
    */androidTest/*|androidTest/*|*/ohosTest/*|ohosTest/*) return 0 ;;
  esac
  for g in ${TEST_GLOBS[@]+"${TEST_GLOBS[@]}"}; do
    # shellcheck disable=SC2254
    case "${f}" in ${g}) return 0 ;; esac
  done
  return 1
}

# fm <卡文件> <frontmatter键> — 取值并去尾随空白
fm() {
  awk -v k="${2}" '
    /^---$/{c++; next}
    c==1 && index($0, k":") == 1 { sub("^" k ":[[:space:]]*", ""); print; exit }
    c>=2 { exit }
  ' "${1}" | sed 's/[[:space:]]*$//'
}

# 2. 遍历 diff:收集在场卡 + 行为文件分类
present=""
behavior=()
while IFS= read -r -d '' f || [ -n "${f}" ]; do
  if [[ "${f}" =~ ^changes/[^/]+/tasks/TASK-[^/]*\.md$ ]] && [[ "${f}" != */archive/* ]]; then
    # 在场卡(新建或修改);已删除卡(归档退场)不计
    [ -f "${f}" ] && present+="${f}"$'\n'
  fi
  is_exempt "${f}" && continue
  is_test_file "${f}" && continue
  is_asset "${f}" && continue
  behavior+=("${f}")
done < "${DIFF_FILES}"

if [ "${#behavior[@]}" -eq 0 ]; then
  echo "✅ 测试对应性检查通过:diff 未触碰行为文件(仅豁免/测试文件),无需测试看护声明"
  exit 0
fi

if [ -z "${present}" ]; then
  echo "❌ 缺任务卡覆盖:diff 触碰 ${#behavior[@]} 个行为文件但本次变更无在场任务卡——AC↔测试对应无从建立,fail-closed" >&2
  echo "   修正方式:为本次变更立卡(声明 spec:/spec_ac/边界/## 测试文件清单),随变更同 diff 提交。" >&2
  exit 1
fi

# 3. 逐卡裁决
FAILED=0
n_cards=0
CARD_BOUND="${WORKDIR}/bound"; CARD_TESTS="${WORKDIR}/tests"
while IFS= read -r card; do
  [ -z "${card}" ] && continue
  n_cards=$((n_cards+1))

  # ① spec_ac 引用有效性
  spec_rel="$(fm "${card}" spec)"
  spec_ac="$(fm "${card}" spec_ac)"
  spec_ac="${spec_ac//[/}"; spec_ac="${spec_ac//]/}"; spec_ac="${spec_ac// /}"
  if [ -n "${spec_ac}" ]; then
    if [ -z "${spec_rel}" ] || [ ! -f "${spec_rel}" ]; then
      echo "🚫 ${card}:声明了 spec_ac 但 Spec 文件缺失或未声明 spec:(当前:${spec_rel:-<未声明>})" >&2
      FAILED=1
    else
      IFS=',' read -r -a ACS <<< "${spec_ac}"
      for ac in "${ACS[@]}"; do
        [ -z "${ac}" ] && continue
        if ! grep -qF -- "${ac}" "${spec_rel}"; then
          echo "🚫 ${card}:spec_ac 引用了 Spec(${spec_rel})中不存在的 ${ac}——幻觉/笔误,fail-closed" >&2
          FAILED=1
        fi
      done
    fi
  fi

  # ② 该卡边界是否覆盖任一行为文件(双格式提取,与 extract-boundary.sh 完全一致)
  : > "${CARD_BOUND}"
  sed -n '/^[[:space:]]*```boundary[[:space:]]*$/,/^[[:space:]]*```[[:space:]]*$/p' "${card}" | sed '1d;$d' >> "${CARD_BOUND}" || true
  awk '/^## 边界/{f=1;next} /^## /{f=0} f&&/^- /{sub(/^- /,"");print}' "${card}" >> "${CARD_BOUND}" || true
  covers=0
  while IFS= read -r g; do
    for f in ${behavior[@]+"${behavior[@]}"}; do
      # shellcheck disable=SC2053
      [[ "${f}" == ${g} ]] && { covers=1; break 2; }
    done
  done < <(grep -vE '^[[:space:]]*(#|$)' "${CARD_BOUND}" || true)
  [ "${covers}" -eq 0 ] && continue

  # ③④⑤ ## 测试文件清单 检查
  : > "${CARD_TESTS}"
  awk '/^## 测试文件清单/{f=1;next} /^## /{f=0} f&&/^- /{sub(/^- /,""); sub(/[[:space:]]+$/,""); print}' "${card}" >> "${CARD_TESTS}" || true
  if [ ! -s "${CARD_TESTS}" ]; then
    echo "🚫 ${card}:边界覆盖行为文件但未声明 ## 测试文件清单——行为变更必须有测试看护,fail-closed" >&2
    FAILED=1
    continue
  fi
  while IFS= read -r entry; do
    [ -z "${entry}" ] && continue
    p="${entry%%::*}"    # ::用例名 后缀剥离(路径校验用;用例与 AC 对应归 ## 验收 人审)
    bad=""
    case "${p}" in
      ""|*" "*) bad="为空或含空格(应为 <仓库根相对路径>[::用例名],一行一条)" ;;
      /*) bad="须为仓库根相对路径(不以 / 开头)" ;;
      *.*|*/*) : ;;
      *) bad="不像文件路径" ;;
    esac
    if [ -n "${bad}" ]; then
      echo "🚫 ${card}:## 测试文件清单 条目格式非法「${entry}」(${bad})——注意区别于文件不存在" >&2
      FAILED=1
      continue
    fi
    if [ ! -f "${p}" ]; then
      echo "🚫 ${card}:## 测试文件清单 声明的测试文件不存在:${p}(待创建承诺落空)" >&2
      FAILED=1
      continue
    fi
    if ! is_test_file "${p}"; then
      echo "🚫 ${card}:## 测试文件清单 条目不是测试文件:${p}——若确为本项目测试文件,用 --test-glob 登记约定" >&2
      FAILED=1
    fi
  done < "${CARD_TESTS}"

  # ⑥ 集成标记检查(--integration-mark 启用时;仅 risk: high——高危卡天生碰真依赖)
  if [ "${CHECK_INT}" -eq 1 ]; then
    _risk="$(fm "${card}" risk)"
    if [ "${_risk}" = "high" ]; then
      _int_hit=0
      while IFS= read -r entry; do
        [ -z "${entry}" ] && continue
        _p="${entry%%::*}"
        if [ -f "${_p}" ] && grep -qF -- "${INT_MARK}" "${_p}"; then _int_hit=1; break; fi
      done < "${CARD_TESTS}"
      if [ "${_int_hit}" -eq 0 ]; then
        echo "🚫 ${card}:risk: high 行为卡清单无带集成标记(${INT_MARK})的测试——真依赖验证缺失,全 mock 的绿是假的,fail-closed" >&2
        FAILED=1
      fi
    fi
    # risk 缺失/非法不做本项(跳过)——由 mutation-gate.sh 拦(缺 risk 即 FAIL),双门禁分工
  fi
done <<< "${present}"

if [ "${FAILED}" -eq 1 ]; then
  echo "❌ 测试对应性检查不通过:${n_cards} 张在场卡存在 AC↔测试对应缺口(见上)" >&2
  exit 1
fi

echo "✅ 测试对应性检查通过:${n_cards} 张在场卡 AC 引用有效;${#behavior[@]} 个行为文件均有 ## 测试文件清单 看护(断言语义对应归人审三焦点)"