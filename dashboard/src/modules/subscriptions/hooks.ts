import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchSubscriptions, grantSubscription } from "./api";
import type { SubscriptionFilter } from "./types";

export const SUBSCRIPTIONS_KEY = ["admin", "subscriptions"] as const;

export function useSubscriptions(filter: SubscriptionFilter, page: number) {
  return useQuery({ queryKey: [...SUBSCRIPTIONS_KEY, "list", filter, page], queryFn: () => fetchSubscriptions(filter, page), retry: false });
}

export function useGrantSubscription() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: grantSubscription,
    onSuccess: () => qc.invalidateQueries({ queryKey: SUBSCRIPTIONS_KEY }),
  });
}

export function useRefreshSubscriptions() {
  const qc = useQueryClient();
  return () => qc.invalidateQueries({ queryKey: SUBSCRIPTIONS_KEY });
}
