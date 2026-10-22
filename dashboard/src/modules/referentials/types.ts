// Formes de docs/api/openapi.yaml : Admin{Item,Sector,Subcategory,Product,Synonym,Zone}, FreeValues.

export type RefType = "zones" | "sectors" | "subcategories" | "service-categories" | "structure-types" | "products" | "synonyms";

export type ZoneLevel = "pays" | "region" | "departement" | "arrondissement" | "ville_village" | "quartier" | "repere";

export const ZONE_LEVEL_LABEL: Record<ZoneLevel, string> = {
  pays: "Pays",
  region: "Région",
  departement: "Département",
  arrondissement: "Arrondissement",
  ville_village: "Ville / village",
  quartier: "Quartier",
  repere: "Repère",
};

/** Niveaux acceptés pour les enfants d'une zone (même règle que le serveur : le niveau du parent est imposé). */
export const CHILD_LEVELS: Record<ZoneLevel, ZoneLevel[]> = {
  pays: ["region"],
  region: ["departement"],
  departement: ["arrondissement", "ville_village"],
  arrondissement: ["ville_village"],
  ville_village: ["quartier", "repere"],
  quartier: ["repere"],
  repere: [],
};

export interface Paginated<T> {
  count: number;
  next: string | null;
  previous?: string | null;
  results: T[];
}

export interface RefBase {
  id: number;
  is_active: boolean;
  updated_at: string;
}

export interface AdminItem extends RefBase {
  code: string;
  name: string;
  icon: string;
  order: number;
  /** Secteurs seulement : sous-catégories actives. */
  active_children_count?: number;
  /** Sous-catégories seulement. */
  sector?: number;
}

export interface AdminProduct extends RefBase {
  name: string;
  category: number | null;
  category_name: string | null;
  synonyms_count: number;
}

export interface AdminSynonym extends RefBase {
  term: string;
  product: number;
  product_name: string;
}

export interface AdminZone extends RefBase {
  name: string;
  level: ZoneLevel;
  parent: number | null;
  parent_name: string | null;
  official_code: string;
  order: number;
  latitude: number | null;
  longitude: number | null;
  active_children_count: number;
}

export type RefRow = AdminItem | AdminProduct | AdminSynonym | AdminZone;

export type StatusFilter = "all" | "active" | "inactive";
export type ActiveAction = "deactivate" | "reactivate";

export interface RefQuery {
  page: number;
  pageSize: number;
  q?: string;
  status?: StatusFilter;
  /** Filtres propres au type : level, parent (id ou « root »), sector, category, product. */
  extra?: Record<string, string | number | null | undefined>;
}

export interface FreeValue {
  value: string;
  normalized: string;
  count: number;
}

export interface FreeValues {
  secteur_libre: FreeValue[];
  categorie_service_libre: FreeValue[];
  structure_type_libre: FreeValue[];
}

export const PAGE_SIZE = 20;
export const TREE_PAGE_SIZE = 50;
export const REASON_MAX = 500;

export interface RefConfig {
  type: RefType;
  /** Titre de la section (pluriel). */
  title: string;
  /** Nom d'un élément (singulier, pour « Ajouter … »). */
  singular: string;
  description: string;
  searchLabel: string;
}

export const REF_CONFIGS: readonly RefConfig[] = [
  { type: "zones", title: "Zones", singular: "une zone", description: "Pays, régions, départements, villes, quartiers : le découpage géographique.", searchLabel: "Rechercher une zone" },
  { type: "sectors", title: "Secteurs", singular: "un secteur", description: "Les grands secteurs d'activité des commerces.", searchLabel: "Rechercher un secteur" },
  { type: "subcategories", title: "Sous-catégories", singular: "une sous-catégorie", description: "Les sous-catégories de chaque secteur.", searchLabel: "Rechercher une sous-catégorie" },
  { type: "service-categories", title: "Catégories de service", singular: "une catégorie de service", description: "Les métiers proposés par les prestataires de service.", searchLabel: "Rechercher une catégorie de service" },
  { type: "structure-types", title: "Types de structure", singular: "un type de structure", description: "Les formes de structure d'un commerce (boutique, société…).", searchLabel: "Rechercher un type de structure" },
  { type: "products", title: "Produits du catalogue", singular: "un produit", description: "Le catalogue des produits que les commerçants peuvent proposer.", searchLabel: "Rechercher un produit" },
  { type: "synonyms", title: "Synonymes", singular: "un synonyme", description: "Les autres mots pour désigner un produit, utilisés par la recherche.", searchLabel: "Rechercher un synonyme" },
];

export function configFor(type: string | undefined): RefConfig | undefined {
  return REF_CONFIGS.find((c) => c.type === type);
}

/** Nom affichable d'une ligne (nom, ou terme pour un synonyme). */
export function rowName(row: RefRow): string {
  return "term" in row ? row.term : row.name;
}
