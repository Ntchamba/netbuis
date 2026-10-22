/** Fuseau d'affichage de toutes les dates du dashboard. */
export const TIME_ZONE = "Africa/Douala";

/** « 21 octobre 2026 » en heure locale du Cameroun. */
export function formatDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  return new Intl.DateTimeFormat("fr-FR", { dateStyle: "long", timeZone: TIME_ZONE }).format(d);
}

/** « il y a 2 h », « il y a 1 j » ; au-delà d'une semaine, la date locale. `now` sert aux tests. */
export function formatRelative(iso: string, now: Date = new Date()): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  const minutes = Math.floor((now.getTime() - d.getTime()) / 60_000);
  if (minutes < 1) return "à l'instant";
  if (minutes < 60) return `il y a ${minutes} min`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `il y a ${hours} h`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `il y a ${days} j`;
  return formatDate(iso);
}

/** « 21 oct. 2026, 14:05 » en heure locale du Cameroun. */
export function formatDateTime(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  return new Intl.DateTimeFormat("fr-FR", { dateStyle: "medium", timeStyle: "short", timeZone: TIME_ZONE }).format(d);
}
