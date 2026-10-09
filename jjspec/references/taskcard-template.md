# 任务卡模板 + DAG 拆卡法

> 用途：任务卡 DAG 拆解阶段、编码执行前。直通模式以有效定稿 PRD 和 draft Spec/HLD 拆卡；走门模式须当前 Spec/HLD 已获用户批准。仅恢复既有行为的缺陷可免 PRD，以有预期依据的修复 Spec 拆卡，模式按 `prd-constitution.md` 风险复判规则确定。**单卡 = 单窗口 = 单 PR；默认单卡单模块**（跨模块原子变更须注明理由）；单卡变更 100~400 行为宜。
> 落点：**一张卡一个文件**——`changes/<需求ID>/tasks/TASK-<编号>.md`（编号与卡 id 一致）。禁止多卡并进单文件：CI 按卡文件路径做在场卡过滤与边界归属，混放会让过滤与越界判定失效。

## 单卡模板

```markdown
---
id: TASK-04
title: 定金支付流程
risk: high | medium | low        # 高风险→AL1 逐卡+100%人审；低→AL2 自主循环
depends_on: [TASK-01, TASK-02]   # DAG 依赖，指向被依赖者
spec: changes/<需求ID>/spec.md   # 本卡对应哪份 Spec（spec_ac 的归属，防多 Spec 的 AC 编号歧义）
spec_ac: [AC1, AC4]              # 本卡验收对应上述 Spec 的哪些 AC
date: YYYY-MM-DD
status: pending | in_progress | blocked | done
---

## 边界（机器可查）
<!-- 允许触碰的文件/目录清单，一行一个 glob。本区块是唯一事实源，禁止手工另编一份（双清单必漂移）。
     CI 由 extract-boundary.sh 自动扫描全部进行中卡的边界（在场卡过滤 + fail-closed 裁决），
     无需手改任何 workflow 文件。两种声明格式任选其一，一卡混用亦可（提取结果合并；注释行与空行忽略）：
     格式①（推荐）```boundary 围栏：
       ```boundary
       modules/payment/deposit.py
       modules/payment/__tests__/deposit_test.py
       ```
     格式② ## 边界 区块下的 `- ` 列表（原生格式）：
     - modules/payment/deposit.py
     - modules/payment/__tests__/deposit_test.py
     未声明边界的卡一旦在场（diff 触碰非豁免文件）→ CI fail-closed，故开卡时必须声明 -->

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
- AI：实现 + 自跑测试循环至全绿（先跑基线；无进展 3 轮熔断报告——AL2 异常出口见 gates.md）
- 人：PR 评审重点 = 竞态处理与金额精度（高风险卡 100% 人审）

## 执行进度
- 下一步/阻塞：<尚未执行时写“待执行”>
- 验证证据：<实际命令、结果；未验证时明确标注>
- 关联提交/PR：<产生后填写>
```

## 拆卡规则

1. **默认一张卡单模块内可完成**——跨两模块默认拆两卡（AI 原稿爱合成大卡，人工必拆）。例外：接口与其调用方必须原子变更时可同卡，须注明理由，仍守单卡 = 单窗口 = 单 PR
2. **依赖必须显式成 DAG**：有向（指向被依赖者）、**无环**（T04 等 T05、T05 又等 T04 = 拆错了重拆）
3. DAG 的三个收益：拓扑排序 = 执行顺序；无依赖分支可并行（多会话/多 Agent）；关键路径决定总工期
4. 高风险卡（资金/鉴权/迁移/删除）标注 `risk: high`，禁止 AL2 自主执行
5. 每张卡自带测试要求——"AC↔测试对应性"门禁会强制（新增测试，或引用既有测试 + 覆盖说明 + 执行结果）
6. 仅写任务卡不授予编码权限；开始实现前核验已有开工授权。拆卡或实现中发现新增触线条件，记录在原续接区并转走门；Spec/HLD 修订影响本卡时置 `blocked`，同步后按当前模式核验适用批准，再继续。

## 反例（来自实战）

- 38 个文件的"新模块 bootstrap"= 8~12 张卡，不是一张
- "实现切面 + 全量生效"应拆为：骨架卡（含生效范围控制/试点模块）→ 脱敏卡 → 输出通道卡 → 放量卡
