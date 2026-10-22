// Formes de docs/api/openapi.yaml : routes /api/admin/calls/*.
export const ANSWER_PERMISSION = "peut_repondre_aux_appels";

export type CallState = "ringing" | "answered" | "ended" | "missed" | "declined" | "unavailable" | "cancelled";

export interface BusinessContext {
  id: number;
  name: string;
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
