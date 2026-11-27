import { useState } from "react";
import { useAuth } from "../../../auth/useAuth";
import { Badge, Button, Pagination, Table, type BadgeStatus, type Column } from "../../../components/ui";
import { formatDateTime } from "../../../lib/dates";
import { cn } from "../../../lib/cn";
import { isPageOutOfRange, usePageFallback } from "../../../lib/pagination";
import { useTeamCalls } from "../hooks";
import { CALLS_PAGE_SIZE, type AgentCall, type CallFilter, type CallState } from "../types";

const FILTERS: Array<{ key: CallFilter; label: string }> = [
  { key: "all", label: "Tous" },
  { key: "missed", label: "Manqués" },
  { key: "answered", label: "Répondus" },
];

const STATE: Record<CallState, { label: string; status: BadgeStatus }> = {
  ringing: { label: "Sonnerie", status: "en_attente" },
  answered: { label: "En cours", status: "abonne" },
  ended: { label: "Terminé", status: "actif" },
  missed: { label: "Manqué", status: "rejete" },
  declined: { label: "Refusé", status: "rejete" },
  unavailable: { label: "Personne de disponible", status: "neutre" },
  cancelled: { label: "Annulé par l'appelant", status: "neutre" },
};

/** « 2 min 05 s » ; « — » si l'appel n'a pas eu lieu. */
export function formatDuration(call: Pick<AgentCall, "answered_at" | "ended_at">): string {
  if (!call.answered_at || !call.ended_at) return "—";
  const seconds = Math.max(0, Math.round((Date.parse(call.ended_at) - Date.parse(call.answered_at)) / 1000));
  if (Number.isNaN(seconds)) return "—";
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return m === 0 ? `${s} s` : `${m} min ${String(s).padStart(2, "0")} s`;
}

const COLUMNS: Column<AgentCall>[] = [
  { key: "date", header: "Date", render: (c) => formatDateTime(c.created_at) },
  { key: "caller", header: "Appelant", render: (c) => <span className="font-bold">{c.caller_name}</span> },
  { key: "business", header: "Commerce", render: (c) => c.business?.name ?? "—" },
  { key: "state", header: "État", render: (c) => <Badge status={STATE[c.state].status}>{STATE[c.state].label}</Badge> },
  { key: "agent", header: "Agent", render: (c) => c.agent?.name ?? "—" },
  { key: "duration", header: "Durée", align: "right", render: (c) => formatDuration(c) },
];

function Pill({ active, onClick, children }: { active: boolean; onClick: () => void; children: string }) {
  return (
    <button
      type="button"
      aria-pressed={active}
      onClick={onClick}
      className={cn(
        "min-h-11 cursor-pointer rounded-full border px-[15px] text-[12.5px] font-bold",
        active ? "border-accent bg-accent text-on-accent" : "border-line bg-transparent text-ink-2",
      )}
    >
      {children}
    </button>
  );
}

/** Appels à l'équipe NetBuis : manqués, répondus, mes appels. Sans numéro ni salle. */
export function TeamCallsPage() {
  const { me } = useAuth();
  const [filter, setFilter] = useState<CallFilter>("all");
  const [mine, setMine] = useState(false);
  const [page, setPage] = useState(1);
  const query = useTeamCalls(filter, mine && me ? me.id : null, page);
  const outOfRange = isPageOutOfRange(query.error, page);
  const data = outOfRange ? undefined : query.data;
  const pageCount = data ? Math.max(1, Math.ceil(data.count / CALLS_PAGE_SIZE)) : 1;
  usePageFallback({ page, setPage, outOfRange, count: data?.count, pageSize: CALLS_PAGE_SIZE, empty: data ? data.results.length === 0 : false });

  return (
    <section aria-label="Appels à l'équipe" className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
      <h1 className="sr-only">Appels à l'équipe</h1>
      <div className="flex flex-wrap items-center gap-2">
        <div role="group" aria-label="Filtrer les appels" className="flex flex-wrap gap-2">
          {FILTERS.map((f) => (
            <Pill
              key={f.key}
              active={filter === f.key}
              onClick={() => {
                setFilter(f.key);
                setPage(1);
              }}
            >
              {f.label}
            </Pill>
          ))}
        </div>
        <Pill
          active={mine}
          onClick={() => {
            setMine((v) => !v);
            setPage(1);
          }}
        >
          Mes appels
        </Pill>
      </div>

      {query.isError && !data && !outOfRange ? (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">Impossible de charger les appels.</p>
          <Button variant="secondary" onClick={() => void query.refetch()}>
            Réessayer
          </Button>
        </div>
      ) : (
        <Table
          caption="Appels à l'équipe"
          columns={COLUMNS}
          rows={data?.results ?? []}
          rowKey={(c) => c.session_id}
          loading={query.isLoading}
          emptyTitle="Aucun appel"
          emptyDescription="Les appels des utilisateurs à l'équipe apparaîtront ici."
        />
      )}
      {data && <Pagination page={page} pageCount={pageCount} onPageChange={setPage} />}
    </section>
  );
}
