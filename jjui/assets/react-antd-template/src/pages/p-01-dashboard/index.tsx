import { useEffect, useMemo, useState } from "react";
import { Col, List, Row } from "antd";
import { MetricCard, PageHeader, SectionCard } from "../../components/admin";
import { listCustomers, type Customer } from "../../services/customer-service";

export default function Dashboard() {
  // 页级数据装配走 Service（判据正源: references/page-splitting.md——页面只消费 async 接口）
  const [rows, setRows] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    listCustomers().then((data) => {
      setRows(data);
      setLoading(false);
    });
  }, []);

  const metrics = useMemo(
    () => [
      { label: "客户总数", value: rows.length, hint: "当前启用与停用客户合计", tone: undefined },
      {
        label: "启用客户",
        value: rows.filter((item) => item.status === "active").length,
        hint: "状态为 active 的客户数量",
        tone: "success" as const
      },
      {
        label: "停用客户",
        value: rows.filter((item) => item.status === "inactive").length,
        hint: "状态为 inactive 的客户数量",
        tone: "danger" as const
      }
    ],
    [rows]
  );
  const recentCustomers = rows.slice(0, 3);

  return (
    <main data-jjui-page="p-01">
      <PageHeader title="总览" description="客户经营核心指标与近期动态。最近客户按创建时间倒序展示样例。" />

      <section data-jjui-region="p-01.metrics">
        <Row gutter={[16, 16]}>
          {metrics.map((metric) => (
            <Col span={8} key={metric.label}>
              <MetricCard label={metric.label} value={metric.value} tone={metric.tone} hint={metric.hint} />
            </Col>
          ))}
        </Row>
      </section>

      <section data-jjui-region="p-01.recent" style={{ marginTop: "var(--space-6)" }}>
        <SectionCard>
          {loading ? (
            <p className="jjui-section__description">加载中…</p>
          ) : (
            <div data-jjui-data="p-01.customer-rows">
              <List
                dataSource={recentCustomers}
                renderItem={(item) => (
                  <List.Item>
                    {item.name} · {item.region} · {item.owner}
                  </List.Item>
                )}
              />
            </div>
          )}
        </SectionCard>
      </section>
    </main>
  );
}
