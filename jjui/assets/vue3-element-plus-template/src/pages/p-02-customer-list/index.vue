<template>
  <main data-jjui-page="p-02">
    <PageHeader
      title="客户列表"
      description="按条件检索客户，并维护客户基础信息。"
    />

    <!-- 入口只做装配（判据正源: references/page-splitting.md）：表格区/弹框表单/详情抽屉是
         封闭交互单元落 features/；共享状态由入口编排下发 -->
    <CustomerTable
      :rows="rows"
      :loading="loading"
      @create="openCreate"
      @edit="openEdit"
      @detail="detail = $event"
      @refresh="reload"
    />
    <CustomerFormModal
      :open="formOpen"
      :title="formTitle"
      :initial="formInitial"
      @submit="submitForm"
      @cancel="formOpen = false"
    />
    <CustomerDetailDrawer :detail="detail" @close="detail = null" />
  </main>
</template>

<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { PageHeader } from "../../components/admin";
import CustomerTable from "./features/customer-table.vue";
import CustomerFormModal from "./features/customer-form-modal.vue";
import CustomerDetailDrawer from "./features/customer-detail-drawer.vue";
import {
  createCustomer,
  listCustomers,
  updateCustomer,
  type Customer,
  type CustomerInput
} from "../../services/customer-service";

const rows = ref<Customer[]>([]);
const loading = ref(true);
const reload = async () => {
  loading.value = true;
  rows.value = await listCustomers();
  loading.value = false;
};
onMounted(reload);

// 新建/编辑：真实交互流——服务写入归入口，Feature 只承接交互（判据: composition-layer.md 页面段操作保真）
const formOpen = ref(false);
const formTitle = ref("创建客户");
const editingId = ref<string | null>(null);
const formInitial = ref<(CustomerInput & { id?: string }) | null>(null);
// 详情抽屉（drawer 轻详情，判据正源: references/composition-layer.md 详情呈现段）
const detail = ref<Customer | null>(null);

const openCreate = () => {
  formTitle.value = "创建客户";
  editingId.value = null;
  formInitial.value = null;
  formOpen.value = true;
};
const openEdit = (record: Customer) => {
  formTitle.value = "编辑客户";
  editingId.value = record.id;
  formInitial.value = { ...record };
  formOpen.value = true;
};
const submitForm = async (values: CustomerInput) => {
  if (editingId.value) {
    const saved = await updateCustomer(editingId.value, values);
    ElMessage.success(`已保存客户 ${saved.name}（mock 数据）`);
  } else {
    const created = await createCustomer(values);
    ElMessage.success(`已创建客户 ${created.name}（mock 数据）`);
  }
  formOpen.value = false;
  await reload();
};
</script>
