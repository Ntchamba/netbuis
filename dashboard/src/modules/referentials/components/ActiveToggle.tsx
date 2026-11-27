import { useRef, useState, type ReactNode } from "react";
import { Button, ConfirmDialog, Modal, Textarea, useToast } from "../../../components/ui";
import { referentialError } from "../errors";
import { useRefreshReferentials, useSetActive } from "../hooks";
import { REASON_MAX, rowName, type ActiveAction, type RefRow, type RefType } from "../types";

export const PERMISSION = "peut_gerer_referentiels";

interface Target {
  id: number;
  name: string;
  action: ActiveAction;
}

/**
 * Désactivation (motif facultatif) et réactivation (confirmation simple). Il n'existe aucune suppression :
 * ni bouton « Supprimer », ni requête DELETE.
 */
export function useActiveToggle(type: RefType): { ask: (row: RefRow, action: ActiveAction) => void; busy: boolean; dialog: ReactNode } {
  const toast = useToast();
  const mutation = useSetActive(type);
  const refresh = useRefreshReferentials();
  const [target, setTarget] = useState<Target | null>(null);
  const [sending, setSending] = useState(false);
  const lock = useRef(false);
  const busy = sending || mutation.isPending;

  const send = (reason?: string) => {
    if (!target || lock.current) return;
    lock.current = true;
    setSending(true);
    mutation.mutate(
      { id: target.id, action: target.action, reason: reason?.trim() || undefined },
      {
        onSettled: () => {
          lock.current = false;
          setSending(false);
        },
        onSuccess: () => {
          toast.success(target.action === "deactivate" ? "Élément désactivé" : "Élément réactivé");
          setTarget(null);
        },
        onError: (err) => {
          const e = referentialError(err);
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

  const dialog = target ? (
    target.action === "deactivate" ? (
      <DeactivateDialog name={target.name} loading={busy} onConfirm={send} onCancel={cancel} />
    ) : (
      <ConfirmDialog
        open
        title="Réactiver l'élément"
        message={`« ${target.name} » sera de nouveau proposé aux commerçants.`}
        confirmLabel="Réactiver"
        variant="primary"
        loading={busy}
        onConfirm={() => send()}
        onCancel={cancel}
      />
    )
  ) : null;

  return { ask: (row, action) => setTarget({ id: row.id, name: rowName(row), action }), busy, dialog };
}

function DeactivateDialog({ name, loading, onConfirm, onCancel }: { name: string; loading: boolean; onConfirm: (reason?: string) => void; onCancel: () => void }) {
  const [reason, setReason] = useState("");
  const tooLong = reason.trim().length > REASON_MAX;
  return (
    <Modal
      open
      title="Désactiver l'élément"
      onClose={onCancel}
      footer={
        <>
          <Button variant="secondary" onClick={onCancel}>
            Annuler
          </Button>
          <Button variant="danger" loading={loading} disabled={tooLong} onClick={() => onConfirm(reason)}>
            Désactiver
          </Button>
        </>
      }
    >
      <p className="text-[13px] text-ink-2">
        « {name} » ne sera plus proposé aux commerçants. Rien n'est supprimé : vous pourrez le réactiver à tout moment.
      </p>
      <Textarea
        label="Motif (facultatif)"
        value={reason}
        onChange={(e) => setReason(e.target.value)}
        error={tooLong ? `Le motif est trop long (${REASON_MAX} caractères au plus).` : undefined}
      />
    </Modal>
  );
}
