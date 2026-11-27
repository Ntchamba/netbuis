import { Badge, Table, type Column } from "../../../components/ui";
import { ModerationButtons } from "./ModerationActions";
import { REASON_LABELS, TARGET_LABELS, type ModerationActionKind, type ReportRow } from "../types";

const PREVIEW_MAX = 140;

/** Statut du contenu : badge (actif, masqué, supprimé) ; pour un commerce, le statut de son compte tel que reçu. */
function StatusBadge({ row }: { row: ReportRow }) {
  switch (row.content_status) {
    case "actif":
      return <Badge status="actif" />;
    case "masque":
      return <Badge status="bloque">Masqué</Badge>;
    case "supprime":
      return <Badge status="supprime" />;
    case "en_attente_validation":
      return <Badge status="en_attente" />;
    case "rejete":
      return <Badge status="rejete" />;
    default:
      return <Badge>{row.content_status}</Badge>;
  }
}

/** Aperçu en TEXTE SIMPLE (React échappe tout) : jamais interprété en HTML, aucun média chargé. */
function Preview({ row }: { row: ReportRow }) {
  const text = row.preview.length > PREVIEW_MAX ? `${row.preview.slice(0, PREVIEW_MAX)}…` : row.preview;
  return (
    <div className="flex max-w-[280px] flex-col gap-1">
      <span className="break-words">{text}</span>
      {row.media_type && <span className="text-[11.5px] font-semibold text-ink-3">{row.media_type === "video" ? "Vidéo jointe" : "Photo jointe"}</span>}
    </div>
  );
}

interface Props {
  rows: ReportRow[];
  loading: boolean;
  busy: boolean;
  onAsk: (row: ReportRow, action: ModerationActionKind) => void;
}

export function ReportQueue({ rows, loading, busy, onAsk }: Props) {
  const columns: Column<ReportRow>[] = [
    { key: "cible", header: "Cible", render: (r) => TARGET_LABELS[r.target_type] },
    { key: "apercu", header: "Aperçu", render: (r) => <Preview row={r} /> },
    {
      key: "auteur",
      header: "Auteur",
      render: (r) => (
        <div className="flex flex-col">
          <span className="font-bold">{r.author_name}</span>
          <span className="text-[12px] text-ink-2">{r.author_phone_masked}</span>
        </div>
      ),
    },
    {
      key: "motifs",
      header: "Motifs",
      render: (r) => (
        <div className="flex flex-wrap gap-1.5">
          {r.reasons.map((m) => (
            <Badge key={m.reason}>
              {REASON_LABELS[m.reason] ?? m.reason} ×{m.count}
            </Badge>
          ))}
        </div>
      ),
    },
    { key: "signalants", header: "Signalants", render: (r) => r.reporters_count },
    { key: "statut", header: "Statut", render: (r) => <StatusBadge row={r} /> },
    { key: "actions", header: "Actions", render: (r) => <ModerationButtons row={r} busy={busy} onAsk={(a) => onAsk(r, a)} /> },
  ];
  return (
    <Table
      caption="Contenus signalés"
      columns={columns}
      rows={rows}
      loading={loading}
      rowKey={(r) => `${r.target_type}-${r.target_id}`}
      emptyTitle="Aucun signalement en attente"
    />
  );
}
