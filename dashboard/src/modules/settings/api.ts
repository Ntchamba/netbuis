import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";
import type { Setting } from "./types";

export async function fetchSettings(): Promise<Setting[]> {
  const res = await api.get<Setting[]>(ENDPOINTS.settings);
  return res.data;
}

export async function updateSetting(key: string, value: number): Promise<Setting> {
  const res = await api.patch<Setting>(`${ENDPOINTS.settings}${encodeURIComponent(key)}/`, { value });
  return res.data;
}
