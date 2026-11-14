<template>
  <el-drawer :model-value="!!detail" :title="detail?.name" size="360px" @update:model-value="emit('close')">
    <el-descriptions :column="1" border>
      <el-descriptions-item label="客户 ID">{{ detail?.id }}</el-descriptions-item>
      <el-descriptions-item label="状态">
        <StatusTag
          :label="statusLabel(detail?.status)"
          :tone="detail?.status === 'active' ? 'success' : 'danger'"
        />
      </el-descriptions-item>
      <el-descriptions-item label="地区">{{ detail?.region }}</el-descriptions-item>
      <el-descriptions-item label="负责人">{{ detail?.owner }}</el-descriptions-item>
    </el-descriptions>
  </el-drawer>
</template>

<script setup lang="ts">
import { StatusTag } from "../../../components/admin";
import type { Customer } from "../../../services/customer-service";

// 详情抽屉 Feature：drawer 轻详情（判据正源: references/page-splitting.md；
// 呈现判据: composition-layer.md 详情呈现段——保持列表上下文）
const props = defineProps<{ detail: Customer | null }>();
const emit = defineEmits<{ (e: "close"): void }>();

// StatusTag label 须为字面量状态词或纯函数调用（判据: composition-layer.md 状态段）
const statusLabel = (status?: string) => (status === "active" ? "启用" : "停用");
</script>
