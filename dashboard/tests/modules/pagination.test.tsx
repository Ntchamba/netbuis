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
import { calls, resetServer, setHandler, type Call, type Reply } from "../auth/fakeServer";
import { byText, cleanup, click, render } from "../components/helpers";

// Données FICTIVES. Le faux serveur répond comme DRF : 404 pour une page hors limites (page > 1).
const SIZE = 20;
const PERMS = ["peut_voir_comptes", "peut_voir_demandes", "peut_valider_demande", "peut_gerer_admins", "peut_modifier_reglages", "peut_gerer_referentiels"];
const ISO = "2026-10-20T10:30:00Z";

let total: number;
let qc: QueryClient;

const request = (id: number) => ({
  id, type: "business", type_compte: "boutique", name: `Commerce Test ${id}`, status: "en_attente_validation", owner_id: 100 + id,
  owner_name: `Propriétaire ${id}`, phone_masked: "+237 6•• •• •• 41", zone: 1, zone_name: "Quartier Test", repere: "", description: "",
  representant_nom: "", forme_juridique: "", rccm: "", categorie_service: null, categorie_service_name: null, categorie_service_libre: "",
  cni_verifiee: false, photo_url: null, representant_photo_url: null, cni_url: null, diplome_url: null, created_at: ISO,
});
const account = (id: number) => ({
  id, name: `Compte ${id}`, phone_masked: "+237 6•• •• •• 41", type: "simple", status: "actif", is_admin: false, is_blocked: false,
  is_deleted: false, business_name: null, business_status: null, zone_id: null, zone_name: null, created_at: ISO,
});
const audit = (id: number) => ({
  id, admin_id: 1, admin_name: "Awa Test", action: "blocage_compte", action_label: "Blocage d'un compte", target_type: "accounts.user",
  target_id: id, reason: "Motif fictif", created_at: ISO,
});
const sector = (id: number) => ({ id, code: `code_${id}`, name: `Secteur ${id}`, icon: "", order: id, is_active: true, updated_at: ISO });

const ROWS: Record<string, (id: number) => unknown> = {
  "/api/admin/requests/": request,
  "/api/admin/accounts/": account,
  "/api/admin/audit/": audit,
  "/api/admin/referentials/sectors/": sector,
};

function page(c: Call): Reply {
  const p = Number(c.params?.page ?? 1);
  const last = Math.max(1, Math.ceil(total / SIZE));
  if (p > last) return { status: 404, data: { detail: "Invalid page." } };
  const ids = Array.from({ length: total }, (_, i) => i + 1).slice((p - 1) * SIZE, p * SIZE);
  return { status: 200, data: { count: total, next: null, results: ids.map(ROWS[c.url]!) } };
}

function server() {
  const me = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions: PERMS };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return { status: 200, data: { pending_requests: total } };
    if (c.url === "/api/zones/") return { status: 200, data: { count: 0, next: null, results: [] } };
    if (c.url === "/api/admin/admins/") return { status: 200, data: { count: 0, next: null, results: [] } };
    if (c.method === "get" && ROWS[c.url]) return page(c);
    if (c.method === "post" && /^\/api\/admin\/requests\/\d+\/approve\/$/.test(c.url)) {
      total -= 1; // la demande est traitée : elle sort de la file
      return { status: 200, data: { id: 1, status: "actif", cni_verifiee: false, motif_rejet: "" } };
    }
    return { status: 404 };
  });
}

async function wait(n = 4) {
  for (let i = 0; i < n; i++) await act(async () => new Promise((r) => setTimeout(r, 15)));
}

async function mount(path: string) {
  qc = new QueryClient();
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
  return div;
}

const gets = (url: string) => calls.filter((c) => c.method === "get" && c.url === url);

beforeEach(() => {
  resetServer();
  clearAccessToken();
  server();
});
afterEach(cleanup);

test("demandes : valider la dernière demande de la dernière page → page précédente, carte traitée disparue", async () => {
  total = 21;
  const div = await mount("/demandes");
  await click(byText(div, "button", "Suivant"));
  await wait();
  expect(div.textContent).toContain("Page 2 sur 2");
  expect(div.textContent).toContain("Commerce Test 21");
  await click(byText(div, "button", "Valider"));
  await wait(8);
  expect(div.textContent).not.toContain("Commerce Test 21");
  expect(div.textContent).not.toMatch(/Page \d+ sur/); // une seule page : pagination masquée
  expect(div.textContent).toContain("Commerce Test 1");
  expect(Array.from(div.querySelectorAll("button")).filter((b) => b.textContent === "Valider").length).toBe(20);
  expect(gets("/api/admin/requests/").length).toBeLessThan(8); // pas de boucle de requêtes
});

test("demandes : 404 de page hors limites → recul jusqu'à une page valide, sans boucle infinie", async () => {
  total = 61; // 4 pages
  const div = await mount("/demandes");
  for (let i = 0; i < 3; i++) {
    await click(byText(div, "button", "Suivant"));
    await wait();
  }
  expect(div.textContent).toContain("Page 4 sur 4");
  total = 25; // le total chute : les pages 3 et 4 n'existent plus
  await act(async () => {
    await qc.invalidateQueries({ queryKey: ["admin", "requests"] });
  });
  await wait(10);
  expect(div.textContent).toContain("Page 2 sur 2");
  expect(div.textContent).not.toContain("Commerce Test 61");
  expect(div.textContent).toContain("Commerce Test 25");
  const before = gets("/api/admin/requests/").length;
  await wait(10);
  expect(gets("/api/admin/requests/").length).toBe(before); // stable : plus aucune requête
  expect(before).toBeLessThan(14);
});

test.each([
  ["comptes", "/comptes", "/api/admin/accounts/", "Compte 21", "Compte 1"],
  ["audit", "/audit", "/api/admin/audit/", "Blocage d'un compte", "Blocage d'un compte"],
  ["référentiels", "/referentiels/sectors", "/api/admin/referentials/sectors/", "Secteur 21", "Secteur 1"],
])("%s : page hors limites (404) après baisse du total → retour page 1, ligne disparue", async (_n, path, url, gone, kept) => {
  total = 21;
  const div = await mount(path);
  await click(byText(div, "button", "Suivant"));
  await wait();
  expect(div.textContent).toContain("Page 2 sur 2");
  if (gone.startsWith("Compte") || gone.startsWith("Secteur")) expect(div.textContent).toContain(gone);
  total = 20;
  await act(async () => {
    await qc.invalidateQueries();
  });
  await wait(10);
  expect(div.textContent).not.toMatch(/Page \d+ sur/); // une seule page : pagination masquée
  if (gone.startsWith("Compte") || gone.startsWith("Secteur")) expect(div.textContent).not.toContain(gone);
  expect(div.textContent).toContain(kept);
  expect(div.querySelector('[role="alert"]')).toBeNull(); // pas de message d'erreur affiché
  const n = gets(url).length;
  await wait(10);
  expect(gets(url).length).toBe(n);
  expect(n).toBeLessThan(8);
});

test("une vraie erreur (500) sur la page 1 reste affichée avec Réessayer (pas de recul)", async () => {
  total = 5;
  const base = (await import("../auth/fakeServer")).handler;
  setHandler((c) => (c.url === "/api/admin/accounts/" ? { status: 500 } : base(c)));
  const div = await mount("/comptes");
  expect(div.querySelector('[role="alert"]')!.textContent).toContain("Impossible de charger les comptes");
});
