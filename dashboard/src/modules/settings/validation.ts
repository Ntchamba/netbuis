/** Valide la saisie d'un réglage : entier, dans les bornes données par le serveur. Renvoie le nombre ou un message. */
export function parseSettingValue(text: string, min: number, max: number): { value: number } | { error: string } {
  const t = text.trim();
  if (t === "") return { error: "Saisissez une valeur." };
  if (!/^-?\d+$/.test(t)) return { error: "La valeur doit être un nombre entier." };
  const value = Number(t);
  if (!Number.isSafeInteger(value) || value < min || value > max) {
    return { error: `La valeur doit être comprise entre ${min} et ${max}.` };
  }
  return { value };
}

/** Message clair selon la réponse du serveur. `refresh` : la liste doit être rechargée. */
export function settingError(err: unknown): { message: string; refresh: boolean } {
  const response = (err as { response?: { status?: number; data?: { code?: string } } }).response;
  if (!response) return { message: "Connexion impossible. Vérifiez le réseau, puis réessayez.", refresh: false };
  const code = response.data?.code;
  switch (response.status) {
    case 400:
      if (code === "unknown_setting") return { message: "Ce réglage n'existe pas. La liste a été actualisée.", refresh: true };
      if (code === "invalid_value") return { message: "Le serveur refuse cette valeur : elle est hors des bornes autorisées ou n'est pas un entier.", refresh: true };
      return { message: "La modification n'a pas pu être envoyée. Vérifiez la valeur.", refresh: false };
    case 403:
      return { message: "Vous n'avez pas le droit de modifier les réglages.", refresh: false };
    default:
      return { message: "Une erreur est survenue. Réessayez dans un instant.", refresh: false };
  }
}
