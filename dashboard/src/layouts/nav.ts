import { PATHS } from "../routes/paths";

export type NavIcon = "overview" | "requests" | "accounts" | "team" | "referentials";

export interface NavItem {
  key: string;
  label: string;
  to: string;
  icon: NavIcon;
  /** Permission du serveur exigée. Refus par défaut : sans elle, l'entrée n'est pas affichée. */
  permission: string;
  /** Entrée visible mais non cliquable (« bientôt »). */
  soon?: boolean;
  /** Affiche la pastille du nombre de demandes en attente. */
  badge?: boolean;
}

export const NAV_ITEMS: readonly NavItem[] = [
  { key: "overview", label: "Vue d'ensemble", to: PATHS.home, icon: "overview", permission: "peut_voir_comptes" },
  { key: "requests", label: "Demandes", to: PATHS.demandes, icon: "requests", permission: "peut_voir_demandes", badge: true },
  { key: "accounts", label: "Comptes", to: PATHS.comptes, icon: "accounts", permission: "peut_voir_comptes" },
  { key: "referentials", label: "Référentiels", to: PATHS.referentiels, icon: "referentials", permission: "peut_gerer_referentiels" },
  // Réservée à l'Administrateur complet ; activée par T113.
  { key: "team", label: "Équipe & abonnements", to: PATHS.equipe, icon: "team", permission: "peut_accorder_abonnement", soon: true },
];

/** Titre de l'en-tête selon la page (maquettes). */
export function titleFor(pathname: string): string {
  if (pathname.startsWith(PATHS.demandes)) return "Demandes en attente";
  if (pathname.startsWith(PATHS.comptes)) return "Comptes";
  if (pathname.startsWith(PATHS.referentiels)) return "Référentiels";
  if (pathname.startsWith(PATHS.equipe)) return "Équipe & abonnements";
  return "Vue d'ensemble";
}
