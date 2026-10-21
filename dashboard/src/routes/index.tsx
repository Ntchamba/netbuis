import { Route, Routes } from "react-router-dom";
import App from "../App";
import { AdminLayout } from "../layouts/AdminLayout";
import { AuthLayout } from "../layouts/AuthLayout";
import { ComingSoonPage } from "../layouts/ComingSoonPage";
import { LoginPage } from "../modules/auth";
import { PATHS } from "./paths";
import { ProtectedRoute } from "./ProtectedRoute";
import { RequirePermission } from "./RequirePermission";

export function AppRoutes() {
  return (
    <Routes>
      <Route element={<AuthLayout />}>
        <Route path={PATHS.login} element={<LoginPage />} />
      </Route>
      <Route element={<ProtectedRoute />}>
        <Route element={<AdminLayout />}>
          {/* Pages provisoires : remplies par T081 (Vue d'ensemble), T082 (Demandes), T083 (Comptes), T113 (Équipe). */}
          <Route path={PATHS.home} element={<App />} />
          <Route
            path={PATHS.demandes}
            element={
              <RequirePermission permission="peut_voir_demandes">
                <ComingSoonPage title="Demandes" />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.comptes}
            element={
              <RequirePermission permission="peut_voir_comptes">
                <ComingSoonPage title="Comptes" />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.equipe}
            element={
              <RequirePermission permission="peut_accorder_abonnement">
                <ComingSoonPage title="Équipe & abonnements" />
              </RequirePermission>
            }
          />
        </Route>
      </Route>
    </Routes>
  );
}
