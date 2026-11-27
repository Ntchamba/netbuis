// Intégration de Jitsi : `external_api.js` est chargé depuis le domaine donné PAR L'API
// (jamais écrit en dur). Aucun nom de salle ni jeton n'est écrit dans la console ni dans le stockage.
import type { JitsiAccess } from "./types";

export interface JitsiApi {
  addListener: (event: string, listener: (...args: unknown[]) => void) => void;
  executeCommand: (command: string, ...args: unknown[]) => void;
  dispose: () => void;
}

export interface JitsiOptions {
  roomName: string;
  jwt: string;
  parentNode: HTMLElement;
  width: string;
  height: string;
  configOverwrite: Record<string, unknown>;
  interfaceConfigOverwrite: Record<string, unknown>;
}

export type JitsiConstructor = new (domain: string, options: JitsiOptions) => JitsiApi;

declare global {
  interface Window {
    JitsiMeetExternalAPI?: JitsiConstructor;
  }
}

// Nom de domaine (avec port éventuel) : on refuse tout ce qui ressemble à une adresse complète.
const DOMAIN_PATTERN = /^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*(:\d{1,5})?$/i;

const IPV4_PATTERN = /^\d{1,3}(\.\d{1,3}){3}(:\d{1,5})?$/;

/**
 * Nom d'hôte seulement, jamais une adresse complète ni une adresse IP. Un nom sans point
 * (« intranet ») n'est accepté que pour « localhost » en développement.
 */
export function isValidJitsiDomain(domain: string): boolean {
  if (!DOMAIN_PATTERN.test(domain) || IPV4_PATTERN.test(domain)) return false;
  const host = domain.replace(/:\d+$/, "");
  if (host.includes(".")) return true;
  return host.toLowerCase() === "localhost" && import.meta.env.DEV;
}

const loading = new Map<string, Promise<JitsiConstructor>>();

/** Charge `https://<domaine>/external_api.js` une seule fois par domaine. */
export function loadJitsiApi(domain: string): Promise<JitsiConstructor> {
  if (!isValidJitsiDomain(domain)) return Promise.reject(new Error("Domaine Jitsi invalide"));
  const known = loading.get(domain);
  if (known) return known;
  const promise = new Promise<JitsiConstructor>((resolve, reject) => {
    const script = document.createElement("script");
    script.src = `https://${domain}/external_api.js`;
    script.async = true;
    script.onload = () => {
      if (window.JitsiMeetExternalAPI) resolve(window.JitsiMeetExternalAPI);
      else reject(new Error("API Jitsi absente"));
    };
    script.onerror = () => {
      script.remove();
      reject(new Error("Chargement de l'API Jitsi impossible"));
    };
    document.head.appendChild(script);
  });
  // Un échec n'est pas gardé : « Réessayer » recharge le script.
  promise.catch(() => loading.delete(domain));
  loading.set(domain, promise);
  return promise;
}

/** Réglages : audio d'abord, vidéo coupée, pas d'écran de pré-connexion, pas d'invitation à installer l'app. */
export function buildOptions(access: JitsiAccess, parentNode: HTMLElement): JitsiOptions {
  return {
    roomName: access.room,
    jwt: access.jwt,
    parentNode,
    width: "100%",
    height: "100%",
    configOverwrite: {
      startWithVideoMuted: true,
      startWithAudioMuted: false,
      startAudioOnly: true,
      prejoinConfig: { enabled: false },
      prejoinPageEnabled: false,
      disableDeepLinking: true,
    },
    interfaceConfigOverwrite: { MOBILE_APP_PROMO: false },
  };
}
