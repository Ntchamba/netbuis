import { Table, type Column } from "../../../components/ui";

interface Row {
  id: number;
  rank: number;
  name: string;
  zone?: string;
}

/** Classement (rang et nom) : sans compteur, sans lien, sans numéro. */
export function TrendTable({ rows, caption, nameHeader, showZone = false }: { rows: Row[]; caption: string; nameHeader: string; showZone?: boolean }) {
  const columns: Column<Row>[] = [
    { key: "rank", header: "Rang", render: (r) => r.rank },
    { key: "name", header: nameHeader, render: (r) => r.name },
    ...(showZone ? [{ key: "zone", header: "Zone", render: (r: Row) => r.zone ?? "" }] : []),
  ];
  return <Table columns={columns} rows={[...rows].sort((a, b) => a.rank - b.rank)} rowKey={(r) => r.id} caption={caption} emptyTitle="Aucun élément" emptyDescription="Pas assez de recherches pour établir un classement." />;
}
