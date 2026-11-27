import { useQuery } from "@tanstack/react-query";
import { fetchCallAnalytics } from "./api";

export const CALL_ANALYTICS_KEY = ["admin", "analytics", "calls"] as const;

export function useCallAnalytics(days: number) {
  return useQuery({ queryKey: [...CALL_ANALYTICS_KEY, days], queryFn: () => fetchCallAnalytics(days), retry: false });
}
