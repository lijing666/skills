import { Col, List, Row } from "antd";
import { MetricCard, PageHeader, SectionCard } from "../../components/admin";
import { customerMetrics, customers } from "../../mock/customers";

const recentCustomers = customers.slice(0, 3);

export default function Dashboard() {
  return (
    <main data-jjui-page="p-01">
      <PageHeader title="总览" description="客户经营核心指标与近期动态。最近客户按创建时间倒序展示样例。" />

      <section data-jjui-region="p-01.metrics">
        <Row gutter={[16, 16]}>
          <Col span={8}>
            <MetricCard
              label="客户总数"
              value={customerMetrics[0].value}
              hint="当前启用与停用客户合计"
            />
          </Col>
          <Col span={8}>
            <MetricCard
              label="启用客户"
              value={customerMetrics[1].value}
              tone="success"
              hint="状态为 active 的客户数量"
            />
          </Col>
          <Col span={8}>
            <MetricCard
              label="停用客户"
              value={customerMetrics[2].value}
              tone="danger"
              hint="状态为 inactive 的客户数量"
            />
          </Col>
        </Row>
      </section>

      <section data-jjui-region="p-01.recent" style={{ marginTop: "var(--space-6)" }}>
        <SectionCard>
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
        </SectionCard>
      </section>
    </main>
  );
}
