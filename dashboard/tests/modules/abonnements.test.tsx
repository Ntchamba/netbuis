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
import { calls, gates, resetServer, setHandler, type Call, type Reply } from "../auth/fakeServer";
import { byText, cleanup, click, render, type } from "../components/helpers";

// Données FICTIVES.
const SUBS = "/api/admin/subscriptions/";
const FULL = ["peut_voir_comptes", "peut_accorder_abonnement"];
const VALIDATEUR = ["peut_voir_comptes", "peut_voir_demandes"];
const END = "2026-12-24T10:00:00Z";

const row = (id: number, name: string, over: Record<string, unknown> = {}) => ({
  id, name, owner_id: 100 + id, phone_masked: "+237 6•• •• •• 41", zone_id: 1, zone_name: "Douala",
  is_subscribed: false, subscription_end: null, calls_last_day: 3, calls_count: 9, high_traffic: false, ...over,
});

let rows: unknown[];
let total: number;
let list: (c: Call) => Reply;
let post: (c: Call) => Reply;

function server(permissions: string[]) {
  const me = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return { status: 200, data: { pending_requests: 0 } };
    if (c.url === SUBS) return c.method === "get" ? list(c) : post(c);
    return { status: 404 };
  });
}

async function wait(n = 4) {
  for (let i = 0; i < n; i++) await act(async () => new Promise((r) => setTimeout(r, 15)));
}

async function mount(path = "/equipe") {
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

const dialog = () => document.querySelector("[role=dialog]") as HTMLElement | null;
const dBtn = (label: string) => byText(dialog()!, "button", label) as HTMLButtonElement;
const reasonBox = () => dialog()!.querySelector("textarea") as HTMLTextAreaElement;
const monthSelect = () => dialog()!.querySelector("select") as HTMLSelectElement;
const posts = () => calls.filter((c) => c.url === SUBS && c.method === "post");
const gets = () => calls.filter((c) => c.url === SUBS && c.method === "get");
const toasts = () => document.body.textContent ?? "";

async function chooseMonths(m: string) {
  await act(async () => {
    const setter = Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, "value")!.set!;
    setter.call(monthSelect(), m);
    monthSelect().dispatchEvent(new Event("change", { bubbles: true }));
  });
}
async function openGrant(div: HTMLElement, id = 1) {
  await click(byText(div.querySelector(`[data-testid="sub-row-${id}"]`)!, "button", "Accorder un abonnement"));
}
async function fillAndConfirm(months: string, reason: string) {
  await chooseMonths(months);
  await type(reasonBox(), reason);
  await click(dBtn("Continuer"));
}

beforeEach(() => {
  resetServer();
  clearAccessToken();
  localStorage.clear();
  sessionStorage.clear();
  rows = [row(1, "Chez Fictif"), row(2, "Atelier Test", { is_subscribed: true, subscription_end: END })];
  total = 2;
  list = () => ({ status: 200, data: { count: total, next: null, results: rows } });
  post = () => ({ status: 201, data: { id: 5, business_id: 1, business_name: "Chez Fictif", start: "2026-10-22T10:00:00Z", end: END, status: "actif", source: "manuel", granted_by_id: 1, granted_by_name: "Awa Test" } });
});
afterEach(cleanup);

// ---------- Liste ----------
test("liste : chargement puis lignes, sans numéro de téléphone", async () => {
  server(FULL);
  let release!: () => void;
  gates.set(SUBS, new Promise<void>((r) => (release = r)));
  const div = await mount();
  expect(div.querySelectorAll("[data-loading-row]").length).toBeGreaterThan(0);
  release();
  await wait();
  expect(div.textContent).toContain("Chez Fictif");
  expect(div.textContent).toContain("Abonné");
  expect(div.textContent).toContain("24 décembre 2026");
  expect(div.textContent).not.toContain("+237");
  expect(div.textContent).not.toMatch(/\d{9}/);
});

test("liste vide : message dédié", async () => {
  list = () => ({ status: 200, data: { count: 0, next: null, results: [] } });
  server(FULL);
  const div = await mount();
  expect(div.textContent).toContain("Aucun compte business ne correspond");
});

test("erreur serveur : message et bouton Réessayer qui relance", async () => {
  list = () => ({ status: 500 });
  server(FULL);
  const div = await mount();
  expect(div.querySelector('[role="alert"]')?.textContent).toContain("Impossible de charger les abonnements.");
  const before = gets().length;
  await click(byText(div, "button", "Réessayer"));
  await wait();
  expect(gets().length).toBe(before + 1);
});

test("403 sur la liste : message clair, pas de Réessayer", async () => {
  list = () => ({ status: 403, data: { code: "permission_denied" } });
  server(FULL);
  const div = await mount();
  expect(div.querySelector('[role="alert"]')?.textContent).toContain("pas le droit");
  expect(byText(div, "button", "Réessayer")).toBeNull();
});

test("filtres : abonnés / non abonnés / à fort trafic envoyés dans la requête, page remise à 1", async () => {
  server(FULL);
  const div = await mount();
  expect(gets()[0]!.params).toEqual({ page: 1, page_size: 20 });
  for (const [label, key] of [["Abonnés", "subscribed"], ["Non abonnés", "unsubscribed"], ["À fort trafic", "high_traffic"]] as const) {
    await click(byText(div, "button", label));
    await wait();
    expect(gets().at(-1)!.params).toEqual({ page: 1, page_size: 20, filter: key });
  }
  await click(byText(div, "button", "Tous"));
  await wait();
  expect(gets().at(-1)!.params).toEqual({ page: 1, page_size: 20 });
});

test("pagination : la page suivante est demandée", async () => {
  total = 45;
  server(FULL);
  const div = await mount();
  await click(byText(div, "button", "Suivant") ?? div.querySelector('[aria-label="Page suivante"]'));
  await wait();
  expect(gets().at(-1)!.params).toMatchObject({ page: 2 });
});

// ---------- Droits ----------
test("Validateur : liste visible, aucun bouton Accorder", async () => {
  server(VALIDATEUR);
  const div = await mount();
  expect(div.textContent).toContain("Chez Fictif");
  expect(byText(div, "button", "Accorder un abonnement")).toBeNull();
});

test("Administrateur complet : bouton Accorder sur les comptes non abonnés seulement", async () => {
  server(FULL);
  const div = await mount();
  expect(byText(div.querySelector('[data-testid="sub-row-1"]')!, "button", "Accorder un abonnement")).not.toBeNull();
  expect(byText(div.querySelector('[data-testid="sub-row-2"]')!, "button", "Accorder un abonnement")).toBeNull();
});

test("sans aucun droit : Accès refusé et aucune requête", async () => {
  server([]);
  const div = await mount();
  expect(div.textContent).toContain("Accès refusé");
  expect(gets()).toHaveLength(0);
});

test("partie équipe : onglet désactivé « à venir », aucune requête d'équipe", async () => {
  server(FULL);
  const div = await mount();
  const tab = byText(div, "button", "Équipe NetBuis (à venir)") as HTMLButtonElement;
  expect(tab.disabled).toBe(true);
  await click(tab);
  expect(calls.filter((c) => c.url.includes("team") || c.url.includes("equipe"))).toHaveLength(0);
});

// ---------- Formulaire ----------
test("motif vide ou d'espaces : bloqué sans requête, message sous le champ", async () => {
  server(FULL);
  const div = await mount();
  await openGrant(div);
  await click(dBtn("Continuer"));
  expect(dialog()!.textContent).toContain("Le motif est obligatoire.");
  await type(reasonBox(), "    ");
  await click(dBtn("Continuer"));
  expect(dialog()!.textContent).toContain("Le motif est obligatoire.");
  expect(dBtn("Confirmer l'accord")).toBeNull();
  expect(posts()).toHaveLength(0);
});

test("compteur de caractères et limite de 1000", async () => {
  server(FULL);
  const div = await mount();
  await openGrant(div);
  await type(reasonBox(), "abc");
  expect(dialog()!.querySelector('[data-testid="reason-counter"]')?.textContent).toBe("3 / 1000");
  expect(reasonBox().maxLength).toBe(1000);
});

test("confirmation : rappelle commerce, durée et motif ; rien n'est envoyé avant", async () => {
  server(FULL);
  const div = await mount();
  await openGrant(div);
  await fillAndConfirm("3", "Paiement reçu en main propre");
  const recap = dialog()!.querySelector('[data-testid="grant-recap"]')!.textContent!;
  expect(recap).toContain("Chez Fictif");
  expect(recap).toContain("3 mois");
  expect(recap).toContain("90 jours");
  expect(recap).toContain("Paiement reçu en main propre");
  expect(posts()).toHaveLength(0);
  await click(dBtn("Retour"));
  expect(reasonBox().value).toBe("Paiement reçu en main propre");
});

test("durées : 1, 2, 3, 6 et 12 mois = 30, 60, 90, 180 et 360 jours", async () => {
  server(FULL);
  const div = await mount();
  const seen: unknown[] = [];
  for (const [m, d] of [["1", 30], ["2", 60], ["3", 90], ["6", 180], ["12", 360]] as const) {
    await openGrant(div);
    await fillAndConfirm(m, "Motif");
    await click(dBtn("Confirmer l'accord"));
    await wait();
    seen.push((posts().at(-1)!.body as { duration_days: number }).duration_days);
    expect(seen.at(-1)).toBe(d);
  }
});

test("succès : bon corps, message, liste rafraîchie, fenêtre fermée", async () => {
  server(FULL);
  const div = await mount();
  const before = gets().length;
  await openGrant(div);
  await fillAndConfirm("2", "  Paiement reçu  ");
  await click(dBtn("Confirmer l'accord"));
  await wait();
  expect(posts()).toHaveLength(1);
  expect(posts()[0]!.body).toEqual({ business_id: 1, duration_days: 60, reason: "Paiement reçu" });
  expect(dialog()).toBeNull();
  expect(toasts()).toContain("Abonnement accordé à Chez Fictif");
  expect(gets().length).toBeGreaterThan(before);
});

test("double clic : une seule requête", async () => {
  server(FULL);
  const div = await mount();
  await openGrant(div);
  await fillAndConfirm("1", "Motif");
  let release!: () => void;
  gates.set(SUBS, new Promise<void>((r) => (release = r)));
  const confirm = dBtn("Confirmer l'accord");
  await click(confirm);
  await click(confirm);
  await click(confirm);
  expect(confirm.disabled).toBe(true);
  release();
  await wait();
  expect(posts()).toHaveLength(1);
});

test("409 already_subscribed : « déjà abonné jusqu'au… », liste actualisée", async () => {
  post = () => ({ status: 409, data: { code: "already_subscribed", message: "TEXTE BRUT SERVEUR" } });
  server(FULL);
  const div = await mount();
  await openGrant(div);
  await fillAndConfirm("1", "Motif");
  await click(dBtn("Confirmer l'accord"));
  await wait();
  expect(toasts()).toContain("déjà abonné");
  expect(toasts()).not.toContain("TEXTE BRUT SERVEUR");
  expect(dialog()).toBeNull();
});

test("409 business_not_active : « commerce non actif »", async () => {
  post = () => ({ status: 409, data: { code: "business_not_active" } });
  server(FULL);
  const div = await mount();
  await openGrant(div);
  await fillAndConfirm("1", "Motif");
  await click(dBtn("Confirmer l'accord"));
  await wait();
  expect(toasts()).toContain("n'est pas actif");
});

test("403 au POST : message propre, aucune fuite du texte serveur", async () => {
  post = () => ({ status: 403, data: { code: "permission_denied", message: "TEXTE BRUT SERVEUR" } });
  server(FULL);
  const div = await mount();
  await openGrant(div);
  await fillAndConfirm("1", "Motif");
  await click(dBtn("Confirmer l'accord"));
  await wait();
  expect(toasts()).toContain("Vous n'avez pas le droit d'accorder un abonnement.");
  expect(toasts()).not.toContain("TEXTE BRUT SERVEUR");
});

test("400 avec fields : retour au formulaire, messages français sous les champs", async () => {
  post = () => ({ status: 400, data: { code: "validation_error", fields: { duration_days: ["Ensure this value is less than"], reason: ["This field may not be blank."] } } });
  server(FULL);
  const div = await mount();
  await openGrant(div);
  await fillAndConfirm("1", "Motif");
  await click(dBtn("Confirmer l'accord"));
  await wait();
  expect(dialog()!.textContent).toContain("Durée invalide");
  expect(dialog()!.textContent).toContain("Motif invalide");
  expect(dialog()!.textContent).not.toContain("Ensure this value");
  expect(dialog()!.textContent).not.toContain("may not be blank");
});

test("erreur réseau : message de connexion, fenêtre conservée, nouvel essai possible", async () => {
  post = () => ({ status: 0, network: true });
  server(FULL);
  const div = await mount();
  await openGrant(div);
  await fillAndConfirm("1", "Motif");
  await click(dBtn("Confirmer l'accord"));
  await wait();
  expect(toasts()).toContain("Connexion impossible");
  expect(dialog()).not.toBeNull();
  expect(dBtn("Confirmer l'accord").disabled).toBe(false);
});

test("motif rendu comme du texte, jamais comme du HTML", async () => {
  server(FULL);
  const div = await mount();
  await openGrant(div);
  await fillAndConfirm("1", "<img src=x onerror=alert(1)>");
  expect(dialog()!.querySelector("img")).toBeNull();
  expect(dialog()!.textContent).toContain("<img src=x onerror=alert(1)>");
});

test("un numéro renvoyé par l'API n'est jamais affiché", async () => {
  rows = [row(1, "Chez Fictif", { phone: "+237699000041", phone_masked: "+237 6•• •• •• 41" })];
  server(FULL);
  const div = await mount();
  expect(div.textContent).not.toContain("699000041");
  expect(div.textContent).not.toContain("+237");
});
