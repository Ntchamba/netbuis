import type { ReactNode } from "react";
import { useAuth } from "./useAuth";

/** Droits renvoyés par le serveur (/api/admin/me/). Le dashboard ne décide jamais seul : refus par défaut. */
export function usePermissions() {
  const { me } = useAuth();
  const permissions = me?.permissions ?? [];
  const roles = me?.roles ?? [];
  return {
    permissions,
    roles,
    can: (code: string) => permissions.includes(code),
    hasRole: (role: string) => roles.includes(role),
  };
}

/** Affiche les enfants seulement si le serveur a accordé la permission. */
export function Can({ permission, children, fallback = null }: { permission: string; children: ReactNode; fallback?: ReactNode }) {
  const { can } = usePermissions();
  return <>{can(permission) ? children : fallback}</>;
}
