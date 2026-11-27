// Outillage commun des parcours : le faux transport d'axios DOIT être chargé avant le code de l'application.
import "../auth/fakeServer";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act } from "react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, vi } from "vitest";
import { AuthProvider } from "../../src/auth/AuthProvider";
import { clearAccessToken } from "../../src/auth/tokenStorage";
import { ThemeProvider } from "../../src/components/theme/ThemeProvider";
import { ToastProvider } from "../../src/components/ui/Toast";
import { AppRoutes } from "../../src/routes";
import { resetServer, setHandler } from "../auth/fakeServer";
import { byText, cleanup, click, render, type } from "../components/helpers";
import { World as WorldClass, type World } from "./world";

export { byText, click, type };
export { calls } from "../auth/fakeServer";

export const wait = async (n = 4, ms = 15) => {
  for (let i = 0; i < n; i++) await act(async () => new Promise((r) => setTimeout(r, ms)));
};

export interface App {
  div: HTMLElement;
  qc: QueryClient;
  main: () => HTMLElement;
  /** Clique une entrée de la barre latérale par son libellé. */
  goTo: (label: string) => Promise<void>;
}

/** Monte l'application complète (routes, session, thème, notifications) sur une adresse. */
export async function mountApp(path: string): Promise<App> {
  const qc = new QueryClient();
  const div = await render(
    <QueryClientProvider client={qc}>
      <ThemeProvider>
        <ToastProvider>
          <MemoryRouter initialEntries={[path]}>
            <AuthProvider>
              <AppRoutes />
            </AuthProvider>
          </MemoryRouter>
        </ToastProvider>
      </ThemeProvider>
    </QueryClientProvider>,
  );
  await wait();
  return {
    div,
    qc,
    main: () => div.querySelector("main") as HTMLElement,
    goTo: async (label) => {
      const link = Array.from(div.querySelectorAll("aside nav a")).find((a) => a.textContent?.trim().startsWith(label));
      if (!link) throw new Error(`entrée de menu introuvable : ${label}`);
      await click(link);
      await wait();
    },
  };
}

/** Crée le faux serveur à état et le branche sur le transport d'axios. */
export function startWorld(permissions: string[], cookie = true): World {
  const w = new WorldClass(permissions, cookie);
  setHandler(w.handle);
  return w;
}

export function installCommonHooks() {
  beforeEach(() => {
    resetServer();
    clearAccessToken();
    localStorage.clear();
    sessionStorage.clear();
    let n = 0;
    URL.createObjectURL = () => `blob:test/${++n}`;
    URL.revokeObjectURL = () => {};
  });
  afterEach(async () => {
    await cleanup();
    vi.restoreAllMocks();
  });
}

export const dialog = () => document.querySelector("[role=dialog]") as HTMLElement | null;
export const dialogButton = (label: string) => byText(dialog()!, "button", label) as HTMLButtonElement;
export const textarea = () => document.querySelector("[role=dialog] textarea") as HTMLTextAreaElement;
export const toastText = () => document.body.textContent ?? "";
export const storageDump = () => JSON.stringify({ ...localStorage }) + JSON.stringify({ ...sessionStorage }) + document.cookie;
