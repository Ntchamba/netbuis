// Routes de l'API utilisées par le dashboard (openapi.yaml).
export const ENDPOINTS = {
  login: "/api/auth/admin/login/",
  refresh: "/api/auth/refresh/",
  logout: "/api/auth/logout/",
  me: "/api/admin/me/",
  stats: "/api/admin/stats/",
  requests: "/api/admin/requests/",
  accounts: "/api/admin/accounts/",
  zones: "/api/zones/",
  /** Réglages de la plateforme : …/<clé>/ (Administrateur complet). */
  settings: "/api/admin/settings/",
  /** Administrateurs : …/<id>/ (changer le rôle, retirer le rôle). */
  admins: "/api/admin/admins/",
  /** Journal d'audit, lecture seule (GET uniquement). */
  audit: "/api/admin/audit/",
  /** Référentiels modifiables (Administrateur complet) : …/<type>/, …/<type>/<id>/, …/deactivate/, …/reactivate/. */
  referentials: "/api/admin/referentials/",
  /** Export CSV des comptes (Administrateur complet, audité) : numéros masqués. */
  exportAccounts: "/api/admin/export/accounts.csv",
  /** Pièces privées (CNI, diplôme) : exigent le jeton d'accès admin. */
  privateFilesPrefix: "/api/admin/private-files/",
} as const;

/** Routes d'authentification : un 401 n'y déclenche jamais de rafraîchissement. */
export const AUTH_PATHS: readonly string[] = [ENDPOINTS.login, ENDPOINTS.refresh, ENDPOINTS.logout];
