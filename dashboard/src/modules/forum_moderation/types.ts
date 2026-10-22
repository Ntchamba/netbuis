// Formes exactes de docs/api/openapi.yaml : ReportRow, ReasonCount, PaginatedReportRowList, ModerationAction,
// ForbiddenWord, PaginatedForbiddenWordList. Aucune identité de signalant n'existe dans ces types.
export type TargetType = "post" | "comment" | "business";
export type ReasonCode = "spam" | "arnaque" | "contenu_inapproprie" | "autre";
export type ModerationActionKind = "hide" | "restore" | "delete";
export type StatusFilter = "" | "actif" | "masque" | "supprime";
export type TypeFilter = "" | TargetType;

export interface ReasonCount {
  reason: ReasonCode;
  count: number;
}

export interface ReportRow {
  target_type: TargetType;
  target_id: number;
  /** Publication/commentaire : actif, masque, supprime. Commerce : statut de son compte. */
  content_status: string;
  /** Texte tronqué par le serveur (numéros masqués) : affiché en texte simple, jamais en HTML. */
  preview: string;
  media_type: "image" | "video" | null;
  post_id: number | null;
  business_id: number;
  business_name: string;
  author_id: number;
  author_name: string;
  /** Numéro masqué par le serveur : le dashboard n'en affiche jamais d'autre. */
  author_phone_masked: string;
  reasons: ReasonCount[];
  /** Nombre de signalants distincts (jamais leur identité). */
  reporters_count: number;
  first_reported_at: string;
  last_reported_at: string;
}

export interface ReportPage {
  count: number;
  next: string | null;
  previous?: string | null;
  results: ReportRow[];
}

export interface ForbiddenWord {
  id: number;
  word: string;
  created_at: string;
}

export interface ForbiddenWordPage {
  count: number;
  next: string | null;
  previous?: string | null;
  results: ForbiddenWord[];
}

export const REPORTS_PAGE_SIZE = 20;
export const WORDS_PAGE_SIZE = 50;
export const REASON_MAX_LENGTH = 900;
export const WORD_MIN = 2;
export const WORD_MAX = 60;

export const TARGET_LABELS: Record<TargetType, string> = { post: "Publication", comment: "Commentaire", business: "Commerce" };
export const REASON_LABELS: Record<ReasonCode, string> = {
  spam: "Spam",
  arnaque: "Arnaque",
  contenu_inapproprie: "Contenu inapproprié",
  autre: "Autre",
};
