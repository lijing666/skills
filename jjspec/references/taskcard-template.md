# 任务卡模板 + DAG 拆卡法

> 用途：步骤 ⑤。**单卡 = 单模块 = 单窗口 = 单 PR**；单卡变更 100~400 行为宜。

## 单卡模板

```markdown
---
id: TASK-04
title: 定金支付流程
risk: high | medium | low        # 高风险→L1 逐卡+100%人审；低→L2 自主循环
depends_on: [TASK-01, TASK-02]   # DAG 依赖，指向被依赖者
spec_ac: [AC1, AC4]              # 本卡验收对应哪些 Spec 的 AC
date: YYYY-MM-DD
---

## 边界（机器可查）
<!-- 允许触碰的文件/目录清单，供 boundary-check.sh 使用；一行一个 glob -->
- modules/payment/deposit.py
- modules/payment/__tests__/deposit_test.py

## 契约
<!-- 输入输出签名，含错误路径 -->
- deposit(order_id: OrderId, amount: Money) -> DepositResult
- raises OrderAlreadyPaid, InsufficientDeposit

## 验收
<!-- 对照 Spec 的 AC，逐条可测 -->
- 定金支付成功后库存锁定、订单进入 deposit_paid（AC1）
- 付尾款瞬间恰好超时：支付被拒且退款（AC4）

## 监督策略
<!-- 人机分工显式化：AI 做什么、人审什么、几轮 -->
- AI：实现 + 自跑测试循环至全绿
- 人：PR 评审重点 = 竞态处理与金额精度（高风险卡 100% 人审）
```

## 拆卡规则

1. **一张卡必须单模块内可完成**——跨两模块 = 两张卡（AI 原稿爱合成大卡，人工必拆）
2. **依赖必须显式成 DAG**：有向（指向被依赖者）、**无环**（T04 等 T05、T05 又等 T04 = 拆错了重拆）
3. DAG 的三个收益：拓扑排序 = 执行顺序；无依赖分支可并行（多会话/多 Agent）；关键路径决定总工期
4. 高风险卡（资金/鉴权/迁移/删除）标注 `risk: high`，禁止 L2 自主执行
5. 每张卡自带测试要求——"新代码测试存在性"门禁会强制

## 反例（来自实战）

- 38 个文件的"新模块 bootstrap"= 8~12 张卡，不是一张
- "实现切面 + 全量生效"应拆为：骨架卡（含生效范围控制/试点模块）→ 脱敏卡 → 输出通道卡 → 放量卡
