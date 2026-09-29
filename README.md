# AI 架构师技能仓库

本仓库是所有自定义 Skill 的**唯一编辑源（source of truth）**。
在本地改完并提交后，再分发同步到各 AI 工具的技能目录。

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

## 各工具技能目录速查

| 工具 | 技能目录 |
| --- | --- |
| WorkBuddy | `~/.workbuddy/skills/` |
| CodeBuddy | 以其官方文档为准，常见为 `~/.codebuddy/skills/` |
| Trae | 以其官方文档为准，常见为 `~/.trae/skills/` |

> 各工具对 skill 的加载方式可能略有差异，同步后请在该工具内确认技能可被识别。

## 设计约定（来自 AI 架构师课程）

- **渐进披露**：`SKILL.md` 控制在 150 行以内，细节下沉到 `references/`。
- **规则必配执法物料**：每条硬规则都要有对应检查脚本 / CI 片段（`assets/`）。
- **回流机制归 skill，内容归项目**：技能定义"怎么回流"，具体项目知识留在项目仓库。
