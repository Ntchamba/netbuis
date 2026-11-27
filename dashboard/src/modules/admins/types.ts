// Formes de docs/api/openapi.yaml : Admin, AdminCreate, AdminCreated, RoleEnum.
export const ADMIN_ROLES = ["Validateur", "Administrateur complet"] as const;
export type AdminRole = (typeof ADMIN_ROLES)[number];

export interface AdminItem {
  id: number;
  name: string;
  /** Numéro masqué par le serveur : la liste n'en montre jamais d'autre. */
  phone_masked: string;
  roles: string[];
  status: "actif" | "bloque" | "supprime";
  created_at: string;
}

export interface AdminPage {
  count: number;
  next: string | null;
  results: AdminItem[];
}

export interface AdminCreateInput {
  phone: string;
  name: string;
  role: AdminRole;
}

/** Réponse de la création : `temporary_password` n'est renvoyé qu'une fois et ne doit jamais être conservé. */
export interface AdminCreated extends AdminItem {
  temporary_password: string;
}

export const ADMINS_PAGE_SIZE = 20;
export const NAME_MAX = 120;
