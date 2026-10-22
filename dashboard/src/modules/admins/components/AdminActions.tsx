import { useRef, useState, type ReactNode } from "react";
import { Button, ConfirmDialog, Modal, Select, useToast } from "../../../components/ui";
import { adminError } from "../errors";
import { useChangeAdminRole, useRefreshAdmins, useRemoveAdminRole } from "../hooks";
import { ADMIN_ROLES, type AdminItem, type AdminRole } from "../types";

type Target = { admin: Pick<AdminItem, "id" | "name" | "roles">; action: "role" | "remove" };

/** Changement de rôle et retrait de rôle (motif obligatoire), sans double envoi. */
export function useAdminActions(): { ask: (admin: Target["admin"], action: Target["action"]) => void; busy: boolean; dialog: ReactNode } {
  const toast = useToast();
  const change = useChangeAdminRole();
  const remove = useRemoveAdminRole();
  const refresh = useRefreshAdmins();
  const [target, setTarget] = useState<Target | null>(null);
  const [sending, setSending] = useState(false);
  const lock = useRef(false);
  const busy = sending || change.isPending || remove.isPending;

  const settle = {
    onSettled: () => {
      lock.current = false;
      setSending(false);
    },
    onError: (err: unknown) => {
      const e = adminError(err);
      toast.error(e.message);
      if (e.refresh) {
        setTarget(null);
        void refresh();
      }
    },
  };

  const begin = () => {
    if (lock.current) return false;
    lock.current = true;
    setSending(true);
    return true;
  };

  const onRemove = (reason?: string) => {
    if (!target || !begin()) return;
    const text = (reason ?? "").trim();
    if (text === "") {
      lock.current = false;
      setSending(false);
      toast.error("Le motif est obligatoire.");
      return;
    }
    remove.mutate(
      { id: target.admin.id, reason: text },
      {
        ...settle,
        onSuccess: () => {
          setTarget(null);
          toast.success("Rôle retiré");
        },
      },
    );
  };

  const onRole = (role: AdminRole) => {
    if (!target || !begin()) return;
    change.mutate(
      { id: target.admin.id, role },
      {
        ...settle,
        onSuccess: () => {
          setTarget(null);
          toast.success("Rôle modifié");
        },
      },
    );
  };

  const cancel = () => {
    if (!busy) setTarget(null);
  };

  const dialog = (
    <>
      <ConfirmDialog
        open={target?.action === "remove"}
        title="Retirer le rôle d'administration"
        message={target ? `${target.admin.name} n'aura plus accès au dashboard et sera déconnecté. Le compte n'est pas supprimé. Le motif est conservé dans le journal.` : undefined}
        confirmLabel="Retirer le rôle"
        reasonLabel="Motif du retrait"
        loading={busy}
        onConfirm={onRemove}
        onCancel={cancel}
      />
      {target?.action === "role" && <RoleDialog admin={target.admin} busy={busy} onConfirm={onRole} onCancel={cancel} />}
    </>
  );

  return { ask: (admin, action) => setTarget({ admin, action }), busy, dialog };
}

function RoleDialog({ admin, busy, onConfirm, onCancel }: { admin: Target["admin"]; busy: boolean; onConfirm: (role: AdminRole) => void; onCancel: () => void }) {
  const current = admin.roles[0] ?? "";
  const [role, setRole] = useState<string>(current);
  return (
    <Modal
      open
      title="Changer le rôle"
      onClose={onCancel}
      footer={
        <>
          <Button variant="secondary" onClick={onCancel}>
            Annuler
          </Button>
          <Button disabled={role === current} loading={busy} onClick={() => onConfirm(role as AdminRole)}>
            Changer le rôle
          </Button>
        </>
      }
    >
      <p className="text-[13px] text-ink-2">Nouveau rôle de {admin.name}.</p>
      <Select label="Rôle" value={role} onChange={(e) => setRole(e.target.value)} options={ADMIN_ROLES.map((r) => ({ value: r, label: r }))} />
    </Modal>
  );
}
