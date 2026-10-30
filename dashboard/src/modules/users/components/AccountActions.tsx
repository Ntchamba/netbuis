import { useRef, useState, type ReactNode } from "react";
import { Can } from "../../../auth/permissions";
import { Button, ConfirmDialog, useToast } from "../../../components/ui";
import { useAccountAction, useRefreshAccounts } from "../hooks";
import { BLOCK_REASON_MAX, DELETE_REASON_MAX, type AccountAction, type AccountListItem } from "../types";

/** Message clair selon l'erreur du serveur ; `refresh` : l'état affiché doit être rechargé. */
export function actionError(err: unknown): { message: string; refresh: boolean } {
  const response = (err as { response?: { status?: number; data?: { code?: string } } }).response;
  if (!response) return { message: "Connexion impossible. Vérifiez le réseau, puis réessayez.", refresh: false };
  const code = response.data?.code;
  switch (response.status) {
    case 409:
      return code === "last_full_admin"
        ? { message: "Action impossible : c'est le dernier Administrateur complet actif.", refresh: false }
        : { message: "L'état de ce compte a changé entre-temps. L'affichage a été actualisé.", refresh: true };
    case 404:
      return { message: "Ce compte n'existe plus. L'affichage a été actualisé.", refresh: true };
    case 400:
      if (code === "self_action_forbidden") return { message: "Vous ne pouvez pas agir sur votre propre compte.", refresh: false };
      if (code === "reason_required") return { message: "Le motif est obligatoire.", refresh: false };
      return { message: "L'action n'a pas pu être envoyée. Vérifiez les informations.", refresh: false };
    case 403:
      return { message: "Vous n'avez pas le droit d'effectuer cette action.", refresh: false };
    default:
      return { message: "Une erreur est survenue. Réessayez dans un instant.", refresh: false };
  }
}

const COPY: Record<AccountAction, { title: string; confirm: string; done: string; reasonLabel?: string; max?: number }> = {
  block: { title: "Bloquer le compte", confirm: "Bloquer", done: "Compte bloqué", reasonLabel: "Motif du blocage", max: BLOCK_REASON_MAX },
  unblock: { title: "Débloquer le compte", confirm: "Débloquer", done: "Compte débloqué" },
  delete: { title: "Supprimer le compte", confirm: "Supprimer", done: "Compte supprimé", reasonLabel: "Motif de la suppression", max: DELETE_REASON_MAX },
  restore: { title: "Restaurer le compte", confirm: "Restaurer", done: "Compte restauré" },
};

const MESSAGES: Record<AccountAction, (name: string) => string> = {
  block: (n) => `${n} ne pourra plus se connecter. Le motif est conservé dans le journal.`,
  unblock: (n) => `${n} pourra de nouveau se connecter.`,
  delete: (n) => `${n} sera supprimé (suppression douce : le compte pourra être restauré). Le motif est conservé dans le journal.`,
  restore: (n) => `${n} sera de nouveau actif.`,
};

interface Target {
  id: number;
  name: string;
  action: AccountAction;
}

/** Fenêtre de confirmation (motif obligatoire pour bloquer et supprimer) et envoi, sans double envoi. */
export function useAccountActions(): { ask: (account: Pick<AccountListItem, "id" | "name">, action: AccountAction) => void; busy: boolean; dialog: ReactNode } {
  const toast = useToast();
  const mutation = useAccountAction();
  const refresh = useRefreshAccounts();
  const [target, setTarget] = useState<Target | null>(null);
  const lock = useRef(false);
  const [sending, setSending] = useState(false);
  const busy = sending || mutation.isPending;

  const onConfirm = (reason?: string) => {
    if (!target || lock.current) return;
    const copy = COPY[target.action];
    const text = (reason ?? "").trim();
    if (copy.reasonLabel) {
      if (text === "") {
        toast.error("Le motif est obligatoire.");
        return;
      }
      if (copy.max !== undefined && text.length > copy.max) {
        toast.error(`Le motif est trop long (${copy.max} caractères au plus).`);
        return;
      }
    }
    lock.current = true;
    setSending(true);
    mutation.mutate(
      { id: target.id, action: target.action, reason: copy.reasonLabel ? text : undefined },
      {
        onSettled: () => {
          lock.current = false;
          setSending(false);
        },
        onSuccess: () => {
          setTarget(null);
          toast.success(copy.done);
        },
        onError: (err) => {
          const e = actionError(err);
          toast.error(e.message);
          if (e.refresh) {
            setTarget(null);
            void refresh();
          }
        },
      },
    );
  };

  const copy = target ? COPY[target.action] : null;
  const dialog = (
    <ConfirmDialog
      open={target !== null}
      title={copy?.title ?? ""}
      message={target ? MESSAGES[target.action](target.name) : undefined}
      confirmLabel={copy?.confirm}
      variant={target && (target.action === "unblock" || target.action === "restore") ? "primary" : "danger"}
      reasonLabel={copy?.reasonLabel}
      loading={busy}
      onConfirm={onConfirm}
      onCancel={() => {
        if (!busy) setTarget(null);
      }}
    />
  );

  return { ask: (account, action) => setTarget({ id: account.id, name: account.name, action }), busy, dialog };
}

interface ButtonsProps {
  account: Pick<AccountListItem, "id" | "name" | "is_blocked" | "is_deleted">;
  busy: boolean;
  onAsk: (action: AccountAction) => void;
  /** Bouton Supprimer sous forme d'icône (tableau) ou de texte (détail). */
  compact?: boolean;
}

/** Boutons d'action : absents (et non seulement désactivés) sans le droit du serveur. */
export function AccountActionButtons({ account, busy, onAsk, compact = false }: ButtonsProps) {
  return (
    <>
      {account.is_deleted ? (
        <Can permission="peut_supprimer_compte">
          <Button variant="secondary" disabled={busy} onClick={() => onAsk("restore")} className={compact ? "px-3 py-1.5 text-[11.5px]" : undefined}>
            Restaurer
          </Button>
        </Can>
      ) : (
        <>
          <Can permission="peut_bloquer_compte">
            <Button
              variant="secondary"
              disabled={busy}
              onClick={() => onAsk(account.is_blocked ? "unblock" : "block")}
              className={compact ? "px-2.5 py-1.5 text-[11.5px]" : undefined}
            >
              {account.is_blocked ? "Débloquer" : "Bloquer"}
            </Button>
          </Can>
          <Can permission="peut_supprimer_compte">
            {compact ? (
              <button
                type="button"
                aria-label="Supprimer"
                disabled={busy}
                onClick={() => onAsk("delete")}
                className="flex h-[30px] w-[30px] cursor-pointer items-center justify-center rounded-lg border border-danger-bg bg-transparent text-danger disabled:cursor-not-allowed disabled:opacity-50"
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
                  <path d="M3 6h18" />
                  <path d="M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                  <path d="M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6" />
                </svg>
              </button>
            ) : (
              <Button variant="danger" disabled={busy} onClick={() => onAsk("delete")}>
                Supprimer
              </Button>
            )}
          </Can>
        </>
      )}
    </>
  );
}
