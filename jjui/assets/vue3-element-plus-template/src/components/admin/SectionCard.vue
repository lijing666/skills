<template>
  <el-card class="jjui-section" :class="$attrs.class">
    <template v-if="title" #header>
      <div class="jjui-section__header">
        <span class="jjui-section__title">{{ title }}</span>
        <div v-if="$slots.extra" class="jjui-section__extra">
          <slot name="extra" />
        </div>
      </div>
    </template>
    <p v-if="description" class="jjui-section__description">{{ description }}</p>
    <slot />
  </el-card>
</template>

<script setup lang="ts">
defineProps<{
  title?: string;
  description?: string;
}>();
</script>
