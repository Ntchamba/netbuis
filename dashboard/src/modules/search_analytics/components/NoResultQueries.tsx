import { TermsChart } from "./TopQueries";
import type { TermCount } from "../types";

export function NoResultQueries({ terms }: { terms: TermCount[] }) {
  return <TermsChart terms={terms} label="Recherches sans résultat" emptyTitle="Aucune recherche sans résultat" />;
}
