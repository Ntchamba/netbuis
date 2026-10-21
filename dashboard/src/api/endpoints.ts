// Routes de l'API utilisées par le dashboard (openapi.yaml).
export const ENDPOINTS = {
  login: "/api/auth/admin/login/",
  refresh: "/api/auth/refresh/",
  logout: "/api/auth/logout/",
  me: "/api/admin/me/",
  stats: "/api/admin/stats/",
  requests: "/api/admin/requests/",
} as const;

/** Routes d'authentification : un 401 n'y déclenche jamais de rafraîchissement. */
export const AUTH_PATHS: readonly string[] = [ENDPOINTS.login, ENDPOINTS.refresh, ENDPOINTS.logout];
