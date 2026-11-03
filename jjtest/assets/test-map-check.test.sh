#!/usr/bin/env bash
# test-map-check.test.sh — test-map-check.sh 回归测试
#
# 场景覆盖：
#       合规地图放行（含「无——缺口:」合法挂起形态）
#       缺节拦截 / 空节无理由拦截 / frontmatter 缺失拦截
#       分期计划缺第二期行拦截 / 缺完成条件锚点拦截
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/test-map-check.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

FAILED=0
expect() { # expect <场景名> <期望退出码> <输出须含的模式(空=不查)> <地图路径…>
  local name="$1" want="$2" pat="${3:-}"; shift 3
  local rc out
  out="$(bash "${SCRIPT}" "$@" 2>&1)" && rc=0 || rc=$?
  if [ "${rc}" -eq "${want}" ] && { [ -z "${pat}" ] || grep -q "${pat}" <<< "${out}"; }; then
    echo "PASS: ${name}"
  else
    echo "FAIL: ${name}(期望退出码 ${want}、输出含「${pat:-—}」，实际 ${rc})"
    echo "---- 输出 ----"; echo "${out}"; echo "--------------"
    FAILED=1
  fi
}

mk_map() { # mk_map <目录> —— 构造合规测试地图（含合法缺口挂起形态）
  local d="$1"
  mkdir -p "${d}/quality"
  cat > "${d}/quality/test-map.md" <<'EOF'
---
title: 测试项目 测试地图
generated_at: 2026-10-25
---
# 测试项目 测试地图

## 业务域
- 订单：核心旅程 下单/支付；关键程度 高（依据：资金）
- 客服：无自动化条件——缺口: 无测试环境

## 接口契约
- 订单 API：OpenAPI api/orders.yaml；消费者 小程序/Web；错误响应要求 400/401/409
- 消息推送 API：无契约——缺口: 契约文件待补

## 测试现状
- 单元：核心计价模块覆盖；集成：无——缺口: CI 无 testcontainers；契约：无——缺口: 待第一期；E2E：无——缺口: 待第一期

## 风险
- 订单: 金额计算精度与幂等（等级: 高）
- 客服: 第三方依赖超时未降级（等级: 中）

## 运行平台
- 小程序：测试面 = 主干下单链路；Web：管理后台

## 自动化条件
- 测试环境：preview 可用；测试账号：池化 5 个；数据初始化/清理：脚本就绪

## 分期计划
- 第一期：订单域 E2E 冒烟 3 旅程 + 订单/支付核心接口运行时契约校验 + 契约静态/漂移门禁
- 第一期完成条件：
  - [ ] 核心用户旅程可重复执行（同环境重跑结果一致）
  - [ ] 核心接口具备运行时契约校验
  - [ ] CI 能阻断必需测试失败
  - [ ] 报告与失败证据可追溯
- 第二期：客服域回归级 E2E + flaky 治理
EOF
}

# 场景1：合规地图（含合法缺口挂起形态）→ 放行
mk_map "${WORK}/ok"
expect "合规地图放行" 0 "结构校验通过" "${WORK}/ok/quality/test-map.md"

# 场景2：缺节 → 拦截
mk_map "${WORK}/miss"
grep -v '^## 风险' "${WORK}/miss/quality/test-map.md" > "${WORK}/miss/tm.tmp" && mv "${WORK}/miss/tm.tmp" "${WORK}/miss/quality/test-map.md"
expect "缺「## 风险」节拦截" 1 "缺「## 风险」节" "${WORK}/miss/quality/test-map.md"

# 场景3：空节无理由 → 拦截
mk_map "${WORK}/empty"
awk '/^## 测试现状$/{print; print ""; next} 1' "${WORK}/empty/quality/test-map.md" \
  | sed '/^- 单元：核心计价模块覆盖/,+0d; /^- 消息推送 API/d' > "${WORK}/empty/tm.tmp" && mv "${WORK}/empty/tm.tmp" "${WORK}/empty/quality/test-map.md"
expect "空节无显式理由拦截" 1 "节为空且无" "${WORK}/empty/quality/test-map.md"

# 场景4：frontmatter 缺 generated_at → 拦截
mk_map "${WORK}/nofm"
sed '/^generated_at:/d' "${WORK}/nofm/quality/test-map.md" > "${WORK}/nofm/tm.tmp" && mv "${WORK}/nofm/tm.tmp" "${WORK}/nofm/quality/test-map.md"
expect "frontmatter 缺 generated_at 拦截" 1 "generated_at" "${WORK}/nofm/quality/test-map.md"

# 场景5：分期计划缺第二期行 → 拦截
mk_map "${WORK}/nophase"
grep -v '^- 第二期' "${WORK}/nophase/quality/test-map.md" > "${WORK}/nophase/tm.tmp" && mv "${WORK}/nophase/tm.tmp" "${WORK}/nophase/quality/test-map.md"
expect "分期计划缺第二期行拦截" 1 "第二期" "${WORK}/nophase/quality/test-map.md"

# 场景6：缺完成条件锚点 → 拦截（全文替换锚点词，含第一期范围行的同词命中）
mk_map "${WORK}/noanchor"
sed 's/运行时契约校验/契约执行校验（改写逃逸形态）/g' "${WORK}/noanchor/quality/test-map.md" > "${WORK}/noanchor/tm.tmp" && mv "${WORK}/noanchor/tm.tmp" "${WORK}/noanchor/quality/test-map.md"
expect "完成条件缺运行时契约校验锚点拦截" 1 "运行时契约校验" "${WORK}/noanchor/quality/test-map.md"

# 场景7：文件不存在 → exit 2
expect "文件不存在 exit 2" 2 "不存在" "${WORK}/ghost.md"

# ── 终裁 ──
if [ "${FAILED}" -eq 1 ]; then
  echo "❌ test-map-check 回归测试存在失败" >&2
  exit 1
fi
echo "ALL PASS"
