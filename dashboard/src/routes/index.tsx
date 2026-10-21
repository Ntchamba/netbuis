import { Route, Routes } from "react-router-dom";
import App from "../App";
import { AuthLayout } from "../layouts/AuthLayout";
import { LoginPage } from "../modules/auth";
import { PATHS } from "./paths";
import { ProtectedRoute } from "./ProtectedRoute";

export function AppRoutes() {
  return (
    <Routes>
      <Route element={<AuthLayout />}>
        <Route path={PATHS.login} element={<LoginPage />} />
      </Route>
      <Route element={<ProtectedRoute />}>
        <Route path={PATHS.home} element={<App />} />
      </Route>
    </Routes>
  );
}
