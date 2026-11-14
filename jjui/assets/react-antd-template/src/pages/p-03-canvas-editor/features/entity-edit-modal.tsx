import { useEffect, useRef } from "react";
import { Form, Input, Modal } from "antd";

// 编辑实体属性弹框表单 Feature（判据正源: references/page-splitting.md——
// 弹框表单是封闭交互单元；初始值与提交回调由入口下发，节点写回归入口）
type Props = {
  open: boolean;
  initial: { label: string; description: string } | null;
  onSubmit: (values: { label: string; description: string }) => void;
  onCancel: () => void;
};

export default function EntityEditModal({ open, initial, onSubmit, onCancel }: Props) {
  const [form] = Form.useForm();
  const initialRef = useRef(initial);
  initialRef.current = initial;
  useEffect(() => {
    if (open) {
      form.resetFields();
      form.setFieldsValue(initialRef.current ?? { label: "", description: "" });
    }
  }, [open, form]);

  return (
    <Modal
      title="编辑实体属性"
      open={open}
      okText="保存"
      cancelText="取消"
      onOk={() => form.validateFields().then(onSubmit)}
      onCancel={onCancel}
    >
      <Form form={form} labelAlign="left" labelCol={{ span: 6 }}>
        <Form.Item label="名称" name="label" rules={[{ required: true, message: "请输入实体名称" }]}>
          <Input data-jjui-action="p-03.form-label" placeholder="请输入实体名称" />
        </Form.Item>
        <Form.Item label="说明" name="description" rules={[{ required: true, message: "请输入实体说明" }]}>
          <Input data-jjui-action="p-03.form-description" placeholder="请输入实体说明" />
        </Form.Item>
      </Form>
    </Modal>
  );
}
