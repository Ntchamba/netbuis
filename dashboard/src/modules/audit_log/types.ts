// Formes du serveur : serializers/audit.py (AuditEntrySerializer). Le motif est déjà masqué côté serveur.
export interface AuditEntry {
  id: number;
  admin_id: number;
  admin_name: string;
  /** Code d'action (liste fermée du serveur, voir ACTION_LABELS). */
  action: string;
  /** Libellé fourni par le serveur ; le dashboard préfère son propre libellé français. */
  action_label?: string;
  /** Modèle de la cible, ex. « accounts.user ». */
  target_type: string;
  target_id: number;
  reason: string;
  created_at: string;
}

export interface AuditPage {
  count: number;
  next: string | null;
  results: AuditEntry[];
}

/** Valeurs envoyées au serveur ; chaîne vide = filtre absent. */
export interface AuditFilters {
  admin: string;
  action: string;
  from: string;
  to: string;
}

export interface AuditQuery extends AuditFilters {
  page: number;
}

export const EMPTY_FILTERS: AuditFilters = { admin: "", action: "", from: "", to: "" };
export const AUDIT_PAGE_SIZE = 20;

/** Libellé français de chaque action de la liste fermée du serveur (openapi : admin_audit_list). */
export const ACTION_LABELS: Record<string, string> = {
  accord_abonnement: "Accord d'un abonnement",
  attribution_role: "Attribution d'un rôle",
  blocage_compte: "Blocage d'un compte",
  consultation_numero: "Consultation du numéro complet d'un compte",
  creation_referentiel: "Création d'un élément de référentiel",
  deblocage_compte: "Déblocage d'un compte",
  desactivation_referentiel: "Désactivation d'un élément de référentiel",
  export_comptes: "Export CSV des comptes",
  moderation_contenu: "Modération d'un contenu",
  modification_referentiel: "Modification d'un élément de référentiel",
  modification_reglage: "Modification d'un réglage",
  reactivation_referentiel: "Réactivation d'un élément de référentiel",
  rejet_business: "Rejet d'un compte business",
  restauration_compte: "Restauration d'un compte",
  retrait_role: "Retrait d'un rôle",
  suppression_compte: "Suppression d'un compte",
  validation_business: "Validation d'un compte business",
};

/** Libellé français, ou le code brut si l'action est inconnue. */
export function actionLabel(code: string): string {
  return Object.prototype.hasOwnProperty.call(ACTION_LABELS, code) ? ACTION_LABELS[code]! : code;
}

export const ACCOUNT_TARGET = "accounts.user";
const TARGET_LABELS: Record<string, string> = {
  "accounts.user": "Compte",
  "business.businessprofile": "Profil business",
};
export function targetLabel(type: string): string {
  return Object.prototype.hasOwnProperty.call(TARGET_LABELS, type) ? TARGET_LABELS[type]! : type;
}
