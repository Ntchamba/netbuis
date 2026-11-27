import { TIME_ZONE } from "../../lib/dates";
import type { AuditFilters } from "./types";

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const MIN_YEAR = 2000;
const MAX_DAYS_AHEAD = 366;
const DIGITS = /^\d{1,18}$/;

export type FilterErrors = Partial<Record<keyof AuditFilters, string>>;

/** Jour courant au Cameroun, « AAAA-MM-JJ ». `now` sert aux tests. */
export function todayInDouala(now: Date = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: TIME_ZONE, year: "numeric", month: "2-digit", day: "2-digit" }).format(now);
}

function utc(day: string): number {
  const [y, m, d] = day.split("-").map(Number) as [number, number, number];
  return Date.UTC(y, m - 1, d);
}

/** Même règle que le serveur : AAAA-MM-JJ réel, année ≥ 2000, au plus aujourd'hui + 366 jours. */
export function dateError(value: string, now: Date = new Date()): string | null {
  if (value === "") return null;
  const message = "Date invalide : format AAAA-MM-JJ, entre 2000 et dans un an au plus.";
  if (!DATE.test(value)) return message;
  const t = utc(value);
  const back = new Date(t);
  const [y, m, d] = value.split("-").map(Number);
  if (back.getUTCFullYear() !== y || back.getUTCMonth() !== (m as number) - 1 || back.getUTCDate() !== d) return message;
  if ((y as number) < MIN_YEAR) return message;
  if (t > utc(todayInDouala(now)) + MAX_DAYS_AHEAD * 86_400_000) return message;
  return null;
}

/** Erreurs de saisie (vide si tout est valide) : aucune requête n'est envoyée tant qu'il en reste. */
export function validateFilters(f: AuditFilters, now: Date = new Date()): FilterErrors {
  const errors: FilterErrors = {};
  if (f.admin !== "" && !DIGITS.test(f.admin)) errors.admin = "Identifiant invalide : chiffres seulement.";
  const from = dateError(f.from, now);
  const to = dateError(f.to, now);
  if (from) errors.from = from;
  if (to) errors.to = to;
  if (!from && !to && f.from !== "" && f.to !== "" && f.from > f.to) errors.to = "La date « Au » doit être égale ou postérieure à la date « Du ».";
  return errors;
}
