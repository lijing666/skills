import { useEffect, useState } from "react";
import { Affix, Button, Descriptions, Drawer, Form, Input, Modal, Space, Tabs, Tree, message } from "antd";
import { PageHeader, StatusTag } from "../../components/admin";

// 编辑器工作台页（判据正源: composition-layer.md 编辑器型页面段；语法: react-antd.md）
// 三栏一体：大纲树 + Tabs 编辑器 + 伴随面板，底部常驻状态栏；树项选中驱动编辑器与伴随面板

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

const VERSIONS = [
  { version: "v2.0", note: "当前草稿基线" },
  { version: "v1.9", note: "新增下单校验规则" },
  { version: "v1.8", note: "调整客户字段说明" }
];

export default function EntityWorkbench() {
  const [outline, setOutline] = useState(OUTLINE);
  const [selectedKey, setSelectedKey] = useState("customer");
  const selected = outline.find((item) => item.key === selectedKey);
  const selectedBindings = BINDINGS.filter((b) => b.source === selectedKey);
  const treeData = [
    {
      title: "对象",
      key: "group-object",
      children: outline.filter((item) => item.group === "对象").map(({ key, title }) => ({ key, title }))
    },
    {
      title: "规则",
      key: "group-rule",
      children: outline.filter((item) => item.group === "规则").map(({ key, title }) => ({ key, title }))
    }
  ];
  // 发布/校验/历史：真实交互流（判据: composition-layer.md 页面段操作保真 + 编辑器型页面段底部状态栏）
  const [published, setPublished] = useState(false);
  const [publishOpen, setPublishOpen] = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);
  // 编辑器表单：key 随选中重建 + initialValues，保存写回 mock（判据: composition-layer.md 表单段）
  const [form] = Form.useForm();

  const selectNode = (key: string) => {
    setSelectedKey(key);
  };
  const runCheck = () => {
    message.info(`校验完成：${ISSUES.length} 项待处理`);
  };
  const submitEdit = () => {
    form.validateFields().then((values) => {
      setOutline(outline.map((item) => (item.key === selectedKey ? { ...item, ...values } : item)));
      message.success(`已保存「${values.title}」（mock 数据）`);
    });
  };
  // StatusTag label 须为字面量状态词或纯变量（判据: composition-layer.md 状态段）
  const statusLabel = published ? "已发布" : "草稿";
  // 状态栏钉住目标：壳层内容滚动容器（判据: composition-layer.md 编辑器型页面段底部状态栏）
  const [scrollEl, setScrollEl] = useState<HTMLElement | null>(null);
  useEffect(() => {
    setScrollEl(document.querySelector(".admin-layout__content"));
  }, []);
  const publish = () => {
    setPublished(true);
    setPublishOpen(false);
    message.success("工作台草稿已发布（mock 数据）");
  };

  return (
    <main data-jjui-page="p-04">
      <PageHeader
        title="实体工作台"
        description="在结构化工作台中维护对象与规则，选中大纲项后编辑并查看校验。"
      />

      <div className="jjui-ide" data-jjui-ide="p-04.workbench">
        <div className="jjui-ide__body">
          <aside className="jjui-ide__tree" data-jjui-region="p-04.tree">
            <Tree
              treeData={treeData}
              blockNode
              defaultExpandAll
              selectedKeys={[selectedKey]}
              titleRender={(node: { key: unknown; title?: string; children?: unknown[] }) =>
                node.children ? (
                  <span>{node.title}</span>
                ) : (
                  <span
                    data-jjui-node={String(node.key)}
                    className={`jjui-ide__tree-item${node.key === selectedKey ? " jjui-ide__tree-item--selected" : ""}`}
                    onClick={() => selectNode(String(node.key))}
                  >
                    {node.title}
                  </span>
                )
              }
            />
          </aside>

          <section className="jjui-ide__editor" data-jjui-region="p-04.editor">
            <Tabs
              items={[
                {
                  key: "base",
                  label: "基本信息",
                  children: (
                    <Form
                      key={selectedKey}
                      form={form}
                      labelAlign="left"
                      labelCol={{ span: 6 }}
                      initialValues={{ title: selected?.title, description: selected?.description }}
                    >
                      <Form.Item label="名称" name="title" rules={[{ required: true, message: "请输入名称" }]}>
                        <Input data-jjui-action="p-04.form-title" />
                      </Form.Item>
                      <Form.Item label="说明" name="description" rules={[{ required: true, message: "请输入说明" }]}>
                        <Input.TextArea data-jjui-action="p-04.form-description" rows={3} />
                      </Form.Item>
                      <Button type="primary" data-jjui-action="p-04.save" onClick={submitEdit}>保存</Button>
                    </Form>
                  )
                },
                {
                  key: "binding",
                  label: "关联设置",
                  children: selectedBindings.length ? (
                    <Descriptions
                      column={1}
                      size="small"
                      bordered
                      items={selectedBindings.map((b) => ({ key: b.target, label: b.target, children: b.note }))}
                    />
                  ) : (
                    <p className="jjui-section__description">未配置关联。</p>
                  )
                }
              ]}
            />
          </section>

          <aside className="jjui-editor-panel" data-jjui-region="p-04.panel">
            <div className="jjui-section__title">{selected?.title}</div>
            <p className="jjui-section__description">{selected?.description}</p>
            <div className="jjui-section__subtitle">校验</div>
            {ISSUES.map((issue) => (
              <p key={issue.text} className="jjui-section__description">{issue.text}</p>
            ))}
            <div className="jjui-section__subtitle">提示</div>
            <p className="jjui-section__description">修改后需通过校验才可发布。</p>
          </aside>
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

      <Modal
        title="发布工作台"
        open={publishOpen}
        okText="发布"
        cancelText="取消"
        onOk={publish}
        onCancel={() => setPublishOpen(false)}
      >
        <p>发布后当前草稿将固化为基线 v2.1，已发布版本不可直接修改。</p>
      </Modal>

      <Drawer title="版本历史" open={historyOpen} onClose={() => setHistoryOpen(false)}>
        <Space orientation="vertical" style={{ width: "100%" }} size={8}>
          {VERSIONS.map((item) => (
            <div key={item.version} style={{ display: "flex", justifyContent: "space-between" }}>
              <span>{item.version}</span>
              <span className="jjui-pagination__meta">{item.note}</span>
            </div>
          ))}
        </Space>
      </Drawer>
    </main>
  );
}
