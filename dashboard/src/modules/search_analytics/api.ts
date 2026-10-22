import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";
import type { SearchAnalytics } from "./types";

/** Lecture seule : ce module n'émet que des GET. */
export async function fetchSearchAnalytics(days: number): Promise<SearchAnalytics> {
  const res = await api.get<SearchAnalytics>(ENDPOINTS.analyticsSearches, { params: { days } });
  return res.data;
}
