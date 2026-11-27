import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";
import type { AdminStats, RecentRequest, RequestPage } from "./types";

export const RECENT_LIMIT = 5;
const PAGE_SIZE = 50;

export async function fetchStats(): Promise<AdminStats> {
  const res = await api.get<AdminStats>(ENDPOINTS.stats);
  return res.data;
}

async function page(n: number): Promise<RequestPage> {
  const res = await api.get<RequestPage>(ENDPOINTS.requests, { params: { type: "business", page: n, page_size: PAGE_SIZE } });
  return res.data;
}

/**
 * Les demandes arrivent des plus anciennes aux plus récentes : on lit la dernière page ;
 * si elle compte moins de 5 éléments et qu'une page précédente existe, on lit aussi
 * l'avant-dernière (3 requêtes au plus). On trie ensuite par date décroissante.
 */
export async function fetchRecentRequests(): Promise<RecentRequest[]> {
  const first = await page(1);
  let items = first.results;
  if (first.next) {
    const last = Math.ceil(first.count / PAGE_SIZE);
    const lastPage = await page(last);
    items = lastPage.results;
    if (items.length < RECENT_LIMIT && last > 1) {
      const before = await page(last - 1);
      items = [...before.results, ...items];
    }
  }
  return [...items]
    .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
    .slice(0, RECENT_LIMIT);
}
