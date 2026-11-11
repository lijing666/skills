<template>
  <header class="jjui-page-header">
    <div class="jjui-page-header__titleline">
      <el-button
        v-if="onBack"
        text
        :icon="ArrowLeft"
        aria-label="返回"
        class="jjui-page-header__back"
        @click="onBack"
      />
      <h1 class="jjui-page-header__title">{{ title }}</h1>
    </div>
    <p v-if="description" class="jjui-page-header__description">{{ description }}</p>
  </header>
</template>

<script setup lang="ts">
import { ArrowLeft } from "@element-plus/icons-vue";

// 页面门牌（判据正源: composition-layer.md 页面段——只承载标题、描述与返回导航；
// 返回箭头与标题同行垂直居中（titleline），描述独立在标题下方；
// 右侧禁任何操作控件，数据操作按语义归位）
defineProps<{
  title: string;
  description?: string;
  onBack?: () => void;
}>();
</script>
