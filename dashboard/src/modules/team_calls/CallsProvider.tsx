import { useQueryClient } from "@tanstack/react-query";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { usePermissions } from "../../auth/permissions";
import { acceptCall, callErrorCode, CALLS_STREAM_URL, declineCall, endCall, sendPresence } from "./api";
import { startRinging, stopRinging, unlockAudio } from "./ringtone";
import { openAuthorizedStream, type SseMessage } from "./sse";
import { ANSWER_PERMISSION, type ActiveCall, type IncomingCall, type RingingEvent, type StreamStatus } from "./types";

export const TEAM_CALLS_KEY = ["admin", "team-calls"] as const;
export const HEARTBEAT_MS = 10_000;
const NOTICE_MS = 5_000;
const ENDING_EVENTS = new Set(["taken", "ended", "missed", "declined", "cancelled"]);

export interface CallsValue {
  /** Le serveur a donné le droit « répondre aux appels » à cet administrateur. */
  enabled: boolean;
  status: StreamStatus;
  available: boolean;
  /** Changement de présence en cours. */
  presenceBusy: boolean;
  /** Message court (erreur) à annoncer, effacé tout seul. */
  notice: string | null;
  incoming: IncomingCall[];
  active: ActiveCall | null;
  answering: boolean;
  setAvailable: (value: boolean) => Promise<void>;
  accept: (sessionId: string) => Promise<void>;
  decline: (sessionId: string) => Promise<void>;
  hangUp: () => Promise<void>;
}

const DISABLED: CallsValue = {
  enabled: false,
  status: "off",
  available: false,
  presenceBusy: false,
  notice: null,
  incoming: [],
  active: null,
  answering: false,
  setAvailable: async () => {},
  accept: async () => {},
  decline: async () => {},
  hangUp: async () => {},
};

const CallsContext = createContext<CallsValue>(DISABLED);

export function useCalls(): CallsValue {
  return useContext(CallsContext);
}

function parse<T>(message: SseMessage): T | null {
  try {
    return JSON.parse(message.data) as T;
  } catch {
    return null;
  }
}

function toIncoming(event: RingingEvent, receivedAt: number): IncomingCall {
  let deadline: number | null = null;
  if (typeof event.ring_seconds_left === "number") deadline = receivedAt + event.ring_seconds_left * 1000;
  else if (event.expires_at) {
    const parsed = Date.parse(event.expires_at);
    if (!Number.isNaN(parsed)) deadline = parsed;
  }
  return { sessionId: event.session_id, callerName: event.caller_name, business: event.business, deadline };
}

/** Flux temps réel des appels, présence, sonnerie et appel en cours. Actif seulement avec le droit du serveur. */
export function CallsProvider({ children }: { children: ReactNode }) {
  const { can } = usePermissions();
  const enabled = can(ANSWER_PERMISSION);
  const queryClient = useQueryClient();
  const [status, setStatus] = useState<StreamStatus>("off");
  const [available, setAvailableState] = useState(false);
  const [presenceBusy, setPresenceBusy] = useState(false);
  const [incoming, setIncoming] = useState<IncomingCall[]>([]);
  const [active, setActive] = useState<ActiveCall | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [answering, setAnswering] = useState(false);
  const activeRef = useRef<ActiveCall | null>(null);
  activeRef.current = active;

  const removeIncoming = useCallback((id: string) => setIncoming((cur) => cur.filter((c) => c.sessionId !== id)), []);

  useEffect(() => {
    if (!enabled) return;
    const stop = openAuthorizedStream({
      url: CALLS_STREAM_URL,
      onStatus: setStatus,
      // Après une coupure, le serveur rejoue les sonneries en cours : on repart d'une liste vide.
      onOpen: () => setIncoming([]),
      isFinal: (m) => m.event === "closed",
      onMessage: (message) => {
        if (message.event === "presence") {
          const data = parse<{ available: boolean }>(message);
          if (data) setAvailableState(data.available === true);
        } else if (message.event === "ringing") {
          const data = parse<RingingEvent>(message);
          if (!data || typeof data.session_id !== "string") return;
          const item = toIncoming(data, Date.now());
          setIncoming((cur) => (cur.some((c) => c.sessionId === item.sessionId) ? cur : [...cur, item]));
          void queryClient.invalidateQueries({ queryKey: TEAM_CALLS_KEY });
        } else if (ENDING_EVENTS.has(message.event)) {
          const data = parse<{ session_id: string }>(message);
          if (!data) return;
          setIncoming((cur) => cur.filter((c) => c.sessionId !== data.session_id));
          // L'appelant a raccroché pendant la communication : la salle se ferme.
          if (message.event === "ended" && activeRef.current?.sessionId === data.session_id) setActive(null);
          void queryClient.invalidateQueries({ queryKey: TEAM_CALLS_KEY });
        }
      },
    });
    return () => {
      stop();
      setIncoming([]);
    };
  }, [enabled, queryClient]);

  // Battement de cœur : le serveur ne sonne que les agents actifs depuis moins de 25 s.
  useEffect(() => {
    if (!enabled || status !== "open") return;
    const id = setInterval(() => {
      sendPresence()
        .then(setAvailableState)
        .catch(() => {
          /* le flux se chargera de la reconnexion */
        });
    }, HEARTBEAT_MS);
    return () => clearInterval(id);
  }, [enabled, status]);

  // Fin de sonnerie locale (le serveur enverra aussi `missed`).
  useEffect(() => {
    if (incoming.length === 0) return;
    const id = setInterval(() => {
      const now = Date.now();
      setIncoming((cur) => (cur.some((c) => c.deadline !== null && c.deadline <= now) ? cur.filter((c) => c.deadline === null || c.deadline > now) : cur));
    }, 500);
    return () => clearInterval(id);
  }, [incoming.length]);

  useEffect(() => {
    if (!notice) return;
    const id = setTimeout(() => setNotice(null), NOTICE_MS);
    return () => clearTimeout(id);
  }, [notice]);

  // Son : tant qu'un appel sonne et qu'aucune communication n'est en cours.
  const ringing = incoming.length > 0 && active === null;
  useEffect(() => {
    if (ringing) startRinging();
    else stopRinging();
    return stopRinging;
  }, [ringing]);

  const setAvailable = useCallback(
    async (value: boolean) => {
      unlockAudio(); // le clic autorise le navigateur à jouer la sonnerie
      setPresenceBusy(true);
      try {
        setAvailableState(await sendPresence(value));
      } catch {
        setNotice("Impossible de changer votre disponibilité.");
      } finally {
        setPresenceBusy(false);
      }
    },
    [],
  );

  const accept = useCallback(
    async (sessionId: string) => {
      const item = incoming.find((c) => c.sessionId === sessionId);
      setAnswering(true);
      try {
        const res = await acceptCall(sessionId);
        removeIncoming(sessionId);
        setActive({ sessionId: res.session_id, callerName: res.caller_name, business: res.business, jitsi: res.jitsi });
      } catch (error) {
        const code = callErrorCode(error);
        if (code === "call_taken") setNotice("Un collègue a déjà répondu à cet appel.");
        else if (code === "call_not_ringing") setNotice("Cet appel n'est plus en attente.");
        else if (code === "jitsi_not_configured") setNotice("Les appels en ligne ne sont pas configurés sur le serveur.");
        else setNotice(`Impossible de répondre${item ? ` à ${item.callerName}` : ""}.`);
        if (code === "call_taken" || code === "call_not_ringing") removeIncoming(sessionId);
      } finally {
        setAnswering(false);
      }
    },
    [incoming, removeIncoming],
  );

  const decline = useCallback(
    async (sessionId: string) => {
      removeIncoming(sessionId);
      try {
        await declineCall(sessionId);
      } catch {
        // Déjà pris ou expiré : la fenêtre est fermée de toute façon.
      }
    },
    [removeIncoming],
  );

  const hangUp = useCallback(async () => {
    const current = activeRef.current;
    if (!current) return;
    setActive(null);
    try {
      await endCall(current.sessionId);
    } catch {
      // Déjà terminé du côté serveur : rien à faire.
    }
    void queryClient.invalidateQueries({ queryKey: TEAM_CALLS_KEY });
  }, [queryClient]);

  const value = useMemo<CallsValue>(
    () => ({ enabled, status, available, presenceBusy, notice, incoming, active, answering, setAvailable, accept, decline, hangUp }),
    [enabled, status, available, presenceBusy, notice, incoming, active, answering, setAvailable, accept, decline, hangUp],
  );
  return <CallsContext.Provider value={value}>{children}</CallsContext.Provider>;
}
