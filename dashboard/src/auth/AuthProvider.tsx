import { useQueryClient } from "@tanstack/react-query";
import { isAxiosError } from "axios";
import { createContext, useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { refreshAccessToken, setSessionExpiredHandler } from "../api/client";
import { fetchMe, loginRequest, logoutRequest } from "../modules/auth/api";
import type { AdminMe } from "../modules/auth/types";
import { bumpSessionGeneration, clearAccessToken, getSessionGeneration } from "./tokenStorage";

/**
 * loading : restauration de la session en cours · anonymous : non connecté ·
 * authenticated : connecté, rôle connu · forbidden : connecté mais sans droit (403 sur /admin/me/) ·
 * error : /admin/me/ en échec (500, réseau) alors que la session est valide.
 */
export type AuthStatus = "loading" | "anonymous" | "authenticated" | "forbidden" | "error";

export interface AuthValue {
  status: AuthStatus;
  me: AdminMe | null;
  login: (phone: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  retry: () => Promise<void>;
}

export const AuthContext = createContext<AuthValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();
  const [status, setStatus] = useState<AuthStatus>("loading");
  const [me, setMe] = useState<AdminMe | null>(null);
  const started = useRef(false);

  const loadMe = useCallback(async () => {
    const gen = getSessionGeneration();
    try {
      const data = await fetchMe();
      if (gen !== getSessionGeneration()) return; // déconnecté entre-temps
      setMe(data);
      setStatus("authenticated");
    } catch (err) {
      if (gen !== getSessionGeneration()) return;
      if (isAxiosError(err) && err.response?.status === 403) {
        clearAccessToken();
        setMe(null);
        setStatus("forbidden");
        return;
      }
      throw err;
    }
  }, []);

  const reset = useCallback(() => {
    bumpSessionGeneration();
    clearAccessToken();
    queryClient.clear();
    setMe(null);
    setStatus("anonymous");
  }, [queryClient]);

  // 401 définitif (refresh échoué) → retour à la connexion.
  useEffect(() => {
    setSessionExpiredHandler(reset);
    return () => setSessionExpiredHandler(null);
  }, [reset]);

  // Au chargement : restaurer la session grâce au cookie HttpOnly.
  useEffect(() => {
    if (started.current) return;
    started.current = true;
    (async () => {
      const gen = getSessionGeneration();
      try {
        await refreshAccessToken();
      } catch {
        if (gen === getSessionGeneration()) reset();
        return;
      }
      if (gen !== getSessionGeneration()) return;
      try {
        await loadMe();
      } catch {
        if (gen === getSessionGeneration()) setStatus("error");
      }
    })();
  }, [loadMe, reset]);

  const login = useCallback(
    async (phone: string, password: string) => {
      bumpSessionGeneration(); // invalide tout rafraîchissement encore en vol
      try {
        await loginRequest(phone, password);
      } catch (err) {
        // Le refresh de démarrage éventuel est ignoré : on ne reste pas bloqué en « loading ».
        setStatus((cur) => (cur === "loading" ? "anonymous" : cur));
        throw err;
      }
      try {
        await loadMe();
      } catch (err) {
        reset();
        throw err;
      }
    },
    [loadMe, reset],
  );

  const retry = useCallback(async () => {
    const gen = getSessionGeneration();
    setStatus("loading");
    try {
      await loadMe();
    } catch {
      if (gen === getSessionGeneration()) setStatus("error");
    }
  }, [loadMe]);

  const logout = useCallback(async () => {
    bumpSessionGeneration();
    try {
      await logoutRequest();
    } catch {
      // Même si le serveur est injoignable, la session locale est effacée.
    }
    reset();
  }, [reset]);

  const value = useMemo(() => ({ status, me, login, logout, retry }), [status, me, login, logout, retry]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
