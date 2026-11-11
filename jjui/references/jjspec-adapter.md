# jjspec 桥接契约

> jjui 不生成 `ui-specs/`，不复制 jjspec 的提取、绑定或验收规则。它只负责把原型准备成 jjspec HTML 原型路线可直接消化的输入。

## 桥接目录

```text
.jjui/jjspec/
├── bridge.json
├── routes.json
└── excluded-pages.json
```

### bridge.json

只登记运行契约和指针，不登记页面语义。

```json
{
  "schema_version": 1,
  "input_type": "html-prototype",
  "prototype_root": ".",
  "start_command": "npm run build && npm run preview -- --host 127.0.0.1 --port 4173",
  "base_url": "http://127.0.0.1:4173/",
  "viewport": {"width": 1440, "height": 900},
  "dpr": 1,
  "visual_source_globs": ["index.html", "src/**", "public/**", "package.json", "vite.config.ts", "tsconfig.json"],
  "tokens_file": "src/styles/tokens.css",
  "route_registry": ".jjui/jjspec/routes.json",
  "excluded_pages": ".jjui/jjspec/excluded-pages.json"
}
```

- `visual_source_globs` 排除 `node_modules/`、`dist/`、报告和截图。
- `base_url` 必须本机可达。
- `route_registry` 和 `excluded_pages` 只是给 jjspec 对账提供输入，不是菜单结构正源。

### routes.json

登记实现路由清单，供菜单三源对账使用；真实菜单仍以渲染态 DOM 和到达路径为准。

### excluded-pages.json

登记排除线索；最终仍以 PRD 非目标表为准。

## 页面与锚点

- `page-plan.json` 的页面 ID 使用 `p-01`、`p-02` 等稳定编号。
- 每页必须有稳定 `data-jjui-page`。
- 区域、操作、动态数据分别使用 `data-jjui-region`、`data-jjui-action`、`data-jjui-data`。
- 锚点是辅助定位，不是提取范围；jjspec 仍扫完整渲染 DOM。

## 文案与动态区

- 静态结构文案登记在 `structural_texts`。
- 动态数据文本放显式 `data-jjui-data` 区域。
- 禁止在结构区新增计划外文案。
- 禁止使用随机数、当前时间或外部请求影响渲染。

## 冻结与交付

- 交付前 `check_prototype.py` 必须 PASS。
- 交付信息包括启动命令、页面清单、已实现交互、Mock 假设和未验证项。
- 交给 jjspec 的输入是原型目录路径，不是截图。
- jjspec 侧的 `entry`、`source_anchor`、四件套、绑定和验收由其自身规则执行。
