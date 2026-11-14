<template>
  <el-dialog :model-value="publishOpen" title="发布画布" width="480px" @update:model-value="emit('publish-cancel')">
    <p>发布后当前草稿将固化为基线 v1.5，已发布版本不可直接修改。</p>
    <template #footer>
      <el-space :size="8">
        <el-button data-jjui-action="p-03.publish-cancel" @click="emit('publish-cancel')">取消</el-button>
        <el-button type="primary" data-jjui-action="p-03.publish-submit" @click="emit('publish')">发布</el-button>
      </el-space>
    </template>
  </el-dialog>

  <el-drawer :model-value="historyOpen" title="版本历史" @update:model-value="emit('history-close')">
    <div v-for="item in VERSIONS" :key="item.version" class="jjui-history-row">
      <span>{{ item.version }}</span>
      <span class="jjui-pagination__meta">{{ item.note }}</span>
    </div>
  </el-drawer>
</template>

<script setup lang="ts">
// 状态栏附属浮层 Feature：发布确认弹框 + 版本历史抽屉（判据正源: references/page-splitting.md——
// 与状态栏触发的发布/历史同属一个状态闭环，合并一个 Feature；写回 published 归入口）
defineProps<{ publishOpen: boolean; historyOpen: boolean }>();
const emit = defineEmits<{
  (e: "publish"): void;
  (e: "publish-cancel"): void;
  (e: "history-close"): void;
}>();

const VERSIONS = [
  { version: "v1.4", note: "当前草稿基线" },
  { version: "v1.3", note: "新增商品实体" },
  { version: "v1.2", note: "调整下单关系基数" }
];
</script>

<style scoped>
.jjui-history-row {
  display: flex;
  justify-content: space-between;
  padding: var(--space-2) 0;
}
</style>
