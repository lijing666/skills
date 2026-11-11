export type Customer = {
  id: string;
  name: string;
  status: "active" | "inactive";
  region: string;
  owner: string;
};

export const customers: Customer[] = [
  { id: "C-001", name: "客户一", status: "active", region: "华南", owner: "李四" },
  { id: "C-002", name: "客户二", status: "active", region: "华北", owner: "王五" },
  { id: "C-003", name: "客户三", status: "inactive", region: "西南", owner: "赵六" },
  { id: "C-004", name: "客户四", status: "active", region: "华东", owner: "张三" },
  { id: "C-005", name: "客户五", status: "active", region: "华南", owner: "李四" },
  { id: "C-006", name: "客户六", status: "inactive", region: "华北", owner: "王五" },
  { id: "C-007", name: "客户七", status: "active", region: "西南", owner: "赵六" },
  { id: "C-008", name: "客户八", status: "active", region: "华东", owner: "张三" },
  { id: "C-009", name: "客户九", status: "inactive", region: "华南", owner: "李四" },
  { id: "C-010", name: "客户十", status: "active", region: "华北", owner: "王五" },
  { id: "C-011", name: "客户十一", status: "active", region: "西南", owner: "赵六" },
  { id: "C-012", name: "客户十二", status: "inactive", region: "华东", owner: "张三" },
  { id: "C-013", name: "客户十三", status: "active", region: "华南", owner: "李四" },
  { id: "C-014", name: "客户十四", status: "active", region: "华北", owner: "王五" },
  { id: "C-015", name: "客户十五", status: "inactive", region: "西南", owner: "赵六" },
  { id: "C-016", name: "客户十六", status: "active", region: "华东", owner: "张三" },
  { id: "C-017", name: "客户十七", status: "active", region: "华南", owner: "李四" },
  { id: "C-018", name: "客户十八", status: "inactive", region: "华北", owner: "王五" },
  { id: "C-019", name: "客户十九", status: "active", region: "西南", owner: "赵六" },
  { id: "C-020", name: "客户二十", status: "active", region: "华东", owner: "张三" },
  { id: "C-021", name: "客户二十一", status: "inactive", region: "华南", owner: "李四" },
  { id: "C-022", name: "客户二十二", status: "active", region: "华北", owner: "王五" },
  { id: "C-023", name: "客户二十三", status: "active", region: "西南", owner: "赵六" },
  { id: "C-024", name: "客户二十四", status: "inactive", region: "华东", owner: "张三" },
  { id: "C-025", name: "客户二十五", status: "active", region: "华南", owner: "李四" },
  { id: "C-026", name: "客户二十六", status: "active", region: "华北", owner: "王五" }
];

export const customerMetrics = [
  { id: "m-001", label: "客户总数", value: customers.length },
  { id: "m-002", label: "启用客户", value: customers.filter((item) => item.status === "active").length },
  { id: "m-003", label: "停用客户", value: customers.filter((item) => item.status === "inactive").length }
];
