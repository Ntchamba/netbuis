// Formes de docs/api/openapi.yaml : admin_subscriptions_list / admin_subscriptions_grant.
export type SubscriptionFilter = "all" | "subscribed" | "unsubscribed" | "high_traffic";

export interface SubscriptionRow {
  /** Identifiant du compte business (profil). */
  id: number;
  name: string;
  zone_name: string | null;
  is_subscribed: boolean;
  subscription_end: string | null;
  calls_last_day: number;
  calls_count: number;
  high_traffic: boolean;
}

export interface SubscriptionPage {
  count: number;
  next: string | null;
  results: SubscriptionRow[];
}

export interface GrantInput {
  business_id: number;
  duration_days: number;
  reason: string;
}

export interface SubscriptionGranted {
  id: number;
  business_id: number;
  business_name: string;
  start: string;
  end: string;
  status: string;
  source: string;
  granted_by_id: number;
  granted_by_name: string;
}

export const SUBSCRIPTIONS_PAGE_SIZE = 20;
export const REASON_MAX = 1000;
export const MAX_DAYS = 366;
export const DAYS_PER_MONTH = 30;
export const MONTH_CHOICES = [1, 2, 3, 6, 12] as const;

/** Mois choisis → jours envoyés (30 × mois, jamais plus de 366). */
export function monthsToDays(months: number): number {
  return Math.min(months * DAYS_PER_MONTH, MAX_DAYS);
}
