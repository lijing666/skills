import { Tag } from "antd";

export type StatusTone = "success" | "warning" | "danger" | "info" | "neutral";

type StatusTagProps = {
  label: string;
  tone?: StatusTone;
};

const toneMap: Record<StatusTone, string> = {
  success: "success",
  warning: "warning",
  danger: "error",
  info: "processing",
  neutral: "default"
};

export default function StatusTag({ label, tone = "neutral" }: StatusTagProps) {
  return <Tag color={toneMap[tone]}>{label}</Tag>;
}
