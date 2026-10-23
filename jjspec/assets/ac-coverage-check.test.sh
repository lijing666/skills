#!/usr/bin/env bash
# ac-coverage-check.test.sh — ac-coverage-check.sh 回归测试
# 在临时 git 仓库中构造场景验证；全部通过输出 ALL PASS，任一失败退出码非 0。
# 覆盖：合规卡放行/幻觉AC拦截/缺清单拦截/条目悬空拦截/条目格式非法拦截/条目非测试文件拦截/
#       纯测试卡放行(仅测试文件early-exit)/豁免改动放行/--test-glob 登记前后对比/
#       缺任务卡覆盖拦截/Spec文件缺失拦截/归档卡不算在场
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/ac-coverage-check.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

git init -q "${WORK}/repo"
cd "${WORK}/repo"
git config user.email test@test && git config user.name test

mkdir -p src/payment tests qa/checks docs changes/R1/tasks
echo pay > src/payment.py
printf '# Spec R1\n- AC-01: 支付成功锁定库存\n- AC-02: 超时退款\n' > changes/R1/spec.md
echo test > tests/test_payment.py
echo custom > qa/checks/payment_check.py
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

# 场景1：合规卡(AC 引用有效 + 清单文件存在) → 通过
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付
risk: low
spec: changes/R1/spec.md
spec_ac: [AC-01, AC-02]
status: in_progress
---

## 边界
- src/payment.py

## 测试文件清单
- tests/test_payment.py
EOF
echo v1 >> src/payment.py && git add -A && git commit -qm "s1 合规"
expect "合规卡放行" 0 "测试对应性检查通过" HEAD~1

# 场景2：spec_ac 引用 Spec 中不存在的 AC → 拦截
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付
risk: low
spec: changes/R1/spec.md
spec_ac: [AC-01, AC-99]
status: in_progress
---

## 边界
- src/payment.py

## 测试文件清单
- tests/test_payment.py
EOF
echo v2 >> src/payment.py && git add -A && git commit -qm "s2 幻觉AC"
expect "幻觉AC拦截" 1 "不存在的 AC-99" HEAD~1

# 场景3：边界覆盖行为文件但未声明 ## 测试文件清单 → 拦截
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付
risk: low
spec: changes/R1/spec.md
spec_ac: [AC-01]
status: in_progress
---

## 边界
- src/payment.py
EOF
echo v3 >> src/payment.py && git add -A && git commit -qm "s3 缺清单"
expect "缺清单拦截" 1 "未声明 ## 测试文件清单" HEAD~1

# 场景4：清单条目指向不存在的文件(待创建承诺落空) → 拦截
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付
risk: low
spec: changes/R1/spec.md
spec_ac: [AC-01]
status: in_progress
---

## 边界
- src/payment.py

## 测试文件清单
- tests/test_missing.py
EOF
echo v4 >> src/payment.py && git add -A && git commit -qm "s4 悬空条目"
expect "条目悬空拦截" 1 "测试文件不存在" HEAD~1

# 场景5：清单条目为散文(格式非法) → 拦截且明确报"格式非法"而非"不存在"
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付
risk: low
spec: changes/R1/spec.md
spec_ac: [AC-01]
status: in_progress
---

## 边界
- src/payment.py

## 测试文件清单
- 这是一个说明性散文条目
EOF
echo v5 >> src/payment.py && git add -A && git commit -qm "s5 格式非法"
expect "条目格式非法拦截" 1 "格式非法" HEAD~1

# 场景6：清单条目是源码文件(把行为文件声明成自己的看护) → 拦截
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付
risk: low
spec: changes/R1/spec.md
spec_ac: [AC-01]
status: in_progress
---

## 边界
- src/payment.py

## 测试文件清单
- src/payment.py
EOF
echo v6 >> src/payment.py && git add -A && git commit -qm "s6 非测试条目"
expect "条目非测试文件拦截" 1 "不是测试文件" HEAD~1

# 场景7：纯测试卡(边界只含测试文件) → 无需清单,通过
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 补测试用例
risk: low
spec: changes/R1/spec.md
spec_ac: [AC-01]
status: in_progress
---

## 边界
- tests/*
EOF
echo "test new case" >> tests/test_payment.py && git add -A && git commit -qm "s7 纯测试"
expect "纯测试卡放行" 0 "未触碰行为文件" HEAD~1

# 场景8：纯文档改动(全豁免,无卡) → 通过
echo doc2 >> docs/n.md && git add -A && git commit -qm "s8 纯文档"
expect "豁免改动放行" 0 "未触碰行为文件" HEAD~1

# 场景9：非典型测试布局——不登记 --test-glob 则条目被判"不是测试文件";登记后放行
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付
risk: low
spec: changes/R1/spec.md
spec_ac: [AC-01]
status: in_progress
---

## 边界
- src/payment.py

## 测试文件清单
- qa/checks/payment_check.py
EOF
echo v9 >> src/payment.py && git add -A && git commit -qm "s9 非典型布局"
expect "未登记非典型测试布局拦截" 1 "不是测试文件" HEAD~1
expect "--test-glob 登记后放行" 0 "测试对应性检查通过" HEAD~1 --test-glob 'qa/checks/*'

# 场景10：只改行为文件、卡不在本次 diff(不在场) → 拦截
echo v10 >> src/payment.py && git add -A && git commit -qm "s10 卡不在场"
expect "缺任务卡覆盖拦截" 1 "缺任务卡覆盖" HEAD~1

# 场景11：spec: 指向不存在的 Spec 文件 → 拦截
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付
risk: low
spec: changes/R1/missing.md
spec_ac: [AC-01]
status: in_progress
---

## 边界
- src/payment.py

## 测试文件清单
- tests/test_payment.py
EOF
echo v11 >> src/payment.py && git add -A && git commit -qm "s11 Spec缺失"
expect "Spec文件缺失拦截" 1 "Spec 文件缺失" HEAD~1

# 场景12：卡归档退场(移入 archive/)= 不算在场 → 行为变更缺覆盖,拦截
mkdir -p changes/R1/tasks/archive
git mv changes/R1/tasks/TASK-001.md changes/R1/tasks/archive/TASK-001.md
echo v12 >> src/payment.py && git add -A && git commit -qm "s12 卡归档"
expect "归档卡不算在场拦截" 1 "缺任务卡覆盖" HEAD~1

# 场景13：--integration-mark 开启但 AGENTS.md 未登记 → 拦截(fail-closed)
git mv changes/R1/tasks/archive/TASK-001.md changes/R1/tasks/TASK-001.md
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付
risk: high
spec: changes/R1/spec.md
spec_ac: [AC-01]
status: in_progress
---

## 边界
- src/payment.py

## 测试文件清单
- tests/test_payment.py
EOF
echo v13 >> src/payment.py && git add -A && git commit -qm "s13 开关开无登记"
expect "integration开关开未登记拦截" 1 "integration-mark 登记块" HEAD~1 --integration-mark

# 场景14：登记标记 + 高危卡清单无带标记测试 → 拦截
cat > AGENTS.md <<'EOF'
# 项目规则
<!-- integration-mark-begin -->
mark: @pytest.mark.integration
<!-- integration-mark-end -->
EOF
perl -pi -e 's/^title: 支付$/title: 支付 s14/' changes/R1/tasks/TASK-001.md
echo v14 >> src/payment.py && git add -A && git commit -qm "s14 高危无集成标记"
expect "高危卡缺集成标记拦截" 1 "真依赖验证缺失" HEAD~1 --integration-mark

# 场景15：高危卡清单含带标记测试 → 放行
printf '# -*- coding: utf-8 -*-\nimport pytest\n\n@pytest.mark.integration\ndef test_deposit_real_db():\n    assert True\n' > tests/test_payment_integration.py
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付
risk: high
spec: changes/R1/spec.md
spec_ac: [AC-01]
status: in_progress
---

## 边界
- src/payment.py

## 测试文件清单
- tests/test_payment.py
- tests/test_payment_integration.py
EOF
echo v15 >> src/payment.py && git add -A && git commit -qm "s15 合规集成"
expect "高危卡集成标记放行" 0 "测试对应性检查通过" HEAD~1 --integration-mark

# 场景16：不带 --integration-mark → 向后兼容(无标记也放行,现有项目零影响)
perl -pi -e 's/^title: 支付$/title: 支付 s16/' changes/R1/tasks/TASK-001.md
echo v16 >> src/payment.py && git add -A && git commit -qm "s16 向后兼容"
expect "不带开关向后兼容" 0 "测试对应性检查通过" HEAD~1

# 场景17：低危卡无集成标记 + 开关开 → 放行(纯高危口径)
perl -pi -e 's/^risk: high$/risk: low/' changes/R1/tasks/TASK-001.md
echo v17 >> src/payment.py && git add -A && git commit -qm "s17 低危跳过"
# 场景18：纯资产（ui-specs 规格 md）不计入行为文件 → 无行为文件放行（yzz 原型仓真实案例）
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付 s18
risk: high
spec: changes/R1/spec.md
spec_ac: [AC-01]
status: in_progress
---

## 边界
- ui-specs/yzz/pages/p-01.md
EOF
mkdir -p ui-specs/yzz/pages
echo spec > ui-specs/yzz/pages/p-01.md
git add -A && git commit -qm "s18 纯资产"
expect "纯资产不计入行为文件" 0 "diff 未触碰行为文件" HEAD~1

if [ "${FAILED}" -eq 0 ]; then
  echo "ALL PASS"
else
  echo "存在失败场景" >&2
  exit 1
fi