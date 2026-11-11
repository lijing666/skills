<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import type { FormInstance, FormRules } from "element-plus";
import { PageHeader, StatusTag } from "../../components/admin";

// 编辑器工作台页（判据正源: composition-layer.md 编辑器型页面段；语法: vue3-element-plus.md）
// 三栏一体：大纲树 + Tabs 编辑器 + 伴随面板，底部常驻状态栏；树项选中驱动编辑器与伴随面板

type OutlineItem = {
  key: string;
  title: string;
  group: "对象" | "规则";
  description: string;
};

const OUTLINE: OutlineItem[] = [
  { key: "customer", title: "客户", group: "对象", description: "购买商品的个人或组织。" },
  { key: "order", title: "订单", group: "对象", description: "一次购买的完整记录。" },
  { key: "product", title: "商品", group: "对象", description: "订单中售卖的最小单元。" },
  { key: "rule-check", title: "下单校验", group: "规则", description: "校验订单库存与收货地址。" },
  { key: "rule-score", title: "积分计算", group: "规则", description: "按订单金额累计积分。" }
];

const BINDINGS = [
  { source: "customer", target: "订单", note: "客户可发起多笔订单" },
  { source: "order", target: "商品", note: "订单包含多个商品明细" },
  { source: "rule-check", target: "订单", note: "下单前校验订单合法性" }
];

const ISSUES = [
  { target: "product", text: "「商品」缺少唯一标识字段" },
  { target: "rule-score", text: "「积分计算」未绑定触发时机" }
];

const VERSIONS = [
  { version: "v2.0", note: "当前草稿基线" },
  { version: "v1.9", note: "新增下单校验规则" },
  { version: "v1.8", note: "调整客户字段说明" }
];

const outline = ref<OutlineItem[]>(OUTLINE);
const selectedKey = ref("customer");
const selected = () => outline.value.find((item) => item.key === selectedKey.value);
const selectedBindings = computed(() => BINDINGS.filter((b) => b.source === selectedKey.value));
const treeData = computed(() => [
  {
    key: "group-object",
    title: "对象",
    children: outline.value.filter((item) => item.group === "对象").map(({ key, title }) => ({ key, title }))
  },
  {
    key: "group-rule",
    title: "规则",
    children: outline.value.filter((item) => item.group === "规则").map(({ key, title }) => ({ key, title }))
  }
]);

// 发布/校验/历史：真实交互流（判据: composition-layer.md 页面段操作保真 + 编辑器型页面段底部状态栏）
const published = ref(false);
const publishOpen = ref(false);
const historyOpen = ref(false);
// 编辑器表单：选中切换同步表单数据，保存写回 mock（判据: composition-layer.md 表单段）
const formRef = ref<FormInstance>();
const activeTab = ref("base");
const editForm = ref({ title: OUTLINE[0].title, description: OUTLINE[0].description });
const editRules: FormRules = {
  title: [{ required: true, message: "请输入名称" }],
  description: [{ required: true, message: "请输入说明" }]
};

const selectNode = (key: string) => {
  selectedKey.value = key;
  const item = outline.value.find((o) => o.key === key);
  if (item) editForm.value = { title: item.title, description: item.description };
};
const runCheck = () => {
  ElMessage.info(`校验完成：${ISSUES.length} 项待处理`);
};
const submitEdit = () => {
  formRef.value?.validate((valid) => {
    if (!valid) return;
    outline.value = outline.value.map((item) =>
      item.key === selectedKey.value ? { ...item, title: editForm.value.title, description: editForm.value.description } : item
    );
    ElMessage.success(`已保存「${editForm.value.title}」（mock 数据）`);
  });
};
// StatusTag label 须为字面量状态词或纯变量（判据: composition-layer.md 状态段）
const statusLabel = computed(() => (published.value ? "已发布" : "草稿"));
// 状态栏钉住目标：壳层内容滚动容器（判据: composition-layer.md 编辑器型页面段底部状态栏）
const scrollEl = ref<HTMLElement | null>(null);
onMounted(() => {
  scrollEl.value = document.querySelector(".admin-layout__content");
});
const publish = () => {
  published.value = true;
  publishOpen.value = false;
  ElMessage.success("工作台草稿已发布（mock 数据）");
};
</script>

<template>
  <main data-jjui-page="p-04">
    <PageHeader
      title="实体工作台"
      description="在结构化工作台中维护对象与规则，选中大纲项后编辑并查看校验。"
    />

    <div class="jjui-ide" data-jjui-ide="p-04.workbench">
      <div class="jjui-ide__body">
        <aside class="jjui-ide__tree" data-jjui-region="p-04.tree">
          <el-tree :data="treeData" node-key="key" default-expand-all>
            <template #default="{ data }">
              <span v-if="data.children">{{ data.title }}</span>
              <span
                v-else
                :data-jjui-node="data.key"
                :class="['jjui-ide__tree-item', data.key === selectedKey && 'jjui-ide__tree-item--selected']"
                @click="selectNode(data.key)"
              >
                {{ data.title }}
              </span>
            </template>
          </el-tree>
        </aside>

        <section class="jjui-ide__editor" data-jjui-region="p-04.editor">
          <el-tabs v-model="activeTab">
            <el-tab-pane label="基本信息" name="base">
              <el-form
                :key="selectedKey"
                ref="formRef"
                :model="editForm"
                :rules="editRules"
                label-position="left"
                label-width="var(--form-label-width)"
              >
                <el-form-item label="名称" prop="title">
                  <el-input v-model="editForm.title" data-jjui-action="p-04.form-title" />
                </el-form-item>
                <el-form-item label="说明" prop="description">
                  <el-input v-model="editForm.description" type="textarea" :rows="3" data-jjui-action="p-04.form-description" />
                </el-form-item>
                <el-button type="primary" data-jjui-action="p-04.save" @click="submitEdit">保存</el-button>
              </el-form>
            </el-tab-pane>
            <el-tab-pane label="关联设置" name="binding">
              <el-descriptions v-if="selectedBindings.length" :column="1" size="small" border>
                <el-descriptions-item v-for="b in selectedBindings" :key="b.target" :label="b.target">
                  {{ b.note }}
                </el-descriptions-item>
              </el-descriptions>
              <p v-else class="jjui-section__description">未配置关联。</p>
            </el-tab-pane>
          </el-tabs>
        </section>

        <aside class="jjui-editor-panel" data-jjui-region="p-04.panel">
          <div class="jjui-section__title">{{ selected()?.title }}</div>
          <p class="jjui-section__description">{{ selected()?.description }}</p>
          <div class="jjui-section__subtitle">校验</div>
          <p v-for="issue in ISSUES" :key="issue.text" class="jjui-section__description">{{ issue.text }}</p>
          <div class="jjui-section__subtitle">提示</div>
          <p class="jjui-section__description">修改后需通过校验才可发布。</p>
        </aside>
      </div>

      <el-affix :offset-bottom="0" :target="scrollEl">
        <footer class="jjui-editor-statusbar" data-jjui-region="p-04.statusbar">
          <el-space :size="12">
            <StatusTag :label="statusLabel" :tone="published ? 'success' : 'info'" />
            <span class="jjui-pagination__meta">基线 v2.0 · {{ ISSUES.length }} 项待处理校验</span>
          </el-space>
          <el-space :size="8">
            <el-button size="small" data-jjui-action="p-04.check" @click="runCheck">校验</el-button>
            <el-button size="small" data-jjui-action="p-04.history" @click="historyOpen = true">版本历史</el-button>
            <el-button type="primary" size="small" data-jjui-action="p-04.publish" @click="publishOpen = true">发布</el-button>
          </el-space>
        </footer>
      </el-affix>
    </div>

    <el-dialog v-model="publishOpen" title="发布工作台" width="480px">
      <p>发布后当前草稿将固化为基线 v2.1，已发布版本不可直接修改。</p>
      <template #footer>
        <el-space :size="8">
          <el-button data-jjui-action="p-04.publish-cancel" @click="publishOpen = false">取消</el-button>
          <el-button type="primary" data-jjui-action="p-04.publish-submit" @click="publish">发布</el-button>
        </el-space>
      </template>
    </el-dialog>

    <el-drawer v-model="historyOpen" title="版本历史">
      <div v-for="item in VERSIONS" :key="item.version" class="jjui-history-row">
        <span>{{ item.version }}</span>
        <span class="jjui-pagination__meta">{{ item.note }}</span>
      </div>
    </el-drawer>
  </main>
</template>

<style scoped>
.jjui-history-row {
  display: flex;
  justify-content: space-between;
  padding: var(--space-2) 0;
}
</style>
