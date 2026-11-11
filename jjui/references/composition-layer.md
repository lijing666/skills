# Admin UI Composition Layer

> 目标不是做设计系统，也不是做无数模板。它是把 AI 的视觉自由度压缩到 Ant Design / Element Plus 的成熟体系内，使后台原型"至少规整、成套、可演示、可交接"。

## 一、设计原则

1. **组件库是视觉真源**
   - React 路线视觉基座是 Ant Design。
   - Vue 路线视觉基座是 Element Plus。
   - jjui 不另造一套 UI 体系，只做组合壳。

2. **有限组合，不做模板海**
   - 页面不是整页模板，而是由有限配方组成。
   - 配方是受控扩展清单：当前为 `dashboard`、`list`、`detail`、`form`、`settings`、`workspace`、`canvas`；新增配方须判据、机械校验、模板资产同版本同步落地，不为局部需求临时扩配方。
   - 新风格通过 token 覆盖解决，不新增模板。

3. **不追求视觉炫技**
   - 只要规整、专业、层级清晰、可演示。
   - 不引入图表库、状态管理、CSS 框架或真实后端。

4. **AI 只填业务内容**
   - AI 负责字段、文案、数据、状态和路由。
   - 页面骨架、间距、卡片、工具栏、状态语义由组合层约束。

5. **原型是真实产品的对照物**
   - 信息架构、交互与操作序列与真实产品一致，唯一差异是数据层（mock 数据替代真实后端）。
   - 禁止以「原型」为由简化交互——占位提示不替代表单流程，死按钮、砍掉二级交互、跳过校验确认流都不允许。

## 二、三层结构

### 1. Token 层

- 每个原型必须有唯一 Token 文件。
- Token 文件位于 `src/styles/tokens.css`。
- 颜色、圆角、阴影、间距、字号集中管理。
- 默认不提供多主题；如需风格变化，先确认后再做 token 覆盖。

### 2. 组合组件层

以下组件位于 `src/components/admin/`：

| 组件 | 作用 |
|---|---|
| `PageHeader` | 页面标题、描述、返回导航 |
| `SectionCard` | 页面内容区块 |
| `MetricCard` | 指标卡 |
| `Toolbar` | 筛选区、操作区 |
| `StatusTag` | 状态语义标签 |
| `EmptyState` | 空态 |
| `MasterDetail` | 主从布局壳（左导航列表 + 右内容，一体容器） |

它们不是新设计系统，而是对组件库的薄封装。

### 3. 页面配方层

| recipe | 推荐组合 |
|---|---|
| `dashboard` | `PageHeader` + `MetricCard` + `SectionCard` |
| `list` | `PageHeader` + `Toolbar` + `SectionCard` + `StatusTag` |
| `detail` | `PageHeader` + `SectionCard` + `StatusTag` |
| `form` | `PageHeader` + `SectionCard` + `Toolbar` |
| `settings` | `PageHeader` + `SectionCard` |
| `workspace` | `PageHeader` + `SectionCard` + `Toolbar` |
| `canvas` | `PageHeader` + 画布主编辑面 + 伴随面板 + 底部状态栏 |
| `ide` | `PageHeader` + 大纲树 + Tabs 编辑器 + 伴随面板 + 底部状态栏 |

`page-plan.json` 每页必须登记：

```json
{
  "composition": {
    "recipe": "list",
    "required_components": ["PageHeader", "Toolbar", "SectionCard", "StatusTag"]
  }
}
```

- `recipe` 是语义分类，不是模板名。
- 需要左侧导航列表的页面，`required_components` 加入 `MasterDetail`。
- `required_components` 必须真实出现在页面源文件中。
- 不允许 page-plan 声明组件但页面实际手写。

## 三、视觉规则

### 主从布局

左侧导航列表 + 右侧内容的页面（配置类型、对象目录、树形选择）用 `MasterDetail`：

- 两栏共用一个容器，栏间 1px 分隔线；禁止两张独立卡片并排（双阴影、双圆角、间隙缝）。
- `MasterDetail` 是自带阴影的一体视觉容器：门牌放容器内部顶部，外层不得再包 `SectionCard` 或带题卡（否则双阴影容器）；左栏等子面板不得自带漂浮标题。
- 左栏定宽（token `--layout-master-width`），右栏弹性；右栏内容直接落在主容器内，不再嵌套独立卡片。
- 左栏选中态高亮，与右栏内容联动。
- `MasterDetail` 组件内置 `title`/`description` 门牌 props（样式单源在 `admin.css`），页面不手搓门牌 DOM；分栏区由组件的 `.jjui-master__body`（flex 行容器）承载，右栏 `__main` 带 `min-width: 0`。
- 右栏宽度与溢出纪律见「弹性窄栏」段（对所有弹性窄栏通用）。

### 弹性窄栏

弹性窄栏（`MasterDetail` 右栏、ide 编辑器栏与伴随面板等 flex 弹性内容栏）内容必须自适应容器宽度，禁止整栏横向溢出（栏 scrollWidth 大于容器宽）撑开整页或压扁兄弟分区——实跑验证必查：

- 横向并列内容用可换行/纵向堆叠布局；超宽内容（宽表格等）在窄栏内自开 `overflow-x: auto` 的独立滚动容器，滚动条属于窄栏内部，不撑开整页。
- 窄栏内横排描述列表（Descriptions `column≥2`）塞输入控件是必然挤压的反模式：窄栏内 Descriptions 一律 `column=1` 纵向堆叠；真实产品的横向紧凑字段组用 Form 栅格承载（react `Row`/`Col`、vue `el-row`/`el-col`，列宽随容器自适应），布局保真与防挤压不冲突；描述项 label 只承载字段名（2~8 字），说明句进描述行。
- **描述列表只读**：`Descriptions`/`el-descriptions` 是只读呈现语义——**描述项内（children/content）出现可编辑控件（Input/Select 等）即报**，哪怕 `column=1`；编辑态字段一律用 Form（label 左侧左对齐、控件右侧，无表格底色），"改 column 数"不是过门禁的手段。
- 表格横向滚动兜底（`scroll={{ x: "max-content" }}`）生效前提是父级宽度约束链完整（flex 链路每层 `min-width: 0`）；窄栏内表格优先精简列数，不靠横向滚动兜底常规内容。
- **栏内分区滚动**：窄栏内"固定区 + 滚动区"结构（如树栏搜索框固定、树列表独立滚动）——滚动容器用 `flex: 1 + min-height: 0 + overflow-y: auto` 弹性撑满栏内剩余高度，滚动条贴栏底；**禁止 `max-height`/`height` 写死像素**——滚动条会被钉死在写死高度处，栏下方留死空白。

### 布局壳层

壳层指侧栏、顶栏、内容区的框架。壳层结构由 `src/layouts/AdminLayout.*` 提供，壳层样式单源在 `src/styles/admin.css` 的壳层段落（`.admin-header` / `.admin-sider` / `.admin-layout__content`）：

- **全高侧栏**：侧栏占满视口高度，品牌区（产品名）在侧栏顶部，菜单区独立滚动（`overflow-y: auto`）；品牌不放顶栏。
- **滚动隔离**：整页 `height: 100vh` 不用 window 滚动；顶栏与侧栏固定，只有内容区滚动（`overflow-y: auto`）。后续表头吸顶等 sticky 效果均相对内容区滚动容器生效。
- **顶栏只横跨内容区**：左侧面包屑（由路由派生，必备），右侧业务全局元素（搜索、通知、用户信息、环境标识）。
- 分隔线单源：顶栏底边一条、侧栏右边一条；嵌套容器、卡片、菜单、品牌区不得再叠边框。
- 组件库菜单自带的边框（如 Element Plus 菜单右边框）必须在壳层段落内显式清除。
- 顶栏高度用 `--layout-header-height`，侧栏宽度用 `--layout-sider-width`，内容区顶边距用 `--space-4`，不写死像素。
- 页面标题距顶栏的总距离 = 内容区顶边距（`--space-4`）；`PageHeader` 不得叠加 `margin-top`。
- 布局文件只写结构，不写分隔线、背景、内边距样式；机械校验对壳层段落检查滚动隔离特征（`height: 100vh`、内容区 `overflow-y: auto`）。
- 壳层布局只挂载一次（react 由 App 的布局路由挂载；vue 由路由父级挂载，`App.vue` 只留 `<router-view />`），机械校验对 App 入口重复渲染布局报错。

### 页面

- 内容区使用统一最大宽度，避免长表格被拉伸过宽；取值走 token `--page-max-width`，推荐值域 1280–1600px（模板基线 1440px），宽屏数据表格可取上限。
- 页面标题使用 `PageHeader`，不手写裸 `h1`。
- 用户可见文案的语言纪律正源在 SKILL.md 组合层段「文案语言」条——逐页实现与巡检对照执行，此处不复述。
- 页面描述使用 `PageHeader`，不塞进卡片标题。
- 页面主操作跟随表格：业务表格的主操作（新建/注册等）一律放该表格卡头左翼快捷操作区（不分配方）；`PageHeader` 只承载标题、描述与返回导航——**返回箭头与标题同行垂直居中（titleline 结构），描述独立在标题下方**，箭头不得悬空独占一行、不得挤进描述行；`PageHeader` **不放任何操作控件**——数据操作按语义归位（表格卡头两翼/查询卡/底部状态栏/详情区/操作列），形态切换（链视图等）属表格配置操作，放表格卡头右翼；页面右上角没有操作区。
- 操作保真：每个登记 action 的控件必须实现真实交互流——CRUD/主操作打开弹框表单/抽屉或状态切换，`message` 仅作为流程完成后的结果提示，不得替代流程本身；破坏性操作（删除等）须二次确认（Popconfirm/确认弹框）；表单提交过校验并真实变更 mock 数据（新增/更新/状态流转）。
- 卡标题只在多区块页承载区块独有语义；`list` 配方页的卡片一律不起标题（页面标题已由 `PageHeader` 承载），机械校验对 `list` 配方页任何卡标题报错。
- `list` 配方页含业务表格时必须使用表格卡头两翼结构（`admin.css` 的 `.jjui-table-header`）：左翼主操作 + 快捷搜索、右翼刷新/列设置；禁止把右翼配置图标单独放在表格上方另起一条，也禁止卡头缺左翼。

### 详情呈现

详情内容只允许三种呈现方式，与 page-plan 的 `expected_entry` 对应：

- `drawer` / `modal`：轻详情（一屏内、只读为主），用抽屉或弹框呈现，保持列表上下文。
- `internal-entry`：重详情（多子区块、可编辑、多操作），路由详情页整页呈现，登记独立页面条目与路由。
- `MasterDetail` 同页分栏：仅限窄列表主从工作台。
- 禁止在列表下方平铺详情卡。

列表与详情是页间主从关系，不是两个并列功能页：

- 承载某条主记录详情的页面必须登记 `master_ref`，值为来源页 ID（如 `p-01`）或 `fixed:<数据集>`（详情绑定固定主记录，无来源列表）；不承载主记录的页面不登记。
- `master_ref` 指向来源页 ID 时，路由必须带参数段（如 `/cases/:id`），详情数据由路由参数定位；禁止整页绑定固定下标（如 `dataset[0]`）兜底。
- `expected_entry` 含 `internal-entry` 的页面不得同时含 `menu`：菜单只给导航型入口，详情页由来源列表页的行操作到达。
- 无主记录的页面不得使用 `detail` 配方（改用其他配方或 `MasterDetail` 同页分栏），机械校验据此要求 `detail` 配方页登记 `master_ref`。

### 区块关系

页面区块间只有三种合法关系，实现前先判定：

- **并列**：同级信息，统一间距、平等容器。
- **从属**：一区内容依赖另一区的选中或输入。解法优先选"详情呈现"的独立呈现方式；真正同页从属（表单联动、级联筛选）才用同页表达：未选中时从属区渲染 `EmptyState` 空态（登记进 `states` 与 `structural_texts`），选中后标题带选中项标识。
- **流程**：走"步骤流"判据。

判定不了关系时按并列处理，不发明第四种；并列超过「区块组织」段上限时必须升级为组织形态——并列是兜底，不是堆卡片的默认出口。

### 区块组织

「页面 = 一摞纵向卡片拼凑」是必须禁止的默认行为：单页纵向并列 `SectionCard` 超过 3 张即违规，须改用一种组织形态承载多区块：

- **Tabs 分区**：同级且互斥展示的区块用组件库 `Tabs`/`el-tabs` 承载，Tab 标签（2~6 字名词）登记进 `structural_texts`；pane 内部结构走既有判据（表单/表格/卡片规则照常生效）。
- **Anchor 锚点导航**：区块多且需同屏对照的长页用组件库 `Anchor`/`el-anchor` 侧栏；锚点目标与区块 region 一一对应（区块元素同时携带 `id` 与 `data-jjui-region` 同值）；锚点导航不替代分页，跨页信息仍拆页。
- **MasterDetail 主从 / 详情拆页**：从属关系按「详情呈现」段拆 drawer/独立页，不塞同页堆叠。
- 组织形态豁免堆叠检查：页面真实使用 Tabs/Anchor/MasterDetail 之一即放行并列区块计数；组织形态内仍禁止无意义嵌套卡（容器层级判据照常）。
- 画布/编辑器工作台配方整页禁卡（见「编辑器型页面」段），不受本段豁免。

### 卡片

- 内容区块使用 `SectionCard`。
- 多区域页面（详情、表单、工作台）每个区域一个 `SectionCard`，区块子标题必填（2~6 字名词，如"基本信息""属性列表"），并登记进 page-plan 的 `structural_texts`。
- **单区块页反向约束**：页面仅一张 `SectionCard` 时（非 canvas/ide 配方）卡不起标题与描述——区块子标题的价值是区分多个区块，单卡页纯属页面标题下的重复层级；页面语义由 `PageHeader` 承载，卡描述承载的补充信息并入 PageHeader 描述行，卡内直接放内容。「区块子标题必填」仅约束多区域页。
- 子标题风格统一（同字号、同位置）；补充说明放标题下的描述行；禁止小字注释独立充当区域标题。
- 区域操作必须落在明确容器内——表格头部/底部用 `Toolbar`，卡片级操作用头部 extra，行内操作用操作列；位置由业务定，禁止漂在无容器归属的缝隙里。
- 区域顺序与数量与 page-plan 的 `regions` 一致。
- 卡片有统一圆角、边框、阴影和留白。
- 指标卡语义彩条必须内嵌于卡片圆角内（overflow 裁剪），不得浮出卡片边界。
- 区块内并列子表/子块用次级子标题分隔（`.jjui-section__subtitle`，字号低于区块门牌），文案同样登记进 `structural_texts`；禁止无题表格直接堆叠。
- ID、编号类关键值禁止断行（nowrap）；Descriptions 与摘要卡的窄列给最小宽度。
- 卡片标题承载区块语义，不承载页面标题。
- 卡片描述是可选补充说明。

### 容器层级

卡片是页面区块的最外层视觉容器，层级不用容器表达：

- 卡内不得再嵌套带边框、阴影或独立底色的容器卡。
- 卡内层级只用三种手段表达：间距（space token 分档）、1px 分隔线、次级门牌——不用新容器。
- 组件库控件自带的边框是控件边界，不算嵌套（表格格线、输入框边框合法）；控件外面再包一层框才是违规。
- `MasterDetail` 与工作台页：外层一个容器，内部左右栏直接放内容；右栏分块用次级门牌加间距，不套卡。
- 工作台内部分区（操作条、属性表、左栏列表等）不保留阴影：分区用间距、1px 分隔线、背景色差表达；需要吸顶时用 sticky + 边框分隔（附着语义），不用阴影（浮起语义）。组件库浮层（下拉、Popover、抽屉）自带的阴影合法。

### 工具栏

- **`Toolbar` 是排布容器，不是视觉容器**：只允许布局属性（flex/align-items/justify-content/gap），零盒模型装饰——无 padding、无 margin、无 background、无 border-radius、无 box-shadow；间距全部由宿主卡的 body 统一提供（否则卡包工具条必然双重边距）。页面上的视觉容器只有三种：`SectionCard`、`MetricCard`、`MasterDetail`。
- 列表页查询与操作分三处承载，不得混用：
  - **高级查询独立成卡**：字段筛选（下拉/多字段/组合条件）放 `Toolbar` 的 `filters` 区（左），"查询/重置"按钮放 `actions` 区（右）；独立成卡，紧贴表格卡上方。
  - **触发语义二分，一处筛选只允许一种**：高级查询卡是受控提交式——筛选控件改值不立即生效，点"查询"应用筛选（前端真实过滤 Mock 数据）、点"重置"清空回默认集；快捷搜索是即时过滤式——输入即过滤，禁止再配提交按钮（如 `Input.Search` 的搜索图标按钮 / `enterButton`，用普通输入框）。禁止"选择即生效 + 查询按钮"并存的缝合行为。
- **表格卡头一行两翼**：左侧 = 快捷操作（新建等主操作）+ 快捷查询搜索框（单输入即时过滤）；右侧 = 配置图标（刷新、列设置）。刷新全局唯一，同一语义不得出现两个入口。
  - **行内操作**：表格操作列，只放行级轻操作。
- 表格卡不用 `SectionCard` 的 `title`/`extra` 承载标题或操作（表格卡无标题）；表格正上方不再有独立工具栏条。
- `filters` 与快捷搜索不混排：字段筛选进查询卡，即时搜索进表格卡头。
- **查询卡布局**：字段筛选区用组件库 `Form layout="inline"`（vue `el-form :inline`）承载——label 横排在控件左侧、左对齐，**禁止 label 竖排**（`layout="vertical"`/`label-position="top"` 全局即报，弹框表单一并管住）；每个字段 Form.Item label 必备，placeholder 不替代 label；**字段槽等宽**：label 定宽（`--form-label-width`）+ 控件统一宽度 token（`--control-width`，tokens.css 单源，全字段一档不分控件类型）——跨行后字段左起对齐，禁止写死像素 width；字段超宽自动换行（flex wrap），查询/重置按钮组 `margin-left: auto` 吸附当前行尾整体换行，不孤悬右上。
- 筛选控件与其他可交互控件同权：一律登记操作并带锚点（判据见 `page-archetypes.md` 操作与状态段）。

### 表格

- 业务数据表格必须分页：`pageSize` 10 且显示总数；业务记录 mock 行数 ≥ 25，保证分页器可见、翻页可演示，行数登记进 page-plan 的 `mock_rows`。
- 分页用完整模式且**整组靠右**：总数、每页条数切换、上一页、页码、下一页自左向右连成一组，靠卡片右缘放置，不得左右分散；上一页/下一页是带边框的中文文字按钮（不用裸文字和小箭头）；页码同样全部带边框，激活页码用主色填充白字（不用裸数字）；分页元信息文字（总数、"每页"等标签）用次要文字色（token `--color-text-secondary`），不与正文抢黑，条数值保持清晰。antd 不用 Table 内置分页（其总数/每页条数被拆在两端，且语义化插槽仅 root/item 无法重排）：Table `pagination={false}` + 数据切片，卡内自组合——`Pagination` 的 `itemRender` 渲染带边框文字上下页（可基于受控状态计算 disabled），排布样式单源在 `admin.css` 的 `.jjui-pagination`（只排自有元素，不覆盖组件库内部样式）；element-plus 用 `layout="total, sizes, prev, pager, next"` + `prev-text`/`next-text` 原生达成。两栈组件库的页码默认视觉均弱（antd v6 非激活页码边框透明、激活页白底蓝边；element-plus 页码裸文字），须在 `admin.css` 的 `.jjui-pagination` 段对页码元素做单源收敛（antd `.ant-pagination-item(-active)`，element-plus `.el-pager li(.is-active)`：边框 + 激活主色填充白字），此为组合层基线的单源豁免点，页面与局部样式仍不得覆盖组件库内部样式。
- 表级配置操作（刷新、列设置）放表格卡头右翼：刷新重放当前 Mock 加载，列设置演示列显隐切换；均须登记 action 并带锚点，刷新不得与查询卡的刷新类操作重复。
- 是否分页由 `mock_rows`（该页表格数据集行数）单源判定：`> 10` 必须分页；`≤ 10` 免分页（固定枚举/字典/配置小表、卡内"最近/Top N"摘要表、MasterDetail 左栏窄列表、嵌套子表），机械校验据此对账。
- 列必须显式声明宽度；表格宽度可能超过容器时开启横向滚动（写法见对应栈参考）。
- **操作列**：固定在右侧并给固定宽度（`fixed: "right"` + 定宽，不随动作数扩列）。形态一律**文字链**（antd `Button type="link"`、element-plus `el-button link`），危险动作（删除/驳回等）用 `danger` 文字链 + `Popconfirm` 二次确认；**禁实心/带边框/虚线按钮、禁 icon、禁 disabled 灰字**。语义：操作列只放真实可执行的动作，行级状态归状态列 `StatusTag`（禁「已发布」「无需操作」这类状态伪按钮）；当前行不可执行的动作**不渲染**（列宁毋假——状态列已解释原因），全部动作不可用时操作列留空。布局：直显动作不超过 3 个（单行文字链，Space 统一间距）；超出时前 2 个高频动作直显、其余收进「更多」文字链下拉，危险动作殿后；行内编辑只用于短记录清单表，多字段实体编辑走抽屉或表单页。
- 行内编辑只用于短记录清单表；多字段实体编辑走抽屉或表单页。
- 编辑行单元格一格一控件占满；自由文本不与控件同格（至多配一个固定宽状态标签）。
- 展示行与编辑行同网格对齐，不因进入编辑态跳宽。

### 表单

- 表单项必须带字段 label（组件库 `Form.Item`/`el-form-item` 的 `label`），label 默认左对齐：水平布局用 `labelAlign="left"`（antd）/`label-position="left"`（element-plus），垂直布局天然左对齐。
- placeholder 只作输入示例或提示，不得替代 label 充当字段名（无 label、只靠 placeholder 说明字段是什么，即违规）。
- **字段槽等宽是表单通用判据**（查询卡 inline、弹框/抽屉表单、form 配方页一并管住）：水平表单 label 必须定宽——同一表单各行 label 等宽、控件左起点对齐、控件占满剩余宽度；禁止 `labelCol={{ flex: "none" }}`（label 按文字自然宽度占位，各行控件长长短短）；antd 用 `labelCol` 定宽（`span` 栅格或 flex 定值），element-plus 用 `label-width` 定宽（走 `--form-label-width` token，禁写死像素）；查询卡 inline 的 label 定宽实现见查询卡布局条。控件宽度分场景：查询卡/快捷搜索区统一 `--control-width` 一档；表单容器（弹框/抽屉/form 页）控件不设固定宽度、占满字段槽预留宽度——antd Input 天然占满，Select/DatePicker 须显式 `width: "100%"`（element-plus 同理），不赌组件默认宽。
- 弹框/抽屉表单底部按钮固定为「取消 + 主操作」两个，右对齐放置（取消在主操作左侧）；主操作动词与触发动作语义一致（保存/创建/发布/删除等），同一动作语义全系统同名，不允许逐弹框漂移；禁用"确定/OK"等无语义词。表单页（`form` 配方）底部操作同理。
- 表单校验随交互保真：必填与基础格式（长度/格式）用组件库 rules 校验，提交前拦截、错误就地展示；提交成功真实变更 mock 数据后关闭弹框。
- Modal/Drawer 承载表单的语法见对应栈参考。

### 步骤流

引导/教程/向导类页面是流程语义，不是多个并列区块：

- 一个语义区块一张容器，禁止把一个流程或清单拆成卡片数组。
- 流程骨架用组件库 Steps（竖向），每步的目标、操作、预期结果、入口内嵌为步骤内容（写法见对应栈参考）。
- 进度、状态等从属信息内嵌所属区块头部或描述，不单独成卡。
- 同一信息禁止重复呈现（如总览列表再列一遍各步名称）。

### 编辑器型页面（`canvas` / `ide`）

需要一屏完成「选中对象 → 编辑 → 看校验与辅助信息 → 发布」的编辑页，禁止纵向卡片堆叠，按主编辑面形态登记 `canvas` 或 `ide` 配方：

**共享判据（两种形态同样适用）**：

- **可选中对象**：画布节点与大纲树项带 `data-jjui-node="<id>"`，画布边带 `data-jjui-edge="<id>"`；对象必须可选中（须有交互信号），选中驱动编辑器与伴随面板。
- **伴随面板**：编辑区一侧的伴随面板（`data-jjui-region` 登记）承载选中对象的详情编辑与校验/辅助信息，随选中即时刷新；禁止把伴随内容流放页尾独立成卡。面板内部走容器层级判据（次级门牌 + 间距，不套卡）。
- **底部状态栏**：草稿状态（状态词、基线版本）与校验/发布等页级操作收敛为常驻状态栏；「常驻」用组件库钉住组件承载（react `Affix` / vue `el-affix`——fixed 吸附，滚动全程贴视口底），钉住目标为内容滚动容器；层级由组件库浮层阶梯自动保证（机制依据：antd v6 `zIndexPopup = zIndexBase + 10` 天然高于表格 fixed 列），禁止手写显式 z-index 压层——破坏浮层阶梯是比层级不足更糟的故障模式；钉住是浮层——树/编辑器/伴随面板滚动内容底部须预留状态栏高度间距（`padding-bottom`），保证末尾操作滚到底部完整可达；版本历史等衍生信息经状态栏入口呼出抽屉；禁止草稿操作独立成卡孤悬页首。
- **禁卡片堆叠**：`canvas` / `ide` 页禁止使用 `SectionCard` 与组件库卡片——分区只有主编辑面、伴随面板、状态栏（`ide` 另有大纲树），一体容器、分区用间距与 1px 分隔线表达。
- 机械校验覆盖锚点存在性、对象交互信号、禁卡片特征；选中联动的真实性属行为级，靠浏览器实跑验证。
- **窄栏纪律**：编辑器栏与伴随面板是弹性窄栏，宽度自适应与 Descriptions 用法见「弹性窄栏」段。

**画布形态**（`canvas` 配方）：图是主编辑面（节点=核心实体、边=实体间关系），图整体落画布区（容器锚点 `data-jjui-canvas`）；图视图库属依赖约束的单点豁免（库名单源在对应栈参考），判据不绑定具体库；「禁卡片堆叠」指图本身不得被卡片切碎，不是禁止面板内用次级门牌分区。

**编辑器工作台形态**（`ide` 配方）：结构化主从三栏——左=大纲树（对象分组导航，树项可选中），中=选中对象编辑器（按 `Tabs` 分区，消除纵向长滚动），右=伴随面板；容器锚点 `data-jjui-ide`；伴随面板与状态栏复用共享样式基线（`admin.css` 的 `.jjui-editor-panel` / `.jjui-editor-statusbar`）。

### 状态

- 状态语义用 `StatusTag`。
- 状态分层：行级/控件级状态用 `StatusTag`（表格状态列等）；页级全局信息与提示（系统状态、校验结果、配置说明等）禁止塞进卡片任何位置（extra、表头、表格下方脚注），须用 `Alert`/`el-alert` 放在相关卡片上方、`PageHeader` 之下，按提醒级别选 type（success/info/warning/error），文案登记进 `structural_texts`。
- `StatusTag` 的 `label` 只承载状态词，不得混入含标点的说明句；label 须为字面量状态词——禁止模板串、三元表达式或函数拼接（拼接会绕过标点检查），动态状态词经纯变量/纯函数调用传入；计数说明（"共 N 条 · 显示 M 条"）不是状态词，用次要色文字承载。
- 状态色只允许 `success`、`warning`、`danger`、`info`、`neutral`。
- 不用红绿蓝硬编码。

### 空态

- 列表、详情、搜索结果必须有明确空态语义。
- 可用 `EmptyState`，或组件库空态组件。
- 空态文案必须进入 `structural_texts`。

## 四、禁用项

- 禁止绕过 `PageHeader` 手写页面标题。
- 禁止绕过 `SectionCard` 手写内容卡片。
- 禁止绕过 `StatusTag` 手写状态标签。
- 禁止用 Tailwind、Bootstrap、Chakra 等另一套样式体系。
- 禁止在同一工程混用 Ant Design 和 Element Plus。
- 禁止为了局部样式覆盖组件库内部结构。
- 禁止用外部 CDN 字体、图标、图片或脚本。
- 禁止用随机数、当前时间或外部请求影响渲染。

## 五、机械检查

`check_prototype.py` 会检查：

- `manifest.jjui_version` 与技能版本对账：不一致即报错（版本单源在 SKILL.md frontmatter 的 `metadata.version`，判据、机械校验或模板资产每次变更须递增它），逼旧基线工程重读新判据、按新校验修复后再交付，阻断"凭旧判据记忆工作"的防御。

- `composition.recipe` 合法。
- `composition.required_components` 非空且都属于组合层。
- 页面源文件真实使用了 `required_components`。
- `src/components/admin/` 中存在对应组件文件。
- Token 文件存在。
- 样式基线文件存在，且含布局壳层规则（`.admin-header` / `.admin-sider` / `.admin-layout__content`）。
- 样式基线判据关键段未过期（指标卡彩条须为 `::before` + 容器 `overflow` 裁剪写法，检出旧版 `border-top` 直条即报"样式基线过期"；判据见上文「指标卡语义彩条必须内嵌于卡片圆角内」）。
- 布局文件存在且未内联分隔线样式。
- `list` 配方页含业务表格时须有表格卡头两翼结构（`.jjui-table-header`），且卡头左翼须含快捷搜索输入框（右翼不得独占卡头，否则 space-between 下单子元素靠左）；任何配方的页面，业务表格出现刷新/列设置等表级配置操作而缺卡头两翼即报错。
- 样式基线含表格卡头两翼布局（`.jjui-table-header` 须 `justify-content: space-between`）。
- 主操作跟随表格：`mock_rows > 10` 的业务表格页须有表格卡头两翼且左翼含快捷搜索（不分配方）。
- `PageHeader` 调用片段内出现可交互控件（Button/Select/Input 等）即报——门牌不放操作控件，返回经组件 `onBack` 承载（组件库 text 按钮，非手写 div）。
- 查询卡（`list` 配方页含 `filters=`/`#filters`）：须用 `layout="inline"`/`:inline` 的 Form 承载（字段自动进入表单项 label 必备检查）；源码出现 `layout="vertical"`/`label-position="top"` 即报 label 竖排；查询卡控件内联 style 写死像素 `width` 即报（宽度走 `--control-width-*` token，字段槽等宽跨行才对齐）。
- 样式基线含门牌 titleline 段（`.jjui-page-header__titleline` 须 `display: flex` + `align-items: center`——返回箭头与标题同行的承载特征）。
- 描述列表只读：描述项内出现可编辑控件（react `children: <Input/Select/...>`、vue `el-descriptions-item` 嵌 `el-input` 等）即报——编辑态走 Form；描述项 label 含括号说明句同报（label 只承载字段名）。
- 死按钮对账：登记 action 的控件就近须有交互/反馈信号（onClick/@click/onConfirm/onChange/itemRender/v-model 等），无信号即报死按钮。
- `StatusTag` 的 label 不得含标点说明句（页级全局信息走 Alert）；非字面量 label（`label={` 模板串/三元拼接、vue `:label` 含三元/引号）与计数说明（"共 N 条"）同报——label 须为字面量状态词或纯变量。
- `canvas`/`ide` 页源码出现横排描述列表（Descriptions `column≥2`）即报窄栏挤压反模式（窄栏内一律 column=1，见「弹性窄栏」段）。
- 状态栏须用 `Affix`/`el-affix` 承载（fixed 吸附滚动全程贴视口底）；层级由组件库浮层阶梯自动保证，页面禁止手写显式 z-index 压层；`.jjui-ide__tree`/`.jjui-ide__editor`/`.jjui-editor-panel` 须含底部预留 `padding-bottom`（钉住浮层不遮末尾内容）。
- 分页基线特征：`.jjui-pagination` 整组靠右、元信息次要色（两栈）；antd 有分页的页面须用 `itemRender` 自组上下页；两栈 `admin.css` 须含页码单源收敛（antd `.ant-pagination-item-active` 主色填充，element-plus `.el-pager li` 边框）。
- 画布页（`canvas` 配方）：须有画布容器锚点 `data-jjui-canvas`，节点/边锚点（`data-jjui-node`/`data-jjui-edge`）非空且各自带交互信号；出现 `SectionCard` 或组件库卡片即报（图不得被卡片堆叠切碎）；package.json 须含对应栈的图视图库（单点豁免，库名见栈参考）。
- 编辑器工作台页（`ide` 配方）：须有容器锚点 `data-jjui-ide` 与非空的大纲树项锚点（`data-jjui-node`）且带交互信号；编辑器须用 `Tabs`/`el-tabs` 分区；出现 `SectionCard` 或组件库卡片即报（同共享判据）。
- 样式基线含画布容器段（`.jjui-canvas` 三区一体容器；`.jjui-canvas__body` 分栏须 `min-width: 0` 防横向溢出）与编辑器工作台容器段（`.jjui-ide` 三栏一体容器；`.jjui-ide__body` 同纪律）。
- 区块组织对账：非 `canvas`/`ide` 配方页源码 `<SectionCard` 计数超过 3 张且未使用 Tabs/Anchor/MasterDetail 组织形态即报"并列区块超限"（画布/编辑器页整页禁卡另行对账）。
- 页面计划、路由、锚点、结构文案仍然对账一致。

机械检查能保证"骨架走的是组合层"，不保证视觉满意度；最终仍需人看。

## 六、组合扩展纪律

新出现的组件组合问题（如 Tabs+Drawer、Form+Modal）按同一模式处理：先在该栈参考文档补该组件的用法规范（判据进本文件对应段，语法进栈参考）；同一组合反复翻车才考虑机械化约束，不预建体系。
