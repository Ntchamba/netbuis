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
import { ACTION_LABELS } from "../../src/modules/audit_log/types";
import { dateError, validateFilters } from "../../src/modules/audit_log/validation";
import { calls, resetServer, setHandler, type Call, type Reply } from "../auth/fakeServer";
import { byText, cleanup, click, render, type } from "../components/helpers";

// Données FICTIVES.
const AUDIT = "/api/admin/audit/";
const ADMINS = "/api/admin/admins/";
const FULL = ["peut_voir_comptes", "peut_voir_demandes", "peut_modifier_reglages", "peut_gerer_admins"];
const VALIDATEUR = ["peut_voir_comptes", "peut_voir_demandes", "peut_valider_demande"];
const NONE = ["peut_voir_demandes"];

const entry = (id: number, over: Record<string, unknown> = {}) => ({
  id, admin_id: 1, admin_name: "Awa Test", action: "blocage_compte", action_label: "Blocage d'un compte",
  target_type: "accounts.user", target_id: 40 + id, reason: "Motif fictif", created_at: "2026-10-20T10:30:00Z", ...over,
});

let rows: unknown[];
let total: number;
let reply: ((c: Call) => Reply) | null;

function server(permissions: string[]) {
  const me = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return { status: 200, data: { pending_requests: 0 } };
    if (c.url === ADMINS) return { status: 200, data: { count: 2, next: null, results: [{ id: 1, name: "Awa Test" }, { id: 2, name: "Bello Test" }] } };
    if (c.url === AUDIT) return reply ? reply(c) : { status: 200, data: { count: total, next: null, results: rows } };
    return { status: 404 };
  });
}

async function wait(n = 4) {
  for (let i = 0; i < n; i++) await act(async () => new Promise((r) => setTimeout(r, 15)));
}

async function mount(path = "/audit") {
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

const auditCalls = () => calls.filter((c) => c.url === AUDIT);
const lastParams = () => auditCalls().at(-1)!.params!;
const input = (div: HTMLElement, label: string) => {
  const l = Array.from(div.querySelectorAll("label")).find((e) => e.textContent === label)!;
  return div.querySelector(`#${CSS.escape(l.getAttribute("for")!)}`) as HTMLInputElement & HTMLSelectElement;
};
async function pick(el: HTMLSelectElement, value: string) {
  await act(async () => {
    el.value = value;
    el.dispatchEvent(new Event("change", { bubbles: true }));
  });
  await wait();
}
async function typeDate(div: HTMLElement, label: string, value: string) {
  await type(input(div, label), value);
  await wait();
}

beforeEach(() => {
  resetServer();
  clearAccessToken();
  localStorage.clear();
  sessionStorage.clear();
  rows = [entry(2, { created_at: "2026-10-21T23:30:00Z" }), entry(1)];
  total = 2;
  reply = null;
});
afterEach(cleanup);

test("liste : colonnes, ordre du serveur (récent d'abord), date en heure du Cameroun, lien vers le compte", async () => {
  server(FULL);
  const div = await mount();
  const heads = Array.from(div.querySelectorAll("th")).map((h) => h.textContent);
  expect(heads).toEqual(["Date", "Admin", "Action", "Cible", "Motif"]);
  const trs = div.querySelectorAll("tbody tr");
  expect(trs).toHaveLength(2);
  // 23:30 UTC le 21 = 00:30 le 22 à Douala (UTC+1) : le plus récent est en premier.
  expect(trs[0]!.textContent).toContain("22");
  expect(trs[0]!.textContent).toContain("00:30");
  expect(trs[0]!.textContent).toContain("Blocage d'un compte");
  expect(trs[0]!.textContent).toContain("Motif fictif");
  const link = trs[0]!.querySelector("a")!;
  expect(link.getAttribute("href")).toBe("/comptes/42");
  expect(link.textContent).toBe("Compte #42");
  expect(div.querySelector("h2")?.textContent).toBe("Journal d'audit");
  expect(auditCalls()).toHaveLength(1);
  expect(auditCalls()[0]!.params).toEqual({ page: 1, page_size: 20 });
});

test("cible autre qu'un compte : texte sans lien ; action inconnue : code brut", async () => {
  server(FULL);
  rows = [entry(1, { action: "action_future", target_type: "admin_panel.platformsetting", target_id: 7 })];
  total = 1;
  const div = await mount();
  const tr = div.querySelector("tbody tr")!;
  expect(tr.textContent).toContain("action_future");
  expect(tr.textContent).toContain("admin_panel.platformsetting #7");
  expect(tr.querySelector("a")).toBeNull();
});

test("chaque action de la liste fermée a un libellé français", () => {
  expect(Object.keys(ACTION_LABELS)).toHaveLength(17);
  for (const l of Object.values(ACTION_LABELS)) expect(l).toMatch(/^[A-ZÉ]/);
});

test("filtres : admin, action, du, au envoient le bon paramètre", async () => {
  server(FULL);
  const div = await mount();
  expect(calls.filter((c) => c.url === ADMINS)).toHaveLength(1);
  await pick(input(div, "Administrateur"), "2");
  expect(lastParams()).toMatchObject({ admin: "2", page: 1 });
  await pick(input(div, "Action"), "rejet_business");
  expect(lastParams()).toMatchObject({ admin: "2", action: "rejet_business" });
  await typeDate(div, "Du", "2026-10-01");
  expect(lastParams()).toMatchObject({ from: "2026-10-01" });
  await typeDate(div, "Au", "2026-10-21");
  expect(lastParams()).toEqual({ page: 1, page_size: 20, admin: "2", action: "rejet_business", from: "2026-10-01", to: "2026-10-21" });
});

test("dates invalides : message, aucune requête", async () => {
  server(FULL);
  const div = await mount();
  const before = auditCalls().length;
  for (const bad of ["21/10/2026", "2026-02-30", "1999-12-31", "2099-01-01"]) {
    await typeDate(div, "Du", bad);
    expect(div.textContent).toContain("Date invalide : format AAAA-MM-JJ");
    expect(div.querySelector("tbody")).toBeNull();
  }
  await typeDate(div, "Du", "2026-10-21");
  await typeDate(div, "Au", "2026-10-01");
  expect(div.textContent).toContain("« Au » doit être égale ou postérieure");
  // Seule la requête de la date valide « Du » seule a pu partir.
  expect(auditCalls().length).toBe(before + 1);
  expect(lastParams()).toMatchObject({ from: "2026-10-21" });
});

test("validation : bornes comme le serveur", () => {
  const now = new Date("2026-10-22T12:00:00Z");
  expect(dateError("2000-01-01", now)).toBeNull();
  expect(dateError("1999-12-31", now)).not.toBeNull();
  expect(dateError("2027-10-23", now)).toBeNull();
  expect(dateError("2027-10-24", now)).not.toBeNull();
  expect(dateError("", now)).toBeNull();
  expect(validateFilters({ admin: "abc", action: "", from: "", to: "" }, now).admin).toBeDefined();
  expect(validateFilters({ admin: "3", action: "", from: "2026-01-02", to: "2026-01-01" }, now).to).toBeDefined();
  expect(validateFilters({ admin: "3", action: "", from: "2026-01-01", to: "2026-01-01" }, now)).toEqual({});
});

test("réinitialiser : vide les filtres et recharge sans paramètre", async () => {
  server(FULL);
  const div = await mount();
  await pick(input(div, "Action"), "export_comptes");
  await typeDate(div, "Du", "2026-10-01");
  await click(byText(div, "button", "Réinitialiser"));
  await wait();
  expect(lastParams()).toEqual({ page: 1, page_size: 20 });
  expect(input(div, "Du").value).toBe("");
  expect(input(div, "Action").value).toBe("");
});

test("pagination : page suivante demandée, retour page 1 quand un filtre change", async () => {
  server(FULL);
  total = 45;
  const div = await mount();
  expect(div.textContent).toContain("Page 1 sur 3");
  await click(byText(div, "button", "Suivant"));
  await wait();
  expect(lastParams()).toMatchObject({ page: 2 });
  await pick(input(div, "Action"), "retrait_role");
  expect(lastParams()).toMatchObject({ page: 1, action: "retrait_role" });
});

test("motif long : tronqué, « Voir plus » le déplie, texte simple (pas de HTML)", async () => {
  server(FULL);
  const long = "<b>gras</b> " + "x".repeat(300) + " FIN";
  rows = [entry(1, { reason: long })];
  total = 1;
  const div = await mount();
  const td = div.querySelectorAll("tbody td")[4]!;
  expect(td.textContent).not.toContain("FIN");
  expect(td.textContent).toContain("<b>gras</b>");
  expect(td.querySelector("b")).toBeNull();
  await click(byText(td as HTMLElement, "button", "Voir plus"));
  expect(td.textContent).toContain("FIN");
  await click(byText(td as HTMLElement, "button", "Voir moins"));
  expect(td.textContent).not.toContain("FIN");
});

test("état vide", async () => {
  server(FULL);
  rows = [];
  total = 0;
  const div = await mount();
  expect(div.textContent).toContain("Aucune action sur cette période");
});

test("sans peut_voir_comptes : Accès refusé, aucune requête", async () => {
  server(NONE);
  const div = await mount();
  expect(div.textContent).toContain("Accès refusé");
  expect(auditCalls()).toHaveLength(0);
  expect(calls.filter((c) => c.url === ADMINS)).toHaveLength(0);
});

test("Validateur : entrée de menu présente, aucun appel à la liste des administrateurs, pas de sélecteur d'admin", async () => {
  server(VALIDATEUR);
  const div = await mount();
  expect(Array.from(div.querySelectorAll("aside nav > *")).map((e) => e.textContent)).toContain("Journal d'audit");
  expect(calls.filter((c) => c.url === ADMINS)).toHaveLength(0);
  expect(Array.from(div.querySelectorAll("label")).map((l) => l.textContent)).not.toContain("Administrateur");
  expect(auditCalls()).toHaveLength(1);
  expect(div.querySelectorAll("tbody tr")).toHaveLength(2);
});

test("lecture seule : aucun bouton d'écriture, aucune requête non-GET", async () => {
  server(FULL);
  const div = await mount();
  await pick(input(div, "Action"), "blocage_compte");
  await click(byText(div, "button", "Réinitialiser"));
  const main = div.querySelector("main")!;
  const labels = Array.from(main.querySelectorAll("button")).map((b) => b.textContent);
  for (const l of labels) expect(l).not.toMatch(/modifier|supprimer|effacer|éditer/i);
  expect(calls.filter((c) => c.method !== "get" && c.url !== "/api/auth/refresh/")).toHaveLength(0);
});

test("erreur 400 invalid_filter : message propre et Réessayer", async () => {
  server(FULL);
  reply = () => ({ status: 400, data: { code: "invalid_filter", detail: "x" } });
  const div = await mount();
  expect(div.querySelector("[role=alert]")?.textContent).toContain("Filtre invalide");
  reply = null;
  await click(byText(div, "button", "Réessayer"));
  await wait();
  expect(div.querySelectorAll("tbody tr")).toHaveLength(2);
});

test("erreur 403 et erreur réseau", async () => {
  server(FULL);
  reply = () => ({ status: 403, data: { code: "permission_denied" } });
  let div = await mount();
  expect(div.querySelector("[role=alert]")?.textContent).toContain("pas le droit");
  await cleanup();
  reply = () => ({ status: 0, network: true });
  div = await mount();
  expect(div.querySelector("[role=alert]")).not.toBeNull();
  expect(byText(div, "button", "Réessayer")).not.toBeNull();
});
