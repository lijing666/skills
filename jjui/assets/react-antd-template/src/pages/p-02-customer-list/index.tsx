import { useEffect, useState } from "react";
import { message } from "antd";
import { PageHeader } from "../../components/admin";
import CustomerTable from "./features/customer-table";
import CustomerFormModal from "./features/customer-form-modal";
import CustomerDetailDrawer from "./features/customer-detail-drawer";
import {
  createCustomer,
  listCustomers,
  updateCustomer,
  type Customer,
  type CustomerInput
} from "../../services/customer-service";

// 页面入口只做装配（判据正源: references/page-splitting.md——
// 表格区/弹框表单/详情抽屉是封闭交互单元，落 features/；共享状态由入口编排下发）
export default function CustomerList() {
  const [rows, setRows] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [formTitle, setFormTitle] = useState("创建客户");
  const [formOpen, setFormOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [formInitial, setFormInitial] = useState<(CustomerInput & { id?: string }) | null>(null);
  const [detail, setDetail] = useState<Customer | null>(null);

  const reload = async () => {
    setLoading(true);
    const data = await listCustomers();
    setRows(data);
    setLoading(false);
  };
  useEffect(() => {
    reload();
  }, []);

  const openCreate = () => {
    setFormTitle("创建客户");
    setEditingId(null);
    setFormInitial(null);
    setFormOpen(true);
  };
  const openEdit = (record: Customer) => {
    setFormTitle("编辑客户");
    setEditingId(record.id);
    setFormInitial(record);
    setFormOpen(true);
  };
  const submitForm = async (values: CustomerInput) => {
    if (editingId) {
      const saved = await updateCustomer(editingId, values);
      message.success(`已保存客户 ${saved.name}（mock 数据）`);
    } else {
      const created = await createCustomer(values);
      message.success(`已创建客户 ${created.name}（mock 数据）`);
    }
    setFormOpen(false);
    await reload();
  };

  return (
    <main data-jjui-page="p-02">
      <PageHeader
        title="客户列表"
        description="按条件检索客户，并维护客户基础信息。"
      />

      <CustomerTable
        rows={rows}
        loading={loading}
        onCreate={openCreate}
        onEdit={openEdit}
        onDetail={setDetail}
        onRefresh={reload}
      />
      <CustomerFormModal
        title={formTitle}
        open={formOpen}
        initial={formInitial}
        onSubmit={submitForm}
        onCancel={() => setFormOpen(false)}
      />
      <CustomerDetailDrawer detail={detail} onClose={() => setDetail(null)} />
    </main>
  );
}
