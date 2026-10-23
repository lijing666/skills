#!/usr/bin/env bash
# release-evidence.test.sh — release-evidence.sh 回归测试
# 全部通过输出 ALL PASS，任一失败退出码非 0。
# 覆盖：完整需求放行/AC无证据缺口/高危卡缺变异行缺口/观测节缺失缺口/采集落点未认领缺口/
#       观测节留白缺口/spec无AC缺口/--strict 拦截/非strict 显影放行
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/release-evidence.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}"

FAILED=0
expect() { # expect <场景名> <期望退出码> <输出须含的模式(空=不查)> [参数...]
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

# ── 完整需求 fixture ──
mkdir -p changes/R1/tasks tests
cat > changes/R1/spec.md <<'EOF'
## 2. 验收标准
- AC-01: Given 下单 When 支付定金 Then 库存锁定
- AC-02: Given 超时 When 回调迟到 Then 退款
EOF
cat > changes/R1/hld.md <<'EOF'
## 6. 观测与灰度声明
### 开关与灰度策略
- 新功能默认带特性开关、默认关合入
### 观测指标表
| 指标 | 阈值（承接 AC-xx） | 采集落点 | 数据来源 |
|---|---|---|---|
| 支付成功率 | ≥99.5%（AC-01） | src/payment.py | 回调日志 |
- 负责人：李晶
- 结束条件：正向 = 48h 全绿转正；负向 = 越阈关开关
EOF
cat > changes/R1/tasks/TASK-001.md <<'EOF'
---
id: TASK-001
title: 支付
risk: high
spec: changes/R1/spec.md
spec_ac: [AC-01, AC-02]
status: done
---

## 边界
- src/payment.py

## 测试文件清单
- tests/test_payment_integration.py

## 验收
- 支付成功库存锁定(AC-01) → 证据:测试全绿
- 超时退款(AC-02) → 证据:race_test 通过

## 执行进度
- 验证证据:mutation-gate 存活率 18% ≤ 30% PASS
EOF
printf 'import pytest\n\n@pytest.mark.integration\ndef test_x():\n    assert True\n' > tests/test_payment_integration.py
cat > AGENTS.md <<'EOF'
<!-- integration-mark-begin -->
mark: @pytest.mark.integration
<!-- integration-mark-end -->
EOF

# 场景1：完整需求 → 无缺口
expect "完整需求无缺口" 0 "证据链完整" changes/R1

# 场景2：AC-02 验收证据被删 → 缺口
perl -0pi -e 's/- 超时退款\(AC-02\) → 证据:race_test 通过\n//' changes/R1/tasks/TASK-001.md
expect "AC无证据缺口" 0 "AC-02] 认领卡验收节无对应证据行" changes/R1
perl -0pi -e 's/(- 支付成功库存锁定\(AC-01\) → 证据:测试全绿\n)/$1- 超时退款(AC-02) → 证据:race_test 通过\n/' changes/R1/tasks/TASK-001.md

# 场景3：高危卡删变异行 → 缺口
perl -0pi -e 's/- 验证证据:mutation-gate 存活率 18% ≤ 30% PASS\n//' changes/R1/tasks/TASK-001.md
expect "高危卡缺变异行缺口" 0 "缺变异存活率行" changes/R1
perl -0pi -e 's/(## 执行进度\n)/$1- 验证证据:mutation-gate 存活率 18% ≤ 30% PASS\n/' changes/R1/tasks/TASK-001.md

# 场景4：HLD 无观测节内容 → 缺口
mv changes/R1/hld.md "${WORK}/hld.bak"
echo "# 技术方案\n\n## 1. 设计概览\n(无观测节)" > changes/R1/hld.md
expect "观测节缺失缺口" 0 "无「观测与灰度声明」节" changes/R1
mv "${WORK}/hld.bak" changes/R1/hld.md

# 场景5：采集落点未认领（改成边界外文件）→ 缺口
perl -pi -e 's/\| src\/payment.py \|/| src\/other.py |/' changes/R1/hld.md
expect "采集落点未认领缺口" 0 "无卡边界认领" changes/R1
perl -pi -e 's/\| src\/other.py \|/| src\/payment.py |/' changes/R1/hld.md

# 场景6：观测节缺负责人 → 缺口
perl -0pi -e 's/- 负责人：李晶\n//' changes/R1/hld.md
expect "负责人缺失缺口" 0 "缺「负责人」行" changes/R1
perl -0pi -e 's/(- 结束条件)/- 负责人：李晶\n$1/' changes/R1/hld.md

# 场景7：spec 无 AC → 缺口
mv changes/R1/spec.md "${WORK}/spec.bak"
echo "## 验收标准\n(无 AC)" > changes/R1/spec.md
expect "spec无AC缺口" 0 "无 AC 定义" changes/R1
mv "${WORK}/spec.bak" changes/R1/spec.md

# 场景8：--strict + 缺口（重新制造一个缺口）→ exit 1
perl -0pi -e 's/- 验证证据:mutation-gate 存活率 18% ≤ 30% PASS\n//' changes/R1/tasks/TASK-001.md
expect "strict 缺口拦截" 1 "缺口(--strict)" changes/R1 --strict

# 场景9：--strict + 完整 → exit 0
perl -0pi -e 's/(## 执行进度\n)/$1- 验证证据:mutation-gate 存活率 18% ≤ 30% PASS\n/' changes/R1/tasks/TASK-001.md
expect "strict 完整放行" 0 "证据包生成完成" changes/R1 --strict

if [ "${FAILED}" -eq 0 ]; then
  echo "ALL PASS"
else
  echo "SOME FAILED"
  exit 1
fi
