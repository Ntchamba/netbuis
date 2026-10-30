// Formes de docs/api/openapi.yaml : routes /api/admin/calls/*.
export const ANSWER_PERMISSION = "peut_repondre_aux_appels";

export type CallState = "ringing" | "answered" | "ended" | "missed" | "declined" | "unavailable" | "cancelled";

export interface BusinessContext {
  id: number;
  name: string;
  /** Type de compte en clair (« Entreprise », « Particulier vendeur »…). Absent des anciens serveurs. */
  type_label?: string;
  kind?: "entreprise" | "particulier";
}

/** Événement `ringing` du flux : ni numéro, ni salle, ni jeton. */
export interface RingingEvent {
  session_id: string;
  state: CallState;
  caller_name: string;
  business: BusinessContext | null;
  expires_at: string | null;
  ring_seconds_left: number | null;
}

/** Appel en train de sonner, avec l'instant local de fin de sonnerie. */
export interface IncomingCall {
  sessionId: string;
  callerName: string;
  business: BusinessContext | null;
  /** Date locale (ms) de fin de sonnerie, ou null si le serveur n'en donne pas. */
  deadline: number | null;
}

export interface JitsiAccess {
  domain: string;
  room: string;
  jwt: string;
}

export interface AcceptResponse {
  session_id: string;
  caller_name: string;
  business: BusinessContext | null;
  jitsi: JitsiAccess;
}

/** Appel accepté : la salle n'est gardée qu'en mémoire. */
export interface ActiveCall {
  sessionId: string;
  callerName: string;
  business: BusinessContext | null;
  jitsi: JitsiAccess;
}

export interface CallError {
  code: string;
  message: string;
  session_id?: string;
}

export interface AgentCall {
  session_id: string;
  state: CallState;
  end_reason: string;
  caller_name: string;
  business: BusinessContext | null;
  agent: { id: number; name: string } | null;
  created_at: string;
  answered_at: string | null;
  ended_at: string | null;
}

export interface AgentCallPage {
  count: number;
  next: string | null;
  previous: string | null;
  results: AgentCall[];
}

export type CallFilter = "all" | "missed" | "answered";
export const CALLS_PAGE_SIZE = 20;

export type StreamStatus = "off" | "connecting" | "open" | "reconnecting" | "forbidden";

/** Fiche de l'appel en cours (GET .../context/) : SEULE réponse qui porte des numéros (D-30). Jamais stockée. */
export interface CallContext {
  session_id: string;
  state: CallState;
  caller: { name: string; phone: string };
  business: BusinessCard | null;
}

export interface BusinessCard {
  id: number;
  name: string;
  type_compte: string;
  type_label: string;
  kind: "entreprise" | "particulier";
  phone: string;
  owner_name: string;
  category: string | null;
  sous_categories: string[];
  zone_name: string;
  zone_parent_name: string | null;
  repere: string;
  description: string;
  representant_nom: string;
  forme_juridique: string;
  rccm: string;
  photo_url: string | null;
  representant_photo_url: string | null;
  status: string;
  cni_verifiee: boolean;
  motif_rejet: string;
  subscription: { active: boolean; end: string | null };
  reports_count: number;
  whatsapp_reports_count: number;
  calls_count: number;
  views_count: number;
  created_at: string;
  history: Array<{ action: string; label: string; reason: string; admin_name: string; created_at: string }>;
}
