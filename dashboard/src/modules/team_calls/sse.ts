// Lecture d'un flux SSE avec fetch : EventSource ne permet pas d'en-tête Authorization.
// Le jeton d'accès (mémoire) est envoyé à chaque connexion ; après un 401, il est renouvelé.
import { refreshAccessToken } from "../../api/client";
import { getAccessToken } from "../../auth/tokenStorage";
import type { StreamStatus } from "./types";

export interface SseMessage {
  event: string;
  data: string;
}

/** Découpe un flux de texte en messages SSE (lignes `event:` / `data:`, commentaires ignorés). */
export class SseParser {
  private buffer = "";
  private event = "";
  private data: string[] = [];
  /** Dernier délai `retry:` demandé par le serveur (ms). */
  retryMs: number | null = null;

  feed(chunk: string): SseMessage[] {
    this.buffer += chunk;
    const out: SseMessage[] = [];
    for (;;) {
      const match = /\r\n|\n|\r(?!$)/.exec(this.buffer);
      if (!match) break;
      const line = this.buffer.slice(0, match.index);
      this.buffer = this.buffer.slice(match.index + match[0].length);
      if (line === "") {
        if (this.data.length > 0) out.push({ event: this.event || "message", data: this.data.join("\n") });
        this.event = "";
        this.data = [];
      } else if (line.startsWith(":")) {
        continue;
      } else {
        const colon = line.indexOf(":");
        const field = colon === -1 ? line : line.slice(0, colon);
        let value = colon === -1 ? "" : line.slice(colon + 1);
        if (value.startsWith(" ")) value = value.slice(1);
        if (field === "event") this.event = value;
        else if (field === "data") this.data.push(value);
        else if (field === "retry" && /^\d+$/.test(value)) this.retryMs = Number(value);
      }
    }
    return out;
  }
}

export interface StreamOptions {
  url: string;
  onMessage: (message: SseMessage) => void;
  onStatus: (status: StreamStatus) => void;
  /** Appelé quand le flux (re)devient ouvert, avant les messages rejoués. */
  onOpen?: () => void;
  /** Le serveur a fermé volontairement (événement `closed`) : plus de reconnexion. */
  isFinal?: (message: SseMessage) => boolean;
  /** Silence maximal toléré (le serveur envoie un commentaire toutes les 5 s). */
  idleMs?: number;
  minDelayMs?: number;
  maxDelayMs?: number;
}

const DEFAULTS = { idleMs: 20_000, minDelayMs: 1_000, maxDelayMs: 15_000 };

/** Ouvre le flux et le rouvre tout seul ; renvoie la fonction qui l'arrête. */
export function openAuthorizedStream(options: StreamOptions): () => void {
  const idleMs = options.idleMs ?? DEFAULTS.idleMs;
  const minDelay = options.minDelayMs ?? DEFAULTS.minDelayMs;
  const maxDelay = options.maxDelayMs ?? DEFAULTS.maxDelayMs;
  const base = import.meta.env.VITE_API_BASE_URL ?? "";
  let stopped = false;
  let controller: AbortController | null = null;

  const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

  async function connect(token: string | null, signal: AbortSignal): Promise<Response> {
    const headers: Record<string, string> = { Accept: "text/event-stream" };
    if (token) headers.Authorization = `Bearer ${token}`;
    return fetch(`${base}${options.url}`, { headers, credentials: "include", cache: "no-store", signal });
  }

  async function loop(): Promise<void> {
    let delay = minDelay;
    let first = true;
    while (!stopped) {
      options.onStatus(first ? "connecting" : "reconnecting");
      first = false;
      const local = new AbortController();
      controller = local;
      let idleTimer: ReturnType<typeof setTimeout> | undefined;
      const armIdle = () => {
        clearTimeout(idleTimer);
        idleTimer = setTimeout(() => local.abort(), idleMs);
      };
      let final = false;
      try {
        armIdle();
        let response = await connect(getAccessToken(), local.signal);
        if (response.status === 401) {
          // Jeton expiré : on en obtient un nouveau puis on se reconnecte tout de suite.
          await refreshAccessToken();
          response = await connect(getAccessToken(), local.signal);
        }
        if (response.status === 403) {
          options.onStatus("forbidden");
          return;
        }
        if (!response.ok || !response.body) throw new Error(`HTTP ${response.status}`);
        options.onStatus("open");
        options.onOpen?.();
        delay = minDelay;
        const parser = new SseParser();
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;
          armIdle();
          for (const message of parser.feed(decoder.decode(value, { stream: true }))) {
            options.onMessage(message);
            if (options.isFinal?.(message)) final = true;
          }
          if (parser.retryMs !== null) delay = Math.max(minDelay, Math.min(parser.retryMs, maxDelay));
        }
      } catch {
        // Réseau coupé, silence trop long ou arrêt demandé : on retombe sur la reconnexion.
      } finally {
        clearTimeout(idleTimer);
        local.abort();
      }
      if (stopped || final) {
        if (final) options.onStatus("off");
        return;
      }
      options.onStatus("reconnecting");
      await sleep(delay);
      delay = Math.min(delay * 2, maxDelay);
    }
  }

  void loop();
  return () => {
    stopped = true;
    controller?.abort();
    options.onStatus("off");
  };
}
