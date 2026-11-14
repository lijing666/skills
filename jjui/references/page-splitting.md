# 页面内部分层（Page / Feature / Service / Shared）

> 评估对象是单个页面目录 `src/pages/<page_id>/` 与其依赖的服务层。本文件只管「代码放哪一层」；组件排布与视觉判据正源仍在 `composition-layer.md`，语法见对应栈参考，此处均不复述。

## 一、四层模型

| 层 | 位置 | 职责 | 禁止 |
|---|---|---|---|
| Page | `src/pages/<page_id>/index.<ext>` | 入口装配：路由参数、布局壳、Feature 组合、页级 loading/empty/error、共享状态编排 | 内联 Drawer/Modal/Tab pane 实现体 |
| Feature | `src/pages/<page_id>/features/` | 封闭交互单元：Tab 分区、抽屉/弹框表单、表格区、画布与 IDE 的大纲树/编辑器/伴随面板 | 跨页复用（跨页复用属组合组件层或 Shared） |
| Service | `src/services/<entity>-service.ts` | 实体数据契约：接口定义 + mock 实现 | 真实网络请求 |
| Shared | `src/components/admin/` 七组件 | 组合层白名单组件（判据见 `composition-layer.md`） | 绕过白名单另造组件 |

Entity（实体类型）不是独立层：类型定义住 Service 文件内，随契约一起导出。

## 二、Feature 拆分判据

入口文件只做装配。满足任一机械对应物即拆 Feature：

- **Tab 分区**：`Tabs`/`el-tabs` 的 pane 实现体不进入口文件。
- **浮层**：`Drawer`/`el-drawer`、`Modal`/`el-dialog` 的实现体不进入口文件。Page 级页态 `Alert` 不属浮层，留在入口合法。
- **伴随面板**：画布/IDE 主编辑面一侧的封闭面板（大纲树、编辑器分区、伴随面板）各一 Feature。

归属与粒度判定：

- 一个 Feature = 一个封闭交互单元 + 它触发的附属浮层——确认弹框、版本历史抽屉与触发它的交互单元同属一个状态闭环时同文件，不按浮层个数碎拆。
- 共享状态归 Page：选中项、数据行、提交回调由入口持有并经 props/emits 下发；Feature 不自行调用 Service（数据由入口装配下发）。
- **禁止仅为减行数机械拆分**：页面没有封闭交互单元时不拆（入口 + 单 Feature 的形式拆分是无效分层）；拆分以职责边界为准，不以行数为准，无行数校验。

## 三、Service 契约

- 文件名 `<entity>-service.ts`，每个业务实体一个文件，跨页单源——同一实体在多个页面出现时只允许一个 Service 文件。
- 接口定义与 mock 实现同文件：导出 async 函数（`listXxx` / `createXxx` / `updateXxx` 等）+ 固定延时 mock 实现；实体 `type` 随文件导出。
- **mock 的是服务接口**：页面与 Feature 只消费 async 接口，与真实场景同构——后续把原型转正式页面只需替换 Service 实现为真实 API 调用，页面与 Feature 零改动。
- 禁止真实网络请求（fetch/axios）；禁止页面或 Feature 绕过 Service 直接 import 数据种子。

## 四、修改前分析（工作流 B 硬步骤）

对既有页面做任何增量修改前，先完成归属判定再动手：

1. 读入口文件与 page-plan `features` 登记，判定改动落在哪一层；
2. 归属既有 Feature → 只改该 Feature 文件；
3. 新职责（新的封闭交互单元）→ 新建 Feature 并登记 `features`；
4. 禁止直接向入口文件追加油浮层、Tab pane、伴随面板实现体。

## 五、机械校验

- 入口文件禁内联 Drawer/Modal/Tabs 实现体（react：`<Drawer`/`<Modal`/`<Tabs`；vue：`el-drawer`/`el-dialog`/`el-tabs`）。
- 禁 `import src/mock/*`（`src/services` 内部装配豁免）。
- page-plan `features`（id + 文件路径）与 `features/` 目录双向对账：登记的文件必须存在，目录里未登记的文件也报。
- 锚点、结构文案、组件使用等页面级对账按「入口 + 全部 Feature 合并源」扫描。
