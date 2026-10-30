import { useEffect, useState } from "react";
import { useLocation } from "react-router-dom";
import { Can } from "../../../auth/permissions";
import { Button, Pagination, Table, type Column } from "../../../components/ui";
import { PERMISSION, useActiveToggle } from "../components/ActiveToggle";
import type { PickerType } from "../components/fields";
import { RefFormDialog, type ZoneContext } from "../components/RefFormDialog";
import { RefPicker, type PickerValue } from "../components/RefPicker";
import { ReferentialsNav, RowActions, StatusBadge } from "../components/RowParts";
import { SearchBox, StatusFilterButtons } from "../components/Toolbar";
import { ZoneTree } from "../components/ZoneTree";
import { useReferentials } from "../hooks";
import { isPageOutOfRange, usePageFallback } from "../../../lib/pagination";
import {
  PAGE_SIZE,
  ZONE_LEVEL_LABEL,
  type AdminItem,
  type AdminProduct,
  type AdminSynonym,
  type AdminZone,
  type RefConfig,
  type RefRow,
  type RefType,
  type StatusFilter,
  type ZoneLevel,
} from "../types";

const SEARCH_DELAY_MS = 300;

/** Filtre propre au type (paramètre du serveur et liste qui l'alimente). */
const EXTRA_FILTER: Partial<Record<RefType, { param: string; label: string; picker: PickerType; empty: string }>> = {
  subcategories: { param: "sector", label: "Secteur", picker: "sectors", empty: "Tous les secteurs" },
  products: { param: "category", label: "Sous-catégorie", picker: "subcategories", empty: "Toutes les sous-catégories" },
  synonyms: { param: "product", label: "Produit", picker: "products", empty: "Tous les produits" },
};

const rowId = (row: RefRow) => row.id;
const marked = (row: RefRow, content: React.ReactNode) => <span data-testid={`ref-row-${row.id}`}>{content}</span>;

interface FormState {
  row?: RefRow;
  initial?: { name?: string };
  zone?: ZoneContext;
}

/** Une section des référentiels : liste, recherche, filtres, pagination, ajout, modification, désactivation. */
export function ReferentialListPage({ config }: { config: RefConfig }) {
  const type = config.type;
  const location = useLocation();
  const prefill = (location.state as { prefill?: { name?: string } } | null)?.prefill;

  const [status, setStatus] = useState<StatusFilter>("all");
  const [text, setText] = useState("");
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const [level, setLevel] = useState("");
  const [picked, setPicked] = useState<PickerValue | null>(null);
  const [form, setForm] = useState<FormState | null>(prefill?.name ? { initial: { name: prefill.name } } : null);
  const toggle = useActiveToggle(type);

  useEffect(() => {
    const next = text.trim();
    if (next === q) return;
    const t = setTimeout(() => {
      setQ(next);
      setPage(1);
    }, SEARCH_DELAY_MS);
    return () => clearTimeout(t);
  }, [text, q]);

  const extra = EXTRA_FILTER[type];
  const extraParams: Record<string, string | number | null> = {};
  if (extra && picked) extraParams[extra.param] = picked.id;
  if (type === "zones" && level) extraParams.level = level;

  // Arbre des zones tant qu'aucune recherche ni aucun filtre n'est demandé.
  const treeMode = type === "zones" && q === "" && status === "all" && level === "";
  const query = useReferentials(type, { page, pageSize: PAGE_SIZE, q, status, extra: extraParams }, !treeMode);
  const sectors = useReferentials("sectors", { page: 1, pageSize: 50, status: "all" }, type === "subcategories");
  const sectorName = (id: number) => (sectors.data?.results as AdminItem[] | undefined)?.find((s) => s.id === id)?.name ?? `n° ${id}`;

  const outOfRange = isPageOutOfRange(query.error, page);
  const data = outOfRange ? undefined : query.data;
  const pageCount = data ? Math.max(1, Math.ceil(data.count / PAGE_SIZE)) : 1;
  usePageFallback({ page, setPage, outOfRange, count: data?.count, pageSize: PAGE_SIZE, empty: data ? data.results.length === 0 : false });

  const actions = (row: RefRow) => (
    <RowActions
      row={row}
      busy={toggle.busy}
      onEdit={() => setForm({ row })}
      onToggle={(a) => toggle.ask(row, a)}
    />
  );
  const state = (row: RefRow) => <StatusBadge active={row.is_active} />;
  const actionColumn: Column<RefRow> = { key: "actions", header: "Actions", align: "right", render: actions };
  const stateColumn: Column<RefRow> = { key: "state", header: "État", render: state };

  const columns: Record<RefType, Column<RefRow>[]> = {
    zones: [
      { key: "name", header: "Nom", render: (r) => marked(r, (r as AdminZone).name) },
      { key: "level", header: "Niveau", render: (r) => ZONE_LEVEL_LABEL[(r as AdminZone).level] },
      { key: "parent", header: "Rattachée à", render: (r) => (r as AdminZone).parent_name ?? "—" },
      { key: "code", header: "Code officiel", render: (r) => (r as AdminZone).official_code || "—" },
      stateColumn,
      actionColumn,
    ],
    sectors: [
      { key: "name", header: "Nom", render: (r) => marked(r, (r as AdminItem).name) },
      { key: "code", header: "Code", render: (r) => (r as AdminItem).code },
      { key: "order", header: "Ordre", render: (r) => (r as AdminItem).order },
      { key: "children", header: "Sous-catégories actives", render: (r) => (r as AdminItem).active_children_count ?? 0 },
      stateColumn,
      actionColumn,
    ],
    subcategories: [
      { key: "name", header: "Nom", render: (r) => marked(r, (r as AdminItem).name) },
      { key: "code", header: "Code", render: (r) => (r as AdminItem).code },
      { key: "sector", header: "Secteur", render: (r) => sectorName((r as AdminItem).sector ?? 0) },
      { key: "order", header: "Ordre", render: (r) => (r as AdminItem).order },
      stateColumn,
      actionColumn,
    ],
    "service-categories": itemColumns(stateColumn, actionColumn),
    "structure-types": itemColumns(stateColumn, actionColumn),
    products: [
      { key: "name", header: "Nom", render: (r) => marked(r, (r as AdminProduct).name) },
      { key: "category", header: "Sous-catégorie", render: (r) => (r as AdminProduct).category_name ?? "—" },
      { key: "synonyms", header: "Synonymes", render: (r) => (r as AdminProduct).synonyms_count },
      stateColumn,
      actionColumn,
    ],
    synonyms: [
      { key: "term", header: "Synonyme", render: (r) => marked(r, (r as AdminSynonym).term) },
      { key: "product", header: "Produit", render: (r) => (r as AdminSynonym).product_name },
      stateColumn,
      actionColumn,
    ],
  };

  const reset = () => setPage(1);
  const showTable = !treeMode && !(query.isError && !data && !outOfRange);
  return (
    <section aria-label={config.title} className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
      <ReferentialsNav />
      <p className="text-[12.5px] text-ink-2">{config.description}</p>

      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="flex flex-wrap items-end gap-3">
          <StatusFilterButtons
            value={status}
            onChange={(v) => {
              setStatus(v);
              reset();
            }}
          />
          {extra && (
            <div className="w-56">
              <RefPicker
                label={extra.label}
                picker={extra.picker}
                value={picked}
                emptyLabel={extra.empty}
                onlyActive={false}
                onChange={(v) => {
                  setPicked(v);
                  reset();
                }}
              />
            </div>
          )}
          {type === "zones" && (
            <label className="flex flex-col gap-1 text-[12px] font-bold text-ink-2">
              Niveau
              <select
                aria-label="Niveau"
                value={level}
                onChange={(e) => {
                  setLevel(e.target.value);
                  reset();
                }}
                className="rounded-[10px] border border-line bg-card px-3 py-2 text-[12.5px] font-normal text-ink-2"
              >
                <option value="">Tous les niveaux</option>
                {(Object.keys(ZONE_LEVEL_LABEL) as ZoneLevel[]).map((l) => (
                  <option key={l} value={l}>
                    {ZONE_LEVEL_LABEL[l]}
                  </option>
                ))}
              </select>
            </label>
          )}
        </div>
        <div className="flex items-center gap-2">
          <SearchBox label={config.searchLabel} value={text} onChange={setText} />
          <Can permission={PERMISSION}>
            {type === "zones" ? (
              treeMode && (
                <Button onClick={() => setForm({ zone: { parent: null, levels: ["pays"] } })}>Ajouter un pays</Button>
              )
            ) : (
              <Button onClick={() => setForm({})}>Ajouter {config.singular}</Button>
            )}
          </Can>
        </div>
      </div>

      {treeMode && (
        <ZoneTree
          busy={toggle.busy}
          onAdd={(zone) => setForm({ zone })}
          onEdit={(row) => setForm({ row })}
          onToggle={(row, action) => toggle.ask(row, action)}
        />
      )}

      {!treeMode && query.isError && !data && !outOfRange && (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">Impossible de charger la liste.</p>
          <Button variant="secondary" onClick={() => void query.refetch()}>
            Réessayer
          </Button>
        </div>
      )}
      {showTable && (
        <Table<RefRow>
          caption={config.title}
          columns={columns[type]}
          rows={data?.results ?? []}
          rowKey={rowId}
          loading={query.isLoading}
          emptyTitle="Aucun élément"
          emptyDescription="Aucun élément ne correspond à ces critères."
        />
      )}
      {!treeMode && data && <Pagination page={page} pageCount={pageCount} onPageChange={setPage} />}

      {form && <RefFormDialog type={type} row={form.row} initial={form.initial} zone={form.zone} onClose={() => setForm(null)} />}
      {toggle.dialog}
    </section>
  );
}

function itemColumns(stateColumn: Column<RefRow>, actionColumn: Column<RefRow>): Column<RefRow>[] {
  return [
    { key: "name", header: "Nom", render: (r) => marked(r, (r as AdminItem).name) },
    { key: "code", header: "Code", render: (r) => (r as AdminItem).code },
    { key: "order", header: "Ordre", render: (r) => (r as AdminItem).order },
    stateColumn,
    actionColumn,
  ];
}
