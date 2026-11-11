import { Navigate, Outlet } from "react-router-dom";

export default function RouterIndex() {
  return <Navigate to="/dashboard" replace />;
}
