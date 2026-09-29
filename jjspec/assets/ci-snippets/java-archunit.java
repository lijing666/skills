// ArchUnit 示例（Java，测试期执法——应用层事实标准）
// 放入 src/test/java；随单测运行，违规即测试失败
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.library.Architectures.layeredArchitecture;

@AnalyzeClasses(packages = "com.myproject")
class ArchitectureTest {

    // 模块内部私有 + .because() 带 ADR 引用——违规者看到的是带原因的失败信息
    @ArchTest
    static final ArchRule payment_internals_are_private = noClasses()
        .that().resideInAPackage("..order..")
        .should().dependOnClassesThat()
        .resideInAPackage("..payment.internals..")
        .because("payment 内部实现私有，只能经 api 包访问（见 ADR-0003）");

    // 分层架构：api -> service -> repository，单向
    @ArchTest
    static final ArchRule layered = layeredArchitecture()
        .consideringAllDependencies()
        .layer("Api").definedBy("..api..")
        .layer("Service").definedBy("..service..")
        .layer("Repository").definedBy("..repository..")
        .whereLayer("Api").mayNotBeAccessedByAnyLayer()
        .whereLayer("Service").mayOnlyBeAccessedByLayers("Api")
        .whereLayer("Repository").mayOnlyBeAccessedByLayers("Service");

    // 例外唯一门模式：越权能力只能经唯一门调用（见 contract-toolbox R3）
    // @ArchTest
    // static final ArchRule tenant_escape_hatch_is_gated = noClasses()
    //     .that().resideOutsideOfPackage("..tenant.support..")
    //     .should().callMethodWhere(JavaCall.Predicates.target(name(TenantContextHolder.class, "setTenantId")))
    //     .because("租户上下文只能经 TenantContext.runAs 切换（见 ADR-0021，违反=跨租户数据泄漏 P0）");
}
