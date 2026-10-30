interface Resp {
  response?: { status?: number; data?: { code?: string } };
}

/** Message clair selon l'erreur du serveur ; `refresh` : l'affichage doit être rechargé. */
export function moderationError(err: unknown): { message: string; refresh: boolean } {
  const response = (err as Resp).response;
  if (!response) return { message: "Connexion impossible. Vérifiez le réseau, puis réessayez.", refresh: false };
  const code = response.data?.code;
  switch (response.status) {
    case 409:
      return { message: "Le statut de ce contenu a changé entre-temps. L'affichage a été actualisé.", refresh: true };
    case 404:
      return { message: "Ce contenu n'existe plus. L'affichage a été actualisé.", refresh: true };
    case 400:
      if (code === "reason_required") return { message: "Le motif est obligatoire.", refresh: false };
      if (code === "unsupported_target") return { message: "Utilisez la page Comptes pour bloquer ce commerce.", refresh: false };
      return { message: "L'action n'a pas pu être envoyée. Vérifiez les informations.", refresh: false };
    case 403:
      return { message: "Vous n'avez pas le droit de modérer le contenu.", refresh: false };
    default:
      return { message: "Une erreur est survenue. Réessayez dans un instant.", refresh: false };
  }
}

/** Message de chargement de la file ou de la liste de mots. */
export function loadError(err: unknown, what: string): string {
  const response = (err as Resp).response;
  if (!response) return "Connexion impossible. Vérifiez le réseau, puis réessayez.";
  if (response.status === 403) return `Vous n'avez pas le droit de consulter ${what}.`;
  return `Impossible de charger ${what}.`;
}

/** Message d'ajout / de suppression d'un mot interdit. */
export function wordError(err: unknown): { message: string; refresh: boolean } {
  const response = (err as Resp).response;
  if (!response) return { message: "Connexion impossible. Vérifiez le réseau, puis réessayez.", refresh: false };
  switch (response.status) {
    case 409:
      return { message: "Ce mot est déjà dans la liste.", refresh: true };
    case 404:
      return { message: "Ce mot n'existe plus. La liste a été actualisée.", refresh: true };
    case 400:
      return { message: "Mot invalide : 2 à 60 caractères.", refresh: false };
    case 403:
      return { message: "Vous n'avez pas le droit de modifier la liste.", refresh: false };
    default:
      return { message: "Une erreur est survenue. Réessayez dans un instant.", refresh: false };
  }
}
