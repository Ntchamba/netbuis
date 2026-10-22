import { EmptyState } from "../../../components/ui";
import { safeTerm } from "../errors";
import type { TermCount } from "../types";
import { BarList } from "./BarList";

/** Termes les plus cherchés : texte seulement, jamais cliquables (un terme peut être saisi librement). */
export function TermsChart({ terms, label, emptyTitle }: { terms: TermCount[]; label: string; emptyTitle: string }) {
  if (terms.length === 0) return <EmptyState title={emptyTitle} description="Rien à afficher sur cette période." />;
  return (
    <BarList
      label={label}
      items={terms.map((t, i) => ({ key: String(i), label: safeTerm(t.term).text, value: t.count }))}
    />
  );
}
