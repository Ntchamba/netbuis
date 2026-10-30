import { useEffect, useState } from "react";
import { Button, Pagination } from "../../../components/ui";
import { cn } from "../../../lib/cn";
import { Can } from "../../../auth/permissions";
import { ExportAccountsButton } from "../components/ExportAccountsButton";
import { useAccountActions } from "../components/AccountActions";
import { UserTable } from "../components/UserTable";
import { useAccounts, useZoneOptions } from "../hooks";
import { ACCOUNTS_PAGE_SIZE, type AccountFilter } from "../types";
import { isPageOutOfRange, usePageFallback } from "../../../lib/pagination";

const FILTERS: Array<{ key: AccountFilter; label: string }> = [
  { key: "all", label: "Tous" },
  { key: "simple", label: "Simple" },
  { key: "business", label: "Business" },
  { key: "blocked", label: "Bloqués" },
  { key: "deleted", label: "Supprimés" },
];

const ZONE_LEVEL_LABEL: Record<string, string> = { ville_village: "ville", quartier: "quartier" };
const SEARCH_DELAY_MS = 300;

/** Comptes : filtres, recherche (nom ; numéro pour l'Administrateur complet), zone, tableau, actions. */
export function UsersPage() {
  const [type, setType] = useState<AccountFilter>("all");
  const [zone, setZone] = useState<number | null>(null);
  const [text, setText] = useState("");
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const query = useAccounts({ type, zone, q, page });
  const zones = useZoneOptions();
  const actions = useAccountActions();

  // La recherche part après une courte pause de frappe (le texte n'est ni dans l'adresse ni stocké).
  useEffect(() => {
    const next = text.trim();
    if (next === q) return;
    const t = setTimeout(() => {
      setQ(next);
      setPage(1);
    }, SEARCH_DELAY_MS);
    return () => clearTimeout(t);
  }, [text, q]);

  const outOfRange = isPageOutOfRange(query.error, page);
  const data = outOfRange ? undefined : query.data;
  const pageCount = data ? Math.max(1, Math.ceil(data.count / ACCOUNTS_PAGE_SIZE)) : 1;

  // Page vide ou hors limites (404) : retour à la dernière page valide.
  usePageFallback({ page, setPage, outOfRange, count: data?.count, pageSize: ACCOUNTS_PAGE_SIZE, empty: data ? data.results.length === 0 : false });

  return (
    <section aria-label="Comptes" className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div role="group" aria-label="Filtrer par type" className="flex flex-wrap gap-2">
          {FILTERS.map((f) => {
            const active = type === f.key;
            return (
              <button
                key={f.key}
                type="button"
                aria-pressed={active}
                onClick={() => {
                  setType(f.key);
                  setPage(1);
                }}
                className={cn(
                  "cursor-pointer rounded-full border px-[15px] py-2 text-[12.5px] font-bold",
                  active ? "border-accent bg-accent text-on-accent" : "border-line bg-transparent text-ink-2",
                )}
              >
                {f.label}
              </button>
            );
          })}
          {/* Les comptes de l'équipe viendront avec V01 : visible, pas cliquable. */}
          <button type="button" disabled aria-disabled="true" className="cursor-not-allowed rounded-full border border-line bg-transparent px-[15px] py-2 text-[12.5px] font-bold text-ink-3 opacity-60">
            Équipe NetBuis <span className="text-[11px] font-semibold">(bientôt)</span>
          </button>
        </div>
        <div className="flex items-center gap-2">
          <Can permission="peut_exporter">
            <ExportAccountsButton />
          </Can>
          <select
            aria-label="Zone"
            value={zone === null ? "" : String(zone)}
            onChange={(e) => {
              setZone(e.target.value === "" ? null : Number(e.target.value));
              setPage(1);
            }}
            className="rounded-[10px] border border-line bg-card px-3 py-2 text-[12.5px] text-ink-2"
          >
            <option value="">Toutes les zones</option>
            {zones.data?.map((z) => (
              <option key={z.id} value={z.id}>
                {z.name} ({ZONE_LEVEL_LABEL[z.level] ?? z.level})
              </option>
            ))}
          </select>
          <label className="flex w-60 items-center gap-2 rounded-[10px] border border-line bg-card px-3 py-2">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="shrink-0 text-ink-2" aria-hidden="true">
              <circle cx="11" cy="11" r="7" />
              <path d="M21 21l-4.3-4.3" />
            </svg>
            <input
              type="search"
              aria-label="Rechercher un compte"
              placeholder="Rechercher un compte..."
              value={text}
              onChange={(e) => setText(e.target.value)}
              autoComplete="off"
              className="w-full min-w-0 bg-transparent text-[12.5px] text-ink outline-none placeholder:text-ink-2"
            />
          </label>
        </div>
      </div>

      {query.isError && !data && !outOfRange ? (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">Impossible de charger les comptes.</p>
          <Button variant="secondary" onClick={() => void query.refetch()}>
            Réessayer
          </Button>
        </div>
      ) : (
        <UserTable rows={data?.results ?? []} loading={query.isLoading} busy={actions.busy} onAsk={actions.ask} />
      )}

      {data && <Pagination page={page} pageCount={pageCount} onPageChange={setPage} />}
      {actions.dialog}
    </section>
  );
}
