import { useEffect, useState } from "react";
import { Button, Dropdown, Form, Input, Pagination, Select, Space, Table } from "antd";
import { PlusOutlined, ReloadOutlined, SearchOutlined, SettingOutlined } from "@ant-design/icons";
import { SectionCard, StatusTag, Toolbar } from "../../../components/admin";
import type { Customer } from "../../../services/customer-service";

// 表格区 Feature：查询卡 + 表格卡头两翼 + 业务表格 + 分页（判据正源: references/page-splitting.md——
// 封闭交互单元；筛选/翻页为单元内部状态，数据行与回调由入口下发）
const ALL_COLUMNS = [
  { key: "name", title: "客户名称", dataIndex: "name", width: 200 },
  { key: "status", title: "状态", dataIndex: "status", width: 100 },
  { key: "region", title: "地区", dataIndex: "region", width: 140 },
  { key: "owner", title: "负责人", dataIndex: "owner", width: 140 }
];

type Props = {
  rows: Customer[];
  loading: boolean;
  onCreate: () => void;
  onEdit: (record: Customer) => void;
  onDetail: (record: Customer) => void;
  onRefresh: () => void;
};

export default function CustomerTable({ rows, loading, onCreate, onEdit, onDetail, onRefresh }: Props) {
  const [visibleCols, setVisibleCols] = useState(["name", "status", "region", "owner"]);
  // 高级查询卡：受控提交式——改值不生效，点"查询"应用（判据: composition-layer.md 工具栏段）
  const [draftKeyword, setDraftKeyword] = useState("");
  const [draftStatus, setDraftStatus] = useState<string | undefined>(undefined);
  const [applied, setApplied] = useState({ keyword: "", status: "" });
  // 表格卡头：即时过滤式——输入即过滤，无提交按钮
  const [quickSearch, setQuickSearch] = useState("");
  const [current, setCurrent] = useState(1);
  const [pageSize, setPageSize] = useState(10);

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
  // 数据重载后回到第一页（新建/编辑由入口写服务层后 reload 下发）
  useEffect(() => {
    setCurrent(1);
  }, [rows]);

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
          <Button type="link" size="small" data-jjui-action="p-02.row-edit" onClick={() => onEdit(record)}>编辑</Button>
          <Button type="link" size="small" data-jjui-action="p-02.row-detail" onClick={() => onDetail(record)}>详情</Button>
        </Space>
      )
    }
  ];

  return (
    <>
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
              <Button type="primary" icon={<PlusOutlined />} data-jjui-action="p-02.create" onClick={onCreate}>
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
                onClick={onRefresh}
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
    </>
  );
}
