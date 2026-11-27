import type { RefType } from "../types";

export type PickerType = "sectors" | "subcategories" | "products";
export type FieldKind = "text" | "integer" | "decimal" | "level" | "picker";

export interface FieldDef {
  name: string;
  label: string;
  kind: FieldKind;
  required?: boolean;
  max?: number;
  min?: number;
  maxValue?: number;
  /** Fixé à la création, non modifiable ensuite (niveau, code, secteur, produit). */
  createOnly?: boolean;
  pattern?: RegExp;
  patternMessage?: string;
  picker?: PickerType;
  help?: string;
}

export const CODE_PATTERN = /^[a-z0-9]+(?:_[a-z0-9]+)*$/;
const CODE_MESSAGE = "Le code ne contient que des minuscules, des chiffres et des « _ » (exemple : vente_detail).";

const code = (max: number): FieldDef => ({
  name: "code",
  label: "Code",
  kind: "text",
  required: true,
  max,
  createOnly: true,
  pattern: CODE_PATTERN,
  patternMessage: CODE_MESSAGE,
  help: "Fixé à la création : il ne pourra plus être modifié.",
});
const itemFields = (codeMax: number): FieldDef[] => [
  code(codeMax),
  { name: "name", label: "Nom", kind: "text", required: true, max: 100 },
  { name: "icon", label: "Icône", kind: "text", max: 16 },
  { name: "order", label: "Ordre d'affichage", kind: "integer", min: 0 },
];

export const FIELDS: Record<RefType, FieldDef[]> = {
  zones: [
    { name: "level", label: "Niveau", kind: "level", required: true, createOnly: true, help: "Fixé à la création." },
    { name: "name", label: "Nom", kind: "text", required: true, max: 150 },
    { name: "official_code", label: "Code officiel", kind: "text", max: 30 },
    { name: "order", label: "Ordre d'affichage", kind: "integer", min: 0 },
    { name: "latitude", label: "Latitude", kind: "decimal", min: -90, maxValue: 90 },
    { name: "longitude", label: "Longitude", kind: "decimal", min: -180, maxValue: 180 },
  ],
  sectors: itemFields(50),
  subcategories: [
    { name: "sector", label: "Secteur", kind: "picker", picker: "sectors", required: true, createOnly: true },
    ...itemFields(60),
  ],
  "service-categories": itemFields(50),
  "structure-types": itemFields(50),
  products: [
    { name: "name", label: "Nom", kind: "text", required: true, max: 150 },
    { name: "category", label: "Sous-catégorie", kind: "picker", picker: "subcategories" },
  ],
  synonyms: [
    { name: "product", label: "Produit", kind: "picker", picker: "products", required: true, createOnly: true },
    { name: "term", label: "Synonyme", kind: "text", required: true, max: 150 },
  ],
};

/** Champ qui porte le nom de l'élément (sous lequel s'affiche « existe déjà »). */
export const nameFieldOf = (type: RefType): string => (type === "synonyms" ? "term" : "name");

/** Code proposé à partir d'un nom : minuscules, sans accents, mots reliés par « _ ». */
export function suggestCode(name: string): string {
  return name
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}
