// Forme de docs/api/openapi.yaml : GET /api/admin/analytics/calls/ (agrégats : ni appelant ni commerçant).
export interface DayCount {
  date: string;
  count: number;
}

export interface CallAnalytics {
  days: number;
  since: string;
  total_calls: number;
  by_day: DayCount[];
  by_operator: { orange: number; mtn: number; unknown: number };
  by_platform: { android: number; ios: number };
  by_channel: { call: number; whatsapp: number };
}
