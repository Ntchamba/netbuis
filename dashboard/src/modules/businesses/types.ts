// Formes exactes de docs/api/openapi.yaml : BusinessRequest, PaginatedBusinessRequestList, RequestDecision, Reject.
export type TypeCompte = "boutique" | "entreprise" | "particulier_vendeur" | "prestataire_service" | "structure";

export interface BusinessRequest {
  id: number;
  type: string;
  type_compte: TypeCompte;
  name: string;
  status: string;
  owner_id: number;
  owner_name: string;
  /** Numéro masqué par le serveur (« +237 6•• •• •• 12 ») : le dashboard n'en affiche jamais d'autre. */
  phone_masked: string;
  zone: number;
  zone_name: string;
  repere: string;
  description: string;
  representant_nom: string;
  forme_juridique: string;
  rccm: string;
  categorie_service: number | null;
  categorie_service_name: string | null;
  categorie_service_libre: string;
  cni_verifiee: boolean;
  /** Photos publiques. */
  photo_url: string | null;
  representant_photo_url: string | null;
  /** URL signées temporaires (5 min), liées à l'admin : jamais préchargées, jamais conservées. */
  cni_url: string | null;
  diplome_url: string | null;
  created_at: string;
}

export interface BusinessRequestPage {
  count: number;
  next: string | null;
  previous?: string | null;
  results: BusinessRequest[];
}

export interface RequestDecision {
  id: number;
  status: string;
  cni_verifiee: boolean;
  motif_rejet: string;
}

export const REASON_MAX_LENGTH = 1000;
export const REQUESTS_PAGE_SIZE = 20;
