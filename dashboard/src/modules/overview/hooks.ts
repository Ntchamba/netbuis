import { useQuery } from "@tanstack/react-query";
import { usePermissions } from "../../auth/permissions";
import { fetchRecentRequests, fetchStats } from "./api";

/** Rafraîchissement au plus toutes les 60 s. */
export const OVERVIEW_REFRESH_MS = 60_000;

export function useAdminStats() {
  return useQuery({ queryKey: ["admin", "overview", "stats"], queryFn: fetchStats, refetchInterval: OVERVIEW_REFRESH_MS, retry: false });
}

/** Chargées seulement si l'administrateur a le droit de voir les demandes. */
export function useRecentRequests() {
  const { can } = usePermissions();
  return useQuery({
    queryKey: ["admin", "overview", "recent_requests"],
    queryFn: fetchRecentRequests,
    enabled: can("peut_voir_demandes"),
    refetchInterval: OVERVIEW_REFRESH_MS,
    retry: false,
  });
}
