<template>
  <section class="jjui-ide__editor" data-jjui-region="p-04.editor">
    <el-tabs v-model="activeTab">
      <el-tab-pane label="基本信息" name="base">
        <el-form
          :key="selectedKey"
          ref="formRef"
          :model="editForm"
          :rules="editRules"
          label-position="left"
          label-width="var(--form-label-width)"
        >
          <el-form-item label="名称" prop="title">
            <el-input v-model="editForm.title" data-jjui-action="p-04.form-title" />
          </el-form-item>
          <el-form-item label="说明" prop="description">
            <el-input v-model="editForm.description" type="textarea" :rows="3" data-jjui-action="p-04.form-description" />
          </el-form-item>
          <el-button type="primary" data-jjui-action="p-04.save" @click="submitEdit">保存</el-button>
        </el-form>
      </el-tab-pane>
      <el-tab-pane label="关联设置" name="binding">
        <el-descriptions v-if="bindings.length" :column="1" size="small" border>
          <el-descriptions-item v-for="b in bindings" :key="b.target" :label="b.target">
            {{ b.note }}
          </el-descriptions-item>
        </el-descriptions>
        <p v-else class="jjui-section__description">未配置关联。</p>
      </el-tab-pane>
    </el-tabs>
  </section>
</template>

<script setup lang="ts">
import { reactive, ref, watch } from "vue";
import type { FormInstance, FormRules } from "element-plus";

// Tabs 编辑器 Feature（判据正源: references/page-splitting.md——Tab pane 实现体不进入口文件；
// 选中项、关联数据与保存回调由入口下发，表单随选中同步判据: composition-layer.md 表单段）
const props = defineProps<{
  selectedKey: string;
  selected?: { title: string; description: string };
  bindings: { target: string; note: string }[];
}>();
const emit = defineEmits<{ (e: "save", values: { title: string; description: string }): void }>();

const formRef = ref<FormInstance>();
const activeTab = ref("base");
const editForm = reactive({ title: "", description: "" });
const editRules: FormRules = {
  title: [{ required: true, message: "请输入名称" }],
  description: [{ required: true, message: "请输入说明" }]
};

// 选中切换同步表单数据（immediate 首装配）
watch(
  () => props.selectedKey,
  () => {
    if (props.selected) Object.assign(editForm, { title: props.selected.title, description: props.selected.description });
  },
  { immediate: true }
);

const submitEdit = () => {
  formRef.value?.validate((valid) => {
    if (!valid) return;
    emit("save", { ...editForm });
  });
};
</script>
