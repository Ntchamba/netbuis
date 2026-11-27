// Formes exactes de docs/api/openapi.yaml : AdminStats, HighTraffic, Revenue, BusinessRequest (extrait).
export interface HighTraffic {
  id: number;
  name: string;
  calls_per_day: number;
}

export interface Revenue {
  amount: number;
  currency: string;
  /** true : chiffre non disponible (paiements non branchés), à ne pas afficher comme un vrai zéro. */
  unavailable: boolean;
}

export interface AdminStats {
  accounts_total: number;
  accounts_new_week: number;
  active_businesses: number;
  neighborhoods_covered: number;
  pending_requests: number;
  calls_week: number;
  searches_week: number;
  subscribers: number;
  subscription_threshold: number;
  high_traffic_count: number;
  high_traffic: HighTraffic[];
  revenue_month: Revenue;
}

/** Champs utilisés par « Demandes récentes » (le numéro, même masqué, n'est pas repris). */
export interface RecentRequest {
  id: number;
  name: string;
  status: string;
  zone_name: string;
  created_at: string;
}

export interface RequestPage {
  count: number;
  next: string | null;
  results: RecentRequest[];
}
