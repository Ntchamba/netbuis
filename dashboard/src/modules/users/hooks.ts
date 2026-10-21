import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchAccount, fetchAccounts, fetchZoneOptions, runAccountAction } from "./api";
import type { AccountAction, AccountQuery } from "./types";

export const ACCOUNTS_KEY = ["admin", "accounts"] as const;

/**
 * Le numéro complet ne vit que dans le cache de la page détail : conservé 30 s après la sortie
 * de la page (≤ 1 min), toujours rechargé (chaque affichage est audité côté serveur, donc pas de
 * rechargement automatique au retour sur la fenêtre). Le cache entier est vidé à la déconnexion.
 */
export const ACCOUNT_DETAIL_GC_MS = 30_000;

export function useAccounts(query: AccountQuery) {
  return useQuery({ queryKey: [...ACCOUNTS_KEY, "list", query], queryFn: () => fetchAccounts(query), retry: false });
}

export function useAccount(id: number | null) {
  return useQuery({
    queryKey: [...ACCOUNTS_KEY, "detail", id],
    queryFn: () => fetchAccount(id as number),
    enabled: id !== null,
    staleTime: 0,
    gcTime: ACCOUNT_DETAIL_GC_MS,
    refetchOnWindowFocus: false,
    retry: false,
  });
}

export function useZoneOptions() {
  return useQuery({ queryKey: ["admin", "zone-options"], queryFn: fetchZoneOptions, staleTime: 5 * 60_000, retry: false });
}

export function useAccountAction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, action, reason }: { id: number; action: AccountAction; reason?: string }) => runAccountAction(id, action, reason),
    onSuccess: () =>
      Promise.all([
        qc.invalidateQueries({ queryKey: ACCOUNTS_KEY }),
        qc.invalidateQueries({ queryKey: ["admin", "stats"] }),
        qc.invalidateQueries({ queryKey: ["admin", "overview"] }),
      ]),
  });
}

/** Rafraîchit liste et détail (après un 409/404). */
export function useRefreshAccounts() {
  const qc = useQueryClient();
  return () => qc.invalidateQueries({ queryKey: ACCOUNTS_KEY });
}
