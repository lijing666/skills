#!/usr/bin/env bash
# doc-chain-check.test.sh —— 文档链正主门禁回归测试
# 用法: bash doc-chain-check.test.sh
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK="$SCRIPT_DIR/doc-chain-check.sh"
WORK="$(mktemp -d /tmp/doc-chain-test.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

PASS=0; TOTAL=0

# expect <描述> <期望退出码> <期望输出片段> <目录> [额外参数...]
expect() {
  local desc="$1" want_rc="$2" want_out="$3" dir="$4"; shift 4
  TOTAL=$((TOTAL+1))
  local out rc
  out="$(bash "$CHECK" "$dir" "$@" 2>&1)"; rc=$?
  if [ "$rc" = "$want_rc" ] && printf '%s' "$out" | grep -q "$want_out"; then
    PASS=$((PASS+1)); echo "ok $TOTAL - $desc"
  else
    echo "not ok $TOTAL - $desc"
    echo "  期望: rc=$want_rc 含「$want_out」"
    echo "  实际: rc=$rc"
    printf '%s\n' "$out" | sed 's/^/    /'
  fi
}

# mk_case <名>：建干净仓库（需求 x 全链合规：prd 已定稿+版本表、spec/hld approved+批准表）
mk_case() {
  local d="$WORK/$1"
  mkdir -p "$d/changes/x"
  printf -- '---\nstatus: 已定稿\n---\n# x\n\n## 版本表\n| 版本 | 状态 | 来源 |\n|---|---|---|\n| v1 | 已定稿 | 用户指令 |\n' > "$d/changes/x/prd.md"
  printf -- '---\nstatus: approved\n---\n# Spec x\n' > "$d/changes/x/spec.md"
  printf -- '---\nstatus: approved\n---\n# HLD x\n\n## 方案批准记录\n| 用户及日期 | 版本 | 依据 | 有效性 |\n|---|---|---|---|\n| u 2026-10-21 | v1 | 消息引用 | 有效 |\n' > "$d/changes/x/hld.md"
  echo "$d"
}

# ── 场景 1：干净全链 → PASS
expect "干净仓库四项全绿" 0 "DOC-CHAIN PASS" "$(mk_case c1)"

# ── 场景 2：嵌套同名目录段 → 拦
d="$(mk_case c2)"; mkdir -p "$d/changes/x/x"
expect "嵌套同名目录段拦截" 1 "嵌套同名目录段" "$d"

# ── 场景 2b：文件名含需求 ID 不误伤（x-notes.md 合法）→ PASS
d="$(mk_case c2b)"; mkdir -p "$d/changes/x/docs"; printf 'note\n' > "$d/changes/x/docs/x-notes.md"
expect "文件名含需求 ID 不误伤" 0 "DOC-CHAIN PASS" "$d"

# ── 场景 3：副本（嵌套目录承载 prd 副本）→ 拦
d="$(mk_case c3)"; mkdir -p "$d/changes/x/copy"; cp "$d/changes/x/prd.md" "$d/changes/x/copy/prd.md"
expect "副本检测（子目录另存 prd）拦截" 1 "核心文档出现多份" "$d"

# ── 场景 4：活跃+归档双份并存 → 拦
d="$(mk_case c4)"; mkdir -p "$d/changes/archive/2026-01-01-x"; cp "$d/changes/x/prd.md" "$d/changes/archive/2026-01-01-x/prd.md"
expect "归档残留副本（活跃+归档双份）拦截" 1 "核心文档出现多份" "$d"

# ── 场景 5：悬空批准（spec approved 但 prd 评审中）→ 拦
d="$(mk_case c5)"; sed -i '' 's/^status: 已定稿/status: 评审中/' "$d/changes/x/prd.md"
expect "悬空批准（prd 未定稿）拦截" 1 "悬空批准" "$d"

# ── 场景 6：免 PRD 修复 Spec（无 prd.md，spec approved）→ PASS
d="$WORK/c6"; mkdir -p "$d/changes/fix-1"
printf -- '---\nstatus: approved\n---\n# 修复 Spec\n' > "$d/changes/fix-1/spec.md"
expect "免 PRD 修复 Spec 不误伤" 0 "DOC-CHAIN PASS" "$d"

# ── 场景 7：hld approved 但批准表残留待批准 → 拦
d="$(mk_case c7)"; sed -i '' 's/| u 2026-10-21 | v1 | 消息引用 | 有效 |/| 待批准 |  |  | 待批准 |/' "$d/changes/x/hld.md"
expect "approved 残留待批准行拦截" 1 "残留" "$d"

# ── 场景 8：prd 已定稿但版本表最新行无定稿 → 拦
d="$(mk_case c8)"; sed -i '' 's/| v1 | 已定稿 | 用户指令 |/| v2 | 评审中 | 修订 |/' "$d/changes/x/prd.md"
expect "定稿与版本表不一致拦截" 1 "版本表最新行无「定稿」" "$d"

# ── 场景 9：archive 历史快照的过时状态不误伤（归档内 spec approved + prd 评审中）→ PASS
d="$(mk_case c9)"; mkdir -p "$d/changes/archive/2026-01-01-y"
printf -- '---\nstatus: 评审中\n---\n# y\n' > "$d/changes/archive/2026-01-01-y/prd.md"
printf -- '---\nstatus: approved\n---\n# Spec y\n' > "$d/changes/archive/2026-01-01-y/spec.md"
expect "archive 历史快照状态跳过" 0 "DOC-CHAIN PASS" "$d"

# ── 场景 10：无 changes/ 目录 → PASS
d="$WORK/c10"; mkdir -p "$d"
expect "无 changes 目录放行" 0 "DOC-CHAIN PASS" "$d"

# ── 场景 11：hld draft 但批准表存在生效行（旧批准冒充）→ 拦
d="$(mk_case c11)"; sed -i '' 's/^status: approved/status: draft/' "$d/changes/x/hld.md"
expect "draft 旧批准冒充拦截" 1 "旧批准冒充" "$d"

echo
echo "PASS: $PASS / $TOTAL"
[ "$PASS" = "$TOTAL" ] && echo "ALL PASS" || exit 1
