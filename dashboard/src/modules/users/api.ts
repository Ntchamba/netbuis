import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";
import type { AccountAction, AccountDetail, AccountPage, AccountQuery, AccountState, Zone } from "./types";
import { ACCOUNTS_PAGE_SIZE } from "./types";

export async function fetchAccounts(query: AccountQuery): Promise<AccountPage> {
  const params: Record<string, unknown> = { page: query.page, page_size: ACCOUNTS_PAGE_SIZE };
  if (query.type !== "all") params.type = query.type;
  if (query.zone !== null) params.zone = query.zone;
  if (query.q !== "") params.q = query.q;
  const res = await api.get<AccountPage>(ENDPOINTS.accounts, { params });
  return res.data;
}

/** Vue détaillée : `phone` (numéro complet) n'est renvoyé qu'à l'Administrateur complet. */
export async function fetchAccount(id: number): Promise<AccountDetail> {
  const res = await api.get<AccountDetail>(`${ENDPOINTS.accounts}${id}/`);
  return res.data;
}

export async function runAccountAction(id: number, action: AccountAction, reason?: string): Promise<AccountState> {
  const url = `${ENDPOINTS.accounts}${id}/`;
  switch (action) {
    case "block":
      return (await api.post<AccountState>(`${url}block/`, { reason })).data;
    case "unblock":
      return (await api.post<AccountState>(`${url}unblock/`, {})).data;
    case "restore":
      return (await api.post<AccountState>(`${url}restore/`, {})).data;
    case "delete":
      return (await api.delete<AccountState>(url, { data: { reason } })).data;
  }
}

const ZONE_LEVELS = ["ville_village", "quartier"] as const;

/** Zones proposées par le filtre (villes et quartiers), toutes pages lues, triées par nom. */
export async function fetchZoneOptions(): Promise<Zone[]> {
  const byId = new Map<number, Zone>();
  for (const level of ZONE_LEVELS) {
    for (let page = 1; page <= 20; page++) {
      const res = await api.get<{ next: string | null; results: Zone[] }>(ENDPOINTS.zones, {
        params: { level, page, page_size: 50 },
      });
      for (const z of res.data.results) byId.set(z.id, z);
      if (!res.data.next) break;
    }
  }
  return Array.from(byId.values()).sort((a, b) => a.name.localeCompare(b.name, "fr"));
}
