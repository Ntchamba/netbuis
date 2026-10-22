import "../auth/fakeServer";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act, Component, type ReactNode } from "react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { AuthProvider } from "../../src/auth/AuthProvider";
import { clearAccessToken, getAccessToken } from "../../src/auth/tokenStorage";
import { ThemeProvider } from "../../src/components/theme/ThemeProvider";
import { ToastProvider } from "../../src/components/ui/Toast";
import { buildOptions, isValidJitsiDomain, loadJitsiApi } from "../../src/modules/team_calls/jitsi";
import { CallErrorBoundary } from "../../src/modules/team_calls/components/CallErrorBoundary";
import { openAuthorizedStream, SseParser, type SseMessage } from "../../src/modules/team_calls/sse";
import { AppRoutes } from "../../src/routes";
import { calls, resetServer, setHandler, type Call, type Reply } from "../auth/fakeServer";
import { byText, cleanup, click, render } from "../components/helpers";

// Les salles Jitsi réelles ne se chargent pas dans jsdom : on remplace seulement le chargeur.
const jitsi = vi.hoisted(() => ({
  created: [] as Array<{ domain: string; options: Record<string, unknown> }>,
  listeners: {} as Record<string, () => void>,
  disposed: 0,
}));
vi.mock("../../src/modules/team_calls/jitsi", async (importOriginal) => {
  const real = await importOriginal<typeof import("../../src/modules/team_calls/jitsi")>();
  return {
    ...real,
    loadJitsiApi: vi.fn(async () =>
      class {
        constructor(domain: string, options: Record<string, unknown>) {
          jitsi.created.push({ domain, options });
        }
        addListener(event: string, fn: () => void) {
          jitsi.listeners[event] = fn;
        }
        executeCommand() {}
        dispose() {
          jitsi.disposed += 1;
        }
      },
    ),
  };
});

const PERMS = ["peut_voir_demandes", "peut_voir_comptes", "peut_valider_demande", "peut_repondre_aux_appels"];
const wait = (ms = 20) => act(async () => new Promise((r) => setTimeout(r, ms)));

// ---- faux flux SSE (fetch) ----
interface FakeStream {
  push: (text: string) => void;
  end: () => void;
}
interface FetchCall {
  url: string;
  authorization: string | undefined;
}
let fetchCalls: FetchCall[] = [];
let streams: FakeStream[] = [];
let fetchPlan: Array<number | "stream"> = [];

function stubFetch() {
  const enc = new TextEncoder();
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string, init: RequestInit) => {
      const headers = init.headers as Record<string, string>;
      fetchCalls.push({ url, authorization: headers.Authorization });
      const step = fetchPlan.length > 1 ? fetchPlan.shift()! : (fetchPlan[0] ?? "stream");
      if (step !== "stream") return new Response(null, { status: step });
      let controller!: ReadableStreamDefaultController<Uint8Array>;
      const body = new ReadableStream<Uint8Array>({
        start(c) {
          controller = c;
        },
      });
      init.signal?.addEventListener("abort", () => {
        try {
          controller.error(new DOMException("abort", "AbortError"));
        } catch {
          /* déjà fermé */
        }
      });
      streams.push({
        push: (t) => controller.enqueue(enc.encode(t)),
        end: () => controller.close(),
      });
      return new Response(body, { status: 200, headers: { "Content-Type": "text/event-stream" } });
    }),
  );
}
const sse = (event: string, data: unknown) => `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
const lastStream = () => streams[streams.length - 1]!;

const RINGING = {
  session_id: "11111111-1111-4111-8111-111111111111",
  state: "ringing",
  caller_name: "Awa",
  business: { id: 7, name: "Boutique Test" },
  expires_at: null,
  ring_seconds_left: 30,
};
const JITSI = { domain: "jitsi.exemple.test", room: "salle-secrete-fictive", jwt: "jeton-jitsi-fictif" };

function agentCall(over: Record<string, unknown> = {}) {
  return {
    session_id: "22222222-2222-4222-8222-222222222222",
    state: "missed",
    end_reason: "timeout",
    caller_name: "Kevin",
    business: { id: 3, name: "Chez Paul" },
    agent: null,
    created_at: new Date().toISOString(),
    answered_at: null,
    ended_at: null,
    ...over,
  };
}

function server(permissions: string[], extra: (c: Call) => Reply | undefined = () => undefined) {
  const me = { id: 4, name: "Agent Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/requests/") return { status: 200, data: { count: 0, next: null, results: [] } };
    const r = extra(c);
    return r ?? { status: 404 };
  });
}

async function mount(path = "/demandes") {
  const div = await render(
    <QueryClientProvider client={new QueryClient()}>
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

const dialog = () => document.querySelector('[data-testid="incoming-call"]');
const room = () => document.querySelector('[data-testid="call-room"]');
const posts = (suffix: string) => calls.filter((c) => c.method === "post" && c.url.endsWith(suffix));

beforeEach(() => {
  resetServer();
  clearAccessToken();
  fetchCalls = [];
  streams = [];
  fetchPlan = ["stream"];
  jitsi.created.length = 0;
  jitsi.disposed = 0;
  stubFetch();
});
afterEach(async () => {
  await cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("lecture SSE", () => {
  test("découpe les messages même coupés en morceaux, ignore les commentaires, lit retry", () => {
    const p = new SseParser();
    const out: SseMessage[] = [];
    out.push(...p.feed("retry: 2000\n\n: keepalive\n\nevent: ringi"));
    out.push(...p.feed('ng\ndata: {"a":1}\n'));
    expect(out).toEqual([]);
    out.push(...p.feed("\nevent: taken\r\ndata: x\r\n\r\n"));
    expect(out).toEqual([
      { event: "ringing", data: '{"a":1}' },
      { event: "taken", data: "x" },
    ]);
    expect(p.retryMs).toBe(2000);
  });

  test("le jeton d'accès part en en-tête ; un 401 renouvelle le jeton puis se reconnecte", async () => {
    server([], (c) => (c.url === "/api/auth/refresh/" ? { status: 200, data: { access: "jeton-renouvele" } } : undefined));
    setHandler((c) => (c.url === "/api/auth/refresh/" ? { status: 200, data: { access: "jeton-renouvele" } } : { status: 404 }));
    const { setAccessToken } = await import("../../src/auth/tokenStorage");
    setAccessToken("jeton-perime");
    fetchPlan = [401, "stream"];
    const seen: string[] = [];
    const stop = openAuthorizedStream({ url: "/x/", onMessage: () => {}, onStatus: (s) => seen.push(s) });
    await wait(40);
    stop();
    expect(fetchCalls.map((c) => c.authorization)).toEqual(["Bearer jeton-perime", "Bearer jeton-renouvele"]);
    expect(getAccessToken()).toBe("jeton-renouvele");
    expect(seen).toContain("open");
  });

  test("403 : arrêt définitif, pas de reconnexion", async () => {
    fetchPlan = [403];
    const seen: string[] = [];
    const stop = openAuthorizedStream({ url: "/x/", onMessage: () => {}, onStatus: (s) => seen.push(s), minDelayMs: 5 });
    await wait(60);
    stop();
    expect(fetchCalls).toHaveLength(1);
    expect(seen).toContain("forbidden");
  });

  test("flux coupé : reconnexion automatique, messages rejoués reçus", async () => {
    const got: string[] = [];
    const stop = openAuthorizedStream({ url: "/x/", onMessage: (m) => got.push(m.event), onStatus: () => {}, minDelayMs: 5, maxDelayMs: 10 });
    await wait(20);
    lastStream().push(sse("ringing", RINGING));
    lastStream().end();
    await wait(60);
    lastStream().push(sse("ringing", RINGING));
    await wait(20);
    stop();
    expect(fetchCalls.length).toBe(2);
    expect(got).toEqual(["ringing", "ringing"]);
  });

  test("événement `closed` : pas de reconnexion", async () => {
    const stop = openAuthorizedStream({ url: "/x/", onMessage: () => {}, onStatus: () => {}, isFinal: (m) => m.event === "closed", minDelayMs: 5 });
    await wait(20);
    lastStream().push(sse("closed", { reason: "permission_removed" }));
    lastStream().end();
    await wait(60);
    stop();
    expect(fetchCalls).toHaveLength(1);
  });
});

describe("droit et présence", () => {
  test("sans le droit : ni bouton Disponible, ni flux, ni entrée de menu", async () => {
    server(PERMS.filter((p) => p !== "peut_repondre_aux_appels"));
    const div = await mount();
    expect(div.querySelector('[role="switch"]')).toBeNull();
    expect(fetchCalls).toHaveLength(0);
    expect(byText(div, "nav a", "Appels à l'équipe")).toBeNull();
  });

  test("avec le droit : flux ouvert avec le jeton, bouton Disponible, présence envoyée", async () => {
    server(PERMS, (c) => (c.url === "/api/admin/calls/presence/" ? { status: 200, data: { available: (c.body as { available: boolean }).available } } : undefined));
    const div = await mount();
    expect(fetchCalls[0]).toEqual({ url: "/api/admin/calls/stream/", authorization: "Bearer jeton-fictif" });
    expect(byText(div, "nav a", "Appels à l'équipe")).not.toBeNull();
    lastStream().push(sse("presence", { available: false }));
    await wait();
    const toggle = div.querySelector<HTMLButtonElement>('[role="switch"]')!;
    expect(toggle.getAttribute("aria-checked")).toBe("false");
    expect(toggle.textContent).toBe("Indisponible");
    await click(toggle);
    await wait();
    expect(posts("/presence/").at(-1)?.body).toEqual({ available: true });
    expect(toggle.getAttribute("aria-checked")).toBe("true");
    expect(toggle.textContent).toBe("Disponible");
  });

  test("le bouton Disponible reste visible sur les autres pages", async () => {
    server(PERMS, (c) => (c.url.startsWith("/api/admin/calls/") ? { status: 200, data: { count: 0, next: null, previous: null, results: [] } } : undefined));
    const div = await mount("/appels-equipe");
    expect(div.querySelector('[role="switch"]')).not.toBeNull();
  });
});

describe("appel entrant", () => {
  const withAccept = (c: Call): Reply | undefined => {
    if (c.url.endsWith("/accept/")) return { status: 200, data: { session_id: RINGING.session_id, caller_name: "Awa", business: RINGING.business, jitsi: JITSI } };
    if (c.url.endsWith("/decline/")) return { status: 200, data: { session_id: RINGING.session_id, state: "declined" } };
    if (c.url.endsWith("/end/")) return { status: 200, data: { session_id: RINGING.session_id, state: "ended" } };
    return undefined;
  };

  test("la fenêtre annonce l'appelant, le commerce, le compte à rebours et des boutons de 44 px", async () => {
    server(PERMS, withAccept);
    await mount();
    lastStream().push(sse("ringing", RINGING));
    await wait();
    const d = dialog()!;
    expect(d.getAttribute("role")).toBe("alertdialog");
    expect(d.textContent).toContain("Awa");
    expect(d.textContent).toContain("Appel au sujet de Boutique Test");
    expect(d.textContent).toMatch(/Sonnerie : (30|29) s/);
    const buttons = Array.from(d.querySelectorAll("button"));
    expect(buttons.map((b) => b.textContent)).toEqual(["Répondre", "Refuser"]);
    expect(buttons.every((b) => b.className.includes("min-h-11"))).toBe(true);
    expect(document.activeElement).toBe(buttons[0]);
  });

  test("Refuser envoie decline et ferme la fenêtre", async () => {
    server(PERMS, withAccept);
    await mount();
    lastStream().push(sse("ringing", RINGING));
    await wait();
    await click(byText(dialog()!, "button", "Refuser"));
    await wait();
    expect(posts(`/${RINGING.session_id}/decline/`)).toHaveLength(1);
    expect(dialog()).toBeNull();
  });

  test("`taken` : la fenêtre se ferme sans qu'on réponde", async () => {
    server(PERMS, withAccept);
    await mount();
    lastStream().push(sse("ringing", RINGING));
    await wait();
    expect(dialog()).not.toBeNull();
    lastStream().push(sse("taken", { session_id: RINGING.session_id, state: "answered", reason: "" }));
    await wait();
    expect(dialog()).toBeNull();
    expect(posts("/accept/")).toHaveLength(0);
  });

  test("reconnexion : les sonneries périmées disparaissent, les sonneries rejouées reviennent", async () => {
    server(PERMS, withAccept);
    fetchPlan = ["stream"];
    await mount();
    lastStream().push(sse("ringing", RINGING));
    await wait();
    expect(dialog()).not.toBeNull();
    lastStream().end();
    await wait(1200); // délai minimal de reconnexion : 1 s
    expect(streams).toHaveLength(2);
    expect(dialog()).toBeNull(); // rien rejoué : un collègue a répondu pendant la coupure
    lastStream().push(sse("ringing", RINGING));
    await wait();
    expect(dialog()).not.toBeNull();
  }, 10_000);

  test("Répondre : accept, salle Jitsi avec le domaine, la salle et le jeton de l'API, audio seul, vidéo coupée", async () => {
    server(PERMS, withAccept);
    await mount();
    lastStream().push(sse("ringing", RINGING));
    await wait();
    await click(byText(dialog()!, "button", "Répondre"));
    await wait();
    expect(posts("/accept/")).toHaveLength(1);
    expect(dialog()).toBeNull();
    expect(room()).not.toBeNull();
    expect(jitsi.created).toHaveLength(1);
    const { domain, options } = jitsi.created[0]!;
    expect(domain).toBe(JITSI.domain);
    expect(options.roomName).toBe(JITSI.room);
    expect(options.jwt).toBe(JITSI.jwt);
    expect(options.configOverwrite).toMatchObject({ startWithVideoMuted: true, startAudioOnly: true });
  });

  test("Raccrocher : end envoyé, salle fermée (dispose)", async () => {
    server(PERMS, withAccept);
    await mount();
    lastStream().push(sse("ringing", RINGING));
    await wait();
    await click(byText(dialog()!, "button", "Répondre"));
    await wait();
    await click(byText(room()!, "button", "Raccrocher"));
    await wait();
    expect(posts("/end/")).toHaveLength(1);
    expect(room()).toBeNull();
    expect(jitsi.disposed).toBeGreaterThan(0);
  });

  test("la salle se ferme quand la fenêtre Jitsi se ferme ou quand l'appelant raccroche (`ended`)", async () => {
    server(PERMS, withAccept);
    await mount();
    lastStream().push(sse("ringing", RINGING));
    await wait();
    await click(byText(dialog()!, "button", "Répondre"));
    await wait();
    lastStream().push(sse("ended", { session_id: RINGING.session_id, state: "ended", reason: "caller_hangup" }));
    await wait();
    expect(room()).toBeNull();
  });

  test("409 call_taken à la réponse : message, fenêtre fermée, pas de salle", async () => {
    server(PERMS, (c) => (c.url.endsWith("/accept/") ? { status: 409, data: { code: "call_taken", message: "pris" } } : undefined));
    await mount();
    lastStream().push(sse("ringing", RINGING));
    await wait();
    await click(byText(dialog()!, "button", "Répondre"));
    await wait();
    expect(document.body.textContent).toContain("Un collègue a déjà répondu à cet appel.");
    expect(dialog()).toBeNull();
    expect(room()).toBeNull();
  });

  test("aucune salle, aucun jeton dans le stockage ni dans la console", async () => {
    const spies = (["log", "info", "warn", "error", "debug"] as const).map((m) => vi.spyOn(console, m));
    server(PERMS, withAccept);
    await mount();
    lastStream().push(sse("ringing", RINGING));
    await wait();
    await click(byText(dialog()!, "button", "Répondre"));
    await wait();
    await click(byText(room()!, "button", "Raccrocher"));
    await wait();
    const stored = JSON.stringify({ ...localStorage }) + JSON.stringify({ ...sessionStorage });
    expect(stored).not.toContain(JITSI.room);
    expect(stored).not.toContain(JITSI.jwt);
    for (const s of spies) expect(s).not.toHaveBeenCalled();
  });

  test("battement de cœur : une présence sans corps toutes les 10 s tant que le flux est ouvert", async () => {
    vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
    try {
      server(PERMS, (c) => (c.url === "/api/admin/calls/presence/" ? { status: 200, data: { available: true } } : undefined));
      await mount();
      expect(posts("/presence/")).toHaveLength(0);
      await act(async () => {
        vi.advanceTimersByTime(10_000);
      });
      await wait(5);
      expect(posts("/presence/")).toHaveLength(1);
      expect(posts("/presence/")[0]!.body).toEqual({});
    } finally {
      vi.useRealTimers();
    }
  });
});

describe("page Appels à l'équipe", () => {
  test("liste (sans numéro), filtre Manqués = missed,declined, Mes appels = agent", async () => {
    server(PERMS, (c) => {
      if (c.url !== "/api/admin/calls/") return undefined;
      const rows = [agentCall(), agentCall({ session_id: "33333333-3333-4333-8333-333333333333", state: "ended", caller_name: "Fanta", agent: { id: 4, name: "Agent Test" }, answered_at: "2026-10-22T10:00:00Z", ended_at: "2026-10-22T10:02:05Z" })];
      return { status: 200, data: { count: 2, next: null, previous: null, results: rows } };
    });
    const div = await mount("/appels-equipe");
    expect(div.textContent).toContain("Kevin");
    expect(div.textContent).toContain("Chez Paul");
    expect(div.textContent).toContain("2 min 05 s");
    expect(div.textContent).not.toMatch(/\+237\s?6\d\d/);
    const listCalls = () => calls.filter((c) => c.url === "/api/admin/calls/");
    expect(listCalls()[0]!.params).toEqual({ page: 1, page_size: 20 });
    await click(byText(div, "button", "Manqués"));
    await wait();
    expect(listCalls().at(-1)!.params).toMatchObject({ state: "missed,declined" });
    await click(byText(div, "button", "Mes appels"));
    await wait();
    expect(listCalls().at(-1)!.params).toMatchObject({ state: "missed,declined", agent: 4 });
  });

  test("sans le droit, la page est refusée", async () => {
    server(PERMS.filter((p) => p !== "peut_repondre_aux_appels"));
    const div = await mount("/appels-equipe");
    expect(div.textContent).not.toContain("Mes appels");
  });
});

describe("Jitsi : chargement du script", () => {
  test("domaine accepté / refusé", () => {
    expect(isValidJitsiDomain("meet.exemple.org")).toBe(true);
    expect(isValidJitsiDomain("meet.exemple.org:8443")).toBe(true);
    for (const bad of ["", "evil.com/x.js", "https://a.b", "a b", "a.b?x=1", "-a.b", "a@b.c"]) expect(isValidJitsiDomain(bad)).toBe(false);
  });

  test("le script est chargé depuis le domaine de l'API, sans domaine invalide", async () => {
    const real = await vi.importActual<typeof import("../../src/modules/team_calls/jitsi")>("../../src/modules/team_calls/jitsi");
    await expect(real.loadJitsiApi("evil.com/x")).rejects.toThrow();
    expect(document.querySelector("script[src*='evil']")).toBeNull();
    const pending = real.loadJitsiApi("jitsi.exemple.test");
    const script = document.querySelector<HTMLScriptElement>("script[src$='/external_api.js']")!;
    expect(script.src).toBe("https://jitsi.exemple.test/external_api.js");
    window.JitsiMeetExternalAPI = class {} as never;
    script.onload?.(new Event("load"));
    await expect(pending).resolves.toBeTypeOf("function");
    delete window.JitsiMeetExternalAPI;
    script.remove();
  });

  test("buildOptions : audio d'abord, vidéo coupée, pas d'écran de pré-connexion", () => {
    const o = buildOptions(JITSI, document.createElement("div"));
    expect(o.configOverwrite).toMatchObject({ startWithVideoMuted: true, startAudioOnly: true, prejoinConfig: { enabled: false } });
  });
});

describe("ErrorBoundary", () => {
  class Bomb extends Component<{ armed: boolean; children?: ReactNode }> {
    render() {
      if (this.props.armed) throw new Error("boum");
      return <p>ok</p>;
    }
  }
  test("une erreur dans la fenêtre d'appel affiche un message et laisse le reste vivant", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const onAbort = vi.fn();
    const div = await render(
      <div>
        <p>reste de la page</p>
        <CallErrorBoundary onAbort={onAbort}>
          <Bomb armed />
        </CallErrorBoundary>
      </div>,
    );
    expect(div.textContent).toContain("reste de la page");
    expect(div.querySelector('[role="alert"]')?.textContent).toContain("La fenêtre d'appel a rencontré un problème.");
    await click(byText(div, "button", "Fermer l'appel"));
    expect(onAbort).toHaveBeenCalledTimes(1);
  });

  test("sans erreur, les enfants s'affichent", async () => {
    const div = await render(
      <CallErrorBoundary>
        <Bomb armed={false} />
      </CallErrorBoundary>,
    );
    expect(div.textContent).toBe("ok");
  });
});

// ---- T132b : fiche du commerce visé pendant l'appel (D-30) ----
const FICHE_PHONES = { business: "+237600000001", caller: "+237600000002" };
const RINGING_TYPED = { ...RINGING, business: { id: 7, name: "Boutique Test", type_label: "Entreprise", kind: "entreprise" } };
const CARD = {
  id: 7, name: "Boutique Test", type_compte: "entreprise", type_label: "Entreprise", kind: "entreprise",
  phone: FICHE_PHONES.business, owner_name: "Mme Ngo", category: "Alimentation", sous_categories: ["Riz"],
  zone_name: "Domayo", zone_parent_name: "Maroua", repere: "Près du marché", description: "Vente de riz.",
  representant_nom: "Mme Ngo", forme_juridique: "SARL", rccm: "RC/MAR/1", photo_url: null, representant_photo_url: null,
  status: "actif", cni_verifiee: true, motif_rejet: "", subscription: { active: true, end: "2027-01-01T00:00:00Z" },
  reports_count: 2, whatsapp_reports_count: 1, calls_count: 5, views_count: 40, created_at: "2026-01-01T00:00:00Z",
  history: [{ action: "validation_business", label: "Validation du compte", reason: "", admin_name: "Chef", created_at: "2026-01-02T10:00:00Z" }],
};

describe("fiche du commerce visé", () => {
  const context = (business: unknown) => ({ session_id: RINGING.session_id, state: "answered", caller: { name: "Awa", phone: FICHE_PHONES.caller }, business });
  const handler = (ctx: () => Reply) => (c: Call): Reply | undefined => {
    if (c.url.endsWith("/accept/")) return { status: 200, data: { session_id: RINGING.session_id, caller_name: "Awa", business: RINGING_TYPED.business, jitsi: JITSI } };
    if (c.url.endsWith("/end/")) return { status: 200, data: { session_id: RINGING.session_id, state: "ended" } };
    if (c.url.endsWith("/context/")) return ctx();
    return undefined;
  };
  const answer = async () => {
    lastStream().push(sse("ringing", RINGING_TYPED));
    await wait();
    await click(byText(dialog()!, "button", "Répondre"));
    await wait();
  };
  const fiche = () => document.querySelector('[data-testid="call-fiche"]');
  const contextCalls = () => calls.filter((c) => c.method === "get" && c.url.endsWith("/context/"));

  test("la fenêtre d'appel entrant indique le type du commerce ; aucun numéro, aucune requête de fiche avant de répondre", async () => {
    server(PERMS, handler(() => ({ status: 200, data: context(CARD) })));
    await mount();
    lastStream().push(sse("ringing", RINGING_TYPED));
    await wait();
    expect(dialog()!.textContent).toContain("Boutique Test");
    expect(dialog()!.textContent).toContain("Entreprise");
    expect(dialog()!.textContent).not.toContain("600000001");
    expect(contextCalls()).toHaveLength(0);
  });

  test("dans la salle : nom et type du commerce visé, bouton « Voir la fiche », rien n'est chargé avant le clic", async () => {
    server(PERMS, handler(() => ({ status: 200, data: context(CARD) })));
    await mount();
    await answer();
    const target = room()!.querySelector('[data-testid="call-target"]')!;
    expect(target.textContent).toContain("Boutique Test");
    expect(target.textContent).toContain("Entreprise");
    expect(byText(target, "button", "Voir la fiche")).not.toBeNull();
    expect(fiche()).toBeNull();
    expect(contextCalls()).toHaveLength(0);
    expect(document.body.textContent).not.toContain("600 000 001");
  });

  test("Voir la fiche : panneau latéral avec fiche complète et les deux numéros ; la salle et l'appel restent en cours", async () => {
    server(PERMS, handler(() => ({ status: 200, data: context(CARD) })));
    await mount();
    await answer();
    const disposedBefore = jitsi.disposed;
    await click(byText(room()!, "button", "Voir la fiche"));
    await wait();
    const panel = fiche()!;
    expect(panel).not.toBeNull();
    expect(panel.querySelector('[data-testid="phone-business"]')!.textContent).toBe("+237 600 000 001");
    expect(panel.querySelector('[data-testid="phone-caller"]')!.textContent).toBe("+237 600 000 002");
    for (const text of ["Entreprise", "Mme Ngo", "Alimentation", "Domayo, Maroua", "Près du marché", "Vente de riz.", "Actif", "Vérifiée", "Abonné jusqu'au", "Validation du compte"]) {
      expect(panel.textContent).toContain(text);
    }
    expect(panel.textContent).toMatch(/Signalements\s*2/);
    expect(room()).not.toBeNull();
    expect(jitsi.created).toHaveLength(1); // la salle n'est pas rechargée
    expect(jitsi.disposed).toBe(disposedBefore);
    expect(posts("/end/")).toHaveLength(0);
    expect(contextCalls()).toHaveLength(1);
    await click(byText(panel, "button", "Fermer la fiche"));
    await wait();
    expect(fiche()).toBeNull();
    expect(room()).not.toBeNull();
  });

  test("raccrocher ferme la fiche ; les numéros ne restent ni dans la page, ni dans le stockage, ni dans la console", async () => {
    const spies = (["log", "info", "warn", "error", "debug"] as const).map((m) => vi.spyOn(console, m));
    server(PERMS, handler(() => ({ status: 200, data: context(CARD) })));
    await mount();
    await answer();
    await click(byText(room()!, "button", "Voir la fiche"));
    await wait();
    const stored = () => JSON.stringify({ ...localStorage }) + JSON.stringify({ ...sessionStorage });
    for (const n of ["600000001", "600000002", "600 000 001"]) expect(stored()).not.toContain(n);
    await click(byText(room()!, "button", "Raccrocher"));
    await wait();
    expect(fiche()).toBeNull();
    expect(document.body.textContent).not.toContain("600 000 001");
    expect(document.body.textContent).not.toContain("600 000 002");
    for (const n of ["600000001", "600000002"]) expect(stored()).not.toContain(n);
    for (const s of spies) expect(s).not.toHaveBeenCalled();
  });

  test("fiche refusée par le serveur (409) : message clair, l'appel continue, on peut réessayer", async () => {
    let status = 409;
    server(PERMS, handler(() => (status === 409 ? { status: 409, data: { code: "call_not_answered", message: "x" } } : { status: 200, data: context(CARD) })));
    await mount();
    await answer();
    await click(byText(room()!, "button", "Voir la fiche"));
    await wait();
    expect(fiche()!.textContent).toContain("Impossible de charger la fiche. L'appel continue.");
    expect(fiche()!.textContent).not.toContain("600000001");
    expect(room()).not.toBeNull();
    status = 200;
    await click(byText(fiche()!, "button", "Réessayer"));
    await wait();
    expect(fiche()!.querySelector('[data-testid="phone-business"]')).not.toBeNull();
  });

  test("appel sans commerce visé : message clair, pas de bouton « Voir la fiche », numéro de l'appelant seulement", async () => {
    server(PERMS, (c) => {
      if (c.url.endsWith("/accept/")) return { status: 200, data: { session_id: RINGING.session_id, caller_name: "Awa", business: null, jitsi: JITSI } };
      if (c.url.endsWith("/context/")) return { status: 200, data: context(null) };
      return undefined;
    });
    await mount();
    lastStream().push(sse("ringing", { ...RINGING, business: null }));
    await wait();
    expect(dialog()!.textContent).toContain("Appel sans commerce précisé");
    await click(byText(dialog()!, "button", "Répondre"));
    await wait();
    const target = room()!.querySelector('[data-testid="call-target"]')!;
    expect(target.textContent).toContain("Appel sans commerce précisé : aucune fiche à afficher.");
    expect(Array.from(room()!.querySelectorAll("button")).some((b) => b.textContent?.includes("fiche"))).toBe(false);
    expect(target.querySelector('[data-testid="phone-caller"]')!.textContent).toBe("+237 600 000 002");
    expect(fiche()).toBeNull();
  });
});
