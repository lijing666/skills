# jjpr 技能

以 GitHub App（jj-ai-agent）安装身份统一 AI 编码代理的 git 推送与
PR 工作流：预检 -> App 身份推送 -> 创建 PR -> CI/评审响应 -> 停在
人审合并门口。

## 安装

把 `jjpr` 目录复制（或用本仓库 `sync.sh`）同步到编码代理的技能目录即可，
脚本执行权限已随文件携带（git 与 cp -R / rsync 均保留权限位），无需额外步骤。

## 配置（机器私有，不随技能分发）

创建 `~/.git-app/jjpr.env`（权限 600）：

```bash
cat > ~/.git-app/jjpr.env <<'EOF'
GITHUB_APP_ID=5173699
GITHUB_APP_PRIVATE_KEY_PATH=~/.git-app/<私钥文件名>.pem
# 安装 ID 留空则从当前仓库 origin 自动发现
# GITHUB_APP_INSTALLATION_ID=
EOF
chmod 600 ~/.git-app/jjpr.env
```

- App 私钥放在 `~/.git-app/`，权限 600，绝不进入任何仓库或提示词。
- 环境变量优先于 jjpr.env；`JJPR_ENV_FILE` 可改指配置文件路径。
- 私钥轮换时只改 jjpr.env，技能不动。

## 验证

在 App 已安装的目标仓库里执行内部诊断命令 doctor（接入期一次）：

```bash
jjpr/scripts/jjpr doctor                                    # macOS / Linux
powershell -NoProfile -ExecutionPolicy Bypass -File jjpr\scripts\jjpr.ps1 doctor   # Windows 原生
```

预检通过后，建一个测试分支用默认动作验证 bot 身份（推送 + 建 PR）：

```bash
git checkout -b jjpr-smoke
# ……提交一点变更……
jjpr/scripts/jjpr --title "jjpr 接入验证" --body-file <正文文件>
```

## 冒烟测试（无网络）

```bash
bash jjpr/tests/doctor-smoke.test.sh                                    # macOS / Linux（20 用例）
powershell -NoProfile -ExecutionPolicy Bypass -File jjpr\tests\doctor-smoke.test.ps1   # Windows（23 用例）
```

## 目录结构

```text
jjpr/
├── SKILL.md                      技能入口：身份模型、命令、安全红线
├── references/workflow.md        十步工作流详解
├── scripts/
│   ├── jjpr                      macOS/Linux 入口（默认动作推送+建PR；内部命令 doctor/gh/push）
│   ├── jjpr-credential.sh        （内部）git 凭据助手，仅由 jjpr 调用
│   ├── jjpr.ps1                  Windows 原生入口（行为对齐 bash 版，PS 5.1+）
│   └── jjpr-credential.ps1       （内部）Windows 凭据助手，仅由 jjpr.ps1 调用
└── tests/
    ├── doctor-smoke.test.sh      bash 版冒烟测试
    └── doctor-smoke.test.ps1     PowerShell 版冒烟测试
```

依赖：

- macOS / Linux：bash / openssl / curl / git / gh（bash 版）
- Windows 原生：Windows PowerShell 5.1（系统内置）+ git + gh（jjpr.ps1，
  JWT 用 .NET RSA、HTTP 用 Invoke-RestMethod，无 openssl/curl 依赖）

平台支持：

- macOS ✅——bash/openssl/curl/git 系统自带，gh 用 brew 安装
- Linux ✅——依赖经发行版包管理器安装（已通过 Linux 容器冒烟测试 20/20）
- Windows 原生 ✅——jjpr.ps1（PS 5.1+，已过 pwsh 冒烟测试 23/23；
  凭据助手挂载与 gh.exe 交互未做 Windows 实机验证，doctor 逐项预检兜底）
- WSL2 ✅（按 Linux 方式装依赖）；Git Bash 未验证，不做承诺

## 安全提醒

- 绝不打印、提交、复制 App 私钥或安装令牌。
- 绝不因 App 权限不足而用个人 PAT 兜底。
- 绝不绕过分支保护与必需人审。
