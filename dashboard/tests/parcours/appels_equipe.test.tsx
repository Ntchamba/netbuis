// Parcours APPELS DE L'ÉQUIPE : Disponible → sonnerie → Répondre → fiche avec numéros → raccrocher ;
// deux sonneries ; sonnerie prise par un collègue ; reconnexion du flux (avec jeton renouvelé).
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { getAccessToken } from "../../src/auth/tokenStorage";
import { byText, calls, click, installCommonHooks, mountApp, startWorld, storageDump, wait } from "./harness";
import type { Call, Reply } from "../auth/fakeServer";
import type { World } from "./world";
import { VALIDATEUR } from "./world";

// Les salles Jitsi réelles ne se chargent pas dans jsdom : on remplace seulement le chargeur.
const jitsi = vi.hoisted(() => ({ created: [] as Array<{ domain: string; options: Record<string, unknown> }>, disposed: 0 }));
vi.mock("../../src/modules/team_calls/jitsi", async (importOriginal) => {
  const real = await importOriginal<typeof import("../../src/modules/team_calls/jitsi")>();
  return {
    ...real,
    loadJitsiApi: vi.fn(async () =>
      class {
        constructor(domain: string, options: Record<string, unknown>) {
          jitsi.created.push({ domain, options });
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

installCommonHooks();

const PERMS = [...VALIDATEUR, "peut_repondre_aux_appels"];
const S1 = "11111111-1111-4111-8111-111111111111";
const S2 = "22222222-2222-4222-8222-222222222222";
const JITSI = { domain: "jitsi.exemple.test", room: "salle-secrete-fictive", jwt: "jeton-jitsi-fictif" };
const PHONES = { business: "+237600000001", caller: "+237600000002" };
const BIZ = { id: 7, name: "Boutique Test", type_label: "Entreprise", kind: "entreprise" };
const ring = (id: string, caller: string) => ({ session_id: id, state: "ringing", caller_name: caller, business: BIZ, expires_at: null, ring_seconds_left: 30 });
const sse = (event: string, data: unknown) => `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;

interface Stream {
  push: (t: string) => void;
  end: () => void;
}
let streams: Stream[];
let streamAuth: Array<string | undefined>;
let world: World;
let acceptReply: (c: Call) => Reply;

function stubStream() {
  const enc = new TextEncoder();
  vi.stubGlobal(
    "fetch",
    vi.fn(async (_url: string, init: RequestInit) => {
      const auth = (init.headers as Record<string, string>).Authorization;
      streamAuth.push(auth);
      // Comme le vrai serveur : un jeton périmé est refusé.
      if (auth !== `Bearer ${world.access}`) return new Response(null, { status: 401 });
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
      streams.push({ push: (t) => controller.enqueue(enc.encode(t)), end: () => controller.close() });
      return new Response(body, { status: 200, headers: { "Content-Type": "text/event-stream" } });
    }),
  );
}
const stream = () => streams[streams.length - 1]!;

function boot(): void {
  world = startWorld(PERMS);
  world.extra = (c) => {
    if (c.url === "/api/admin/calls/presence/") return { status: 200, data: { available: (c.body as { available?: boolean }).available ?? true } };
    if (c.url === "/api/admin/calls/") return { status: 200, data: { count: 0, next: null, previous: null, results: [] } };
    const m = /^\/api\/admin\/calls\/sessions\/([0-9a-f-]+)\/(accept|decline|end|context)\/$/.exec(c.url);
    if (!m) return undefined;
    if (m[2] === "accept") return acceptReply(c);
    if (m[2] === "context") {
      return {
        status: 200,
        data: {
          session_id: m[1], state: "answered", caller: { name: "Awa", phone: PHONES.caller },
          business: { ...BIZ, type_compte: "entreprise", phone: PHONES.business, owner_name: "Mme Ngo", category: "Alimentation", sous_categories: [], zone_name: "Domayo", zone_parent_name: "Maroua", repere: "Près du marché", description: "Vente de riz.", representant_nom: "", forme_juridique: "", rccm: "", photo_url: null, representant_photo_url: null, status: "actif", cni_verifiee: true, motif_rejet: "", subscription: { active: false, end: null }, reports_count: 0, whatsapp_reports_count: 0, calls_count: 1, views_count: 3, created_at: "2026-01-01T00:00:00Z", history: [] },
        },
      };
    }
    return { status: 200, data: { session_id: m[1], state: m[2] === "end" ? "ended" : "declined" } };
  };
}

beforeEach(() => {
  streams = [];
  streamAuth = [];
  jitsi.created.length = 0;
  jitsi.disposed = 0;
  acceptReply = (c) => {
    const id = /sessions\/([0-9a-f-]+)\/accept/.exec(c.url)![1]!;
    return { status: 200, data: { session_id: id, caller_name: id === S1 ? "Awa" : "Kevin", business: BIZ, jitsi: JITSI } };
  };
  stubStream();
});
afterEach(() => vi.unstubAllGlobals());

const dialog = () => document.querySelector('[data-testid="incoming-call"]') as HTMLElement | null;
const room = () => document.querySelector('[data-testid="call-room"]') as HTMLElement | null;
const fiche = () => document.querySelector('[data-testid="call-fiche"]') as HTMLElement | null;
const posts = (suffix: string) => calls.filter((c) => c.method === "post" && c.url.endsWith(suffix));
const toggle = (div: HTMLElement) => div.querySelector('[role="switch"]') as HTMLButtonElement;

test("Disponible → sonnerie → Répondre → fiche avec les numéros → raccrocher : tout est nettoyé", async () => {
  boot();
  const logs = (["log", "info", "warn", "error", "debug"] as const).map((m) => vi.spyOn(console, m));
  const app = await mountApp("/demandes");
  expect(streamAuth).toEqual([`Bearer ${world.access}`]); // le flux s'authentifie par l'en-tête, pas par l'adresse
  expect(calls.some((c) => c.url.includes("stream") && c.url.includes("jeton"))).toBe(false);

  // Disponible.
  stream().push(sse("presence", { available: false }));
  await wait();
  expect(toggle(app.div).textContent).toBe("Indisponible");
  await click(toggle(app.div));
  await wait();
  expect(posts("/presence/").at(-1)?.body).toEqual({ available: true });
  expect(toggle(app.div).textContent).toBe("Disponible");

  // Sonnerie : l'appelant et le commerce, mais aucun numéro et aucune lecture de fiche.
  stream().push(sse("ringing", ring(S1, "Awa")));
  await wait();
  expect(dialog()!.getAttribute("role")).toBe("alertdialog");
  expect(dialog()!.textContent).toContain("Awa");
  expect(dialog()!.textContent).toContain("Appel au sujet de Boutique Test");
  expect(document.body.textContent).not.toContain("600000001");
  expect(calls.some((c) => c.url.endsWith("/context/"))).toBe(false);

  // Répondre → salle Jitsi (audio seul, jeton de l'API), dialogue fermé.
  await click(byText(dialog()!, "button", "Répondre"));
  await wait();
  expect(posts(`/${S1}/accept/`)).toHaveLength(1);
  expect(dialog()).toBeNull();
  expect(room()).not.toBeNull();
  expect(jitsi.created[0]!.domain).toBe(JITSI.domain);
  expect(jitsi.created[0]!.options).toMatchObject({ roomName: JITSI.room, jwt: JITSI.jwt });
  expect(jitsi.created[0]!.options.configOverwrite).toMatchObject({ startWithVideoMuted: true, startAudioOnly: true });

  // Fiche : les deux numéros apparaissent, l'appel continue.
  await click(byText(room()!, "button", "Voir la fiche"));
  await wait();
  expect(fiche()!.querySelector('[data-testid="phone-business"]')!.textContent).toBe("+237 600 000 001");
  expect(fiche()!.querySelector('[data-testid="phone-caller"]')!.textContent).toBe("+237 600 000 002");
  expect(fiche()!.textContent).toContain("Domayo, Maroua");
  expect(room()).not.toBeNull();
  expect(posts("/end/")).toHaveLength(0);
  expect(storageDump()).not.toContain("6000000");

  // Raccrocher : end envoyé, salle et fiche fermées, plus aucun numéro nulle part.
  await click(byText(room()!, "button", "Raccrocher"));
  await wait();
  expect(posts(`/${S1}/end/`)).toHaveLength(1);
  expect(room()).toBeNull();
  expect(fiche()).toBeNull();
  expect(jitsi.disposed).toBeGreaterThan(0);
  expect(document.body.textContent).not.toContain("600 000 001");
  expect(document.body.textContent).not.toContain("600 000 002");
  expect(storageDump()).not.toContain(JITSI.room);
  expect(storageDump()).not.toContain(JITSI.jwt);
  for (const l of logs) expect(l).not.toHaveBeenCalled();
  // La page d'équipe, elle, ne montre jamais de numéro.
  await app.goTo("Appels à l'équipe");
  expect(app.main().textContent).not.toMatch(/\+237\s?6\d\d/);
});

test("deux sonneries simultanées : la première s'affiche, la seconde attend ; une seule communication à la fois", async () => {
  boot();
  const app = await mountApp("/demandes");
  stream().push(sse("ringing", ring(S1, "Awa")));
  stream().push(sse("ringing", ring(S2, "Kevin")));
  await wait();
  expect(dialog()!.textContent).toContain("Awa");
  expect(dialog()!.textContent).toContain("1 autre appel sonne aussi.");
  expect(document.querySelectorAll('[data-testid="incoming-call"]')).toHaveLength(1);

  await click(byText(dialog()!, "button", "Répondre"));
  await wait();
  expect(posts("/accept/").map((c) => c.url)).toEqual([`/api/admin/calls/sessions/${S1}/accept/`]);
  // Pendant la communication, la 2e sonne encore mais on ne peut pas y répondre.
  expect(room()).not.toBeNull();
  expect(dialog()!.textContent).toContain("Kevin");
  expect(dialog()!.textContent).toContain("Terminez l'appel en cours pour répondre.");
  expect(byText(dialog()!, "button", "Répondre")!.hasAttribute("disabled")).toBe(true);
  await click(byText(dialog()!, "button", "Répondre"));
  await wait(2);
  expect(posts("/accept/")).toHaveLength(1);

  // On raccroche : la 2e est toujours là et peut être prise.
  await click(byText(room()!, "button", "Raccrocher"));
  await wait();
  expect(room()).toBeNull();
  expect(dialog()!.textContent).toContain("Kevin");
  expect(byText(dialog()!, "button", "Répondre")!.hasAttribute("disabled")).toBe(false);
  await click(byText(dialog()!, "button", "Répondre"));
  await wait();
  expect(posts("/accept/").map((c) => c.url)).toEqual([`/api/admin/calls/sessions/${S1}/accept/`, `/api/admin/calls/sessions/${S2}/accept/`]);
  expect(room()).not.toBeNull();
  expect(app.div.querySelector('[data-testid="call-room"]')).not.toBeNull();
});

test("sonnerie prise par un collègue : la fenêtre se ferme toute seule, sans requête de notre part", async () => {
  boot();
  await mountApp("/demandes");
  stream().push(sse("ringing", ring(S1, "Awa")));
  await wait();
  expect(dialog()).not.toBeNull();
  stream().push(sse("taken", { session_id: S1, state: "answered", reason: "" }));
  await wait();
  expect(dialog()).toBeNull();
  expect(posts("/accept/")).toHaveLength(0);
  expect(posts("/decline/")).toHaveLength(0);
  expect(room()).toBeNull();
});

test("course perdue : on clique Répondre juste après le collègue (409) → message, pas de salle", async () => {
  boot();
  acceptReply = () => ({ status: 409, data: { code: "call_taken", message: "pris" } });
  await mountApp("/demandes");
  stream().push(sse("ringing", ring(S1, "Awa")));
  await wait();
  await click(byText(dialog()!, "button", "Répondre"));
  await wait();
  expect(document.body.textContent).toContain("Un collègue a déjà répondu à cet appel.");
  expect(dialog()).toBeNull();
  expect(room()).toBeNull();
  expect(jitsi.created).toHaveLength(0);
});

test("refuser une sonnerie : decline envoyé, fenêtre fermée ; l'appelant qui raccroche ferme la salle", async () => {
  boot();
  await mountApp("/demandes");
  stream().push(sse("ringing", ring(S1, "Awa")));
  await wait();
  await click(byText(dialog()!, "button", "Refuser"));
  await wait();
  expect(posts(`/${S1}/decline/`)).toHaveLength(1);
  expect(dialog()).toBeNull();
  stream().push(sse("ringing", ring(S2, "Kevin")));
  await wait();
  await click(byText(dialog()!, "button", "Répondre"));
  await wait();
  expect(room()).not.toBeNull();
  stream().push(sse("ended", { session_id: S2, state: "ended", reason: "caller_hangup" }));
  await wait();
  expect(room()).toBeNull();
});

test("flux coupé, jeton expiré entre-temps : reconnexion automatique avec un jeton renouvelé ; les sonneries périmées disparaissent, les rejouées reviennent", async () => {
  boot();
  await mountApp("/demandes");
  stream().push(sse("ringing", ring(S1, "Awa")));
  await wait();
  expect(dialog()).not.toBeNull();
  const refreshBefore = world.refreshCount;
  const oldToken = world.access;

  world.expire(); // le jeton d'accès expire pendant que le flux est coupé
  const first = stream();
  first.end();
  await wait(80, 20); // délai minimal de reconnexion : 1 s
  expect(streams).toHaveLength(2);
  expect(streamAuth).toEqual([`Bearer ${oldToken}`, `Bearer ${oldToken}`, `Bearer ${world.access}`]); // refusé (401), puis rejoué
  expect(world.refreshCount).toBe(refreshBefore + 1);
  expect(getAccessToken()).toBe(world.access);
  // Un collègue a répondu pendant la coupure : rien n'est rejoué, la fenêtre périmée disparaît.
  expect(dialog()).toBeNull();
  // Une nouvelle sonnerie rejouée par le serveur s'affiche de nouveau.
  stream().push(sse("ringing", ring(S2, "Kevin")));
  await wait();
  expect(dialog()!.textContent).toContain("Kevin");
});

test("sans le droit de répondre : ni bouton Disponible, ni flux, ni entrée de menu", async () => {
  world = startWorld(VALIDATEUR);
  const app = await mountApp("/demandes");
  expect(app.div.querySelector('[role="switch"]')).toBeNull();
  expect(streams).toHaveLength(0);
  expect(byText(app.div, "nav a", "Appels à l'équipe")).toBeNull();
  const direct = await mountApp("/appels-equipe");
  expect(direct.main().textContent).toContain("Accès refusé");
});
