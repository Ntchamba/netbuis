import { useRef, useState, type ReactNode } from "react";
import { Link } from "react-router-dom";
import { PATHS } from "../../../routes/paths";
import { Button, ConfirmDialog, Modal, Textarea, useToast } from "../../../components/ui";
import { moderationError } from "../errors";
import { useModerate, useRefreshReports } from "../hooks";
import { REASON_MAX_LENGTH, type ModerationActionKind, type ReportRow } from "../types";

const COPY: Record<ModerationActionKind, { title: string; confirm: string; done: string }> = {
  hide: { title: "Masquer le contenu", confirm: "Masquer", done: "Contenu masqué" },
  restore: { title: "Restaurer le contenu", confirm: "Restaurer", done: "Contenu restauré" },
  delete: { title: "Supprimer le contenu", confirm: "Supprimer", done: "Contenu supprimé" },
};

const MESSAGES: Record<ModerationActionKind, string> = {
  hide: "Le contenu disparaîtra du fil. Vous pourrez le restaurer. Le motif (facultatif) est conservé dans le journal.",
  restore: "Le contenu redeviendra visible dans le fil. Le motif (facultatif) est conservé dans le journal.",
  delete: "Le contenu sera supprimé. Le motif est conservé dans le journal.",
};

interface Target {
  type: ReportRow["target_type"];
  id: number;
  action: ModerationActionKind;
}

/** Statuts pour lesquels chaque action est proposée (publication / commentaire seulement). */
export function actionsFor(row: Pick<ReportRow, "target_type" | "content_status">): ModerationActionKind[] {
  if (row.target_type === "business") return [];
  if (row.content_status === "actif") return ["hide", "delete"];
  if (row.content_status === "masque") return ["restore", "delete"];
  return [];
}

/** Confirmation (motif facultatif pour masquer / restaurer, obligatoire pour supprimer) et envoi, sans double envoi. */
export function useModerationActions(): { ask: (row: ReportRow, action: ModerationActionKind) => void; busy: boolean; dialog: ReactNode } {
  const toast = useToast();
  const mutation = useModerate();
  const refresh = useRefreshReports();
  const [target, setTarget] = useState<Target | null>(null);
  const lock = useRef(false);
  const [sending, setSending] = useState(false);
  const busy = sending || mutation.isPending;

  const send = (text: string) => {
    if (!target || lock.current) return;
    if (target.action === "delete" && text === "") {
      toast.error("Le motif est obligatoire.");
      return;
    }
    if (text.length > REASON_MAX_LENGTH) {
      toast.error(`Le motif est trop long (${REASON_MAX_LENGTH} caractères au plus).`);
      return;
    }
    lock.current = true;
    setSending(true);
    mutation.mutate(
      { targetType: target.type, targetId: target.id, action: target.action, reason: text === "" ? undefined : text },
      {
        onSettled: () => {
          lock.current = false;
          setSending(false);
        },
        onSuccess: () => {
          setTarget(null);
          toast.success(COPY[target.action].done);
        },
        onError: (err) => {
          const e = moderationError(err);
          toast.error(e.message);
          if (e.refresh) {
            setTarget(null);
            void refresh();
          }
        },
      },
    );
  };

  const cancel = () => {
    if (!busy) setTarget(null);
  };

  let dialog: ReactNode;
  if (target?.action === "delete") {
    dialog = (
      <ConfirmDialog
        open
        title={COPY.delete.title}
        message={MESSAGES.delete}
        confirmLabel={COPY.delete.confirm}
        reasonLabel="Motif de la suppression"
        loading={busy}
        onConfirm={(r) => send((r ?? "").trim())}
        onCancel={cancel}
      />
    );
  } else if (target) {
    dialog = <OptionalReasonDialog action={target.action} busy={busy} onSend={send} onCancel={cancel} />;
  }

  return {
    ask: (row, action) => {
      setTarget({ type: row.target_type, id: row.target_id, action });
    },
    busy,
    dialog,
  };
}

/** Motif facultatif : l'état du champ est local pour que la saisie ne perde pas le focus. */
function OptionalReasonDialog({ action, busy, onSend, onCancel }: { action: ModerationActionKind; busy: boolean; onSend: (reason: string) => void; onCancel: () => void }) {
  const [reason, setReason] = useState("");
  const copy = COPY[action];
  return (
    <Modal
      open
      title={copy.title}
      onClose={onCancel}
      footer={
        <>
          <Button variant="secondary" onClick={onCancel}>
            Annuler
          </Button>
          <Button variant={action === "restore" ? "primary" : "danger"} loading={busy} onClick={() => onSend(reason.trim())}>
            {copy.confirm}
          </Button>
        </>
      }
    >
      <p className="text-[13px] text-ink-2">{MESSAGES[action]}</p>
      <Textarea label="Motif (facultatif)" value={reason} onChange={(e) => setReason(e.target.value)} />
    </Modal>
  );
}

const LABELS: Record<ModerationActionKind, string> = { hide: "Masquer", restore: "Restaurer", delete: "Supprimer" };

export function ModerationButtons({ row, busy, onAsk }: { row: ReportRow; busy: boolean; onAsk: (a: ModerationActionKind) => void }) {
  const actions = actionsFor(row);
  if (row.target_type === "business") {
    return (
      <p className="max-w-[200px] text-[12px] text-ink-2">
        Utilisez la page Comptes pour bloquer ce commerce.{" "}
        <Link to={PATHS.comptes} className="font-bold text-accent underline">
          Ouvrir Comptes
        </Link>
      </p>
    );
  }
  return (
    <div className="flex flex-wrap gap-2">
      {actions.map((a) => (
        <Button key={a} variant={a === "delete" ? "danger" : "secondary"} disabled={busy} onClick={() => onAsk(a)} className="px-3 py-1.5 text-[11.5px]">
          {LABELS[a]}
        </Button>
      ))}
    </div>
  );
}
