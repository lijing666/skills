# UAT 环境接入管线

> 用途：「接入 UAT」「搭建 UAT 环境」触发指令的执行细则。定位：环境契约（`e2e-guide.md` 环境契约节）的**生产者**——先建环境、登记契约，验收级 E2E 才有执行载体；本管线只管接入，E2E 执行判据仍归 e2e-guide，禁复述。逐命令执行演示见 `assets/uat-setup-walkthrough.md`（阿里云 ECS + GitHub 场景，讲义体；判据以本文为准，演示与本文同步维护）。

## 作用域（写死，命中不适用即停）

- **适用**：仓库托管于 GitHub、目标为单机容器化 UAT 的中小项目（前后端任栈，前提可容器化）。
- **不适用**：K8s 集群形态、PaaS 托管形态（Vercel / Render / SAE 类）、无国内可达性要求的多地域部署——命中即停，说明缺口，禁套用本管线。
- **默认载体（可替换实现，替换时判据层不变）**：Docker Compose（运行时）+ Caddy（入口 / 自动 TLS）+ GitHub Actions（CI）+ GitHub Environments（发布门禁）。载体选型须项目确认，禁静默默认。

## 判据层（工具无关，载体替换时不许破）

1. **同域同构**：UAT 前端与 API 同域（路径分流），认证链路与生产同构——跨域 UAT 的 CORS/cookie 行为失真，该环境上的验收结果无效。
2. **环境即仓库文件**：环境定义、数据脚本、流水线、门禁配置全部声明式进仓库——环境重建 = 重放仓库文件；禁存在只活在云控制台里的环境知识。
3. **数据可复跑**：seed 脚本幂等可复跑可重置，UAT 数据状态可预期；生产快照初始化必须脱敏。
4. **部署即流水线 + 门禁挂证据**：UAT 部署是 CI 任务非人肉操作；生产发布门禁依赖 UAT 验收证据（冒烟全绿），禁无证据放行。

## 六步管线

1. **预检（fail-closed）**：逐项检查前置条件——① 服务器（SSH 可达，建议 ≥2C4G）；② 域名（可配 UAT 子域解析）；③ GitHub 仓库 Actions 权限与 secrets 可配；④ 生产数据源（快照导出通道，可缺——缺则 seed-only 起步并登记缺口）；⑤ 各端可容器化确认。任一缺失 → **停下列出人工动作清单向用户要**：云资源创建 / DNS / 凭据配置是人工动作，本管线只产出清单，禁假装能创建。
2. **环境定义**：产出 `compose.yaml` + `Caddyfile` 进仓库——同域分流（UAT 域根路径 → 前端静态产物，`/api` → 反代后端；DB/Redis 容器化）；入口容器对后端用 healthcheck 强依赖（`condition: service_healthy`），防冒烟打在未就绪后端上；配置经 env 文件外置，秘密不入仓库（`.env.example` 登记变量名）。本地验证形态用 http-only（`:80` 站点块），落 UAT 换真实域名（Caddy 自动 HTTPS）——两形态切换是模板必配项，禁拿本地形态直接上线。
3. **数据初始化**：seed 脚本（幂等）+ 可选生产快照脱敏接入脚本。**数据红线：AI 产出脱敏脚本与操作清单，生产数据的导出与脚本执行由人完成——AI 禁直接接触生产数据。**
4. **CI 挂钩**：产出 `deploy-uat.yml`（目标分支合入自动部署 + 部署后自动跑冒烟 E2E）；secrets 清单列给用户在 GitHub 配置（AI 禁自配凭据）。
5. **门禁配置**：产出 production environment 的 required reviewer + 生产部署 job 依赖 UAT 冒烟证据的配置步骤清单，由人在 GitHub 执行。
6. **验证收口**：UAT 实跑部署 + 冒烟全绿（SPA 项目冒烟须含路由回退探活——不存在路径应 200 回 index.html，防「首页绿了、深链全 404」）；登记环境契约——`env.json` 字段口径沿 `e2e-guide.md`，env 取值 `uat`。后续验收 E2E 即消费本契约。

## 产物清单

`compose.yaml`、`Caddyfile`、`.env.example`、seed 脚本（及可选脱敏脚本）、`.github/workflows/deploy-uat.yml`、门禁配置步骤清单、环境契约登记。产物全部落项目仓。

## 诚实边界

- **本地编排已实测**（2026-11-25，夹具项目 OrbStack 实跑）：同域分流、SPA 路由回退、healthcheck 启动门控、seed 幂等、冒烟探活、workflow 语法全部通过。**云端链路待实战**：真实服务器部署、DNS、GitHub Actions secrets、Environments 门禁未验证——首次实战后回填修订本管线；执行中遇与判据层冲突的现实约束，停下登记，禁硬套。
- 非默认载体形态（K8s / PaaS）无正源，登记于 SKILL.md 未覆盖盲区。
