import { useState } from "react";
import { Button, type ButtonVariant } from "./Button";
import { Modal } from "./Modal";
import { Textarea } from "./Input";

interface ConfirmDialogProps {
  open: boolean;
  title: string;
  message?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  variant?: ButtonVariant;
  /** Si défini, un motif est exigé : le bouton reste désactivé tant qu'il est vide. */
  reasonLabel?: string;
  loading?: boolean;
  onConfirm: (reason?: string) => void;
  onCancel: () => void;
}

/** Confirmation réutilisable (rejet, blocage, suppression…), avec motif obligatoire à la demande. */
export function ConfirmDialog(props: ConfirmDialogProps) {
  // Le contenu est monté seulement à l'ouverture : le motif repart donc vide à chaque fois.
  if (!props.open) return null;
  return <ConfirmBody {...props} />;
}

function ConfirmBody({
  open,
  title,
  message,
  confirmLabel = "Confirmer",
  cancelLabel = "Annuler",
  variant = "danger",
  reasonLabel,
  loading = false,
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  const [reason, setReason] = useState("");
  const needsReason = reasonLabel !== undefined;
  const trimmed = reason.trim();
  const blocked = needsReason && trimmed === "";
  return (
    <Modal
      open={open}
      title={title}
      onClose={onCancel}
      footer={
        <>
          <Button variant="secondary" onClick={onCancel}>
            {cancelLabel}
          </Button>
          <Button
            variant={variant === "primary" ? "primary" : variant}
            disabled={blocked}
            loading={loading}
            onClick={() => onConfirm(needsReason ? trimmed : undefined)}
          >
            {confirmLabel}
          </Button>
        </>
      }
    >
      {message && <p className="text-[13px] text-ink-2">{message}</p>}
      {needsReason && <Textarea label={reasonLabel} value={reason} onChange={(e) => setReason(e.target.value)} required />}
    </Modal>
  );
}
