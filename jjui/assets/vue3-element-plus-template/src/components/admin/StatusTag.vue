<template>
  <el-tag :type="tagType">{{ label }}</el-tag>
</template>

<script setup lang="ts">
import { computed } from "vue";

export type StatusTone = "success" | "warning" | "danger" | "info" | "neutral";

const props = withDefaults(
  defineProps<{
    label: string;
    tone?: StatusTone;
  }>(),
  {
    tone: "neutral"
  }
);

const tagType = computed(() => {
  switch (props.tone) {
    case "success":
      return "success";
    case "warning":
      return "warning";
    case "danger":
      return "danger";
    case "info":
      return "info";
    default:
      return "info";
  }
});
</script>
