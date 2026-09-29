# 契约强度工具箱（按语言）

> 用途：规则先行阶段选执法工具、写架构约束时。核心原则：**架构规则必须机器可执行**——能用工具表达的绝不写成文档，文档只写机器表达不了的"为什么"。

## 契约强度光谱（排序原则，非选型结论）

```
编译期 ──→ lint 期 ──→ 测试期 ──→ CI 期
（最硬）                              （最兜底）
```

**选型口诀**：先问能否落 L1（类型/语言级）；不能则架构测试（测试期）；再不行 CI 脚本兜底。**唯一不可接受的是"只写在 Wiki 里"**。
⚠️ 每种工具仍需过生态成熟度与迁移成本评估——JPMS 拦截时机满分但应用层采用率极低，Java 事实标准是测试期的 ArchUnit。

## 跨语言执法工具表

| 拦截时机   | Python                              | Java                                      | JS/TS                          | Go           |
| ------ | ----------------------------------- | ----------------------------------------- | ------------------------------ | ------------ |
| 编译/语言级 | （无，靠测试期补）                           | Kotlin `internal`（按 Gradle 模块）            | TS project refs                | 小写私有（语言级）    |
| lint 期 | Ruff TID251（banned-api）             | Checkstyle ImportControl                  | ESLint `no-restricted-imports` | —            |
| 测试期    | **import-linter**（声明式 contracts，首选） | **ArchUnit**（事实标准，`.because()` 可带 ADR 引用） | dependency-cruiser             | go-arch-lint |
| CI 期   | git diff 扫 import 的 20 行脚本          | Maven Enforcer                            | 同左                             | 同左           |

## 语言要点

### Python
- 类型：type hints + mypy/pyright 严格模式（AI 写带类型代码错误率显著更低）；运行时边界用 pydantic
- 架构测试：import-linter，contracts 声明 forbidden / layered / independence（见 `assets/ci-snippets/python-import-linter.toml`）

### Java
- **务实阶梯**：① ArchUnit（测试期）→ ② Checkstyle ImportControl（lint 期，需更早拦截时叠加）→ ③ Maven Enforcer（构建期兜底）；✗ JPMS 仅做库且明确要封闭边界时考虑
- 领域建模：sealed interface（Java 17+）模拟可辨识联合；状态机显式声明

### JS/TS
- **AI 辅助开发时代，新 Node 项目默认 TS**（Node 22.6+ type stripping / 24 直接跑 .ts）
- 遗留 JS：JSDoc + `checkJs` 渐进改造，不迁后缀也能拿到大半收益
- 运行时边界（API 入参）仍需 zod 校验——编译期管不了运行期

## 例外唯一门模式（带语义例外的禁令怎么执法）

"禁止手拼租户 where，但平台管理员场景合法"——这类**带运行时语义例外**的规则无法直接静态化。三步改造：

1. **造唯一合法门**：专用 API（如 `TenantContext.runAs(tenantId, action)`），调用处必须带 `@TenantOverride(reason=...)` 注解留痕
2. **机器执法绝对禁令**：门以外禁止触碰越权能力（ArchUnit/lint 按语法结构判定，完全可测）
3. **语义判断收敛到门的使用处**：调用点全仓库可 grep、数量少、每个带 reason——人审只盯门口

> 真造不出门（合法路径无法用代码界定）→ 才退回 L2 文字规则 + 人工审查。

## "能否机器表达"判断顺序

1. 能进类型/lint 的 → L1，**不占 AGENTS.md 行数**
2. 带语义例外的 → 造唯一门（R3 模式）
3. 都不行的 → L2 文字规则（R 编号 + 违反后果），长尾配知识库指针
