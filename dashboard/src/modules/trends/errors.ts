export function trendsError(err: unknown): string {
  const response = (err as { response?: { status?: number } }).response;
  if (!response) return "Connexion impossible. Vérifiez le réseau, puis réessayez.";
  if (response.status === 403) return "Vous n'avez pas le droit de consulter les tendances.";
  if (response.status === 400) return "Ville inconnue : choisissez une ville de la liste.";
  return "Impossible de charger les tendances.";
}
