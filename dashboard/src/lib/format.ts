/**
 * Normalise un numéro camerounais saisi par l'admin : tolère espaces, points, tirets,
 * « +237 », « 237 » ou rien. Renvoie « +2376XXXXXXXX » ou null si le format est faux.
 */
export function normalizeCameroonPhone(input: string): string | null {
  const compact = input.replace(/[\s.\-()]/g, "");
  const m = /^(?:\+?237)?(6\d{8})$/.exec(compact);
  return m ? `+237${m[1]}` : null;
}
