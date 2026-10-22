import { useState } from "react";
import { Button, Card, EmptyState, Skeleton } from "../../../components/ui";
import { formatInt } from "../../../lib/format";
import { formatDate } from "../../../lib/dates";
import { NoResultQueries } from "../components/NoResultQueries";
import { PeriodSelect } from "../components/PeriodSelect";
import { TermsChart } from "../components/TopQueries";
import { analyticsError } from "../errors";
import { useSearchAnalytics } from "../hooks";
import { DEFAULT_DAYS } from "../types";

/** Recherches : termes les plus fréquents et recherches sans résultat. Lecture seule, agrégats seulement. */
export function SearchAnalyticsPage() {
  const [days, setDays] = useState(DEFAULT_DAYS);
  const query = useSearchAnalytics(days);
  const data = query.data;

  return (
    <section aria-label="Recherches" className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
      <h1 className="sr-only">Recherches</h1>
      <div className="flex flex-wrap items-end justify-between gap-3">
        <PeriodSelect days={days} onChange={setDays} />
        {data && (
          <p className="text-[12.5px] text-ink-2">
            Depuis le {formatDate(data.since)} · {formatInt(data.total_searches)} recherches · {formatInt(data.total_without_results)} sans résultat
          </p>
        )}
      </div>

      {query.isLoading && (
        <div role="status" aria-label="Chargement">
          <Skeleton className="h-40 w-full" />
        </div>
      )}
      {query.isError && !data && (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">{analyticsError(query.error, "les recherches")}</p>
          <Button variant="secondary" onClick={() => void query.refetch()}>
            Réessayer
          </Button>
        </div>
      )}
      {data && data.total_searches === 0 && <EmptyState title="Aucune recherche sur cette période" description="Choisissez une période plus longue." />}
      {data && data.total_searches > 0 && (
        <div className="grid grid-cols-1 gap-4 min-[1100px]:grid-cols-2">
          <Card>
            <h2 className="mb-3 text-[14px] font-bold">Termes les plus cherchés</h2>
            <TermsChart terms={data.top_terms} label="Termes les plus cherchés" emptyTitle="Aucun terme" />
          </Card>
          <Card>
            <h2 className="mb-1 text-[14px] font-bold">Recherches sans résultat</h2>
            <p className="mb-3 text-[12px] text-ink-2">Des produits ou services à ajouter au catalogue.</p>
            <NoResultQueries terms={data.no_result_terms} />
          </Card>
        </div>
      )}
    </section>
  );
}
