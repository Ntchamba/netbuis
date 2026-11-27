/** Message clair selon la réponse du serveur (partagé par les pages d'analyses). */
export function analyticsError(err: unknown, what: string): string {
  const response = (err as { response?: { status?: number } }).response;
  if (!response) return "Connexion impossible. Vérifiez le réseau, puis réessayez.";
  if (response.status === 403) return `Vous n'avez pas le droit de consulter ${what}.`;
  if (response.status === 400) return "Période invalide : choisissez une durée de 1 à 90 jours.";
  return `Impossible de charger ${what}.`;
}

/**
 * Un terme tapé dans la barre de recherche peut être un numéro de téléphone. Le serveur écarte déjà
 * les termes de 6 chiffres ou plus ; par prudence, on masque aussi ici tout motif qui y ressemble.
 */
const PHONE_LIKE = /(\d[^\d]*){6,}/;
export function safeTerm(term: string): { text: string; masked: boolean } {
  return PHONE_LIKE.test(term) ? { text: "Terme masqué (numéro possible)", masked: true } : { text: term, masked: false };
}
