<template>
  <div class="admin-layout">
    <aside class="admin-sider">
      <div class="admin-sider__brand">__PRODUCT_ID__ · __BUSINESS__</div>
      <div class="admin-sider__menu">
        <el-menu :default-active="$route.path" router>
          <el-menu-item index="/dashboard">总览</el-menu-item>
          <el-menu-item index="/customers">客户列表</el-menu-item>
          <el-menu-item index="/canvas">实体画布</el-menu-item>
          <el-menu-item index="/workbench">实体工作台</el-menu-item>
        </el-menu>
      </div>
    </aside>
    <div class="admin-main">
      <header class="admin-header">
        <el-breadcrumb separator="/">
          <el-breadcrumb-item :to="{ path: '/dashboard' }">首页</el-breadcrumb-item>
          <el-breadcrumb-item v-if="currentLabel">{{ currentLabel }}</el-breadcrumb-item>
        </el-breadcrumb>
        <el-space size="large">
          <el-icon><Bell /></el-icon>
          <el-space size="small">
            <el-icon><User /></el-icon>
            <span>管理员</span>
          </el-space>
        </el-space>
      </header>
      <main class="admin-layout__content">
        <div class="admin-layout__page">
          <router-view />
        </div>
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useRoute } from "vue-router";
import { Bell, User } from "@element-plus/icons-vue";

const route = useRoute();
const routeLabels: Record<string, string> = {
  "/dashboard": "总览",
  "/customers": "客户列表",
  "/canvas": "实体画布",
  "/workbench": "实体工作台"
};
const currentLabel = computed(() => routeLabels[route.path]);
</script>
