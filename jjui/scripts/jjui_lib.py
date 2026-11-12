#!/usr/bin/env python3
"""Shared deterministic checks for jjui prototypes."""

from __future__ import annotations

import json
import re
from pathlib import Path

# 技能版本单源 = SKILL.md frontmatter 的 metadata.version（技能标准版本号），
# 此处解析派生，不另设常量；判据、机械校验或模板资产每次变更后在 frontmatter 递增该版本，
# 用于 manifest.jjui_version 对账——逼旧基线工程重读新判据并重跑校验
def _skill_version() -> str:
    try:
        skill_md = (Path(__file__).resolve().parent.parent / "SKILL.md").read_text(encoding="utf-8")
    except Exception:
        return "unknown"
    matched = re.search(r"^  version:\s*(\S+)", skill_md, re.M)
    return matched.group(1) if matched else "unknown"

SKILL_VERSION = _skill_version()

STACKS = {
    "react-antd": {
        "component": "antd",
        "conflicting": "element-plus",
        "forbidden": {"axios", "redux", "pinia", "tailwindcss", "echarts"},
        "required": {"react", "react-dom", "react-router-dom", "antd", "@ant-design/icons"},
        "ext": ".tsx",
        "control_re": r"<(?:Input(?:\.Search)?|Select|Switch|Checkbox|Radio|DatePicker|RangePicker|Cascader|AutoComplete|Slider|Button|Upload)\b",
        "table_re": r"<Table\b",
        "pagination_re": r"(?:pagination\s*=\s*\{\{[^}]*pageSize|<Pagination\b)",
    },
    "vue3-element-plus": {
        "component": "element-plus",
        "conflicting": "antd",
        "forbidden": {"axios", "redux", "pinia", "tailwindcss", "echarts"},
        "required": {"vue", "vue-router", "element-plus", "@element-plus/icons-vue"},
        "ext": ".vue",
        "control_re": r"<(?:el-input|el-select|el-switch|el-checkbox|el-radio|el-date-picker|el-cascader|el-autocomplete|el-slider|el-button|el-upload)\b",
        "table_re": r"<el-table\b",
        "pagination_re": r"<el-pagination\b",
    },
}

MANIFEST = ".jjui/manifest.json"
PAGE_PLAN = ".jjui/page-plan.json"
BRIDGE = ".jjui/jjspec/bridge.json"
ROUTE_REGISTRY = ".jjui/jjspec/routes.json"
EXCLUDED_PAGES = ".jjui/jjspec/excluded-pages.json"
STYLE_BASELINE = "src/styles/admin.css"
COMPONENTS_DIR = "src/components/admin"
LAYOUT_DIR = "src/layouts"

RECIPES = {"dashboard", "list", "detail", "form", "settings", "workspace", "canvas", "ide"}
COMPOSITION_COMPONENTS = {"PageHeader", "SectionCard", "MetricCard", "Toolbar", "StatusTag", "EmptyState", "MasterDetail"}
# 画布页图视图库单点豁免（判据正源: references/composition-layer.md 画布段 + prototype-contract.md 依赖约束；
# 库名单源在对应栈参考画布段，此处与栈参考对账）
GRAPH_DEPS = {"react-antd": "@xyflow/react", "vue3-element-plus": "@vue-flow/core"}

# 工程根白名单：固定结构 + 版本管理 + 构建/安装产物；其余一律视为工具残留
ROOT_ALLOWED = {
    "README.md", "package.json", "package-lock.json", "vite.config.ts",
    "index.html", "tsconfig.json", "src", "public", ".jjui",
    ".git", ".gitignore", ".gitattributes", "node_modules", "dist", ".vite",
}

ID_RE = re.compile(r"^p-\d{2}$")
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
ANCHOR_RE = re.compile(r"^[A-Za-z0-9._-]+$")


def read_json(path: Path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def slug_ok(value: str) -> bool:
    return bool(SLUG_RE.match(value or ""))


def id_ok(value: str) -> bool:
    return bool(ID_RE.match(value or ""))


def anchor_ok(value: str) -> bool:
    return bool(ANCHOR_RE.match(value or ""))


def replace_tokens(root: Path, product_id: str, business: str) -> None:
    replacements = {"__PRODUCT_ID__": product_id, "__BUSINESS__": business, "__JJUI_VERSION__": SKILL_VERSION}
    for path in root.rglob("*"):
        if path.is_file() and path.suffix in {".md", ".json", ".html", ".css", ".ts", ".tsx", ".vue"}:
            text = path.read_text(encoding="utf-8")
            for token, value in replacements.items():
                text = text.replace(token, value)
            path.write_text(text, encoding="utf-8")


def validate_root(root: Path) -> list[str]:
    errors: list[str] = []
    root = root.resolve()
    try:
        manifest = read_json(root / MANIFEST)
    except Exception as exc:
        return [f"manifest 不可读: {exc}"]
    # 版本对账（判据正源: references/composition-layer.md 五、机械检查）——
    # 旧基线工程逼重读新判据：技能版本不一致即报错，阻断"凭旧判据记忆工作"的防御
    manifest_version = manifest.get("jjui_version")
    if manifest_version != SKILL_VERSION:
        errors.append(
            f"原型基线与技能版本脱节（manifest.jjui_version={manifest_version or '未登记'} ≠ 技能 {SKILL_VERSION}）："
            "判据与机械校验可能已升级——先重读当前技能副本与判据正源（references/），按新判据修复后再重跑本校验"
        )
    try:
        page_plan = read_json(root / PAGE_PLAN)
    except Exception as exc:
        return [f"page-plan 不可读: {exc}"]
    try:
        bridge = read_json(root / BRIDGE)
    except Exception as exc:
        return [f"bridge 不可读: {exc}"]
    try:
        routes = read_json(root / ROUTE_REGISTRY)
    except Exception as exc:
        return [f"route registry 不可读: {exc}"]
    try:
        excluded = read_json(root / EXCLUDED_PAGES)
    except Exception as exc:
        errors.append(f"excluded-pages 不可读: {exc}")
        excluded = {}

    for rel in (MANIFEST, PAGE_PLAN, BRIDGE, ROUTE_REGISTRY, EXCLUDED_PAGES, "README.md", "package.json"):
        if not (root / rel).is_file():
            errors.append(f"文件缺失: {rel}")

    stack = manifest.get("stack")
    if stack not in STACKS:
        errors.append(f"manifest.stack 非法: {stack or '<空>'}")
        return errors

    spec = STACKS[stack]
    required_manifest = {
        "schema_version", "kind", "product_id", "business", "stack", "start_command",
        "base_url", "viewport", "dpr", "tokens_file", "page_plan", "route_registry",
        "excluded_pages", "visual_source_globs"
    }
    missing_manifest = required_manifest - set(manifest)
    if missing_manifest:
        errors.append("manifest 缺字段: " + ", ".join(sorted(missing_manifest)))
    if manifest.get("kind") != "admin-prototype":
        errors.append("manifest.kind 须为 admin-prototype")
    for key in ("product_id", "business"):
        if not slug_ok(manifest.get(key, "")):
            errors.append(f"manifest.{key} 须为 kebab-case")

    if manifest.get("page_plan") != PAGE_PLAN or manifest.get("route_registry") != ROUTE_REGISTRY or manifest.get("excluded_pages") != EXCLUDED_PAGES:
        errors.append("manifest 的 page_plan/route_registry/excluded_pages 指针不一致")

    tokens_file = manifest.get("tokens_file", "")
    if not tokens_file or not (root / tokens_file).is_file():
        errors.append(f"tokens 文件缺失: {tokens_file or '<空>'}")

    if not (root / STYLE_BASELINE).is_file():
        errors.append(f"组合层样式基线缺失: {STYLE_BASELINE}")
    if not (root / COMPONENTS_DIR).is_dir():
        errors.append(f"组合层组件目录缺失: {COMPONENTS_DIR}")
    admin_css_path = root / STYLE_BASELINE
    if admin_css_path.is_file():
        try:
            admin_css_text = admin_css_path.read_text(encoding="utf-8")
        except Exception as exc:
            admin_css_text = ""
            errors.append(f"样式基线不可读: {STYLE_BASELINE}: {exc}")
        for selector in (".admin-header", ".admin-sider", ".admin-layout__content"):
            if selector not in admin_css_text:
                errors.append(f"样式基线缺布局壳层规则: {selector}")
        # 壳层滚动隔离特征（判据正源: references/composition-layer.md 布局壳层段）
        if ".admin-main" not in admin_css_text:
            errors.append("样式基线缺壳层固定顶栏容器: .admin-main")
        if ".admin-sider__brand" not in admin_css_text:
            errors.append("样式基线缺壳层品牌区（品牌在侧栏顶部）: .admin-sider__brand")
        if "100vh" not in admin_css_text:
            errors.append("样式基线缺壳层滚动隔离特征: height 100vh")
        if "overflow-y: auto" not in admin_css_text:
            errors.append("样式基线缺壳层滚动隔离特征: 内容区 overflow-y: auto")
        # 判据关键段对账（判据正源: references/composition-layer.md「指标卡语义彩条必须内嵌于卡片圆角内」）
        if re.search(r"\.jjui-metric--\w+\s*\{[^}]*border-top", admin_css_text):
            errors.append("样式基线过期: 指标卡彩条为旧版 border-top 直条写法，浮出卡片圆角")
        if ".jjui-metric--warning::before" not in admin_css_text:
            errors.append("样式基线过期: 指标卡彩条缺 ::before 裁剪写法")
        metric_block = re.search(r"\.jjui-metric\s*\{([^}]*)\}", admin_css_text)
        if metric_block and "overflow" not in metric_block.group(1):
            errors.append("样式基线过期: .jjui-metric 容器缺 overflow 裁剪")
    layout_dir = root / LAYOUT_DIR
    layout_files = sorted(layout_dir.glob("AdminLayout.*")) if layout_dir.is_dir() else []
    if not layout_files:
        errors.append(f"布局壳层文件缺失: {LAYOUT_DIR}/AdminLayout.*")
    layout_routes: set[str] = set()
    for layout_path in layout_files:
        try:
            layout_text = layout_path.read_text(encoding="utf-8")
        except Exception:
            continue
        if "border" in layout_text.lower():
            errors.append(f"布局文件内联分隔线样式（分隔线单源在 {STYLE_BASELINE}）: {layout_path.relative_to(root)}")
        # 壳层结构特征（判据正源: references/composition-layer.md 布局壳层段）
        breadcrumb_ok = "<Breadcrumb" in layout_text or "<el-breadcrumb" in layout_text
        if not breadcrumb_ok:
            errors.append(f"壳层顶栏缺面包屑（由路由派生，必备）: {layout_path.relative_to(root)}")
        if "admin-header__brand" in layout_text:
            errors.append(f"品牌区违规回顶栏（品牌在侧栏顶部 .admin-sider__brand，顶栏左侧只放面包屑）: {layout_path.relative_to(root)}")
        layout_routes.update(re.findall(r'["\'](/[A-Za-z0-9_:-]+)["\']', layout_text))

    # 壳层单挂载（判据正源: references/composition-layer.md 布局壳层段）——布局由路由/入口挂一次，防双重壳
    app_entry = root / ("src/App.tsx" if spec["ext"] == ".tsx" else "src/App.vue")
    if app_entry.is_file():
        try:
            app_text = app_entry.read_text(encoding="utf-8")
        except Exception:
            app_text = ""
        if spec["ext"] == ".tsx":
            if app_text.count("<AdminLayout") > 1:
                errors.append("壳层布局重复挂载（App 入口只渲染一次 AdminLayout）")
        elif "AdminLayout" in app_text:
            errors.append("壳层布局重复挂载（vue 布局由路由父级挂载，App.vue 只留 <router-view />）")

    base_url = str(manifest.get("base_url", ""))
    if not base_url.startswith(("http://127.0.0.1", "http://localhost")):
        errors.append("manifest.base_url 须为本机地址")

    visual_globs = manifest.get("visual_source_globs")
    if not isinstance(visual_globs, list) or not visual_globs:
        errors.append("manifest.visual_source_globs 须为非空数组")
    else:
        for item in visual_globs:
            if str(item).startswith(("node_modules", "dist", ".jjui/reports")):
                errors.append(f"visual_source_globs 含禁用项: {item}")

    try:
        package = read_json(root / "package.json")
    except Exception as exc:
        errors.append(f"package.json 不可读: {exc}")
        package = {}

    deps: dict[str, str] = {}
    for section in ("dependencies", "devDependencies"):
        deps.update(package.get(section, {}))
    if spec["component"] not in deps:
        errors.append(f"package.json 缺组件库依赖: {spec['component']}")
    if spec["conflicting"] in deps:
        errors.append(f"package.json 混入冲突组件库: {spec['conflicting']}")
    for package_name in spec["forbidden"]:
        if package_name in deps:
            errors.append(f"package.json 含默认禁止依赖: {package_name}")
    for package_name in spec["required"]:
        if package_name not in deps:
            errors.append(f"package.json 缺必需依赖: {package_name}")

    pages = page_plan.get("pages")
    if not isinstance(pages, list) or not pages:
        errors.append("page-plan.pages 须为非空数组")
        pages = []

    seen_ids, seen_routes, seen_files = set(), set(), set()
    all_page_ids = {page.get("id") for page in pages if isinstance(page, dict)}
    page_meta: dict = {}
    op_texts: list = []  # 跨页操作列文案采集（循环内逐页收集，循环后做全站同质性对账）
    route_rows = routes.get("routes") if isinstance(routes, dict) else None
    if not isinstance(route_rows, list) or len(route_rows) != len(pages):
        errors.append("route registry 数量须与 page-plan.pages 一致")
        route_rows = []
    route_by_id = {row.get("page_id"): row for row in route_rows if isinstance(row, dict)}

    for page in pages:
        page_id, slug = page.get("id", ""), page.get("slug", "")
        if not id_ok(page_id):
            errors.append(f"页面 ID 非法: {page_id or '<空>'}")
        if page_id in seen_ids:
            errors.append(f"页面 ID 重复: {page_id}")
        seen_ids.add(page_id)
        if not slug_ok(slug):
            errors.append(f"页面短名非法: {slug or '<空>'}")
        route, file_rel = page.get("route", ""), page.get("file", "")
        if not route.startswith("/") or route in seen_routes:
            errors.append(f"页面路由非法或重复: {page_id} {route or '<空>'}")
        seen_routes.add(route)
        file_path = root / file_rel
        if not file_rel or not file_path.is_file():
            errors.append(f"页面文件缺失: {page_id} {file_rel or '<空>'}")
            continue
        if file_rel in seen_files:
            errors.append(f"页面文件重复: {file_rel}")
        seen_files.add(file_rel)
        try:
            source = file_path.read_text(encoding="utf-8")
        except Exception as exc:
            errors.append(f"页面文件不可读: {file_rel}: {exc}")
            continue
        if f'data-jjui-page="{page_id}"' not in source:
            errors.append(f"页面缺稳定页锚点: {page_id}")
        for region in page.get("regions", []):
            anchor = region.get("anchor", "")
            if not anchor_ok(anchor) or f'data-jjui-region="{anchor}"' not in source:
                errors.append(f"页面缺区域锚点: {page_id} {anchor or '<空>'}")
        for action in page.get("actions", []):
            anchor = action.get("anchor", "")
            if not anchor_ok(anchor) or f'data-jjui-action="{anchor}"' not in source:
                errors.append(f"页面缺操作锚点: {page_id} {anchor or '<空>'}")
        for dynamic in page.get("dynamic_regions", []):
            anchor = dynamic.get("anchor", "")
            if not anchor_ok(anchor) or f'data-jjui-data="{anchor}"' not in source:
                errors.append(f"页面缺动态区锚点: {page_id} {anchor or '<空>'}")
        for text in page.get("structural_texts", []):
            if text not in source:
                errors.append(f"页面缺计划内结构文案: {page_id} {text}")
        # 表格分页对账（判据正源: references/composition-layer.md 表格段——归类判据 = 页面有无新增类入口，
        # 数据可经 UI 增长即业务记录必须分页；当前种子数量不是免分页依据，少就补种子）
        if re.search(spec["table_re"], source):
            mock_rows = page.get("mock_rows")
            # 新增入口判定：page-plan actions 登记项的 id/anchor/label 命中新增类语义
            has_create = any(
                re.search(r"新建|新增|创建|添加|录入|create|add\b", str(a.get(k) or ""), re.IGNORECASE)
                for a in page.get("actions", []) if isinstance(a, dict)
                for k in ("id", "anchor", "label")
            )
            if has_create:
                if not isinstance(mock_rows, int) or mock_rows <= 0:
                    errors.append(f"业务记录表格页缺 mock_rows 登记（页面有新增入口，数据可经 UI 增长，须登记行数并分页）: {page_id}")
                else:
                    if mock_rows < 25:
                        errors.append(f"业务记录表格 mock_rows={mock_rows} < 25（页面有新增入口，种子须 ≥ 25 保证分页器可见、翻页可演示）: {page_id}")
                    if not re.search(spec["pagination_re"], source):
                        errors.append(f"业务数据表格缺分页（页面有新增入口，须 pageSize=10 且显示总数）: {page_id}")
                    # antd 分页须 itemRender 自组带边框文字上下页（判据正源: references/composition-layer.md 表格段）
                    if spec["component"] == "antd" and "itemRender" not in source:
                        errors.append(f"antd 分页须用 itemRender 自组带边框文字上下页（不用内置小箭头/裸文字）: {page_id}")
                    # 主操作跟随表格（判据正源: references/composition-layer.md 页面段——不分配方，业务表格须卡头两翼+左翼快捷搜索）
                    header_pos = source.find("jjui-table-header")
                    if header_pos < 0:
                        errors.append(f"业务表格须用表格卡头两翼结构（.jjui-table-header：主操作+快捷搜索在左，配置图标在右）: {page_id}")
                    elif not re.search(r"<Input\b|<el-input\b", source[header_pos:header_pos + 1200]):
                        errors.append(f"业务表格卡头缺左翼快捷搜索（左翼主操作+即时过滤输入框，右翼配置图标）: {page_id}")
            elif isinstance(mock_rows, int) and mock_rows > 10:
                # 无新增入口但登记行数 > 10：仍须分页（登记量已超出免分页白名单量级）
                if not re.search(spec["pagination_re"], source):
                    errors.append(f"业务数据表格缺分页（mock_rows={mock_rows} > 10，须 pageSize=10 且显示总数）: {page_id}")

        # 可交互控件对账（判据正源: references/page-archetypes.md 操作与状态段）
        control_count = len(re.findall(spec["control_re"], source))
        anchor_count = len(re.findall(r'data-jjui-action="', source))
        if control_count > anchor_count:
            errors.append(
                f"页面存在未登记操作的可交互控件: {page_id}"
                f"（可交互控件 {control_count} 个 / 操作锚点 {anchor_count} 个；"
                "每个控件须登记 action 并带 data-jjui-action 锚点）"
            )
        # 页面源码禁嵌套组件库卡与手写阴影（判据正源: references/composition-layer.md 工具栏段/容器层级段）
        for pattern, message in ((r"<Card[\s>/]", "页面内嵌套组件库卡片"), (r"<el-card[\s>/]", "页面内嵌套组件库卡片"), (r"boxShadow|box-shadow", "页面手写阴影")):
            if re.search(pattern, source):
                errors.append(f"{message}: {page_id}")
        # 表单项 label 必备（判据正源: references/composition-layer.md 表单段——placeholder 不得替代 label 充当字段名）
        form_item_tag = r"<Form\.Item\b[^>]*>" if spec["component"] == "antd" else r"<el-form-item\b[^>]*>"
        form_items = re.findall(form_item_tag, source)
        unlabeled_items = [m for m in form_items if "label=" not in m]
        if unlabeled_items:
            errors.append(
                f"表单项缺 label（字段名必须用 label，placeholder 只作输入示例；水平布局 label 左对齐）: "
                f"{page_id}（{len(unlabeled_items)}/{len(form_items)} 项未标注）"
            )
        # 死按钮对账（判据正源: references/composition-layer.md 页面段/工具栏段——每个登记 action 须有可演示反馈）
        for m in re.finditer(r'data-jjui-action="[^"]+"', source):
            window = source[max(0, m.start() - 600):m.end() + 600]
            if not re.search(r"onClick|@click|onConfirm|onChange|@change|@input|onOk|itemRender|v-model|Popconfirm|Dropdown|Link|navigate|router|href|submit|rules|validateFields|Form\.Item|el-form-item", window):
                errors.append(f"操作无可演示反馈（死按钮：须有 onClick/@click 打开弹框、切换状态、导航或 message 反馈）: {page_id} {m.group(0)}")
        # StatusTag 不承载说明句/拼接/计数（判据正源: references/composition-layer.md 状态段——label 须为字面量状态词）
        for m in re.finditer(r'<StatusTag\b[^>]*?(?<![:-])label="([^"]*)"', source):
            if re.search(r"[，。；：（）]", m.group(1)):
                errors.append(f"StatusTag 混入说明句（label 只承载状态词，页级全局信息用 Alert 放卡片上方）: {page_id} {m.group(1)[:20]}")
            elif re.search(r"共\s*\d|·", m.group(1)):
                errors.append(f"StatusTag label 禁计数说明（共 N 条等计数不是状态词，用次要色文字承载）: {page_id} {m.group(1)[:20]}")
        # 非字面量 label：react label={`...`}/label={cond ? "a" : "b"} 拼接说明句绕过标点检查（判据正源: 状态段）
        # 三元判定排除可选链 ?.（statusLabel(detail?.status) 是合法纯函数调用）
        for m in re.finditer(r'<StatusTag\b[^>]*?(?<![:-])label=\{', source):
            expr = source[m.end():m.end() + 120].split("}")[0].replace("?.", "")
            if "`" in expr or "?" in expr:
                errors.append(f"StatusTag label 须为字面量状态词（模板串/三元表达式拼接会绕过标点检查，动态状态词经纯变量传入）: {page_id}")
        # vue :label 绑定表达式含三元同判（静态字符串绑定等价字面量，放行）
        for m in re.finditer(r'<StatusTag\b[^>]*?:label="([^"]*)"', source):
            if "?" in m.group(1).replace("?.", ""):
                errors.append(f"StatusTag label 须为字面量状态词（绑定表达式三元拼接会绕过标点检查，动态状态词经纯变量/纯函数传入）: {page_id}")
            elif re.search(r"[，。；：（）]", m.group(1)):
                errors.append(f"StatusTag 混入说明句（label 只承载状态词，页级全局信息用 Alert 放卡片上方）: {page_id} {m.group(1)[:20]}")
        composition = page.get("composition")
        if not isinstance(composition, dict):
            errors.append(f"页面缺 composition 契约: {page_id}")
        else:
            recipe = composition.get("recipe")
            if recipe not in RECIPES:
                errors.append(f"composition.recipe 非法: {page_id} {recipe or '<空>'}")
            required = composition.get("required_components")
            if not isinstance(required, list) or not required:
                errors.append(f"composition.required_components 须为非空数组: {page_id}")
            else:
                for name in required:
                    if name not in COMPOSITION_COMPONENTS:
                        errors.append(f"required_components 含未注册组件: {page_id} {name}")
                        continue
                    comp_path = root / COMPONENTS_DIR / f"{name}{spec['ext']}"
                    if not comp_path.is_file():
                        errors.append(f"组合层组件文件缺失: {page_id} {name}{spec['ext']}")
                    if name not in source:
                        errors.append(f"页面未实际使用组合层组件: {page_id} {name}")
        row = route_by_id.get(page_id)
        if not row:
            errors.append(f"route registry 缺页面: {page_id}")
        else:
            if row.get("route") != route:
                errors.append(f"route registry 路由不一致: {page_id}")
            if row.get("file") != file_rel:
                errors.append(f"route registry 文件不一致: {page_id}")
            if row.get("entry") != page.get("expected_entry"):
                errors.append(f"route registry entry 不一致: {page_id}")

        # 页间主从关系（判据正源: references/composition-layer.md 详情呈现段）
        recipe = composition.get("recipe") if isinstance(composition, dict) else None
        expected_entry = page.get("expected_entry", [])
        if not isinstance(expected_entry, list):
            errors.append(f"expected_entry 须为数组: {page_id}")
            expected_entry = []
        master_ref = page.get("master_ref")
        if (recipe == "detail" or "internal-entry" in expected_entry) and not master_ref:
            errors.append(f"详情页缺 master_ref（须为来源页 ID 或 fixed:<数据集>）: {page_id}")
        if "internal-entry" in expected_entry and "menu" in expected_entry:
            errors.append(f"internal-entry 详情页不得挂菜单: {page_id}")
        # 菜单挂载物理对账：壳层 AdminLayout 真实挂载 ↔ expected_entry 申报一致
        route_in_layout = route in layout_routes
        if route_in_layout and "menu" not in expected_entry:
            errors.append(f"计划外菜单/壳层入口挂载: {page_id} {route}")
        if "menu" in expected_entry and not route_in_layout:
            errors.append(f"计划内菜单未在壳层挂载: {page_id} {route}")
        if master_ref is not None:
            if isinstance(master_ref, str) and master_ref.startswith("fixed:"):
                if not slug_ok(master_ref[len("fixed:"):]):
                    errors.append(f"master_ref fixed:<数据集> 须为 kebab-case 数据集名: {page_id} {master_ref}")
            elif id_ok(master_ref) and master_ref in all_page_ids:
                if ":" not in route:
                    errors.append(f"master_ref 指向来源页时路由须带参数段（如 /cases/:id）: {page_id}")
            else:
                errors.append(f"master_ref 非法（须为计划内页面 ID 或 fixed:<数据集>）: {page_id} {master_ref}")
        # 编辑器型页面对账（判据正源: references/composition-layer.md 编辑器型页面段——canvas/ide 共享判据）
        if recipe in ("canvas", "ide"):
            if recipe == "canvas":
                container, obj_re = "data-jjui-canvas", r"data-jjui-(?:node|edge)="
            else:
                container, obj_re = "data-jjui-ide", r"data-jjui-node="
            if container not in source:
                errors.append(f"编辑器型页面缺容器锚点 {container}（主编辑面整体落容器）: {page_id}")
            if recipe == "canvas" and (not re.search(r"data-jjui-node=", source) or not re.search(r"data-jjui-edge=", source)):
                errors.append(f"画布页节点/边锚点缺失（data-jjui-node / data-jjui-edge 均须非空）: {page_id}")
            if recipe == "ide" and not re.search(obj_re, source):
                errors.append(f"ide 页大纲树项锚点缺失（可选中对象须带 data-jjui-node）: {page_id}")
            if recipe == "ide" and not re.search(r"<Tabs\b|<el-tabs\b", source):
                errors.append(f"ide 页编辑器须用 Tabs/el-tabs 分区（消除右栏纵向长滚动）: {page_id}")
            # 嵌入式详情返回控件落位（判据正源: composition-layer.md 编辑器型页面段——
            # 返回控件落位编辑器面板页头行左端（← 图标 + 文案，与 PageHeader titleline 同型），禁混入 Tabs 标签行）
            tpos = re.search(r"<Tabs\b|<el-tabs\b", source)
            if tpos and re.search(r"返回", source[tpos.start():tpos.start() + 2000]):
                errors.append(
                    f"返回控件禁止混入 Tabs 区（落位编辑器面板页头行左端：← 图标 + 文案，与 PageHeader 返回导航同型）: {page_id}"
                )
            for m in re.finditer(obj_re, source):
                window = source[max(0, m.start() - 600):m.end() + 600]
                if not re.search(r"onClick|@click|onNodeClick|onEdgeClick|onSelect|onSelectChange", window):
                    errors.append(f"画布/树对象无交互信号（须可选中驱动编辑器与伴随面板，onClick/@click 等）: {page_id} {m.group(0)}")
            if "SectionCard" in source or re.search(r"<Card[\s>/]|<el-card[\s>/]", source):
                errors.append(f"编辑器型页面禁卡片堆叠（图/编辑器不得被 SectionCard/组件库卡片切碎，分区只有主编辑面、伴随面板、状态栏）: {page_id}")
            if re.search(r'column=\{[2-9]\}|:column="[2-9]"', source):
                errors.append(f"窄栏禁横排描述列表（Descriptions column≥2 塞控件必然挤压，横向紧凑字段组用 Form 栅格 Row/Col 承载）: {page_id}")
            # 栏内滚动容器禁写死高度（判据正源: composition-layer.md 弹性窄栏段栏内分区滚动——
            # max-height 写死会把滚动条钉死在写死高度处，栏下方留死空白；JSX camelCase 与 kebab-case 同查，
            # 前置排除 line-height/min-height 等复合属性）
            if re.search(r"maxHeight:\s*\d|max-height:\s*\d|(?<![-a-zA-Z])[hH]eight:\s*\d", source):
                errors.append(
                    f"窄栏内滚动容器禁止 max-height/height 写死像素（滚动条会被钉死在写死高度处，用 flex:1 + min-height:0 + overflow-y:auto 弹性撑满）: {page_id}"
                )
            # 底部状态栏承载（判据正源: references/composition-layer.md 编辑器型页面段底部状态栏；
            # 层级由组件库浮层阶梯自动保证，不查显式 zIndex——antd v6 已移除 Affix zIndex prop）
            if not re.search(r"<Affix\b|<el-affix\b", source):
                errors.append(f"底部状态栏须用组件库钉住组件承载（Affix/el-affix，fixed 吸附滚动全程贴视口底）: {page_id}")
            if recipe == "canvas":
                graph_dep = GRAPH_DEPS.get(stack)
                if graph_dep and graph_dep not in deps:
                    errors.append(f"canvas 页缺图视图库依赖（单点豁免库 {graph_dep}，库名单源见对应栈参考画布段）: {page_id}")
        # 区块组织对账（判据正源: references/composition-layer.md 区块组织段——并列兜底有上限，超限须组织形态）
        if recipe not in ("canvas", "ide"):
            card_count = len(re.findall(r"<SectionCard\b", source))
            if (
                card_count > 3
                and not re.search(r"<Tabs\b|<el-tabs\b|<Anchor\b|<el-anchor\b|MasterDetail", source)
            ):
                errors.append(
                    f"并列区块超限（{card_count} 张 SectionCard 纵向堆叠，>3 须改用 Tabs 分区/Anchor 锚点导航/MasterDetail 主从或拆详情页）: {page_id}"
                )
        # PageHeader 门牌禁操作控件（判据正源: references/composition-layer.md 页面段——
        # 右上角没有操作区，返回经组件 onBack 承载；数据操作按语义归位表格卡头两翼/查询卡/状态栏/详情区）
        ph_start = source.find("<PageHeader")
        if ph_start >= 0:
            ph_end_close = source.find("/>", ph_start)
            ph_end_pair = source.find("</PageHeader>", ph_start)
            ph_end = min(x for x in (ph_end_close + 2, ph_end_pair) if x > 0)
            if ph_end_pair > 0:
                ph_end = min(ph_end_close + 2, ph_end_pair + 13)
            fragment = source[ph_start:ph_end]
            if re.search(spec["control_re"], fragment):
                errors.append(f"PageHeader 只承载标题、描述与返回导航，不放操作控件（数据操作按语义归位表格卡头两翼/查询卡/状态栏/详情区）: {page_id}")
        # 查询卡布局对账（判据正源: references/composition-layer.md 表格段查询卡布局——label 横排、Form inline 承载）
        if recipe == "list" and re.search(r"filters=\{|#filters", source):
            if not re.search(r'layout="inline"|"inline": true|:inline="true"|:inline\b', source):
                errors.append(f"查询卡字段须用 Form layout=\"inline\" 承载（label 横排左对齐，placeholder 不替代 label）: {page_id}")
            # 控件宽度走 token（字段槽等宽是跨行对齐的前提；--control-width 引用不匹配数字正则。
            # 只查查询卡片段窗口——表格列定义 width、操作列固定宽度是判据要求的合法声明，不能全局误伤）
            fpos = re.search(r"filters=\{|#filters", source)
            fwindow = source[fpos.start():fpos.start() + 1500] if fpos else ""
            if re.search(r"style=\{\{[^}]*[wW]idth:\s*\d+(?:px)?(?=[\s;\"'}>])|style=\"[^\"]*[wW]idth:\s*\d+(?:px)?(?=[\s;\"'}>])", fwindow):
                errors.append(f"查询卡控件宽度禁止写死像素（走 --control-width 统一 token，字段槽等宽跨行才对齐）: {page_id}")
        # label 竖排禁令——全局适用（判据正源: composition-layer.md 表格段查询卡布局："全局即报，弹框表单一并管住"；
        # 不可嵌进 list 查询卡分支——0.2.17 曾因此让 ide 页弹框表单的 layout="vertical" 逃逸）
        if re.search(r'layout="vertical"|label-position="top"', source):
            errors.append(f"label 禁止竖排（layout=\"vertical\"/label-position=\"top\"，label 横排在控件左侧左对齐）: {page_id}")
        # 表单字段槽等宽（判据正源: references/composition-layer.md 表单段——label 定宽，禁自然宽度）
        # react：labelCol flex:"none" 让 label 按文字自然宽度占位，各行控件左起点漂移、宽窄不一
        if re.search(r"labelCol=\{\{\s*flex:\s*[\"']none[\"']", source):
            errors.append(f"表单 labelCol 禁止 flex: \"none\"（label 自然宽度导致各行字段槽长长短短；用 span 栅格或 flex 定值定宽）: {page_id}")
        # vue：非 inline 的 el-form 缺 label-width 定宽即同病（inline 查询卡由 CSS .jjui-toolbar__filters 定宽管住，豁免；
        # (?!-) 排除 el-form-item——\b 在连字符前同样成立；[^>]* 可跨行匹配多行属性的 el-form 标签）
        for m in re.finditer(r"<el-form\b(?!-)[^>]*>", source):
            tag = m.group(0)
            if ":inline" in tag or "label-width" in tag:
                continue
            errors.append(f"el-form 非 inline 承载须 label-width 定宽（缺省自然宽度导致各行字段槽长长短短；走 --form-label-width token）: {page_id}")
        # 控件宽度 token 单档化对账（判据正源: composition-layer.md 查询卡布局——两档合并为 --control-width 统一档，全局查）
        if re.search(r"--control-width-select|--control-width-input", source):
            errors.append(f"控件宽度 token 已合并为 --control-width 单档（--control-width-select/-input 已废除，查询卡全字段统一等宽）: {page_id}")
        # 弹框表单控件占满槽宽（判据正源: composition-layer.md 表单段字段槽等宽——不设固定宽度，Select 须显式 100%）；
        # 窗口法从 Modal/el-dialog 开标签起 2000 字符；只查 style 前缀形态——表格列定义 width 是裸键不带 style，不误伤
        for m in re.finditer(r"<Modal\b|<el-dialog\b", source):
            mwin = source[m.start():m.start() + 2000]
            if re.search(r"style=\{\{[^}]*[wW]idth:\s*\d+(?:px)?(?=[\s;\"'}>])|style=\"[^\"]*[wW]idth:\s*\d+(?:px)?(?=[\s;\"'}>])", mwin):
                errors.append(f"弹框表单控件禁止写死像素宽度（占满字段槽预留宽度，Select 须显式 width: \"100%\"）: {page_id}")
                break
        # 操作列形态（判据正源: composition-layer.md 表格段操作列条——文字链、禁 disabled 灰字）。
        # 窗口法：title:"操作"/label="操作" 起 700 字符；逐 Button 取其后 200 字符片段校验 link 形态
        op_react = re.search(r'title:\s*"操作"', source)
        if op_react:
            owin = source[op_react.start():op_react.start() + 700]
            # 片段边界 = 下一个 Button 起点，防止前一按钮的片段渗漏进后一按钮的 link 形态造成漏判
            btn_starts = [bm.start() for bm in re.finditer(r"<Button\b", owin)] + [len(owin)]
            for i, s in enumerate(btn_starts[:-1]):
                if 'type="link"' not in owin[s:btn_starts[i + 1]]:
                    errors.append(f"操作列动作一律文字链（Button type=\"link\"，危险动作 danger 文字链 + Popconfirm，禁实心/带边框按钮）: {page_id}")
                    break
            if re.search(r"<Button\b[^>\n]{0,120}\bdisabled\b", owin):
                errors.append(f"操作列当前行不可执行的动作不渲染（列宁毋假，禁 disabled 灰字）: {page_id}")
            # 跨页操作列文案采集（全站同质性对账在循环后汇总，判据正源: composition-layer.md 表格段操作列条；
            # 复用 btn_starts 分段——按钮属性含箭头函数 => 会截断单正则，须逐段取 </Button> 前文字）
            for i, s in enumerate(btn_starts[:-1]):
                tm = re.search(r">([^<>{}]+)</Button>", owin[s:btn_starts[i + 1]])
                if tm:
                    t = tm.group(1).strip()
                    if t and t != "更多":
                        op_texts.append(t)
        op_vue = re.search(r'label="操作"', source)
        if op_vue:
            owin = source[op_vue.start():op_vue.start() + 700]
            btn_starts = [bm.start() for bm in re.finditer(r"<el-button\b", owin)] + [len(owin)]
            for i, s in enumerate(btn_starts[:-1]):
                if "link" not in owin[s:btn_starts[i + 1]]:
                    errors.append(f"操作列动作一律文字链（el-button link，危险动作 danger 文字链 + el-popconfirm，禁实心/带边框按钮）: {page_id}")
                    break
            if re.search(r"<el-button\b[^>\n]{0,120}\bdisabled\b", owin):
                errors.append(f"操作列当前行不可执行的动作不渲染（列宁毋假，禁 disabled 灰字）: {page_id}")
            # 跨页操作列文案采集（全站同质性对账在循环后汇总，判据正源: composition-layer.md 表格段操作列条；
            # 复用 btn_starts 分段——属性含箭头函数 => 会截断单正则，须逐段取 </el-button> 前文字）
            for i, s in enumerate(btn_starts[:-1]):
                tm = re.search(r">([^<>{}]+)</el-button>", owin[s:btn_starts[i + 1]])
                if tm:
                    t = tm.group(1).strip()
                    if t and t != "更多":
                        op_texts.append(t)
        # 描述列表只读（判据正源: references/composition-layer.md 弹性窄栏段——Descriptions 是只读呈现，
        # 描述项塞可编辑控件即报；column=1 只是避免挤压，不改变只读语义）
        if re.search(r"children:\s*<(?:Input(?:\.TextArea)?|Select|Switch|DatePicker|InputNumber|Radio|Checkbox)\b", source) or \
           re.search(r"<el-descriptions-item\b[\s\S]{0,300}?<el-(?:input|select|date-picker|switch|input-number)\b", source):
            errors.append(f"描述列表是只读呈现，描述项内禁塞可编辑控件（编辑态字段一律 Form：label 左侧左对齐、控件右侧）: {page_id}")
        # 描述项 label 只承载字段名（判据正源: 同上——说明句进描述行；
        # 只查全角括号——半角括号是绑定表达式/函数调用的代码特征，不能当说明句判据）
        if re.search(r'label:\s*"[^"]*（[^"]*）"|label="[^"]*（[^"]*）"', source):
            errors.append(f"描述项 label 只承载字段名（2~8 字），说明句进描述行: {page_id}")
        # 操作锚点唯一性（判据正源: references/composition-layer.md 工具栏段——刷新等同一语义不得多入口）
        anchor_names = re.findall(r'data-jjui-action="([^"]+)"', source)
        anchor_dups = sorted({a for a in anchor_names if anchor_names.count(a) > 1})
        if anchor_dups:
            errors.append(f"操作锚点重复: {page_id} {', '.join(anchor_dups)}")
        # 列表页卡片不起标题（判据正源: references/composition-layer.md 页面段/工具栏段）
        # 单区块页禁卡题卡述（判据正源: references/composition-layer.md 卡片段——区块子标题的价值是区分多区块，
        # 单卡页纯重复层级；canvas/ide 主编辑面容器不属此列。只查静态字面量——title={...} 动态绑定是映射卡特征，跳过）
        if recipe not in ("canvas", "ide") and len(re.findall(r"<SectionCard\b", source)) == 1:
            if re.search(r'<SectionCard[^>]*?(?:title="[^"]*"|description="[^"]*")', source):
                errors.append(f"单区块页卡不起标题与描述（页面语义由 PageHeader 承载，卡描述信息并 PageHeader 描述行，卡内直接放内容）: {page_id}")
        if recipe == "list":
            card_titles = re.findall(r'<SectionCard[^>]*?title="([^"]*)"', source)
            if card_titles:
                errors.append(f"列表页卡片不起标题（页面标题由 PageHeader 承载，卡不重复起名）: {page_id} {card_titles[0]}")
            # 表格卡头两翼结构（判据正源: references/composition-layer.md 页面段——左翼主操作+快捷搜索，右翼配置图标）
            if re.search(spec["table_re"], source) and "jjui-table-header" not in source:
                errors.append(f"列表页缺表格卡头两翼结构（.jjui-table-header：左翼主操作+快捷搜索，右翼刷新/列设置，禁止在表格上方另起工具条）: {page_id}")
            # 卡头左翼对账（判据正源: references/composition-layer.md 工具栏段——两翼齐备，右翼不得独占卡头；
            # 只有右翼时 space-between 下单子元素靠左，视觉上图标漂在表格左上）
            header_pos = source.find("jjui-table-header")
            if re.search(spec["table_re"], source) and header_pos >= 0 and not re.search(r"<Input\b|<el-input\b", source[header_pos:header_pos + 1200]):
                errors.append(f"列表页表格卡头缺左翼快捷搜索（.jjui-table-header 左翼须有即时过滤输入框，主操作+搜索在左、配置图标在右）: {page_id}")
        # 表级配置操作须入表格卡头两翼，任何配方通用（判据正源: references/composition-layer.md 工具栏段/表格段）
        if (
            re.search(spec["table_re"], source)
            and "jjui-table-header" not in source
            and re.search(r"列设置|列配置|刷新", source)
        ):
            errors.append(f"表级配置操作（刷新/列设置）漂在表格卡外——须进 .jjui-table-header 右翼，禁止在表格上方另起独立工具条: {page_id}")
        page_meta[page_id] = {
            "route": route,
            "entry": expected_entry,
            "source": source,
            "datasets": {d.get("dataset") for d in page.get("dynamic_regions", []) if isinstance(d, dict)},
        }

    # 操作列跨页同质性对账（判据正源: references/composition-layer.md 表格段操作列条——
    # 动作文案按页面业务语义命名并来自 page-plan actions 登记，禁止全站统一占位文案）
    if op_texts:
        counts = {}
        for t in op_texts:
            counts[t] = counts.get(t, 0) + 1
        total = len(op_texts)
        top_text = max(counts, key=lambda k: counts[k])
        top_n = counts[top_text]
        if total >= 2 and len(counts) == 1:
            errors.append(
                f"操作列文案全站同质（{total} 处全部为「{top_text}」）：动作须按页面业务语义命名并来自 page-plan actions 登记，禁止全站统一占位文案"
            )
        elif total >= 5 and top_n / total > 0.6:
            errors.append(
                f"操作列文案高度同质（「{top_text}」占 {top_n}/{total}）：动作须按页面业务语义命名，禁止单一占位文案贯穿全站"
            )

    if isinstance(excluded, dict) and not isinstance(excluded.get("excluded"), list):
        errors.append("excluded-pages.excluded 须为数组")

    # 容器层级对账（判据正源: references/composition-layer.md 工具栏段/容器层级段），admin.css 只查一次
    admin_css_clean = re.sub(r"/\*[\s\S]*?\*/", "", admin_css_text)
    # 1) 阴影白名单：只有视觉容器组件可声明 box-shadow（编辑器型页面一体容器同为主视觉容器）
    shadow_whitelist = (".jjui-section", ".jjui-metric", ".jjui-master", ".jjui-canvas", ".jjui-ide")
    for selector_block, body in re.findall(r"([^{}]+)\{([^{}]*)\}", admin_css_clean):
        if "box-shadow" not in body:
            continue
        selectors = [s.strip() for s in selector_block.split(",")]
        if not any(any(s.startswith(w) or s.startswith(f"{w}:") for w in shadow_whitelist) for s in selectors):
            first = selectors[0].strip().splitlines()[-1].strip()
            errors.append(f"样式基线阴影越权（视觉容器仅 .jjui-section/.jjui-metric/.jjui-master）: {first}")
    # 2) 工具栏零盒模型：只允许布局属性
    toolbar_block = re.search(r"\.jjui-toolbar\s*\{([^}]*)\}", admin_css_text)
    if toolbar_block:
        decorated = re.findall(r"(?:padding|margin|background|border-radius|box-shadow)\s*[:;]", toolbar_block.group(1))
        if decorated:
            errors.append("工具条混入视觉容器样式（零盒模型，间距归宿主卡 body）")
    # 2.1) 工具栏换行基线（判据正源: composition-layer.md 工具栏段查询卡布局——字段超宽换行、按钮组吸附行尾整体换行；
    # 0.2.25 实锤：业务工程漏抄此基线导致查询/重置被 space-between 挤成右侧竖排）
    if toolbar_block and "flex-wrap: wrap" not in toolbar_block.group(1):
        errors.append("样式基线工具条缺 flex-wrap: wrap（查询字段超宽须换行，按钮组整体换行不拆行）")
    actions_blocks = re.findall(r"\.jjui-toolbar__actions\s*\{([^}]*)\}", admin_css_clean)
    if not actions_blocks or not any("margin-left: auto" in b for b in actions_blocks):
        errors.append("样式基线工具条操作区未吸附行尾（.jjui-toolbar__actions 须 margin-left: auto，查询/重置整体换行不孤悬）")
    # 3) 主从分栏容器基线（判据正源: references/composition-layer.md 主从布局段——右栏 min-width: 0 防横向溢出）
    master_body_block = re.search(r"\.jjui-master__body\s*\{([^}]*)\}", admin_css_clean)
    if not master_body_block or "min-width: 0" not in master_body_block.group(1):
        errors.append("样式基线缺主从分栏容器（.jjui-master__body 须 display:flex 且 min-width: 0）")
    # 3.5) 表格卡头基线（判据正源: references/composition-layer.md 工具栏段——两翼布局单源）
    table_header_block = re.search(r"\.jjui-table-header\s*\{([^}]*)\}", admin_css_clean)
    if not table_header_block or "justify-content: space-between" not in table_header_block.group(1):
        errors.append("样式基线表格卡头未两翼分布（.jjui-table-header 须 justify-content: space-between）")
    # 3.6) MasterDetail 门牌字号统一（判据正源: references/composition-layer.md 卡片段——子标题风格统一，同字号）
    master_title_block = re.search(r"\.jjui-master__title\s*\{([^}]*)\}", admin_css_clean)
    if not master_title_block or "var(--font-size-section)" not in master_title_block.group(1):
        errors.append("样式基线门牌字号漂移（.jjui-master__title 须与区块标题同字号 var(--font-size-section)）")
    # 3.7) 画布容器基线（判据正源: references/composition-layer.md 画布段——三区一体容器，分栏防横向溢出）
    canvas_css_block = re.search(r"\.jjui-canvas\s*\{([^}]*)\}", admin_css_clean)
    if not canvas_css_block or "display: flex" not in canvas_css_block.group(1):
        errors.append("样式基线缺画布容器段（.jjui-canvas 三区一体容器）")
    canvas_body_block = re.search(r"\.jjui-canvas__body\s*\{([^}]*)\}", admin_css_clean)
    if not canvas_body_block or "min-width: 0" not in canvas_body_block.group(1):
        errors.append("样式基线画布分栏缺 min-width: 0（.jjui-canvas__body 防横向溢出压扁伴随面板）")
    ide_css_block = re.search(r"\.jjui-ide\s*\{([^}]*)\}", admin_css_clean)
    if not ide_css_block or "display: flex" not in ide_css_block.group(1):
        errors.append("样式基线缺编辑器工作台容器段（.jjui-ide 三栏一体容器）")
    ide_body_block = re.search(r"\.jjui-ide__body\s*\{([^}]*)\}", admin_css_clean)
    if not ide_body_block or "min-width: 0" not in ide_body_block.group(1):
        errors.append("样式基线编辑器工作台分栏缺 min-width: 0（.jjui-ide__body 防横向溢出压扁伴随面板）")
    # 3.8) 钉住浮层的底部预留（判据正源: references/composition-layer.md 编辑器型页面段底部状态栏——
    # Affix 钉住是浮层，滚动内容底部须预留状态栏高度，末尾操作才完整可达）
    # 3.9) 门牌 titleline 基线（判据正源: references/composition-layer.md 页面段——返回箭头与标题同行垂直居中）
    titleline_block = re.search(r"\.jjui-page-header__titleline\s*\{([^}]*)\}", admin_css_clean)
    if not titleline_block or "display: flex" not in titleline_block.group(1) or "align-items: center" not in titleline_block.group(1):
        errors.append("样式基线缺门牌 titleline 段（.jjui-page-header__titleline 须 flex + center，返回箭头与标题同行）")
    for sel in (".jjui-ide__tree", ".jjui-ide__editor", ".jjui-editor-panel"):
        blk = re.search(re.escape(sel) + r"\s*\{([^}]*)\}", admin_css_clean)
        if not blk or "padding-bottom" not in blk.group(1):
            errors.append(f"样式基线 {sel} 缺底部预留 padding-bottom（Affix 状态栏是浮层，末尾内容须完整可达）")

    # 4) 分页基线特征（判据正源: references/composition-layer.md 表格段——整组靠右、元信息次要色、翻页按钮带边框）
    pagination_block = re.search(r"\.jjui-pagination\s*\{([^}]*)\}", admin_css_clean)
    if not pagination_block:
        errors.append("样式基线缺分页段（.jjui-pagination 整组靠右）")
    elif "justify-content: flex-end" not in pagination_block.group(1):
        errors.append("样式基线分页未整组靠右（.jjui-pagination 须 justify-content: flex-end）")
    meta_block = re.search(r"\.jjui-pagination__meta\s*\{([^}]*)\}", admin_css_clean)
    if spec["component"] == "antd":
        if not meta_block or "var(--color-text-secondary)" not in meta_block.group(1):
            errors.append("样式基线分页元信息未用次要色（.jjui-pagination__meta 须 color: var(--color-text-secondary)）")
        # 页码单源收敛（判据正源: references/composition-layer.md 表格段——页码全带边框，激活主色填充白字）
        active_block = re.search(r"\.jjui-pagination \.ant-pagination-item-active\s*\{([^}]*)\}", admin_css_clean)
        if not active_block or "var(--color-primary)" not in active_block.group(1):
            errors.append("样式基线缺页码激活收敛（.ant-pagination-item-active 须在 .jjui-pagination 段单源主色填充）")
        item_block = re.search(r"\.jjui-pagination \.ant-pagination-item\s*\{([^}]*)\}", admin_css_clean)
        if not item_block or "border" not in item_block.group(1):
            errors.append("样式基线缺页码边框（.ant-pagination-item 须在 .jjui-pagination 段单源补边框）")
    else:
        total_block = re.search(r"\.jjui-pagination \.el-pagination__total\s*\{([^}]*)\}", admin_css_clean)
        if not total_block or "var(--color-text-secondary)" not in total_block.group(1):
            errors.append("样式基线分页元信息未用次要色（.el-pagination__total 须在 .jjui-pagination 段单源用 var(--color-text-secondary)）")
        prev_block = re.search(r"\.jjui-pagination \.el-pagination \.btn-prev[^{]*\{([^}]*)\}", admin_css_clean)
        if not prev_block or "border" not in prev_block.group(1):
            errors.append("样式基线缺分页翻页边框（element-plus .btn-prev/.btn-next 须在 .jjui-pagination 段单源补边框）")
        pager_block = re.search(r"\.jjui-pagination \.el-pager li\s*\{([^}]*)\}", admin_css_clean)
        if not pager_block or "border" not in pager_block.group(1):
            errors.append("样式基线缺页码边框（.el-pager li 须在 .jjui-pagination 段单源补边框）")

    # 主从伪装反推（判据正源: references/composition-layer.md 详情呈现段）：
    # 来源页 A 行内跳转到菜单页 B，且 B 以固定下标（D[0] 等）绑定 A 数据集的记录 → B 是伪装成独立页的详情
    nav_re = re.compile(r'(?:to\s*=|navigate\(|router\.push\(|push\()\s*["\'`](/[^"\'`?#]+)')
    route_to_id = {meta["route"]: pid for pid, meta in page_meta.items()}
    for pid_a, meta_a in page_meta.items():
        datasets_a = meta_a["datasets"]
        if not datasets_a:
            continue
        for match in nav_re.finditer(meta_a["source"]):
            pid_b = route_to_id.get(match.group(1))
            if not pid_b or pid_b == pid_a:
                continue
            meta_b = page_meta[pid_b]
            if "menu" not in meta_b["entry"]:
                continue
            fixed = sorted(
                d for d in datasets_a
                if d and re.search(rf"\b{re.escape(d)}\s*\[\s*\d+\s*\]", meta_b["source"])
            )
            if fixed:
                errors.append(
                    f"疑似详情页伪装成菜单页: {pid_b} 以固定下标绑定 {pid_a} 的数据集 {fixed[0]}，"
                    "须按主从关系建模（master_ref + 参数路由 + 不挂菜单）或改为真实列表"
                )

    if not (root / "src/custom").is_dir():
        errors.append("src/custom 缺失")

    for entry in sorted(root.iterdir()):
        if entry.name not in ROOT_ALLOWED:
            errors.append(f"工程根计划外条目（疑似工具快照/会话残留，物证只允许落 .jjui/reports/）: {entry.name}")

    for path in (root / "src").rglob("*"):
        if path.is_file() and path.suffix in {".ts", ".tsx", ".vue", ".css", ".html"}:
            try:
                text = path.read_text(encoding="utf-8")
            except Exception:
                continue
            if "http://" in text or "https://" in text:
                errors.append(f"源码含外部 URL: {path.relative_to(root)}")

    if "__PRODUCT_ID__" in json.dumps(manifest) or "__BUSINESS__" in json.dumps(manifest) or "__JJUI_VERSION__" in json.dumps(manifest):
        errors.append("manifest 仍含初始化占位符")

    return errors
