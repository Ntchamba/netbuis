// Client HTTP unique. Jeton d'accès en mémoire ; refresh par cookie HttpOnly (D-01).
import axios, { type AxiosError, type InternalAxiosRequestConfig } from "axios";
import { clearAccessToken, getAccessToken, getSessionGeneration, setAccessToken } from "../auth/tokenStorage";
import { AUTH_PATHS, ENDPOINTS } from "./endpoints";

const baseURL = import.meta.env.VITE_API_BASE_URL ?? "";

export const api = axios.create({ baseURL, withCredentials: true });

// Client nu (sans intercepteurs) pour le rafraîchissement : évite toute boucle.
const bare = axios.create({ baseURL, withCredentials: true });

/** Le rafraîchissement a été invalidé par un changement de session (déconnexion, connexion). */
export class StaleSessionError extends Error {
  constructor() {
    super("Session changée pendant le rafraîchissement");
  }
}

let refreshing: Promise<string> | null = null;
let onSessionExpired: (() => void) | null = null;

/** Appelé quand le rafraîchissement échoue : l'application revient à la connexion. */
export function setSessionExpiredHandler(handler: (() => void) | null): void {
  onSessionExpired = handler;
}

/** Un seul rafraîchissement en vol : les appelants simultanés partagent la même promesse. */
export function refreshAccessToken(): Promise<string> {
  if (!refreshing) {
    const generation = getSessionGeneration();
    refreshing = bare
      .post<{ access: string }>(ENDPOINTS.refresh, {})
      .then((res) => {
        // Déconnexion ou nouvelle connexion survenue pendant le vol : on jette le résultat.
        if (generation !== getSessionGeneration()) throw new StaleSessionError();
        setAccessToken(res.data.access);
        return res.data.access;
      })
      .finally(() => {
        refreshing = null;
      });
  }
  return refreshing;
}

type Retriable = InternalAxiosRequestConfig & { _retried?: boolean; _gen?: number };

api.interceptors.request.use((config) => {
  // Génération de la session au moment de l'envoi (conservée lors d'une reprise).
  const c = config as Retriable;
  if (c._gen === undefined) c._gen = getSessionGeneration();
  const token = getAccessToken();
  if (token) config.headers.set("Authorization", `Bearer ${token}`);
  return config;
});

api.interceptors.response.use(
  (res) => res,
  async (error: AxiosError) => {
    const config = error.config as Retriable | undefined;
    const isAuthCall = AUTH_PATHS.some((p) => config?.url?.includes(p));
    if (error.response?.status !== 401 || !config || config._retried || isAuthCall) {
      throw error;
    }
    // Requête d'une session déjà terminée (déconnexion, nouvelle connexion) : on ne touche à rien.
    const gen = config._gen ?? getSessionGeneration();
    if (gen !== getSessionGeneration()) throw error;
    config._retried = true; // une seule nouvelle tentative
    try {
      await refreshAccessToken();
    } catch (refreshError) {
      // Tout échec d'un refresh de l'ancienne session est ignoré : il ne doit pas effacer la nouvelle.
      if (refreshError instanceof StaleSessionError || gen !== getSessionGeneration()) throw error;
      clearAccessToken();
      onSessionExpired?.();
      throw error;
    }
    return api(config);
  },
);
