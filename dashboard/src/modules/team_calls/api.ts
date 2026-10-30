import { api } from "../../api/client";
import type { AcceptResponse, AgentCallPage, CallContext, CallFilter } from "./types";
import { CALLS_PAGE_SIZE } from "./types";

const BASE = "/api/admin/calls/";
export const CALLS_STREAM_URL = `${BASE}stream/`;

/** `available` absent = simple battement de cœur. */
export async function sendPresence(available?: boolean): Promise<boolean> {
  const res = await api.post<{ available: boolean }>(`${BASE}presence/`, available === undefined ? {} : { available });
  return res.data.available;
}

export async function acceptCall(id: string): Promise<AcceptResponse> {
  return (await api.post<AcceptResponse>(`${BASE}sessions/${id}/accept/`, {})).data;
}

export async function declineCall(id: string): Promise<void> {
  await api.post(`${BASE}sessions/${id}/decline/`, {});
}

export async function endCall(id: string): Promise<void> {
  await api.post(`${BASE}sessions/${id}/end/`, {});
}

/** Fiche de l'appel en cours, avec les numéros (agent qui a répondu, appel `answered`). Jamais en cache HTTP. */
export async function fetchCallContext(id: string): Promise<CallContext> {
  return (await api.get<CallContext>(`${BASE}sessions/${id}/context/`)).data;
}

const STATES: Record<CallFilter, string | null> = { all: null, missed: "missed,declined", answered: "answered,ended" };

export async function fetchTeamCalls(filter: CallFilter, mine: number | null, page: number): Promise<AgentCallPage> {
  const params: Record<string, unknown> = { page, page_size: CALLS_PAGE_SIZE };
  const state = STATES[filter];
  if (state) params.state = state;
  if (mine !== null) params.agent = mine;
  return (await api.get<AgentCallPage>(BASE, { params })).data;
}

/** Code d'erreur métier d'une réponse 4xx/5xx (`call_taken`…), ou null. */
export function callErrorCode(error: unknown): string | null {
  const code = (error as { response?: { data?: { code?: unknown } } } | null)?.response?.data?.code;
  return typeof code === "string" ? code : null;
}
