#!/usr/bin/env bash
# boundary-check.sh — 越界改动检测门禁
# 用途：PR 的 diff 文件清单对照任务卡声明的边界（boundary 文件，一行一个 glob），超出即失败。
# 用法：boundary-check.sh <base_ref> <boundary_file>
#   base_ref      比较基准，如 origin/main
#   boundary_file 任务卡"边界"区块导出的文件，一行一个 glob（支持 fnmatch，如 modules/payment/*）
# CI 集成见 ci-snippets/github-actions-boundary.yml
set -euo pipefail

BASE="${1:?用法: boundary-check.sh <base_ref> <boundary_file>}"
BOUNDARY="${2:?用法: boundary-check.sh <base_ref> <boundary_file>}"

[ -f "$BOUNDARY" ] || { echo "❌ 边界文件不存在: $BOUNDARY"; exit 1; }
# 忽略空行与注释
grep -vE '^\s*(#|$)' "$BOUNDARY" > /tmp/boundary_patterns.txt
[ -s /tmp/boundary_patterns.txt ] || { echo "❌ 边界文件为空（任务卡未声明边界）"; exit 1; }

violations=0
while IFS= read -r file; do
  allowed=0
  while IFS= read -r pattern; do
    case "$file" in
      $pattern) allowed=1; break ;;
    esac
  done < /tmp/boundary_patterns.txt
  if [ "$allowed" -eq 0 ]; then
    echo "🚫 越界改动: $file"
    violations=$((violations+1))
  fi
done < <(git diff --name-only "$BASE"...HEAD)

if [ "$violations" -gt 0 ]; then
  echo ""
  echo "❌ 越界检测失败：$violations 个文件超出任务卡边界（声明见 $BOUNDARY）"
  echo "   修正方式：撤销越界改动，或将该文件正式加入任务卡边界并说明理由。"
  exit 1
fi
echo "✅ 越界检测通过：改动均在任务卡边界内"
