// Forme de docs/api/openapi.yaml : Setting.
export interface Setting {
  key: string;
  /** Libellé français fourni par le serveur. */
  label: string;
  value: number;
  default: number;
  min: number;
  max: number;
  modified_by: number | null;
  updated_at: string | null;
}
