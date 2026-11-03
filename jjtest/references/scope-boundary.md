# jjtest ↔ jjspec 职责边界与单源归属

> 用途：两技能协作的切分正源。任何一方修改判据前先对读本表——归属冲突即停靠交用户裁决（防双源）。

## 一、单源归属表

| 判据 | 正源 | 另一方动作 |
|---|---|---|
| 需求/AC/风险分级定义 | jjspec（PRD/Spec/taskcard） | jjtest 引用 `spec_ac` 与 `risk` 字段，禁止复述定义 |
| 旅程从哪来（AC→关键旅程选择判据） | jjspec（AC 验收场景是旅程唯一来源） | jjtest 只定旅程规格格式与工程化，选择判据指针引用 |
| 操作映射素材（E2E 直译通道的定位符/文案/九态） | jjspec UI 管线产物（量化表/文案清单） | jjtest 指针引用为直译素材，探索通道兜底（e2e-guide 操作映射层） |
| E2E 冒烟与契约校验证据行格式 | jjspec gates.md 发布证据包节 ⑥⑦（⑧ 消费方结构） | jjtest 定生产判据（怎么跑出可信证据），证据行按 jjspec 格式落 |
| 旅程规格/脚手架选型/数据管理/环境契约/稳定性纪律/CI 接入/旅程↔AC 对账维护 | jjtest（本技能） | jjspec gates.md 只留指针（已改：「工程判据正源 = jjtest」） |
| 契约四层执法判据（静态/漂移/运行时/CDC） | jjtest（本技能） | jjspec 无契约执法判据，不新增 |
| 测试地图 schema 与机械校验 | jjtest（test-map-guide + test-map-check.sh） | jjspec 体检项只做在场检测 |
| 测试治理链（测试文件清单/boundary/task-done-gate 对 E2E 脚本的管辖） | jjspec（已存在，e2e 目录已被 ac-coverage 识别为测试文件） | jjtest 服从：E2E 脚本增改同样须被卡认领 |
| 集成测试环境与禁 mock 主依赖规则 | jjspec AGENTS.md.template R-INT | jjtest 引用不复制（迁移 = 双源） |
| 发布门/观测拍板门的聚合与裁决 | jjspec（release-evidence.sh + 发布策略） | jjtest 是证据生产方，不做发布裁决 |

## 二、衔接点执法细则（仅三处，全为指针）

1. **项目接入体检**（jjspec onboarding-checklist）：只检测「测试地图在场 + 测试运行能力可用」两个存在性事实，不读地图内容——内容缺口归 jjtest 处置。
2. **⑧ 质量门禁**：jjspec 按卡 `risk` 与触点类型（API/界面）判定是否委托 jjtest；委托 = 存在检测（jjtest 已安装？）+ 兼容检测（版本触发词）+ 委托，**禁止在 jjspec 内复述 jjtest 判据**（编写纪律第 5 条）。jjtest 未安装时：E2E 冒烟证据行格式（gates.md）仍可独立使用，工程判据缺位显式留痕。
3. **⑨ 观测回流**：生产缺陷 → jjtest 回归资产流程（复现旅程沉淀为回归用例，登记测试地图风险行）；测试缺口/治理改进 → 反馈 jjspec 修订 SOP。

## 三、边界四修正（设计定稿时钉死的防双源决策）

1. **证据行格式正源留 jjspec**：发布证据包是 ⑧ 门禁消费方结构，E2E（⑥ 已有）与契约（待并入）证据行格式都住 gates.md；jjtest 只定义可信证据的生产与自检。
2. **触发判定所有权归 jjtest**：域级测试请求（搭 E2E/契约/地图）由 jjtest 触发词接管；卡内随卡测试仍归 jjspec——两类触发不互斥、作用域不同（域级 vs 卡级）。
3. **测试地图落项目仓**：`quality/test-map.md`（schema 正源在 jjtest）——同 ui-specs「机制归 Skill、内容归项目」；禁止在 jjtest 内维护各项目测试清单。
4. **R-INT 不迁移**：集成测试环境规则留 jjspec AGENTS.md.template（项目规则执法物料），jjtest 引用。

## 四、待办区（显式登记，非盲区）

- [x] **契约证据行并入发布证据包**（2026-10-25 完成）：gates.md 发布证据包 ⑦ + `release-evidence.sh` 聚合升级（含显式豁免口径）+ 单测 14 场景；格式正源已迁 gates.md，contract-gates 只留生产判据。
- [x] **CI 接入模板**（2026-10-25 提供）：`assets/ci-snippets/github-actions-contract.yml` + `github-actions-e2e-smoke.yml`——判据本文件的模板物料，runner/环境按项目改。
- [ ] 第二期启动时：本表增补回归级 E2E 与 flaky 治理的执法锚点行；金丝雀测试案例集补 jjtest 场景案例（素材已备：分组Agent 预演留痕 + 三幕场景草案见 canary-suite §5）。
