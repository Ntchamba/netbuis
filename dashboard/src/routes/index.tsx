import { Route, Routes } from "react-router-dom";
import { AdminLayout } from "../layouts/AdminLayout";
import { AuthLayout } from "../layouts/AuthLayout";
import { ComingSoonPage } from "../layouts/ComingSoonPage";
import { LoginPage } from "../modules/auth";
import { BusinessesPage } from "../modules/businesses";
import { OverviewPage } from "../modules/overview";
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
          {/* Pages provisoires : remplies par T083 (Comptes), T113 (Équipe). */}
          <Route
            path={PATHS.home}
            element={
              <RequirePermission permission="peut_voir_comptes">
                <OverviewPage />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.demandes}
            element={
              <RequirePermission permission="peut_voir_demandes">
                <BusinessesPage />
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
