#!/usr/bin/env bash
# boundary-check.sh — 越界改动检测门禁（fail-closed：检查不了 = 不通过）
# 用途：PR 的 diff 文件清单对照任务卡声明的边界（boundary 文件，一行一个 glob），超出即失败。
# 用法：boundary-check.sh <base_ref> <boundary_file> [--worktree]
#   base_ref      比较基准，如 origin/main
#   boundary_file 任务卡"边界"区块导出的文件，一行一个 glob（支持 fnmatch，如 modules/payment/*）
#   --worktree    预演口径（本地预演专用，开关型）：diff 基准改为 merge-base(base_ref,HEAD)→工作区，
#                 覆盖已提交+已暂存+未暂存变更，且不含 base 落后的反向假 diff；未跟踪文件不进任何
#                 git diff，检出即拦（先 git add 再预演）。默认（CI）口径 = base_ref...HEAD 不变——
#                 CI 工作区干净，两口径等价，CI 调用零改动；默认模式下检出未提交变更仅警告不拦截
# CI 集成见 ci-snippets/github-actions-boundary.yml；回归测试见 boundary-check.test.sh
set -euo pipefail

BASE="${1:?用法: boundary-check.sh <base_ref> <boundary_file> [--worktree]}"
BOUNDARY="${2:?用法: boundary-check.sh <base_ref> <boundary_file> [--worktree]}"
shift 2
WORKTREE=0
while [ $# -gt 0 ]; do
  case "${1}" in
    --worktree) WORKTREE=1 ;;
    *) echo "❌ 未知参数:${1}(用法:boundary-check.sh <base_ref> <boundary_file> [--worktree])" >&2; exit 1 ;;
  esac
  shift
done

[ -f "${BOUNDARY}" ] || { echo "❌ 边界文件不存在: ${BOUNDARY}"; exit 1; }

# 临时文件用 mktemp（防并发 CI 互相干扰），trap 兜底清理
PATTERNS="$(mktemp)" ; DIFF_FILES="$(mktemp)"
trap 'rm -f "${PATTERNS}" "${DIFF_FILES}"' EXIT

# 1. 读取边界清单（忽略空行与注释）
grep -vE '^[[:space:]]*(#|$)' "${BOUNDARY}" > "${PATTERNS}" || true
[ -s "${PATTERNS}" ] || { echo "❌ 边界文件为空（任务卡未声明边界）"; exit 1; }

# 2. 获取 diff 文件清单——获取失败必须显式失败，禁止静默放行（fail-closed）
#    默认（CI）口径 = BASE...HEAD（仅已提交）；--worktree 预演口径 = merge-base(BASE,HEAD)→工作区
#    --no-renames      ：重命名拆成"删旧路径+增新路径"，两侧都参与边界判定（防改名搬运越界内容）
#    -z + read -d ''   ：NUL 分隔读取，含引号/反斜杠/制表符的路径不做任何转义（防误判越界）
if [ "${WORKTREE}" -eq 1 ]; then
  MB="$(git merge-base "${BASE}" HEAD 2>/dev/null)" || {
    echo "❌ 越界检测未能执行：git merge-base 失败（基准 ${BASE} 与 HEAD 无共同祖先？）——检查失败按不通过处理"
    exit 1
  }
  DIFF_TARGET=("${MB}")
else
  DIFF_TARGET=("${BASE}...HEAD")
  # 预演忘加 --worktree 的防呆：工作区有未提交变更时警告（不拦截——CI 干净工作区无感）
  _dirty="$(git -c core.quotepath=off status --porcelain 2>/dev/null | grep -c . || true)"
  if [ "${_dirty}" -gt 0 ]; then
    echo "⚠️ 检测到 ${_dirty} 个未提交变更未纳入本次检查——默认口径仅覆盖已提交 diff(${BASE}...HEAD)；本地预演请加 --worktree" >&2
  fi
fi
if ! git -c core.quotepath=off diff --name-only --no-renames -z "${DIFF_TARGET[@]}" > "${DIFF_FILES}" 2>/dev/null; then
  echo "❌ 越界检测未能执行：git diff 失败（基准 ${BASE} 是否存在？）——检查失败按不通过处理"
  exit 1
fi
# 未跟踪文件任何 git diff 都不可见——预演模式 fail-closed（先 git add 使其进入工作区 diff）；
# 默认模式不拦（CI 检出工作区干净，无未跟踪文件）
if [ "${WORKTREE}" -eq 1 ]; then
  _ut="$(git -c core.quotepath=off status --porcelain 2>/dev/null | grep -c '^??' || true)"
  if [ "${_ut}" -gt 0 ]; then
    echo "❌ 预演（--worktree）检出 ${_ut} 个未跟踪文件——未跟踪文件不进任何 git diff，预演覆盖不到；先 git add 再预演——fail-closed"
    exit 1
  fi
fi

# 3. 逐文件对照边界 glob（NUL 分隔：文件名中的引号/反斜杠/换行以外特殊字符均原样保留）
violations=0
while IFS= read -r -d '' file || [ -n "${file}" ]; do
  allowed=0
  while IFS= read -r pattern; do
    case "${file}" in
      ${pattern}) allowed=1; break ;;
    esac
  done < "${PATTERNS}"
  if [ "${allowed}" -eq 0 ]; then
    echo "🚫 越界改动: ${file}"
    violations=$((violations+1))
  fi
done < "${DIFF_FILES}"

if [ "${violations}" -gt 0 ]; then
  echo ""
  echo "❌ 越界检测失败：${violations} 个文件超出任务卡边界（声明见 ${BOUNDARY}）"
  echo "   修正方式：撤销越界改动，或将该文件正式加入任务卡边界并说明理由。"
  exit 1
fi
echo "✅ 越界检测通过：改动均在任务卡边界内"
