import type { ReactNode } from "react";
import { cn } from "../../lib/cn";
import { EmptyState } from "./EmptyState";
import { Skeleton } from "./Spinner";

export interface Column<T> {
  key: string;
  header: string;
  render: (row: T) => ReactNode;
  align?: "left" | "right";
}

interface TableProps<T> {
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T) => string | number;
  loading?: boolean;
  emptyTitle?: string;
  emptyDescription?: string;
  caption?: string;
}

/** Tableau de la maquette Comptes : carte arrondie, en-têtes en capitales grises, lignes séparées. */
export function Table<T>({ columns, rows, rowKey, loading = false, emptyTitle = "Aucun résultat", emptyDescription, caption }: TableProps<T>) {
  const align = (c: Column<T>) => (c.align === "right" ? "text-right" : "text-left");
  return (
    <div className="overflow-hidden rounded-2xl border border-line bg-card">
      <table className="w-full border-collapse">
        {caption && <caption className="sr-only">{caption}</caption>}
        <thead>
          <tr className="border-b border-line">
            {columns.map((c) => (
              <th key={c.key} scope="col" className={cn("px-[18px] py-3 text-[11.5px] font-bold uppercase text-ink-3", align(c))}>
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody aria-busy={loading || undefined}>
          {loading &&
            [0, 1, 2].map((i) => (
              <tr key={`sk-${i}`} data-loading-row className="border-b border-line">
                {columns.map((c) => (
                  <td key={c.key} className="px-[18px] py-[14px]">
                    <Skeleton className="h-4 w-3/4" />
                  </td>
                ))}
              </tr>
            ))}
          {!loading && rows.length === 0 && (
            <tr>
              <td colSpan={columns.length}>
                <EmptyState title={emptyTitle} description={emptyDescription} />
              </td>
            </tr>
          )}
          {!loading &&
            rows.map((row) => (
              <tr key={rowKey(row)} className="border-b border-line last:border-b-0">
                {columns.map((c) => (
                  <td key={c.key} className={cn("px-[18px] py-[14px] text-[13px] text-ink", align(c))}>
                    {c.render(row)}
                  </td>
                ))}
              </tr>
            ))}
        </tbody>
      </table>
    </div>
  );
}
