<template>
  <aside class="jjui-editor-panel" data-jjui-region="p-04.panel">
    <div class="jjui-section__title">{{ selected?.title }}</div>
    <p class="jjui-section__description">{{ selected?.description }}</p>
    <div class="jjui-section__subtitle">校验</div>
    <p v-for="issue in issues" :key="issue.text" class="jjui-section__description">{{ issue.text }}</p>
    <div class="jjui-section__subtitle">提示</div>
    <p class="jjui-section__description">修改后需通过校验才可发布。</p>
  </aside>
</template>

<script setup lang="ts">
// 伴随面板 Feature（判据正源: references/page-splitting.md——画布/IDE 伴随面板型封闭交互单元；
// 选中项与校验数据由入口下发）
defineProps<{
  selected?: { title: string; description: string };
  issues: { target: string; text: string }[];
}>();
</script>
