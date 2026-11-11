<template>
  <main data-jjui-page="p-02">
    <PageHeader
      title="客户列表"
      description="按条件检索客户，并维护客户基础信息。"
    />

    <section data-jjui-region="p-02.filter">
      <SectionCard>
        <Toolbar>
          <!-- 查询卡：el-form inline 承载——label 横排左对齐、placeholder 不替代 label、控件宽度走 token
               （判据正源: composition-layer.md 表格段查询卡布局） -->
          <template #filters>
            <el-form :inline="true" label-position="left">
              <el-form-item label="客户名称">
                <el-input v-model="draftKeyword" placeholder="客户名称" style="width: var(--control-width)" data-jjui-action="p-02.filter-keyword" />
              </el-form-item>
              <el-form-item label="状态">
                <el-select v-model="draftStatus" placeholder="全部状态" clearable style="width: var(--control-width)" data-jjui-action="p-02.filter-status">
                  <el-option label="启用" value="active" />
                  <el-option label="停用" value="inactive" />
                </el-select>
              </el-form-item>
            </el-form>
          </template>
          <template #actions>
            <el-button type="primary" data-jjui-action="p-02.filter-apply" @click="applyQuery">查询</el-button>
            <el-button data-jjui-action="p-02.filter-reset" @click="resetQuery">重置</el-button>
          </template>
        </Toolbar>
      </SectionCard>
    </section>

    <section data-jjui-region="p-02.table" class="section">
      <SectionCard>
        <div class="jjui-table-header">
          <el-space :size="12">
            <el-button type="primary" data-jjui-action="p-02.create" @click="openCreate">新建客户</el-button>
            <el-input
              v-model="quickSearch"
              placeholder="快捷搜索客户"
              style="width: var(--control-width)"
              :prefix-icon="Search"
              clearable
              data-jjui-action="p-02.quick-search"
              @input="currentPage = 1"
            />
          </el-space>
          <el-space :size="12">
            <el-button size="small" :icon="Refresh" title="刷新" data-jjui-action="p-02.table-refresh" @click="reload" />
            <el-dropdown trigger="click" @command="toggleColumn">
              <el-button size="small" :icon="Setting" title="列设置" data-jjui-action="p-02.table-columns" />
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item v-for="col in ALL_COLUMNS" :key="col.key" :command="col.key">{{ col.title }}</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </el-space>
        </div>
        <div v-loading="loading" data-jjui-data="p-02.customer-rows">
          <el-table :data="pagedCustomers" row-key="id">
            <el-table-column v-if="visibleCols.includes('name')" prop="name" label="客户名称" min-width="160" />
            <el-table-column v-if="visibleCols.includes('status')" label="状态" width="100">
              <template #default="{ row }">
                <StatusTag
                  :label="statusLabel(row.status)"
                  :tone="row.status === 'active' ? 'success' : 'danger'"
                />
              </template>
            </el-table-column>
            <el-table-column v-if="visibleCols.includes('region')" prop="region" label="地区" min-width="120" />
            <el-table-column v-if="visibleCols.includes('owner')" prop="owner" label="负责人" min-width="120" />
            <el-table-column label="操作" width="140" fixed="right">
              <template #default="{ row }">
                <el-space :size="8">
                  <el-button link type="primary" size="small" data-jjui-action="p-02.row-edit" @click="openEdit(row)">编辑</el-button>
                  <el-button link type="primary" size="small" data-jjui-action="p-02.row-detail" @click="openDetail(row)">详情</el-button>
                </el-space>
              </template>
            </el-table-column>
          </el-table>
        </div>
        <div class="jjui-pagination">
          <el-pagination
            v-model:current-page="currentPage"
            v-model:page-size="pageSize"
            :page-sizes="[10, 20, 50]"
            :total="filteredCustomers.length"
            layout="total, sizes, prev, pager, next"
            prev-text="上一页"
            next-text="下一页"
          />
        </div>
      </SectionCard>
    </section>

    <el-dialog v-model="formOpen" :title="formTitle" width="480px">
      <el-form ref="formRef" :model="formState" :rules="formRules" label-position="left" label-width="var(--form-label-width)">
        <el-form-item label="客户名称" prop="name">
          <el-input v-model="formState.name" placeholder="请输入客户名称" data-jjui-action="p-02.form-name" />
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-select v-model="formState.status" style="width: 100%" data-jjui-action="p-02.form-status">
            <el-option label="启用" value="active" />
            <el-option label="停用" value="inactive" />
          </el-select>
        </el-form-item>
        <el-form-item label="地区" prop="region">
          <el-select v-model="formState.region" style="width: 100%" data-jjui-action="p-02.form-region">
            <el-option v-for="region in REGIONS" :key="region" :label="region" :value="region" />
          </el-select>
        </el-form-item>
        <el-form-item label="负责人" prop="owner">
          <el-input v-model="formState.owner" placeholder="请输入负责人" data-jjui-action="p-02.form-owner" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button data-jjui-action="p-02.create-cancel" @click="formOpen = false">取消</el-button>
        <el-button type="primary" data-jjui-action="p-02.create-submit" @click="submitForm">{{ editingId ? "保存" : "创建" }}</el-button>
      </template>
    </el-dialog>

    <el-drawer v-model="detailOpen" :title="detail?.name" size="360px">
      <el-descriptions :column="1" border>
        <el-descriptions-item label="客户 ID">{{ detail?.id }}</el-descriptions-item>
        <el-descriptions-item label="状态">
          <StatusTag
            :label="statusLabel(detail?.status)"
            :tone="detail?.status === 'active' ? 'success' : 'danger'"
          />
        </el-descriptions-item>
        <el-descriptions-item label="地区">{{ detail?.region }}</el-descriptions-item>
        <el-descriptions-item label="负责人">{{ detail?.owner }}</el-descriptions-item>
      </el-descriptions>
    </el-drawer>
  </main>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from "vue";
import { ElMessage } from "element-plus";
import { Refresh, Search, Setting } from "@element-plus/icons-vue";
import { PageHeader, SectionCard, StatusTag, Toolbar } from "../../components/admin";
import { customers, type Customer } from "../../mock/customers";

// StatusTag label 须为字面量状态词或纯函数调用（判据: composition-layer.md 状态段——拼接表达式会绕过标点检查）
const statusLabel = (status?: string) => (status === "active" ? "启用" : "停用");
const REGIONS = ["华南", "华北", "华东", "西南"];
const ALL_COLUMNS = [
  { key: "name", title: "客户名称" },
  { key: "status", title: "状态" },
  { key: "region", title: "地区" },
  { key: "owner", title: "负责人" }
];

const rows = ref<Customer[]>([...customers]);
const loading = ref(false);
const visibleCols = ref(["name", "status", "region", "owner"]);
// 高级查询卡：受控提交式——改值不生效，点"查询"应用（判据正源: references/composition-layer.md 工具栏段）
const draftKeyword = ref("");
const draftStatus = ref("");
const applied = ref({ keyword: "", status: "" });
// 表格卡头：即时过滤式——输入即过滤，无提交按钮
const quickSearch = ref("");
const currentPage = ref(1);
const pageSize = ref(10);
// 新建/编辑：真实交互流（弹框表单 + 校验 + 写入 mock，判据正源: references/composition-layer.md 页面段操作保真）
const formOpen = ref(false);
const formTitle = ref("创建客户");
const editingId = ref<string | null>(null);
const formRef = ref();
const formState = reactive({ name: "", status: "active", region: "华南", owner: "" });
const formRules = {
  name: [{ required: true, message: "请输入客户名称", trigger: "blur" }],
  status: [{ required: true, message: "请选择状态", trigger: "change" }],
  region: [{ required: true, message: "请选择地区", trigger: "change" }],
  owner: [{ required: true, message: "请输入负责人", trigger: "blur" }]
};
// 详情抽屉（drawer 轻详情，判据正源: references/composition-layer.md 详情呈现段）
const detail = ref<Customer | null>(null);
const detailOpen = ref(false);

const filteredCustomers = computed(() =>
  rows.value.filter(
    (c) =>
      (!applied.value.keyword || c.name.includes(applied.value.keyword)) &&
      (!applied.value.status || c.status === applied.value.status) &&
      (!quickSearch.value || c.id.toLowerCase().includes(quickSearch.value.toLowerCase()))
  )
);
const pagedCustomers = computed(() =>
  filteredCustomers.value.slice((currentPage.value - 1) * pageSize.value, currentPage.value * pageSize.value)
);

const applyQuery = () => {
  applied.value = { keyword: draftKeyword.value, status: draftStatus.value };
  currentPage.value = 1;
};
const resetQuery = () => {
  draftKeyword.value = "";
  draftStatus.value = "";
  applied.value = { keyword: "", status: "" };
  currentPage.value = 1;
};
const reload = () => {
  loading.value = true;
  setTimeout(() => {
    loading.value = false;
  }, 400);
};
const toggleColumn = (key: string) => {
  if (visibleCols.value.includes(key)) {
    if (visibleCols.value.length > 1) visibleCols.value = visibleCols.value.filter((c) => c !== key);
  } else {
    visibleCols.value = [...visibleCols.value, key];
  }
};

const openCreate = () => {
  formTitle.value = "创建客户";
  editingId.value = null;
  Object.assign(formState, { name: "", status: "active", region: "华南", owner: "" });
  formOpen.value = true;
};
const openEdit = (record: Customer) => {
  formTitle.value = "编辑客户";
  editingId.value = record.id;
  Object.assign(formState, { name: record.name, status: record.status, region: record.region, owner: record.owner });
  formOpen.value = true;
};
const openDetail = (record: Customer) => {
  detail.value = record;
  detailOpen.value = true;
};
const submitForm = () => {
  formRef.value?.validate((valid: boolean) => {
    if (!valid) return;
    if (editingId.value) {
      rows.value = rows.value.map((r) => (r.id === editingId.value ? ({ ...r, ...formState } as Customer) : r));
      ElMessage.success(`已保存客户 ${formState.name}（mock 数据）`);
    } else {
      const next: Customer = { id: `C-${String(rows.value.length + 1).padStart(3, "0")}`, ...formState } as Customer;
      rows.value = [next, ...rows.value];
      ElMessage.success(`已创建客户 ${next.name}（mock 数据）`);
      currentPage.value = 1;
    }
    formOpen.value = false;
  });
};
</script>

<style scoped>
.section {
  margin-top: var(--space-4);
}
</style>
