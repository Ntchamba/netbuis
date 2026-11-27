import { useQuery } from "@tanstack/react-query";
import { fetchSearchAnalytics } from "./api";

export const SEARCH_ANALYTICS_KEY = ["admin", "analytics", "searches"] as const;

export function useSearchAnalytics(days: number) {
  return useQuery({ queryKey: [...SEARCH_ANALYTICS_KEY, days], queryFn: () => fetchSearchAnalytics(days), retry: false });
}
