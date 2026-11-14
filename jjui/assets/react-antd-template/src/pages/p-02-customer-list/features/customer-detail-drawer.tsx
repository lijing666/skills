import { Descriptions, Drawer } from "antd";
import { StatusTag } from "../../../components/admin";
import type { Customer } from "../../../services/customer-service";

// 详情抽屉 Feature：drawer 轻详情（判据正源: references/page-splitting.md；
// 呈现判据: composition-layer.md 详情呈现段——保持列表上下文）
// StatusTag label 须为字面量状态词或纯变量（判据: composition-layer.md 状态段）
const statusWord = (status?: string) => (status === "active" ? "启用" : "停用");

type Props = {
  detail: Customer | null;
  onClose: () => void;
};

export default function CustomerDetailDrawer({ detail, onClose }: Props) {
  return (
    <Drawer title={detail?.name} open={!!detail} onClose={onClose}>
      <Descriptions column={1} bordered size="small" items={[
        { key: "id", label: "客户 ID", children: detail?.id },
        { key: "status", label: "状态", children: <StatusTag label={statusWord(detail?.status)} tone={detail?.status === "active" ? "success" : "danger"} /> },
        { key: "region", label: "地区", children: detail?.region },
        { key: "owner", label: "负责人", children: detail?.owner }
      ]} />
    </Drawer>
  );
}
