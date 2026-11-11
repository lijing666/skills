---
name: jjui
description: "管理后台前端原型生成 skill：基于 React+Ant Design 或 Vue3+Element Plus 生成可运行、可冻结、可直接接入 jjspec HTML 原型路线的后台原型工程。适用于客户/订单/运营/配置类后台、列表-详情-表单-设置页面，以及需要用真实组件库替代手绘页面、并把原型交付给 jjspec 做后续 UI 规范与实现验收的场景；不适用于营销页、小程序、移动端、图片像素级还原、真实后端或生产级架构。"
metadata:
  version: 0.2.27
  created: "2026-11-08"
---

# jjui · 管理后台原型生成

以真实组件库为视觉真源，以组合层（壳层 + Token + 组件 + 排布配方）约束视觉一致性，以页面计划管需求覆盖，以确定性检查管工程与渲染层质量，以 jjspec-ready 桥接层承接后续 UI 规范管线。

## 组合层（Admin UI Composition Layer）

界面质量不靠堆模板，靠四层约束：

- **壳层**：`src/layouts/AdminLayout` 提供顶栏/侧栏/内容区框架，分隔线与间距单源在 `src/styles/admin.css` 壳层段落；布局文件不内联分隔线样式，页面标题距顶栏不得过远。
- **Token**：`src/styles/tokens.css` 统一色彩、间距、圆角、阴影；页面样式不得绕过 Token。
- **组件**：`src/components/admin/` 下七个受控组合组件——`PageHeader`、`SectionCard`、`MetricCard`、`Toolbar`、`StatusTag`、`EmptyState`、`MasterDetail`；页面必须声明并实际使用计划内组件。
- **配方**：每页在 page-plan 的 `composition.recipe` 中登记排布配方（`dashboard` / `list` / `detail` / `form` / `settings` / `workspace` / `canvas` / `ide`），机械校验拒绝配方外排布与"声明未使用"组件。
- **文案语言**（本条为文案语言正源，`composition-layer.md` 不复述）：原型全部用户可见文案（标题、描述、label、按钮、提示、说明、空态）一律中文——真实产品中这些字符串走 i18n 词条，原型直接落中文定稿。判据只问一句：**这串字符将来要不要翻译？** 要翻译的必须已是中文；机器标识符不受限（枚举值、事件名、状态机标识、样例标识如 `SCHEMA_PUBLISHED`、`batch`、`qwen3-4b-local` 是代码常量，不是文案）。

判定与排布细节见 `references/composition-layer.md`。

## 适用边界

- 只生成管理后台前端原型，默认为桌面端。
- 只支持 React + Ant Design 或 Vue3 + Element Plus。
- 所有数据固定 Mock；不接真实后端、数据库、鉴权或生产 API。
- 不做营销页、小程序、移动端、图片像素级还原、UI 规格生成或生产级架构。
- 首次创建必须显式选择技术栈；写入 manifest 后锁定，不在原项目内切换栈。

## 工作流 A：新建后台原型

1. **范围判定**：确认是管理后台前端原型；非后台需求拒绝本技能。
2. **技术栈确认**：显式选择 `react-antd` 或 `vue3-element-plus`；未选择时停靠询问。
3. **页面计划封闭**：读取 `references/page-archetypes.md`，列出页面、路由、菜单、字段、操作、状态、Mock 数据和假设；模糊处集中确认。
4. **初始化工程**：运行 `scripts/init_prototype.py` 从对应模板复制工程；先读 `references/prototype-contract.md`。
5. **实现页面**：按栈读 `references/react-antd.md` 或 `references/vue3-element-plus.md`；按页面计划的 `composition.recipe` 用组合层组件排布，再以组件库组件填充内容。
6. **锚点与分层**：给页面、区域、操作、动态区加稳定 `data-jjui-*` 锚点；静态结构文案入页面计划，动态数据放显式 `data-jjui-data` 区。
7. **机械校验**：运行 `scripts/check_prototype.py <原型目录>`；修复到 PASS。
8. **实跑验证**：按 manifest 启动工程，逐页实跑，确认无控制台错误、页面不空白、声明交互可演示；截图用绝对路径落盘 `.jjui/reports/screenshots/<page_id>-<场景>.png`，每张立即核验存在且非 0 字节，交付前用 `scripts/evidence.py check` 逐页对账。交互演示一律用 playwright 原生 click/fill 等真实输入事件，禁止 JS `el.click()` 注入点击——antd 等组件的事件可能不响应注入点击，会误判交互失效。**升级依赖后必须重启 dev server 再验证**（旧进程的 `.vite/deps` 预构建残留会静默供给旧版组件，让新 API"看起来未实装"）；进程新鲜度判定：页面模块 URL 的 `?v=<hash>` 与 `node_modules/.vite/deps/_metadata.json` 的 `browserHash` 不一致即过期。
9. **交付**：输出启动命令、页面清单、已实现交互、Mock 假设和未验证项，以及"规范坑回流清单"——执行过程中发现的与技能判据冲突的组件库事实（版本差异、API 不存在、静默失败）；不宣称业务需求或生产验收通过。
   - 回流纪律：每条回流必须给出可定位源（文件 + 行号 + 原文引用），引用不出原文的判断一律不提出；版本口径以模板 `package.json` 为准，引用他版资料先声明版本差异。
   - 新鲜度纪律：重载技能或跨会话续作时，先重读本次工作涉及的判据正源（`references/*.md`）再下结论，不得拿缓存 grep 结果或记忆当现状；判据是否漂移以 `manifest.jjui_version` 与 SKILL.md 声明的技能版本对账为准（不一致时 `check_prototype.py` 必报）。

## 工作流 B：需求增量修改

触发：任何对既有原型工程（含 `.jjui/` 目录的工程）的改动请求，无论多小——改样式、改文案、加按钮都算；不得绕过本工作流直接改代码。

1. 先改 `.jjui/page-plan.json`，登记新增/修改/删除页面、字段、操作、状态和 `composition` 契约。
2. 只修改受影响页面及必要共享模块；不重写 `src/custom/`。
3. 不切换技术栈、不重排页面 ID。
4. 重跑 `check_prototype.py` 与受影响页面的实跑验证；check FAIL 时不得交付，修复到 PASS 为止。
5. 交付增量对账清单，标明未受影响页面；如过程中发现与技能判据冲突的组件库事实，一并输出"规范坑回流清单"。

## 工作流 C：规范对齐巡检

存量工程按当前判据全面自查与修复，适用于判据更新后清理旧工程、或交付前全面验收：

1. **逐页实跑截图**：按 manifest 启动工程，逐页截图（走截图物证纪律，绝对路径落 `.jjui/reports/screenshots/`）。
2. **对照判据检查**：以 `references/composition-layer.md` 全部判据为清单逐条对照；壳层与全局组件问题（布局壳、菜单、指标卡等）单列在前。
3. **输出违规清单**：每条 = 页面 + 判据名 + 证据（截图编号）+ 修复建议；经确认后再动手修复。
4. **修复与回归**：修复后重跑 `check_prototype.py` 与 `evidence.py check`，更新截图物证；本工作流只引用判据正源，不复述判据内容。

## 资源索引

| 资源 | 何时使用 |
|---|---|
| `references/composition-layer.md` | 实现页面、扩展组合组件或调整样式基线时 |
| `references/prototype-contract.md` | 初始化、调整目录、manifest/page-plan/bridge 或锚点时 |
| `references/page-archetypes.md` | 做页面封闭清单或判定页面类型时 |
| `references/react-antd.md` | React 路线实现页面时 |
| `references/vue3-element-plus.md` | Vue 路线实现页面时 |
| `references/jjspec-adapter.md` | 准备交给 jjspec 或生成桥接文件时 |
| `assets/react-antd-template/` | React + Ant Design 原型初始化 |
| `assets/vue3-element-plus-template/` | Vue3 + Element Plus 原型初始化 |
| `scripts/init_prototype.py` | 从模板初始化可运行工程 |
| `scripts/check_prototype.py` | 工程结构、页面覆盖、锚点、路由和桥接层检查 |
| `scripts/evidence.py` | 交付前对账逐页截图物证 |
| `scripts/test_tools.py` | 修改脚本或契约后运行端到端回归 |

## 完成判据

- 页面计划 ↔ 页面文件 ↔ 路由注册一一对应。
- 菜单和入口真实可达，无死页面，无计划外菜单。
- 列表与详情按主从关系建模：详情页登记 `master_ref`，非导航型详情页不挂菜单（判据见 `references/composition-layer.md` 详情呈现段）。
- 静态文案有计划来源，动态数据在显式 `data-jjui-data` 区。
- Token 文件存在，组件库唯一，样式不绕过 Token。
- 每页有合法 `composition.recipe`，声明的组合层组件真实存在且被页面使用。
- 工程根无计划外条目：工具快照、会话目录（如 `.playwright-cli/`）不入工程，物证只落 `.jjui/reports/`。
- 桥接文件合法，无外部 CDN 运行依赖。
- 固定视口下逐页实跑无控制台错误。
- 通过 `check_prototype.py` 机械校验。
