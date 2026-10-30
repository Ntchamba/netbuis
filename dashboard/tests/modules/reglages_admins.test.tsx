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

// Données FICTIVES. Le « mot de passe » ci-dessous n'existe nulle part.
const SETTINGS = "/api/admin/settings/";
const ADMINS = "/api/admin/admins/";
const FULL = ["peut_voir_comptes", "peut_voir_demandes", "peut_modifier_reglages", "peut_gerer_admins"];
const VALIDATEUR = ["peut_voir_comptes", "peut_voir_demandes", "peut_valider_demande"];
const SECRET = "Zx9-fictif-Tmp-4821";
const NOW = "2026-01-01T00:00:00Z";

const setting = (key: string, label: string, value: number, over: Record<string, unknown> = {}) => ({
  key, label, value, default: value, min: 0, max: 100, modified_by: null, updated_at: null, ...over,
});
const admin = (id: number, name: string, role: string, over: Record<string, unknown> = {}) => ({
  id, name, phone_masked: "+237 6•• •• •• 41", roles: [role], status: "actif", created_at: NOW, ...over,
});

let settings: unknown[];
let admins: unknown[];
let writeSetting: (c: Call) => Reply;
let writeAdmin: (c: Call) => Reply;
let qc: QueryClient;

function server(permissions: string[], meId = 1) {
  const me = { id: meId, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return { status: 200, data: { pending_requests: 0 } };
    if (c.url === SETTINGS && c.method === "get") return { status: 200, data: settings };
    if (c.url.startsWith(SETTINGS)) return writeSetting(c);
    if (c.url === ADMINS && c.method === "get") return { status: 200, data: { count: admins.length, next: null, results: admins } };
    if (c.url.startsWith(ADMINS)) return writeAdmin(c);
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

const dialog = () => document.querySelector("[role=dialog]") as HTMLElement;
const dialogButton = (label: string) => byText(dialog(), "button", label) as HTMLButtonElement;
const field = (label: string) => {
  const l = Array.from(dialog().querySelectorAll("label")).find((e) => e.textContent === label)!;
  return dialog().querySelector(`#${CSS.escape(l.getAttribute("for")!)}`) as HTMLInputElement;
};
const writes = (base: string) => calls.filter((c) => c.url.startsWith(base) && c.method !== "get");
const rowOf = (div: HTMLElement, id: number) => div.querySelector(`[data-testid="admin-row-${id}"]`) as HTMLElement;
const settingBox = (div: HTMLElement, key: string) => div.querySelector(`[data-testid="setting-${key}"]`) as HTMLElement;
const settingInput = (div: HTMLElement, key: string) => settingBox(div, key).querySelector("input") as HTMLInputElement;

beforeEach(() => {
  resetServer();
  clearAccessToken();
  localStorage.clear();
  sessionStorage.clear();
  settings = [setting("limite_appels_par_jour", "Limite d'appels par jour", 50, { max: 1000 }), setting("limite_appels_par_minute", "Limite d'appels par minute", 5, { max: 60 })];
  admins = [admin(1, "Awa Test", "Administrateur complet"), admin(2, "Bello Test", "Validateur"), admin(3, "Carine Test", "Administrateur complet")];
  writeSetting = (c) => ({ status: 200, data: setting("limite_appels_par_jour", "x", (c.body as { value: number }).value) });
  writeAdmin = () => ({ status: 200, data: admin(2, "Bello Test", "Validateur") });
});
afterEach(cleanup);

// ---------- Droits ----------
test("Validateur : Accès refusé sans requête, entrées de menu masquées", async () => {
  server(VALIDATEUR);
  for (const path of ["/reglages", "/administrateurs"]) {
    const div = await mount(path);
    expect(div.textContent).toContain("Accès refusé");
    const nav = Array.from(div.querySelectorAll("aside nav > *")).map((e) => e.textContent);
    expect(nav).not.toContain("Réglages");
    expect(nav).not.toContain("Administrateurs");
    await cleanup();
  }
  expect(calls.filter((c) => c.url === SETTINGS || c.url === ADMINS)).toHaveLength(0);
});

test("Administrateur complet : les deux entrées de menu sont présentes", async () => {
  server(FULL);
  const div = await mount("/reglages");
  const nav = Array.from(div.querySelectorAll("aside nav > *")).map((e) => e.textContent);
  expect(nav).toContain("Réglages");
  expect(nav).toContain("Administrateurs");
});

// ---------- Réglages ----------
test("réglages : libellé, valeur, bornes ; modification valide avec confirmation", async () => {
  server(FULL);
  const div = await mount("/reglages");
  expect(settingBox(div, "limite_appels_par_jour").textContent).toContain("Limite d'appels par jour");
  expect(div.querySelector('[data-testid="setting-value-limite_appels_par_jour"]')?.textContent).toBe("50");
  await type(settingInput(div, "limite_appels_par_jour"), "80");
  await click(byText(settingBox(div, "limite_appels_par_jour"), "button", "Enregistrer"));
  expect(writes(SETTINGS)).toHaveLength(0); // la confirmation d'abord
  expect(dialog().textContent).toContain("50 → 80");
  await click(dialogButton("Enregistrer"));
  await wait();
  const w = writes(SETTINGS);
  expect(w).toHaveLength(1);
  expect(w[0]!.method).toBe("patch");
  expect(w[0]!.url).toBe(`${SETTINGS}limite_appels_par_jour/`);
  expect(w[0]!.body).toEqual({ value: 80 });
  expect(dialog()).toBeNull();
});

test("réglages : valeurs hors bornes, non entières ou vides refusées sans requête", async () => {
  server(FULL);
  const div = await mount("/reglages");
  const box = settingBox(div, "limite_appels_par_minute");
  for (const bad of ["61", "-1", "2.5", "abc", ""]) {
    await type(settingInput(div, "limite_appels_par_minute"), bad);
    await click(byText(box, "button", "Enregistrer"));
    expect(box.querySelector("[role=alert]"), bad).not.toBeNull();
    expect(dialog()).toBeNull();
    if (bad === "61" || bad === "-1") expect(box.textContent).toContain("entre 0 et 60");
  }
  expect(writes(SETTINGS)).toHaveLength(0);
});

test("réglages : erreur serveur invalid_value affichée, pas de succès annoncé", async () => {
  server(FULL);
  writeSetting = () => ({ status: 400, data: { code: "invalid_value", message: "x" } });
  const div = await mount("/reglages");
  await type(settingInput(div, "limite_appels_par_jour"), "80");
  await click(byText(settingBox(div, "limite_appels_par_jour"), "button", "Enregistrer"));
  await click(dialogButton("Enregistrer"));
  await wait();
  expect(writes(SETTINGS)).toHaveLength(1);
  expect(settingBox(div, "limite_appels_par_jour").textContent).toContain("Le serveur refuse cette valeur");
  expect(dialog()).toBeNull();
});

test("réglages : double envoi impossible", async () => {
  server(FULL);
  let release!: () => void;
  gates.set(`${SETTINGS}limite_appels_par_jour/`, new Promise<void>((r) => (release = r)));
  const div = await mount("/reglages");
  await type(settingInput(div, "limite_appels_par_jour"), "80");
  await click(byText(settingBox(div, "limite_appels_par_jour"), "button", "Enregistrer"));
  const confirm = dialogButton("Enregistrer");
  await click(confirm);
  await click(confirm);
  await click(confirm);
  expect(writes(SETTINGS)).toHaveLength(1);
  release();
  await wait();
  expect(writes(SETTINGS)).toHaveLength(1);
});

// ---------- Administrateurs ----------
test("administrateurs : numéros masqués, rôle et statut ; boutons masqués sur sa propre ligne", async () => {
  server(FULL, 1);
  admins.push(admin(4, "Dora Test", "Validateur", { status: "bloque" }));
  const div = await mount("/administrateurs");
  expect(rowOf(div, 2).textContent).toContain("+237 6•• •• •• 41");
  expect(div.textContent).not.toMatch(/\+237 ?6\d{8}/);
  expect(rowOf(div, 2).textContent).toContain("Validateur");
  expect(rowOf(div, 3).textContent).toContain("Administrateur complet");
  expect(rowOf(div, 4).textContent).toContain("Bloqué");
  expect(byText(rowOf(div, 1), "button", "Changer le rôle")).toBeNull();
  expect(byText(rowOf(div, 1), "button", "Retirer le rôle")).toBeNull();
  expect(byText(rowOf(div, 2), "button", "Changer le rôle")).not.toBeNull();
});

test("création : champs obligatoires et numéro vérifiés sans requête", async () => {
  server(FULL);
  const div = await mount("/administrateurs");
  await click(byText(div, "button", "Créer un administrateur"));
  await click(dialogButton("Créer"));
  expect(dialog().textContent).toContain("Numéro invalide");
  expect(dialog().textContent).toContain("Le nom est obligatoire");
  expect(dialog().textContent).toContain("Choisissez un rôle");
  await type(field("Numéro de téléphone"), "12345");
  await type(field("Nom"), "Nouveau Test");
  await click(dialogButton("Créer"));
  expect(writes(ADMINS)).toHaveLength(0);
});

async function fillAndCreate(div: HTMLElement) {
  await click(byText(div, "button", "Créer un administrateur"));
  await type(field("Numéro de téléphone"), "6 99 00 00 00");
  await type(field("Nom"), "Nouveau Test");
  const select = field("Rôle") as unknown as HTMLSelectElement;
  await act(async () => {
    select.value = "Validateur";
    select.dispatchEvent(new Event("change", { bubbles: true }));
  });
  await click(dialogButton("Créer"));
  await wait();
}

test("création : mot de passe affiché une seule fois, puis introuvable (DOM, caches, stockage, console)", async () => {
  server(FULL);
  const spies = (["log", "info", "warn", "error", "debug"] as const).map((m) => vi.spyOn(console, m));
  writeAdmin = () => ({ status: 201, data: { ...admin(9, "Nouveau Test", "Validateur"), temporary_password: SECRET } });
  const div = await mount("/administrateurs");
  await fillAndCreate(div);

  const w = writes(ADMINS);
  expect(w).toHaveLength(1);
  expect(w[0]!.body).toEqual({ phone: "+237699000000", name: "Nouveau Test", role: "Validateur" });
  // Fenêtre dédiée, avertissement, masqué par défaut.
  expect(dialog().textContent).toContain("Notez-le maintenant, il ne sera plus affiché.");
  expect(dialog().textContent).toContain("valable jusqu'à son changement");
  expect(dialog().textContent).not.toContain(SECRET);
  await click(byText(dialog(), "button", "Afficher"));
  expect(dialog().textContent).toContain(SECRET);
  expect(document.title).not.toContain(SECRET);
  expect(window.location.href).not.toContain(SECRET);
  // Échap ne ferme pas la fenêtre (le mot de passe ne se perd pas par mégarde).
  await act(async () => {
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
  });
  expect(dialog()).not.toBeNull();

  await click(dialogButton("J'ai noté le mot de passe"));
  await wait();
  expect(dialog()).toBeNull();
  expect(document.body.innerHTML).not.toContain(SECRET);
  expect(document.body.textContent).not.toContain(SECRET);
  expect(JSON.stringify(qc.getQueryCache().getAll().map((q) => q.state.data))).not.toContain(SECRET);
  expect(JSON.stringify(qc.getMutationCache().getAll().map((m) => m.state.data))).not.toContain(SECRET);
  expect(JSON.stringify({ ...localStorage })).not.toContain(SECRET);
  expect(JSON.stringify({ ...sessionStorage })).not.toContain(SECRET);
  for (const s of spies) expect(JSON.stringify(s.mock.calls)).not.toContain(SECRET);
  // La liste a été rechargée.
  expect(calls.filter((c) => c.url === ADMINS && c.method === "get").length).toBeGreaterThanOrEqual(2);
  spies.forEach((s) => s.mockRestore());
});

test("création : Copier utilise le presse-papiers ; repli propre s'il est indisponible", async () => {
  server(FULL);
  writeAdmin = () => ({ status: 201, data: { ...admin(9, "Nouveau Test", "Validateur"), temporary_password: SECRET } });
  const writeText = vi.fn().mockResolvedValue(undefined);
  Object.defineProperty(navigator, "clipboard", { value: { writeText }, configurable: true });
  const div = await mount("/administrateurs");
  await fillAndCreate(div);
  await click(dialogButton("Copier"));
  expect(writeText).toHaveBeenCalledWith(SECRET);
  expect(dialog().textContent).toContain("copié");
  expect(dialog().textContent).not.toContain(SECRET);

  Object.defineProperty(navigator, "clipboard", { value: undefined, configurable: true });
  await click(dialogButton("Copier"));
  expect(dialog().textContent).toContain("Copie automatique impossible");
  expect(dialog().textContent).toContain(SECRET); // affiché pour copie manuelle
});

test("création : 409 phone_exists affiché sous le numéro, aucun mot de passe", async () => {
  server(FULL);
  writeAdmin = () => ({ status: 409, data: { code: "phone_exists", message: "x" } });
  const div = await mount("/administrateurs");
  await fillAndCreate(div);
  expect(dialog().textContent).toContain("appartient déjà à un compte");
  expect(dialog().textContent).toContain("pas un client");
  expect(document.querySelector('[data-testid="temporary-password"]')).toBeNull();
});

test("création : 403 et erreur réseau affichées", async () => {
  server(FULL);
  writeAdmin = () => ({ status: 403, data: { code: "forbidden", message: "x" } });
  const div = await mount("/administrateurs");
  await fillAndCreate(div);
  expect(dialog().textContent).toContain("pas le droit");
  writeAdmin = () => ({ status: 0, network: true });
  await click(dialogButton("Créer"));
  await wait();
  expect(dialog().textContent).toContain("Connexion impossible");
});

test("création : double envoi impossible", async () => {
  server(FULL);
  let release!: () => void;
  gates.set(ADMINS, new Promise<void>((r) => (release = r)));
  writeAdmin = () => ({ status: 201, data: { ...admin(9, "N", "Validateur"), temporary_password: SECRET } });
  const div = await mount("/administrateurs");
  // Le GET de la liste passe par la même porte : on la libère d'abord pour afficher la page.
  release();
  await wait();
  gates.set(ADMINS, new Promise<void>((r) => (release = r)));
  await click(byText(div, "button", "Créer un administrateur"));
  await type(field("Numéro de téléphone"), "699000000");
  await type(field("Nom"), "N");
  const select = field("Rôle") as unknown as HTMLSelectElement;
  await act(async () => {
    select.value = "Validateur";
    select.dispatchEvent(new Event("change", { bubbles: true }));
  });
  const create = dialogButton("Créer");
  await click(create);
  await click(create);
  expect(writes(ADMINS)).toHaveLength(1);
  release();
  await wait();
});

test("changement de rôle : PATCH puis liste rafraîchie ; rôle inchangé impossible", async () => {
  server(FULL);
  const div = await mount("/administrateurs");
  await click(byText(rowOf(div, 2), "button", "Changer le rôle"));
  expect(dialogButton("Changer le rôle").disabled).toBe(true);
  const select = dialog().querySelector("select") as HTMLSelectElement;
  await act(async () => {
    select.value = "Administrateur complet";
    select.dispatchEvent(new Event("change", { bubbles: true }));
  });
  const before = calls.filter((c) => c.url === ADMINS && c.method === "get").length;
  await click(dialogButton("Changer le rôle"));
  await wait();
  const w = writes(ADMINS);
  expect(w).toHaveLength(1);
  expect(w[0]).toMatchObject({ method: "patch", url: `${ADMINS}2/`, body: { role: "Administrateur complet" } });
  expect(calls.filter((c) => c.url === ADMINS && c.method === "get").length).toBe(before + 1);
  expect(dialog()).toBeNull();
});

test("retrait de rôle : sans motif impossible ; avec motif DELETE puis liste rafraîchie", async () => {
  server(FULL);
  const div = await mount("/administrateurs");
  await click(byText(rowOf(div, 2), "button", "Retirer le rôle"));
  expect(dialogButton("Retirer le rôle").disabled).toBe(true);
  await click(dialogButton("Retirer le rôle"));
  expect(writes(ADMINS)).toHaveLength(0);
  await type(dialog().querySelector("textarea") as HTMLTextAreaElement, "   ");
  expect(dialogButton("Retirer le rôle").disabled).toBe(true);
  await type(dialog().querySelector("textarea") as HTMLTextAreaElement, "Départ de l'équipe");
  const before = calls.filter((c) => c.url === ADMINS && c.method === "get").length;
  await click(dialogButton("Retirer le rôle"));
  await wait();
  const w = writes(ADMINS);
  expect(w).toHaveLength(1);
  expect(w[0]).toMatchObject({ method: "delete", url: `${ADMINS}2/`, body: { reason: "Départ de l'équipe" } });
  expect(calls.filter((c) => c.url === ADMINS && c.method === "get").length).toBe(before + 1);
});

test("last_full_admin et self_action_forbidden : messages clairs", async () => {
  server(FULL);
  writeAdmin = () => ({ status: 409, data: { code: "last_full_admin", message: "x" } });
  const div = await mount("/administrateurs");
  await click(byText(rowOf(div, 3), "button", "Retirer le rôle"));
  await type(dialog().querySelector("textarea") as HTMLTextAreaElement, "Test");
  await click(dialogButton("Retirer le rôle"));
  await wait();
  expect(document.body.textContent).toContain("dernier Administrateur complet actif");

  writeAdmin = () => ({ status: 400, data: { code: "self_action_forbidden", message: "x" } });
  await click(dialogButton("Retirer le rôle"));
  await wait();
  expect(document.body.textContent).toContain("Vous ne pouvez pas agir sur votre propre compte");
});
