#!/bin/zsh
# 同步技能到目标目录：./sync.sh [目标目录]
# 默认目标：~/.workbuddy/skills/
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$HOME/.workbuddy/skills}"

mkdir -p "$TARGET"

for skill_dir in "$REPO_DIR"/*/; do
  name="$(basename "$skill_dir")"
  [[ "$name" == ".*" ]] && continue
  echo "同步 $name -> $TARGET/$name"
  rm -rf "$TARGET/$name"
  cp -R "$REPO_DIR/$name" "$TARGET/$name"
done

echo "完成：所有技能已同步到 $TARGET"
