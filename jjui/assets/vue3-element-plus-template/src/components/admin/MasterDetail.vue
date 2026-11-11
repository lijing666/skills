<template>
  <div class="jjui-master" :class="$attrs.class">
    <header v-if="title" class="jjui-master__head">
      <h2 class="jjui-master__title">{{ title }}</h2>
      <p v-if="description" class="jjui-master__description">{{ description }}</p>
    </header>
    <div class="jjui-master__body">
      <aside class="jjui-master__aside">
        <slot name="aside" />
      </aside>
      <main class="jjui-master__main">
        <slot />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
// 门牌放容器内部顶部（判据正源: composition-layer.md 主从布局段——外层不得再包 SectionCard 或带题卡）
defineProps<{ title?: string; description?: string }>();
</script>
