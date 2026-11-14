<template>
  <aside class="jjui-ide__tree" data-jjui-region="p-04.tree">
    <el-tree :data="treeData" node-key="key" default-expand-all>
      <template #default="{ data }">
        <span v-if="data.children">{{ data.title }}</span>
        <span
          v-else
          :data-jjui-node="data.key"
          :class="['jjui-ide__tree-item', data.key === selectedKey && 'jjui-ide__tree-item--selected']"
          @click="emit('select', data.key)"
        >
          {{ data.title }}
        </span>
      </template>
    </el-tree>
  </aside>
</template>

<script setup lang="ts">
import { computed } from "vue";

// 大纲树 Feature（判据正源: references/page-splitting.md——画布/IDE 伴随面板型封闭交互单元；
// 大纲数据与选中回调由入口下发）
const props = defineProps<{ items: { key: string; title: string; group: string }[]; selectedKey: string }>();
const emit = defineEmits<{ (e: "select", key: string): void }>();

const treeData = computed(() => [
  {
    key: "group-object",
    title: "对象",
    children: props.items.filter((item) => item.group === "对象").map(({ key, title }) => ({ key, title }))
  },
  {
    key: "group-rule",
    title: "规则",
    children: props.items.filter((item) => item.group === "规则").map(({ key, title }) => ({ key, title }))
  }
]);
</script>
