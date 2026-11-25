# UAT 接入操作手册（阿里云 ECS + GitHub 全流程演示）

> 定位：本文档是 `references/uat-onboarding.md` 六步管线的**执行演示**（讲义体），逐命令、逐文件给全。判据与适用作用域以正源为准（本文不复述判据）；示例参数——域名 `example.com`、IP `47.x.x.x`、仓库名 `<org>/<repo>`——按项目替换。文档与正源同步维护：正源判据变更时本文对应步骤回填。
>
> 实测说明：管线②③⑥的本地编排部分已于 2026-11-25 用夹具项目实跑验证（OrbStack）；本文在此基础上把载体换成阿里云 ECS 真实场景。云端步骤（DNS、secrets、Environments）为首次实战形态，执行时遇阻记录回填。

## 场景假设（开工前确认）

| 项 | 假设值 | 谁提供 |
| --- | --- | --- |
| 代码仓库 | `github.com/<org>/<repo>`，main 分支开发 | 项目 |
| 服务器 | 阿里云 ECS 2C4G，Ubuntu 22.04，公网 IP `47.x.x.x`，SSH 可达 | 用户（已在手） |
| 域名 | `example.com` 已备案，UAT 子域 `uat.example.com` | 用户 |
| 项目形态 | 前端 SPA（构建产物静态）+ 后端 API + PostgreSQL + Redis，全部可容器化 | 项目 |
| 数据 | 生产快照可选；缺则 seed-only 起步 | 用户 |

---

## 第 0 步：预检（AI 跑检查命令，人工动作出清单）

### AI 可直接执行的检查

```bash
# ① SSH 可达（用户已配好本机到 ECS 的密钥）
ssh root@47.x.x.x 'echo ok'

# ② DNS 已生效（首次接入时尚未配置则为空——正常，走下方人工清单）
dig +short uat.example.com

# ③ GitHub 仓库与 Actions 可见
gh repo view <org>/<repo> --json defaultBranchRef,visibility

# ④ 机器上 docker 就绪（未装走下方人工清单的安装命令）
ssh root@47.x.x.x 'docker --version && docker compose version'
```

### 人工动作清单（AI 禁代操作，逐项给出操作路径）

**A. 阿里云安全组放行 80/443**（只放行入口端口，DB/Redis 不暴露公网）：
控制台 → ECS 实例 → 安全组 → 配置规则 → 入方向 → 添加：80/443、授权对象 0.0.0.0/0。

**B. 机器安装 Docker**（用阿里云镜像源加速）：

```bash
ssh root@47.x.x.x 'curl -fsSL https://get.docker.com | sh && systemctl enable --now docker'
```

**C. 云解析 DNS 加 A 记录**：
控制台 → 云解析 DNS → example.com → 添加记录：记录类型 A、主机记录 `uat`、记录值 `47.x.x.x`、TTL 600。

**D. GitHub 权限确认**：仓库 Settings → Actions 已启用；操作者有 Settings → Secrets 写权限。

**E. 生产数据源**：有则用户导出脱敏前快照（见第 2 步红线）；无则登记「seed-only 起步」继续。

> 预检 fail-closed：A–E 任一项用户无法完成即停，不带病开工。

---

## 第 1 步：环境定义（产物模板全量）

仓库内目录布局：

```
deploy/
├── compose.yaml
├── Caddyfile
├── .env.example
└── caddy/            # Caddy 数据卷挂载点（运行时生成）
scripts/
├── seed.sh
└── smoke.sh
```

### compose.yaml（模板）

```yaml
services:
  caddy:
    image: caddy:2-alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ../frontend/dist:/srv/frontend:ro        # 前端构建产物
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      backend:
        condition: service_healthy               # healthcheck 门控：冒烟不会打在未就绪后端
  backend:
    image: <backend-image>:uat                   # 项目按栈替换（jar/node/python 镜像）
    restart: unless-stopped
    env_file: .env
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    healthcheck:
      test: ["CMD-SHELL", "curl -fs http://localhost:8000/api/health || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 10
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    env_file: .env
    volumes:
      - db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      timeout: 3s
      retries: 10
  redis:
    image: redis:7-alpine
    restart: unless-stopped

volumes:
  caddy_data:
  caddy_config:
  db_data:
```

### Caddyfile（两形态，切换是必配项）

**本地验证形态**（http-only，用于本机 compose 试跑）：

```caddyfile
:80 {
	root * /srv/frontend
	encode gzip
	handle /api/* {
		reverse_proxy backend:8000
	}
	handle {
		try_files {path} /index.html    # SPA 路由回退
		file_server
	}
}
```

**UAT 域名形态**（落 ECS 用这版，Caddy 自动签发续期 HTTPS 证书）：

```caddyfile
uat.example.com {
	root * /srv/frontend
	encode gzip
	handle /api/* {
		reverse_proxy backend:8000
	}
	handle {
		try_files {path} /index.html
		file_server
	}
}
```

> 禁拿本地形态直接上线——两形态只差站点块头部，切换后本地复验一遍再部署。

### .env.example（变量名清单，真值不进仓库）

```bash
POSTGRES_USER=uat
POSTGRES_PASSWORD=change-me
POSTGRES_DB=app
REDIS_URL=redis://redis:6379
BACKEND_PORT=8000
```

首次在 ECS 上：`cp deploy/.env.example deploy/.env && vim deploy/.env` 填真值。

---

## 第 2 步：数据初始化

### seed.sh（幂等模板：可重复执行，结果一致）

```bash
#!/bin/sh
# 用法: seed.sh   （在 ECS 的 deploy/ 同级执行）
set -e
echo "seed v1: applying migrations + baseline data (idempotent)"
docker compose exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<'SQL'
-- 迁移用 CREATE TABLE IF NOT EXISTS / INSERT ... ON CONFLICT DO NOTHING 保证幂等
CREATE TABLE IF NOT EXISTS seed_meta (k text primary key, v text);
INSERT INTO seed_meta (k, v) VALUES ('seed_version', '1') ON CONFLICT (k) DO NOTHING;
SQL
echo "seed done"
```

### 生产快照脱敏（数据红线：AI 只产出脚本与清单，导出与执行由人做）

人工动作清单：
1. 阿里云控制台 → RDS → 备份恢复 → 下载最近快照到本机；
2. **人执行** `scripts/anonymize.sh <快照文件>`（AI 产出的脱敏脚本：手机号/身份证置空或映射、密码哈希统一重置、token 全清）；
3. **人执行**脱敏后快照导入 ECS 的 `db` 容器（命令在脚本头部注释给出）。

AI 全程不接触未脱敏数据与生产凭据。

---

## 第 3 步：CI 挂钩

### 专用部署密钥（人执行，一次性）

```bash
ssh-keygen -t ed25519 -f uat_deploy_key -N '' -C 'uat-deploy'
# 公钥进 ECS：
ssh root@47.x.x.x 'cat >> ~/.ssh/authorized_keys' < uat_deploy_key.pub
# 私钥值稍后填入 GitHub secret UAT_SSH_KEY
```

### GitHub secrets 清单（人配置：仓库 Settings → Secrets and variables → Actions → New repository secret）

| Secret 名 | 值 |
| --- | --- |
| `UAT_HOST` | `47.x.x.x` |
| `UAT_USER` | `root` |
| `UAT_SSH_KEY` | `uat_deploy_key` 私钥全文 |
| `UAT_BASE_URL` | `https://uat.example.com` |

### .github/workflows/deploy-uat.yml（模板）

```yaml
name: deploy-uat
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: build frontend artifact
        run: |
          cd frontend && npm ci && npm run build   # 按项目前端栈替换
      - name: deploy over ssh
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.UAT_HOST }}
          username: ${{ secrets.UAT_USER }}
          key: ${{ secrets.UAT_SSH_KEY }}
          script: |
            cd /opt/app
            git pull --ff-only
            docker compose -f deploy/compose.yaml up -d
            ./scripts/seed.sh
      - name: smoke
        run: ./scripts/smoke.sh ${{ secrets.UAT_BASE_URL }}
```

### smoke.sh（模板：前端 + API + SPA 回退三探活）

```bash
#!/bin/sh
# 用法: smoke.sh <baseUrl>
set -e
BASE="${1:?usage: smoke.sh <baseUrl>}"
code_front=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/")
code_api=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/health")
code_spa=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/some/deep/route")
[ "$code_front" = "200" ] || { echo "SMOKE FAIL: front=$code_front"; exit 1; }
[ "$code_api" = "200" ] || { echo "SMOKE FAIL: api=$code_api"; exit 1; }
[ "$code_spa" = "200" ] || { echo "SMOKE FAIL: spa-fallback=$code_spa"; exit 1; }
echo "SMOKE GREEN: front=$code_front api=$code_api spa=$code_spa"
```

---

## 第 4 步：发布门禁（GitHub Environments，人配置）

操作路径（仓库 Settings → Environments）：

1. **创建 `uat` 环境**：不配审批（自动部署），可选配 deployment branches = `main`；
2. **创建 `production` 环境**：Required reviewers → 加审批人（发布负责人）；Deployment branches = `main`；
3. **生产工作流挂环境 + 挂证据**（`.github/workflows/deploy-prod.yml` 要点）：

```yaml
jobs:
  smoke:            # 生产部署前重跑 UAT 冒烟作为证据
    runs-on: ubuntu-latest
    steps:
      - run: ./scripts/smoke.sh ${{ secrets.UAT_BASE_URL }}
  deploy-prod:
    needs: smoke              # 冒烟不绿不进生产
    environment: production   # 挂起等 Required reviewers 点批准
    runs-on: ubuntu-latest
    steps:
      - uses: actions/deploy-to-production   # 按项目替换为真实生产部署步骤
```

> 效果：`uat` push 自动部署 + 自动冒烟 → 生产流水线先跑 UAT 冒烟 → 全绿后**挂起等人批准** → 放行。这就是「验证通过后再发布」的 GitHub 原生落点。

---

## 第 5 步：验证收口

### 首次部署（ECS 上人工/AI 经 SSH 执行）

```bash
ssh root@47.x.x.x
cd /opt && git clone git@github.com:<org>/<repo>.git app && cd app
cp deploy/.env.example deploy/.env && vim deploy/.env      # 填真值
docker compose -f deploy/compose.yaml up -d
docker compose -f deploy/compose.yaml ps                   # 全 healthy 再往下
./scripts/seed.sh
./scripts/smoke.sh https://uat.example.com                 # 期望 SMOKE GREEN
```

### 流水线全链路验证

```bash
git commit --allow-empty -m 'chore: trigger uat pipeline' && git push
gh run watch   # 期望：deploy → seed → smoke 全绿
```

### 环境契约登记（验收 E2E 的消费入口）

```json
{ "baseUrl": "https://uat.example.com", "env": "uat", "accountPool": "seed 账号清单", "seedVersion": "1" }
```

### 完成标志

- [ ] ECS 上四容器全 healthy；`https://uat.example.com` 浏览器可访问（证书有效）
- [ ] push main 自动部署 + 冒烟全绿
- [ ] production 流水线挂起等审批
- [ ] 环境契约已登记（env 取值 `uat`）

---

## 附：夹具实测记录（2026-11-25）

本地编排验证通过项：同域分流（域根 200 / `/api` JSON 直达）、SPA 路由回退 200、healthcheck 启动门控（backend Healthy 后 caddy 才启动）、seed 幂等（两遍输出一致）、smoke 双探活全绿、workflow YAML 语法。云端链路（DNS、Caddy 真实签发、Actions secrets、Environments 审批）待首次实战回填。
