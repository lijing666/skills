<template>
  <main data-jjui-page="p-01">
    <PageHeader title="总览" description="客户经营核心指标与近期动态。最近客户按创建时间倒序展示样例。" />

    <section data-jjui-region="p-01.metrics">
      <el-row :gutter="16">
        <el-col :span="8">
          <MetricCard
            label="客户总数"
            :value="customerMetrics[0].value"
            hint="当前启用与停用客户合计"
          />
        </el-col>
        <el-col :span="8">
          <MetricCard
            label="启用客户"
            :value="customerMetrics[1].value"
            tone="success"
            hint="状态为 active 的客户数量"
          />
        </el-col>
        <el-col :span="8">
          <MetricCard
            label="停用客户"
            :value="customerMetrics[2].value"
            tone="danger"
            hint="状态为 inactive 的客户数量"
          />
        </el-col>
      </el-row>
    </section>

    <section data-jjui-region="p-01.recent" class="section">
      <SectionCard>
        <div data-jjui-data="p-01.customer-rows">
          <el-table :data="recentCustomers" row-key="id">
            <el-table-column prop="name" label="客户名称" />
            <el-table-column prop="region" label="地区" />
            <el-table-column prop="owner" label="负责人" />
          </el-table>
        </div>
      </SectionCard>
    </section>
  </main>
</template>

<script setup lang="ts">
import { MetricCard, PageHeader, SectionCard } from "../../components/admin";
import { customerMetrics, customers } from "../../mock/customers";

const recentCustomers = customers.slice(0, 3);
</script>

<style scoped>
.section {
  margin-top: var(--space-6);
}
</style>
