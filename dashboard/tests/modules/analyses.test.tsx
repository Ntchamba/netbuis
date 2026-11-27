import "../auth/fakeServer";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act } from "react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, expect, test } from "vitest";
import { AuthProvider } from "../../src/auth/AuthProvider";
import { clearAccessToken } from "../../src/auth/tokenStorage";
import { ThemeProvider } from "../../src/components/theme/ThemeProvider";
import { ToastProvider } from "../../src/components/ui/Toast";
import { AppRoutes } from "../../src/routes";
import { safeTerm } from "../../src/modules/search_analytics/errors";
import { calls, resetServer, setHandler, type Call, type Reply } from "../auth/fakeServer";
import { byText, cleanup, click, render, type } from "../components/helpers";

// Données FICTIVES.
const SEARCHES = "/api/admin/analytics/searches/";
const CALLS = "/api/admin/analytics/calls/";
const TRENDS = "/api/trends/";
const ZONES = "/api/zones/";
const SETTINGS = "/api/admin/settings/";
const FULL = ["peut_voir_comptes", "peut_voir_demandes", "peut_modifier_reglages", "peut_gerer_admins"];
const VALIDATEUR = ["peut_voir_comptes", "peut_voir_demandes", "peut_valider_demande"];
const NONE = ["peut_voir_demandes"];

const searchData = (over: Record<string, unknown> = {}) => ({
  days: 7, since: "2026-10-16", total_searches: 40, total_without_results: 6,
  top_terms: [{ term: "riz", count: 12 }, { term: "savon", count: 5 }],
  no_result_terms: [{ term: "drone", count: 3 }],
  ...over,
});
const callData = (over: Record<string, unknown> = {}) => ({
  days: 7, since: "2026-10-16", total_calls: 30,
  by_day: [
    { date: "2026-10-16", count: 0 }, { date: "2026-10-17", count: 4 }, { date: "2026-10-18", count: 10 },
  ],
  by_operator: { orange: 15, mtn: 12, unknown: 3 },
  by_platform: { android: 25, ios: 5 },
  by_channel: { call: 20, whatsapp: 10 },
  ...over,
});
const trendData = (over: Record<string, unknown> = {}) => ({
  zone: { id: 1, name: "Douala" }, computed_at: "2026-10-21T04:00:00Z", period_days: 7,
  products: [{ id: 9, name: "Savon", rank: 2 }, { id: 8, name: "Riz", rank: 1 }],
  businesses: [{ id: 5, name: "Chez Awa", rank: 1, zone: { id: 2, name: "Akwa" } }],
  ...over,
});

let reply: Record<string, (c: Call) => Reply>;

function server(permissions: string[]) {
  const me = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return { status: 200, data: { pending_requests: 0 } };
    return reply[c.url]?.(c) ?? { status: 404 };
  });
}

async function wait(n = 4) {
  for (let i = 0; i < n; i++) await act(async () => new Promise((r) => setTimeout(r, 15)));
}

async function mount(path: string) {
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
  await wait();
  return div;
}

const main = (div: HTMLElement) => div.querySelector("section[aria-label]") as HTMLElement;
const select = (div: HTMLElement, label: string) => {
  const l = Array.from(div.querySelectorAll("label")).find((e) => e.textContent === label)!;
  return div.querySelector(`#${CSS.escape(l.getAttribute("for")!)}`) as HTMLSelectElement;
};
async function pick(el: HTMLSelectElement, value: string) {
  await act(async () => {
    el.value = value;
    el.dispatchEvent(new Event("change", { bubbles: true }));
  });
  await wait();
}
const of = (url: string) => calls.filter((c) => c.url === url);
const navLabels = (div: HTMLElement) => Array.from(div.querySelectorAll("aside nav > *")).map((e) => e.textContent);

beforeEach(() => {
  resetServer();
  clearAccessToken();
  localStorage.clear();
  sessionStorage.clear();
  reply = {
    [SEARCHES]: () => ({ status: 200, data: searchData() }),
    [CALLS]: () => ({ status: 200, data: callData() }),
    [ZONES]: () => ({ status: 200, data: { count: 2, next: null, results: [{ id: 3, name: "Yaoundé", level: "ville_village", parent: null }, { id: 1, name: "Douala", level: "ville_village", parent: null }] } }),
    [TRENDS]: () => ({ status: 200, data: trendData() }),
  };
});
afterEach(cleanup);

// ---------- Droits ----------
test("sans droit : entrées masquées, route refusée, aucune requête d'analyse", async () => {
  server(NONE);
  for (const path of ["/recherches", "/appels", "/tendances"]) {
    const div = await mount(path);
    expect(div.textContent).toContain("Accès refusé");
    expect(navLabels(div)).not.toContain("Recherches");
    expect(navLabels(div)).not.toContain("Appels");
    expect(navLabels(div)).not.toContain("Tendances");
    await cleanup();
  }
  expect(calls.filter((c) => [SEARCHES, CALLS, TRENDS, ZONES].includes(c.url))).toHaveLength(0);
});

test("Validateur et Administrateur complet : les trois entrées sont présentes", async () => {
  for (const perms of [VALIDATEUR, FULL]) {
    server(perms);
    const div = await mount("/recherches");
    expect(navLabels(div)).toEqual(expect.arrayContaining(["Recherches", "Appels", "Tendances"]));
    expect(div.textContent).not.toContain("Accès refusé");
    await cleanup();
  }
});

// ---------- Recherches ----------
test("recherches : termes fréquents, sans résultat, totaux, jeton seulement en en-tête", async () => {
  server(VALIDATEUR);
  const div = await mount("/recherches");
  const page = main(div);
  expect(page.textContent).toContain("Termes les plus cherchés");
  expect(page.textContent).toContain("Recherches sans résultat");
  expect(page.querySelector('ul[aria-label="Termes les plus cherchés"]')?.textContent).toContain("riz12");
  expect(page.querySelector('ul[aria-label="Recherches sans résultat"]')?.textContent).toContain("drone3");
  expect(page.textContent).toContain("40 recherches");
  expect(page.querySelector("h1")?.textContent).toBe("Recherches");
  const c = of(SEARCHES)[0]!;
  expect(c.params).toEqual({ days: 7 });
  expect(c.url).not.toContain("jeton");
  expect(c.auth).toBe("Bearer jeton-fictif");
  expect(page.querySelectorAll("a, button")).toHaveLength(0); // aucun terme cliquable
  expect(JSON.stringify(localStorage) + JSON.stringify(sessionStorage)).not.toContain("jeton");
});

test("recherches : changer la période relance la requête avec days", async () => {
  server(FULL);
  const div = await mount("/recherches");
  await pick(select(div, "Période"), "30");
  expect(of(SEARCHES).at(-1)!.params).toEqual({ days: 30 });
});

test("recherches : un terme qui ressemble à un numéro est masqué", async () => {
  reply[SEARCHES] = () => ({ status: 200, data: searchData({ top_terms: [{ term: "699 12 34 56", count: 2 }, { term: "riz", count: 1 }], no_result_terms: [{ term: "+237 677889900", count: 1 }] }) });
  server(FULL);
  const div = await mount("/recherches");
  expect(div.textContent).not.toContain("699");
  expect(div.textContent).not.toContain("677889900");
  expect(div.textContent).toContain("Terme masqué");
  expect(safeTerm("riz 50kg").masked).toBe(false);
  expect(safeTerm("0699123456").masked).toBe(true);
});

test("recherches : aucune donnée → état vide", async () => {
  reply[SEARCHES] = () => ({ status: 200, data: searchData({ total_searches: 0, total_without_results: 0, top_terms: [], no_result_terms: [] }) });
  server(FULL);
  const div = await mount("/recherches");
  expect(div.textContent).toContain("Aucune recherche sur cette période");
});

test("recherches : erreur réseau, 403 puis nouvel essai", async () => {
  reply[SEARCHES] = () => ({ status: 0, network: true });
  server(FULL);
  const div = await mount("/recherches");
  expect(div.querySelector("[role=alert]")?.textContent).toContain("Connexion impossible");
  reply[SEARCHES] = () => ({ status: 200, data: searchData() });
  await click(byText(div, "button", "Réessayer"));
  await wait();
  expect(div.textContent).toContain("riz");
  await cleanup();

  reply[SEARCHES] = () => ({ status: 403, data: { code: "permission_denied" } });
  const d2 = await mount("/recherches");
  expect(d2.querySelector("[role=alert]")?.textContent).toContain("Vous n'avez pas le droit");
  expect(d2.textContent).not.toContain("Termes les plus cherchés");
});

test("recherches : chargement affiché pendant la requête", async () => {
  reply[SEARCHES] = () => ({ status: 200, data: searchData() });
  server(FULL);
  const { gates } = await import("../auth/fakeServer");
  let release!: () => void;
  gates.set(SEARCHES, new Promise<void>((r) => (release = r)));
  const div = await mount("/recherches");
  expect(div.querySelector('[role=status][aria-label="Chargement"]')).not.toBeNull();
  release();
  await wait();
  expect(div.querySelector('[role=status][aria-label="Chargement"]')).toBeNull();
});

// ---------- Appels ----------
test("appels : par jour, opérateur, plateforme, canal ; chiffres écrits en texte", async () => {
  server(VALIDATEUR);
  const div = await mount("/appels");
  const page = main(div);
  expect(page.querySelector("h1")?.textContent).toBe("Appels");
  expect(page.querySelector('ul[aria-label="Appels par opérateur"]')?.textContent).toContain("Orange15");
  expect(page.querySelector('ul[aria-label="Appels par opérateur"]')?.textContent).toContain("MTN12");
  expect(page.querySelector('ul[aria-label="Appels par plateforme"]')?.textContent).toContain("Android25");
  expect(page.querySelector('ul[aria-label="Appels par plateforme"]')?.textContent).toContain("iOS5");
  expect(page.querySelector('ul[aria-label="Appels par canal"]')?.textContent).toContain("WhatsApp10");
  expect(page.querySelectorAll('[data-testid="calls-chart"] > div')).toHaveLength(3);
  expect(page.querySelector("table caption")?.textContent).toBe("Appels par jour");
  expect(page.querySelectorAll("tbody tr")).toHaveLength(3);
  expect(page.textContent).toContain("30 appels");
  expect(of(CALLS)[0]!.params).toEqual({ days: 7 });
});

test("appels : période, vide, 403, erreur réseau", async () => {
  server(FULL);
  const div = await mount("/appels");
  await pick(select(div, "Période"), "90");
  expect(of(CALLS).at(-1)!.params).toEqual({ days: 90 });
  await cleanup();

  reply[CALLS] = () => ({ status: 200, data: callData({ total_calls: 0 }) });
  expect((await mount("/appels")).textContent).toContain("Aucun appel sur cette période");
  await cleanup();

  reply[CALLS] = () => ({ status: 403 });
  expect((await mount("/appels")).querySelector("[role=alert]")?.textContent).toContain("Vous n'avez pas le droit");
  await cleanup();

  reply[CALLS] = () => ({ status: 0, network: true });
  expect((await mount("/appels")).querySelector("[role=alert]")?.textContent).toContain("Connexion impossible");
});

// ---------- Tendances ----------
test("tendances : choix de la ville, classement trié par rang, sans compteur ni lien", async () => {
  server(VALIDATEUR);
  const div = await mount("/tendances");
  expect(div.textContent).toContain("Choisissez une ville");
  expect(of(TRENDS)).toHaveLength(0);
  const sel = select(div, "Ville");
  expect(Array.from(sel.options).map((o) => o.textContent)).toEqual(["Choisir une ville", "Douala", "Yaoundé"]);
  await pick(sel, "1");
  expect(of(TRENDS)[0]!.params).toEqual({ zone: 1 });
  const page = main(div);
  const rows = Array.from(page.querySelectorAll("table")[0]!.querySelectorAll("tbody tr")).map((r) => r.textContent);
  expect(rows).toEqual(["1Riz", "2Savon"]);
  expect(page.textContent).toContain("Chez Awa");
  expect(page.textContent).toContain("Akwa");
  expect(page.textContent).toContain("sur 7 jours");
  expect(page.querySelectorAll("a, [role=link]")).toHaveLength(0);
  expect(page.textContent).not.toMatch(/\+237|\d{6}/);
});

test("tendances : ville sans calcul, 400, 403", async () => {
  reply[TRENDS] = () => ({ status: 200, data: trendData({ computed_at: null, period_days: null, products: [], businesses: [] }) });
  server(FULL);
  let div = await mount("/tendances");
  await pick(select(div, "Ville"), "3");
  expect(div.textContent).toContain("Aucun calcul de tendances pour cette ville");
  await cleanup();

  reply[TRENDS] = () => ({ status: 403, data: { code: "account_blocked" } });
  div = await mount("/tendances");
  await pick(select(div, "Ville"), "1");
  expect(div.querySelector("[role=alert]")?.textContent).toContain("Vous n'avez pas le droit");
  await cleanup();

  reply[TRENDS] = () => ({ status: 400, data: { code: "invalid" } });
  div = await mount("/tendances");
  await pick(select(div, "Ville"), "1");
  expect(div.querySelector("[role=alert]")?.textContent).toContain("Ville inconnue");
});

test("tendances : erreur réseau sur la liste des villes", async () => {
  reply[ZONES] = () => ({ status: 0, network: true });
  server(FULL);
  const div = await mount("/tendances");
  expect(div.querySelector("[role=alert]")?.textContent).toContain("liste des villes");
});

// ---------- Réglages : clés trends_* ----------
test("réglages : les 3 clés trends_* s'affichent et se modifient (bornes 1–1000, 1–1000, 1–90)", async () => {
  const s = (key: string, label: string, value: number, max: number) => ({ key, label, value, default: value, min: 1, max, modified_by: null, updated_at: null });
  reply[SETTINGS] = (c) =>
    c.method === "get"
      ? { status: 200, data: [s("trends_min_searches", "Tendances : recherches minimales", 5, 1000), s("trends_min_accounts", "Tendances : comptes distincts minimaux", 3, 1000), s("trends_window_days", "Tendances : fenêtre de calcul (jours)", 7, 90)] }
      : { status: 200, data: s("trends_window_days", "x", (c.body as { value: number }).value, 90) };
  server(FULL);
  const div = await mount("/reglages");
  for (const [k, text, v] of [["trends_min_searches", "recherches minimales", "5"], ["trends_min_accounts", "comptes distincts", "3"], ["trends_window_days", "fenêtre de calcul", "7"]] as const) {
    expect(div.querySelector(`[data-testid="setting-${k}"]`)?.textContent).toContain(text);
    expect(div.querySelector(`[data-testid="setting-value-${k}"]`)?.textContent).toBe(v);
  }
  const box = div.querySelector('[data-testid="setting-trends_window_days"]') as HTMLElement;
  expect(box.textContent).toContain("de 1 à 90");
  await type(box.querySelector("input")!, "91");
  await click(byText(box, "button", "Enregistrer"));
  expect(box.textContent).toContain("entre 1 et 90");
  expect(calls.filter((c) => c.url.startsWith(SETTINGS) && c.method !== "get")).toHaveLength(0);
  await type(box.querySelector("input")!, "14");
  await click(byText(box, "button", "Enregistrer"));
  await click(byText(document.querySelector("[role=dialog]")!, "button", "Enregistrer"));
  await wait();
  const w = calls.filter((c) => c.url.startsWith(SETTINGS) && c.method === "patch");
  expect(w).toHaveLength(1);
  expect(w[0]!.url).toBe(`${SETTINGS}trends_window_days/`);
  expect(w[0]!.body).toEqual({ value: 14 });
});
