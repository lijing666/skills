#!/usr/bin/env python3
"""End-to-end regression tests for jjui deterministic tools."""

from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
INIT = HERE / "init_prototype.py"
CHECK = HERE / "check_prototype.py"
EVIDENCE = HERE / "evidence.py"


class JjuiToolsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def run_init(self, stack: str, target: Path, product_id: str = "demo", business: str = "admin"):
        return subprocess.run(
            ["python3", str(INIT), "init", str(target), "--stack", stack, "--product-id", product_id, "--business", business],
            text=True,
            capture_output=True,
        )

    def run_check(self, target: Path):
        return subprocess.run(["python3", str(CHECK), str(target)], text=True, capture_output=True)

    def run_evidence(self, target: Path):
        return subprocess.run(["python3", str(EVIDENCE), "check", str(target)], text=True, capture_output=True)

    def init_stack(self, stack: str) -> Path:
        target = self.base / stack
        result = self.run_init(stack, target)
        self.assertEqual(result.returncode, 0, result.stderr)
        return target

    def patch_page(self, target: Path, page_rel: str, old: str, new: str) -> None:
        """页面源 = 入口 + features/ 合并源（判据正源: references/page-splitting.md）。

        在入口与其 features/ 目录内定位含 old 的文件做替换；定位不到即测试失效。
        """
        page_file = target / page_rel
        candidates = [page_file, *sorted(page_file.parent.glob("features/*"))]
        for path in candidates:
            text = path.read_text(encoding="utf-8")
            if old in text:
                path.write_text(text.replace(old, new), encoding="utf-8")
                return
        raise AssertionError(f"patch source not found: {page_rel} :: {old[:60]!r}")

    def test_init_and_check_react(self):
        target = self.init_stack("react-antd")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PROTOTYPE CHECK PASS", result.stdout)

    def test_init_and_check_vue(self):
        target = self.init_stack("vue3-element-plus")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PROTOTYPE CHECK PASS", result.stdout)

    def test_nonempty_target_is_rejected(self):
        target = self.base / "existing"
        target.mkdir()
        (target / "keep.txt").write_text("keep", encoding="utf-8")
        result = self.run_init("react-antd", target)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("目标目录非空", result.stderr)

    def test_conflicting_component_library_is_rejected(self):
        target = self.init_stack("react-antd")
        package_path = target / "package.json"
        package = json.loads(package_path.read_text(encoding="utf-8"))
        package["dependencies"]["element-plus"] = "^2.8.8"
        package_path.write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("混入冲突组件库", result.stderr)

    def test_missing_page_anchor_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-01-dashboard/index.vue"
        page.write_text(page.read_text(encoding="utf-8").replace('data-jjui-page="p-01"', "data-page"), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("页面缺稳定页锚点", result.stderr)

    def test_missing_structural_text_is_rejected(self):
        target = self.init_stack("react-antd")
        self.patch_page(target, "src/pages/p-02-customer-list/features/customer-table.tsx", "新建客户", "新增客户")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("页面缺计划内结构文案", result.stderr)

    def test_invalid_recipe_is_rejected(self):
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        plan["pages"][0]["composition"]["recipe"] = "landing"
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("composition.recipe 非法", result.stderr)

    def test_detail_recipe_without_master_ref_is_rejected(self):
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        plan["pages"][1]["composition"]["recipe"] = "detail"
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("详情页缺 master_ref", result.stderr)

    def test_internal_entry_with_menu_is_rejected(self):
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        plan["pages"][1]["expected_entry"] = ["menu", "internal-entry"]
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("internal-entry 详情页不得挂菜单", result.stderr)
        self.assertIn("详情页缺 master_ref", result.stderr)

    def test_master_ref_without_param_route_is_rejected(self):
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        plan["pages"][1]["expected_entry"] = ["internal-entry"]
        plan["pages"][1]["master_ref"] = "p-01"
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("路由须带参数段", result.stderr)

    def test_unregistered_component_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        plan["pages"][1]["composition"]["required_components"].append("FancyBanner")
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("含未注册组件", result.stderr)

    def test_declared_but_unused_component_is_rejected(self):
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        plan["pages"][0]["composition"]["required_components"].append("StatusTag")
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("页面未实际使用组合层组件", result.stderr)

    def test_missing_composition_contract_is_rejected(self):
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        del plan["pages"][0]["composition"]
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("页面缺 composition 契约", result.stderr)

    def test_layout_inline_border_is_rejected(self):
        target = self.init_stack("react-antd")
        layout = target / "src/layouts/AdminLayout.tsx"
        layout.write_text(layout.read_text(encoding="utf-8").replace(
            '<aside className="admin-sider">',
            '<aside className="admin-sider" style={{ borderRight: "1px solid #000" }}>'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("布局文件内联分隔线样式", result.stderr)

    def _write_baselines(self, target, tiny_first=False):
        plan = json.loads((target / ".jjui/page-plan.json").read_text(encoding="utf-8"))
        shots = target / ".jjui/reports/screenshots"
        for i, page in enumerate(plan["pages"]):
            data = b"\x89PNG" if tiny_first and i == 0 else b"\x89PNG" + b"0" * 2048
            (shots / f"{page['id']}-baseline.png").write_bytes(data)
        return shots

    def test_evidence_missing_is_reported(self):
        target = self.init_stack("react-antd")
        result = self.run_evidence(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("页面缺截图物证", result.stdout)

    def test_evidence_passes_with_valid_baselines(self):
        target = self.init_stack("vue3-element-plus")
        self._write_baselines(target)
        result = self.run_evidence(target)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("EVIDENCE CHECK PASS", result.stdout)

    def test_evidence_tiny_screenshot_is_rejected(self):
        target = self.init_stack("react-antd")
        self._write_baselines(target, tiny_first=True)
        result = self.run_evidence(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("截图过小", result.stdout)

    def test_evidence_nonbaseline_file_is_rejected(self):
        target = self.init_stack("react-antd")
        shots = self._write_baselines(target)
        (shots / "p-01-chain-view.png").write_bytes(b"\x89PNG" + b"0" * 2048)
        result = self.run_evidence(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("非 baseline 文件", result.stdout)

    def test_tool_residue_in_root_is_rejected(self):
        target = self.init_stack("react-antd")
        (target / ".playwright-cli").mkdir()
        (target / ".playwright-cli/console.log").write_text("log", encoding="utf-8")
        (target / "p01.yml").write_text("page: dump\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("工程根计划外条目", result.stderr)
        self.assertIn(".playwright-cli", result.stderr)
        self.assertIn("p01.yml", result.stderr)

    def test_master_detail_declared_but_unused_is_rejected(self):
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        plan["pages"][1]["composition"]["required_components"].append("MasterDetail")
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("页面未实际使用组合层组件", result.stderr)
        self.assertNotIn("含未注册组件", result.stderr)

    def test_stale_metric_baseline_is_rejected(self):
        target = self.init_stack("react-antd")
        css_path = target / "src/styles/admin.css"
        css = css_path.read_text(encoding="utf-8")
        css = css.replace("  overflow: hidden;\n", "")
        css = css.replace(
            ".jjui-metric--warning::before { background: var(--color-warning); }",
            ".jjui-metric--warning { border-top: 3px solid var(--color-warning); }",
        )
        css_path.write_text(css, encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("样式基线过期", result.stderr)
        self.assertIn("border-top", result.stderr)
        self.assertIn("overflow", result.stderr)

    def test_unregistered_interactive_control_is_rejected(self):
        target = self.init_stack("react-antd")
        self.patch_page(
            target,
            "src/pages/p-02-customer-list/features/customer-table.tsx",
            '<div data-jjui-data="p-02.customer-rows">',
            '<div data-jjui-data="p-02.customer-rows"><Input.Search placeholder="跳转编辑" enterButton="前往" />',
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("页面存在未登记操作的可交互控件", result.stderr)

    def test_table_without_mock_rows_is_rejected(self):
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        for pg in plan["pages"]:
            if pg["id"] == "p-02":
                del pg["mock_rows"]
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("表格页缺 mock_rows 登记", result.stderr)

    def test_business_table_without_pagination_is_rejected(self):
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        for pg in plan["pages"]:
            if pg["id"] == "p-02":
                pg["mock_rows"] = 30
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        self.patch_page(
            target, "src/pages/p-02-customer-list/features/customer-table.tsx", "<Pagination", "<HiddenPagination"
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("业务数据表格缺分页", result.stderr)

    def test_create_entry_table_with_small_mock_without_pagination_is_rejected(self):
        # 新增入口 ↔ 分页对账：页面有 create 类 action 时，mock_rows 登记小数字不能规避分页与 ≥25 种子
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        for pg in plan["pages"]:
            if pg["id"] == "p-02":
                pg["mock_rows"] = 8
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        self.patch_page(
            target, "src/pages/p-02-customer-list/features/customer-table.tsx", "<Pagination", "<HiddenPagination"
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("业务数据表格缺分页（页面有新增入口", result.stderr)
        self.assertIn("mock_rows=8 < 25", result.stderr)

    def test_uniform_action_column_is_rejected(self):
        # 操作列跨页同质性对账：全站动作文案统一为占位词即拦
        target = self.init_stack("react-antd")
        self.patch_page(target, "src/pages/p-02-customer-list/features/customer-table.tsx", ">编辑</Button>", ">打开详情</Button>")
        self.patch_page(target, "src/pages/p-02-customer-list/features/customer-table.tsx", ">详情</Button>", ">打开详情</Button>")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("操作列文案全站同质", result.stderr)

    def test_return_control_inside_tabs_is_rejected(self):
        # 嵌入式详情返回控件落位：返回文案出现在 Tabs 起始窗口内即拦
        target = self.init_stack("react-antd")
        self.patch_page(target, "src/pages/p-04-entity-workbench/features/entity-editor.tsx", "<Tabs", '<Tabs data-probe="返回列表"')
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("返回控件禁止混入 Tabs 区", result.stderr)

    def test_table_header_descriptive_title_is_rejected(self):
        # 卡头禁描述性标题：卡头内非按钮文本以「列表/清单」结尾即拦（判据正源: composition-layer.md 工具栏段）
        target = self.init_stack("react-antd")
        self.patch_page(
            target,
            "src/pages/p-02-customer-list/features/customer-table.tsx",
            '<div className="jjui-table-header">',
            '<div className="jjui-table-header"><span className="jjui-x">对象类型列表</span>'
            '<Button type="primary">同步清单</Button>',
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("表格卡头禁描述性标题", result.stderr)
        self.assertIn("对象类型列表", result.stderr)
        # Button 内文字不触发本条（卡头按钮文案可含列表字样，如「导出清单」）
        self.assertNotIn("同步清单", result.stderr)

    def test_table_header_descriptive_title_vue_is_rejected(self):
        # vue 栈同判据：el-button 剥离后查非按钮文本
        target = self.init_stack("vue3-element-plus")
        self.patch_page(
            target,
            "src/pages/p-02-customer-list/features/customer-table.vue",
            '<div class="jjui-table-header">',
            '<div class="jjui-table-header"><span class="jjui-x">对象类型清单</span>'
            '<el-button type="primary">同步列表</el-button>',
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("表格卡头禁描述性标题", result.stderr)
        self.assertIn("对象类型清单", result.stderr)
        self.assertNotIn("同步列表", result.stderr)

    def test_unregistered_menu_mount_is_rejected(self):
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        plan["pages"][1]["expected_entry"] = ["unreachable"]
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("计划外菜单/壳层入口挂载", result.stderr)

    def test_disguised_detail_menu_page_is_rejected(self):
        target = self.init_stack("react-antd")
        page_a = target / "src/pages/p-02-customer-list/index.tsx"
        page_a.write_text(page_a.read_text(encoding="utf-8").replace(
            '<main data-jjui-page="p-02">',
            '<main data-jjui-page="p-02"><a to="/dashboard">回总览</a>'
        ), encoding="utf-8")
        page_b = target / "src/pages/p-01-dashboard/index.tsx"
        page_b.write_text(page_b.read_text(encoding="utf-8").replace(
            "export default function Dashboard() {",
            "export default function Dashboard() {\n  const fixed = customers[0];"
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("疑似详情页伪装成菜单页", result.stderr)

    def test_duplicate_action_anchor_is_rejected(self):
        target = self.init_stack("react-antd")
        self.patch_page(
            target,
            "src/pages/p-02-customer-list/features/customer-table.tsx",
            'data-jjui-action="p-02.table-refresh"',
            'data-jjui-action="p-02.create"',
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("操作锚点重复", result.stderr)

    def test_single_table_card_title_is_rejected(self):
        target = self.init_stack("react-antd")
        self.patch_page(
            target,
            "src/pages/p-02-customer-list/features/customer-table.tsx",
            '<SectionCard>\n          <div className="jjui-table-header">',
            '<SectionCard title="客户清单">\n          <div className="jjui-table-header">',
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("列表页卡片不起标题", result.stderr)

    def test_shell_without_scroll_isolation_is_rejected(self):
        target = self.init_stack("react-antd")
        css_path = target / "src/styles/admin.css"
        css_path.write_text(css_path.read_text(encoding="utf-8").replace("overflow-y: auto", "overflow-y: visible"), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("样式基线缺壳层滚动隔离特征", result.stderr)

    def test_shadow_outside_visual_containers_is_rejected(self):
        target = self.init_stack("react-antd")
        css_path = target / "src/styles/admin.css"
        css = css_path.read_text(encoding="utf-8")
        css_path.write_text(css + "\n.jjui-footer {\n  box-shadow: var(--shadow-card);\n}\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("样式基线阴影越权", result.stderr)

    def test_decorated_toolbar_is_rejected(self):
        target = self.init_stack("react-antd")
        css_path = target / "src/styles/admin.css"
        css_path.write_text(css_path.read_text(encoding="utf-8").replace(
            ".jjui-toolbar {", ".jjui-toolbar {\n  padding: var(--space-3);"
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("工具条混入视觉容器样式", result.stderr)

    def test_nested_card_in_page_is_rejected(self):
        target = self.init_stack("react-antd")
        self.patch_page(
            target,
            "src/pages/p-02-customer-list/features/customer-table.tsx",
            '<div data-jjui-data="p-02.customer-rows">',
            '<div data-jjui-data="p-02.customer-rows"><Card>x</Card>',
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("页面内嵌套组件库卡片", result.stderr)

    def test_shell_without_breadcrumb_is_rejected(self):
        target = self.init_stack("react-antd")
        layout = target / "src/layouts/AdminLayout.tsx"
        layout.write_text(layout.read_text(encoding="utf-8").replace("<Breadcrumb", "<Nav"), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("壳层顶栏缺面包屑", result.stderr)

    def test_brand_back_in_header_is_rejected(self):
        target = self.init_stack("react-antd")
        layout = target / "src/layouts/AdminLayout.tsx"
        layout.write_text(layout.read_text(encoding="utf-8").replace(
            '<header className="admin-header">', '<header className="admin-header">\n          <span className="admin-header__brand">demo</span>'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("品牌区违规回顶栏", result.stderr)

    def test_forbidden_dependency_is_rejected(self):
        target = self.init_stack("react-antd")
        package_path = target / "package.json"
        package = json.loads(package_path.read_text(encoding="utf-8"))
        package["dependencies"]["axios"] = "^1.7.9"
        package_path.write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("默认禁止依赖", result.stderr)

    def test_react_pagination_item_without_border_baseline_is_rejected(self):
        target = self.init_stack("react-antd")
        css_path = target / "src/styles/admin.css"
        css_path.write_text(css_path.read_text(encoding="utf-8").replace(
            ".jjui-pagination .ant-pagination-item {\n  border: 1px solid var(--color-border);\n  background: var(--color-surface);\n}\n\n", ""
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("样式基线缺页码边框", result.stderr)

    def test_list_table_header_without_left_wing_is_rejected(self):
        target = self.init_stack("react-antd")
        self.patch_page(
            target,
            "src/pages/p-02-customer-list/features/customer-table.tsx",
            '''              <Input
                data-jjui-action="p-02.quick-search"
                prefix={<SearchOutlined />}
                placeholder="快捷搜索客户"
                style={{ width: "var(--control-width)" }}
                value={quickSearch}
                onChange={(event) => {
                  setQuickSearch(event.target.value);
                  setCurrent(1);
                }}
                allowClear
              />
''',
            "",
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("列表页表格卡头缺左翼快捷搜索", result.stderr)

    def test_table_header_baseline_without_space_between_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        css_path = target / "src/styles/admin.css"
        css_path.write_text(css_path.read_text(encoding="utf-8").replace(
            ".jjui-table-header {\n  display: flex;\n  align-items: center;\n  justify-content: space-between;",
            ".jjui-table-header {\n  display: flex;\n  align-items: center;"
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("样式基线表格卡头未两翼分布", result.stderr)

    def test_form_item_without_label_is_rejected(self):
        target = self.init_stack("react-antd")
        self.patch_page(
            target,
            "src/pages/p-02-customer-list/features/customer-table.tsx",
            '<div data-jjui-data="p-02.customer-rows">',
            '<div data-jjui-data="p-02.customer-rows"><Form.Item><Input placeholder="类型标识" /></Form.Item>',
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("表单项缺 label", result.stderr)

    def test_vue_form_item_without_label_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        self.patch_page(
            target,
            "src/pages/p-02-customer-list/features/customer-table.vue",
            '<div v-loading="loading" data-jjui-data="p-02.customer-rows">',
            '<div v-loading="loading" data-jjui-data="p-02.customer-rows"><el-form-item><el-input placeholder="类型标识" /></el-form-item>',
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("表单项缺 label", result.stderr)

    def test_dead_button_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-01-dashboard/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<main data-jjui-page="p-01">',
            '<main data-jjui-page="p-01">\n      <Button data-jjui-action="p-01.dead-op">注册模型</Button>'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("操作无可演示反馈", result.stderr)

    def test_status_tag_with_sentence_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-01-dashboard/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<main data-jjui-page="p-01">',
            '<main data-jjui-page="p-01"><StatusTag label="配置 DB 单源（LLM-002），保存即热加载" tone="info" />'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("StatusTag 混入说明句", result.stderr)

    def test_settings_table_without_two_wing_is_rejected(self):
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        for pg in plan["pages"]:
            if pg["id"] == "p-02":
                pg["composition"]["recipe"] = "settings"
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        self.patch_page(
            target,
            "src/pages/p-02-customer-list/features/customer-table.tsx",
            '<div className="jjui-table-header">',
            '<div className="jjui-table-head">',
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("业务表格须用表格卡头两翼结构", result.stderr)

    def test_master_title_font_size_drift_is_rejected(self):
        target = self.init_stack("react-antd")
        css_path = target / "src/styles/admin.css"
        css_path.write_text(css_path.read_text(encoding="utf-8").replace(
            ".jjui-master__title {\n  margin: 0;\n  color: var(--color-text-primary);\n  font-size: var(--font-size-section);",
            ".jjui-master__title {\n  margin: 0;\n  color: var(--color-text-primary);\n  font-size: var(--font-size-body);"
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("样式基线门牌字号漂移", result.stderr)

    def test_master_body_baseline_missing_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        css_path = target / "src/styles/admin.css"
        css_path.write_text(css_path.read_text(encoding="utf-8").replace(
            ".jjui-master__body {\n  display: flex;\n  align-items: stretch;\n  flex: 1;\n  min-width: 0;\n}\n\n", ""
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("样式基线缺主从分栏容器", result.stderr)

    def test_stale_skill_version_is_rejected(self):
        target = self.init_stack("react-antd")
        manifest_path = target / ".jjui/manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["jjui_version"] = "0.9.0"
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("原型基线与技能版本脱节", result.stderr)

    def test_table_config_ops_outside_header_is_rejected(self):
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        for pg in plan["pages"]:
            if pg["id"] == "p-02":
                pg["composition"]["recipe"] = "workspace"
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        self.patch_page(
            target,
            "src/pages/p-02-customer-list/features/customer-table.tsx",
            '<div className="jjui-table-header">',
            '<div className="jjui-table-head">',
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("表级配置操作（刷新/列设置）漂在表格卡外", result.stderr)

    def test_vue_double_shell_mount_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        app = target / "src/App.vue"
        app.write_text(
            '<template>\n  <AdminLayout />\n</template>\n\n<script setup lang="ts">\n'
            'import AdminLayout from "./layouts/AdminLayout.vue";\n</script>\n',
            encoding="utf-8",
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("壳层布局重复挂载", result.stderr)

    def test_list_without_table_header_is_rejected(self):
        target = self.init_stack("react-antd")
        self.patch_page(
            target,
            "src/pages/p-02-customer-list/features/customer-table.tsx",
            '<div className="jjui-table-header">',
            '<div className="jjui-table-head">',
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("列表页缺表格卡头两翼结构", result.stderr)

    def test_pagination_meta_without_secondary_color_is_rejected(self):
        target = self.init_stack("react-antd")
        css_path = target / "src/styles/admin.css"
        css_path.write_text(css_path.read_text(encoding="utf-8").replace(
            ".jjui-pagination__meta {\n  color: var(--color-text-secondary);\n}", ""
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("样式基线分页元信息未用次要色", result.stderr)

    def test_vue_pagination_without_border_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        css_path = target / "src/styles/admin.css"
        css_path.write_text(css_path.read_text(encoding="utf-8").replace(
            "  border: 1px solid var(--color-border);\n  border-radius: var(--radius-sm);\n", ""
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("样式基线缺分页翻页边框", result.stderr)

    def test_react_pagination_without_item_render_is_rejected(self):
        target = self.init_stack("react-antd")
        plan_path = target / ".jjui/page-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        for pg in plan["pages"]:
            if pg["id"] == "p-02":
                pg["mock_rows"] = 30
        plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        self.patch_page(target, "src/pages/p-02-customer-list/features/customer-table.tsx", "itemRender", "renderItem")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("antd 分页须用 itemRender", result.stderr)

    def test_canvas_without_canvas_anchor_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-03-canvas-editor/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            'data-jjui-canvas="p-03.canvas-stage"', 'data-jjui-stage="p-03.canvas-stage"'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("编辑器型页面缺容器锚点 data-jjui-canvas", result.stderr)

    def test_canvas_card_stacking_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-03-canvas-editor/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<div className="jjui-canvas__body">',
            '<div className="jjui-canvas__body"><SectionCard title="实体列表"></SectionCard>'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("编辑器型页面禁卡片堆叠", result.stderr)

    def test_canvas_node_without_interaction_signal_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-03-canvas-editor/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<main data-jjui-page="p-03">',
            '<main data-jjui-page="p-03"><div data-jjui-node="ghost-node"></div>'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("画布/树对象无交互信号", result.stderr)

    def test_canvas_missing_graph_dependency_is_rejected(self):
        target = self.init_stack("react-antd")
        package_path = target / "package.json"
        package = json.loads(package_path.read_text(encoding="utf-8"))
        del package["dependencies"]["@xyflow/react"]
        package_path.write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("canvas 页缺图视图库依赖", result.stderr)

    def test_vue_canvas_without_canvas_anchor_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-03-canvas-editor/index.vue"
        page.write_text(page.read_text(encoding="utf-8").replace(
            'data-jjui-canvas="p-03.canvas-stage"', 'data-jjui-stage="p-03.canvas-stage"'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("编辑器型页面缺容器锚点 data-jjui-canvas", result.stderr)

    def test_ide_without_tabs_is_rejected(self):
        target = self.init_stack("react-antd")
        self.patch_page(target, "src/pages/p-04-entity-workbench/features/entity-editor.tsx", "<Tabs", "<Panels")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("ide 页编辑器须用 Tabs", result.stderr)

    def test_ide_card_stacking_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-04-entity-workbench/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<div className="jjui-ide__body">',
            '<div className="jjui-ide__body"><SectionCard title="大纲"></SectionCard>'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("编辑器型页面禁卡片堆叠", result.stderr)

    def test_ide_without_tree_anchor_is_rejected(self):
        target = self.init_stack("react-antd")
        self.patch_page(
            target, "src/pages/p-04-entity-workbench/features/outline-tree.tsx", "data-jjui-node={String(node.key)}", "data-node={String(node.key)}"
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("ide 页大纲树项锚点缺失", result.stderr)

    def test_ide_without_container_anchor_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-04-entity-workbench/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            'data-jjui-ide="p-04.workbench"', 'data-jjui-shell="p-04.workbench"'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("编辑器型页面缺容器锚点", result.stderr)

    def test_vue_ide_without_container_anchor_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-04-entity-workbench/index.vue"
        page.write_text(page.read_text(encoding="utf-8").replace(
            'data-jjui-ide="p-04.workbench"', 'data-jjui-shell="p-04.workbench"'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("编辑器型页面缺容器锚点", result.stderr)

    def test_section_card_overflow_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<main data-jjui-page="p-02">',
            '<main data-jjui-page="p-02"><SectionCard>x</SectionCard><SectionCard>y</SectionCard>'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("并列区块超限", result.stderr)

    def test_section_card_overflow_with_tabs_passes(self):
        target = self.init_stack("react-antd")
        # 入口禁内联 Tabs（封闭交互单元落 features/），Tabs 放进 Feature 即可豁免并列区块超限
        self.patch_page(
            target,
            "src/pages/p-02-customer-list/features/customer-table.tsx",
            '<section data-jjui-region="p-02.filter">',
            '<Tabs items={[]} />\n      <section data-jjui-region="p-02.filter">',
        )
        page = target / "src/pages/p-02-customer-list/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<main data-jjui-page="p-02">',
            '<main data-jjui-page="p-02"><SectionCard>x</SectionCard><SectionCard>y</SectionCard>'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PROTOTYPE CHECK PASS", result.stdout)

    def test_vue_section_card_overflow_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-02-customer-list/index.vue"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<main data-jjui-page="p-02">',
            '<main data-jjui-page="p-02"><SectionCard /><SectionCard />'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("并列区块超限", result.stderr)

    def test_status_tag_template_label_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<main data-jjui-page="p-02">',
            '<main data-jjui-page="p-02"><StatusTag label={`当前上下文：全局`} tone="info" />'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("StatusTag label 须为字面量状态词", result.stderr)

    def test_status_tag_count_label_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<main data-jjui-page="p-02">',
            '<main data-jjui-page="p-02"><StatusTag label="共 7 条 · 显示 7 条" tone="neutral" />'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("StatusTag label 禁计数说明", result.stderr)

    def test_vue_status_tag_ternary_label_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-02-customer-list/features/customer-table.vue"
        page.write_text(page.read_text(encoding="utf-8").replace(
            ':label="statusLabel(row.status)"', ":label=\"row.status === 'active' ? '启用' : '停用'\""
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("StatusTag label 须为字面量状态词", result.stderr)

    def test_narrow_column_descriptions_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-04-entity-workbench/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<main data-jjui-page="p-04">',
            '<main data-jjui-page="p-04"><Descriptions column={3} items={[]} />'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("窄栏禁横排描述列表", result.stderr)

    def test_statusbar_without_affix_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-04-entity-workbench/index.tsx"
        text = page.read_text(encoding="utf-8").replace("<Affix", "<div").replace("</Affix>", "</div>")
        page.write_text(text, encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("底部状态栏须用组件库钉住组件承载", result.stderr)

    def test_vue_statusbar_without_affix_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-04-entity-workbench/index.vue"
        text = page.read_text(encoding="utf-8").replace("<el-affix", "<div").replace("</el-affix>", "</div>")
        page.write_text(text, encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("底部状态栏须用组件库钉住组件承载", result.stderr)

    def test_pageheader_with_controls_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/index.tsx"
        text = page.read_text(encoding="utf-8").replace(
            '<PageHeader\n        title="客户列表"',
            '<PageHeader\n        extra={<Button>链视图</Button>}\n        title="客户列表"'
        )
        page.write_text(text, encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("PageHeader 只承载标题、描述与返回导航", result.stderr)

    def test_filter_form_without_inline_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/features/customer-table.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<Form layout="inline">', "<Form>"
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn('查询卡字段须用 Form layout="inline" 承载', result.stderr)

    def test_form_vertical_layout_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/features/customer-table.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<Form layout="inline">', '<Form layout="vertical">'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("label 禁止竖排", result.stderr)

    def test_vue_filter_form_without_inline_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-02-customer-list/features/customer-table.vue"
        page.write_text(page.read_text(encoding="utf-8").replace(
            ':inline="true"', ""
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("查询卡字段须用 Form layout", result.stderr)

    def test_pageheader_titleline_missing_is_rejected(self):
        target = self.init_stack("react-antd")
        css_path = target / "src/styles/admin.css"
        css_path.write_text(css_path.read_text(encoding="utf-8").replace(
            ".jjui-page-header__titleline {", ".jjui-page-header__titleline-x {"
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("样式基线缺门牌 titleline 段", result.stderr)

    def test_filter_width_hardcoded_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/features/customer-table.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            'style={{ width: "var(--control-width)" }}', 'style={{ width: 130 }}'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("查询卡控件宽度禁止写死像素", result.stderr)

    def test_modal_form_labelcol_flex_none_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/features/customer-form-modal.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<Form form={form} labelAlign="left" labelCol={{ span: 6 }}',
            '<Form form={form} labelAlign="left" labelCol={{ flex: "none" }}'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("表单 labelCol 禁止 flex", result.stderr)

    def test_vue_el_form_without_label_width_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-02-customer-list/features/customer-form-modal.vue"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<el-form ref="formRef" :model="formState" :rules="formRules" label-position="left" label-width="var(--form-label-width)">',
            '<el-form ref="formRef" :model="formState" :rules="formRules" label-position="left">'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("el-form 非 inline 承载须 label-width 定宽", result.stderr)

    def test_toolbar_without_wrap_is_rejected(self):
        target = self.init_stack("react-antd")
        css = target / "src/styles/admin.css"
        css.write_text(css.read_text(encoding="utf-8").replace(
            ".jjui-toolbar {\n  display: flex;\n  align-items: center;\n  flex-wrap: wrap;\n  gap: var(--space-3) var(--space-4);\n}",
            ".jjui-toolbar {\n  display: flex;\n  align-items: center;\n  gap: var(--space-3) var(--space-4);\n}"
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("样式基线工具条缺 flex-wrap: wrap", result.stderr)

    def test_vue_toolbar_actions_without_margin_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        css = target / "src/styles/admin.css"
        css.write_text(css.read_text(encoding="utf-8").replace(
            ".jjui-toolbar__actions {\n  margin-left: auto;\n}", ""
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("样式基线工具条操作区未吸附行尾", result.stderr)

    def test_deprecated_control_width_token_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/features/customer-table.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            'var(--control-width)', 'var(--control-width-select)'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("已合并为 --control-width 单档", result.stderr)

    def test_modal_control_fixed_width_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/features/customer-form-modal.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            'data-jjui-action="p-02.form-status" style={{ width: "100%" }}',
            'data-jjui-action="p-02.form-status" style={{ width: 130 }}'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("弹框表单控件禁止写死像素宽度", result.stderr)

    def test_vue_dialog_control_fixed_width_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-02-customer-list/features/customer-form-modal.vue"
        page.write_text(page.read_text(encoding="utf-8").replace(
            'style="width: 100%" data-jjui-action="p-02.form-status"',
            'style="width: 130px" data-jjui-action="p-02.form-status"'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("弹框表单控件禁止写死像素宽度", result.stderr)

    def test_single_card_with_title_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-01-dashboard/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            "<SectionCard>",
            '<SectionCard title="最近客户">'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("单区块页卡不起标题与描述", result.stderr)

    def test_vue_single_card_with_description_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-01-dashboard/index.vue"
        page.write_text(page.read_text(encoding="utf-8").replace(
            "<SectionCard>",
            '<SectionCard description="按最近创建时间展示客户样例。">'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("单区块页卡不起标题与描述", result.stderr)

    def test_op_column_solid_button_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/features/customer-table.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<Button type="link" size="small" data-jjui-action="p-02.row-edit"',
            '<Button type="primary" size="small" data-jjui-action="p-02.row-edit"'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("操作列动作一律文字链", result.stderr)

    def test_vue_op_column_solid_button_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-02-customer-list/features/customer-table.vue"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<el-button link type="primary" size="small" data-jjui-action="p-02.row-edit"',
            '<el-button type="primary" size="small" data-jjui-action="p-02.row-edit"'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("操作列动作一律文字链", result.stderr)

    def test_op_column_disabled_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/features/customer-table.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<Button type="link" size="small" data-jjui-action="p-02.row-detail"',
            '<Button type="link" size="small" disabled data-jjui-action="p-02.row-detail"'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("操作列当前行不可执行的动作不渲染", result.stderr)

    def test_vue_op_column_disabled_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-02-customer-list/features/customer-table.vue"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<el-button link type="primary" size="small" data-jjui-action="p-02.row-detail"',
            '<el-button link type="primary" size="small" disabled data-jjui-action="p-02.row-detail"'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("操作列当前行不可执行的动作不渲染", result.stderr)

    def test_descriptions_with_controls_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/features/customer-detail-drawer.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<Descriptions',
            '<Descriptions items={[{ key: "n", label: "名称", children: <Input /> }]}'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("描述列表是只读呈现", result.stderr)

    def test_vue_descriptions_with_controls_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-02-customer-list/features/customer-detail-drawer.vue"
        page.write_text(page.read_text(encoding="utf-8").replace(
            "<el-descriptions",
            '<el-descriptions><el-descriptions-item label="名称"><el-input v-model="draftKeyword" /></el-descriptions-item>'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("描述列表是只读呈现", result.stderr)

    def test_ide_page_vertical_form_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-04-entity-workbench/features/entity-editor.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<Form\n                key={selectedKey}',
            '<Form layout="vertical"\n                key={selectedKey}'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("label 禁止竖排", result.stderr)

    def test_tree_inner_maxheight_is_rejected(self):
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-04-entity-workbench/features/outline-tree.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<aside className="jjui-ide__tree" data-jjui-region="p-04.tree">',
            '<aside className="jjui-ide__tree" data-jjui-region="p-04.tree"><div style={{ maxHeight: 520, overflowY: "auto" }}>'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("禁止 max-height/height 写死像素", result.stderr)

    def test_vue_tree_inner_maxheight_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-04-entity-workbench/features/outline-tree.vue"
        page.write_text(page.read_text(encoding="utf-8").replace(
            '<aside class="jjui-ide__tree" data-jjui-region="p-04.tree">',
            '<aside class="jjui-ide__tree" data-jjui-region="p-04.tree"><div style="max-height: 520px; overflow-y: auto;">'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("禁止 max-height/height 写死像素", result.stderr)

    def test_vue_pageheader_with_controls_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-02-customer-list/index.vue"
        text = page.read_text(encoding="utf-8").replace(
            "<PageHeader", '<PageHeader><template #actions><el-button>链视图</el-button></template>'
        )
        page.write_text(text, encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("PageHeader 只承载标题、描述与返回导航", result.stderr)

    def test_editor_panel_missing_bottom_reserve_is_rejected(self):
        target = self.init_stack("react-antd")
        css_path = target / "src/styles/admin.css"
        css_path.write_text(css_path.read_text(encoding="utf-8").replace(
            ".jjui-ide__editor {\n  flex: 1;\n  min-width: 0;\n  padding: var(--space-4) var(--space-6);\n  padding-bottom: var(--space-8);",
            ".jjui-ide__editor {\n  flex: 1;\n  min-width: 0;\n  padding: var(--space-4) var(--space-6);"
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("缺底部预留 padding-bottom", result.stderr)

    # ── 页面内分层机判（判据正源: references/page-splitting.md）──

    def test_entry_inline_unit_is_rejected(self):
        # 机判①：入口文件禁内联 Drawer/Modal/Tabs 实现体，封闭交互单元落 features/
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-02-customer-list/index.tsx"
        page.write_text(page.read_text(encoding="utf-8").replace(
            "<CustomerTable",
            '<Modal title="临时弹框" open={false}></Modal><CustomerTable'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("页面入口文件禁内联 Drawer/Modal/Tabs 实现体", result.stderr)

    def test_vue_entry_inline_unit_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-02-customer-list/index.vue"
        page.write_text(page.read_text(encoding="utf-8").replace(
            "<CustomerTable",
            '<el-dialog title="临时弹框"></el-dialog><CustomerTable'
        ), encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("页面入口文件禁内联 Drawer/Modal/Tabs 实现体", result.stderr)

    def test_mock_import_is_rejected(self):
        # 机判②：禁止 import src/mock/*——数据契约收敛为 src/services 服务层
        target = self.init_stack("react-antd")
        page = target / "src/pages/p-01-dashboard/index.tsx"
        page.write_text(
            'import { legacyRows } from "../../mock/legacy";\n'
            + page.read_text(encoding="utf-8"),
            encoding="utf-8",
        )
        (target / "src/mock").mkdir(exist_ok=True)
        (target / "src/mock/legacy.ts").write_text(
            "export const legacyRows: unknown[] = [];\n", encoding="utf-8"
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("禁止 import src/mock/*", result.stderr)

    def test_vue_mock_import_is_rejected(self):
        target = self.init_stack("vue3-element-plus")
        page = target / "src/pages/p-01-dashboard/index.vue"
        page.write_text(
            '<script setup lang="ts">\nimport { legacyRows } from "../../mock/legacy";\n</script>\n'
            + page.read_text(encoding="utf-8"),
            encoding="utf-8",
        )
        (target / "src/mock").mkdir(exist_ok=True)
        (target / "src/mock/legacy.ts").write_text(
            "export const legacyRows: unknown[] = [];\n", encoding="utf-8"
        )
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("禁止 import src/mock/*", result.stderr)

    def test_features_registered_file_missing_is_rejected(self):
        # 机判③：page-plan features 登记与 features/ 目录双向对账——登记文件缺失报错
        target = self.init_stack("react-antd")
        (target / "src/pages/p-02-customer-list/features/customer-table.tsx").unlink()
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("features 登记文件缺失", result.stderr)

    def test_features_unregistered_file_is_rejected(self):
        # 双向对账反向：features/ 目录存在未登记文件也报错
        target = self.init_stack("vue3-element-plus")
        extra = target / "src/pages/p-02-customer-list/features/extra-panel.vue"
        extra.write_text("<template><span>未登记浮层</span></template>\n", encoding="utf-8")
        result = self.run_check(target)
        self.assertEqual(result.returncode, 1)
        self.assertIn("features/ 目录存在未登记文件", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
