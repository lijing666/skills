# AI 架构师技能仓库

本仓库是所有自定义 Skill 的**唯一编辑源（source of truth）**。
在本地改完并提交后，再分发同步到各 AI 工具的技能目录。

> 本地与 GitHub 为**同一个仓库**：https://github.com/lijing666/skills
> 本地 commit 后 `git push` 即备份/开源，没有第二份副本，没有发布变换。

## 目录结构

```
skills/
├── jjspec/          # AI 架构师工作流 skill（需求 Spec / 架构 / 任务卡 / 九步 SOP）
└── sync.sh          # 一键同步脚本
```

每个 skill 一个顶层目录，目录内包含 `SKILL.md`（入口）+ `references/` + `assets/` 等。

## 同步工作流

1. **编辑**：只在本仓库内修改技能文件。
2. **提交**：`git add -A && git commit -m "..."`（每次改动留痕，可回滚）。
3. **分发**：`./sync.sh` 将所有技能同步到目标技能目录（默认 `~/.workbuddy/skills/`）。

```bash
# 同步到 WorkBuddy（默认）
./sync.sh

# 同步到指定目录（CodeBuddy / Trae 等）
./sync.sh ~/.codebuddy/skills
./sync.sh ~/.trae/skills
```

## 各工具技能目录速查（已在本机验证）

| 工具 | 技能目录 |
| --- | --- |
| WorkBuddy | `~/.workbuddy/skills/` |
| CodeBuddy | `~/.codebuddy/skills/`（官方文档：用户级自定义 Skills 目录，装完用 /skills 验证加载） |
| Trae CN | `~/.trae-cn/skills/` |

> 各工具对 skill 的加载方式可能略有差异，同步后请在该工具内确认技能可被识别（CodeBuddy 用 /skills 查看；Trae CN 重启后生效）。

## 使用速查（触发即用）

对 AI 说以下话术即可触发对应场景（点名 `jjspec` 最稳）：

| 想做什么 | 话术示例 |
| --- | --- |
| 接入体检（新项目/接手项目必做第一步） | 「用 jjspec 给 /path/to/项目 做接入体检」 |
| 新需求开发（九步 SOP） | 「在 /path/to/项目 开工新需求：<一句话需求>」 |
| 缺陷修复（精简 SOP） | 「用 jjspec 修 bug：/path/to/项目，<bug 描述>」 |
| 编写文档类产物 | 「用 jjspec 写需求 Spec / PRD / 架构设计 / 任务拆解 / ADR」 |
| 大需求立项（PRD 层） | 「用 jjspec 写 PRD / 需求文档：<产品名>」（≥3 张任务卡的需求先 PRD 再拆 Spec） |
| 存量项目改造 | 「用 jjspec 改造 /path/to/项目」（走体检起步，渐进治理） |
| 体系变更评估 | 「换模型/换 AI 工具了，先跑金丝雀任务集验证体系」（换模型/换宿主/大改规则前必做） |

人工介入点只有三处：**方案批准三查、任务卡粒度调整、风险区人审**。

> 原则：机制归 skill，内容归项目——AGENTS.md/ADR/回流表落在被操作的项目里，本仓库只存方法论。

## 设计约定（来自 AI 架构师课程）

- **渐进披露**：`SKILL.md` 控制在 150 行以内，细节下沉到 `references/`。
- **规则必配执法物料**：每条硬规则都要有对应检查脚本 / CI 片段（`assets/`）。
- **回流机制归 skill，内容归项目**：技能定义"怎么回流"，具体项目知识留在项目仓库。
