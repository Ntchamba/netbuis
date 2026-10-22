import { useEffect, useRef, useState } from "react";
import { Button, Spinner } from "../../../components/ui";
import { buildOptions, loadJitsiApi, type JitsiApi } from "../jitsi";
import type { ActiveCall } from "../types";

interface Props {
  call: ActiveCall;
  onHangUp: () => void;
}

type RoomState = "loading" | "ready" | "error";

/** Salle Jitsi intégrée (audio, vidéo coupée). Le domaine, la salle et le jeton viennent de l'API. */
export function CallRoom({ call, onHangUp }: Props) {
  const container = useRef<HTMLDivElement>(null);
  const apiRef = useRef<JitsiApi | null>(null);
  const hangUpRef = useRef(onHangUp);
  hangUpRef.current = onHangUp;
  const [state, setState] = useState<RoomState>("loading");
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let cancelled = false;
    setState("loading");
    loadJitsiApi(call.jitsi.domain)
      .then((Jitsi) => {
        const parent = container.current;
        if (cancelled || !parent) return;
        const api = new Jitsi(call.jitsi.domain, buildOptions(call.jitsi, parent));
        apiRef.current = api;
        api.addListener("readyToClose", () => hangUpRef.current());
        api.addListener("videoConferenceLeft", () => hangUpRef.current());
        setState("ready");
      })
      .catch(() => {
        if (!cancelled) setState("error");
      });
    return () => {
      cancelled = true;
      try {
        apiRef.current?.dispose();
      } catch {
        // La salle est déjà fermée.
      }
      apiRef.current = null;
    };
  }, [call.jitsi, attempt]);

  const subject = call.business ? ` · ${call.business.name}` : "";
  return (
    <section
      aria-label="Appel en cours"
      data-testid="call-room"
      className="fixed bottom-4 right-4 z-50 flex h-[min(520px,calc(100vh-2rem))] w-[min(420px,calc(100vw-2rem))] flex-col overflow-hidden rounded-2xl border border-line bg-card text-ink shadow-2xl"
    >
      <header className="flex items-center justify-between gap-3 border-b border-line px-4 py-3">
        <div className="min-w-0">
          <p className="truncate text-[13.5px] font-extrabold">{call.callerName}</p>
          <p className="truncate text-[12px] text-ink-2">Appel en cours{subject}</p>
        </div>
        <Button variant="danger" className="min-h-11 shrink-0" onClick={onHangUp}>
          Raccrocher
        </Button>
      </header>
      <div className="relative min-h-0 flex-1 bg-bg">
        <div ref={container} data-testid="jitsi-container" className="h-full w-full" />
        {state === "loading" && (
          <div role="status" className="absolute inset-0 flex items-center justify-center gap-2 text-[13px] text-ink-2">
            <Spinner size={18} /> Connexion à la salle…
          </div>
        )}
        {state === "error" && (
          <div role="alert" className="absolute inset-0 flex flex-col items-center justify-center gap-3 p-6 text-center">
            <p className="text-[13px] text-danger">Impossible d'ouvrir la salle d'appel.</p>
            <Button variant="secondary" className="min-h-11" onClick={() => setAttempt((n) => n + 1)}>
              Réessayer
            </Button>
          </div>
        )}
      </div>
    </section>
  );
}
