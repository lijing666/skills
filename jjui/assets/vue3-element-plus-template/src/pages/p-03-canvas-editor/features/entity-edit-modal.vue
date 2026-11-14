<template>
  <el-dialog :model-value="open" title="编辑实体属性" width="480px" @update:model-value="emit('cancel')">
    <el-form ref="formRef" :model="editForm" :rules="editRules" label-position="left" label-width="var(--form-label-width)">
      <el-form-item label="名称" prop="label">
        <el-input v-model="editForm.label" data-jjui-action="p-03.form-label" placeholder="请输入实体名称" />
      </el-form-item>
      <el-form-item label="说明" prop="description">
        <el-input v-model="editForm.description" data-jjui-action="p-03.form-description" placeholder="请输入实体说明" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-space :size="8">
        <el-button data-jjui-action="p-03.edit-cancel" @click="emit('cancel')">取消</el-button>
        <el-button type="primary" data-jjui-action="p-03.edit-submit" @click="submitEdit">保存</el-button>
      </el-space>
    </template>
  </el-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from "vue";
import type { FormInstance, FormRules } from "element-plus";

// 编辑实体属性弹框表单 Feature（判据正源: references/page-splitting.md——
// 弹框表单是封闭交互单元；初始值由入口下发，节点写回归入口）
const props = defineProps<{ open: boolean; initial: { label: string; description: string } | null }>();
const emit = defineEmits<{
  (e: "submit", values: { label: string; description: string }): void;
  (e: "cancel"): void;
}>();

const formRef = ref<FormInstance>();
const editForm = ref({ label: "", description: "" });
const editRules: FormRules = {
  label: [{ required: true, message: "请输入实体名称" }],
  description: [{ required: true, message: "请输入实体说明" }]
};

// 打开时装配初始值（校验判据: composition-layer.md 表单段）
watch(
  () => props.open,
  (open) => {
    if (open) editForm.value = props.initial ? { ...props.initial } : { label: "", description: "" };
  }
);

const submitEdit = () => {
  formRef.value?.validate((valid) => {
    if (!valid) return;
    emit("submit", { ...editForm.value });
  });
};
</script>
