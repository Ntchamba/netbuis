import { useState } from "react";
import { Button, Skeleton } from "../../../components/ui";
import { useReferentials } from "../hooks";
import { CHILD_LEVELS, TREE_PAGE_SIZE, ZONE_LEVEL_LABEL, type ActiveAction, type AdminZone } from "../types";
import type { ZoneContext } from "./RefFormDialog";
import { RowActions, StatusBadge } from "./RowParts";

export interface TreeHandlers {
  busy: boolean;
  onAdd: (zone: ZoneContext) => void;
  onEdit: (row: AdminZone) => void;
  onToggle: (row: AdminZone, action: ActiveAction) => void;
}

/** Arbre des zones : chaque niveau est chargé au dépliage (filtre `parent`), jamais d'un seul bloc. */
export function ZoneTree(handlers: TreeHandlers) {
  return (
    <div className="overflow-hidden rounded-2xl border border-line bg-card" data-testid="zone-tree">
      <ul aria-label="Arbre des zones" className="m-0 list-none p-0">
        <ZoneBranch parent="root" depth={0} handlers={handlers} />
      </ul>
    </div>
  );
}

function ZoneBranch({ parent, depth, handlers }: { parent: number | "root"; depth: number; handlers: TreeHandlers }) {
  const [pages, setPages] = useState(1);
  return (
    <>
      {Array.from({ length: pages }, (_, i) => (
        <ZoneBranchPage
          key={i}
          parent={parent}
          page={i + 1}
          depth={depth}
          handlers={handlers}
          isLast={i === pages - 1}
          onMore={() => setPages(pages + 1)}
        />
      ))}
    </>
  );
}

function ZoneBranchPage({
  parent,
  page,
  depth,
  handlers,
  isLast,
  onMore,
}: {
  parent: number | "root";
  page: number;
  depth: number;
  handlers: TreeHandlers;
  isLast: boolean;
  onMore: () => void;
}) {
  const query = useReferentials("zones", { page, pageSize: TREE_PAGE_SIZE, extra: { parent } });
  const indent = { paddingLeft: 18 + depth * 24 };
  if (query.isLoading) {
    return (
      <li data-loading-row aria-busy="true" style={indent} className="border-b border-line py-3 pr-[18px]">
        <Skeleton className="h-4 w-1/2" />
      </li>
    );
  }
  if (query.isError && !query.data) {
    return (
      <li role="alert" style={indent} className="flex items-center gap-3 border-b border-line py-3 pr-[18px] text-[13px] text-danger">
        Impossible de charger les zones.
        <Button variant="secondary" className="px-3 py-1.5 text-[11.5px]" onClick={() => void query.refetch()}>
          Réessayer
        </Button>
      </li>
    );
  }
  const rows = (query.data?.results ?? []) as AdminZone[];
  return (
    <>
      {rows.length === 0 && page === 1 && (
        <li style={indent} className="border-b border-line py-3 pr-[18px] text-[12.5px] text-ink-2">
          {parent === "root" ? "Aucune zone pour le moment." : "Aucune zone à ce niveau."}
        </li>
      )}
      {rows.map((row) => (
        <ZoneNode key={row.id} row={row} depth={depth} handlers={handlers} />
      ))}
      {isLast && query.data?.next && (
        <li style={indent} className="border-b border-line py-3 pr-[18px]">
          <Button variant="secondary" className="px-3 py-1.5 text-[11.5px]" onClick={onMore}>
            Voir plus
          </Button>
        </li>
      )}
    </>
  );
}

function ZoneNode({ row, depth, handlers }: { row: AdminZone; depth: number; handlers: TreeHandlers }) {
  const [open, setOpen] = useState(false);
  const childLevels = CHILD_LEVELS[row.level];
  const canExpand = childLevels.length > 0;
  return (
    <li className="border-b border-line last:border-b-0">
      <div style={{ paddingLeft: 18 + depth * 24 }} className="flex flex-wrap items-center gap-3 py-2.5 pr-[18px]">
        {canExpand ? (
          <button
            type="button"
            aria-expanded={open}
            aria-label={`${open ? "Replier" : "Déplier"} ${row.name}`}
            onClick={() => setOpen(!open)}
            className="flex h-6 w-6 shrink-0 cursor-pointer items-center justify-center rounded-md border border-line bg-transparent text-ink-2"
          >
            <span aria-hidden="true">{open ? "▾" : "▸"}</span>
          </button>
        ) : (
          <span className="inline-block h-6 w-6 shrink-0" aria-hidden="true" />
        )}
        <span data-testid={`zone-${row.id}`} className="min-w-0 flex-1 text-[13px] font-semibold text-ink">
          {row.name}
          <span className="ml-2 text-[11.5px] font-normal text-ink-3">{ZONE_LEVEL_LABEL[row.level]}</span>
        </span>
        <StatusBadge active={row.is_active} />
        <RowActions row={row} busy={handlers.busy} onEdit={() => handlers.onEdit(row)} onToggle={(a) => handlers.onToggle(row, a)}>
          {canExpand && row.is_active && (
            <Button
              variant="secondary"
              className="px-2.5 py-1.5 text-[11.5px]"
              disabled={handlers.busy}
              aria-label={`Ajouter une zone dans ${row.name}`}
              onClick={() => handlers.onAdd({ parent: { id: row.id, name: row.name }, levels: childLevels })}
            >
              + Ajouter
            </Button>
          )}
        </RowActions>
      </div>
      {open && (
        <ul className="m-0 list-none p-0">
          <ZoneBranch parent={row.id} depth={depth + 1} handlers={handlers} />
        </ul>
      )}
    </li>
  );
}
