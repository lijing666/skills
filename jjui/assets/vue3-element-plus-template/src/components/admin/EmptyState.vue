<template>
  <el-empty :description="description">
    <template v-if="title" #image>
      <span></span>
    </template>
    <p v-if="title" class="jjui-empty__title">{{ title }}</p>
    <div v-if="$slots.action" class="jjui-empty__action">
      <slot name="action" />
    </div>
  </el-empty>
</template>

<script setup lang="ts">
defineProps<{
  title?: string;
  description?: string;
}>();
</script>
