<template>
  <div class="jjui-toolbar">
    <div v-if="$slots.filters" class="jjui-toolbar__filters">
      <slot name="filters" />
    </div>
    <div v-if="$slots.actions" class="jjui-toolbar__actions">
      <slot name="actions" />
    </div>
  </div>
</template>
