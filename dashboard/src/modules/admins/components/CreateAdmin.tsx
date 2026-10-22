import { useRef, useState } from "react";
import { Button, Input, Modal, Select, useToast } from "../../../components/ui";
import { normalizeCameroonPhone } from "../../../lib/format";
import { adminError } from "../errors";
import { useCreateAdmin } from "../hooks";
import { ADMIN_ROLES, NAME_MAX, type AdminRole } from "../types";
import { TemporaryPasswordDialog } from "./TemporaryPasswordDialog";

const ROLE_OPTIONS = ADMIN_ROLES.map((r) => ({ value: r, label: r }));

/** Bouton « Créer un administrateur », sa fenêtre de saisie, puis la fenêtre du mot de passe temporaire. */
export function CreateAdmin() {
  const toast = useToast();
  const mutation = useCreateAdmin();
  const [open, setOpen] = useState(false);
  const lock = useRef(false);
  const [sending, setSending] = useState(false);
  const busy = sending || mutation.isPending;

  return (
    <>
      <Button onClick={() => setOpen(true)}>Créer un administrateur</Button>
      {open && (
        <CreateForm
          busy={busy}
          onCancel={() => {
            if (!busy) setOpen(false);
          }}
          onSubmit={(input, fail) => {
            if (lock.current) return;
            lock.current = true;
            setSending(true);
            mutation.mutate(input, {
              onSettled: () => {
                lock.current = false;
                setSending(false);
              },
              onSuccess: () => {
                setOpen(false);
                toast.success("Administrateur créé");
              },
              onError: (err) => {
                const e = adminError(err);
                fail(e.message, e.field);
              },
            });
          }}
        />
      )}
      {mutation.isSuccess && mutation.data && (
        <TemporaryPasswordDialog name={mutation.data.name} password={mutation.data.temporary_password} onDone={() => mutation.reset()} />
      )}
    </>
  );
}

interface FormProps {
  busy: boolean;
  onCancel: () => void;
  onSubmit: (input: { phone: string; name: string; role: AdminRole }, fail: (message: string, field?: "phone" | "name" | "role") => void) => void;
}

function CreateForm({ busy, onCancel, onSubmit }: FormProps) {
  const [phone, setPhone] = useState("");
  const [name, setName] = useState("");
  const [role, setRole] = useState<AdminRole | "">("");
  const [errors, setErrors] = useState<{ phone?: string; name?: string; role?: string; form?: string }>({});

  const submit = () => {
    const next: typeof errors = {};
    const normalized = normalizeCameroonPhone(phone);
    if (normalized === null) next.phone = "Numéro invalide : format attendu +237 6XXXXXXXX.";
    const trimmed = name.trim();
    if (trimmed === "") next.name = "Le nom est obligatoire.";
    else if (trimmed.length > NAME_MAX) next.name = `Le nom est trop long (${NAME_MAX} caractères au plus).`;
    if (role === "") next.role = "Choisissez un rôle.";
    setErrors(next);
    if (normalized === null || role === "" || next.name) return;
    onSubmit({ phone: normalized, name: trimmed, role }, (message, field) => setErrors(field ? { [field]: message } : { form: message }));
  };

  return (
    <Modal
      open
      title="Créer un administrateur"
      onClose={onCancel}
      footer={
        <>
          <Button variant="secondary" onClick={onCancel}>
            Annuler
          </Button>
          <Button loading={busy} onClick={submit}>
            Créer
          </Button>
        </>
      }
    >
      <Input label="Numéro de téléphone" type="tel" autoComplete="off" placeholder="+237 6XXXXXXXX" value={phone} error={errors.phone} onChange={(e) => setPhone(e.target.value)} />
      <Input label="Nom" autoComplete="off" value={name} error={errors.name} onChange={(e) => setName(e.target.value)} />
      <Select
        label="Rôle"
        value={role}
        error={errors.role}
        onChange={(e) => setRole(e.target.value as AdminRole | "")}
        options={[{ value: "", label: "Choisir un rôle" }, ...ROLE_OPTIONS]}
      />
      <p className="text-[12px] text-ink-2">
        Un mot de passe temporaire sera généré et affiché une seule fois. Il reste valable jusqu'à son changement (aucun changement de mot de passe n'est possible pour l'instant).
      </p>
      {errors.form && (
        <p role="alert" className="text-[12px] text-danger">
          {errors.form}
        </p>
      )}
    </Modal>
  );
}
