---
name: jjpr
description: |
  以 GitHub App（jj-ai-agent）安装身份统一 AI 编码代理的 git 推送与
  GitHub 操作：doctor 预检、App 身份 push、创建 PR、CI 与评审响应，
  停在人审合并门口。仅当用户明确点名 jjpr 时使用（如"用 jjpr 推送"、
  "jjpr 发个 PR"、"jjpr 检查一下"）；用户泛说推送/PR 时是普通 git
  操作，不触发本技能。不负责本地编码与文档工作流。
---

# jjpr：GitHub App 身份的推送与 PR 技能

## 用途

为 AI 编码代理提供统一的 GitHub 身份与操作入口：所有 git 推送与
GitHub API 操作以 GitHub App（jj-ai-agent）安装身份执行，不使用个人
OAuth/PAT 凭据。一个技能覆盖认证、推送、PR、CI、评审响应，避免每个
代理各写一套规则。

## 身份与安全模型

```text
AI 代理 -> App 私钥（本机 ~/.git-app，绝不进入提示/日志/仓库）
        -> JWT（10 分钟时窗）
        -> 安装访问令牌（1 小时有效）
        -> GH_TOKEN / git 凭据助手
        -> gh / git push / GitHub API
```

安全红线（任何情况下不得违反）：

1. 绝不打印、复制、提交 App 私钥或令牌（GH_TOKEN / JJPR_TOKEN）。
2. 绝不因 App 权限不足而改用个人 PAT 兜底——停下报告缺失的权限。
3. 绝不绕过分支保护、CODEOWNERS、必需人审；绝不强推受保护分支。
4. 绝不修改 `.github/workflows/*`，除非任务明确要求且 App 有 Workflows 权限。
5. 绝不自行合并需要人审的 PR——停在"等待人工批准"。
6. GitHub 上的操作保持可归因到 App bot 身份（jj-ai-agent[bot]）。
7. 仅在用户点名 jjpr 时接管 GitHub 操作；普通 git 操作不切身份、不经本技能。
8. 一切 GitHub 操作经 `jjpr` 入口执行；内部脚本不直接调用、不绕过。

## 配置

配置文件 `~/.git-app/jjpr.env`（机器私有，严禁提交到任何仓库）：

```text
GITHUB_APP_ID=5173699
GITHUB_APP_PRIVATE_KEY_PATH=~/.git-app/jj-ai-agent.2026-10-03.private-key.pem
# 安装 ID 留空则从当前仓库 origin 自动发现
# GITHUB_APP_INSTALLATION_ID=
```

优先级：环境变量 > jjpr.env（JJPR_ENV_FILE 可改指配置文件）。
私钥轮换时只改 jjpr.env，技能本身不动。

App 仓库权限基线：Contents / Issues / Pull requests 读写，Metadata
只读，Workflows 默认无权限。

## 平台支持

双实现，按操作系统自选入口（行为对齐：doctor / gh / push / 默认动作）：

- macOS / Linux：`scripts/jjpr`（bash，依赖 openssl + curl + git + gh）
- Windows 原生：`scripts/jjpr.ps1`（Windows PowerShell 5.1 系统内置即可，
  无需装 pwsh 7；依赖仅 git + gh，JWT 用 .NET RSA、HTTP 用 Invoke-RestMethod）。
  调用：`powershell -NoProfile -ExecutionPolicy Bypass -File jjpr\scripts\jjpr.ps1 <命令>`
- WSL2：按 Linux 方式用 bash 版；Git Bash 未验证，不做承诺

## 命令

对外只有一个动作——推送当前分支并以 App 身份创建 PR：

```bash
jjpr --title "<PR 标题>" --body-file <正文文件> [--base <默认分支>]
```

内部按序执行：获取安装令牌 -> 推送 -> `gh pr create`（参数透传）。
Windows 上将命令中的 `jjpr` 换成
`powershell -NoProfile -ExecutionPolicy Bypass -File jjpr\scripts\jjpr.ps1`。

AI 编排用的内部命令（不对外，逐步用法见 `references/workflow.md`）：
`jjpr doctor`（预检/排障）、`jjpr push`（CI 修复后重推）、
`jjpr gh <参数>`（CI/评审查看）。

典型序列：

```bash
jjpr doctor                                   # 接入验证（一次性）
# ……本地实现与小步提交（本地 commit 沿用项目 git 既有署名）……
jjpr --title "…" --body-file pr.md            # 推送 + 创建 PR
jjpr gh pr checks <PR号>                      # （内部）盯 CI
jjpr gh pr view <PR号>                        # （内部）看评审
```

## 标准流程（概览）

人工建好特性分支或 worktree 后，代理在其中实现：

1. **预检**：`jjpr doctor` 确认身份链路可用。
2. **理解任务**：从 Issue/需求描述提取目标与验收标准，不擅自扩范围。
3. **实现**：最小连贯变更；遵循仓库既有架构与约定；本地小步提交，保持可回滚。
4. **自检**：跑仓库的格式化/静态检查/测试/构建，不谎报通过。
5. **推送**：`jjpr push`（App 身份、HTTPS、凭据走安装令牌）。
6. **PR**：`jjpr pr` 或 `jjpr gh pr create`；正文含变更说明、已跑检查、Issue 引用。
7. **响应**：CI 失败且因本变更 -> 诊断修复重推；评审意见可执行 -> 落实并重推。
8. **边界**：输出"PR 已就绪，等待人工批准"并停止——合并由人决定。

逐步细节见 `references/workflow.md`。

## 令牌生命周期

- 安装令牌 1 小时有效；`jjpr` 缓存于 `~/.cache/jjpr`（0600），55 分钟内复用。
- 过期自动重新生成，无需手动干预；如遇 401，先重跑 `jjpr doctor`。

## 故障排查

- `403 Resource not accessible by integration`：App 未安装到该仓库或权限不足——检查安装与权限，不用个人 token 兜底。
- push 被拒但 gh 正常：不要手动配凭据——直接用 `jjpr push`（已隔离钥匙串）。
- `未发现 App 安装（404）`：App 未安装到 origin 指向的仓库，或安装 ID 配错。
- 令牌疑似失效：删除 `~/.cache/jjpr` 后重试，或 `jjpr doctor` 复查。
- 直接执行报 Permission denied：分发途径丢失执行位（罕见，仅 bash 版）——`chmod +x jjpr/scripts/*` 即可；Windows 经 `-File` 调用，无此问题。

## 完成报告

任务完成时报告：Issue / 分支 / PR、已跑检查及结果、变更文件范围、
是否仍需人工批准、遗留阻塞项。绝不在报告中包含凭据或私钥内容。
