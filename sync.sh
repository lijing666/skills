#!/bin/zsh
# 同步技能到目标目录。
# 用法：./sync.sh [技能名...] [--to 目标目录]
#   ./sync.sh              只同步 jjspec（默认；多数使用者只需要它）
#   ./sync.sh jjpr         只同步 jjpr
#   ./sync.sh all          同步仓库内全部技能（技能维护者用）
#   --to <目录>            目标目录，默认 ~/.workbuddy/skills/
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.workbuddy/skills"
SKILLS=()

# 解析参数：--to 指定目标目录，其余均为技能名
while [[ $# -gt 0 ]]; do
  case "$1" in
    --to) [[ $# -ge 2 ]] || { echo "用法：--to 需跟目标目录" >&2; exit 1; }; TARGET="$2"; shift 2 ;;
    *) SKILLS+=("$1"); shift ;;
  esac
done

# 收集仓库内全部技能（非隐藏目录），用于 all 展开与校验提示
ALL_SKILLS=()
for d in "$REPO_DIR"/*/; do
  name="$(basename "$d")"
  [[ "$name" == ".*" ]] && continue
  ALL_SKILLS+=("$name")
done

# 默认只同步 jjspec：多数使用者只用这一个技能；all 展开为全部
[[ ${#SKILLS[@]} -eq 0 ]] && SKILLS=(jjspec)
[[ " ${SKILLS[*]} " == *" all "* ]] && SKILLS=("${ALL_SKILLS[@]}")

# 技能名校验：拼错立即报错，不静默跳过
for s in "${SKILLS[@]}"; do
  [[ -d "$REPO_DIR/$s" ]] || { echo "未知技能：$s（可用：${ALL_SKILLS[*]}）" >&2; exit 1; }
done

mkdir -p "$TARGET"
for s in "${SKILLS[@]}"; do
  echo "同步 $s -> $TARGET/$s"
  rm -rf "$TARGET/$s"
  cp -R "$REPO_DIR/$s" "$TARGET/$s"
done
echo "完成：${SKILLS[*]} 已同步到 $TARGET"
