import "./fakeServer";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act } from "react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { api } from "../../src/api/client";
import { AuthProvider } from "../../src/auth/AuthProvider";
import { Can, usePermissions } from "../../src/auth/permissions";
import { clearAccessToken, getAccessToken } from "../../src/auth/tokenStorage";
import { useAuth } from "../../src/auth/useAuth";
import { ToastProvider } from "../../src/components/ui/Toast";
import { AuthLayout } from "../../src/layouts/AuthLayout";
import { LoginPage } from "../../src/modules/auth";
import { ProtectedRoute } from "../../src/routes/ProtectedRoute";
import { byText, cleanup, click, render, type as typeInto } from "../components/helpers";
import { calls, count, gates, resetServer, setHandler, type Call, type Reply } from "./fakeServer";

const ME = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["Validateur"], permissions: ["peut_valider"] };
const TOKEN_A = "jeton-fictif-A";
const TOKEN_B = "jeton-fictif-B";
const PASSWORD = "mdp-fictif-123";

function StatusProbe() {
  return <p data-testid="status">{useAuth().status}</p>;
}

function Probe() {
  const { me, logout } = useAuth();
  const { can } = usePermissions();
  return (
    <div>
      <p data-testid="probe">Bonjour {me?.name}</p>
      <Can permission="peut_valider">
        <button>Valider</button>
      </Can>
      <Can permission="peut_gerer_admins">
        <button>Gérer les admins</button>
      </Can>
      <p data-testid="can">{String(can("peut_gerer_admins"))}</p>
      <button onClick={() => void logout()}>Quitter</button>
    </div>
  );
}

let qc: QueryClient;
async function mount(path = "/") {
  qc = new QueryClient();
  return render(
    <QueryClientProvider client={qc}>
      <ToastProvider>
        <MemoryRouter initialEntries={[path]}>
          <AuthProvider>
            <StatusProbe />
            <Routes>
              <Route element={<AuthLayout />}>
                <Route path="/connexion" element={<LoginPage />} />
              </Route>
              <Route element={<ProtectedRoute />}>
                <Route path="/" element={<Probe />} />
              </Route>
            </Routes>
          </AuthProvider>
        </MemoryRouter>
      </ToastProvider>
    </QueryClientProvider>,
  );
}

/** Serveur nominal : cookie valide (refresh OK), login OK, me OK. */
function server(over: Partial<Record<string, (c: Call) => Reply>> = {}) {
  setHandler((c) => {
    const f = over[c.url];
    if (f) return f(c);
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: TOKEN_A } };
    if (c.url === "/api/auth/admin/login/") return { status: 200, data: { access: TOKEN_A } };
    if (c.url === "/api/admin/me/") return { status: 200, data: ME };
    if (c.url === "/api/auth/logout/") return { status: 204 };
    return { status: 404 };
  });
}
const noCookie = { "/api/auth/refresh/": () => ({ status: 401, data: { code: "token_invalid", message: "x" } }) };

async function fillAndSubmit(div: HTMLElement, phone: string, password: string) {
  await typeInto(div.querySelector('input[type="tel"]')!, phone);
  await typeInto(div.querySelector('input[type="password"]')!, password);
  await click(div.querySelector('button[type="submit"]'));
}

const fakeAdapter = api.defaults.adapter;

beforeEach(() => {
  api.defaults.adapter = fakeAdapter;
  resetServer();
  clearAccessToken();
  localStorage.clear();
  sessionStorage.clear();
});
afterEach(cleanup);

describe("session et routes protégées", () => {
  test("route protégée sans session : redirige vers la connexion", async () => {
    server(noCookie);
    const div = await mount("/");
    expect(div.querySelector("h1")?.textContent).toBe("Connexion");
    expect(calls.some((c) => c.url === "/api/admin/me/")).toBe(false);
  });

  test("refresh au démarrage (cookie envoyé) restaure la session et lit /admin/me/", async () => {
    server();
    const div = await mount("/");
    expect(div.querySelector('[data-testid="probe"]')?.textContent).toBe("Bonjour Awa Test");
    const refresh = calls.find((c) => c.url === "/api/auth/refresh/")!;
    expect(refresh.withCredentials).toBe(true);
    expect(calls.find((c) => c.url === "/api/admin/me/")!.auth).toBe(`Bearer ${TOKEN_A}`);
  });

  test("refresh au démarrage qui échoue : retour à la connexion", async () => {
    server(noCookie);
    const div = await mount("/");
    expect(div.querySelector("h1")?.textContent).toBe("Connexion");
    expect(getAccessToken()).toBeNull();
  });

  test("403 sur /admin/me/ : écran « Accès non autorisé » puis déconnexion", async () => {
    server({ "/api/admin/me/": () => ({ status: 403, data: { code: "forbidden", message: "x" } }) });
    const div = await mount("/");
    expect(div.querySelector("h1")?.textContent).toBe("Accès non autorisé");
    expect(getAccessToken()).toBeNull();
    await click(byText(div, "button", "Se déconnecter"));
    expect(count("/api/auth/logout/")).toBe(1);
    expect(div.querySelector("h1")?.textContent).toBe("Connexion");
  });
});

describe("connexion", () => {
  test("réussie : numéro normalisé, jeton en mémoire seulement", async () => {
    server(noCookie);
    const div = await mount("/connexion");
    await fillAndSubmit(div, "+237 677 12 34 56", PASSWORD);
    const login = calls.find((c) => c.url === "/api/auth/admin/login/")!;
    expect(login.body).toEqual({ phone: "+237677123456", password: PASSWORD });
    expect(div.querySelector('[data-testid="probe"]')?.textContent).toBe("Bonjour Awa Test");
    expect(getAccessToken()).toBe(TOKEN_A);
    // Le jeton n'est nulle part ailleurs qu'en mémoire.
    const where = JSON.stringify({ ...localStorage }) + JSON.stringify({ ...sessionStorage }) + document.cookie + location.href;
    expect(where).not.toContain(TOKEN_A);
    expect(where).not.toContain(PASSWORD);
    expect(localStorage.length + sessionStorage.length).toBe(0);
    expect(document.cookie).toBe("");
  });

  test("échec : message identique, mot de passe vidé", async () => {
    const bad = () => ({ status: 401, data: { code: "invalid_credentials", message: "Numéro ou mot de passe incorrect." } });
    server({ ...noCookie, "/api/auth/admin/login/": bad });
    const div = await mount("/connexion");
    await fillAndSubmit(div, "677123456", PASSWORD);
    const first = div.querySelector('[role="alert"]')?.textContent;
    expect(first).toBe("Numéro ou mot de passe incorrect.");
    expect((div.querySelector('input[type="password"]') as HTMLInputElement).value).toBe("");
    await fillAndSubmit(div, "699000000", "autre-mdp");
    expect(div.querySelector('[role="alert"]')?.textContent).toBe(first);
    expect(getAccessToken()).toBeNull();
  });

  test("429 : affiche le délai Retry-After", async () => {
    server({
      ...noCookie,
      "/api/auth/admin/login/": () => ({ status: 429, headers: { "retry-after": "600" }, data: { code: "too_many_requests", message: "x" } }),
    });
    const div = await mount("/connexion");
    await fillAndSubmit(div, "677123456", PASSWORD);
    expect(div.querySelector('[role="alert"]')?.textContent).toBe("Trop d'essais. Réessayez dans 10 minutes.");
  });

  test("erreur réseau : message dédié", async () => {
    server({ ...noCookie, "/api/auth/admin/login/": () => ({ status: 0, network: true }) });
    const div = await mount("/connexion");
    await fillAndSubmit(div, "677123456", PASSWORD);
    expect(div.querySelector('[role="alert"]')?.textContent).toBe("Connexion impossible. Vérifiez votre réseau et réessayez.");
  });

  test("numéro au mauvais format : aucune requête de connexion", async () => {
    server(noCookie);
    const div = await mount("/connexion");
    await fillAndSubmit(div, "12345", PASSWORD);
    expect(div.textContent).toContain("Numéro invalide. Format : +237 6XXXXXXXX.");
    expect(count("/api/auth/admin/login/")).toBe(0);
  });

  test("anti double soumission : bouton désactivé pendant l'envoi, une seule requête", async () => {
    let release: () => void = () => {};
    const gate = new Promise<void>((r) => (release = r));
    server(noCookie);
    setHandlerSlow(gate);
    const div = await mount("/connexion");
    await typeInto(div.querySelector('input[type="tel"]')!, "677123456");
    await typeInto(div.querySelector('input[type="password"]')!, PASSWORD);
    const btn = div.querySelector('button[type="submit"]') as HTMLButtonElement;
    await click(btn);
    await click(btn);
    expect(btn.disabled).toBe(true);
    await act(async () => {
      release();
      await gate;
    });
    expect(count("/api/auth/admin/login/")).toBe(1);
  });
});

function setHandlerSlow(gate: Promise<void>) {
  // Le faux serveur est synchrone : on retarde la réponse en laissant la requête en attente via le client.
  const original = api.defaults.adapter;
  api.defaults.adapter = async (config) => {
    if (config.url === "/api/auth/admin/login/") await gate;
    const a = original as (c: typeof config) => Promise<never>;
    return a(config);
  };
}

describe("rafraîchissement sur 401", () => {
  test("refresh puis une seule nouvelle tentative ; un seul refresh en vol", async () => {
    let pingCalls = 0;
    server({
      "/api/ping/": (c) => {
        pingCalls++;
        return c.auth === `Bearer ${TOKEN_B}` ? { status: 200, data: { ok: true } } : { status: 401, data: { code: "token_invalid", message: "x" } };
      },
      "/api/auth/refresh/": () => ({ status: 200, data: { access: TOKEN_B } }),
    });
    const [a, b] = await Promise.all([api.get("/api/ping/"), api.get("/api/ping/")]);
    expect(a.data).toEqual({ ok: true });
    expect(b.data).toEqual({ ok: true });
    expect(count("/api/auth/refresh/")).toBe(1);
    expect(pingCalls).toBe(4); // 2 échecs + 2 reprises, jamais plus
    expect(getAccessToken()).toBe(TOKEN_B);
  });

  test("si la reprise renvoie encore 401 : pas de boucle", async () => {
    server({
      "/api/ping/": () => ({ status: 401 }),
      "/api/auth/refresh/": () => ({ status: 200, data: { access: TOKEN_B } }),
    });
    await expect(api.get("/api/ping/")).rejects.toMatchObject({ response: { status: 401 } });
    expect(count("/api/ping/")).toBe(2);
    expect(count("/api/auth/refresh/")).toBe(1);
  });

  test("refresh qui échoue en session : retour à la connexion et cache vidé", async () => {
    let expired = false;
    server({
      "/api/auth/refresh/": () => (expired ? { status: 401 } : { status: 200, data: { access: TOKEN_A } }),
    });
    const div = await mount("/");
    expect(div.querySelector('[data-testid="probe"]')).not.toBeNull();
    qc.setQueryData(["x"], 1);
    expired = true;
    setHandler(() => ({ status: 401 }));
    await act(async () => {
      await api.get("/api/ping/").catch(() => undefined);
    });
    expect(div.querySelector("h1")?.textContent).toBe("Connexion");
    expect(getAccessToken()).toBeNull();
    expect(qc.getQueryData(["x"])).toBeUndefined();
  });
});

describe("course refresh / déconnexion et échecs", () => {
  test("refresh lent en vol puis déconnexion : la résolution tardive laisse jeton nul et statut anonyme", async () => {
    server({ "/api/ping/": () => ({ status: 401 }) });
    const div = await mount("/");
    expect(getAccessToken()).toBe(TOKEN_A);
    let release: () => void = () => {};
    const gate = new Promise<void>((r) => (release = r));
    gates.set("/api/auth/refresh/", gate);
    let pending: Promise<unknown> = Promise.resolve();
    await act(async () => {
      pending = api.get("/api/ping/").catch(() => undefined); // 401 -> refresh en vol
    });
    await click(byText(div, "button", "Quitter"));
    expect(div.querySelector("h1")?.textContent).toBe("Connexion");
    await act(async () => {
      release();
      await pending;
    });
    expect(getAccessToken()).toBeNull();
    expect(div.querySelector("h1")?.textContent).toBe("Connexion");
    expect(div.querySelector('[data-testid="probe"]')).toBeNull();
  });

  test.each([
    ["erreur 500", { status: 500 }],
    ["réseau coupé", { status: 0, network: true }],
  ])("déconnexion alors que POST logout échoue (%s) : état local quand même effacé", async (_n, reply) => {
    server({ "/api/auth/logout/": () => reply });
    const div = await mount("/");
    qc.setQueryData(["secret"], 1);
    await click(byText(div, "button", "Quitter"));
    expect(count("/api/auth/logout/")).toBe(1);
    expect(getAccessToken()).toBeNull();
    expect(qc.getQueryData(["secret"])).toBeUndefined();
    expect(div.querySelector("h1")?.textContent).toBe("Connexion");
  });

  test("échec de /admin/me/ (500) au démarrage : écran d'erreur, Réessayer relance le chargement", async () => {
    let fail = true;
    server({ "/api/admin/me/": () => (fail ? { status: 500 } : { status: 200, data: ME }) });
    const div = await mount("/");
    expect(div.querySelector("h1")?.textContent).toBe("Chargement impossible");
    expect(byText(div, "button", "Se déconnecter")).not.toBeNull();
    fail = false;
    await click(byText(div, "button", "Réessayer"));
    expect(div.querySelector('[data-testid="probe"]')?.textContent).toBe("Bonjour Awa Test");
  });

  test("échec de /admin/me/ (réseau) puis Se déconnecter : aucun jeton conservé", async () => {
    server({ "/api/admin/me/": () => ({ status: 0, network: true }) });
    const div = await mount("/");
    expect(div.querySelector("h1")?.textContent).toBe("Chargement impossible");
    await click(byText(div, "button", "Se déconnecter"));
    expect(getAccessToken()).toBeNull();
    expect(div.querySelector("h1")?.textContent).toBe("Connexion");
  });
});

describe("session périmée : un échec tardif n'efface pas la nouvelle session", () => {
  async function logoutThenLogin(div: HTMLElement) {
    await click(byText(div, "button", "Quitter"));
    expect(div.querySelector("h1")?.textContent).toBe("Connexion");
    await fillAndSubmit(div, "677123456", PASSWORD);
    expect(getAccessToken()).toBe(TOKEN_B);
  }
  function serverWithLateRefresh(late: Reply) {
    let refreshes = 0;
    server({
      "/api/ping/": () => ({ status: 401 }),
      "/api/auth/refresh/": () => (++refreshes === 1 ? { status: 200, data: { access: TOKEN_A } } : late),
      "/api/auth/admin/login/": () => ({ status: 200, data: { access: TOKEN_B } }),
    });
  }

  test.each([
    ["401", { status: 401 }],
    ["réseau", { status: 0, network: true }],
  ])("refresh de l'ancienne session en échec tardif (%s) après logout puis nouveau login", async (_n, late) => {
    serverWithLateRefresh(late as Reply);
    const div = await mount("/");
    let release: () => void = () => {};
    gates.set("/api/auth/refresh/", new Promise<void>((r) => (release = r)));
    let pending: Promise<unknown> = Promise.resolve();
    await act(async () => {
      pending = api.get("/api/ping/").catch(() => undefined);
    });
    await logoutThenLogin(div);
    await act(async () => {
      release();
      await pending;
    });
    expect(getAccessToken()).toBe(TOKEN_B);
    expect(div.querySelector('[data-testid="probe"]')?.textContent).toBe("Bonjour Awa Test");
    expect(div.querySelector('[data-testid="status"]')?.textContent).toBe("authenticated");
  });

  test("requête périmée qui reçoit 401 après logout et nouveau login : ni refresh ni effacement", async () => {
    serverWithLateRefresh({ status: 401 });
    const div = await mount("/");
    let release: () => void = () => {};
    gates.set("/api/ping/", new Promise<void>((r) => (release = r)));
    let pending: Promise<unknown> = Promise.resolve();
    await act(async () => {
      pending = api.get("/api/ping/").catch(() => undefined);
    });
    await logoutThenLogin(div);
    await act(async () => {
      release();
      await pending;
    });
    expect(count("/api/auth/refresh/")).toBe(1); // seulement celui du démarrage
    expect(getAccessToken()).toBe(TOKEN_B);
    expect(div.querySelector('[data-testid="status"]')?.textContent).toBe("authenticated");
  });

  test("login refusé pendant le refresh de démarrage : le statut ne reste pas « loading »", async () => {
    server({
      "/api/auth/admin/login/": () => ({ status: 401, data: { code: "invalid_credentials", message: "x" } }),
    });
    let release: () => void = () => {};
    gates.set("/api/auth/refresh/", new Promise<void>((r) => (release = r)));
    const div = await mount("/connexion");
    expect(div.querySelector('[data-testid="status"]')?.textContent).toBe("loading");
    await fillAndSubmit(div, "677123456", PASSWORD);
    expect(div.querySelector('[data-testid="status"]')?.textContent).toBe("anonymous");
    await act(async () => release());
    expect(div.querySelector('[data-testid="status"]')?.textContent).toBe("anonymous");
    expect(getAccessToken()).toBeNull();
  });
});

describe("déconnexion et permissions", () => {
  test("déconnexion : POST logout, jeton et cache effacés, retour à la connexion", async () => {
    server();
    const div = await mount("/");
    qc.setQueryData(["secret"], { a: 1 });
    await click(byText(div, "button", "Quitter"));
    expect(count("/api/auth/logout/")).toBe(1);
    expect(getAccessToken()).toBeNull();
    expect(qc.getQueryData(["secret"])).toBeUndefined();
    expect(div.querySelector("h1")?.textContent).toBe("Connexion");
  });

  test("les permissions du serveur masquent les actions interdites", async () => {
    server();
    const div = await mount("/");
    expect(byText(div, "button", "Valider")).not.toBeNull();
    expect(byText(div, "button", "Gérer les admins")).toBeNull();
    expect(div.querySelector('[data-testid="can"]')?.textContent).toBe("false");
  });
});
