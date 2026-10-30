import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";
import type { ForbiddenWord, ForbiddenWordPage, ModerationActionKind, ReportPage, ReportRow, StatusFilter, TargetType, TypeFilter } from "./types";
import { REPORTS_PAGE_SIZE, WORDS_PAGE_SIZE } from "./types";

export interface ReportQuery {
  status: StatusFilter;
  type: TypeFilter;
  page: number;
}

export async function fetchReports({ status, type, page }: ReportQuery): Promise<ReportPage> {
  const params: Record<string, string | number> = { page, page_size: REPORTS_PAGE_SIZE };
  if (status) params.status = status;
  if (type) params.type = type;
  const res = await api.get<ReportPage>(ENDPOINTS.reports, { params });
  return res.data;
}

export async function moderate(targetType: TargetType, targetId: number, action: ModerationActionKind, reason?: string): Promise<ReportRow> {
  const body = reason ? { reason } : {};
  const res = await api.post<ReportRow>(`${ENDPOINTS.reports}${targetType}/${targetId}/${action}/`, body);
  return res.data;
}

export async function fetchForbiddenWords(page: number): Promise<ForbiddenWordPage> {
  const res = await api.get<ForbiddenWordPage>(ENDPOINTS.forbiddenWords, { params: { page, page_size: WORDS_PAGE_SIZE } });
  return res.data;
}

export async function addForbiddenWord(word: string): Promise<ForbiddenWord> {
  const res = await api.post<ForbiddenWord>(ENDPOINTS.forbiddenWords, { word });
  return res.data;
}

export async function deleteForbiddenWord(id: number): Promise<void> {
  await api.delete(`${ENDPOINTS.forbiddenWords}${id}/`);
}
