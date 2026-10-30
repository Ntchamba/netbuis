import { useState } from "react";
import { useCalls } from "../CallsProvider";
import { CallErrorBoundary } from "./CallErrorBoundary";
import { CallFichePanel } from "./CallFichePanel";
import { CallRoom } from "./CallRoom";
import { IncomingCallDialog } from "./IncomingCallDialog";

/** Fenêtre d'appel entrant et salle Jitsi, au-dessus de toutes les pages. */
export function CallsOverlay() {
  const { enabled, notice, incoming, active, answering, accept, decline, hangUp } = useCalls();
  const [fiche, setFiche] = useState<string | null>(null); // appel dont la fiche est ouverte
  if (!enabled) return null;
  const first = incoming[0];
  return (
    <CallErrorBoundary onAbort={() => void hangUp()}>
      {first && (
        <IncomingCallDialog
          key={first.sessionId}
          call={first}
          others={incoming.length - 1}
          inCall={active !== null}
          busy={answering}
          onAccept={() => void accept(first.sessionId)}
          onDecline={() => void decline(first.sessionId)}
        />
      )}
      {notice && (
        <p role="alert" className="fixed bottom-4 left-1/2 z-50 -translate-x-1/2 rounded-xl border border-danger bg-card px-4 py-3 text-[13px] text-danger">
          {notice}
        </p>
      )}
      {active && (
        <CallRoom
          key={active.sessionId}
          call={active}
          onHangUp={() => void hangUp()}
          ficheOpen={fiche === active.sessionId}
          onToggleFiche={() => setFiche((cur) => (cur === active.sessionId ? null : active.sessionId))}
        />
      )}
      {active && active.business && fiche === active.sessionId && (
        <CallFichePanel key={`fiche-${active.sessionId}`} sessionId={active.sessionId} onClose={() => setFiche(null)} />
      )}
    </CallErrorBoundary>
  );
}
