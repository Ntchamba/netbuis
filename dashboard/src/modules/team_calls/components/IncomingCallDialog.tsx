import { useEffect, useRef, useState } from "react";
import { Button } from "../../../components/ui";
import type { IncomingCall } from "../types";

/** Secondes restantes avant la fin de la sonnerie (null si le serveur n'en donne pas). */
export function secondsLeft(call: IncomingCall, now: number): number | null {
  return call.deadline === null ? null : Math.max(0, Math.ceil((call.deadline - now) / 1000));
}

interface Props {
  call: IncomingCall;
  /** Nombre d'autres appels qui sonnent aussi. */
  others: number;
  /** Une communication est déjà en cours : on ne peut pas répondre en même temps. */
  inCall: boolean;
  busy: boolean;
  onAccept: () => void;
  onDecline: () => void;
}

/** Fenêtre d'appel entrant : annoncée aux lecteurs d'écran (alertdialog), boutons de 44 px minimum. */
export function IncomingCallDialog({ call, others, inCall, busy, onAccept, onDecline }: Props) {
  const [now, setNow] = useState(() => Date.now());
  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 250);
    return () => clearInterval(id);
  }, []);

  // Le focus va sur « Répondre » : Entrée répond, Tab passe à « Refuser ».
  useEffect(() => {
    root.current?.querySelector<HTMLButtonElement>("button:not(:disabled)")?.focus();
  }, [call.sessionId]);

  const left = secondsLeft(call, now);
  const subject = call.business ? `Appel au sujet de ${call.business.name}` : "Appel sans commerce précisé";

  return (
    <div
      ref={root}
      role="alertdialog"
      aria-modal="false"
      aria-labelledby="incoming-call-title"
      aria-describedby="incoming-call-desc"
      data-testid="incoming-call"
      className="fixed right-4 top-4 z-50 flex w-[min(380px,calc(100vw-2rem))] flex-col gap-4 rounded-2xl border border-accent bg-card p-5 text-ink shadow-2xl"
    >
      <div>
        <p className="text-[11.5px] font-bold uppercase text-accent-ink">Appel entrant</p>
        <h2 id="incoming-call-title" className="mt-1 text-[19px] font-extrabold">
          {call.callerName}
        </h2>
        <p id="incoming-call-desc" className="mt-1 text-[13px] text-ink-2">
          {subject}
        </p>
        {left !== null && (
          <p className="mt-2 text-[12.5px] font-semibold text-ink-2">
            <span aria-hidden="true">Sonnerie : {left} s</span>
            <span className="sr-only">Sonnerie encore {left} secondes</span>
          </p>
        )}
        {others > 0 && <p className="mt-1 text-[12px] text-ink-3">{others === 1 ? "1 autre appel sonne aussi." : `${others} autres appels sonnent aussi.`}</p>}
        {inCall && <p className="mt-2 text-[12.5px] text-warn">Terminez l'appel en cours pour répondre.</p>}
      </div>
      <div className="flex gap-3">
        <Button className="min-h-11 flex-1" disabled={inCall} loading={busy} onClick={onAccept}>
          Répondre
        </Button>
        <Button variant="danger" className="min-h-11 flex-1" onClick={onDecline}>
          Refuser
        </Button>
      </div>
    </div>
  );
}
