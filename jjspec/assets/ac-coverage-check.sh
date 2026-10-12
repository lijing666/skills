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
#   附:diff 只触碰豁免/测试文件 → 通过;触碰行为文件但无在场卡 → 失败(缺覆盖)
#   断言语义对应(测试是否真测了 AC)仍归人审三焦点——本脚本只执法存在性契约。
#
# 概念(与 extract-boundary.sh 同口径):
#   在场卡   = 本次 diff(BASE...HEAD)中新建或修改的 changes/<需求ID>/tasks/TASK-*.md(归档件不算)
#   豁免文件 = README.md、AGENTS.md、docs/*、changes/*
#   测试文件 = 匹配测试模式集(内置约定 + --test-glob 追加)
#   行为文件 = 非豁免 且 非测试文件
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
# 用法:ac-coverage-check.sh <base_ref> [changes_dir] [--test-glob <glob>...]
#   base_ref    比较基准,必传(在场卡过滤依赖它):PR 场景 origin/${{ github.base_ref }},
#               push 直推场景 ${{ github.event.before }}(全零 sha 由 CI 层跳过)
#   changes_dir 任务卡根目录,默认仓库根 changes/(卡路径匹配与 extract-boundary.sh 相同,固定 changes/ 前缀)
#   --test-glob 追加项目特有测试模式(fnmatch glob,可多次;注意 case 匹配中 * 可跨斜杠)
# 配套:taskcard-template.md(## 测试文件清单 格式);ci-snippets/github-actions-ac-coverage.yml;
#       references/gates.md 第二层(测试对应性检查)
# author: 李晶
set -euo pipefail

BASE="${1:?用法: ac-coverage-check.sh <base_ref> [changes_dir] [--test-glob <glob>...](base_ref 必传——在场卡过滤依赖它)}"
shift
CHANGES="changes"
if [ $# -gt 0 ] && [[ "${1}" != --* ]]; then CHANGES="${1}"; shift; fi
TEST_GLOBS=()
while [ $# -gt 0 ]; do
  case "${1}" in
    --test-glob) shift; TEST_GLOBS+=("${1:?--test-glob 需要一个 glob 参数}") ;;
    *) echo "❌ 未知参数:${1}(用法:ac-coverage-check.sh <base_ref> [changes_dir] [--test-glob <glob>...])" >&2; exit 1 ;;
  esac
  shift
done

DIFF_FILES="$(mktemp)"; WORKDIR="$(mktemp -d)"
trap 'rm -rf "${DIFF_FILES}" "${WORKDIR}"' EXIT

# 1. diff 文件清单——失败显式失败,禁止静默放行(fail-closed)
#    --no-renames:重命名拆成"删旧+增新",两侧都参与分类(防改名搬运)
#    -z + read -d '':NUL 分隔读取,特殊字符路径不做任何转义(防误判)
if ! git -c core.quotepath=off diff --name-only --no-renames -z "${BASE}"...HEAD > "${DIFF_FILES}" 2>/dev/null; then
  echo "❌ 测试对应性检查未能执行:git diff 失败(基准 ${BASE} 是否存在?仓库是否干净?)——检查失败按不通过处理" >&2
  exit 1
fi

is_exempt() {
  case "${1}" in
    README.md|AGENTS.md|docs/*|changes/*) return 0 ;;
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
done <<< "${present}"

if [ "${FAILED}" -eq 1 ]; then
  echo "❌ 测试对应性检查不通过:${n_cards} 张在场卡存在 AC↔测试对应缺口(见上)" >&2
  exit 1
fi

echo "✅ 测试对应性检查通过:${n_cards} 张在场卡 AC 引用有效;${#behavior[@]} 个行为文件均有 ## 测试文件清单 看护(断言语义对应归人审三焦点)"