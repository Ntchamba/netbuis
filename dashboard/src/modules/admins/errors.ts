export interface AdminError {
  message: string;
  /** Champ du formulaire concerné. */
  field?: "phone" | "name" | "role";
  /** La liste doit être rechargée. */
  refresh: boolean;
}

/** Message clair selon la réponse du serveur (création, changement de rôle, retrait). */
export function adminError(err: unknown): AdminError {
  const response = (err as { response?: { status?: number; data?: { code?: string } } }).response;
  if (!response) return { message: "Connexion impossible. Vérifiez le réseau, puis réessayez.", refresh: false };
  const code = response.data?.code;
  switch (response.status) {
    case 409:
      if (code === "phone_exists")
        return { message: "Ce numéro appartient déjà à un compte : on ne transforme pas un client en administrateur.", field: "phone", refresh: false };
      if (code === "last_full_admin")
        return { message: "Action impossible : c'est le dernier Administrateur complet actif.", refresh: false };
      return { message: "L'état de ce compte a changé entre-temps. La liste a été actualisée.", refresh: true };
    case 404:
      return { message: "Cet administrateur n'existe plus. La liste a été actualisée.", refresh: true };
    case 400:
      if (code === "self_action_forbidden") return { message: "Vous ne pouvez pas agir sur votre propre compte.", refresh: false };
      if (code === "reason_required") return { message: "Le motif est obligatoire.", refresh: false };
      if (code === "invalid_phone") return { message: "Numéro invalide : format attendu +237 6XXXXXXXX.", field: "phone", refresh: false };
      if (code === "invalid_role") return { message: "Rôle invalide.", field: "role", refresh: false };
      return { message: "La demande n'a pas pu être envoyée. Vérifiez les informations.", refresh: false };
    case 403:
      return { message: "Vous n'avez pas le droit d'effectuer cette action.", refresh: false };
    default:
      return { message: "Une erreur est survenue. Réessayez dans un instant.", refresh: false };
  }
}
