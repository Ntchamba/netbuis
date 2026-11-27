import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";
import type { CallAnalytics } from "./types";

/** Lecture seule : ce module n'émet que des GET. */
export async function fetchCallAnalytics(days: number): Promise<CallAnalytics> {
  const res = await api.get<CallAnalytics>(ENDPOINTS.analyticsCalls, { params: { days } });
  return res.data;
}
