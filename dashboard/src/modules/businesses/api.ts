import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";
import type { BusinessRequestPage, RequestDecision } from "./types";
import { REQUESTS_PAGE_SIZE } from "./types";

export async function fetchBusinessRequests(page: number): Promise<BusinessRequestPage> {
  const res = await api.get<BusinessRequestPage>(ENDPOINTS.requests, {
    params: { type: "business", page, page_size: REQUESTS_PAGE_SIZE },
  });
  return res.data;
}

export async function approveRequest(id: number): Promise<RequestDecision> {
  const res = await api.post<RequestDecision>(`${ENDPOINTS.requests}${id}/approve/`, {});
  return res.data;
}

export async function rejectRequest(id: number, reason: string): Promise<RequestDecision> {
  const res = await api.post<RequestDecision>(`${ENDPOINTS.requests}${id}/reject/`, { reason });
  return res.data;
}

/**
 * Chemin relatif d'une pièce privée, tiré de l'URL signée reçue. Refuse toute URL qui ne pointe
 * pas vers la route des pièces privées : le jeton d'accès admin n'est jamais envoyé ailleurs.
 */
export function privateFilePath(url: string): string | null {
  let pathname: string;
  try {
    pathname = new URL(url, "http://local.invalid").pathname;
  } catch {
    return null;
  }
  const prefix = ENDPOINTS.privateFilesPrefix;
  if (!pathname.startsWith(prefix)) return null;
  const token = pathname.slice(prefix.length).replace(/\/$/, "");
  if (token === "" || token.includes("/")) return null;
  return `${prefix}${token}/`;
}

/** Télécharge la pièce avec le jeton d'accès (intercepteur du client) ; le résultat est un blob local. */
export async function fetchPrivateFile(url: string): Promise<Blob> {
  const path = privateFilePath(url);
  if (!path) throw new Error("lien invalide");
  const res = await api.get<Blob>(path, { responseType: "blob" });
  return res.data;
}
