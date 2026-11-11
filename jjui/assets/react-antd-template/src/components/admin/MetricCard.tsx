import { Card, Statistic } from "antd";

export type MetricTone = "default" | "success" | "warning" | "danger";

type MetricCardProps = {
  label: string;
  value: string | number;
  hint?: string;
  tone?: MetricTone;
  loading?: boolean;
};

export default function MetricCard({ label, value, hint, tone = "default", loading = false }: MetricCardProps) {
  return (
    <Card className={`jjui-metric jjui-metric--${tone}`} loading={loading}>
      <Statistic title={label} value={value} />
      {hint ? <p className="jjui-metric__hint">{hint}</p> : null}
    </Card>
  );
}
