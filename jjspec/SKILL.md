---
name: jjspec
description: "AI 架构师工作流 skill：以 AI 友好架构五属性（可理解性/可分解性/显式性/可验证性/可回滚性）编写需求 Spec、架构设计文档、任务卡；执行九步交付 SOP（预检→规则先行→Spec→方案三查→任务卡 DAG→分级执行→三层门禁→开关灰度→回流）；含项目接入体检、执法物料包（AGENTS.md 模板/越界检测/import-linter/ArchUnit）。当用户要求：编写需求文档/PRD/架构设计/HLD/任务拆解/任务卡/ADR，或说 jjspec/新需求开工/修 bug 任务/SOP/项目接入体检，或要求按 AI 架构师规范交付时使用。"
agent_created: true
version: 1.0.0
created: 2026-09-29
source: "《AI 架构师五天教程》课程沉淀（用户深度参与修订）"
---

# jjspec · AI 架构师工作流

把软件工程知识从人脑搬进 AI 的一等公民上下文：AI 按本 skill 产出文档与代码，人类架构师只保留**方案批准三查**和**人审三焦点**。

## 核心理念（一切决策的依据）

- **五属性框架**（唯一理论框架，一词一义）：可理解性 · 可分解性 · 显式性 · 可验证性 · 可回滚性——每条既是原则又是度量，详见 `references/principles-v1.md`
- **三条定律**：局部性（任务只依赖局部上下文）· 上下文预算（信息要编列，规则常驻、背景按需）· 显式优于隐式（没写下来的约定 = 不存在）
- **万能判断法则**：任务的决策空间能否装进一个上下文窗口？不能 → 先分解成能

## 触发场景与工作流

### 场景 A：新项目 / 新接手项目 → 先做接入体检

1. 读 `references/onboarding-checklist.md`，对目标项目逐项体检（规则文件 / CI 门禁 / 文档层 / 执法工具 / 测试覆盖）
2. 按体检结果产出《接入行动清单》，**先补 L2 规则文件（用 assets/AGENTS.md.template）再进入任何编码任务**——高风险区规则先行

### 场景 B：新需求 → 九步 SOP

| 步骤 | 动作 | 加载的参考 |
|---|---|---|
| ① 架构预检 | 影响面扫描 + 上下文供给检查（高风险区规则/ADR 是否齐） | onboarding 已有则跳过 |
| ② 规则先行 | 高风险区先补 AGENTS.md 规则与 ADR | assets/AGENTS.md.template, adr-template |
| ③ 写 Spec | 需求 ≥3 张任务卡 → 先写 PRD（宪法约束）再逐卡拆 Spec；小需求直接 Spec。验收标准（GWT 可测）+ 非目标 + 边界约束 | spec-template.md, prd-* |
| ④ AI 起草方案，人批准 | 查边界 / 查方向 / 查遗漏；产出打回意见 + 隐性约定（当天回流 L2） | hld-template.md 的三查节 |
| ⑤ 任务卡 DAG | 单卡=单模块=单窗口=单PR；拆出依赖图，无环校验 | taskcard-template.md |
| ⑥ 分级执行 | 低风险 Agent 自主循环；高风险逐卡 + 100% 人审 | gates.md |
| ⑦ 三层门禁 | 机械 → 行为 → AI 特有（越界/幻觉/缺测试），全绿才合入 | gates.md, assets/boundary-check.sh |
| ⑧ 开关 + 灰度 | 功能默认关合入主干；回滚=关开关不回滚代码 | — |
| ⑨ 观测 + 回流 | 48h 观测 → 教训归因到 L1~L4 → 体系升级 | feedback-loop.md |

### 场景 C：缺陷修复任务

走精简 SOP：①影响面（含回归测试定位）→ ③修复 Spec（复现 AC + 不引入回归的非目标）→ ⑤单任务卡 → ⑦门禁（必须带回归测试）→ ⑨回流（根因归层，防再犯）。

## 参考文档索引（按需加载，勿一次性全读）

| 文件 | 何时加载 |
|---|---|
| `references/principles-v1.md` | 设计决策拿不准时；用户问"为什么这么要求"时 |
| `references/spec-template.md` | 步骤 ③ |
| `references/prd-constitution.md` | 写 PRD / 需求文档 / 需求变更前必读 |
| `references/prd-template.md` | 大需求（≥3 张任务卡）立项写 PRD 时 |
| `references/hld-template.md` | 步骤 ④ |
| `references/taskcard-template.md` | 步骤 ⑤ |
| `references/adr-template.md` | 步骤 ②④⑨ 需要记录决策时 |
| `references/antipatterns.md` | 体检、评审、拆卡时对照打勾 |
| `references/contract-toolbox.md` | 步骤 ② 选执法工具、写架构约束时 |
| `references/gates.md` | 步骤 ⑥⑦ |
| `references/onboarding-checklist.md` | 场景 A |
| `references/feedback-loop.md` | 步骤 ⑨ 及每次 AI 出错后 |

## 执法物料包（直接落进目标项目，不是"读"是"用"）

- `assets/AGENTS.md.template`：根级（六区块）+ 模块级模板，规则带 R 编号与违反后果
- `assets/boundary-check.sh`：越界检测——PR diff 对照任务卡声明的文件边界，超出即失败
- `assets/ci-snippets/`：import-linter（Python）/ ArchUnit（Java）/ GitHub Actions 越界检查 job

## 四条设计铁律（维护本 skill 时不可违反）

1. **SKILL.md 永不超 150 行**——细节一律下沉 references，防止 2000 行文档病（注意力稀释）
2. **规则必配物料**——纯文字规则是文档期最软契约；能机器执法的给配置、给脚本
3. **机制归 skill，内容归项目**——回流教训写进项目的 AGENTS.md/ADR/知识库；skill 自身升级由人控节奏（第二条循环）
4. **references 必须自包含**——编号（步骤 ⑨）、场景代号（场景 A）离开 SKILL.md 就无上下文；references 内一律用阶段名/内容名自描述，跨文件代号只允许出现在 SKILL.md

## 输出纪律

- 文档一律 Markdown，YAML frontmatter 标注来源与日期
- 金额/数量类字段禁浮点（整数最小单位 + 币种/单位枚举）；错误路径进类型签名
- 修改"为什么"必须留痕：代码注释 `// 见 ADR-00xx` + ADR 归档
- 交付任何方案时，同时声明：改动边界（文件清单）与运行时影响边界——两者反差大时标记为高风险
