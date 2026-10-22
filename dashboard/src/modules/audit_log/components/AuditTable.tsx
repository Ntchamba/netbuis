import { useState } from "react";
import { Link } from "react-router-dom";
import { Table, type Column } from "../../../components/ui";
import { formatDateTime } from "../../../lib/dates";
import { PATHS } from "../../../routes/paths";
import { ACCOUNT_TARGET, actionLabel, targetLabel, type AuditEntry } from "../types";

export const REASON_PREVIEW = 120;

/** Motif en texte simple (jamais en HTML), tronqué avec « Voir plus » s'il est long. */
function Reason({ text }: { text: string }) {
  const [open, setOpen] = useState(false);
  if (text === "") return <span className="text-ink-3">—</span>;
  const long = text.length > REASON_PREVIEW;
  return (
    <span className="whitespace-pre-wrap break-words text-ink-2">
      {long && !open ? `${text.slice(0, REASON_PREVIEW).trimEnd()}…` : text}
      {long && (
        <button type="button" aria-expanded={open} onClick={() => setOpen(!open)} className="ml-2 cursor-pointer text-[12px] font-bold text-accent-ink underline">
          {open ? "Voir moins" : "Voir plus"}
        </button>
      )}
    </span>
  );
}

function Target({ row }: { row: AuditEntry }) {
  const text = `${targetLabel(row.target_type)} #${row.target_id}`;
  if (row.target_type === ACCOUNT_TARGET) {
    return (
      <Link to={PATHS.compte.replace(":id", String(row.target_id))} className="font-bold text-accent-ink underline">
        {text}
      </Link>
    );
  }
  return <span>{text}</span>;
}

const COLUMNS: Column<AuditEntry>[] = [
  { key: "date", header: "Date", render: (r) => <span className="whitespace-nowrap text-ink-2">{formatDateTime(r.created_at)}</span> },
  { key: "admin", header: "Admin", render: (r) => <span className="font-bold">{r.admin_name}</span> },
  { key: "action", header: "Action", render: (r) => actionLabel(r.action) },
  { key: "target", header: "Cible", render: (r) => <Target row={r} /> },
  { key: "reason", header: "Motif", render: (r) => <Reason text={r.reason} /> },
];

export function AuditTable({ rows, loading }: { rows: AuditEntry[]; loading: boolean }) {
  return <Table columns={COLUMNS} rows={rows} rowKey={(r) => r.id} loading={loading} caption="Journal d'audit" emptyTitle="Aucune action sur cette période" />;
}
