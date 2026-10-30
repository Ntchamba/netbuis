import { useRef, useState } from "react";
import { Button, Modal, Select, Textarea, useToast } from "../../../components/ui";
import { formatDate } from "../../../lib/dates";
import { grantError, type GrantError } from "../errors";
import { useGrantSubscription, useRefreshSubscriptions } from "../hooks";
import { MONTH_CHOICES, REASON_MAX, monthsToDays, type SubscriptionRow } from "../types";

const monthLabel = (m: number) => `${m} mois`;

/** Accord manuel d'un abonnement : saisie, puis confirmation récapitulative, puis envoi (un seul à la fois). */
export function GrantDialog({ row, onClose }: { row: SubscriptionRow; onClose: () => void }) {
  const toast = useToast();
  const grant = useGrantSubscription();
  const refresh = useRefreshSubscriptions();
  const [months, setMonths] = useState<number>(1);
  const [reason, setReason] = useState("");
  const [step, setStep] = useState<"form" | "confirm">("form");
  const [error, setError] = useState<GrantError | null>(null);
  const [sending, setSending] = useState(false);
  const lock = useRef(false);
  const trimmed = reason.trim();
  const days = monthsToDays(months);
  const busy = sending || grant.isPending;

  const next = () => {
    if (trimmed === "") {
      setError({ message: "", fields: { reason: "Le motif est obligatoire." }, refresh: false });
      return;
    }
    if (trimmed.length > REASON_MAX) {
      setError({ message: "", fields: { reason: `Le motif ne doit pas dépasser ${REASON_MAX} caractères.` }, refresh: false });
      return;
    }
    if (!MONTH_CHOICES.includes(months as (typeof MONTH_CHOICES)[number]) || !Number.isInteger(days) || days < 1 || days > 366) {
      setError({ message: "", fields: { duration_days: "Durée invalide : choisissez entre 1 et 12 mois." }, refresh: false });
      return;
    }
    setError(null);
    setStep("confirm");
  };

  const send = () => {
    if (lock.current) return;
    lock.current = true;
    setSending(true);
    grant.mutate(
      { business_id: row.id, duration_days: days, reason: trimmed },
      {
        onSuccess: (done) => {
          toast.success(`Abonnement accordé à ${done.business_name} jusqu'au ${formatDate(done.end)}.`);
          onClose();
        },
        onError: (err) => {
          const e = grantError(err, row.subscription_end);
          toast.error(e.message);
          if (e.refresh) {
            void refresh();
            onClose();
          } else {
            setError(e);
            if (e.fields) setStep("form");
          }
        },
        onSettled: () => {
          lock.current = false;
          setSending(false);
        },
      },
    );
  };

  const close = () => {
    if (!busy) onClose();
  };

  return (
    <Modal
      open
      title="Accorder un abonnement"
      onClose={close}
      footer={
        step === "form" ? (
          <>
            <Button variant="secondary" onClick={close}>
              Annuler
            </Button>
            <Button onClick={next}>Continuer</Button>
          </>
        ) : (
          <>
            <Button variant="secondary" disabled={busy} onClick={() => setStep("form")}>
              Retour
            </Button>
            <Button loading={busy} disabled={busy} onClick={send}>
              Confirmer l'accord
            </Button>
          </>
        )
      }
    >
      {step === "form" ? (
        <>
          <p className="text-[13px] text-ink-2">
            Commerce : <strong className="text-ink">{row.name}</strong>. L'abonnement démarre maintenant, sans paiement ; l'action est inscrite au journal d'audit.
          </p>
          <Select
            label="Durée"
            value={String(months)}
            onChange={(e) => setMonths(Number(e.target.value))}
            options={MONTH_CHOICES.map((m) => ({ value: String(m), label: monthLabel(m) }))}
            error={error?.fields?.duration_days}
          />
          <Textarea label="Motif" value={reason} maxLength={REASON_MAX} onChange={(e) => setReason(e.target.value)} required error={error?.fields?.reason} />
          <p data-testid="reason-counter" className="text-right text-[11.5px] text-ink-3">
            {reason.length} / {REASON_MAX}
          </p>
        </>
      ) : (
        <div data-testid="grant-recap" className="flex flex-col gap-2 text-[13px] text-ink-2">
          <p>Vous allez accorder un abonnement manuel. Cette action est inscrite au journal d'audit.</p>
          <p>
            Commerce : <strong className="text-ink">{row.name}</strong>
          </p>
          <p>
            Durée : <strong className="text-ink">{monthLabel(months)}</strong> ({days} jours)
          </p>
          <p>
            Motif : <span className="whitespace-pre-wrap text-ink">{trimmed}</span>
          </p>
        </div>
      )}
    </Modal>
  );
}
