import { createApp } from "vue";
import ElementPlus from "element-plus";
import zhCn from "element-plus/es/locale/lang/zh-cn";
import App from "./App.vue";
import router from "./router";
import "element-plus/dist/index.css";
import "./styles/tokens.css";
import "./styles/admin.css";

const app = createApp(App);
app.use(router);
app.use(ElementPlus, { locale: zhCn });
app.mount("#app");
