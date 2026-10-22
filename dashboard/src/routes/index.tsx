import { Route, Routes } from "react-router-dom";
import { AdminLayout } from "../layouts/AdminLayout";
import { AuthLayout } from "../layouts/AuthLayout";
import { LoginPage } from "../modules/auth";
import { BusinessesPage } from "../modules/businesses";
import { FreeValuesPage, ReferentialsIndexPage, ReferentialTypePage } from "../modules/referentials";
import { AdminsPage } from "../modules/admins";
import { AuditLogPage } from "../modules/audit_log";
import { ReportsPage } from "../modules/forum_moderation";
import { CallsAnalyticsPage } from "../modules/calls_analytics";
import { SearchAnalyticsPage } from "../modules/search_analytics";
import { TrendsPage } from "../modules/trends";
import { SubscriptionsPage } from "../modules/subscriptions";
import { SettingsPage } from "../modules/settings";
import { OverviewPage } from "../modules/overview";
import { UserDetailPage, UsersPage } from "../modules/users";
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
                <UsersPage />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.compte}
            element={
              <RequirePermission permission="peut_voir_comptes">
                <UserDetailPage />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.referentiels}
            element={
              <RequirePermission permission="peut_gerer_referentiels">
                <ReferentialsIndexPage />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.referentielsAExaminer}
            element={
              <RequirePermission permission="peut_gerer_referentiels">
                <FreeValuesPage />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.referentiel}
            element={
              <RequirePermission permission="peut_gerer_referentiels">
                <ReferentialTypePage />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.reglages}
            element={
              <RequirePermission permission="peut_modifier_reglages">
                <SettingsPage />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.administrateurs}
            element={
              <RequirePermission permission="peut_gerer_admins">
                <AdminsPage />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.audit}
            element={
              <RequirePermission permission="peut_voir_comptes">
                <AuditLogPage />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.recherches}
            element={
              <RequirePermission permission="peut_voir_comptes">
                <SearchAnalyticsPage />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.appels}
            element={
              <RequirePermission permission="peut_voir_comptes">
                <CallsAnalyticsPage />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.tendances}
            element={
              <RequirePermission permission="peut_voir_comptes">
                <TrendsPage />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.moderation}
            element={
              <RequirePermission permission="peut_moderer_contenu">
                <ReportsPage />
              </RequirePermission>
            }
          />
          <Route
            path={PATHS.equipe}
            element={
              <RequirePermission permission="peut_voir_comptes">
                <SubscriptionsPage />
              </RequirePermission>
            }
          />
        </Route>
      </Route>
    </Routes>
  );
}
