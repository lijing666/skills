<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import {
  Background,
  BaseEdge,
  Controls,
  EdgeLabelRenderer,
  VueFlow,
  getBezierPath,
  type EdgeProps
} from "@vue-flow/core";
import "@vue-flow/core/dist/style.css";
import { ElMessage } from "element-plus";
import { PageHeader, StatusTag } from "../../components/admin";
import EntityEditModal from "./features/entity-edit-modal.vue";
import StatusDialogs from "./features/status-dialogs.vue";

// 画布页（判据正源: composition-layer.md 画布段；语法: vue3-element-plus.md 画布段）
// 入口只做装配（判据正源: references/page-splitting.md）：画布 + 伴随面板 + 状态栏；
// 弹框表单与状态栏附属浮层是封闭交互单元，落 features/
// 三区一体：画布主编辑面 + 伴随面板 + 底部状态栏；节点/边可选中驱动伴随面板

type EntityData = {
  identifier: string;
  label: string;
  description: string;
  primary: string;
};

const ENTITIES: EntityData[] = [
  { identifier: "customer", label: "客户", description: "购买商品的个人或组织。", primary: "客户编号" },
  { identifier: "order", label: "订单", description: "一次购买的完整记录。", primary: "订单编号" },
  { identifier: "product", label: "商品", description: "订单中售卖的最小单元。", primary: "待补充" }
];

const NODE_POSITIONS: Record<string, { x: number; y: number }> = {
  customer: { x: 40, y: 80 },
  order: { x: 300, y: 40 },
  product: { x: 540, y: 130 }
};

const RELATIONS = [
  { id: "rel-customer-order", source: "entity-customer", target: "entity-order", label: "下单 · 1..n" },
  { id: "rel-order-product", source: "entity-order", target: "entity-product", label: "包含 · n..m" }
];

const ISSUES = [
  { target: "商品", text: "「商品」缺少主键属性" },
  { target: "订单", text: "「订单」到「商品」的关系未标注基数" }
];

const nodes = ref(
  ENTITIES.map((entity) => ({
    id: `entity-${entity.identifier}`,
    type: "entity",
    position: NODE_POSITIONS[entity.identifier],
    data: { ...entity }
  }))
);
const edges = ref(
  RELATIONS.map((relation) => ({
    id: relation.id,
    source: relation.source,
    target: relation.target,
    type: "relation",
    data: { label: relation.label }
  }))
);

const selectedId = ref("entity-customer");
const selectedEntity = () => nodes.value.find((node) => node.id === selectedId.value)?.data;
const selectNode = (id: string) => {
  selectedId.value = id;
};
const edgePath = (props: EdgeProps) => getBezierPath(props)[0];
const labelPos = (props: EdgeProps) => [getBezierPath(props)[1], getBezierPath(props)[2]];

// 发布/校验/历史：真实交互流（判据: composition-layer.md 页面段操作保真 + 画布段底部状态栏）
const published = ref(false);
const publishOpen = ref(false);
const historyOpen = ref(false);
// 伴随面板编辑：弹框表单为封闭交互单元落 features/（判据正源: references/page-splitting.md），初始值经 props 下发
const editOpen = ref(false);
const editInitial = ref<{ label: string; description: string } | null>(null);

const runCheck = () => {
  ElMessage.info(`校验完成：${ISSUES.length} 项待处理`);
};
const openEdit = () => {
  const entity = selectedEntity();
  if (!entity) return;
  editInitial.value = { label: entity.label, description: entity.description };
  editOpen.value = true;
};
const submitEdit = (values: { label: string; description: string }) => {
  nodes.value = nodes.value.map((node) =>
    node.id === selectedId.value
      ? { ...node, data: { ...node.data, label: values.label, description: values.description } }
      : node
  );
  ElMessage.success(`已保存实体「${values.label}」（mock 数据）`);
  editOpen.value = false;
};
// StatusTag label 须为字面量状态词或纯变量（判据: composition-layer.md 状态段）
const statusLabel = computed(() => (published.value ? "已发布" : "草稿"));
// 状态栏钉住目标：壳层内容滚动容器（判据: composition-layer.md 编辑器型页面段底部状态栏）
const scrollEl = ref<HTMLElement | null>(null);
onMounted(() => {
  scrollEl.value = document.querySelector(".admin-layout__content");
});
const publishCanvas = () => {
  published.value = true;
  publishOpen.value = false;
  ElMessage.success("画布草稿已发布（mock 数据）");
};
</script>

<template>
  <main data-jjui-page="p-03">
    <PageHeader
      title="实体画布"
      description="以画布维护实体与关系，选中节点或边后在伴随面板编辑并查看校验。"
    />

    <div class="jjui-canvas" data-jjui-region="p-03.canvas">
      <div class="jjui-canvas__body">
        <div class="jjui-canvas__stage" data-jjui-canvas="p-03.canvas-stage">
          <VueFlow v-model:nodes="nodes" v-model:edges="edges" fit-view>
            <Background />
            <Controls />
            <template #node-entity="props">
              <div
                :data-jjui-node="props.id"
                :class="['jjui-canvas__node', props.selected && 'jjui-canvas__node--selected']"
                @click="selectNode(props.id)"
              >
                <div class="jjui-canvas__node-title">{{ props.data.label }}</div>
                <div class="jjui-canvas__node-desc">{{ props.data.description }}</div>
              </div>
            </template>
            <template #edge-relation="props">
              <BaseEdge :id="props.id" :path="edgePath(props)" />
              <EdgeLabelRenderer>
                <span
                  class="jjui-canvas__edge-label"
                  :data-jjui-edge="props.id"
                  :style="{
                    transform: `translate(-50%, -50%) translate(${labelPos(props)[0]}px, ${labelPos(props)[1]}px)`
                  }"
                  @click="selectNode(props.id)"
                >
                  {{ props.data.label }}
                </span>
              </EdgeLabelRenderer>
            </template>
          </VueFlow>
        </div>

        <aside class="jjui-editor-panel" data-jjui-region="p-03.panel">
          <div class="jjui-section__title">{{ selectedEntity()?.label }}</div>
          <p class="jjui-section__description">{{ selectedEntity()?.description }}</p>
          <el-descriptions :column="1" size="small" border>
            <el-descriptions-item label="标识">{{ selectedEntity()?.identifier }}</el-descriptions-item>
            <el-descriptions-item label="主键">{{ selectedEntity()?.primary }}</el-descriptions-item>
          </el-descriptions>
          <el-button
            block
            style="margin-top: var(--space-3)"
            data-jjui-action="p-03.edit-entity"
            @click="openEdit"
          >
            编辑属性
          </el-button>
          <div class="jjui-section__subtitle">校验</div>
          <p v-for="issue in ISSUES" :key="issue.text" class="jjui-section__description">{{ issue.text }}</p>
        </aside>
      </div>

      <el-affix :offset-bottom="0" :target="scrollEl">
        <footer class="jjui-editor-statusbar" data-jjui-region="p-03.statusbar">
          <el-space :size="12">
            <StatusTag :label="statusLabel" :tone="published ? 'success' : 'info'" />
            <span class="jjui-pagination__meta">基线 v1.4 · {{ ISSUES.length }} 项待处理校验</span>
          </el-space>
          <el-space :size="8">
            <el-button size="small" data-jjui-action="p-03.canvas-check" @click="runCheck">校验</el-button>
            <el-button size="small" data-jjui-action="p-03.canvas-history" @click="historyOpen = true">版本历史</el-button>
            <el-button type="primary" size="small" data-jjui-action="p-03.canvas-publish" @click="publishOpen = true">发布</el-button>
          </el-space>
        </footer>
      </el-affix>
    </div>

    <EntityEditModal
      :open="editOpen"
      :initial="editInitial"
      @submit="submitEdit"
      @cancel="editOpen = false"
    />
    <StatusDialogs
      :publish-open="publishOpen"
      :history-open="historyOpen"
      @publish="publishCanvas"
      @publish-cancel="publishOpen = false"
      @history-close="historyOpen = false"
    />
  </main>
</template>

<style scoped>
.jjui-history-row {
  display: flex;
  justify-content: space-between;
  padding: var(--space-2) 0;
}
</style>
