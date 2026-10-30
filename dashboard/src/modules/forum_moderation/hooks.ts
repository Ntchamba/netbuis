import { useCallback } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { addForbiddenWord, deleteForbiddenWord, fetchForbiddenWords, fetchReports, moderate, type ReportQuery } from "./api";
import type { ModerationActionKind, TargetType } from "./types";

export const REPORTS_KEY = ["admin", "reports"] as const;
export const WORDS_KEY = ["admin", "forbidden-words"] as const;

export function useReports(q: ReportQuery) {
  return useQuery({ queryKey: [...REPORTS_KEY, q.status, q.type, q.page], queryFn: () => fetchReports(q), retry: false });
}

export function useRefreshReports() {
  const qc = useQueryClient();
  return useCallback(() => qc.invalidateQueries({ queryKey: REPORTS_KEY }), [qc]);
}

export function useModerate() {
  const refresh = useRefreshReports();
  return useMutation({
    mutationFn: (v: { targetType: TargetType; targetId: number; action: ModerationActionKind; reason?: string }) =>
      moderate(v.targetType, v.targetId, v.action, v.reason),
    onSuccess: () => refresh(),
  });
}

export function useForbiddenWords(page: number) {
  return useQuery({ queryKey: [...WORDS_KEY, page], queryFn: () => fetchForbiddenWords(page), retry: false });
}

export function useRefreshWords() {
  const qc = useQueryClient();
  return useCallback(() => qc.invalidateQueries({ queryKey: WORDS_KEY }), [qc]);
}

export function useAddWord() {
  const refresh = useRefreshWords();
  return useMutation({ mutationFn: (word: string) => addForbiddenWord(word), onSuccess: () => refresh() });
}

export function useDeleteWord() {
  const refresh = useRefreshWords();
  return useMutation({ mutationFn: (id: number) => deleteForbiddenWord(id), onSuccess: () => refresh() });
}
