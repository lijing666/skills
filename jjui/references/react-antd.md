# React + Ant Design 实现契约

> 适用于 `stack = react-antd`。组件库为视觉真源；页面结构由页面计划约束。

## 组件映射

| 能力 | Ant Design |
|---|---|
| 布局 | `Layout` / `Layout.Sider` / `Layout.Content` |
| 导航 | `Menu` |
| 表格 | `Table` |
| 表单 | `Form` |
| 弹窗 | `Modal` |
| 抽屉 | `Drawer` |
| 详情 | `Descriptions` |
| 反馈 | `message` |
| 指标 | `Statistic` |
| 卡片 | `Card` |

## 规则

- 优先使用组件库组件；有对应组件时禁止手写原生控件。
- 图标优先用 `@ant-design/icons`。
- 自定义 SVG 不允许临场手绘冒充设计资产；必须来自登记资产或占位待确认。
- 路由使用 React Router；菜单通过 `Menu` 渲染。
- 页面文件放 `src/pages/<页面ID>-<短名>/index.tsx`。
- 页面根节点带 `data-jjui-page`。
- 区域、操作、动态数据分别带 `data-jjui-region`、`data-jjui-action`、`data-jjui-data`。
- 使用 TypeScript；禁止引入 Vue、Element Plus 或另一套组件库。
- 使用 `ConfigProvider` 控制语言和主题；不要用全局 CSS 覆盖组件库内部样式。

## Table 用法

> 判据正源：`composition-layer.md` 表格段；本节只写 antd 语法。

- 每列在 `columns` 中声明 `width`。
- 预期超宽时设 `scroll={{ x: "max-content" }}`，内容撑开并在表格容器内出横向滚动。
- 操作列：`fixed: "right"` 加显式 `width`。
- 行内编辑行：单元格内只渲染一个控件占满；状态标签用 `Tag` 紧随其后。
- 长文本列用 `ellipsis`，不手工挤压。
- 分页完整模式（自组合，整组靠右）：Table `pagination={false}`，数据按 `current`/`pageSize` 切片；卡内底部 `<div className="jjui-pagination">` 内连成一组靠右——总数、每页条数 `Select`、`Pagination`（`current`/`pageSize`/`total` 受控、`showSizeChanger={false}`、`itemRender` 把前后页渲染成**带边框**的"上一页/下一页" `Button`，并按受控状态计算 disabled）。禁止用 `prevIcon`/`nextIcon`（rc-pagination 内部属性，非官方 API），禁止用 CSS 覆盖 `.ant-pagination-*` 内部结构重排，禁止把总数拆到左侧分散放置；禁止给 `Pagination` 套 `ConfigProvider` 组件 token 收敛样式（token 名随组件版本漂移、不可达，分页样式单源在 `admin.css` 的 `.jjui-pagination`）。

## 查询卡与快捷搜索写法

> 判据正源：`composition-layer.md` 工具栏段（触发语义二分）；本节只写 antd 语法。

- 高级查询卡是受控提交式：筛选控件绑定 draft 状态（`draftKeyword`/`draftStatus`），点"查询"把 draft 拷入 `applied` 并回到第 1 页，点"重置"同时清 draft 与 applied；表格过滤只读 `applied` 与快捷搜索词，draft 改值不触发表格变化。参照模板 `src/pages/p-02-customer-list/index.tsx`。
- 快捷搜索是即时过滤式：普通 `Input` 加 `prefix={<SearchOutlined />}` + `allowClear`，输入即过滤并回到第 1 页；禁止 `Input.Search`（自带搜索按钮）与 `enterButton`——即时过滤没有提交动作，搜索按钮是死控件。

## Alert 页级提醒

> 判据正源：`composition-layer.md` 状态段；本节只写 antd 语法。

- 页级全局信息放 `<Alert type="success|info|warning|error" showIcon message="..." />`，位置在 `PageHeader` 之下、相关卡片之上；禁止把说明文字塞进卡片 extra、表头或表格下方。

## Modal 表单用法

> 判据正源：`composition-layer.md` 表单段；本节只写 antd 语法。

- 表单项一律 `Form.Item` 带 `label`；水平布局加 `labelAlign="left"`；placeholder 只写输入示例（如"请输入 11 位手机号"），不承载字段名。
- Modal 底部按钮：`footer` 或 `onOk`/`onCancel` 渲染「取消 + 主操作」两个右对齐按钮，主操作动词与动作语义一致（如"创建草稿""保存"），全系统同名，不用"确定"。
- 表单校验：`Form` + `rules`（必填/基础格式），`onOk` 内 `validateFields()` 拦截；提交成功真实变更 mock 数据（新增/更新行）后关闭弹框，`message.success` 只作结果提示。
- 破坏性操作（删除）用 `Popconfirm` 二次确认；刷新类操作触发真实 loading 重载（Table `loading` + 固定延时复位）。

## Space 用法与依赖升级验证纪律

> 判据正源：`composition-layer.md` 主从布局段（右栏宽度纪律）；本节只写 antd 语法。

- antd 6.7.0 实测：Space 与 Steps 的 `orientation="vertical"` 均已实装（DOM 出现 `.ant-space-vertical` / `.ant-steps-vertical`）；`direction` 仍向后兼容但触发废弃警告。纵向排布统一写 `orientation="vertical"`。
- **静默失败真源是过期 dev server，不是 API**：升级依赖（如 antd 6.7.0）后，长驻的 dev server 仍在用升级前预构建的旧 chunk（`.vite/deps` 内存残留），新 API 全部"看起来未实装"——运行时验证前必须重启 dev server（必要时删 `node_modules/.vite`）。判定进程新鲜度：页面模块 URL 的 `?v=<hash>` 与 `node_modules/.vite/deps/_metadata.json` 的 `browserHash` 不一致即过期。
- Steps 的 `items[].content` 在普通模式实测渲染（6.7.0）；`items[].description` 同样渲染但触发废弃警告，应迁移到 `content`。

## 画布用法（@xyflow/react）

> 判据正源：`composition-layer.md` 画布段；本节只写 react 栈语法与依赖豁免。库版本单源在模板 `package.json`。

- **依赖豁免单源**：react 栈 `canvas` 配方页允许且仅允许额外安装 `@xyflow/react`（React Flow 官方包）；其余页面不得使用。参照模板 `src/pages/p-03-canvas-editor/index.tsx`。
- 画布容器：`<ReactFlow ... />` 外层容器带 `data-jjui-canvas` 锚点并给定高度（画布不随 window 滚动）；样式引入 `import "@xyflow/react/dist/style.css"` 合法（库级样式），页面不得手写 box-shadow 覆盖画布控件。
- 节点锚点：自定义 `nodeTypes` 节点组件根元素带 `data-jjui-node={id}` 与 `onClick`（选中回调经节点 `data` 注入，`setSelectedId` 引用稳定）；边锚点：自定义 `edgeTypes` 边组件内用 `EdgeLabelRenderer` 渲染标签元素，带 `data-jjui-edge={id}` 与 `onClick`（`EdgeLabelRenderer` 容器 `pointer-events: none`，标签元素须 `pointer-events: all` 才可点，样式单源在 `admin.css` 的 `.jjui-canvas__edge-label`）。
- 节点/边高亮用组件传入的 `selected` 态拼 class，选中数据驱动伴随面板渲染。

## Tabs 与 Anchor 组织形态

> 判据正源：`composition-layer.md` 区块组织段；本节只写 antd 语法。

- 多区块互斥切换用 `Tabs items={[...]}`；Tab 标签 2~6 字名词并登记 page-plan `structural_texts`；pane 内部按区块内容走既有判据（Form/Table/SectionCard 规则照常生效），禁止把整页卡片原样搬进 pane 缝合了事。
- 长页同屏对照用 `Anchor items={[...]}`：锚点目标元素同时携带 `id` 与 `data-jjui-region` 同值（region 锚点登记对账复用）；内容区为独立滚动容器时，`Anchor` 用 `getContainer={() => 滚动容器引用}` 指向内容区，不用 window 滚动。

## Steps 用法

> 判据正源：`composition-layer.md` 步骤流段；本节只写 antd 语法。组件库版本单源在模板 `package.json`（当前 antd ^6）。

- 流程骨架用 `Steps`，竖向加 `orientation="vertical"`（v6 起 `direction` 已废弃）；步骤详情用 `items[].content` 内嵌（v6 起 `description` 已废弃，误用会被运行时静默丢弃且 tsc 不报错——`.map()` 返回值不受多余属性检查约束）。
- 步骤状态用 `current` / `status` 表达完成与进行中。
- 不用多张卡片模拟步骤，也不用无序列表模拟步骤条。
