import "../auth/fakeServer";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act } from "react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, expect, test } from "vitest";
import { AuthProvider } from "../../src/auth/AuthProvider";
import { clearAccessToken } from "../../src/auth/tokenStorage";
import { ThemeProvider } from "../../src/components/theme/ThemeProvider";
import { formatRelative } from "../../src/lib/dates";
import { formatInt } from "../../src/lib/format";
import { AppRoutes } from "../../src/routes";
import { calls, resetServer, setHandler, type Call, type Reply } from "../auth/fakeServer";
import { byText, cleanup, click, render } from "../components/helpers";

const STATS = {
  accounts_total: 4812,
  accounts_new_week: 96,
  active_businesses: 612,
  neighborhoods_covered: 9,
  pending_requests: 7,
  calls_week: 300,
  searches_week: 900,
  subscribers: 86,
  subscription_threshold: 10,
  high_traffic_count: 12,
  high_traffic: [
    { id: 1, name: "Boutique Test A", calls_per_day: 17 },
    { id: 2, name: "Atelier Test B", calls_per_day: 13 },
  ],
  revenue_month: { amount: 0, currency: "XAF", unavailable: true },
};
const ago = (h: number) => new Date(Date.now() - h * 3_600_000).toISOString();
const REQUESTS = {
  count: 3,
  next: null,
  results: [
    { id: 1, name: "Ancienne Demande", status: "en_attente_validation", zone_name: "Quartier Un", created_at: ago(50) },
    { id: 2, name: "Demande Récente", status: "en_attente_validation", zone_name: "Quartier Deux", created_at: ago(2) },
    { id: 3, name: "Demande Moyenne", status: "en_attente_validation", zone_name: "", created_at: ago(5) },
  ],
};

let statsReply: Reply;
let requestsReply: Reply;

function server(permissions: string[]) {
  const me = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return statsReply;
    if (c.url === "/api/admin/requests/") return requestsReply;
    return { status: 404 };
  });
}

async function mount(path = "/") {
  const div = await render(
    <QueryClientProvider client={new QueryClient()}>
      <ThemeProvider>
        <MemoryRouter initialEntries={[path]}>
          <AuthProvider>
            <AppRoutes />
          </AuthProvider>
        </MemoryRouter>
      </ThemeProvider>
    </QueryClientProvider>,
  );
  for (let i = 0; i < 4; i++) await act(async () => new Promise((r) => setTimeout(r, 15)));
  return div;
}

const BOTH = ["peut_voir_demandes", "peut_voir_comptes"];

beforeEach(() => {
  resetServer();
  clearAccessToken();
  statsReply = { status: 200, data: STATS };
  requestsReply = { status: 200, data: REQUESTS };
});
afterEach(cleanup);

test("quatre cartes, revenus en tiret avec la mention, un seul h1", async () => {
  server(BOTH);
  const div = await mount("/");
  const text = div.textContent ?? "";
  expect(text).toContain(`Comptes au total${formatInt(4812)}+96 cette semaine`);
  expect(text).toContain("Comptes business actifs");
  expect(text).toContain("dans 9 quartiers");
  expect(text).toContain("Demandes en attente");
  expect(text).toContain("Revenus du mois—paiements non activés");
  expect(text).not.toContain("0 FCFA");
  expect(formatInt(4812)).toMatch(/^4\s812$/);
  expect(div.querySelectorAll("h1")).toHaveLength(1);
});

test("revenus disponibles : montant formaté", async () => {
  statsReply = { status: 200, data: { ...STATS, revenue_month: { amount: 184300, currency: "XAF", unavailable: false } } };
  server(BOTH);
  const div = await mount("/");
  expect(div.textContent).toMatch(/184\s300\s(FCFA)/);
});

test("demandes récentes : plus récentes d'abord, lien vers /demandes, pas de numéro", async () => {
  server(BOTH);
  const div = await mount("/");
  const items = Array.from(div.querySelectorAll("section ul li")).map((e) => e.textContent ?? "");
  const idx = (n: string) => items.findIndex((t) => t.includes(n));
  expect(idx("Demande Récente")).toBeLessThan(idx("Demande Moyenne"));
  expect(idx("Demande Moyenne")).toBeLessThan(idx("Ancienne Demande"));
  expect(items.some((t) => t.includes("il y a 2 h") && t.includes("Quartier Deux"))).toBe(true);
  expect(div.querySelector('main a[href="/demandes"]')?.textContent).toBe("Voir tout →");
  expect(div.textContent).not.toContain("+237 6");
});

test("sans peut_voir_demandes : demandes récentes non demandées", async () => {
  server(["peut_voir_comptes"]);
  const div = await mount("/");
  expect(calls.some((c) => c.url === "/api/admin/requests/")).toBe(false);
  expect(div.textContent).not.toContain("Demandes récentes");
  expect(div.textContent).toContain("Comptes au total");
});

test("abonnements, fort trafic (nom + appels par jour), équipe à venir", async () => {
  server(BOTH);
  const div = await mount("/");
  const text = div.textContent ?? "";
  expect(text).toContain("comptes abonnés sur 612 actifs (14");
  expect(text).toContain("Seuil d'abonnement : 10 appels par jour");
  expect(text).toContain("Boutique Test A");
  expect(text).toContain("17 appels/jour");
  expect(text).toContain("et 10 autres comptes");
  expect(text).toContain("Performance équipe NetBuis");
  expect(text).toContain("Fonction à venir");
});

test("chargement : squelettes tant que les stats ne sont pas arrivées", async () => {
  server(BOTH);
  const { gates } = await import("../auth/fakeServer");
  let open!: () => void;
  gates.set("/api/admin/stats/", new Promise<void>((r) => (open = r)));
  const div = await mount("/");
  expect(div.querySelector('[data-testid="overview-skeleton"]')).not.toBeNull();
  expect(div.textContent).not.toContain("Comptes au total");
  await act(async () => open());
  await act(async () => new Promise((r) => setTimeout(r, 15)));
  expect(div.querySelector('[data-testid="overview-skeleton"]')).toBeNull();
});

test("erreur : message et Réessayer relance la requête", async () => {
  statsReply = { status: 500 };
  server(BOTH);
  const div = await mount("/");
  expect(div.querySelector('main [role="alert"]')?.textContent).toContain("Impossible de charger les chiffres.");
  const before = calls.filter((c) => c.url === "/api/admin/stats/").length;
  statsReply = { status: 200, data: STATS };
  await click(byText(div, "button", "Réessayer"));
  await act(async () => new Promise((r) => setTimeout(r, 30)));
  expect(calls.filter((c) => c.url === "/api/admin/stats/").length).toBeGreaterThan(before);
  expect(div.textContent).toContain("Comptes au total");
});

test("erreur des demandes récentes : message local et Réessayer, le reste reste affiché", async () => {
  requestsReply = { status: 500 };
  server(BOTH);
  const div = await mount("/");
  expect(div.textContent).toContain("Impossible de charger les demandes.");
  expect(div.textContent).toContain("Comptes au total");
});

test("dates relatives", () => {
  const now = new Date("2026-10-21T12:00:00Z");
  expect(formatRelative("2026-10-21T11:59:30Z", now)).toBe("à l'instant");
  expect(formatRelative("2026-10-21T11:30:00Z", now)).toBe("il y a 30 min");
  expect(formatRelative("2026-10-20T10:00:00Z", now)).toBe("il y a 1 j");
  expect(formatRelative("2026-10-01T23:30:00Z", now)).toContain("2 octobre 2026"); // 00 h 30 à Douala (UTC+1)
});

// --- Cas limites de « Demandes récentes » et du pourcentage d'abonnés ---

function req(i: number, hoursAgo: number) {
  return { id: i, name: `Demande ${i}`, status: "en_attente_validation", zone_name: "Quartier", created_at: ago(hoursAgo) };
}

/** Faux serveur paginé (50 par page, plus ancien d'abord). */
function paged(total: number) {
  const all = Array.from({ length: total }, (_, i) => req(i + 1, total - i)); // i+1 = rang, plus grand = plus récent
  server(BOTH);
  const base = requestsReply;
  void base;
  const me = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions: BOTH };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return statsReply;
    if (c.url === "/api/admin/requests/") {
      const n = Number(c.params?.page ?? 1);
      const results = all.slice((n - 1) * 50, n * 50);
      return { status: 200, data: { count: total, next: n * 50 < total ? "suivant" : null, results } };
    }
    return { status: 404 };
  });
}
const shown = (div: HTMLElement) =>
  Array.from(div.querySelectorAll("section ul")).filter((u) => u.parentElement?.textContent?.includes("Demandes récentes")).flatMap((u) => Array.from(u.querySelectorAll("li"))).map((e) => e.textContent ?? "");

test("0 demande : état vide", async () => {
  requestsReply = { status: 200, data: { count: 0, next: null, results: [] } };
  server(BOTH);
  const div = await mount("/");
  expect(div.textContent).toContain("Aucune demande en attente");
});

test("51 demandes : la dernière page n'a qu'un élément, 5 lignes affichées (3 requêtes)", async () => {
  paged(51);
  const div = await mount("/");
  const items = shown(div);
  expect(items).toHaveLength(5);
  expect(items[0]).toContain("Demande 51");
  expect(items[4]).toContain("Demande 47");
  expect(calls.filter((c) => c.url === "/api/admin/requests/")).toHaveLength(3);
});

test("plus de 100 demandes : les 5 plus récentes", async () => {
  paged(130);
  const div = await mount("/");
  const items = shown(div);
  expect(items).toHaveLength(5);
  expect(items[0]).toContain("Demande 130");
  expect(items[4]).toContain("Demande 126");
});

test("échec de la 2e requête : erreur locale avec Réessayer, reste de la page affiché", async () => {
  paged(51);
  const inner = (await import("../auth/fakeServer")).handler;
  setHandler((c) => (c.url === "/api/admin/requests/" && c.params?.page === 2 ? { status: 500 } : inner(c)));
  const div = await mount("/");
  expect(div.textContent).toContain("Impossible de charger les demandes.");
  expect(byText(div, "button", "Réessayer")).not.toBeNull();
  expect(div.textContent).toContain("Comptes au total");
});

test("0 business actif : pas de NaN ni d'Infinity", async () => {
  statsReply = { status: 200, data: { ...STATS, active_businesses: 0, subscribers: 0 } };
  server(BOTH);
  const div = await mount("/");
  expect(div.textContent).toContain("sur 0 actifs (0");
  expect(div.textContent).not.toMatch(/NaN|Infinity/);
});
