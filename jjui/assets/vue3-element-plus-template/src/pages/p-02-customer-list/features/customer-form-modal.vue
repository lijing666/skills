<template>
  <el-dialog :model-value="open" :title="title" width="480px" @update:model-value="emit('cancel')">
    <el-form ref="formRef" :model="formState" :rules="formRules" label-position="left" label-width="var(--form-label-width)">
      <el-form-item label="客户名称" prop="name">
        <el-input v-model="formState.name" placeholder="请输入客户名称" data-jjui-action="p-02.form-name" />
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="formState.status" style="width: 100%" data-jjui-action="p-02.form-status">
          <el-option label="启用" value="active" />
          <el-option label="停用" value="inactive" />
        </el-select>
      </el-form-item>
      <el-form-item label="地区" prop="region">
        <el-select v-model="formState.region" style="width: 100%" data-jjui-action="p-02.form-region">
          <el-option v-for="region in REGIONS" :key="region" :label="region" :value="region" />
        </el-select>
      </el-form-item>
      <el-form-item label="负责人" prop="owner">
        <el-input v-model="formState.owner" placeholder="请输入负责人" data-jjui-action="p-02.form-owner" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button data-jjui-action="p-02.create-cancel" @click="emit('cancel')">取消</el-button>
      <el-button type="primary" data-jjui-action="p-02.create-submit" @click="submitForm">{{ initial?.id ? "保存" : "创建" }}</el-button>
    </template>
  </el-dialog>
</template>

<script setup lang="ts">
import { reactive, ref, watch } from "vue";
import type { CustomerInput } from "../../../services/customer-service";

// 新建/编辑客户弹框表单 Feature（判据正源: references/page-splitting.md——
// 弹框表单是封闭交互单元；初始值由入口下发，服务写入归入口）
const props = defineProps<{
  open: boolean;
  title: string;
  initial: (CustomerInput & { id?: string }) | null;
}>();
const emit = defineEmits<{
  (e: "submit", values: CustomerInput): void;
  (e: "cancel"): void;
}>();

const REGIONS = ["华南", "华北", "华东", "西南"];
const formRef = ref();
const formState = reactive({ name: "", status: "active", region: "华南", owner: "" });
const formRules = {
  name: [{ required: true, message: "请输入客户名称", trigger: "blur" }],
  status: [{ required: true, message: "请选择状态", trigger: "change" }],
  region: [{ required: true, message: "请选择地区", trigger: "change" }],
  owner: [{ required: true, message: "请输入负责人", trigger: "blur" }]
};

// 打开时装配初始值：编辑带入当前行，新建回默认（校验判据: composition-layer.md 表单段）
watch(
  () => props.open,
  (open) => {
    if (open) {
      Object.assign(formState, props.initial ?? { name: "", status: "active", region: "华南", owner: "" });
    }
  }
);

const submitForm = () => {
  formRef.value?.validate((valid: boolean) => {
    if (!valid) return;
    emit("submit", { ...formState });
  });
};
</script>
