import { createRouter, createWebHistory } from "vue-router";
import AdminLayout from "../layouts/AdminLayout.vue";
import Dashboard from "../pages/p-01-dashboard/index.vue";
import CustomerList from "../pages/p-02-customer-list/index.vue";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: "/",
      component: AdminLayout,
      children: [
        { path: "", redirect: "/dashboard" },
        { path: "dashboard", component: Dashboard },
        { path: "customers", component: CustomerList }
      ]
    }
  ]
});

export default router;
