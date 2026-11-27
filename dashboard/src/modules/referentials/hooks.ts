import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { createReferential, fetchFreeValues, fetchReferentials, setReferentialActive, updateReferential } from "./api";
import type { ActiveAction, RefQuery, RefType } from "./types";

export const REFERENTIALS_KEY = ["admin", "referentials"] as const;

export function useReferentials(type: RefType, query: RefQuery, enabled = true) {
  return useQuery({
    queryKey: [...REFERENTIALS_KEY, type, "list", query],
    queryFn: () => fetchReferentials(type, query),
    enabled,
    retry: false,
    placeholderData: keepPreviousData,
  });
}

export function useFreeValues() {
  return useQuery({ queryKey: [...REFERENTIALS_KEY, "free-values"], queryFn: fetchFreeValues, retry: false });
}

export function useRefreshReferentials() {
  const qc = useQueryClient();
  return () => qc.invalidateQueries({ queryKey: REFERENTIALS_KEY });
}

/** Après une écriture, toutes les listes, arbres et valeurs libres sont rechargés. */
export function useCreateReferential(type: RefType) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (payload: Record<string, unknown>) => createReferential(type, payload),
    onSuccess: () => qc.invalidateQueries({ queryKey: REFERENTIALS_KEY }),
  });
}

export function useUpdateReferential(type: RefType) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, payload }: { id: number; payload: Record<string, unknown> }) => updateReferential(type, id, payload),
    onSuccess: () => qc.invalidateQueries({ queryKey: REFERENTIALS_KEY }),
  });
}

export function useSetActive(type: RefType) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, action, reason }: { id: number; action: ActiveAction; reason?: string }) => setReferentialActive(type, id, action, reason),
    onSuccess: () => qc.invalidateQueries({ queryKey: REFERENTIALS_KEY }),
  });
}
