import { useEffect, useRef } from "react";
import { Form, Input, Modal, Select } from "antd";
import type { CustomerInput } from "../../../services/customer-service";

// 新建/编辑客户弹框表单 Feature（判据正源: references/page-splitting.md——
// 弹框表单是封闭交互单元；初始值与提交回调由入口下发，服务写入归入口）
type Props = {
  title: string;
  open: boolean;
  initial: (CustomerInput & { id?: string }) | null;
  onSubmit: (values: CustomerInput) => void;
  onCancel: () => void;
};

export default function CustomerFormModal({ title, open, initial, onSubmit, onCancel }: Props) {
  const [form] = Form.useForm();
  const initialRef = useRef(initial);
  initialRef.current = initial;
  // 打开时装配初始值：编辑带入当前行，新建回默认（校验与控件占满槽宽判据: composition-layer.md 表单段）
  useEffect(() => {
    if (open) {
      form.resetFields();
      form.setFieldsValue(initialRef.current ?? { status: "active", region: "华南" });
    }
  }, [open, form]);

  return (
    <Modal
      title={title}
      open={open}
      okText={initial?.id ? "保存" : "创建"}
      cancelText="取消"
      onOk={() => form.validateFields().then(onSubmit)}
      onCancel={onCancel}
    >
      <Form form={form} labelAlign="left" labelCol={{ span: 6 }}>
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
  );
}
