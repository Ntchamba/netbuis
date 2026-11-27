import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";
import { setAccessToken } from "../../auth/tokenStorage";
import type { AccessResponse, AdminMe } from "./types";

export async function loginRequest(phone: string, password: string): Promise<void> {
  const res = await api.post<AccessResponse>(ENDPOINTS.login, { phone, password });
  setAccessToken(res.data.access);
}

export async function fetchMe(): Promise<AdminMe> {
  const res = await api.get<AdminMe>(ENDPOINTS.me);
  return res.data;
}

export async function logoutRequest(): Promise<void> {
  await api.post(ENDPOINTS.logout, {});
}
