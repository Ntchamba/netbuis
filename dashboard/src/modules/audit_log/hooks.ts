import { useQuery } from "@tanstack/react-query";
import { fetchAdminOptions, fetchAudit } from "./api";
import type { AuditQuery } from "./types";

export const AUDIT_KEY = ["admin", "audit"] as const;

/** `enabled` faux = aucune requête (filtres invalides). */
export function useAudit(query: AuditQuery, enabled: boolean) {
  return useQuery({ queryKey: [...AUDIT_KEY, "list", query], queryFn: () => fetchAudit(query), enabled, retry: false });
}

/** Seulement pour l'Administrateur complet (sinon 403) : `enabled` vient du droit lu depuis le serveur. */
export function useAdminOptions(enabled: boolean) {
  return useQuery({ queryKey: [...AUDIT_KEY, "admin-options"], queryFn: fetchAdminOptions, enabled, staleTime: 5 * 60_000, retry: false });
}
