import { isAxiosError } from "axios";

export const MSG_INVALID_CREDENTIALS = "Numéro ou mot de passe incorrect.";
export const MSG_NETWORK = "Connexion impossible. Vérifiez votre réseau et réessayez.";
export const MSG_GENERIC = "Une erreur est survenue. Réessayez dans un instant.";

function formatDelay(seconds: number): string {
  if (seconds < 60) return `${seconds} seconde${seconds > 1 ? "s" : ""}`;
  const min = Math.ceil(seconds / 60);
  return `${min} minute${min > 1 ? "s" : ""}`;
}

/** Message affiché pour un échec de connexion. Identique que le compte existe ou non. */
export function loginErrorMessage(err: unknown): string {
  if (!isAxiosError(err)) return MSG_GENERIC;
  if (!err.response) return MSG_NETWORK;
  const status = err.response.status;
  if (status === 401) return MSG_INVALID_CREDENTIALS;
  if (status === 429) {
    const retry = Number(err.response.headers?.["retry-after"]);
    if (Number.isFinite(retry) && retry > 0) {
      return `Trop d'essais. Réessayez dans ${formatDelay(Math.ceil(retry))}.`;
    }
    return "Trop d'essais. Réessayez dans quelques minutes.";
  }
  return MSG_GENERIC;
}
