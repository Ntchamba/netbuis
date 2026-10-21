import "./auth/fakeServer";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act } from "react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, expect, test } from "vitest";
import { AuthProvider } from "../src/auth/AuthProvider";
import { clearAccessToken } from "../src/auth/tokenStorage";
import { ThemeProvider } from "../src/components/theme/ThemeProvider";
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

function server(permissions: string[], stats: Reply = { status: 200, data: { pending_requests: 7 } }) {
  const me = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return stats;
    if (c.url === "/api/auth/logout/") return { status: 204 };
    return { status: 404 };
  });
}

async function mount(path = "/") {
  const qc = new QueryClient();
  const div = await render(
    <QueryClientProvider client={qc}>
      <ThemeProvider>
        <MemoryRouter initialEntries={[path]}>
          <AuthProvider>
            <AppRoutes />
          </AuthProvider>
        </MemoryRouter>
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
  expect(items).toHaveLength(4);
  expect(items[0]).toBe("Vue d'ensemble");
  expect(items[1]).toBe("Demandes7");
  expect(items[2]).toBe("Comptes");
  expect(items[3]).toContain("Équipe & abonnements");
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
  const team = div.querySelectorAll("nav > *")[3]!;
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
  server(FULL, { status: 200, data: { pending_requests: 0 } });
  const div = await mount("/");
  expect(labels(div)[1]).toBe("Demandes");
});

test("pastille masquée, sans message, si les stats échouent", async () => {
  server(FULL, { status: 500 });
  const div = await mount("/");
  expect(labels(div)[1]).toBe("Demandes");
  expect(div.querySelector('[role="alert"]')).toBeNull();
});

test("page protégée : un Validateur n'ouvre pas /equipe", async () => {
  server(VALIDATEUR);
  const div = await mount("/equipe");
  expect(div.querySelector('[role="alert"]')?.textContent).toContain("Accès refusé");
});

test("pages provisoires lisibles pour Demandes", async () => {
  server(FULL);
  const div = await mount("/demandes");
  expect(div.textContent).toContain("Cette page arrive bientôt.");
  expect(div.querySelector("header h2")?.textContent).toBe("Demandes en attente");
});

test("Déconnexion appelle le serveur et ramène à la connexion", async () => {
  server(FULL);
  const div = await mount("/");
  await click(byText(div, "button", "Déconnexion"));
  expect(calls.some((c) => c.url === "/api/auth/logout/" && c.method === "post")).toBe(true);
  expect(div.querySelector("aside")).toBeNull();
});
