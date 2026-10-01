#!/usr/bin/env bash
# risk-zone-check.test.sh — risk-zone-check.sh 回归测试
# 在临时 git 仓库中构造场景验证；全部通过输出 ALL PASS，任一失败退出码非 0。
# 覆盖：普通改动放行/风险区无标记拦截/带标记放行(subject与body)/混合commit/清单缺标记(fail-closed)/
#       清单为空(fail-closed)/显式"无风险区"放行/基准不存在(fail-closed)/中文路径/merge跳过/报告完整
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/risk-zone-check.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

git init -q "${WORK}/repo"
cd "${WORK}/repo"
git config user.email test@test && git config user.name test

mkdir -p src/normal src/payment docs
echo a > src/normal/a.py
echo b > src/payment/b.py

cat > AGENTS.md <<'EOF'
# AGENTS.md
## 5. 风险区清单（AI 禁改区）
<!-- risk-zones-begin（机器解析区）
     行格式：- <glob> —— <说明> -->
- src/payment/** —— 支付核心：改动须人批准 + 100% 人审
<!-- risk-zones-end -->
EOF
git add -A && git commit -qm "init"

FAILED=0
expect() { # expect <场景名> <期望退出码> <base_ref> [agents_md]
  local name="$1" want="$2" base="$3" agents="${4:-AGENTS.md}" rc out
  out="$(bash "${SCRIPT}" "${base}" "${agents}" 2>&1)" && rc=0 || rc=$?
  if [ "${rc}" -eq "${want}" ]; then
    echo "PASS: ${name}"
  else
    echo "FAIL: ${name}（期望退出码 ${want}，实际 ${rc}）"
    echo "---- 输出 ----"; echo "${out}"; echo "--------------"
    FAILED=1
  fi
}

# 场景1：不触碰风险区的普通改动 → 通过
echo x >> src/normal/a.py && git add -A && git commit -qm "c1: normal change"
expect "普通改动放行" 0 "HEAD~1"

# 场景2：触碰风险区且无 [risk-ok] → 拒绝
echo y >> src/payment/b.py && git add -A && git commit -qm "c2: payment change without marker"
expect "风险区无标记拦截" 1 "HEAD~1"

# 场景3：触碰风险区且 subject 带 [risk-ok] → 放行
echo z >> src/payment/b.py && git add -A && git commit -qm "[risk-ok] c3: payment fix"
expect "带标记放行（subject）" 0 "HEAD~1"

# 场景4：标记在 message body → 放行（%B 全文检索）
echo w >> src/payment/b.py && git add -A && git commit -qm "c4: payment fix" -m "背景说明" -m "[risk-ok] 批准留痕"
expect "带标记放行（body）" 0 "HEAD~1"

# 场景5：混合 commits——普通无标记 + 风险区带标记 → 放行
echo q >> src/normal/a.py && git add -A && git commit -qm "c5: normal"
echo r >> src/payment/b.py && git add -A && git commit -qm "[risk-ok] c6: payment"
expect "混合commit风险区带标记放行" 0 "HEAD~2"

# 场景6：混合 commits——风险区无标记 → 只拦风险区那个 commit
echo s >> src/normal/a.py && git add -A && git commit -qm "c7: normal"
echo t >> src/payment/b.py && git add -A && git commit -qm "c8: payment no marker"
expect "混合commit风险区无标记拦截" 1 "HEAD~2"

# 场景7：AGENTS.md 缺 risk-zones 标记 → fail-closed（禁止静默当作无风险区）
printf '# AGENTS.md\n## 5. 风险区清单\n- src/payment/**\n' > AGENTS-bad.md
expect "清单缺标记fail-closed" 1 "HEAD~1" "AGENTS-bad.md"

# 场景8：标记之间无清单行 → fail-closed
printf '# AGENTS.md\n<!-- risk-zones-begin -->\n<!-- risk-zones-end -->\n' > AGENTS-empty.md
expect "清单为空fail-closed" 1 "HEAD~1" "AGENTS-empty.md"

# 场景9：显式"无风险区"（- 无）→ 一切改动放行
printf '# AGENTS.md\n<!-- risk-zones-begin -->\n- 无\n<!-- risk-zones-end -->\n' > AGENTS-none.md
expect "显式无风险区放行" 0 "HEAD~1" "AGENTS-none.md"

# 场景10：基准分支不存在 → 必须失败（fail-closed）
expect "基准不存在fail-closed" 1 "refs/heads/nonexistent"

# 场景11：风险区内中文文件名 → 正常拦截/放行（core.quotepath=off 处理）
echo u > src/payment/退款逻辑.py && git add -A && git commit -qm "c9: 中文路径无标记"
expect "中文路径无标记拦截" 1 "HEAD~1"
echo v >> src/payment/退款逻辑.py && git add -A && git commit -qm "[risk-ok] c10: 中文路径带标记"
expect "中文路径带标记放行" 0 "HEAD~1"

# 场景12：merge commit 不参与逐 commit 检查（其构成 commit 各自负责）
git checkout -qb side HEAD~1
echo m >> docs/readme.md && git add -A && git commit -qm "side: docs"
git checkout -q -
git merge -q --no-ff side -m "merge: side"
expect "merge跳过不误报" 0 "HEAD^1"

# 场景13：拦截报告完整——退出码、违规路径、错误摘要、无脚本自身报错
echo n > src/payment/new.py && git add -A && git commit -qm "c11: no marker"
out="$(bash "${SCRIPT}" "HEAD~1" 2>&1)" && rc=0 || rc=$?
if [ "${rc}" -eq 1 ] \
   && echo "${out}" | grep -q "src/payment/new.py" \
   && echo "${out}" | grep -q "风险区门禁失败" \
   && ! echo "${out}" | grep -q "unbound variable"; then
  echo "PASS: 拦截报告完整（退出码/违规路径/摘要/无脚本报错）"
else
  echo "FAIL: 拦截报告不完整（退出码=${rc}）"
  echo "---- 输出 ----"; echo "${out}"; echo "--------------"
  FAILED=1
fi

if [ "${FAILED}" -eq 0 ]; then echo "ALL PASS"; else exit 1; fi
