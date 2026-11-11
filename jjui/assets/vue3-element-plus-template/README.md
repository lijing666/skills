# __PRODUCT_ID__ · __BUSINESS__ 管理后台原型

Vue3 + Element Plus 管理后台原型。

## 启动

```bash
npm install
npm run build
npm run preview -- --host 127.0.0.1 --port 4173
```

## 编辑边界

- `src/pages/` 内的生成页面由 jjui 维护。
- `src/custom/` 内的使用者扩展由人或设计师维护；模板再生成不得覆盖。
- 页面、区域、操作、动态数据使用 `data-jjui-*` 稳定锚点。
- `.jjui/page-plan.json` 是页面清单和文案/动态区分层的事实源。
- `.jjui/jjspec/bridge.json` 只登记启动契约和指针，不复制页面语义。
- `.jjui/jjspec/routes.json` 只是路由注册表；菜单结构仍以渲染态为准。
