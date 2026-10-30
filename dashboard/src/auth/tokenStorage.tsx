// Jeton d'accès : UNIQUEMENT en mémoire (variable de module).
// Jamais dans localStorage, sessionStorage, un cookie lisible, l'URL ou un journal (D-01).
let accessToken: string | null = null;

// Génération de session : incrémentée à chaque connexion, déconnexion ou réinitialisation.
// Un rafraîchissement ou un chargement lancé avant le changement est ignoré à sa résolution.
let generation = 0;

export function getSessionGeneration(): number {
  return generation;
}

export function bumpSessionGeneration(): void {
  generation += 1;
}

export function getAccessToken(): string | null {
  return accessToken;
}

export function setAccessToken(token: string): void {
  accessToken = token;
}

export function clearAccessToken(): void {
  accessToken = null;
}
