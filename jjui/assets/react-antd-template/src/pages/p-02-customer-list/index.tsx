import { useState } from "react";
import { Button, Descriptions, Drawer, Dropdown, Form, Input, Modal, Pagination, Select, Space, Table, message } from "antd";
import { PlusOutlined, ReloadOutlined, SearchOutlined, SettingOutlined } from "@ant-design/icons";
import { PageHeader, SectionCard, StatusTag, Toolbar } from "../../components/admin";
import { customers, type Customer } from "../../mock/customers";

const ALL_COLUMNS = [
  { key: "name", title: "客户名称", dataIndex: "name", width: 200 },
  { key: "status", title: "状态", dataIndex: "status", width: 100 },
  { key: "region", title: "地区", dataIndex: "region", width: 140 },
  { key: "owner", title: "负责人", dataIndex: "owner", width: 140 }
];

export default function CustomerList() {
  const [rows, setRows] = useState(customers);
  const [loading, setLoading] = useState(false);
  const [visibleCols, setVisibleCols] = useState(["name", "status", "region", "owner"]);
  // 高级查询卡：受控提交式——改值不生效，点"查询"应用（判据: composition-layer.md 工具栏段）
  const [draftKeyword, setDraftKeyword] = useState("");
  const [draftStatus, setDraftStatus] = useState<string | undefined>(undefined);
  const [applied, setApplied] = useState({ keyword: "", status: "" });
  // 表格卡头：即时过滤式——输入即过滤，无提交按钮
  const [quickSearch, setQuickSearch] = useState("");
  const [current, setCurrent] = useState(1);
  const [pageSize, setPageSize] = useState(10);
  // 新建/编辑：真实交互流（弹框表单 + 校验 + 写入 mock，判据: composition-layer.md 页面段操作保真）
  const [form] = Form.useForm();
  const [formTitle, setFormTitle] = useState("创建客户");
  const [formOpen, setFormOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  // 详情抽屉（drawer 轻详情，判据: composition-layer.md 详情呈现段）
  const [detail, setDetail] = useState<Customer | null>(null);

  const reload = () => {
    setLoading(true);
    setTimeout(() => setLoading(false), 400);
  };
  const toggleColumn = (key: string) => {
    setVisibleCols((prev) =>
      prev.includes(key) ? (prev.length > 1 ? prev.filter((c) => c !== key) : prev) : [...prev, key]
    );
  };

  const filtered = rows.filter(
    (c) =>
      (!applied.keyword || c.name.includes(applied.keyword)) &&
      (!applied.status || c.status === applied.status) &&
      (!quickSearch || c.id.toLowerCase().includes(quickSearch.toLowerCase()))
  );
  const pagedCustomers = filtered.slice((current - 1) * pageSize, current * pageSize);

  const openCreate = () => {
    setFormTitle("创建客户");
    setEditingId(null);
    form.resetFields();
    setFormOpen(true);
  };
  const openEdit = (record: Customer) => {
    setFormTitle("编辑客户");
    setEditingId(record.id);
    form.setFieldsValue(record);
    setFormOpen(true);
  };
  const submitForm = () => {
    form.validateFields().then((values) => {
      if (editingId) {
        setRows(rows.map((r) => (r.id === editingId ? { ...r, ...values } : r)));
        message.success(`已保存客户 ${values.name}（mock 数据）`);
      } else {
        const next: Customer = { id: `C-${String(rows.length + 1).padStart(3, "0")}`, ...values };
        setRows([next, ...rows]);
        message.success(`已创建客户 ${next.name}（mock 数据）`);
        setCurrent(1);
      }
      setFormOpen(false);
    });
  };

  // StatusTag label 须为字面量状态词或纯变量（判据: composition-layer.md 状态段——拼接表达式会绕过标点检查）
  const detailStatusLabel = detail?.status === "active" ? "启用" : "停用";

  const columns = [
    ...ALL_COLUMNS.filter((c) => visibleCols.includes(c.key)).map((c) => ({
      ...c,
      render: c.key === "status"
        ? (status: string) => {
            const label = status === "active" ? "启用" : "停用";
            return <StatusTag label={label} tone={status === "active" ? "success" : "danger"} />;
          }
        : undefined
    })),
    {
      title: "操作",
      width: 140,
      fixed: "right" as const,
      render: (_: unknown, record: Customer) => (
        <Space size={8}>
          <Button type="link" size="small" data-jjui-action="p-02.row-edit" onClick={() => openEdit(record)}>编辑</Button>
          <Button type="link" size="small" data-jjui-action="p-02.row-detail" onClick={() => setDetail(record)}>详情</Button>
        </Space>
      )
    }
  ];

  return (
    <main data-jjui-page="p-02">
      <PageHeader
        title="客户列表"
        description="按条件检索客户，并维护客户基础信息。"
      />

      <section data-jjui-region="p-02.filter">
        <SectionCard>
          <Toolbar
            filters={
              // 查询卡：Form inline 承载——label 横排左对齐、placeholder 不替代 label、控件宽度走 token
              // （判据正源: composition-layer.md 表格段查询卡布局）
              <Form layout="inline">
                <Form.Item label="客户名称">
                  <Input
                    data-jjui-action="p-02.filter-keyword"
                    placeholder="客户名称"
                    style={{ width: "var(--control-width)" }}
                    value={draftKeyword}
                    onChange={(event) => setDraftKeyword(event.target.value)}
                  />
                </Form.Item>
                <Form.Item label="状态">
                  <Select
                    data-jjui-action="p-02.filter-status"
                    placeholder="全部状态"
                    style={{ width: "var(--control-width)" }}
                    value={draftStatus}
                    allowClear
                    onChange={(value) => setDraftStatus(value)}
                    options={[
                      { label: "启用", value: "active" },
                      { label: "停用", value: "inactive" }
                    ]}
                  />
                </Form.Item>
              </Form>
            }
            actions={
              <>
                <Button type="primary" data-jjui-action="p-02.filter-apply" onClick={() => { setApplied({ keyword: draftKeyword, status: draftStatus ?? "" }); setCurrent(1); }}>查询</Button>
                <Button data-jjui-action="p-02.filter-reset" onClick={() => { setDraftKeyword(""); setDraftStatus(undefined); setApplied({ keyword: "", status: "" }); setCurrent(1); }}>重置</Button>
              </>
            }
          />
        </SectionCard>
      </section>

      <section data-jjui-region="p-02.table" style={{ marginTop: "var(--space-4)" }}>
        <SectionCard>
          <div className="jjui-table-header">
            <Space size={12}>
              <Button type="primary" icon={<PlusOutlined />} data-jjui-action="p-02.create" onClick={openCreate}>
                新建客户
              </Button>
              <Input
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
            </Space>
            <Space size={12}>
              <Button
                size="small"
                icon={<ReloadOutlined />}
                title="刷新"
                data-jjui-action="p-02.table-refresh"
                onClick={reload}
              />
              <Dropdown
                menu={{
                  items: ALL_COLUMNS.map((c) => ({ key: c.key, label: c.title })),
                  selectable: true,
                  multiple: true,
                  selectedKeys: visibleCols,
                  onClick: ({ key }) => toggleColumn(key)
                }}
              >
                <Button size="small" icon={<SettingOutlined />} title="列设置" data-jjui-action="p-02.table-columns" />
              </Dropdown>
            </Space>
          </div>
          <div data-jjui-data="p-02.customer-rows">
            <Table
              rowKey="id"
              columns={columns}
              dataSource={pagedCustomers}
              loading={loading}
              pagination={false}
              scroll={{ x: "max-content" }}
            />
          </div>
          <div className="jjui-pagination">
            <span className="jjui-pagination__meta">共 {filtered.length} 条</span>
            <Space size={4}>
              <span className="jjui-pagination__meta">每页</span>
              <Select
                data-jjui-action="p-02.page-size"
                value={pageSize}
                style={{ width: 90 }}
                onChange={(value) => {
                  setPageSize(value);
                  setCurrent(1);
                }}
                options={[
                  { value: 10, label: "10 条" },
                  { value: 20, label: "20 条" },
                  { value: 50, label: "50 条" }
                ]}
              />
            </Space>
            <Pagination
              current={current}
              pageSize={pageSize}
              total={filtered.length}
              showSizeChanger={false}
              itemRender={(page, type, element) => {
                const lastPage = Math.max(1, Math.ceil(filtered.length / pageSize));
                if (type === "prev") return <Button size="small" data-jjui-action="p-02.page-prev" disabled={current <= 1}>上一页</Button>;
                if (type === "next") return <Button size="small" data-jjui-action="p-02.page-next" disabled={current >= lastPage}>下一页</Button>;
                return element;
              }}
              onChange={setCurrent}
            />
          </div>
        </SectionCard>
      </section>

      <Modal
        title={formTitle}
        open={formOpen}
        okText={editingId ? "保存" : "创建"}
        cancelText="取消"
        onOk={submitForm}
        onCancel={() => setFormOpen(false)}
      >
        <Form form={form} labelAlign="left" labelCol={{ span: 6 }} initialValues={{ status: "active", region: "华南" }}>
          <Form.Item label="客户名称" name="name" rules={[{ required: true, message: "请输入客户名称" }]}>
            <Input data-jjui-action="p-02.form-name" placeholder="请输入客户名称" />
          </Form.Item>
          <Form.Item label="状态" name="status" rules={[{ required: true, message: "请选择状态" }]}>
            <Select data-jjui-action="p-02.form-status" style={{ width: "100%" }} options={[{ label: "启用", value: "active" }, { label: "停用", value: "inactive" }]} />
          </Form.Item>
          <Form.Item label="地区" name="region" rules={[{ required: true, message: "请选择地区" }]}>
            <Select data-jjui-action="p-02.form-region" style={{ width: "100%" }} options={[{ label: "华南", value: "华南" }, { label: "华北", value: "华北" }, { label: "华东", value: "华东" }, { label: "西南", value: "西南" }]} />
          </Form.Item>
          <Form.Item label="负责人" name="owner" rules={[{ required: true, message: "请输入负责人" }]}>
            <Input data-jjui-action="p-02.form-owner" placeholder="请输入负责人" />
          </Form.Item>
        </Form>
      </Modal>

      <Drawer title={detail?.name} open={!!detail} onClose={() => setDetail(null)}>
        <Descriptions column={1} bordered size="small" items={[
          { key: "id", label: "客户 ID", children: detail?.id },
          { key: "status", label: "状态", children: <StatusTag label={detailStatusLabel} tone={detail?.status === "active" ? "success" : "danger"} /> },
          { key: "region", label: "地区", children: detail?.region },
          { key: "owner", label: "负责人", children: detail?.owner }
        ]} />
      </Drawer>
    </main>
  );
}
