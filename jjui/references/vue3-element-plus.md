# Vue3 + Element Plus 实现契约

> 适用于 `stack = vue3-element-plus`。组件库为视觉真源；页面结构由页面计划约束。

## 组件映射

| 能力 | Element Plus |
|---|---|
| 布局 | `el-container` / `el-aside` / `el-main` |
| 导航 | `el-menu` |
| 表格 | `el-table` |
| 表单 | `el-form` |
| 弹窗 | `el-dialog` |
| 抽屉 | `el-drawer` |
| 详情 | `el-descriptions` |
| 反馈 | `ElMessage` |
| 指标 | `el-statistic` |
| 卡片 | `el-card` |

## 规则

- 优先使用 Element Plus 组件；有对应组件时禁止手写原生控件。
- 图标优先用 `@element-plus/icons-vue`。
- 自定义 SVG 不允许临场手绘冒充设计资产；必须来自登记资产或占位待确认。
- 路由使用 Vue Router；菜单通过 `el-menu` 渲染。
- 页面文件放 `src/pages/<页面ID>-<短名>/index.vue`。
- 页面根节点带 `data-jjui-page`。
- 区域、操作、动态数据分别带 `data-jjui-region`、`data-jjui-action`、`data-jjui-data`。
- 使用 TypeScript 与 `<script setup>`；禁止引入 React、Ant Design 或另一套组件库。
- 主题用 Element Plus CSS 变量；不要用全局 CSS 覆盖组件库内部样式。唯一豁免：分页样式收敛（`.btn-prev`/`.btn-next` 边框、`.el-pagination__total` 次要色）单源落在 `admin.css` 的 `.jjui-pagination` 段，判据见 `composition-layer.md` 表格段。

## el-table 用法

> 判据正源：`composition-layer.md` 表格段；本节只写 Element Plus 语法。

- 每列显式设置 `width`（或 `min-width`）。
- 预期超宽时把表格放进 `overflow-x: auto` 的容器，或给表格设 `min-width`，在容器内出横向滚动。
- 操作列：`fixed="right"` 加显式 `width`。
- 行内编辑行：单元格内只渲染一个控件占满；状态标签用 `el-tag` 紧随其后。
- 长文本列用 `show-overflow-tooltip`，不手工挤压。

## el-alert 页级提醒

> 判据正源：`composition-layer.md` 状态段；本节只写 Element Plus 语法。

- 页级全局信息放 `<el-alert type="success|info|warning|error" :title="..." show-icon />`，位置在 `PageHeader` 之下、相关卡片之上；禁止把说明文字塞进卡片 extra、表头或表格下方。

## el-dialog 表单用法

> 判据正源：`composition-layer.md` 表单段；本节只写 Element Plus 语法。

- 表单项一律 `el-form-item` 带 `label`；水平布局 `el-form` 加 `label-position="left"`；placeholder 只写输入示例，不承载字段名。
- el-dialog 底部按钮：footer 插槽渲染「取消 + 主操作」两个右对齐按钮，主操作动词与动作语义一致，全系统同名，不用"确定"。
- 表单校验：`el-form` `:rules` + `validate()` 拦截；提交成功真实变更 mock 数据后关闭弹框，`ElMessage.success` 只作结果提示。
- 破坏性操作用 `el-popconfirm` 二次确认；刷新类操作触发真实 loading（`v-loading` + 固定延时复位）。

## 查询卡与快捷搜索写法

> 判据正源：`composition-layer.md` 工具栏段（触发语义二分）；本节只写 Element Plus 语法。

- 高级查询卡是受控提交式：筛选控件绑定 draft ref（`draftKeyword`/`draftStatus`），点"查询"拷入 `applied` ref 并回到第 1 页，点"重置"同时清 draft 与 applied；表格过滤只读 `applied` 与快捷搜索词。参照模板 `src/pages/p-02-customer-list/index.vue`。
- 快捷搜索是即时过滤式：普通 `el-input` 加 `:prefix-icon="Search"` + `clearable`，`@input` 回到第 1 页、输入即过滤；禁止给快捷搜索配任何提交按钮。
- 查询卡的 `el-select` 加 `clearable`，与"重置回默认集"语义配套。

## 画布用法（@vue-flow/core）

> 判据正源：`composition-layer.md` 画布段；本节只写 vue 栈语法与依赖豁免。库版本单源在模板 `package.json`。

- **依赖豁免单源**：vue 栈 `canvas` 配方页允许且仅允许额外安装 `@vue-flow/core`（社区成熟稳定版）；早期替代品（如 @xyflow/vue）在稳定版发布前不进入豁免清单。参照模板 `src/pages/p-03-canvas-editor/index.vue`。
- 画布容器：`<VueFlow ... />` 外层容器带 `data-jjui-canvas` 锚点并给定高度（画布不随 window 滚动）；样式引入 `import "@vue-flow/core/dist/style.css"` 合法（库级样式），页面不得手写 box-shadow 覆盖画布控件。
- 节点锚点：`#node-<type>` 插槽根元素带 `:data-jjui-node="props.id"` 与 `@click`（插槽闭包可直接调选中函数）；边锚点：`#edge-<type>` 插槽内用 `BaseEdge` + `EdgeLabelRenderer` 渲染标签元素，带 `:data-jjui-edge="props.id"` 与 `@click`（标签元素须 `pointer-events: all` 才可点，样式单源在 `admin.css` 的 `.jjui-canvas__edge-label`）。
- 节点/边高亮用插槽 props 的 `selected` 态拼 class，选中数据驱动伴随面板渲染。

## el-tabs 与 el-anchor 组织形态

> 判据正源：`composition-layer.md` 区块组织段；本节只写 Element Plus 语法。

- 多区块互斥切换用 `el-tabs` + `el-tab-pane`（`label` 为 2~6 字名词，登记 page-plan `structural_texts`）；pane 内部按区块内容走既有判据，禁止把整页卡片原样搬进 pane 缝合了事。
- 长页同屏对照用 `el-anchor`（`:anchor-el` 或默认按容器）：锚点目标元素同时携带 `id` 与 `data-jjui-region` 同值；内容区为独立滚动容器时用 `:scroll-el` 指向内容区，不用 window 滚动。

## el-steps 用法

> 判据正源：`composition-layer.md` 步骤流段；本节只写 Element Plus 语法。

- 流程骨架用 `el-steps`（`direction="vertical"`）加 `el-step`；步骤详情放 `el-step` 的 `description` 或紧跟其后的内容区。
- 步骤状态用 `active` / `finish-status` 表达完成与进行中。
- 不用多张卡片模拟步骤，也不用无序列表模拟步骤条。
