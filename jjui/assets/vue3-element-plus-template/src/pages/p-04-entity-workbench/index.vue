<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { PageHeader, StatusTag } from "../../components/admin";
import OutlineTree from "./features/outline-tree.vue";
import EntityEditor from "./features/entity-editor.vue";
import InsightPanel from "./features/insight-panel.vue";
import StatusDialogs from "./features/status-dialogs.vue";

// 编辑器工作台页（判据正源: composition-layer.md 编辑器型页面段；语法: vue3-element-plus.md）
// 入口只做装配（判据正源: references/page-splitting.md）：三栏 Feature（大纲树/Tabs 编辑器/伴随面板）
// + 底部状态栏；共享状态（选中项、大纲、发布态）由入口编排下发
// 三区一体：大纲树 + Tabs 编辑器 + 伴随面板，底部常驻状态栏；树项选中驱动编辑器与伴随面板

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

const outline = ref<OutlineItem[]>(OUTLINE);
const selectedKey = ref("customer");
const selected = () => outline.value.find((item) => item.key === selectedKey.value);
const selectedBindings = computed(() => BINDINGS.filter((b) => b.source === selectedKey.value));

// 发布/校验/历史：真实交互流（判据: composition-layer.md 页面段操作保真 + 编辑器型页面段底部状态栏）
const published = ref(false);
const publishOpen = ref(false);
const historyOpen = ref(false);

const selectNode = (key: string) => {
  selectedKey.value = key;
};
const runCheck = () => {
  ElMessage.info(`校验完成：${ISSUES.length} 项待处理`);
};
const submitEdit = (values: { title: string; description: string }) => {
  outline.value = outline.value.map((item) =>
    item.key === selectedKey.value ? { ...item, title: values.title, description: values.description } : item
  );
  ElMessage.success(`已保存「${values.title}」（mock 数据）`);
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
        <OutlineTree :items="outline" :selected-key="selectedKey" @select="selectNode" />
        <EntityEditor :selected-key="selectedKey" :selected="selected()" :bindings="selectedBindings" @save="submitEdit" />
        <InsightPanel :selected="selected()" :issues="ISSUES" />
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

    <StatusDialogs
      :publish-open="publishOpen"
      :history-open="historyOpen"
      @publish="publish"
      @publish-cancel="publishOpen = false"
      @history-close="historyOpen = false"
    />
  </main>
</template>
