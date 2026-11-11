# 原型目录、manifest 与页面计划契约

> 适用于 jjui 初始化、结构调整和检查脚本口径。评估对象是一个 `admin-prototypes/<产品ID>-<业务大项>/` 原型目录。

## 固定结构

```text
admin-prototypes/<产品ID>-<业务大项>/
├── README.md
├── package.json
├── package-lock.json
├── vite.config.ts
├── index.html
├── src/
│   ├── main.tsx / main.ts
│   ├── App.tsx / App.vue
│   ├── layouts/
│   ├── router/
│   ├── pages/
│   ├── components/
│   ├── mock/
│   ├── styles/
│   └── custom/
└── .jjui/
    ├── manifest.json
    ├── page-plan.json
    ├── jjspec/
    │   ├── bridge.json
    │   ├── routes.json
    │   └── excluded-pages.json
    └── reports/
        ├── screenshots/
        └── smoke/
```

- `package-lock.json` 在安装后必须存在；模板阶段可以暂缺，交付阶段必须有。
- `src/custom/` 是使用者扩展区；模板再生成不得覆盖。
- `.jjui/reports/` 存本技能自验截图与烟测记录，不冒充 jjspec 的 `baselines/`。

## 截图物证纪律

截图工具的相对路径按其常驻进程的 cwd 解析，与工作目录无关，禁止使用相对路径截图：

- 截图一律用**绝对路径**落盘到 `<原型目录绝对路径>/.jjui/reports/screenshots/`。
- 命名契约：`<page_id>-<场景>.png`，如 `p-01-dashboard.png`、`p-02-customers-empty.png`；同页多变体用场景后缀区分，不用 `截图1`、`临时`、`final` 等无语义名。
- 每次截图后**立即核验**：`ls -la` 确认文件存在且非 0 字节；未核验 = 未落盘，截图工具返回成功不算证据。
- 交付前运行 `python3 scripts/evidence.py check <原型目录>` 逐页对账；缺页、文件过小（疑似空白）、命名不符都会 FAIL。
- 重画页保留前后对比：`<page_id>-<场景>-before.png` 与 `<page_id>-<场景>-after.png` 成对登记；多轮重画只保留最后一对，旧对比轮次删除。
- reports 是可再生物证：可整体清空后按同契约重拍，工程源码才是唯一源头；不得把截图当唯一留存的手工资产。

## 工具残留隔离

playwright-cli、agent-browser 等工具的快照 dump 和会话目录默认落在 cwd（如根目录出现 `p01.yml`、`filter.yml`，工程内出现 `.playwright-cli/`）：

- 快照/截图/日志一律显式指定绝对路径，产物只允许落 `.jjui/reports/`；不指定路径的工具调用视为违规，产物即使生成成功也要删除重做。
- 工具会话目录（如 `.playwright-cli/`）禁止留在工程内：要么把工具工作目录设到工程外，要么用完即删。
- 工程根只允许固定结构条目（见上文目录树）加版本管理与构建产物（`.git`、`node_modules`、`dist` 等）；`check_prototype.py` 按白名单拒绝计划外根条目。

## manifest.json 最小字段

```json
{
  "schema_version": 1,
  "kind": "admin-prototype",
  "product_id": "<kebab-case>",
  "business": "<kebab-case>",
  "stack": "react-antd | vue3-element-plus",
  "start_command": "npm run build && npm run preview -- --host 127.0.0.1 --port 4173",
  "base_url": "http://127.0.0.1:4173/",
  "viewport": {"width": 1440, "height": 900},
  "dpr": 1,
  "tokens_file": "src/styles/tokens.css",
  "page_plan": ".jjui/page-plan.json",
  "route_registry": ".jjui/jjspec/routes.json",
  "excluded_pages": ".jjui/jjspec/excluded-pages.json",
  "visual_source_globs": ["index.html", "src/**", "public/**", "package.json", "vite.config.ts", "tsconfig.json"]
}
```

- `stack` 创建后锁定。
- `visual_source_globs` 是冻结范围，禁止包含 `node_modules/`、`dist/`、报告或截图。
- `base_url` 只允许本机地址。

## page-plan.json 最小字段

每页至少登记：

| 字段 | 说明 |
|---|---|
| `id` | `p-01`、`p-02` 等稳定编号 |
| `slug` | 英文 kebab-case 短名 |
| `title` | 业务标题 |
| `route` | 渲染可达路由 |
| `file` | 页面源文件 |
| `expected_entry` | 预期到达方式，值域同 jjspec：`menu` / `internal-tab` / `internal-entry` / `drawer` / `modal` / `unreachable` |
| `master_ref` | 主记录来源页 ID 或 `fixed:<数据集>`；承载主记录详情的页面必须登记，约束见 `composition-layer.md` 详情呈现段 |
| `regions` | 页面区域与锚点 |
| `actions` | 可操作点与锚点 |
| `dynamic_regions` | 动态数据区、锚点与数据集 |
| `structural_texts` | 静态结构文案封闭清单 |
| `states` | 已实现状态 |
| `mock_dataset` | 固定数据集 |
| `acceptance` | 原型自验项 |

- 页面 ID 创建后不重排。
- `expected_entry` 只是自查预期；真实 `entry` 由 jjspec 从渲染态采集。
- `expected_entry` 含 `internal-entry` 时不得同时含 `menu`，且该页必须登记 `master_ref`（约束见 `composition-layer.md` 详情呈现段）。
- 路由、文件、页面 ID 都必须唯一。
- 静态结构文案必须封闭登记，不得在实现里新增计划外文案。
- 动态数据必须放进显式 `data-jjui-data` 区域。

## 稳定锚点

```html
<div data-jjui-page="p-01">
  <section data-jjui-region="p-01.filter">...</section>
  <button data-jjui-action="p-01.create">新建</button>
  <div data-jjui-data="p-01.customer-rows">...</div>
</div>
```

- `data-jjui-page` 每页必须有且唯一。
- `regions`、`actions`、`dynamic_regions` 的锚点必须存在于页面源文件。
- 锚点用于定位与对账，不代表提取范围；jjspec 仍扫完整渲染 DOM。

## Token 与样式

- 每个原型必须有唯一 Token 文件，如 `src/styles/tokens.css`。
- React 通过 Ant Design 主题与 CSS 变量映射。
- Vue 通过 Element Plus CSS 变量映射。
- 颜色、字号、间距、圆角、阴影等不得散落硬编码。
- 禁止大段全局 CSS 覆盖组件库内部结构。

## 依赖约束

- 只允许安装所选栈的组件库。
- 禁止同一工程混用 Ant Design 与 Element Plus。
- 默认不引入 Redux、Pinia、Axios、Tailwind、ECharts；确需图表时另行确认。
- 依赖唯一豁免：`canvas` 配方页允许且仅允许额外安装对应栈参考声明的图视图库一个 npm 依赖（react 栈见 `react-antd.md` 画布段、vue 栈见 `vue3-element-plus.md` 画布段）；其余第三方 UI/数据/图表库仍默认禁止。
- 组件库可组合的形态优先用组件库组合（如状态栏 = `Affix` + `Space`），禁止为单一组件引入扩展组件库全家桶（如 `@ant-design/pro-components`）：随包可达的 ProTable 等自封装组件会绕开全部表格机判特征（itemRender/表头结构），撕裂判据体系，且此类包无 vue 对等物、破坏双栈对等。
- 不使用外部 CDN 字体、图片、图标库。
