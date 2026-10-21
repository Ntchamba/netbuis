import "../auth/fakeServer";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act } from "react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { AuthProvider } from "../../src/auth/AuthProvider";
import { clearAccessToken } from "../../src/auth/tokenStorage";
import { ThemeProvider } from "../../src/components/theme/ThemeProvider";
import { ToastProvider } from "../../src/components/ui/Toast";
import { AppRoutes } from "../../src/routes";
import { calls, gates, resetServer, setHandler, type Call, type Reply } from "../auth/fakeServer";
import { byText, cleanup, click, render, type } from "../components/helpers";

// Numéros FICTIFS.
const FULL_PHONE = "+237 600 00 00 41";
const MASKED = "+237 6•• •• •• 41";
const SIGNED_CNI = "/api/admin/private-files/jeton-cni-fictif/";
const ago = (h: number) => new Date(Date.now() - h * 3_600_000).toISOString();

function account(id: number, over: Record<string, unknown> = {}) {
  return {
    id,
    name: `Compte ${id}`,
    phone_masked: MASKED,
    type: "simple",
    status: "actif",
    is_admin: false,
    is_blocked: false,
    is_deleted: false,
    business_name: null,
    business_status: null,
    zone_id: null,
    zone_name: null,
    created_at: ago(30),
    ...over,
  };
}

function detail(id: number, over: Record<string, unknown> = {}) {
  return {
    ...account(id, { type: "business", business_name: "Boutique Test", business_status: "actif", zone_id: 5, zone_name: "Quartier Test" }),
    phone: FULL_PHONE,
    language: "fr",
    blocked_reason: "",
    blocked_at: null,
    deleted_at: null,
    roles: [],
    business: {
      id: 9,
      type: "business",
      type_compte: "prestataire_service",
      name: "Boutique Test",
      status: "actif",
      owner_id: id,
      owner_name: "Propriétaire",
      phone_masked: MASKED,
      zone: 5,
      zone_name: "Quartier Test",
      repere: "Près du marché",
      description: "Vente de tissus",
      representant_nom: "",
      forme_juridique: "",
      rccm: "",
      categorie_service: null,
      categorie_service_name: null,
      categorie_service_libre: "",
      cni_verifiee: true,
      photo_url: null,
      representant_photo_url: null,
      cni_url: SIGNED_CNI,
      diplome_url: null,
      created_at: ago(40),
    },
    status_history: [{ action: "blocage_compte", label: "Compte bloqué", reason: "Fausse annonce répétée", admin_id: 2, admin_name: "Admin Un", created_at: ago(20) }],
    recent_audit: [{ action: "consultation_numero", label: "Numéro consulté", reason: "", admin_id: 2, admin_name: "Admin Un", created_at: ago(1) }],
    ...over,
  };
}

const ZONES = [
  { id: 5, name: "Quartier Test", level: "quartier", parent: 2 },
  { id: 2, name: "Ville Test", level: "ville_village", parent: null },
];

let list: unknown[];
let total: number;
let detailReply: Reply;
let action: (c: Call) => Reply;
let fileReply: Reply;

function server(permissions: string[]) {
  const me = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return { status: 200, data: { pending_requests: 0 } };
    if (c.url === "/api/admin/requests/") return { status: 200, data: { count: 0, next: null, results: [] } };
    if (c.url === "/api/zones/") {
      const level = c.params?.level;
      return { status: 200, data: { count: 1, next: null, results: ZONES.filter((z) => z.level === level) } };
    }
    if (c.url === "/api/admin/accounts/" && c.method === "get") return { status: 200, data: { count: total, next: null, results: list } };
    if (c.url.startsWith("/api/admin/private-files/")) return fileReply;
    if (/^\/api\/admin\/accounts\/\d+\/$/.test(c.url) && c.method === "get") return detailReply;
    if (c.url.startsWith("/api/admin/accounts/")) return action(c);
    return { status: 404 };
  });
}

async function wait(n = 4) {
  for (let i = 0; i < n; i++) await act(async () => new Promise((r) => setTimeout(r, 15)));
}

let qc: QueryClient;
async function mount(path = "/comptes") {
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

const FULL = ["peut_voir_comptes", "peut_voir_demandes", "peut_bloquer_compte", "peut_supprimer_compte"];
const VALIDATEUR = ["peut_voir_comptes", "peut_voir_demandes", "peut_valider_demande"];
const listCalls = () => calls.filter((c) => c.url === "/api/admin/accounts/" && c.method === "get");
const lastList = () => listCalls().at(-1)!;
const textarea = () => document.querySelector("[role=dialog] textarea") as HTMLTextAreaElement;
const dialogButton = (label: string) => byText(document.querySelector("[role=dialog]")!, "button", label) as HTMLButtonElement;
const row = (div: HTMLElement, id: number) => div.querySelector(`[data-testid="account-row-${id}"]`) as HTMLElement;

beforeEach(() => {
  resetServer();
  clearAccessToken();
  localStorage.clear();
  sessionStorage.clear();
  list = [account(1, { name: "Jeff N.", zone_name: "Hardé" }), account(2, { type: "business", business_name: "Boutique Mama", status: "bloque", is_blocked: true }), account(3, { status: "supprime", is_deleted: true })];
  total = 3;
  detailReply = { status: 200, data: detail(7) };
  action = () => ({ status: 200, data: { id: 1, status: "bloque", is_blocked: true, is_deleted: false, blocked_reason: "x", deleted_at: null } });
  fileReply = { status: 200, data: new Blob(["image-fictive"], { type: "image/png" }) };
  let n = 0;
  URL.createObjectURL = () => `blob:test/${++n}`;
  URL.revokeObjectURL = () => {};
});
afterEach(async () => {
  await cleanup();
  vi.restoreAllMocks();
});

test("tableau : colonnes de la maquette, numéro masqué seulement, filtres, Équipe non cliquable", async () => {
  server(FULL);
  const div = await mount();
  const main = div.querySelector("main")!;
  expect(Array.from(main.querySelectorAll("th")).map((t) => t.textContent)).toEqual(["NOM", "TÉLÉPHONE", "TYPE", "ZONE", "STATUT", "ACTIONS"]);
  expect(main.textContent).toContain("Jeff N.");
  expect(main.textContent).toContain("Boutique Mama");
  expect(main.textContent).toContain(MASKED);
  expect(main.textContent).not.toMatch(/\+237 6\d/);
  expect(row(div, 1).textContent).toContain("Simple");
  expect(row(div, 1).textContent).toContain("Actif");
  expect(row(div, 2).textContent).toContain("Business");
  expect(row(div, 2).textContent).toContain("Bloqué");
  expect(row(div, 3).textContent).toContain("Supprimé");
  const filters = Array.from(main.querySelectorAll('[aria-label="Filtrer par type"] button')).map((b) => b.textContent);
  expect(filters).toEqual(["Tous", "Simple", "Business", "Bloqués", "Supprimés", "Équipe NetBuis (bientôt)"]);
  const equipe = main.querySelector('[aria-label="Filtrer par type"] button:last-child') as HTMLButtonElement;
  expect(equipe.disabled).toBe(true);
  const before = listCalls().length;
  await click(equipe);
  await wait(2);
  expect(listCalls().length).toBe(before);
  expect(lastList().params).toEqual({ page: 1, page_size: 20 });
});

test("actions par ligne : Bloquer/Supprimer, Débloquer/Supprimer, Restaurer seul pour un supprimé", async () => {
  server(FULL);
  const div = await mount();
  const labels = (id: number) => Array.from(row(div, id).querySelectorAll("button")).map((b) => b.textContent || b.getAttribute("aria-label"));
  expect(labels(1)).toEqual(["Bloquer", "Supprimer"]);
  expect(labels(2)).toEqual(["Débloquer", "Supprimer"]);
  expect(labels(3)).toEqual(["Restaurer"]);
});

test("filtres : chaque filtre envoie le bon type au serveur et revient à la page 1", async () => {
  server(FULL);
  total = 45;
  const div = await mount();
  await click(byText(div, "button", "Suivant"));
  await wait(2);
  expect(lastList().params).toMatchObject({ page: 2 });
  for (const [label, type] of [["Simple", "simple"], ["Business", "business"], ["Bloqués", "blocked"], ["Supprimés", "deleted"]]) {
    await click(byText(div, "button", label));
    await wait(2);
    expect(lastList().params).toEqual({ type, page: 1, page_size: 20 });
    expect(byText(div, "button", label)!.getAttribute("aria-pressed")).toBe("true");
  }
  await click(byText(div, "button", "Tous"));
  await wait(2);
  expect(lastList().params).toEqual({ page: 1, page_size: 20 });
});

test("zone : liste alimentée par l'API des zones, filtre envoyé", async () => {
  server(FULL);
  const div = await mount();
  expect(calls.filter((c) => c.url === "/api/zones/").map((c) => c.params?.level)).toEqual(["ville_village", "quartier"]);
  const select = div.querySelector('select[aria-label="Zone"]') as HTMLSelectElement;
  expect(Array.from(select.options).map((o) => o.textContent)).toEqual(["Toutes les zones", "Quartier Test (quartier)", "Ville Test (ville)"]);
  await act(async () => {
    select.value = "5";
    select.dispatchEvent(new Event("change", { bubbles: true }));
  });
  await wait(2);
  expect(lastList().params).toMatchObject({ zone: 5, page: 1 });
});

test("recherche : envoyée après une pause, trimée, revient à la page 1, pas dans l'adresse ni le stockage", async () => {
  server(FULL);
  const setItem = vi.spyOn(Storage.prototype, "setItem");
  const div = await mount();
  const input = div.querySelector('input[aria-label="Rechercher un compte"]') as HTMLInputElement;
  await type(input, "  Mama ");
  const before = listCalls().length;
  expect(listCalls().length).toBe(before); // pas encore envoyée
  await act(async () => new Promise((r) => setTimeout(r, 400)));
  await wait(2);
  expect(lastList().params).toEqual({ q: "Mama", page: 1, page_size: 20 });
  expect(listCalls().length).toBe(before + 1);
  expect(setItem).not.toHaveBeenCalled();
  await type(input, "   ");
  await act(async () => new Promise((r) => setTimeout(r, 400)));
  await wait(2);
  expect(lastList().params).toEqual({ page: 1, page_size: 20 });
});

test("pagination : 45 comptes = 3 pages, « Suivant » demande la page 2", async () => {
  server(FULL);
  total = 45;
  const div = await mount();
  expect(div.textContent).toContain("Page 1 sur 3");
  await click(byText(div, "button", "Suivant"));
  await wait(2);
  expect(lastList().params).toMatchObject({ page: 2 });
  expect(div.textContent).toContain("Page 2 sur 3");
});

test("états : vide, chargement (squelette), erreur avec Réessayer", async () => {
  server(FULL);
  list = [];
  total = 0;
  let div = await mount();
  expect(div.querySelector("main")!.textContent).toContain("Aucun compte");
  await cleanup();

  resetServer();
  server(FULL);
  const { handler } = await import("../auth/fakeServer");
  const base = handler;
  let fail = true;
  setHandler((c) => (c.url === "/api/admin/accounts/" && fail ? { status: 500 } : base(c)));
  div = await mount();
  expect(div.querySelector("main [role=alert]")?.textContent).toContain("Impossible de charger les comptes.");
  fail = false;
  list = [account(1)];
  total = 1;
  await click(byText(div, "button", "Réessayer"));
  await wait();
  expect(div.querySelector("main")!.textContent).toContain("Compte 1");

  await cleanup();
  resetServer();
  server(FULL);
  let open!: () => void;
  gates.set("/api/admin/accounts/", new Promise<void>((r) => (open = r)));
  div = await mount();
  expect(div.querySelector("[data-loading-row]")).not.toBeNull();
  await act(async () => open());
  await wait();
  expect(div.querySelector("[data-loading-row]")).toBeNull();
});

test("Bloquer sans motif impossible ; avec motif : POST du motif, toast, liste rechargée", async () => {
  server(FULL);
  const div = await mount();
  await click(byText(row(div, 1), "button", "Bloquer"));
  expect(document.querySelector("[role=dialog]")!.textContent).toContain("Bloquer le compte");
  expect(dialogButton("Bloquer").disabled).toBe(true);
  await type(textarea(), "    ");
  expect(dialogButton("Bloquer").disabled).toBe(true);
  await click(dialogButton("Bloquer"));
  await wait(2);
  expect(calls.some((c) => c.url.includes("/block/"))).toBe(false);

  await type(textarea(), "  Fausses annonces  ");
  const before = listCalls().length;
  list = [account(1, { status: "bloque", is_blocked: true })];
  await click(dialogButton("Bloquer"));
  await wait();
  const post = calls.find((c) => c.method === "post" && c.url === "/api/admin/accounts/1/block/");
  expect(post?.body).toEqual({ reason: "Fausses annonces" });
  expect(post?.auth).toBe("Bearer jeton-fictif");
  expect(document.querySelector("[role=dialog]")).toBeNull();
  expect(document.body.textContent).toContain("Compte bloqué");
  expect(listCalls().length).toBeGreaterThan(before);
  expect(row(div, 1).textContent).toContain("Bloqué");
  expect(byText(row(div, 1), "button", "Débloquer")).not.toBeNull();
});

test("motifs trop longs non envoyés (255 pour bloquer, 1000 pour supprimer)", async () => {
  server(FULL);
  const div = await mount();
  await click(byText(row(div, 1), "button", "Bloquer"));
  await type(textarea(), "x".repeat(256));
  await click(dialogButton("Bloquer"));
  await wait(2);
  expect(document.body.textContent).toContain("Le motif est trop long (255");
  expect(calls.some((c) => c.url.includes("/block/"))).toBe(false);
  await click(dialogButton("Annuler"));
  await click(row(div, 1).querySelector('[aria-label="Supprimer"]'));
  await type(textarea(), "x".repeat(1001));
  await click(dialogButton("Supprimer"));
  await wait(2);
  expect(document.body.textContent).toContain("Le motif est trop long (1000");
  expect(calls.some((c) => c.method === "delete")).toBe(false);
});

test("Supprimer : motif obligatoire, DELETE avec le motif dans le corps", async () => {
  server(FULL);
  const div = await mount();
  await click(row(div, 1).querySelector('[aria-label="Supprimer"]'));
  expect(dialogButton("Supprimer").disabled).toBe(true);
  await type(textarea(), "Demande du titulaire");
  await click(dialogButton("Supprimer"));
  await wait();
  const del = calls.find((c) => c.method === "delete");
  expect(del?.url).toBe("/api/admin/accounts/1/");
  expect(del?.body).toEqual({ reason: "Demande du titulaire" });
  expect(document.body.textContent).toContain("Compte supprimé");
});

test("Débloquer et Restaurer : confirmation simple sans motif", async () => {
  server(FULL);
  const div = await mount();
  await click(byText(row(div, 2), "button", "Débloquer"));
  expect(document.querySelector("[role=dialog] textarea")).toBeNull();
  await click(dialogButton("Débloquer"));
  await wait();
  expect(calls.find((c) => c.url === "/api/admin/accounts/2/unblock/")?.body).toEqual({});
  expect(document.body.textContent).toContain("Compte débloqué");

  await click(byText(row(div, 3), "button", "Restaurer"));
  expect(document.querySelector("[role=dialog] textarea")).toBeNull();
  await click(dialogButton("Restaurer"));
  await wait();
  expect(calls.some((c) => c.method === "post" && c.url === "/api/admin/accounts/3/restore/")).toBe(true);
  expect(document.body.textContent).toContain("Compte restauré");
});

test("Annuler ne fait aucune requête", async () => {
  server(FULL);
  const div = await mount();
  await click(byText(row(div, 2), "button", "Débloquer"));
  await click(dialogButton("Annuler"));
  await wait(2);
  expect(document.querySelector("[role=dialog]")).toBeNull();
  expect(calls.some((c) => c.method === "post" && c.url.startsWith("/api/admin/accounts/"))).toBe(false);
});

test("Validateur : aucune action (boutons absents), mais la liste et le détail restent consultables", async () => {
  server(VALIDATEUR);
  const div = await mount();
  expect(row(div, 1)).not.toBeNull();
  for (const label of ["Bloquer", "Débloquer", "Restaurer"]) expect(byText(div, "button", label)).toBeNull();
  expect(div.querySelector('[aria-label="Supprimer"]')).toBeNull();
  // Seul le droit de bloquer : pas de suppression ni de restauration.
  await cleanup();
  server(["peut_voir_comptes", "peut_bloquer_compte"]);
  const d2 = await mount();
  expect(byText(row(d2, 1), "button", "Bloquer")).not.toBeNull();
  expect(d2.querySelector('[aria-label="Supprimer"]')).toBeNull();
  expect(byText(d2, "button", "Restaurer")).toBeNull();
  await cleanup();
  server(["peut_voir_comptes", "peut_supprimer_compte"]);
  const d3 = await mount();
  expect(byText(d3, "button", "Bloquer")).toBeNull();
  expect(d3.querySelector('[aria-label="Supprimer"]')).not.toBeNull();
  expect(byText(row(d3, 3), "button", "Restaurer")).not.toBeNull();
});

test("409 invalid_state : message + liste rechargée ; la fenêtre se ferme", async () => {
  server(FULL);
  action = () => ({ status: 409, data: { code: "invalid_state", message: "x" } });
  const div = await mount();
  await click(byText(row(div, 2), "button", "Débloquer"));
  const before = listCalls().length;
  list = [account(2)];
  await click(dialogButton("Débloquer"));
  await wait();
  expect(document.body.textContent).toContain("L'état de ce compte a changé");
  expect(listCalls().length).toBeGreaterThan(before);
  expect(document.querySelector("[role=dialog]")).toBeNull();
});

test("self_action_forbidden, last_full_admin, 403 et réseau : messages clairs, fenêtre gardée", async () => {
  server(FULL);
  const div = await mount();
  const attempt = async (reply: Reply) => {
    action = () => reply;
    if (!document.querySelector("[role=dialog]")) await click(byText(row(div, 2), "button", "Débloquer"));
    await click(dialogButton("Débloquer"));
    await wait(2);
  };
  await attempt({ status: 400, data: { code: "self_action_forbidden", message: "x" } });
  expect(document.body.textContent).toContain("Vous ne pouvez pas agir sur votre propre compte.");
  await attempt({ status: 409, data: { code: "last_full_admin", message: "x" } });
  expect(document.body.textContent).toContain("dernier Administrateur complet actif");
  await attempt({ status: 403, data: { code: "forbidden", message: "x" } });
  expect(document.body.textContent).toContain("Vous n'avez pas le droit d'effectuer cette action.");
  await attempt({ status: 0, network: true });
  expect(document.body.textContent).toContain("Connexion impossible");
  expect(document.querySelector("[role=dialog]")).not.toBeNull();
});

test("400 reason_required venant du serveur : message du motif", async () => {
  server(FULL);
  action = () => ({ status: 400, data: { code: "reason_required", message: "x" } });
  const div = await mount();
  await click(byText(row(div, 1), "button", "Bloquer"));
  await type(textarea(), "Motif");
  await click(dialogButton("Bloquer"));
  await wait(2);
  expect(document.body.textContent).toContain("Le motif est obligatoire.");
  expect(document.querySelector("[role=dialog]")).not.toBeNull();
});

test("double clic impossible : un seul envoi", async () => {
  server(FULL);
  let open!: () => void;
  gates.set("/api/admin/accounts/2/unblock/", new Promise<void>((r) => (open = r)));
  const div = await mount();
  await click(byText(row(div, 2), "button", "Débloquer"));
  const confirm = dialogButton("Débloquer");
  await click(confirm);
  await click(confirm);
  expect(Array.from(div.querySelectorAll("tbody button")).every((b) => (b as HTMLButtonElement).disabled)).toBe(true);
  await act(async () => open());
  await wait();
  expect(calls.filter((c) => c.url === "/api/admin/accounts/2/unblock/")).toHaveLength(1);
});

test("un clic sur la ligne ouvre le détail ; les boutons d'action n'ouvrent pas le détail", async () => {
  server(FULL);
  const div = await mount();
  await click(byText(row(div, 1), "button", "Bloquer"));
  expect(div.querySelector("main")!.textContent).toContain("TÉLÉPHONE");
  await click(byText(document.body, "button", "Annuler"));
  await click(row(div, 1).querySelectorAll("td")[3]);
  await wait();
  expect(calls.some((c) => c.url === "/api/admin/accounts/1/" && c.method === "get")).toBe(true);
  expect(div.querySelector("main")!.textContent).toContain("← Comptes");
  expect(div.querySelector("header h2")?.textContent).toBe("Comptes");
});

test("détail, Administrateur complet : numéro complet, profil, historique, audit avec motifs ; titre sans numéro", async () => {
  server(FULL);
  const setItem = vi.spyOn(Storage.prototype, "setItem");
  const div = await mount("/comptes/7");
  const main = div.querySelector("main")!;
  expect(main.textContent).toContain(FULL_PHONE);
  expect(main.textContent).toContain("Profil business");
  expect(main.textContent).toContain("Vente de tissus");
  expect(main.textContent).toContain("Compte bloqué");
  expect(main.textContent).toContain("Motif : Fausse annonce répétée");
  expect(main.textContent).toContain("Numéro consulté");
  expect(document.title).not.toContain("600");
  expect(div.querySelector("header")!.textContent).not.toContain(FULL_PHONE);
  expect(Array.from(div.querySelectorAll("h1,h2,h3")).some((h) => h.textContent?.includes(FULL_PHONE))).toBe(false);
  expect(calls.filter((c) => c.url === "/api/admin/accounts/7/" && c.method === "get")).toHaveLength(1);
  expect(setItem).not.toHaveBeenCalled();
  expect(JSON.stringify({ ...localStorage })).not.toContain("600 00 00");
  expect(JSON.stringify({ ...sessionStorage })).not.toContain("600 00 00");
  // Boutons d'action présents (compte actif non supprimé).
  expect(byText(main, "button", "Bloquer")).not.toBeNull();
  expect(byText(main, "button", "Supprimer")).not.toBeNull();
});

test("détail, Validateur : phone null → numéro masqué seulement, jamais de numéro complet ni d'action", async () => {
  server(VALIDATEUR);
  detailReply = { status: 200, data: detail(7, { phone: null }) };
  const div = await mount("/comptes/7");
  const main = div.querySelector("main")!;
  expect(main.textContent).toContain(MASKED);
  expect(main.textContent).not.toContain(FULL_PHONE);
  expect(main.textContent).not.toMatch(/\+237 6\d/);
  expect(byText(main, "button", "Bloquer")).toBeNull();
  expect(byText(main, "button", "Supprimer")).toBeNull();
  expect(byText(main, "button", "Restaurer")).toBeNull();
});

test("détail : le numéro complet n'est jamais dans la liste ; cache détail court (≤ 1 min), vidé à la déconnexion", async () => {
  server(FULL);
  const div = await mount("/comptes/7");
  const q = qc.getQueryCache().find({ queryKey: ["admin", "accounts", "detail", 7] })!;
  expect(q.options.gcTime).toBeLessThanOrEqual(60_000);
  expect((q.options as { staleTime?: number }).staleTime).toBe(0);
  expect(JSON.stringify(qc.getQueryCache().findAll({ queryKey: ["admin", "accounts", "list"] }).map((x) => x.state.data))).not.toContain("600 00 00");
  const buttonBack = byText(div, "a", "← Comptes");
  expect(buttonBack?.getAttribute("href")).toBe("/comptes");
  await click(byText(div, "button", "Déconnexion"));
  await wait();
  expect(qc.getQueryCache().findAll({ queryKey: ["admin", "accounts"] })).toHaveLength(0);
});

test("détail : action sur le compte puis détail rechargé", async () => {
  server(FULL);
  const div = await mount("/comptes/7");
  await click(byText(div.querySelector("main")!, "button", "Bloquer"));
  await type(textarea(), "Motif de test");
  detailReply = { status: 200, data: detail(7, { status: "bloque", is_blocked: true, blocked_reason: "Motif de test", blocked_at: ago(0) }) };
  await click(dialogButton("Bloquer"));
  await wait();
  expect(calls.find((c) => c.url === "/api/admin/accounts/7/block/")?.body).toEqual({ reason: "Motif de test" });
  const main = div.querySelector("main")!;
  expect(main.textContent).toContain("Motif du blocage");
  expect(byText(main, "button", "Débloquer")).not.toBeNull();
});

test("détail : pièce ouverte seulement au clic, avec le jeton, en blob ; lien expiré géré", async () => {
  server(FULL);
  const div = await mount("/comptes/7");
  expect(calls.some((c) => c.url.startsWith("/api/admin/private-files/"))).toBe(false);
  expect(div.querySelector('a[href*="private-files"], img[src*="private-files"]')).toBeNull();
  await click(byText(div, "button", "Voir la CNI"));
  await wait(2);
  const file = calls.filter((c) => c.url.startsWith("/api/admin/private-files/"));
  expect(file).toHaveLength(1);
  expect(file[0].auth).toBe("Bearer jeton-fictif");
  expect(document.querySelector("[role=dialog] img")?.getAttribute("src")).toMatch(/^blob:/);
  await click(dialogButton("Fermer"));
  fileReply = { status: 403, data: { code: "invalid_link", message: "x" } };
  await click(byText(div, "button", "Voir la CNI"));
  await wait(2);
  expect(document.querySelector("[role=dialog]")!.textContent).toContain("Ce lien a expiré");
  const before = calls.filter((c) => c.url === "/api/admin/accounts/7/" && c.method === "get").length;
  await click(dialogButton("Actualiser la demande"));
  await wait(2);
  expect(calls.filter((c) => c.url === "/api/admin/accounts/7/" && c.method === "get").length).toBeGreaterThan(before);
});

test("détail : 404, 403, erreur avec Réessayer, identifiant invalide", async () => {
  server(FULL);
  detailReply = { status: 404, data: { code: "not_found", message: "x" } };
  let div = await mount("/comptes/7");
  expect(div.querySelector("main [role=alert]")?.textContent).toContain("Ce compte n'existe pas.");
  await cleanup();
  detailReply = { status: 403, data: { code: "forbidden", message: "x" } };
  div = await mount("/comptes/7");
  expect(div.querySelector("main [role=alert]")?.textContent).toContain("pas le droit de voir ce compte");
  await cleanup();
  detailReply = { status: 500 };
  div = await mount("/comptes/7");
  expect(div.querySelector("main [role=alert]")?.textContent).toContain("Impossible de charger ce compte.");
  detailReply = { status: 200, data: detail(7) };
  await click(byText(div, "button", "Réessayer"));
  await wait();
  expect(div.querySelector("main")!.textContent).toContain(FULL_PHONE);
  await cleanup();
  const before = calls.length;
  div = await mount("/comptes/abc");
  expect(div.querySelector("main [role=alert]")?.textContent).toContain("Ce compte n'existe pas.");
  expect(calls.slice(before).some((c) => c.url.startsWith("/api/admin/accounts/"))).toBe(false);
});

test("droits par route : sans peut_voir_comptes, ni /comptes ni /comptes/7 ne chargent quoi que ce soit", async () => {
  for (const path of ["/comptes", "/comptes/7"]) {
    resetServer();
    server(["peut_voir_demandes"]);
    const div = await mount(path);
    expect(div.querySelector('[role="alert"]')?.textContent).toContain("Accès refusé");
    expect(calls.some((c) => c.url.startsWith("/api/admin/accounts/") || c.url === "/api/zones/")).toBe(false);
    await cleanup();
  }
});

test("barre latérale : l'entrée Comptes mène à la vraie page", async () => {
  server(FULL);
  const div = await mount("/demandes");
  await click(byText(div.querySelector("aside")!, "a", "Comptes"));
  await wait();
  expect(div.querySelector("main")!.textContent).toContain("TÉLÉPHONE");
});
