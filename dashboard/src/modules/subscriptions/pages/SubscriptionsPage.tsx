import { useState } from "react";
import { Can } from "../../../auth/permissions";
import { Button, EmptyState, Pagination, Skeleton } from "../../../components/ui";
import { cn } from "../../../lib/cn";
import { formatDate } from "../../../lib/dates";
import { isPageOutOfRange, usePageFallback } from "../../../lib/pagination";
import { GrantDialog } from "../components/GrantDialog";
import { useSubscriptions } from "../hooks";
import { SUBSCRIPTIONS_PAGE_SIZE, type SubscriptionFilter, type SubscriptionRow } from "../types";

const FILTERS: Array<{ key: SubscriptionFilter; label: string }> = [
  { key: "all", label: "Tous" },
  { key: "subscribed", label: "Abonnés" },
  { key: "unsubscribed", label: "Non abonnés" },
  { key: "high_traffic", label: "À fort trafic" },
];
const HEADERS = ["COMMERCE", "ZONE", "STATUT", "FIN D'ABONNEMENT", "APPELS (24 h)", "ACTIONS"];

/** Équipe & abonnements : comptes business abonnés ou non, accord manuel (Administrateur complet), équipe à venir. */
export function SubscriptionsPage() {
  const [filter, setFilter] = useState<SubscriptionFilter>("all");
  const [page, setPage] = useState(1);
  const [target, setTarget] = useState<SubscriptionRow | null>(null);
  const query = useSubscriptions(filter, page);
  const outOfRange = isPageOutOfRange(query.error, page);
  const data = outOfRange ? undefined : query.data;
  const pageCount = data ? Math.max(1, Math.ceil(data.count / SUBSCRIPTIONS_PAGE_SIZE)) : 1;
  const forbidden = (query.error as { response?: { status?: number } } | null)?.response?.status === 403;

  usePageFallback({ page, setPage, outOfRange, count: data?.count, pageSize: SUBSCRIPTIONS_PAGE_SIZE, empty: data ? data.results.length === 0 : false });

  return (
    <section aria-label="Équipe & abonnements" className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
      <div role="tablist" aria-label="Sections" className="flex gap-2">
        <button type="button" role="tab" aria-selected="true" className="rounded-full border border-accent bg-accent px-[15px] py-2 text-[12.5px] font-bold text-on-accent">
          Abonnements
        </button>
        {/* Équipe NetBuis (V01) : onglet désactivé, aucun appel au serveur. */}
        <button type="button" role="tab" aria-selected="false" disabled aria-disabled="true" className="cursor-not-allowed rounded-full border border-line px-[15px] py-2 text-[12.5px] font-bold text-ink-3 opacity-60">
          Équipe NetBuis <span className="text-[11px] font-semibold">(à venir)</span>
        </button>
      </div>

      <p className="text-[13px] text-ink-2">
        Comptes business actifs, les plus sollicités d'abord. En attendant les paiements, un abonnement s'accorde ici à la main (Administrateur complet), avec un motif conservé au journal d'audit.
      </p>

      <div role="group" aria-label="Filtrer les comptes" className="flex flex-wrap gap-2">
        {FILTERS.map((f) => {
          const active = filter === f.key;
          return (
            <button
              key={f.key}
              type="button"
              aria-pressed={active}
              onClick={() => {
                setFilter(f.key);
                setPage(1);
              }}
              className={cn("cursor-pointer rounded-full border px-[15px] py-2 text-[12.5px] font-bold", active ? "border-accent bg-accent text-on-accent" : "border-line bg-transparent text-ink-2")}
            >
              {f.label}
            </button>
          );
        })}
      </div>

      {query.isError && !data && !outOfRange ? (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">{forbidden ? "Vous n'avez pas le droit de consulter les abonnements." : "Impossible de charger les abonnements."}</p>
          {!forbidden && (
            <Button variant="secondary" onClick={() => void query.refetch()}>
              Réessayer
            </Button>
          )}
        </div>
      ) : (
        <div className="overflow-hidden rounded-2xl border border-line bg-card">
          <table className="w-full border-collapse">
            <caption className="sr-only">Comptes business et abonnements</caption>
            <thead>
              <tr className="border-b border-line">
                {HEADERS.map((h) => (
                  <th key={h} scope="col" className={`px-[18px] py-3 text-[11.5px] font-bold text-ink-3 ${h === "ACTIONS" ? "text-right" : "text-left"}`}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody aria-busy={query.isLoading || undefined}>
              {query.isLoading &&
                [0, 1, 2].map((i) => (
                  <tr key={i} data-loading-row className="border-b border-line">
                    {HEADERS.map((h) => (
                      <td key={h} className="px-[18px] py-[14px]">
                        <Skeleton className="h-4 w-3/4" />
                      </td>
                    ))}
                  </tr>
                ))}
              {data && data.results.length === 0 && (
                <tr>
                  <td colSpan={HEADERS.length}>
                    <EmptyState title="Aucun compte" description="Aucun compte business ne correspond à ce filtre." />
                  </td>
                </tr>
              )}
              {data?.results.map((r) => (
                <tr key={r.id} data-testid={`sub-row-${r.id}`} className="border-b border-line last:border-b-0">
                  <td className="px-[18px] py-[14px] text-[13.5px] font-bold">{r.name}</td>
                  <td className="px-[18px] py-[14px] text-[12.5px] text-ink-2">{r.zone_name ?? "—"}</td>
                  <td className="px-[18px] py-[14px] text-[12.5px] font-bold">
                    {r.is_subscribed ? "Abonné" : "Non abonné"}
                    {r.high_traffic && <span className="ml-2 text-[11px] font-semibold text-danger">Fort trafic</span>}
                  </td>
                  <td className="px-[18px] py-[14px] text-[12.5px] text-ink-2">{r.is_subscribed && r.subscription_end ? formatDate(r.subscription_end) : "—"}</td>
                  <td className="px-[18px] py-[14px] text-[12.5px] text-ink-2">{r.calls_last_day}</td>
                  <td className="px-[18px] py-[14px]">
                    <div className="flex justify-end gap-2">
                      {!r.is_subscribed && (
                        <Can permission="peut_accorder_abonnement">
                          <Button variant="secondary" onClick={() => setTarget(r)} className="px-2.5 py-1.5 text-[11.5px]">
                            Accorder un abonnement
                          </Button>
                        </Can>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {data && <Pagination page={page} pageCount={pageCount} onPageChange={setPage} />}
      {target && <GrantDialog row={target} onClose={() => setTarget(null)} />}
    </section>
  );
}
