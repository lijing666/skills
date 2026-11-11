<template>
  <el-card class="jjui-metric" :class="`jjui-metric--${tone}`">
    <el-statistic :title="label" :value="value" />
    <p v-if="hint" class="jjui-metric__hint">{{ hint }}</p>
  </el-card>
</template>

<script setup lang="ts">
export type MetricTone = "default" | "success" | "warning" | "danger";

withDefaults(
  defineProps<{
    label: string;
    value: number | string;
    hint?: string;
    tone?: MetricTone;
  }>(),
  {
    tone: "default"
  }
);
</script>
