<template>
  <div>
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
            <el-button type="primary" data-jjui-action="p-02.create" @click="emit('create')">新建客户</el-button>
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
            <el-button size="small" :icon="Refresh" title="刷新" data-jjui-action="p-02.table-refresh" @click="emit('refresh')" />
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
                  <el-button link type="primary" size="small" data-jjui-action="p-02.row-edit" @click="emit('edit', row)">编辑</el-button>
                  <el-button link type="primary" size="small" data-jjui-action="p-02.row-detail" @click="emit('detail', row)">详情</el-button>
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
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { Refresh, Search, Setting } from "@element-plus/icons-vue";
import { SectionCard, StatusTag, Toolbar } from "../../../components/admin";
import type { Customer } from "../../../services/customer-service";

// 表格区 Feature：查询卡 + 表格卡头两翼 + 业务表格 + 分页（判据正源: references/page-splitting.md——
// 封闭交互单元；筛选/翻页为单元内部状态，数据行与回调由入口下发）
const props = defineProps<{ rows: Customer[]; loading: boolean }>();
const emit = defineEmits<{
  (e: "create"): void;
  (e: "edit", record: Customer): void;
  (e: "detail", record: Customer): void;
  (e: "refresh"): void;
}>();

// StatusTag label 须为字面量状态词或纯函数调用（判据: composition-layer.md 状态段——拼接表达式会绕过标点检查）
const statusLabel = (status?: string) => (status === "active" ? "启用" : "停用");
const ALL_COLUMNS = [
  { key: "name", title: "客户名称" },
  { key: "status", title: "状态" },
  { key: "region", title: "地区" },
  { key: "owner", title: "负责人" }
];

const visibleCols = ref(["name", "status", "region", "owner"]);
// 高级查询卡：受控提交式——改值不生效，点"查询"应用（判据正源: references/composition-layer.md 工具栏段）
const draftKeyword = ref("");
const draftStatus = ref("");
const applied = ref({ keyword: "", status: "" });
// 表格卡头：即时过滤式——输入即过滤，无提交按钮
const quickSearch = ref("");
const currentPage = ref(1);
const pageSize = ref(10);

const filteredCustomers = computed(() =>
  props.rows.filter(
    (c) =>
      (!applied.value.keyword || c.name.includes(applied.value.keyword)) &&
      (!applied.value.status || c.status === applied.value.status) &&
      (!quickSearch.value || c.id.toLowerCase().includes(quickSearch.value.toLowerCase()))
  )
);
const pagedCustomers = computed(() =>
  filteredCustomers.value.slice((currentPage.value - 1) * pageSize.value, currentPage.value * pageSize.value)
);
// 数据重载后回到第一页（新建/编辑由入口写服务层后 reload 下发）
watch(
  () => props.rows,
  () => {
    currentPage.value = 1;
  }
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
const toggleColumn = (key: string) => {
  if (visibleCols.value.includes(key)) {
    if (visibleCols.value.length > 1) visibleCols.value = visibleCols.value.filter((c) => c !== key);
  } else {
    visibleCols.value = [...visibleCols.value, key];
  }
};
</script>

<style scoped>
.section {
  margin-top: var(--space-4);
}
</style>
