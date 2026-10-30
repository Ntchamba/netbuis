import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";
import type { AdminCreateInput, AdminCreated, AdminItem, AdminPage, AdminRole } from "./types";
import { ADMINS_PAGE_SIZE } from "./types";

export async function fetchAdmins(page: number): Promise<AdminPage> {
  const res = await api.get<AdminPage>(ENDPOINTS.admins, { params: { page, page_size: ADMINS_PAGE_SIZE } });
  return res.data;
}

export async function createAdmin(input: AdminCreateInput): Promise<AdminCreated> {
  const res = await api.post<AdminCreated>(ENDPOINTS.admins, input);
  return res.data;
}

export async function changeAdminRole(id: number, role: AdminRole): Promise<AdminItem> {
  const res = await api.patch<AdminItem>(`${ENDPOINTS.admins}${id}/`, { role });
  return res.data;
}

export async function removeAdminRole(id: number, reason: string): Promise<AdminItem> {
  const res = await api.delete<AdminItem>(`${ENDPOINTS.admins}${id}/`, { data: { reason } });
  return res.data;
}
