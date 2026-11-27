import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../auth/useAuth";
import { Spinner } from "../components/ui";
import { ForbiddenPage, LoadErrorPage } from "../modules/auth";
import { PATHS } from "./paths";

export function ProtectedRoute() {
  const { status } = useAuth();
  const location = useLocation();
  if (status === "loading") {
    return (
      <div className="flex min-h-screen items-center justify-center bg-bg" role="status" aria-label="Chargement">
        <Spinner size={24} />
      </div>
    );
  }
  if (status === "error") return <LoadErrorPage />;
  if (status === "forbidden") return <ForbiddenPage />;
  if (status === "anonymous") {
    return <Navigate to={PATHS.login} replace state={{ from: location.pathname + location.search }} />;
  }
  return <Outlet />;
}
