/** Message clair selon la réponse du serveur. */
export function auditError(err: unknown): string {
  const response = (err as { response?: { status?: number; data?: { code?: string } } }).response;
  if (!response) return "Connexion impossible. Vérifiez le réseau, puis réessayez.";
  if (response.status === 400 && response.data?.code === "invalid_filter")
    return "Filtre invalide : vérifiez l'administrateur, l'action et les dates (AAAA-MM-JJ).";
  if (response.status === 403) return "Vous n'avez pas le droit de consulter le journal d'audit.";
  return "Impossible de charger le journal d'audit.";
}
