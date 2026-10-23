#!/usr/bin/env bash
# mutation-gate.test.sh — mutation-gate.sh 回归测试
# 在临时 git 仓库中构造场景验证；全部通过输出 ALL PASS，任一失败退出码非 0。
# 覆盖：无在场卡放行/非高危卡跳过/高危纯文档卡跳过/缺登记拦截/显式豁免放行/
#       合规达标放行/存活率超标拦截/引擎命令失败拦截/报告缺失拦截/JSON非法拦截/
#       零变体拦截/基线期只记录/超时拦截/缺risk字段拦截/risk值非法拦截/
#       --exclude-glob 出口/登记块不完整拦截/--worktree 工作区自检
# 场景构造纪律：每个"高危在场"场景须同时使任务卡与行为文件进入 diff
#   （改配置文件不进 diff——豁免项，只改它们会造成 early-exit 假场景）。
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/mutation-gate.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

git init -q "${WORK}/repo"
cd "${WORK}/repo"
git config user.email test@test && git config user.name test

mkdir -p src/payment tests tools changes/R1/tasks docs
echo pay > src/payment.py
echo test > tests/test_payment.py
echo doc > docs/n.md
git add -A && git commit -qm "init"

FAILED=0
expect() { # expect <场景名> <期望退出码> <输出须含的模式(空=不查)> [脚本附加参数...,首个为 base]
  local name="$1" want="$2" pat="${3:-}"; shift 3
  local rc out
  out="$(bash "${SCRIPT}" "$@" 2>&1)" && rc=0 || rc=$?
  if [ "${rc}" -eq "${want}" ] && { [ -z "${pat}" ] || grep -q "${pat}" <<< "${out}"; }; then
    echo "PASS: ${name}"
  else
    echo "FAIL: ${name}(期望退出码 ${want}、输出含「${pat:-—}」,实际 ${rc})"
    echo "---- 输出 ----"; echo "${out}"; echo "--------------"
    FAILED=1
  fi
}

SV=0
bump() { SV=$((SV+1)); echo "v${SV}" >> src/payment.py; }   # 行为文件改动计数器(每场景递增,保证进入 diff)

hi_card() { # hi_card <risk值> — 生成带场景唯一标记的高危/低危卡(标记变 = 卡进 diff)
  cat > changes/R1/tasks/TASK-001.md <<EOF
---
id: TASK-001
title: 支付 s${SV}
risk: ${1}
spec: changes/R1/spec.md
spec_ac: [AC-01]
status: in_progress
---

## 边界
- src/payment.py
EOF
}

register() { # register <engine> [command] — command 缺省/显式空 = command 行留空(登记不完整场景用)
  local cmd="${2-}"
  cat > AGENTS.md <<EOF
# 项目规则
<!-- mutation-engine-begin -->
engine: ${1}
command: ${cmd}
report: mutation-report.json
threshold: 30
timeout: 600
enforcement_date:
<!-- mutation-engine-end -->
EOF
}

mock_report() { # mock_report <total> <killed> <survived>
  cat > tools/gen-report.sh <<EOF
#!/usr/bin/env bash
printf '%s' '{"total": ${1}, "killed": ${2}, "survived": ${3}}' > mutation-report.json
EOF
  chmod +x tools/gen-report.sh
}

# 场景1：无在场卡（纯文档改动）→ 通过
echo v >> docs/n.md && git add -A && git commit -qm "s1"
expect "无在场卡放行" 0 "无在场任务卡" HEAD~1

# 场景2：非高危卡触碰行为文件 → 跳过放行（纯高危口径）
bump; hi_card low; git add -A && git commit -qm "s2"
expect "非高危卡跳过" 0 "非高危,纯高危口径不检" HEAD~1

# 场景3：高危卡在场但 diff 未触碰其边界内行为文件（仅文档）→ 跳过放行
hi_card high; echo v >> docs/n.md; git add -A && git commit -qm "s3"
expect "高危纯文档卡跳过" 0 "无高危行为卡待检" HEAD~1

# 场景4：高危卡 + 行为文件 + 无 AGENTS.md 登记块 → 拦截
bump; hi_card high; git add -A && git commit -qm "s4"
expect "缺登记拦截" 1 "无 mutation-engine 登记块" HEAD~1

# 场景5：登记 engine: 无（显式豁免）→ 警告放行
bump; hi_card high; register "无（暂无可用引擎,冷启动攒基线）"; git add -A && git commit -qm "s5"
expect "显式豁免放行" 0 "豁免放行" HEAD~1

# 场景6：登记完整 + 存活率 20% ≤ 30% → 通过
bump; hi_card high; register mockmut "sh tools/gen-report.sh {targets}"; mock_report 10 8 2; git add -A && git commit -qm "s6"
expect "存活率达标放行" 0 "断言强度门禁通过" HEAD~1

# 场景7：存活率 60% > 30% → 拦截
bump; hi_card high; mock_report 10 4 6; git add -A && git commit -qm "s7"
expect "存活率超标拦截" 1 "测试空转嫌疑" HEAD~1

# 场景8：引擎命令失败（退出码非 0）→ 拦截
bump; hi_card high; register mockmut "exit 3"; git add -A && git commit -qm "s8"
expect "引擎命令失败拦截" 1 "引擎命令失败" HEAD~1

# 场景9：命令成功但报告缺失（先删旧报告）→ 拦截
bump; hi_card high; register mockmut "echo running"; rm -f mutation-report.json; git add -A && git commit -qm "s9"
expect "报告缺失拦截" 1 "变异报告缺失" HEAD~1

# 场景10：报告 JSON 缺 total → 拦截
bump; hi_card high; register mockmut "sh tools/gen-report.sh {targets}"
cat > tools/gen-report.sh <<'EOF'
#!/usr/bin/env bash
printf '%s' '{"killed": 8, "survived": 2}' > mutation-report.json
EOF
chmod +x tools/gen-report.sh
git add -A && git commit -qm "s10"
expect "JSON 非法拦截" 1 "JSON 非法" HEAD~1

# 场景11：零变体 → 拦截
bump; hi_card high; mock_report 0 0 0; git add -A && git commit -qm "s11"
expect "零变体拦截" 1 "total=0" HEAD~1

# 场景12：enforcement_date 未来 → 超标只记录不阻断
bump; hi_card high; mock_report 10 4 6; register mockmut "sh tools/gen-report.sh {targets}"
perl -pi -e 's/^enforcement_date:$/enforcement_date: 2099-01-01/' AGENTS.md
git add -A && git commit -qm "s12"
expect "基线期只记录" 0 "只记录存活率不阻断" HEAD~1

# 场景13：timeout=2s + 命令 sleep 10 → 超时拦截（# 后注释掉 {targets},防 BSD sleep 报 usage）
bump; hi_card high; register mockmut "sleep 10 # {targets}"
perl -pi -e 's/^timeout: 600$/timeout: 2/' AGENTS.md
git add -A && git commit -qm "s13"
expect "超时拦截" 1 "超时" HEAD~1

# 场景14：在场卡缺 risk 字段 → 拦截
bump
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付 s14
spec: changes/R1/spec.md
spec_ac: [AC-01]
status: in_progress
---

## 边界
- src/payment.py
EOF
register mockmut "sh tools/gen-report.sh {targets}"; mock_report 10 8 2
git add -A && git commit -qm "s14"
expect "缺 risk 字段拦截" 1 "缺 risk 字段" HEAD~1

# 场景15：risk 值非法 → 拦截
bump; hi_card "疯狂"; register mockmut "sh tools/gen-report.sh {targets}"; mock_report 10 8 2; git add -A && git commit -qm "s15"
expect "risk 值非法拦截" 1 "risk 值非法" HEAD~1

# 场景16：--exclude-glob 排除后目标为空 → 跳过放行
bump; hi_card high; register mockmut "sh tools/gen-report.sh {targets}"; mock_report 10 8 2; git add -A && git commit -qm "s16"
expect "exclude-glob 出口" 0 "无高危行为卡待检" HEAD~1 --exclude-glob '*.py'

# 场景17：登记块缺 command → 拦截
bump; hi_card high; register mockmut ""; git add -A && git commit -qm "s17"
expect "登记不完整拦截" 1 "登记块不完整" HEAD~1

# 场景19.5：纯资产（ui-specs 规格 md）不计入行为文件 → 高危卡跳过（yzz 原型仓真实案例）
bump; hi_card high
mkdir -p ui-specs/yzz/pages
echo spec > ui-specs/yzz/pages/p-01.md
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付 s195
risk: high
spec: changes/R1/spec.md
spec_ac: [AC-01]
status: in_progress
---

## 边界
- ui-specs/yzz/pages/p-01.md
EOF
git add -A && git commit -qm "s19.5 纯资产"
expect "纯资产不计入行为文件" 0 "无高危行为卡待检" HEAD~1

# 场景18：--worktree 工作区改动 + 无登记块（工作区删除 AGENTS.md）→ 拦截
rm AGENTS.md; bump; hi_card high
expect "worktree 工作区自检" 1 "无 mutation-engine 登记块" HEAD --worktree

# 场景19：--worktree + 完整登记 + 达标 → 放行
register mockmut "sh tools/gen-report.sh {targets}"; mock_report 10 8 2; bump; hi_card high
expect "worktree 达标放行" 0 "断言强度门禁通过" HEAD --worktree

if [ "${FAILED}" -eq 0 ]; then
  echo "ALL PASS"
else
  echo "SOME FAILED"
  exit 1
fi
