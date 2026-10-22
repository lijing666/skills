#!/usr/bin/env bash
# task-dag-check.sh —— 任务卡 DAG 完备性门禁（⑥任务卡 DAG → ⑦分级执行 的硬门，fail-closed）
# 封堵目标：滚动拆卡——上下文压力下「拆几张就开工、做一张停一张」（实战：20 分册 PRD 只拆 7 卡即开工）
# 校验清单（唯一口径；跨平台兜底自编校验时不得增删项）：
#   1. AC 反向完备性（需求有 spec.md 时）：spec「验收标准（AC）」节的每条 AC 编号至少被一张
#      任务卡 frontmatter spec_ac 认领；卡 spec_ac 引用不存在的 AC 编号同样拦截
#   2. 卡 spec 字段一致性：所有卡 frontmatter spec 指向同一份 spec（防多 Spec 的 AC 编号歧义）
#   3. DAG 闭合性：depends_on 引用不存在的卡即失败；依赖环（含自依赖）即失败（Kahn 拓扑排序）
#   无 tasks/ 目录 = 未拆卡阶段，跳过放行（门禁对象是「开工而 DAG 未闭合」，不是「未拆卡」）；
#   无 spec.md 的纯缺陷修复需求只查 DAG 闭合性
# 用法：task-dag-check.sh <项目根或需求目录> [--diff <基准>]
#   --diff <基准>：仅校验基准以来 diff 涉及的需求目录（CI 批量模式）；无开关全量校验
set -u

FAIL=0
detail=""

fail() { FAIL=1; detail="${detail}FAIL: $1
"; }

TARGET="${1:-}"
DIFF_BASE=""
[ "${2:-}" = "--diff" ] && DIFF_BASE="${3:-}"

if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "用法: $0 <项目根或需求目录> [--diff <基准commit>]" >&2
  exit 2
fi
cd "$TARGET" || exit 2

# ── 定位需求目录集合：参数本身含 tasks/ → 单需求；否则遍历 changes/*/（含 tasks/ 者）──
req_dirs=""
if [ -d "tasks" ]; then
  req_dirs="."
elif [ -d "changes" ]; then
  if [ -n "$DIFF_BASE" ]; then
    diff_ids="$(git diff --name-only "$DIFF_BASE" -- changes/ 2>/dev/null | sed -n 's|^changes/\([^/]*\)/.*|\1|p' | sort -u)"
    for id in $diff_ids; do
      [ -d "changes/$id/tasks" ] && req_dirs="$req_dirs changes/$id"
    done
  else
    for d in changes/*/; do
      [ -d "${d}tasks" ] && req_dirs="$req_dirs ${d%/}"
    done
  fi
fi

if [ -z "$req_dirs" ]; then
  echo "TASK-DAG PASS（无任务卡需求，未到拆卡阶段）"
  exit 0
fi

for req in $req_dirs; do
  label="${req#./}"
  [ "$label" = "." ] && label="<需求目录>"

  # ── 收集卡与 frontmatter 字段 ──
  cards="$(ls "$req/tasks" 2>/dev/null | grep -E '^TASK-[0-9]+.*\.md$' | grep -oE 'TASK-[0-9]+' | sort -u)"
  [ -z "$cards" ] && continue

  # 依赖边：<卡> <dep1> <dep2> ...（供 awk Kahn）
  dep_lines=""
  spec_fields=""
  spec_ac_all=""
  for f in "$req"/tasks/TASK-*.md; do
    t="$(basename "$f" .md)"
    deps="$(sed -n 's/^depends_on:[[:space:]]*\[\(.*\)\].*/\1/p' "$f" | tr ',' ' ' | tr -s ' ')"
    dep_lines="${dep_lines}${t} ${deps}
"
    sp="$(sed -n 's/^spec:[[:space:]]*//p' "$f" | head -1)"
    [ -n "$sp" ] && spec_fields="$spec_fields$sp
"
    acs="$(sed -n 's/^spec_ac:[[:space:]]*\[\(.*\)\].*/\1/p' "$f" | tr ',' '\n' | tr -d ' ' | grep -v '^$')"
    spec_ac_all="$spec_ac_all
$acs"
  done

  # ── 校验 3：DAG 闭合性 ──
  # 3a. 引用存在性
  for dep in $(printf '%s\n' "$dep_lines" | awk 'NR>1 || NF>1 {for(i=2;i<=NF;i++) print $i}' | sort -u); do
    if ! printf '%s\n' "$cards" | grep -qx "$dep"; then
      fail "$label: depends_on 引用不存在的卡 $dep"
    fi
  done
  # 3b. 环检测（Kahn：删入度0节点，剩余即环）
  cycles="$(printf '%s\n' "$dep_lines" | awk '
    NF >= 1 {
      t=$1; if(!(t in deg)) deg[t]=0
      for(i=2;i<=NF;i++){ d=$i; if(!(d in deg)) deg[d]=0; deg[t]++; adj[d]=adj[d]" "t }
    }
    END {
      do {
        progress=0
        for(t in deg) if(!done[t] && deg[t]==0){ done[t]=1; progress=1; m=split(adj[t],a," "); for(i=1;i<=m;i++) deg[a[i]]-- }
      } while(progress)
      for(t in deg) if(!done[t]) print t
    }')"
  [ -n "$cycles" ] && fail "$label: 依赖环（含自依赖），涉及卡: $(printf '%s ' $cycles)"

  # ── 校验 2：卡 spec 字段一致性 ──
  n_specs="$(printf '%s\n' "$spec_fields" | sed '/^$/d' | sort -u | wc -l | tr -d ' ')"
  if [ "$n_specs" -gt 1 ]; then
    fail "$label: 任务卡 spec 字段指向多份 spec（${n_specs}），AC 编号歧义:
$(printf '%s\n' "$spec_fields" | sed '/^$/d' | sort -u | sed 's/^/  /')"
  fi

  # ── 校验 1：AC 反向完备性（有 spec.md 时）──
  if [ -f "$req/spec.md" ]; then
    spec_acs="$(sed -n '/^## 2[.:、) ]*.*验收标准/,/^## /p' "$req/spec.md" | grep -E '^- *AC[0-9]+' | grep -oE 'AC[0-9]+' | sort -u)"
    if [ -n "$spec_acs" ]; then
      claimed="$(printf '%s\n' "$spec_ac_all" | sed '/^$/d' | sort -u)"
      # 1a. 无卡认领的 AC
      unclaimed="$(comm -23 <(printf '%s\n' "$spec_acs") <(printf '%s\n' "$claimed" | sed '/^$/d'))"
      [ -n "$unclaimed" ] && fail "$label: spec 的 AC 无任何任务卡认领（DAG 未闭合，禁止滚动开工）:
$(printf '%s\n' "$unclaimed" | sed 's/^/  /')"
      # 1b. 幻觉 AC 引用
      ghost="$(comm -13 <(printf '%s\n' "$spec_acs") <(printf '%s\n' "$claimed" | sed '/^$/d'))"
      [ -n "$ghost" ] && fail "$label: 任务卡 spec_ac 引用了 spec 不存在的 AC:
$(printf '%s\n' "$ghost" | sed 's/^/  /')"
    fi
  fi
done

if [ "$FAIL" -eq 1 ]; then
  printf '%s' "$detail"
  echo "TASK-DAG FAIL"
  exit 1
fi
echo "TASK-DAG PASS（AC 反向完备 + DAG 闭合 + spec 一致 全绿）"
exit 0
