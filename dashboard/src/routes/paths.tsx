export const PATHS = {
  home: "/",
  login: "/connexion",
  demandes: "/demandes",
  comptes: "/comptes",
  compte: "/comptes/:id",
  equipe: "/equipe",
  reglages: "/reglages",
  administrateurs: "/administrateurs",
  audit: "/audit",
  recherches: "/recherches",
  appels: "/appels",
  appelsEquipe: "/appels-equipe",
  tendances: "/tendances",
  moderation: "/moderation",
  referentiels: "/referentiels",
  referentielsAExaminer: "/referentiels/a-examiner",
  referentiel: "/referentiels/:type",
} as const;

/** Adresse d'une section des référentiels (le nom du type est celui de l'API). */
export function referentialPath(type: string): string {
  return `/referentiels/${type}`;
}
