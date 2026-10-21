// Formes de docs/api/openapi.yaml : AccountList, AccountDetail, AccountState, AuditEntry, Zone.
import type { BusinessRequest } from "../businesses/types";

export type AccountType = "simple" | "business";
export type AccountStatus = "actif" | "bloque" | "supprime";
/** Valeurs du filtre `type` du serveur. */
export type AccountFilter = "all" | "simple" | "business" | "blocked" | "deleted";
export type AccountAction = "block" | "unblock" | "delete" | "restore";

export interface AccountListItem {
  id: number;
  name: string;
  /** Numéro masqué par le serveur (« +237 6•• •• •• 41 ») : la liste n'en montre jamais d'autre. */
  phone_masked: string;
  type: AccountType;
  status: AccountStatus;
  is_admin: boolean;
  is_blocked: boolean;
  is_deleted: boolean;
  business_name: string | null;
  business_status: string | null;
  zone_id: number | null;
  zone_name: string | null;
  created_at: string;
}

export interface AccountPage {
  count: number;
  next: string | null;
  previous?: string | null;
  results: AccountListItem[];
}

export interface AuditEntry {
  action: string;
  label: string;
  /** Motif tel que fourni à l'API. */
  reason: string;
  admin_id: number;
  admin_name: string;
  created_at: string;
}

export interface AccountDetail extends AccountListItem {
  /** Numéro complet : Administrateur complet seulement (audité côté serveur), sinon null. */
  phone: string | null;
  language: string;
  blocked_reason: string;
  blocked_at: string | null;
  deleted_at: string | null;
  roles: string[];
  business: BusinessRequest | null;
  status_history: AuditEntry[];
  recent_audit: AuditEntry[];
}

export interface AccountState {
  id: number;
  status: AccountStatus;
  is_blocked: boolean;
  is_deleted: boolean;
  blocked_reason: string;
  deleted_at: string | null;
}

export interface Zone {
  id: number;
  name: string;
  level: string;
  parent: number | null;
}

export interface AccountQuery {
  type: AccountFilter;
  zone: number | null;
  q: string;
  page: number;
}

export const ACCOUNTS_PAGE_SIZE = 20;
/** Limites du serveur (AccountReason). */
export const BLOCK_REASON_MAX = 255;
export const DELETE_REASON_MAX = 1000;
