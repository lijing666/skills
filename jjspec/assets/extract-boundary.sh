#!/usr/bin/env bash
# extract-boundary.sh — 从"在场"任务卡提取越界检测边界(jjspec 物料:提取层 + 覆盖裁决)
#
# 在场卡 = 本次 diff 中新建或修改的进行中任务卡
#   (默认 CI 口径 = BASE...HEAD 仅已提交;本地预演加 --worktree = merge-base→工作区,含未提交卡)
#   changes/<需求ID>/tasks/TASK-*.md(归档件 changes/**/archive/ 不算)。
# 白名单 = 在场卡边界并集 + 豁免段——不在场卡的边界一律不进白名单,
#   防"借别的卡的边界夹带越界改动"(在场卡过滤)。
#
# 裁决口径(fail-closed:检查不了/覆盖不了 = 不通过):
#   1. git diff 失败                        → exit 1
#   2. diff 触碰非豁免文件但无在场任务卡覆盖 → exit 1(缺卡覆盖)
#   3. 有在场卡但未声明边界(双格式皆无,
#      或声明全为注释/空行)                 → exit 1(卡未声明边界)
#   4. diff 全豁免(只动文档/变更工件)       → 输出豁免段,exit 0(boundary-check 自然放行)
#   5. 其余                                  → 输出豁免段+在场卡边界并集,exit 0
#
# 豁免清单(不要求卡覆盖、不参与越界判定):README.md、AGENTS.md、docs/*、changes/*
#   —— 代码/配置/CI/依赖文件不在豁免范围,改动必须有在场卡覆盖。
#
# 边界声明双格式(一卡可混用,提取结果合并):
#   格式一:```boundary 围栏,一行一个 glob(未闭合围栏取到文件尾,内容仍有效)
#   格式二:## 边界 区块下的 `- ` 列表(taskcard-template 原生格式)
#
# 输出:一行一个 glob,写 stdout(恒含豁免段,永不为空——CI 无需判空跳过)。
# 用法:extract-boundary.sh <base_ref> [changes_dir] [--worktree]
#   base_ref    比较基准,如 origin/main 或 PR 场景 ${{ github.base_ref }};
#               push 直推场景用 ${{ github.event.before }}(全零 sha 由 CI 层跳过)。
#               必传——不传即放弃在场卡过滤,等于放弃漏洞①防线,故设计为必填。
#   changes_dir 任务卡根目录,默认仓库根 changes/
#   --worktree  预演口径(本地预演专用,开关型):在场卡扫描基准改为 merge-base(base_ref,HEAD)→工作区,
#               未提交(已暂存/已修改)任务卡进白名单——与 boundary-check --worktree 必须同开:
#               check 侧看见了未提交代码改动、extract 侧看不见未提交卡 = 白名单缺卡假红。
#               未跟踪文件不进任何 git diff,检出即拦(任务卡先 git add 再预演,不强制提交)。
#               默认(CI)口径 = base_ref...HEAD 不变——CI 工作区干净,两口径等价,CI 调用零改动;
#               默认模式下检出未提交变更仅警告不拦截(与另两件套同款防呆)
# 路径解析基准:git 仓库根(diff 清单为仓库根相对路径,卡文件按此打开;脚本内部统一切换到仓库根
#   执行,从任意子目录调用行为一致;非 git 仓库 fail-closed)
# 配套:boundary-check.sh(白名单比对器,本脚本输出直接作其边界文件入参);
#       CI 集成见 ci-snippets/github-actions-boundary.yml
# author: 李晶
set -euo pipefail

BASE="${1:?用法: extract-boundary.sh <base_ref> [changes_dir] [--worktree](base_ref 必传——在场卡过滤依赖它)}"
shift
CHANGES="changes"
WORKTREE=0
if [ $# -gt 0 ] && [[ "${1}" != --* ]]; then CHANGES="${1}"; shift; fi
while [ $# -gt 0 ]; do
  case "${1}" in
    --worktree) WORKTREE=1 ;;
    *) echo "❌ 未知参数:${1}(用法:extract-boundary.sh <base_ref> [changes_dir] [--worktree])" >&2; exit 1 ;;
  esac
  shift
done

# 0. 定位 git 仓库根并切换——diff 清单为仓库根相对路径,卡文件按此路径打开,须以仓库根为基准;
#    从任意子目录调用行为一致;CI 在仓库根执行,cd 为 no-op,行为不变(fail-closed:非 git 仓库即拦)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "❌ 边界提取未能执行:不在 git 仓库内(卡路径 = 仓库根相对,无从解析)——检查失败按不通过处理" >&2
  exit 1
}
cd "${REPO_ROOT}"

# 临时文件 mktemp(防并发 CI 互相干扰),trap 兜底清理
DIFF_FILES="$(mktemp)" ; RAW="$(mktemp)" ; CLEAN="$(mktemp)"
trap 'rm -f "${DIFF_FILES}" "${RAW}" "${CLEAN}"' EXIT

# 1. 获取 diff 文件清单——失败必须显式失败,禁止静默放行(fail-closed)
#    默认(CI)口径 = BASE...HEAD(仅已提交);--worktree 预演口径 = merge-base(BASE,HEAD)→工作区
#    (含已提交+已暂存+已修改,未提交卡才进得了在场清单)
#    --no-renames:重命名拆成"删旧+增新",两侧都参与在场判定(防改名搬运)
#    -z + read -d '':NUL 分隔读取,特殊字符路径不做任何转义(防误判)
if [ "${WORKTREE}" -eq 1 ]; then
  MB="$(git merge-base "${BASE}" HEAD 2>/dev/null)" || {
    echo "❌ 边界提取未能执行:git merge-base 失败(基准 ${BASE} 与 HEAD 无共同祖先?)——检查失败按不通过处理" >&2
    exit 1
  }
  DIFF_TARGET=("${MB}")
else
  DIFF_TARGET=("${BASE}...HEAD")
  # 预演忘加 --worktree 的防呆:工作区有未提交变更时警告(不拦截——CI 干净工作区无感)
  _dirty="$(git -c core.quotepath=off status --porcelain 2>/dev/null | grep -c . || true)"
  if [ "${_dirty}" -gt 0 ]; then
    echo "⚠️ 检测到 ${_dirty} 个未提交变更未纳入在场卡扫描——默认口径仅覆盖已提交 diff(${BASE}...HEAD);本地预演请加 --worktree" >&2
  fi
fi
if ! git -c core.quotepath=off diff --name-only --no-renames -z "${DIFF_TARGET[@]}" > "${DIFF_FILES}" 2>/dev/null; then
  echo "❌ 边界提取未能执行:git diff 失败(基准 ${BASE} 是否存在?)——检查失败按不通过处理" >&2
  exit 1
fi
# 未跟踪文件任何 git diff 都不可见——预演模式 fail-closed(未提交任务卡也须先 git add 才进得了
# 在场清单;不强制提交);默认模式不拦(CI 检出工作区干净,无未跟踪文件)
if [ "${WORKTREE}" -eq 1 ]; then
  _ut="$(git -c core.quotepath=off status --porcelain 2>/dev/null | grep -c '^??' || true)"
  if [ "${_ut}" -gt 0 ]; then
    echo "❌ 预演(--worktree)检出 ${_ut} 个未跟踪文件——未跟踪文件不进任何 git diff,在场卡扫描覆盖不到(含新建任务卡);先 git add 再预演——fail-closed" >&2
    exit 1
  fi
fi

# 2. 遍历 diff:收集在场卡 + 标记是否存在非豁免文件
#    正则用 [^/] 严格单级,防 case 的 * 跨斜杠误匹配多级路径
present=""      # 在场卡路径(换行分隔)
nonexempt=0     # 1 = diff 含非豁免文件(存在越界判定需求)
while IFS= read -r -d '' f || [ -n "${f}" ]; do
  if [[ "${f}" =~ ^changes/[^/]+/tasks/TASK-[^/]*\.md$ ]] && [[ "${f}" != */archive/* ]]; then
    # 在场卡(新建或修改);工作区已删除的卡(归档退场)不计——它不再提供边界,
    # 由"缺卡覆盖"闸裁决本次变更是否另有覆盖
    if [ -f "${f}" ]; then
      present+="${f}"$'\n'
    fi
  fi
  case "${f}" in
    README.md|AGENTS.md|docs/*|changes/*) continue ;;  # 豁免(case 为 Pattern Matching,* 可跨斜杠)
  esac
  nonexempt=1
done < "${DIFF_FILES}"

# 3. 覆盖裁决(fail-closed 两道闸)
if [ "${nonexempt}" -eq 1 ]; then
  if [ -z "${present}" ]; then
    echo "❌ 缺任务卡覆盖:diff 触碰代码/配置/CI/依赖等非豁免文件,但本次变更无在场任务卡(新建/修改)——fail-closed" >&2
    echo "   修正方式:为本次变更立项任务卡并声明边界,或确认改动确属文档类后调整提交内容。" >&2
    exit 1
  fi
fi

# 4. 提取在场卡边界(双格式合并;归档件与已删除卡在步骤 2 已排除)
n_cards=0
while IFS= read -r card; do
  [ -z "${card}" ] && continue
  n_cards=$((n_cards+1))
  # 格式一:```boundary 围栏(去首尾围栏行;未闭合围栏取到文件尾)
  sed -n '/^[[:space:]]*```boundary[[:space:]]*$/,/^[[:space:]]*```[[:space:]]*$/p' "${card}" \
    | sed '1d;$d' >> "${RAW}" || true
  # 格式二:## 边界 区块下的 - 列表(taskcard-template 原生格式)
  awk '/^## 边界/{f=1;next} /^## /{f=0} f&&/^- /{sub(/^- /,"");print}' "${card}" >> "${RAW}" || true
done <<< "${present}"

# 5. 去注释与空行(与 boundary-check.sh 比对口径一致),并作第二道裁决
grep -vE '^[[:space:]]*(#|$)' "${RAW}" > "${CLEAN}" || true
if [ "${nonexempt}" -eq 1 ] && [ ! -s "${CLEAN}" ]; then
  echo "❌ 在场任务卡未声明边界(${n_cards} 张在场卡中既无 \`\`\`boundary 围栏、\`## 边界\` 列表也为空)——fail-closed" >&2
  echo "   修正方式:在任务卡中以 \`\`\`boundary 围栏或 \`## 边界\` 区块声明本次变更允许触碰的文件。" >&2
  exit 1
fi

# 6. 输出:豁免段(恒在,boundary-check 据此放行豁免文件)+ 在场卡边界并集
echo "# —— 豁免段(文档/变更工件,不参与越界判定;由 extract-boundary.sh 生成)——"
echo "README.md"
echo "AGENTS.md"
echo "docs/*"
echo "changes/*"
if [ -s "${CLEAN}" ]; then
  cat "${CLEAN}"
fi
