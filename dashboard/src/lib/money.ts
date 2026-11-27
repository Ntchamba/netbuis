import { formatInt } from "./format";

/** « 184 300 FCFA » (espace fine insécable entre les milliers). Le franc CFA n'a pas de décimales. */
export function formatMoney(amount: number, currency = "FCFA"): string {
  return `${formatInt(amount)} ${currency === "XAF" ? "FCFA" : currency}`;
}
