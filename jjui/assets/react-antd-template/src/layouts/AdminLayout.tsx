import { Breadcrumb, Menu, Space } from "antd";
import { BellOutlined, ClusterOutlined, DashboardOutlined, PartitionOutlined, TeamOutlined, UserOutlined } from "@ant-design/icons";
import { Link, Outlet, useLocation } from "react-router-dom";

const menuItems = [
  { key: "/dashboard", icon: <DashboardOutlined />, label: <Link to="/dashboard">总览</Link> },
  { key: "/customers", icon: <TeamOutlined />, label: <Link to="/customers">客户列表</Link> },
  { key: "/canvas", icon: <PartitionOutlined />, label: <Link to="/canvas">实体画布</Link> },
  { key: "/workbench", icon: <ClusterOutlined />, label: <Link to="/workbench">实体工作台</Link> }
];

export default function AdminLayout() {
  const location = useLocation();
  const current = menuItems.find((item) => item.key === location.pathname);

  return (
    <div className="admin-layout">
      <aside className="admin-sider">
        <div className="admin-sider__brand">__PRODUCT_ID__ · __BUSINESS__</div>
        <div className="admin-sider__menu">
          <Menu mode="inline" selectedKeys={[location.pathname]} items={menuItems} />
        </div>
      </aside>
      <div className="admin-main">
        <header className="admin-header">
          <Breadcrumb
            items={
              current
                ? [{ title: <Link to="/dashboard">首页</Link> }, { title: current.label }]
                : [{ title: "首页" }]
            }
          />
          <Space size="middle">
            <BellOutlined />
            <Space size={4}>
              <UserOutlined />
              <span>管理员</span>
            </Space>
          </Space>
        </header>
        <main className="admin-layout__content">
          <div className="admin-layout__page">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
