import { useEffect, useState } from "react";
import { Affix, Button, Space, message } from "antd";
import { PageHeader, StatusTag } from "../../components/admin";
import OutlineTree from "./features/outline-tree";
import EntityEditor from "./features/entity-editor";
import InsightPanel from "./features/insight-panel";
import StatusDialogs from "./features/status-dialogs";

// 编辑器工作台页（判据正源: composition-layer.md 编辑器型页面段；语法: react-antd.md）
// 入口只做装配（判据正源: references/page-splitting.md）：三栏 Feature（大纲树/Tabs 编辑器/伴随面板）
// + 底部状态栏；共享状态（选中项、大纲、发布态）由入口编排下发
// 三区一体：大纲树 + Tabs 编辑器 + 伴随面板，底部常驻状态栏；树项选中驱动编辑器与伴随面板

type OutlineItem = {
  key: string;
  title: string;
  group: "对象" | "规则";
  description: string;
};

const OUTLINE: OutlineItem[] = [
  { key: "customer", title: "客户", group: "对象", description: "购买商品的个人或组织。" },
  { key: "order", title: "订单", group: "对象", description: "一次购买的完整记录。" },
  { key: "product", title: "商品", group: "对象", description: "订单中售卖的最小单元。" },
  { key: "rule-check", title: "下单校验", group: "规则", description: "校验订单库存与收货地址。" },
  { key: "rule-score", title: "积分计算", group: "规则", description: "按订单金额累计积分。" }
];

const BINDINGS = [
  { source: "customer", target: "订单", note: "客户可发起多笔订单" },
  { source: "order", target: "商品", note: "订单包含多个商品明细" },
  { source: "rule-check", target: "订单", note: "下单前校验订单合法性" }
];

const ISSUES = [
  { target: "product", text: "「商品」缺少唯一标识字段" },
  { target: "rule-score", text: "「积分计算」未绑定触发时机" }
];

export default function EntityWorkbench() {
  const [outline, setOutline] = useState(OUTLINE);
  const [selectedKey, setSelectedKey] = useState("customer");
  const selected = outline.find((item) => item.key === selectedKey);
  const selectedBindings = BINDINGS.filter((b) => b.source === selectedKey);
  // 发布/校验/历史：真实交互流（判据: composition-layer.md 页面段操作保真 + 编辑器型页面段底部状态栏）
  const [published, setPublished] = useState(false);
  const [publishOpen, setPublishOpen] = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);

  const runCheck = () => {
    message.info(`校验完成：${ISSUES.length} 项待处理`);
  };
  const submitEdit = (values: { title: string; description: string }) => {
    setOutline(outline.map((item) => (item.key === selectedKey ? { ...item, ...values } : item)));
    message.success(`已保存「${values.title}」（mock 数据）`);
  };
  // StatusTag label 须为字面量状态词或纯变量（判据: composition-layer.md 状态段）
  const statusLabel = published ? "已发布" : "草稿";
  // 状态栏钉住目标：壳层内容滚动容器（判据: composition-layer.md 编辑器型页面段底部状态栏）
  const [scrollEl, setScrollEl] = useState<HTMLElement | null>(null);
  useEffect(() => {
    setScrollEl(document.querySelector(".admin-layout__content"));
  }, []);

  return (
    <main data-jjui-page="p-04">
      <PageHeader
        title="实体工作台"
        description="在结构化工作台中维护对象与规则，选中大纲项后编辑并查看校验。"
      />

      <div className="jjui-ide" data-jjui-ide="p-04.workbench">
        <div className="jjui-ide__body">
          <OutlineTree items={outline} selectedKey={selectedKey} onSelect={setSelectedKey} />
          <EntityEditor
            selectedKey={selectedKey}
            selected={selected}
            bindings={selectedBindings}
            onSave={submitEdit}
          />
          <InsightPanel selected={selected} issues={ISSUES} />
        </div>

        <Affix offsetBottom={0} target={() => scrollEl ?? undefined}>
          <footer className="jjui-editor-statusbar" data-jjui-region="p-04.statusbar">
            <Space size={12}>
              <StatusTag label={statusLabel} tone={published ? "success" : "info"} />
              <span className="jjui-pagination__meta">基线 v2.0 · {ISSUES.length} 项待处理校验</span>
            </Space>
            <Space size={8}>
              <Button size="small" data-jjui-action="p-04.check" onClick={runCheck}>校验</Button>
              <Button size="small" data-jjui-action="p-04.history" onClick={() => setHistoryOpen(true)}>版本历史</Button>
              <Button type="primary" size="small" data-jjui-action="p-04.publish" onClick={() => setPublishOpen(true)}>发布</Button>
            </Space>
          </footer>
        </Affix>
      </div>

      <StatusDialogs
        publishOpen={publishOpen}
        historyOpen={historyOpen}
        onPublish={() => {
          setPublished(true);
          setPublishOpen(false);
          message.success("工作台草稿已发布（mock 数据）");
        }}
        onPublishCancel={() => setPublishOpen(false)}
        onHistoryClose={() => setHistoryOpen(false)}
      />
    </main>
  );
}
