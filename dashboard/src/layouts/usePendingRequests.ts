import { useQuery } from "@tanstack/react-query";
import { api } from "../api/client";
import { ENDPOINTS } from "../api/endpoints";
import { usePermissions } from "../auth/permissions";

export const PENDING_REFRESH_MS = 60_000;

/**
 * Nombre de demandes en attente (pastille). Silencieux : une erreur donne `null` (pastille masquée).
 * /api/admin/stats/ exige peut_voir_comptes : sans ce droit, aucune requête n'est envoyée.
 */
export function usePendingRequests(): number | null {
  const { can } = usePermissions();
  const enabled = can("peut_voir_demandes") && can("peut_voir_comptes");
  const query = useQuery({
    queryKey: ["admin", "stats", "pending_requests"],
    queryFn: async () => {
      const res = await api.get<{ pending_requests?: number }>(ENDPOINTS.stats);
      return res.data.pending_requests ?? null;
    },
    enabled,
    refetchInterval: PENDING_REFRESH_MS,
    retry: false,
  });
  if (!enabled || query.isError) return null;
  return typeof query.data === "number" ? query.data : null;
}
