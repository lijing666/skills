import { Button, Descriptions, Form, Input, Tabs } from "antd";

// Tabs 编辑器 Feature（判据正源: references/page-splitting.md——Tab pane 实现体不进入口文件；
// 选中项、关联数据与保存回调由入口下发，编辑器表单 key 随选中重建判据: composition-layer.md 表单段）
type EditorItem = { key: string; title: string; description: string };
type Binding = { target: string; note: string };

type Props = {
  selectedKey: string;
  selected?: EditorItem;
  bindings: Binding[];
  onSave: (values: { title: string; description: string }) => void;
};

export default function EntityEditor({ selectedKey, selected, bindings, onSave }: Props) {
  const [form] = Form.useForm();

  return (
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
                <Button type="primary" data-jjui-action="p-04.save" onClick={() => form.validateFields().then(onSave)}>保存</Button>
              </Form>
            )
          },
          {
            key: "binding",
            label: "关联设置",
            children: bindings.length ? (
              <Descriptions
                column={1}
                size="small"
                bordered
                items={bindings.map((b) => ({ key: b.target, label: b.target, children: b.note }))}
              />
            ) : (
              <p className="jjui-section__description">未配置关联。</p>
            )
          }
        ]}
      />
    </section>
  );
}
