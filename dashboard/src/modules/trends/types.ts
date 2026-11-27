// Forme de docs/api/openapi.yaml : GET /api/trends/?zone=<id>. Classement seulement : pas de compteurs.
export interface TrendZone {
  id: number;
  name: string;
}
export interface TrendProduct {
  id: number;
  name: string;
  rank: number;
}
export interface TrendBusiness {
  id: number;
  name: string;
  zone: TrendZone;
  rank: number;
}
export interface Trends {
  zone: TrendZone | null;
  computed_at: string | null;
  period_days: number | null;
  products: TrendProduct[];
  businesses: TrendBusiness[];
}
