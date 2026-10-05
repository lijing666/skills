# jjpr 标准工作流（十步详解）

本文是 SKILL.md"标准流程"的逐步展开。前提：人工已建好特性分支或
worktree，代理在其上工作；所有 GitHub 操作经 `jjpr` 以 App 身份执行。
对用户呈现的唯一动作是 `jjpr --title …`（推送 + 建 PR）；文中其余
jjpr 形态（doctor / push / gh）为内部编排命令。
Windows 原生环境下 `jjpr` 指 `jjpr.ps1`（调用形式见 SKILL.md 平台支持节），
步骤与本文一致。

## 1. 预检身份链路

开工时在项目仓库内执行一次：

```bash
jjpr doctor
```

逐项检查 curl / openssl / gh / 配置 / 私钥 / origin 仓库 / 令牌生成 /
gh 访问，任一失败即停（fail-fast）并给出修复指引。预检不过，不进入
后续步骤——尤其不要退回个人凭据"先干着"。

## 2. 理解任务（从 Issue 或需求描述）

```bash
jjpr gh issue view <编号>
jjpr gh issue view <编号> --comments
```

提取：期望行为、验收标准、复现步骤、约束、相关标签与里程碑、已有
讨论、关联 PR/Issue。任务含糊时，先提出聚焦的问题再动手；不擅自
扩大范围。

## 3. 检查仓库现状

动手前确认环境与约定：

```bash
git status --short        # 工作区干净再开工
git branch --show-current # 确认在人工建好的特性分支上（不是 main）
git remote -v
jjpr gh repo view
```

阅读仓库的贡献说明、agent 说明、CI 配置、构建配置与相关架构规则。
优先用仓库自带的命令，不发明新命令。

## 4. 实现变更

做满足任务的最小连贯变更：

- 保持既有架构与约定，不改无关文件。
- 发现必须做的后续事项超出范围时，写进 PR 说明，不静默扩权。
- 本地小步提交，每步可独立回滚；commit 沿用项目 git 既有署名配置。

## 5. 跑确定性检查

至少跑仓库适用的：格式化、静态检查、类型检查、单元/集成测试、构建；
若仓库配置了架构/依赖边界检查（如 dependency-cruiser、ESLint 边界、
import-linter、ArchUnit），一并执行。没跑过的不说通过。

## 6. 提交（本地）

提交前自查：

```bash
git status
git diff --check
git diff
```

绝不提交：密钥、私钥、含凭据的 .env、仓库未明确要求的生成产物。

## 7. 推送（App 身份）

```bash
jjpr push
```

内部行为：生成安装令牌 -> 清空继承的凭据助手（钥匙串等个人凭据被
隔离）-> 注入 jjpr 专用凭据助手 -> 以 HTTPS 推送当前分支。origin 是
SSH 形式也能推（不改 remote 配置）。需要附加 git 参数时透传，
如 `jjpr push --force-with-lease`（受保护分支除外）。

## 8. 创建 PR（App 身份）

```bash
jjpr --base <默认分支> --title "<简洁标题>" --body-file <正文文件>
```

`jjpr` 默认动作会先推送再创建；也可拆开用 `jjpr push` +
`jjpr gh pr create`（内部命令）。
PR 正文应包含：

- 摘要：改了什么、为什么
- 已跑的检查及结果
- 已知局限
- Issue 引用（如 `Closes #123`）

不声称已获人工批准。

## 9. 监控 CI 与响应评审

```bash
jjpr gh pr checks <PR号>
jjpr gh pr view <PR号>
```

- CI 失败且因本变更：诊断、修复、`jjpr push` 重推、汇报改了什么。
- 评审意见可执行：落实后重跑相关检查再重推。
- 每次重推后，视为此前的人工批准可能需要刷新（部分仓库要求批准
  最新提交）。

## 10. 合并边界

不绕过分支保护、ruleset、CODEOWNERS、必需人审。仓库要求 Code Owner
批准时，PR 就绪后明确输出：

```text
PR ready for human approval.
```

并停止。除非仓库政策明确允许 AI 自动合并且检查/批准全部满足，否则
合并由人决定。管理员旁路、强推受保护分支、换个人凭据绕门，一律禁止。
