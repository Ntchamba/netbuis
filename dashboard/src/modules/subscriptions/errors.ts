import { formatDate } from "../../lib/dates";

export interface GrantError {
  message: string;
  /** Messages français par champ (400) : durée, motif. */
  fields?: { duration_days?: string; reason?: string };
  /** La liste doit être rechargée (l'état du commerce a changé). */
  refresh: boolean;
}

interface ErrorBody {
  code?: string;
  fields?: Record<string, unknown>;
}

/** Message français clair selon la réponse du serveur ; jamais le texte brut du serveur. `end` : fin connue de l'abonnement en cours. */
export function grantError(err: unknown, end?: string | null): GrantError {
  const response = (err as { response?: { status?: number; data?: ErrorBody } }).response;
  if (!response) return { message: "Connexion impossible. Vérifiez le réseau, puis réessayez.", refresh: false };
  const code = response.data?.code;
  switch (response.status) {
    case 400: {
      const f = response.data?.fields ?? {};
      const fields: GrantError["fields"] = {};
      if (f.duration_days !== undefined) fields.duration_days = "Durée invalide : choisissez entre 1 et 12 mois.";
      if (f.reason !== undefined) fields.reason = "Motif invalide : il est obligatoire et ne doit pas dépasser 1000 caractères.";
      const has = Object.keys(fields).length > 0;
      return {
        message: has ? "Certaines informations sont incorrectes. Vérifiez le formulaire." : "La demande n'a pas pu être envoyée. Vérifiez les informations.",
        fields: has ? fields : undefined,
        refresh: false,
      };
    }
    case 403:
      return { message: "Vous n'avez pas le droit d'accorder un abonnement.", refresh: false };
    case 404:
      return { message: "Ce commerce n'existe plus. La liste a été actualisée.", refresh: true };
    case 409:
      if (code === "already_subscribed")
        return { message: end ? `Ce commerce est déjà abonné jusqu'au ${formatDate(end)}. Aucune prolongation ni cumul.` : "Ce commerce est déjà abonné. Aucune prolongation ni cumul.", refresh: true };
      if (code === "business_not_active") return { message: "Ce commerce n'est pas actif : on ne peut pas lui accorder d'abonnement.", refresh: true };
      return { message: "L'état de ce commerce a changé entre-temps. La liste a été actualisée.", refresh: true };
    default:
      return { message: "Une erreur est survenue. Réessayez dans un instant.", refresh: false };
  }
}
