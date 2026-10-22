import "./auth/fakeServer";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act } from "react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, expect, test } from "vitest";
import { AuthProvider } from "../src/auth/AuthProvider";
import { clearAccessToken } from "../src/auth/tokenStorage";
import { ThemeProvider } from "../src/components/theme/ThemeProvider";
import { ToastProvider } from "../src/components/ui/Toast";
import { AppRoutes } from "../src/routes";
import { byText, cleanup, click, render } from "./components/helpers";
import { calls, resetServer, setHandler, type Call, type Reply } from "./auth/fakeServer";

const FULL = [
  "peut_voir_demandes",
  "peut_voir_comptes",
  "peut_valider_demande",
  "peut_bloquer_compte",
  "peut_supprimer_compte",
  "peut_modifier_reglages",
  "peut_exporter",
  "peut_gerer_admins",
  "peut_accorder_abonnement",
  "peut_gerer_referentiels",
];
const VALIDATEUR = ["peut_voir_demandes", "peut_voir_comptes", "peut_valider_demande"];

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
  high_traffic_count: 0,
  high_traffic: [],
  revenue_month: { amount: 0, currency: "XAF", unavailable: true },
};

function server(permissions: string[], stats: Reply = { status: 200, data: STATS }) {
  const me = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return stats;
    if (c.url === "/api/auth/logout/") return { status: 204 };
    if (c.url === "/api/admin/requests/") return { status: 200, data: { count: 0, next: null, results: [] } };
    return { status: 404 };
  });
}

async function mount(path = "/") {
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
  // Laisse la session se restaurer et les requêtes (me, stats) se terminer.
  for (let i = 0; i < 3; i++) await act(async () => new Promise((r) => setTimeout(r, 15)));
  return div;
}

const labels = (div: HTMLElement) =>
  Array.from(div.querySelectorAll("nav > *")).map((e) => e.textContent ?? "");

beforeEach(() => {
  resetServer();
  clearAccessToken();
});
afterEach(cleanup);

test("Administrateur complet : toutes les entrées, pastille, nom, thème, déconnexion", async () => {
  server(FULL);
  const div = await mount("/");
  expect(div.querySelector("aside")?.textContent).toContain("Admin");
  const items = labels(div);
  expect(items).toHaveLength(5);
  expect(items[0]).toBe("Vue d'ensemble");
  expect(items[1]).toBe("Demandes7");
  expect(items[2]).toBe("Comptes");
  expect(items[3]).toBe("Référentiels");
  expect(items[4]).toContain("Équipe & abonnements");
  expect(div.querySelector('[data-testid="admin-name"]')?.textContent).toBe("Awa Test");
  expect(div.textContent).not.toContain("+237");
  expect(div.querySelector('[aria-label="Changer de thème"]')).not.toBeNull();
  expect(byText(div, "button", "Déconnexion")).not.toBeNull();
});

test("l'entrée active est mise en évidence", async () => {
  server(FULL);
  const div = await mount("/comptes");
  const active = div.querySelectorAll("nav a[aria-current='page']");
  expect(active).toHaveLength(1);
  expect(active[0]!.textContent).toBe("Comptes");
});

test("Équipe & abonnements : visible, désactivée, non cliquable, mention bientôt", async () => {
  server(FULL);
  const div = await mount("/");
  const team = div.querySelectorAll("nav > *")[4]!;
  expect(team.tagName).toBe("SPAN");
  expect(team.getAttribute("aria-disabled")).toBe("true");
  expect(team.textContent).toContain("bientôt");
  expect(team.getAttribute("href")).toBeNull();
});

test("Validateur : l'entrée réservée à l'Administrateur complet est masquée", async () => {
  server(VALIDATEUR);
  const div = await mount("/");
  expect(labels(div)).toEqual(["Vue d'ensemble", "Demandes7", "Comptes"]);
  expect(div.textContent).not.toContain("Équipe & abonnements");
});

test("sans aucune permission : aucune entrée et aucune requête de stats (refus par défaut)", async () => {
  server([]);
  const div = await mount("/");
  expect(labels(div)).toEqual([]);
  expect(calls.some((c) => c.url === "/api/admin/stats/")).toBe(false);
});

test("pastille masquée si 0", async () => {
  server(FULL, { status: 200, data: { ...STATS, pending_requests: 0 } });
  const div = await mount("/");
  expect(labels(div)[1]).toBe("Demandes");
});

test("pastille masquée, sans message, si les stats échouent", async () => {
  server(FULL, { status: 500 });
  const div = await mount("/");
  expect(labels(div)[1]).toBe("Demandes");
  expect(div.querySelector('aside [role="alert"]')).toBeNull(); // la pastille échoue en silence (la page affiche son propre message)
});

test("page protégée : un Validateur n'ouvre pas /equipe", async () => {
  server(VALIDATEUR);
  const div = await mount("/equipe");
  expect(div.querySelector('[role="alert"]')?.textContent).toContain("Accès refusé");
});

test("sans permission : /comptes, /demandes et / affichent « Accès refusé » sans aucune requête de données", async () => {
  for (const path of ["/comptes", "/demandes", "/"]) {
    resetServer();
    server([]);
    const div = await mount(path);
    expect(div.querySelector('[role="alert"]')?.textContent).toContain("Accès refusé");
    expect(calls.filter((c) => c.url.startsWith("/api/admin/") && c.url !== "/api/admin/me/")).toEqual([]);
    await cleanup();
  }
});

test("Comptes a sa vraie page depuis T083 (plus de page provisoire)", async () => {
  server(FULL);
  const div = await mount("/comptes");
  expect(div.textContent).not.toContain("Cette page arrive bientôt.");
  expect(div.querySelector("header h2")?.textContent).toBe("Comptes");
  expect(div.querySelector("main")?.textContent).toContain("Impossible de charger les comptes.");
});

test("Déconnexion appelle le serveur et ramène à la connexion", async () => {
  server(FULL);
  const div = await mount("/");
  await click(byText(div, "button", "Déconnexion"));
  expect(calls.some((c) => c.url === "/api/auth/logout/" && c.method === "post")).toBe(true);
  expect(div.querySelector("aside")).toBeNull();
});
