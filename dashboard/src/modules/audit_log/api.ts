import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";
import type { AdminItem } from "../admins/types";
import type { AuditPage, AuditQuery } from "./types";
import { AUDIT_PAGE_SIZE } from "./types";

/** Lecture seule : ce module n'émet que des GET. */
export async function fetchAudit(query: AuditQuery): Promise<AuditPage> {
  const params: Record<string, unknown> = { page: query.page, page_size: AUDIT_PAGE_SIZE };
  if (query.admin !== "") params.admin = query.admin;
  if (query.action !== "") params.action = query.action;
  if (query.from !== "") params.from = query.from;
  if (query.to !== "") params.to = query.to;
  const res = await api.get<AuditPage>(ENDPOINTS.audit, { params });
  return res.data;
}

/** Administrateurs proposés par le filtre (nom seulement), toutes pages lues. */
export async function fetchAdminOptions(): Promise<Array<{ id: number; name: string }>> {
  const out: Array<{ id: number; name: string }> = [];
  for (let page = 1; page <= 20; page++) {
    const res = await api.get<{ next: string | null; results: AdminItem[] }>(ENDPOINTS.admins, { params: { page, page_size: 50 } });
    for (const a of res.data.results) out.push({ id: a.id, name: a.name });
    if (!res.data.next) break;
  }
  return out;
}
