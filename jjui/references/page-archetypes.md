# 页面配方与组合基线

> 评估粒度是单页、区域、操作、状态和组合组件；不得用“典型后台”替代页面计划封闭清单。

## 页面配方

| recipe | 标准组合 | 注意 |
|---|---|---|
| `dashboard` | `PageHeader` + `MetricCard` + `SectionCard` | 指标必须来自固定 Mock 数据 |
| `list` | `PageHeader` + `Toolbar` + `SectionCard` + `StatusTag` | 不自动发明业务操作 |
| `detail` | `PageHeader` + `SectionCard` + `StatusTag` | 可用页面或 Drawer，必须登记 `expected_entry` 与 `master_ref`（主从约束见 `composition-layer.md` 详情呈现段） |
| `form` | `PageHeader` + `SectionCard` + `Toolbar` | 新增/编辑用页面、Modal 或 Drawer 须显式登记 |
| `settings` | `PageHeader` + `SectionCard` | 不接真实保存逻辑 |
| `workspace` | `PageHeader` + `SectionCard` + `Toolbar` | 仅在确有需要时使用 |

## 页面计划字段

每页至少登记：

| 字段 | 说明 |
|---|---|
| `id` | `p-01`、`p-02` 等稳定编号 |
| `slug` | 英文 kebab-case 短名 |
| `title` | 业务标题 |
| `route` | 渲染可达路由 |
| `file` | 页面源文件 |
| `expected_entry` | 预期到达方式 |
| `master_ref` | 主记录来源页 ID 或 `fixed:<数据集>`；约束见 `composition-layer.md` 详情呈现段 |
| `regions` | 页面区域与锚点 |
| `actions` | 可操作点与锚点 |
| `dynamic_regions` | 动态数据区、锚点与数据集 |
| `structural_texts` | 静态结构文案封闭清单 |
| `states` | 已实现状态 |
| `mock_dataset` | 固定数据集 |
| `mock_rows` | 该页表格数据集行数；含表格的页面必须登记，`> 10` 必须分页（判据见 `composition-layer.md` 表格段） |
| `composition` | 页面配方与必需组合组件 |
| `acceptance` | 原型自验项 |

## 操作与状态

- 每个操作必须登记语义与锚点。
- 页面上每个可交互控件（按钮、输入框、选择器、开关等，含工具栏筛选控件）都必须是登记过的操作：带 `data-jjui-action` 锚点，且有前端状态变化或固定 Mock 反馈；机械校验按"控件数 ≤ 锚点数"对账。
- 跳转是操作的一种：用按钮或链接承载并登记锚点；禁止用输入框（如 `Input.Search` 的 `enterButton`）客串跳转按钮，placeholder 只写输入提示、不承载操作指引——跨页单源引用（如"边界由另一页约束"）用只读标签 + 登记过的跳转操作表达，不造死输入框。
- 原型操作只做前端状态变化或固定 Mock 反馈。
- 每页登记可采集状态；默认至少考虑 `default`、`loading`、`empty`。
- `error`、`disabled`、`permission-denied` 等状态无需求来源时不默认编造。

## 文案与数据分层

- 静态结构文案进 `structural_texts`。
- 动态数据文本放 `dynamic_regions`。
- 禁止使用 `Date.now()`、随机 ID、随机姓名或外部请求影响渲染。

## 新增页面

1. 先改 `.jjui/page-plan.json`，登记配方和必需组件。
2. 新建页面文件与路由。
3. 使用组合层组件搭建骨架。
4. 补菜单或入口。
5. 加稳定锚点。
6. 重跑 `check_prototype.py` 和页面实跑。
