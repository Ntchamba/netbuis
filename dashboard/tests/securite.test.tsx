// T121 — revue de sécurité du tableau de bord : contrôles automatiques.
import "./auth/fakeServer";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act, Component, type ReactNode } from "react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { AuthProvider } from "../src/auth/AuthProvider";
import { clearAccessToken, getAccessToken } from "../src/auth/tokenStorage";
import { ThemeProvider } from "../src/components/theme/ThemeProvider";
import { ErrorBoundary } from "../src/components/ErrorBoundary";
import { ToastProvider } from "../src/components/ui/Toast";
import { NAV_ITEMS } from "../src/layouts/nav";
import { safeImageUrl } from "../src/lib/safeUrl";
import { isValidJitsiDomain } from "../src/modules/team_calls/jitsi";
import { referentialError } from "../src/modules/referentials/errors";
import { AppRoutes } from "../src/routes";
import { PATHS } from "../src/routes/paths";
import { calls, resetServer, setHandler, type Call, type Reply } from "./auth/fakeServer";
import { byText, cleanup, click, render } from "./components/helpers";

const jitsi = vi.hoisted(() => ({ disposed: 0, created: 0 }));
vi.mock("../src/modules/team_calls/jitsi", async (importOriginal) => {
  const real = await importOriginal<typeof import("../src/modules/team_calls/jitsi")>();
  return {
    ...real,
    loadJitsiApi: vi.fn(async () =>
      class {
        constructor() {
          jitsi.created += 1;
        }
        addListener() {}
        executeCommand() {}
        dispose() {
          jitsi.disposed += 1;
        }
      },
    ),
  };
});

import indexHtml from "../index.html?raw";

// ---------- lecture du code source ----------
// Les commentaires expliquent l'interdit (« jamais dans localStorage ») : seul le code compte.
const stripComments = (code: string) => code.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[\s;{}(,])\/\/.*$/gm, "$1");
const raw = import.meta.glob<string>(["../src/**/*.ts", "../src/**/*.tsx", "!../src/api/generated/**"], { query: "?raw", import: "default", eager: true });
const sources = Object.entries(raw).map(([path, text]) => ({ file: path.replace("../src/", ""), text: stripComments(text) }));
const offenders = (pattern: RegExp, allowed: string[] = []) =>
  sources.filter((s) => !allowed.includes(s.file) && pattern.test(s.text)).map((s) => s.file);

describe("code source : motifs interdits", () => {
  test("le contrôle voit bien les fichiers (le test n'est pas aveugle)", () => {
    expect(sources.length).toBeGreaterThan(100);
    expect(offenders(/localStorage/)).toEqual(["lib/theme.ts"]);
  });

  test("aucun HTML injecté, aucune évaluation de texte", () => {
    expect(offenders(/dangerouslySetInnerHTML|\.innerHTML|\.outerHTML|insertAdjacentHTML|document\.write|\beval\s*\(|new Function\s*\(/)).toEqual([]);
  });

  test("aucune console, aucun window.open ni redirection vers une adresse du serveur", () => {
    expect(offenders(/\bconsole\s*\./)).toEqual([]);
    expect(offenders(/window\.open|location\.(href|assign|replace)\s*[=(]/)).toEqual([]);
  });

  test("stockage du navigateur : seul le thème (clair/sombre) est écrit", () => {
    expect(offenders(/sessionStorage|indexedDB|document\.cookie|caches\.open/)).toEqual([]);
    const theme = sources.find((s) => s.file === "lib/theme.ts")!.text;
    const keys = [...theme.matchAll(/(?:get|set)Item\(([^,)]+)/g)].map((m) => m[1]);
    expect(new Set(keys)).toEqual(new Set(["THEME_KEY"]));
    expect(theme).toMatch(/THEME_KEY = "netbuis-theme"/);
  });

  test("variables exposées au navigateur : VITE_API_BASE_URL (et l'indicateur de simulation, sans effet dans l'application)", () => {
    const names = new Set<string>();
    for (const s of sources) for (const m of s.text.matchAll(/import\.meta\.env\.([A-Z_]+)/g)) names.add(m[1]!);
    expect([...names].sort()).toEqual(["DEV", "VITE_API_BASE_URL", "VITE_USE_MOCKS"]);
  });

  test("le numéro complet (champ `phone`) n'est lu que par la fiche d'appel et le détail de compte audité", () => {
    const users = ["modules/team_calls/components/CallFichePanel.tsx", "modules/team_calls/components/CallRoom.tsx", "modules/users/pages/UserDetailPage.tsx"];
    // CreateAdmin : `errors.phone` / `next.phone` sont les messages du formulaire de saisie, pas un numéro reçu du serveur.
    expect(offenders(/\.phone(?![_A-Za-z])/, [...users, "modules/admins/components/CreateAdmin.tsx"])).toEqual([]);
    for (const f of users) expect(sources.find((s) => s.file === f)!.text).toMatch(/\.phone(?![_A-Za-z])/); // contre-épreuve
  });

  test("toute image dont l'adresse vient du serveur passe par safeImageUrl", () => {
    const withImg = sources.filter((s) => /<img\b/.test(s.text) && /src=\{(url|state\.blobUrl)\}/.test(s.text));
    expect(withImg.length).toBeGreaterThanOrEqual(2);
    for (const s of withImg) {
      if (s.text.includes("src={url}")) expect(s.text, s.file).toContain("safeImageUrl(");
    }
  });

  test("index.html : aucun script en ligne (CSP stricte possible), référent limité", () => {
    const html = indexHtml;
    const inline = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>/g)];
    expect(inline).toEqual([]);
    expect(html).toContain('<meta name="referrer" content="same-origin" />');
  });

  test("l'application est enveloppée dans l'ErrorBoundary global", () => {
    expect(sources.find((s) => s.file === "main.tsx")!.text).toMatch(/<ErrorBoundary>[\s\S]*<AppRoutes \/>[\s\S]*<\/ErrorBoundary>/);
  });
});

describe("adresses venant du serveur", () => {
  test("safeImageUrl accepte https, chemin relatif et http local", () => {
    for (const ok of ["https://cdn.exemple.org/a.jpg", "/media/a.jpg", "http://localhost:8000/media/a.jpg", "http://127.0.0.1:8000/a.jpg"]) expect(safeImageUrl(ok)).toBe(ok);
  });
  test("safeImageUrl refuse tout le reste", () => {
    const bad = ["javascript:alert(1)", "JaVaScRiPt:alert(1)", "data:text/html,<script>1</script>", "blob:https://a/b", "file:///etc/passwd", "http://exemple.org/a.jpg", "//evil.example/a.jpg", "https://user:pw@exemple.org/a.jpg", " https://a.org/x", "a.jpg", "", null, undefined];
    for (const b of bad) expect(safeImageUrl(b as string | null), String(b)).toBeNull();
  });
  test("domaine Jitsi : nom d'hôte seulement, ni adresse IP, ni nom sans point", () => {
    for (const ok of ["meet.exemple.org", "8x8.vc", "jitsi.exemple.org:8443"]) expect(isValidJitsiDomain(ok), ok).toBe(true);
    for (const bad of ["127.0.0.1", "10.0.0.5:8443", "intranet", "evil.com/x.js", "https://a.b", "a.b#x", "a.b\\c", "user@a.b", "a b.c"]) expect(isValidJitsiDomain(bad), bad).toBe(false);
  });
  test("une erreur de champ du serveur n'est jamais affichée telle quelle", () => {
    const e = referentialError({ response: { status: 400, data: { code: "validation_error", fields: { name: ["This field may not be blank."] } } } });
    expect(JSON.stringify(e)).not.toContain("may not be blank");
    expect(e.fields?.name).toContain("Valeur invalide");
  });
});

describe("ErrorBoundary global", () => {
  class Bomb extends Component<{ children?: ReactNode }> {
    render(): ReactNode {
      throw new Error("detail-secret-0612345678");
    }
  }
  test("une erreur d'affichage montre un message sobre, sans le texte de l'erreur", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {}); // React signale lui-même l'erreur capturée
    const div = await render(
      <ErrorBoundary>
        <Bomb />
      </ErrorBoundary>,
    );
    expect(div.querySelector('[role="alert"]')?.textContent).toContain("Une erreur est survenue");
    expect(div.textContent).not.toContain("detail-secret");
    vi.restoreAllMocks();
  });
  test("sans erreur, les enfants s'affichent", async () => {
    const div = await render(
      <ErrorBoundary>
        <p>ok</p>
      </ErrorBoundary>,
    );
    expect(div.textContent).toBe("ok");
  });
});

// ---------- routes, menu, déconnexion ----------
const ALL = ["peut_voir_demandes", "peut_voir_comptes", "peut_valider_demande", "peut_gerer_referentiels", "peut_modifier_reglages", "peut_gerer_admins", "peut_moderer_contenu", "peut_repondre_aux_appels"];
const wait = (ms = 20) => act(async () => new Promise((r) => setTimeout(r, ms)));
let qc: QueryClient;
let streamSignals: AbortSignal[] = [];
let streamPush: (t: string) => void = () => {};

function server(permissions: string[], extra: (c: Call) => Reply | undefined = () => undefined) {
  const me = { id: 4, name: "Agent Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/auth/logout/") return { status: 200, data: {} };
    return extra(c) ?? { status: 404 };
  });
}

async function mount(path: string) {
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
  for (let i = 0; i < 4; i++) await wait(15);
  return div;
}

beforeEach(() => {
  resetServer();
  clearAccessToken();
  qc = new QueryClient();
  jitsi.disposed = 0;
  jitsi.created = 0;
  streamSignals = [];
  const enc = new TextEncoder();
  vi.stubGlobal(
    "fetch",
    vi.fn(async (_url: string, init: RequestInit) => {
      let controller!: ReadableStreamDefaultController<Uint8Array>;
      const body = new ReadableStream<Uint8Array>({ start: (c) => (controller = c) });
      streamSignals.push(init.signal as AbortSignal);
      init.signal?.addEventListener("abort", () => {
        try {
          controller.error(new DOMException("abort", "AbortError"));
        } catch {
          /* déjà fermé */
        }
      });
      streamPush = (t) => controller.enqueue(enc.encode(t));
      return new Response(body, { status: 200 });
    }),
  );
});
afterEach(async () => {
  await cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const PATH_SAMPLES: Record<string, string> = { [PATHS.compte]: "/comptes/5", [PATHS.referentiel]: "/referentiels/zones" };

describe("routes protégées", () => {
  test("chaque route du menu exige, dans les routes, la même permission que l'entrée de menu", () => {
    const routes = sources.find((s) => s.file === "routes/index.tsx")!.text;
    const found = [...routes.matchAll(/path=\{PATHS\.(\w+)\}\s*element=\{\s*<RequirePermission permission="(\w+)"/g)].map((m) => [m[1]!, m[2]!] as const);
    const byKey = new Map(found);
    expect(byKey.size).toBe(Object.keys(PATHS).length - 1); // toutes les pages sauf la connexion
    for (const item of NAV_ITEMS) {
      const key = Object.entries(PATHS).find(([, v]) => v === item.to)![0];
      expect(byKey.get(key), item.key).toBe(item.permission);
    }
  });

  test("sans aucun droit : toute page affiche « Accès refusé », sans demander de données", async () => {
    const paths = Object.entries(PATHS).filter(([k]) => k !== "login").map(([, v]) => PATH_SAMPLES[v] ?? v);
    expect(paths).toContain("/appels-equipe");
    for (const path of paths) {
      resetServer();
      server([]);
      const div = await mount(path);
      expect(div.querySelector('[role="alert"]')?.textContent, path).toContain("Accès refusé");
      expect(calls.filter((c) => c.url.startsWith("/api/admin/") && c.url !== "/api/admin/me/"), path).toEqual([]);
      expect(streamSignals, path).toHaveLength(0);
      await cleanup();
    }
  });

  test("/appels-equipe : refusée sans « peut_repondre_aux_appels » (menu masqué ET route refusée), autorisée avec", async () => {
    server(ALL.filter((p) => p !== "peut_repondre_aux_appels"));
    let div = await mount("/appels-equipe");
    expect(div.querySelector('[role="alert"]')?.textContent).toContain("Accès refusé");
    expect(div.querySelector("nav")?.textContent).not.toContain("Appels à l'équipe");
    expect(streamSignals).toHaveLength(0);
    await cleanup();
    resetServer();
    server(ALL, (c) => (c.url === "/api/admin/calls/" ? { status: 200, data: { count: 0, next: null, previous: null, results: [] } } : undefined));
    div = await mount("/appels-equipe");
    expect(div.textContent).not.toContain("Accès refusé");
    expect(div.querySelector("nav")?.textContent).toContain("Appels à l'équipe");
  });
});

describe("déconnexion", () => {
  test("pendant un appel : flux fermé, salle Jitsi fermée, jeton et cache effacés, plus rien à l'écran", async () => {
    const session = "11111111-1111-4111-8111-111111111111";
    const biz = { id: 7, name: "Boutique Test" };
    server(ALL, (c) => {
      if (c.url.endsWith("/accept/")) return { status: 200, data: { session_id: session, caller_name: "Awa", business: biz, jitsi: { domain: "jitsi.exemple.test", room: "salle-fictive", jwt: "jeton-fictif-jitsi" } } };
      if (c.url.endsWith("/context/")) return { status: 200, data: { session_id: session, caller: { name: "Awa", phone: "+237600000002" }, business: null } };
      if (c.url === "/api/admin/requests/") return { status: 200, data: { count: 0, next: null, results: [] } };
      return undefined;
    });
    const div = await mount("/demandes");
    expect(streamSignals).toHaveLength(1);
    streamPush(`event: ringing\ndata: ${JSON.stringify({ session_id: session, state: "ringing", caller_name: "Awa", business: biz, ring_seconds_left: 30 })}\n\n`);
    await wait();
    await click(byText(document.body, "button", "Répondre"));
    await wait();
    expect(document.querySelector('[data-testid="call-room"]')).not.toBeNull();
    expect(jitsi.created).toBe(1);
    qc.setQueryData(["admin", "accounts", "detail", 1], { phone: "+237600000009" });
    expect(getAccessToken()).not.toBeNull();

    await click(byText(div, "button", "Déconnexion"));
    await wait();

    expect(streamSignals[0]!.aborted).toBe(true);
    expect(jitsi.disposed).toBeGreaterThan(0);
    expect(document.querySelector('[data-testid="call-room"]')).toBeNull();
    expect(document.querySelector('[data-testid="call-fiche"]')).toBeNull();
    expect(document.querySelector('[data-testid="incoming-call"]')).toBeNull();
    expect(document.body.textContent).not.toContain("+237600000002");
    expect(getAccessToken()).toBeNull();
    expect(qc.getQueryCache().getAll()).toHaveLength(0);
    expect(JSON.stringify({ ...localStorage }) + JSON.stringify({ ...sessionStorage })).not.toMatch(/jeton|salle-fictive|\+237/);
    expect(streamSignals).toHaveLength(1); // pas de reconnexion du flux
  });
});
