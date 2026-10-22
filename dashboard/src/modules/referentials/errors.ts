export interface RefError {
  message: string;
  /** Champ du formulaire concerné (affiche le message sous le champ). */
  field?: string;
  /** L'affichage doit être rechargé (l'élément a changé ou n'existe plus). */
  refresh: boolean;
  /** Messages par champ renvoyés par le serveur (400). */
  fields?: Record<string, string>;
}

interface ErrorBody {
  code?: string;
  message?: string;
  fields?: Record<string, unknown>;
}

function fieldMessages(fields: Record<string, unknown> | undefined): Record<string, string> | undefined {
  if (!fields) return undefined;
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(fields)) {
    const first = Array.isArray(value) ? value[0] : value;
    if (typeof first === "string" && first !== "") out[key] = first;
  }
  return Object.keys(out).length > 0 ? out : undefined;
}

/**
 * Message clair selon la réponse du serveur. `nameField` : champ qui porte le nom (« name » ou « term »),
 * sous lequel s'affiche le conflit « existe déjà ».
 */
export function referentialError(err: unknown, nameField = "name"): RefError {
  const response = (err as { response?: { status?: number; data?: ErrorBody } }).response;
  if (!response) return { message: "Connexion impossible. Vérifiez le réseau, puis réessayez.", refresh: false };
  const code = response.data?.code;
  switch (response.status) {
    case 409:
      switch (code) {
        case "already_exists":
          return { message: "Un élément portant ce nom ou ce code existe déjà.", field: nameField, refresh: false };
        case "has_active_children":
          return { message: "Désactivez d'abord les éléments enfants.", refresh: false };
        case "parent_inactive":
          return { message: "Le parent est désactivé : réactivez-le d'abord.", refresh: false };
        case "protected_item":
          return { message: "La ligne « Autre » est protégée : elle ne peut pas être désactivée.", refresh: false };
        case "invalid_state":
          return { message: "L'état de cet élément a changé entre-temps. L'affichage a été actualisé.", refresh: true };
        default:
          return { message: "Cette action est en conflit avec l'état actuel. L'affichage a été actualisé.", refresh: true };
      }
    case 404:
      return { message: "Cet élément n'existe plus. L'affichage a été actualisé.", refresh: true };
    case 400: {
      const fields = fieldMessages(response.data?.fields);
      return { message: "Certaines informations sont incorrectes. Vérifiez le formulaire.", refresh: false, fields };
    }
    case 403:
      return { message: "Vous n'avez pas le droit d'effectuer cette action.", refresh: false };
    default:
      return { message: "Une erreur est survenue. Réessayez dans un instant.", refresh: false };
  }
}
