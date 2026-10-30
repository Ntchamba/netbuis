// Forme de docs/api/openapi.yaml : GET /api/admin/analytics/searches/ (agrégats, jamais de compte).
export interface TermCount {
  term: string;
  count: number;
}

export interface SearchAnalytics {
  days: number;
  since: string;
  total_searches: number;
  total_without_results: number;
  top_terms: TermCount[];
  no_result_terms: TermCount[];
}

/** Périodes proposées (le serveur accepte 1 à 90 jours, 7 par défaut). */
export const PERIOD_OPTIONS = [
  { value: "7", label: "7 derniers jours" },
  { value: "14", label: "14 derniers jours" },
  { value: "30", label: "30 derniers jours" },
  { value: "90", label: "90 derniers jours" },
] as const;
export const DEFAULT_DAYS = 7;
