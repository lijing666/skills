#!/usr/bin/env bash
# task-dag-check.test.sh —— 任务卡 DAG 完备性门禁回归测试
# 用法: bash task-dag-check.test.sh
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK="$SCRIPT_DIR/task-dag-check.sh"
WORK="$(mktemp -d /tmp/task-dag-test.XXXXXX)"
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

# mk_spec <需求目录>：写含 AC1/AC2/AC3 的 spec.md
mk_spec() {
  mkdir -p "$1"
  printf -- '---\nstatus: approved\n---\n# S\n\n## 2. 验收标准（AC）\n- AC1: Given a When b Then c\n- AC2: Given a When b Then d\n- AC3: Given a When e Then f\n\n## 3. 非目标\n- 不做 X\n' > "$1/spec.md"
}

# mk_card <需求目录> <编号> <spec_ac JSON数组> <depends_on JSON数组>
mk_card() {
  mkdir -p "$1/tasks"
  printf -- '---\nid: %s\nstatus: pending\nspec: changes/x/spec.md\nspec_ac: %s\ndepends_on: %s\n---\n# %s\n' "$2" "$3" "$4" "$2" > "$1/tasks/$2.md"
}

# ── 场景 1：完备 DAG（2 卡认领 3 AC，依赖合法）→ PASS（单需求目录模式）
d="$WORK/c1"; mk_spec "$d"; mk_card "$d" TASK-001 '[AC1, AC2]' '[]'; mk_card "$d" TASK-002 '[AC3]' '[TASK-001]'
expect "完备 DAG 放行（单需求目录）" 0 "TASK-DAG PASS" "$d"

# ── 场景 2：AC 无卡认领 → 拦（滚动拆卡核心场景）
d="$WORK/c2"; mk_spec "$d"; mk_card "$d" TASK-001 '[AC1]' '[]'
expect "AC 无卡认领拦截（DAG 未闭合）" 1 "无任何任务卡认领" "$d"

# ── 场景 3：spec_ac 引用幻觉 AC → 拦
d="$WORK/c3"; mk_spec "$d"; mk_card "$d" TASK-001 '[AC1, AC2, AC9]' '[]'; mk_card "$d" TASK-002 '[AC3]' '[]'
expect "幻觉 AC 引用拦截" 1 "不存在的 AC" "$d"

# ── 场景 4：depends_on 引用不存在的卡 → 拦
d="$WORK/c4"; mk_spec "$d"; mk_card "$d" TASK-001 '[AC1, AC2]' '[TASK-009]'; mk_card "$d" TASK-002 '[AC3]' '[]'
expect "依赖引用缺失卡拦截" 1 "不存在的卡" "$d"

# ── 场景 5：依赖环 → 拦
d="$WORK/c5"; mk_spec "$d"; mk_card "$d" TASK-001 '[AC1, AC2]' '[TASK-002]'; mk_card "$d" TASK-002 '[AC3]' '[TASK-001]'
expect "依赖环拦截" 1 "依赖环" "$d"

# ── 场景 6：自依赖 → 拦
d="$WORK/c6"; mk_spec "$d"; mk_card "$d" TASK-001 '[AC1, AC2]' '[TASK-001]'; mk_card "$d" TASK-002 '[AC3]' '[]'
expect "自依赖拦截" 1 "依赖环" "$d"

# ── 场景 7：无 tasks/ 未拆卡 → 跳过放行
d="$WORK/c7"; mkdir -p "$d"
expect "未拆卡阶段跳过" 0 "未到拆卡阶段" "$d"

# ── 场景 8：无 spec 的纯缺陷修复（只查 DAG）→ PASS
d="$WORK/c8"; mkdir -p "$d/tasks"
printf -- '---\nid: TASK-001\nstatus: pending\ndepends_on: []\n---\n# 修复\n' > "$d/tasks/TASK-001.md"
expect "无 spec 纯修复只查 DAG" 0 "TASK-DAG PASS" "$d"

# ── 场景 9：卡 spec 字段指向多份 spec → 拦
d="$WORK/c9"; mk_spec "$d"; mk_card "$d" TASK-001 '[AC1, AC2]' '[]'; mk_card "$d" TASK-002 '[AC3]' '[]'
sed -i '' 's|spec: changes/x/spec.md|spec: changes/y/spec.md|' "$d/tasks/TASK-002.md"
expect "多 spec 歧义拦截" 1 "AC 编号歧义" "$d"

# ── 场景 10：项目根模式（changes/ 下多需求遍历）
d="$WORK/c10"; mkdir -p "$d/changes/req-a" "$d/changes/req-b"
mk_spec "$d/changes/req-a"; mk_card "$d/changes/req-a" TASK-001 '[AC1, AC2]' '[]'; mk_card "$d/changes/req-a" TASK-002 '[AC3]' '[]'
mk_spec "$d/changes/req-b"; mk_card "$d/changes/req-b" TASK-001 '[AC1, AC2, AC3]' '[]'
expect "项目根多需求遍历放行" 0 "TASK-DAG PASS" "$d"

# ── 场景 11：项目根模式下一需求未闭合 → 拦并指出需求名
d="$WORK/c11"; mkdir -p "$d/changes/req-a" "$d/changes/req-b"
mk_spec "$d/changes/req-a"; mk_card "$d/changes/req-a" TASK-001 '[AC1]' '[]'
mk_spec "$d/changes/req-b"; mk_card "$d/changes/req-b" TASK-001 '[AC1, AC2, AC3]' '[]'
expect "多需求下定位未闭合需求" 1 "req-a" "$d"

# ── 场景 12：--diff 模式只校验基准以来 diff 涉及的需求（存量未闭合不在本次 diff → 放行）
d="$WORK/c12"; mkdir -p "$d"
( cd "$d" && git init -q . && git config user.email t@t.local && git config user.name t )
mkdir -p "$d/changes/req-old"
mk_spec "$d/changes/req-old"; mk_card "$d/changes/req-old" TASK-001 '[AC1]' '[]'
( cd "$d" && git add -A && git commit -qm init )
mk_spec "$d/changes/req-new"; mk_card "$d/changes/req-new" TASK-001 '[AC1, AC2, AC3]' '[]'
expect "--diff 模式只校验 diff 涉及需求" 0 "TASK-DAG PASS" "$d" --diff HEAD

echo
echo "PASS: $PASS / $TOTAL"
[ "$PASS" = "$TOTAL" ] && echo "ALL PASS" || exit 1
