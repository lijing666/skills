#!/usr/bin/env bash
# risk-zone-check.sh — 风险区门禁（[risk-ok] 唯一合法门；fail-closed：检查不了 = 不通过）
# 用途：逐 commit 对照 AGENTS.md 第 5 节"风险区清单"（risk-zones-begin/end 标记包裹的 glob）——
#       触碰风险区的 commit 必须在 message 中带 [risk-ok] 标记（人批准留痕），无标记即失败。
# 与 boundary-check.sh 的分工：boundary 查"改动是否超出任务卡边界"（白名单）；本脚本查
#       "改动是否擅入风险区且未走唯一门"（黑名单 + 门）。两道门禁并行，互不替代。
# 用法：risk-zone-check.sh <base_ref> [agents_md]
#   base_ref   比较基准，如 origin/main
#   agents_md  AGENTS.md 路径，默认仓库根 AGENTS.md（第 5 节须含 risk-zones-begin/end 标记）
# CI 集成见 ci-snippets/github-actions-risk-zone.yml；回归测试见 risk-zone-check.test.sh
set -euo pipefail

BASE="${1:?用法: risk-zone-check.sh <base_ref> [agents_md]}"
AGENTS="${2:-AGENTS.md}"

[ -f "${AGENTS}" ] || { echo "❌ AGENTS.md 不存在: ${AGENTS}（风险区清单缺失 = 无法执法，fail-closed）"; exit 1; }

# 临时文件用 mktemp（防并发 CI 互相干扰），trap 兜底清理
ZONES="$(mktemp)" ; COMMITS="$(mktemp)" ; FILES="$(mktemp)"
trap 'rm -f "${ZONES}" "${COMMITS}" "${FILES}"' EXIT

# 1. 提取风险区清单——begin/end 标记之间的"- <glob> —— <说明>"行，取 glob（首个 token）
#    标记缺失 = 风险区未显式声明（没写下来 = 不存在）→ fail-closed，禁止静默当作"无风险区"
grep -q 'risk-zones-begin' "${AGENTS}" || { echo "❌ ${AGENTS} 缺少 risk-zones-begin 标记（风险区清单未声明——确无风险区也须显式写 \"- 无\"）"; exit 1; }
grep -q 'risk-zones-end' "${AGENTS}" || { echo "❌ ${AGENTS} 缺少 risk-zones-end 标记"; exit 1; }
sed -n '/risk-zones-begin/,/risk-zones-end/p' "${AGENTS}" \
  | grep -E '^[[:space:]]*-' \
  | sed -E 's/^[[:space:]]*-[[:space:]]*//' \
  | awk 'NF {print $1}' > "${ZONES}" || true
[ -s "${ZONES}" ] || { echo "❌ 风险区清单为空（标记之间无 \"- <glob>\" 行；确无风险区也须显式写 \"- 无\"）"; exit 1; }

# 2. 取范围内全部非 merge commit——获取失败必须显式失败，禁止静默放行（fail-closed）
if ! git -c core.quotepath=off rev-list --no-merges "${BASE}..HEAD" > "${COMMITS}" 2>/dev/null; then
  echo "❌ 风险区门禁未能执行：git rev-list 失败（基准 ${BASE} 是否存在？）——检查失败按不通过处理"
  exit 1
fi

# 3. 逐 commit 比对：改动文件 ∩ 风险区 glob ≠ ∅ 时，message 必须含 [risk-ok]
violations=0; flagged=0
while IFS= read -r commit || [ -n "${commit}" ]; do
  # 该 commit 的完整 message（subject + body，%B）
  if ! msg="$(git log -1 --format=%B "${commit}" 2>/dev/null)"; then
    echo "❌ 风险区门禁未能执行：git log 失败（${commit:0:7}）——检查失败按不通过处理"
    exit 1
  fi
  # 该 commit 的改动文件清单（-z NUL 分隔，防特殊字符路径误判；--root 覆盖仓库首 commit）
  if ! git -c core.quotepath=off diff-tree --no-commit-id --name-only -r --root -z "${commit}" > "${FILES}" 2>/dev/null; then
    echo "❌ 风险区门禁未能执行：git diff-tree 失败（${commit:0:7}）——检查失败按不通过处理"
    exit 1
  fi
  touched=""
  while IFS= read -r -d '' file || [ -n "${file}" ]; do
    while IFS= read -r zone; do
      case "${file}" in
        ${zone}) touched="${touched}${file} " ; break ;;
      esac
    done < "${ZONES}"
  done < "${FILES}"
  [ -n "${touched}" ] || continue
  if printf '%s' "${msg}" | grep -qF '[risk-ok]'; then
    flagged=$((flagged+1))
    echo "⚠️ 风险区改动（[risk-ok] 已标记，人审核验批准事实）：${commit:0:7} → ${touched}"
  else
    violations=$((violations+1))
    echo "🚫 风险区改动且无 [risk-ok] 标记：${commit:0:7} → ${touched}"
  fi
done < "${COMMITS}"

if [ "${violations}" -gt 0 ]; then
  echo ""
  echo "❌ 风险区门禁失败：${violations} 个 commit 触碰风险区且无 [risk-ok] 标记（清单见 ${AGENTS} 第 5 节）"
  echo "   修正方式：撤销风险区改动；或走唯一合法门——获得人批准后，在 commit message 加 [risk-ok] 标记（建议附批准人与理由）。"
  exit 1
fi
if [ "${flagged}" -gt 0 ]; then
  echo "✅ 风险区门禁通过：${flagged} 个 commit 带 [risk-ok] 标记（人审必须核验批准事实）"
else
  echo "✅ 风险区门禁通过：无风险区改动"
fi
