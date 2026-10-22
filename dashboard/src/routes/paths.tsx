export const PATHS = {
  home: "/",
  login: "/connexion",
  demandes: "/demandes",
  comptes: "/comptes",
  compte: "/comptes/:id",
  equipe: "/equipe",
  referentiels: "/referentiels",
  referentielsAExaminer: "/referentiels/a-examiner",
  referentiel: "/referentiels/:type",
} as const;

/** Adresse d'une section des référentiels (le nom du type est celui de l'API). */
export function referentialPath(type: string): string {
  return `/referentiels/${type}`;
}
