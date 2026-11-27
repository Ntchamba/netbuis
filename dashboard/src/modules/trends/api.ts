import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";
import type { TrendZone, Trends } from "./types";

/** Tendances d'une ville : le serveur accepte le jeton d'un administrateur (compte connecté non bloqué). */
export async function fetchTrends(zone: number): Promise<Trends> {
  const res = await api.get<Trends>(ENDPOINTS.trends, { params: { zone } });
  return res.data;
}

/** Villes proposées par le sélecteur (toutes pages lues), triées par nom. */
export async function fetchCities(): Promise<TrendZone[]> {
  const out: TrendZone[] = [];
  for (let page = 1; page <= 20; page++) {
    const res = await api.get<{ next: string | null; results: TrendZone[] }>(ENDPOINTS.zones, {
      params: { level: "ville_village", page, page_size: 50 },
    });
    for (const z of res.data.results) out.push({ id: z.id, name: z.name });
    if (!res.data.next) break;
  }
  return out.sort((a, b) => a.name.localeCompare(b.name, "fr"));
}
