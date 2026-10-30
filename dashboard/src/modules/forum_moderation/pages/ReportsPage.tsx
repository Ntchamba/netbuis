import { useState } from "react";
import { Button, Pagination } from "../../../components/ui";
import { cn } from "../../../lib/cn";
import { isPageOutOfRange, usePageFallback } from "../../../lib/pagination";
import { ForbiddenWords } from "../components/ForbiddenWords";
import { useModerationActions } from "../components/ModerationActions";
import { ReportQueue } from "../components/ReportQueue";
import { loadError } from "../errors";
import { useReports } from "../hooks";
import { REPORTS_PAGE_SIZE, type StatusFilter, type TypeFilter } from "../types";

const STATUS_FILTERS: Array<{ key: StatusFilter; label: string }> = [
  { key: "", label: "Tous" },
  { key: "actif", label: "Actifs" },
  { key: "masque", label: "Masqués" },
  { key: "supprime", label: "Supprimés" },
];
const TYPE_FILTERS: Array<{ key: TypeFilter; label: string }> = [
  { key: "", label: "Tous" },
  { key: "post", label: "Publications" },
  { key: "comment", label: "Commentaires" },
  { key: "business", label: "Commerces" },
];

function Chips<K extends string>({ label, items, value, onPick }: { label: string; items: Array<{ key: K; label: string }>; value: K; onPick: (k: K) => void }) {
  return (
    <div role="group" aria-label={label} className="flex flex-wrap gap-2">
      {items.map((f) => (
        <button
          key={f.key}
          type="button"
          aria-pressed={value === f.key}
          onClick={() => onPick(f.key)}
          className={cn(
            "cursor-pointer rounded-full border px-[15px] py-2 text-[12.5px] font-bold",
            value === f.key ? "border-accent bg-accent text-on-accent" : "border-line bg-transparent text-ink-2",
          )}
        >
          {f.label}
        </button>
      ))}
    </div>
  );
}

/** Modération : file des signalements (ordre du serveur : le plus récemment signalé d'abord) et mots interdits. */
export function ReportsPage() {
  const [status, setStatus] = useState<StatusFilter>("");
  const [type, setType] = useState<TypeFilter>("");
  const [page, setPage] = useState(1);
  const query = useReports({ status, type, page });
  const actions = useModerationActions();

  const outOfRange = isPageOutOfRange(query.error, page);
  const data = outOfRange ? undefined : query.data;
  const pageCount = data ? Math.max(1, Math.ceil(data.count / REPORTS_PAGE_SIZE)) : 1;
  usePageFallback({ page, setPage, outOfRange, count: data?.count, pageSize: REPORTS_PAGE_SIZE, empty: data ? data.results.length === 0 : false });

  return (
    <section aria-label="Modération" className="flex flex-col gap-6 px-8 pb-7 pt-[18px]">
      <div className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center gap-x-6 gap-y-3">
          <Chips label="Filtrer par statut" items={STATUS_FILTERS} value={status} onPick={(k) => { setStatus(k); setPage(1); }} />
          <Chips label="Filtrer par type" items={TYPE_FILTERS} value={type} onPick={(k) => { setType(k); setPage(1); }} />
        </div>

        {query.isError && !data && !outOfRange ? (
          <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
            <p className="text-[13px] text-danger">{loadError(query.error, "les signalements")}</p>
            <Button variant="secondary" onClick={() => void query.refetch()}>
              Réessayer
            </Button>
          </div>
        ) : (
          <ReportQueue rows={data?.results ?? []} loading={query.isLoading} busy={actions.busy} onAsk={actions.ask} />
        )}
        {data && <Pagination page={page} pageCount={pageCount} onPageChange={setPage} />}
      </div>

      <ForbiddenWords />
      {actions.dialog}
    </section>
  );
}
