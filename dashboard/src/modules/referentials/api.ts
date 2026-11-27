import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";
import type { ActiveAction, FreeValues, Paginated, RefQuery, RefRow, RefType } from "./types";

// Aucune fonction de suppression : les « suppressions » sont des désactivations (POST …/deactivate/).
const base = (type: RefType) => `${ENDPOINTS.referentials}${type}/`;

export async function fetchReferentials(type: RefType, query: RefQuery): Promise<Paginated<RefRow>> {
  const params: Record<string, unknown> = { page: query.page, page_size: query.pageSize };
  if (query.q) params.q = query.q;
  if (query.status === "active") params.is_active = true;
  if (query.status === "inactive") params.is_active = false;
  for (const [key, value] of Object.entries(query.extra ?? {})) {
    if (value !== null && value !== undefined && value !== "") params[key] = value;
  }
  const res = await api.get<Paginated<RefRow>>(base(type), { params });
  return res.data;
}

export async function createReferential(type: RefType, payload: Record<string, unknown>): Promise<RefRow> {
  return (await api.post<RefRow>(base(type), payload)).data;
}

export async function updateReferential(type: RefType, id: number, payload: Record<string, unknown>): Promise<RefRow> {
  return (await api.patch<RefRow>(`${base(type)}${id}/`, payload)).data;
}

export async function setReferentialActive(type: RefType, id: number, action: ActiveAction, reason?: string): Promise<RefRow> {
  const body = reason ? { reason } : {};
  return (await api.post<RefRow>(`${base(type)}${id}/${action}/`, body)).data;
}

export async function fetchFreeValues(): Promise<FreeValues> {
  return (await api.get<FreeValues>(`${ENDPOINTS.referentials}free-values/`)).data;
}
