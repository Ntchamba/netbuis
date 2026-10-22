import { useQuery } from "@tanstack/react-query";
import { fetchCities, fetchTrends } from "./api";

export const TRENDS_KEY = ["admin", "trends"] as const;

export function useCities() {
  return useQuery({ queryKey: [...TRENDS_KEY, "cities"], queryFn: fetchCities, staleTime: 5 * 60_000, retry: false });
}

export function useTrends(zone: number | null) {
  return useQuery({
    queryKey: [...TRENDS_KEY, zone],
    queryFn: () => fetchTrends(zone as number),
    enabled: zone !== null,
    retry: false,
  });
}
