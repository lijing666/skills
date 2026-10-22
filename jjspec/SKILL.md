---
name: jjspec
description: "AI 架构师工作流 skill：以 AI 友好架构五属性（可理解性/可分解性/显式性/可验证性/可回滚性）编写 PRD、需求 Spec、架构设计文档、任务卡；执行九步交付 SOP（预检→规则先行→PRD 打磨→Spec→方案三查→任务卡 DAG→分级执行→门禁灰度→观测回流），直通/走门双模式，走门停在方案三查等用户批准；含项目接入体检、执法物料包（AGENTS.md 模板/越界检测/风险区门禁/测试对应性门禁/import-linter/ArchUnit）。当用户要求：编写需求文档/PRD/打磨需求/多模块需求/分册需求/拆分需求/架构设计/HLD/任务拆解/任务卡/ADR，或说 jjspec/写需求/按 PRD 开工/直接开工/只写 prd/只写 spec/只写 task/修 bug 任务/SOP/项目接入体检/生成 UI 规范/绑定 UI 规范（配套 HTML 原型或 Figma 设计稿），或要求按 AI 架构师规范交付时使用。"
metadata:
  agent_created: true
  version: 1.15.1
  created: "2026-09-29"
  source: "《AI 架构师五天教程》课程沉淀（用户深度参与修订）"
---

# jjspec · AI 架构师工作流

把软件工程知识从人脑搬进 AI 的一等公民上下文：AI 按本 skill 产出文档与代码，人类架构师只保留 **PRD 定稿权**、**方案批准三查**和**人审三焦点**。

## 核心理念（一切决策的依据）

- **五属性框架**（唯一理论框架，一词一义）：可理解性 · 可分解性 · 显式性 · 可验证性 · 可回滚性——每条既是原则又是度量，详见 `references/principles-v1.md`
- **三条定律**：局部性（任务只依赖局部上下文）· 上下文预算（信息要编列，规则常驻、背景按需）· 显式优于隐式（没写下来的约定 = 不存在）
- **万能判断法则**：任务的决策空间能否装进一个上下文窗口？不能 → 先分解成能

## 触发场景与工作流

### 场景 A：新项目 / 新接手项目 → 先做接入体检

1. 读 `references/onboarding-checklist.md`，对目标项目逐项体检（规则文件 / CI 门禁 / 文档层 / 执法工具 / 测试覆盖）
2. 按体检结果产出《接入行动清单》，**先补 L2 规则文件（用 assets/AGENTS.md.template）再进入任何编码任务**——高风险区规则先行（风险区清单 + `[risk-ok: @批准人]` 门禁约定随模板落地）

### 场景 B：新需求 → 指令即阶段，九步 SOP

PRD 是新需求的第一停靠点（人与 AI 都能读的桥梁：PRD 错，后面步步错）；恢复既有约定行为的缺陷修复按场景 C。**指令决定起止阶段**：

| 用户指令 | AI 行为 |
|---|---|
| 写需求 X / 打磨需求 X / 只写 prd X | ①只读预检 → ③产出 `changes/<需求ID>/prd.md`（status: draft→评审中）；②规则缺口只记建议，待澄清问题集中在附 D，**停在定稿前**——定稿只能由用户指令触发 |
| 多模块需求 X / 分册需求 X / 拆分需求 X | 按 `references/prd-splitting.md` 以「主 prd.md + prd-<序号>-<模块>.md」分册起稿（新需求）或迁移拆分（存量整稿）；①②③照常但产物为分册，校验按 `references/prd-splitting.md` 由 AI 自行执行全绿后停在定稿前；④起 Spec、⑤HLD、⑥任务卡及后续步骤不变（spec/hld 仍单文件）。仅显式指令触发，不做自动判定 |
| 定稿 X / PRD 定稿（仅用户可发） | PRD status 置"已定稿" + 版本表登记，停在开工前；用户同句要求"定稿并开工"则直接进入下行 |
| 按 PRD 开工 X / 开发 X | 落点自检（宪法第八节第 3 条：复用已有需求目录、禁嵌套同名目录段、歧义停下确认）→ 校验 `changes/<需求ID>/prd.md` 的定稿对当前版本有效（正主唯一，副本上的状态/批准无效）→ 复查①并落实② → 判定模式 → 直通执行④-⑥（⑥→⑦ 须过 task-dag-check.sh 完备性硬门 + 拆卡完成停靠等「继续」，见 taskcard-template.md 拆卡规则 2 与 ⑥行）再续⑦-⑨，或走门停在⑤；草稿/评审中不得进入实现 |
| 直接开工 X | 单卡且不触线：轻量 PRD 一轮确认（复述需求 + 假设 + 澄清打包一单，用户确认即定稿）→ 落实①②后执行④-⑥，拆卡后停靠等「继续」（⑥行，单卡不豁免）再⑦-⑨；触线或超出单卡则补完整 PRD，经用户定稿后按触线清单判定直通/走门 |
| 只写 spec X / 只写 task X | 新需求从定稿 PRD 产出到截断点（Spec=④ / 任务卡=⑥）；缺 PRD 时先补草稿待用户定稿，缺方案时先起草，走门须获批准才拆卡；仅写目标及必要前置文档，不实施规则建议、不编码 |
| 生成 UI 规范 X（附 HTML 原型或 Figma 地址） | 加载 `references/ui-spec-guide.md` 生成管线：判定 HTML/设计稿分支 → 机械提取（含视觉物扫描）→ 前置产物四件套落 `ui-specs/<产品ID>-<业务大项>/` → 机械校验（含 ui-pack-check 资产门禁）→ 输出对账清单**停在用户确认前**（确认前 README 状态 draft）；仅文档任务，不编码 |
| 绑定 UI 规范 X（需求 X 与 UI 规范 Y） | 加载 `references/ui-spec-guide.md` 绑定管线：AI 语义识别页面↔REQ 映射（每条带证据，歧义列《待修正清单》等用户修正）→ 确认后回填 PRD 第 8 章「UI 真源」列与主 PRD 绑定块 → 版本 +1 回评审中（宪法第九节）；不进入 Spec 或编码 |

**九步 SOP**（④-⑨ 为执行段，受模式门约束）：

| 步骤 | 动作 | 加载的参考 |
|---|---|---|
| ① 架构预检 | 影响面扫描 + 上下文供给检查（高风险区规则/ADR 是否齐） | onboarding 已有则跳过 |
| ② 规则先行 | 文档限定任务只记录缺口；获开工授权且需求明确后、编码前，补齐适用 AGENTS.md 规则与 ADR（风险区改动仍遵守批准要求） | assets/AGENTS.md.template, adr-template |
| ③ PRD 打磨环 + 模式判定 | 需求与用户往复打磨（EARS 句式、非目标、失败场景），落 `changes/<需求ID>/prd.md`；按触线清单判定直通/走门 | prd-constitution.md, prd-template.md |
| ④ 拆 Spec | 由定稿 PRD 逐卡拆 Spec：验收标准（GWT 可测）+ 非目标 + 边界约束 | spec-template.md |
| ⑤ 方案起草 + 停靠门 | AI 起草 HLD；架构知识协助按 hld-template.md 用途块的"架构知识协助路由"执行（该块是唯一正源，不在此复述）；走门模式停在方案三查（查边界/查方向/查遗漏）等用户批准；打回意见与隐性约定当天回流 | hld-template.md 的三查节 |
| ⑥ 任务卡 DAG | **硬门槛：未读 taskcard-template.md 不得产出任务卡（凭记忆复述格式曾致缺 `## 测试文件清单` 被 ac-coverage-check 拦截，2026-10-12）**；单窗口=单PR；默认单卡单模块（跨模块原子变更须注明理由）；拆出依赖图，无环校验；**DAG 完备性硬门：第一张卡开工前须过 task-dag-check.sh（AC 反向完备 + 依赖闭合），未过禁止进⑦**（判据与豁免口径见 taskcard-template.md 拆卡规则 2）；**拆卡完成即停靠**：硬门全绿后停，交付任务卡清单 + 调度方案（单分支报拓扑序、多分支按拆卡规则 3 三要素交选），明示「已停在⑥」，获用户「继续」指令才进⑦——单卡与缺陷修复不豁免（上下文中断后靠落盘任务卡 + 状态即续接恢复，无停靠即无恢复点） | taskcard-template.md |
| ⑦ 分级执行 | 低风险 Agent 自主循环（前置低风险卡 done 即解堵下游，连续执行不等提交）；高风险逐卡 + 100% 人审（置 review 必附人审请示材料包，人审通过才解堵下游；「合入」与解堵脱钩，提交窗口按拓扑序批量执行）；多卡并行按 ⑥ 交付的调度方案执行（判据见 taskcard-template.md 拆卡规则 3） | gates.md |
| ⑧ 三层门禁 + 开关灰度 | 机械 → 行为 → AI 特有（越界/风险区/幻觉/缺测试），全绿才合入；功能默认关合入主干，回滚默认=关开关，不可逆变更显式标注恢复方式 | gates.md, assets/extract-boundary.sh, assets/boundary-check.sh, assets/ac-coverage-check.sh, assets/risk-zone-check.sh, hld-template.md |
| ⑨ 观测 + 回流 | 观测期按风险定（默认 48h），须带指标、负责人、结束条件 → 教训归因到知识层 L1~L4 → 体系升级 | feedback-loop.md |

**模式判定（触线清单，命中任一 → 走门，全不命中 → 直通）**：风险区（AGENTS.md 第 5 节清单）· 跨模块接口变更 · 全局运行时行为（AOP/拦截器/全局配置）· schema 迁移/不可逆变更 · 金额/幂等/并发 · 预计 ≥3 张任务卡——与三层门禁分层抽审的 100% 人审维度对齐（gates.md）。

- **直通模式**：已获开工授权时，④-⑨ 不另设方案批准停靠；Spec/HLD 以 `draft` 进入拆卡与实现，随 PR 交付并按 gates.md 抽审；`draft` 不代表任务未执行。PRD 未覆盖的实现假设逐条标注，改变目标/AC/非目标/关键约束的假设须回 PRD 再定稿；合入、发布仍遵守项目权限与门禁。
- **走门模式**：停在⑤交审当前 Spec/HLD，AI 不得自行宣布三查通过或批准；用户批准后记录所批版本，方可进入⑥。状态可随事实更新，`approved` 只能依据用户批准置位。
- **变更时复判**：拆卡及执行中发现触线条件，立即转走门并停下受影响实现；语义修订撤销相关旧批准，按 `prd-constitution.md` 的修订规则重新评审，纯排版/错字修订豁免。
- **状态即续接**：读取当前工件的版本、批准记录和续接区，再核对 HLD、任务卡、Git/PR 实况；PRD 定稿不等于开工授权，文档状态不等于执行阶段。字段与规则见 `prd-constitution.md`，无需另建台账。

> **低风险小需求精简路径**（单卡内可完成、不触线）：走"直接开工"快速通道，轻量 PRD 一轮确认即定稿；④Spec 与⑤方案合一为单文档（三查并入卡评审，仅直通模式可用），⑥自然单卡无 DAG（拆卡后停靠不豁免，等「继续」再实现），⑧灰度按需。免打磨不等于免流程——AC、非目标、边界约束、门禁、回流一样不少。

### 场景 C：缺陷修复任务

仅恢复既有约定行为时可免新 PRD：①影响面 → ④修复 Spec（引用原规格/契约/用户确认的预期行为，附复现 AC 与非目标）→ ⑥任务卡（按影响面拆卡）→ 停靠等「继续」（⑥行，缺陷修复不豁免）→ ⑦实现 → ⑧门禁（必须带回归测试）→ ⑨回流。Spec 承载续接信息；现有代码本身不能证明预期行为。预期不明先澄清，改变产品行为则转场景 B。

- **缺陷同样按触线清单复判**：高风险缺陷（鉴权/数据修复/资金/跨模块等）补②规则先行 + ⑤方案三查（走门停靠），⑧灰度不豁免；风险区改动走 `[risk-ok: @批准人]` 门禁。免新 PRD 不等于免方案批准或回归测试。

## 贯穿各场景的约定

- **体系变更评估**（不绑定场景）：模型升级 / 更换宿主工具 / 大改规则资产（AGENTS.md、模板、门禁脚本）之前，先按 `evaluation.md` 跑金丝雀任务集——体系是概率组件，变更会静默漂移，先量化再放量。
- **变更工件落点与归档**（推荐约定，详见 `prd-constitution.md` 第八节；场景 B ⑨ 与场景 C ⑨ 均触发）：进行中的变更放 `changes/<需求ID>/{prd.md, spec.md, hld.md, tasks/TASK-<编号>.md}`（一卡一文件）；验收合入后走**归档三步**——移入 `changes/archive/<日期>-<ID>`、`INDEX.md` 登记一行（能力编年导航）、资产基线检查（PRD：触碰目标/非目标/角色/成功标准才修订并版本留痕；HLD：模块增删/数据流/接口契约变更才更新 `docs/HLD.md`；spec/tasks 不回流）。命名分层：`docs/` 资产层大写（PRD.md / HLD.md / SPEC.md / TASKS.md），`changes/` 过程层小写（prd / spec / hld / tasks），文件名全局只用 prd/hld/spec/tasks/adr 五个词（带编号实体文件例外见 prd-constitution.md 第八节）。
- **文档/分析范围优先**：预检只读，规则缺口记入目标产物的建议，不自动修改 AGENTS.md、CI 或新增已接受 ADR；指定产物完成即止。用户明确要求修改规则/配置/lint/CI 时在授权范围内实施并验证，不自动发布。纯文档任务不要求开工授权。

## 参考文档索引（按需加载，勿一次性全读）

| 文件 | 何时加载 |
|---|---|
| `references/principles-v1.md` | 设计决策拿不准时；用户问"为什么这么要求"时 |
| `references/spec-template.md` | 步骤 ④ |
| `references/prd-constitution.md` | 写 PRD / 需求文档 / 需求变更前必读 |
| `references/prd-template.md` | 步骤 ③ 落 `changes/<需求ID>/prd.md` 时 |
| `references/prd-splitting.md` | 分册需求（多模块需求/大需求）起稿，或存量单文件 PRD 迁移拆分时 |
| `references/ui-spec-guide.md` | 「生成 UI 规范」或「绑定 UI 规范」指令触发时；前置规则见 prd-constitution.md 第九节 |
| `references/hld-template.md` | 步骤 ⑤ |
| `references/taskcard-template.md` | 步骤 ⑥ |
| `references/adr-template.md` | 步骤 ②⑤⑨ 需要记录决策时 |
| `references/antipatterns.md` | 体检、评审、拆卡时对照打勾 |
| `references/contract-toolbox.md` | 步骤 ② 选执法工具、写架构约束时 |
| `references/gates.md` | 步骤 ⑦⑧ |
| `references/onboarding-checklist.md` | 场景 A |
| `references/feedback-loop.md` | 步骤 ⑨ 及每次 AI 出错后 |
| `references/evaluation.md` | 模型升级/换宿主/大改规则资产前；月度体系级复盘 |

## 执法物料包（直接落进目标项目，不是"读"是"用"）

- `assets/AGENTS.md.template`：根级（六区块）+ 模块级模板，规则带 R 编号与违反后果
- `assets/extract-boundary.sh`：边界提取层——自动扫描进行中任务卡（```boundary 围栏 + `## 边界` 列表双格式），白名单 = 在场卡（本次 diff 新建/修改的卡）边界并集 + 豁免段；内置 fail-closed 裁决（非豁免文件缺卡覆盖/在场卡未声明边界即失败）。CI 零手改，免手工指定任务卡路径
- `assets/boundary-check.sh`：越界检测——diff 对照边界文件（由 extract-boundary.sh 生成），超出即失败（fail-closed；回归测试 `boundary-check.test.sh`）
- `assets/risk-zone-check.sh`：风险区门禁——触碰 AGENTS.md 风险区清单的 commit 须带 `[risk-ok: @<批准人>]` 标记（人批准留痕；裸标记/占位符无效，与 author 同名即拦），无标记即失败（fail-closed；回归测试 `risk-zone-check.test.sh`）
- `assets/ac-coverage-check.sh`：测试对应性门禁——diff 触碰行为文件（非豁免且非测试文件）时，覆盖卡必须声明 `## 测试文件清单`（taskcard-template 定义格式）；清单条目格式非法/悬空/非测试文件、spec_ac 幻觉引用均失败（fail-closed；回归测试 `ac-coverage-check.test.sh`）。测试文件识别内置多平台命名约定（Python/Go/Java/Kotlin/Swift/ObjC/Dart/ArkTS/JS·TS/Shell 与测试目录段），`--test-glob` 追加项目特有布局
- `assets/ui-pack-check.sh`：UI 规范包资产完整性门禁——README 资产类别登记 15 类封闭（颜色/字号/字重/行高/字体族/间距/圆角/边框/阴影/透明度/渐变/布局/动效/图标/位图素材，无值须显式豁免）、icons.json 存在合法、素材清单无未终态条目、页面编号连续、页面短名英文 kebab-case、每页含视觉锚点；`--require-digest` 模式另查 digest=quantified、四段规格、合法 `entry`，并对账 `source_node_count`、量化表与覆盖账本行数、两表源定位符集合及唯一性与汇总 `source=N spec=N uncovered=0`；该机械核对不能替代对原始 DOM/Figma 节点树的逐项扫描复核；`--require-final` 定稿清零门禁查「人工补录」挂起清零（宪法第九节第 11 条，fail-closed；回归测试 `ui-pack-check.test.sh`）
- `assets/menu-recon-check.sh`：菜单三源对账门禁（页面卡「## 菜单/入口对账」固定节执法，宪法第九节第 12 条）——ui-specs 中 entry 含 menu 的页面清单 ↔ 实现工程路由注册表 ↔ PRD 非目标表排除名单，自造菜单/菜单缺失/排除命中均拦（fail-closed；回归测试 `menu-recon-check.test.sh`）
- `assets/page-excerpt-check.sh`：UI 规格摘录对账门禁（页面卡「## UI 规格摘录」节执法）——N=M 严格对账：登记 N/M 必须纯数字且与节点样式摘录条目数、ui_source_page 各页量化表实际行数三方相等，覆盖账本摘录条数须与节点样式摘录一一对应（六块齐全：缺账本块/条数错配/缩进表格式逃逸均拦），占位符未替换/规则文字占位/漏转抄/指针悬空均拦（fail-closed；单卡模式供开工前自查——不通过不得写第一行代码，`--diff` 批量供 CI 打回；回归测试 `page-excerpt-check.test.sh`）
- `assets/task-done-gate.sh`：done 语义门禁（仅深查 status=done，pending/in_progress/blocked/review 为合法中间态跳过）——验收节逐条证据、spec_ac 全覆盖验收节、risk: high 须有「人审通过」记录、页面卡 ui-gate 内容判据（必含视觉验收字样 + 差异或 n/m 数字 + PASS，且**按页面规格 source_anchor 路线感知**：HTML 路线只认 pixel-diff、设计稿路线只认结构化断言，路线谎报机械拦截——防验收器漂移与路线谎报；“待执行 + done”后门组合直接拦；先标 done 后补证据的时间窗由此关闭；fail-closed；回归测试 `task-done-gate.test.sh`）
- `assets/doc-chain-check.sh`：文档链正主门禁（宪法第八节落点自检/正主唯一 + 批准效力正主判据的机械执法）——嵌套同名目录段（仅目录段，文件名含需求 ID 不受限）、同一需求 ID 核心文档多份（含活跃+归档双位置）、悬空批准（spec/hld approved 但正主 prd 未定稿；免 PRD 修复 Spec 无 prd.md 天然跳过）、状态自洽（approved 残留待批准 / draft 旧批准冒充 / 定稿与版本表不一致）均拦；archive 历史快照状态跳过、结构违例永久拦截；`--diff` 批量供 CI（fail-closed；回归测试 `doc-chain-check.test.sh`）
- `assets/task-dag-check.sh`：任务卡 DAG 完备性门禁（⑥→⑦ 硬门，判据正源 taskcard-template.md 拆卡规则 2）——AC 反向完备（spec 每条 AC 至少被一张卡 `spec_ac` 认领 + 幻觉 AC 引用拦截，封堵滚动拆卡）、卡 `spec` 字段一致（防多 Spec 的 AC 编号歧义）、DAG 闭合（depends_on 引用存在 + Kahn 环检测，含自依赖）；无 tasks/ 未拆卡不拦（门禁对象是「开工而未闭合」不是「未拆卡」），无 spec.md 纯修复只查闭合与一致；单需求目录与项目根两模式，`--diff` 批量供 CI（fail-closed；回归测试 `task-dag-check.test.sh`）
- `assets/pixel-diff.mjs`：HTML 原型路线逐卡内联视觉验收参考实现（本地跑，非 CI 物料——ui-gate 行 `pixel-diff <差异>% ≤ <PRD阈值>% PASS（命令:node pixel-diff.mjs ...）` 的可复跑命令本体）；基准 vs 实现截图逐像素对比，缺基准/截图/env.json/尺寸不一致/超阈值均 fail-closed，热区统计与 diff 返回值强制对账，env.json 机械校验视口/DPR/UA/字体就绪；`--out` 物化差异图/叠加图/热区三联裁剪 + report.json；阈值不因调优困难放宽，环境契约对齐后按热区归因修复。
- `assets/visual-diagnose.mjs`：HTML 路线 pixel-diff FAIL 页热区级 DOM/CSS 诊断参考实现（本地跑，非 CI 物料）——消费 pixel-diff `--out` 的 report.json，按缩放比换算热区坐标后在实现页渲染态逐热区采样 elementsFromPoint，输出命中元素链及排版、盒模型、定位、布局、裁切与视觉效果等计算样式，供 AI 与页面规格量化表对读归因；按需登记级：项目侧 `npm i -D playwright pngjs`，实现侧 env.json 必须登记。
- `assets/ci-snippets/`：import-linter（Python）/ ArchUnit（Java）/ GitHub Actions 越界检查（extract-boundary + boundary-check）、测试对应性（ac-coverage-check）、风险区门禁与密钥扫描（gitleaks）job——均支持 PR 与 push 双基准，覆盖不可禁直推的场景
- **脚本执行前提与跨平台兜底**（适用以上全部 `.sh`）：正源判据只有 bash 版一份，**不内置任何其他平台版本**——①主路径：bash 环境（macOS/Linux 原生；Windows 用 Git Bash 或 WSL 执行同一脚本，零改动）；②兜底：确无 bash 可用时（如 Windows-only CI runner），AI 在会话内参考脚本头部「校验清单」注释自编等价校验（如 PowerShell）——校验清单为唯一口径不得增删项、fail-closed 语义不变（检查不了 = 不通过）、输出逐项对账明细禁只报结论、**一次性使用，禁入库禁提交**（防双源漂移与口径自由发挥）；③本地执行的脚本（ui-pack-check.sh）在头部注明该口径语义正源地位
- 物料分级：以上为**开箱可用**（boundary/ac-coverage job 无需按 PR 手改路径，风险区 job 无需配置；测试布局非典型时 --test-glob 登记）；DAG 完备性校验由 task-dag-check.sh 开箱承担（不再随项目测试框架自配）；人审三焦点（含 AC↔测试断言语义对应）为人工项

## 四条设计铁律（维护本 skill 时不可违反）

1. **SKILL.md 永不超 150 行**——细节一律下沉 references，防止 2000 行文档病（注意力稀释）
2. **规则必配物料**——纯文字规则是文档期最软契约；能机器执法的给配置、给脚本
3. **机制归 skill，内容归项目**——回流教训散写进项目的代码/AGENTS.md/ADR；L4 跨项目教训由人决定去向（项目内零回流文件，禁止机制/台账文档，见 references/feedback-loop.md 硬边界）；skill 自身升级由人控节奏（第二条循环）
4. **references 必须自包含**——编号（步骤 ⑨）、场景代号（场景 A）离开 SKILL.md 就无上下文；references 内一律用阶段名/内容名自描述，跨文件代号只允许出现在 SKILL.md

## 输出纪律

- 文档一律 Markdown，YAML frontmatter 标注来源与日期
- 领域敏感量（金额/数量/权重等）禁浮点——整数最小单位 + 单位枚举；具体哪些量敏感、最小单位、精度与舍入方式由项目在 AGENTS.md 定义（如支付=分、重量=克）；错误路径进类型签名
- 修改"为什么"必须留痕：代码注释 `// 见 ADR-00xx` + ADR 归档
- 交付任何方案时，同时声明：改动边界（文件清单）与运行时影响边界——两者反差大时标记为高风险
