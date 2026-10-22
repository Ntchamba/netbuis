import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";
import type { GrantInput, SubscriptionFilter, SubscriptionGranted, SubscriptionPage } from "./types";
import { SUBSCRIPTIONS_PAGE_SIZE } from "./types";

export async function fetchSubscriptions(filter: SubscriptionFilter, page: number): Promise<SubscriptionPage> {
  const params: Record<string, unknown> = { page, page_size: SUBSCRIPTIONS_PAGE_SIZE };
  if (filter !== "all") params.filter = filter;
  const res = await api.get<SubscriptionPage>(ENDPOINTS.subscriptions, { params });
  return res.data;
}

export async function grantSubscription(input: GrantInput): Promise<SubscriptionGranted> {
  const res = await api.post<SubscriptionGranted>(ENDPOINTS.subscriptions, input);
  return res.data;
}
