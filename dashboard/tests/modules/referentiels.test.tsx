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
import { calls, gates, handler, resetServer, setHandler, type Call, type Reply } from "../auth/fakeServer";
import { byText, cleanup, click, render, type } from "../components/helpers";

// Données FICTIVES.
const BASE = "/api/admin/referentials/";
const FULL = ["peut_voir_comptes", "peut_voir_demandes", "peut_gerer_referentiels"];
const VALIDATEUR = ["peut_voir_comptes", "peut_voir_demandes", "peut_valider_demande"];
const NOW = "2026-01-01T00:00:00Z";

const item = (id: number, name: string, over: Record<string, unknown> = {}) => ({
  id,
  code: `code_${id}`,
  name,
  icon: "",
  order: id,
  is_active: true,
  updated_at: NOW,
  ...over,
});
const zone = (id: number, name: string, level: string, parent: number | null, over: Record<string, unknown> = {}) => ({
  id,
  name,
  level,
  parent,
  parent_name: null,
  official_code: "",
  order: 0,
  latitude: null,
  longitude: null,
  is_active: true,
  active_children_count: 1,
  updated_at: NOW,
  ...over,
});

let lists: Record<string, unknown[]>;
let totals: Record<string, number>;
let write: (c: Call) => Reply;
let listStatus: number;
let freeValues: unknown;

function server(permissions: string[]) {
  const me = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return { status: 200, data: { pending_requests: 0 } };
    if (c.url === BASE + "free-values/") return { status: 200, data: freeValues };
    if (c.url.startsWith(BASE)) {
      const type = c.url.slice(BASE.length).split("/")[0]!;
      if (c.method === "get") {
        if (listStatus !== 200) return { status: listStatus, data: { code: "server_error", message: "x" } };
        let results = lists[type] ?? [];
        if (type === "zones" && c.params?.parent !== undefined) {
          const parent = c.params.parent === "root" ? null : Number(c.params.parent);
          results = (results as Array<{ parent: number | null }>).filter((z) => z.parent === parent);
        }
        return { status: 200, data: { count: totals[type] ?? results.length, next: null, results } };
      }
      return write(c);
    }
    return { status: 404 };
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

const posts = () => calls.filter((c) => c.method === "post" && c.url.startsWith(BASE));
const refCalls = () => calls.filter((c) => c.url.startsWith(BASE));
const lastGet = (type: string) => calls.filter((c) => c.url === `${BASE}${type}/` && c.method === "get").at(-1)!;
const dialog = () => document.querySelector("[role=dialog]") as HTMLElement;
const dialogButton = (label: string) => byText(dialog(), "button", label) as HTMLButtonElement;
const field = (label: string) => {
  const l = Array.from(dialog().querySelectorAll("label")).find((e) => e.textContent === label)!;
  return dialog().querySelector(`#${CSS.escape(l.getAttribute("for")!)}`) as HTMLInputElement;
};
const rowOf = (div: HTMLElement, id: number) => div.querySelector(`[data-testid="ref-row-${id}"]`)!.closest("tr") as HTMLElement;
const rowButton = (tr: HTMLElement, label: string) => byText(tr, "button", label) as HTMLButtonElement;

beforeEach(() => {
  resetServer();
  clearAccessToken();
  localStorage.clear();
  sessionStorage.clear();
  listStatus = 200;
  totals = {};
  lists = {
    sectors: [item(1, "Alimentation", { active_children_count: 2 }), item(2, "Mode", { is_active: false }), item(3, "Autre", { code: "autre" })],
    products: [{ id: 10, name: "Riz", category: 4, category_name: "Céréales", synonyms_count: 2, is_active: true, updated_at: NOW }],
    synonyms: [{ id: 20, term: "Riz blanc", product: 10, product_name: "Riz", is_active: true, updated_at: NOW }],
    subcategories: [item(4, "Céréales", { sector: 1 })],
    zones: [
      zone(1, "Pays Test", "pays", null),
      zone(2, "Région Test", "region", 1),
      zone(3, "Département Test", "departement", 2),
      zone(4, "Région Vide", "region", 1, { is_active: false }),
    ],
  };
  freeValues = {
    secteur_libre: [{ value: "Quincaillerie", normalized: "quincaillerie", count: 7 }],
    categorie_service_libre: [],
    structure_type_libre: [{ value: "Kiosque", normalized: "kiosque", count: 3 }],
  };
  write = () => ({ status: 200, data: item(1, "x") });
});
afterEach(cleanup);

test("index : les 7 sections et À examiner ; une seule entrée « Référentiels » dans la barre latérale", async () => {
  server(FULL);
  const div = await mount("/referentiels");
  const main = div.querySelector("main")!;
  for (const t of ["Zones", "Secteurs", "Sous-catégories", "Catégories de service", "Types de structure", "Produits du catalogue", "Synonymes", "À examiner"]) {
    expect(main.querySelectorAll("h3").length).toBe(8);
    expect(Array.from(main.querySelectorAll("h3")).map((h) => h.textContent)).toContain(t);
  }
  const nav = Array.from(div.querySelectorAll("aside nav > *")).map((e) => e.textContent);
  expect(nav.filter((t) => t === "Référentiels")).toHaveLength(1);
  expect(refCalls()).toHaveLength(0);
});

test("zones : arbre chargé niveau par niveau avec le filtre parent, dépliage et repliage", async () => {
  server(FULL);
  const div = await mount("/referentiels/zones");
  expect(lastGet("zones").params).toMatchObject({ parent: "root" });
  expect(div.querySelector('[data-testid="zone-1"]')?.textContent).toContain("Pays Test");
  expect(div.querySelector('[data-testid="zone-2"]')).toBeNull();
  const before = calls.filter((c) => c.url === `${BASE}zones/`).length;

  await click(div.querySelector('[aria-label="Déplier Pays Test"]'));
  await wait();
  expect(calls.filter((c) => c.url === `${BASE}zones/`).length).toBe(before + 1);
  expect(lastGet("zones").params).toMatchObject({ parent: 1 });
  expect(div.querySelector('[data-testid="zone-2"]')?.textContent).toContain("Région Test");
  expect(div.querySelector('[data-testid="zone-4"]')?.closest("li")?.textContent).toContain("Désactivé");
  expect(div.querySelector('[data-testid="zone-3"]')).toBeNull();

  await click(div.querySelector('[aria-label="Déplier Région Test"]'));
  await wait();
  expect(lastGet("zones").params).toMatchObject({ parent: 2 });
  expect(div.querySelector('[data-testid="zone-3"]')?.textContent).toContain("Département Test");

  await click(div.querySelector('[aria-label="Replier Pays Test"]'));
  expect(div.querySelector('[data-testid="zone-2"]')).toBeNull();
});

test("zones : ajouter une zone enfant impose le parent et propose les niveaux permis", async () => {
  server(FULL);
  write = () => ({ status: 201, data: zone(9, "Région Neuve", "region", 1) });
  const div = await mount("/referentiels/zones");
  await click(div.querySelector('[aria-label="Ajouter une zone dans Pays Test"]'));
  expect(dialog().querySelector('[data-testid="zone-parent"]')?.textContent).toContain("Pays Test");
  const level = dialog().querySelector("select") as HTMLSelectElement;
  expect(Array.from(level.options).map((o) => o.textContent)).toEqual(["Région"]);
  await type(field("Nom"), "Région Neuve");
  await click(dialogButton("Ajouter"));
  await wait();
  const post = posts().find(() => true)!;
  expect(post.url).toBe(`${BASE}zones/`);
  expect(post.body).toEqual({ level: "region", name: "Région Neuve", parent: 1 });
  expect(dialog()).toBeNull();
});

test("zones : la recherche passe en liste à plat (niveau, rattachement) ; le niveau n'est pas modifiable", async () => {
  server(FULL);
  const div = await mount("/referentiels/zones");
  await type(div.querySelector('input[aria-label="Rechercher une zone"]') as HTMLInputElement, "Rég");
  await wait(40);
  expect(lastGet("zones").params).toMatchObject({ q: "Rég", page: 1 });
  expect(div.querySelector("main table")).not.toBeNull();
  await click(rowButton(rowOf(div, 2), "Modifier"));
  expect(dialog().textContent).toContain("Niveau :");
  expect(dialog().querySelector("select")).toBeNull();
});

test("création : succès (corps envoyé, message, liste rechargée)", async () => {
  server(FULL);
  write = () => ({ status: 201, data: item(9, "Pêche") });
  const div = await mount("/referentiels/sectors");
  await click(byText(div, "button", "Ajouter un secteur"));
  await type(field("Code"), "peche");
  await type(field("Nom"), "Pêche");
  const gets = calls.filter((c) => c.method === "get" && c.url === `${BASE}sectors/`).length;
  await click(dialogButton("Ajouter"));
  await wait();
  const post = posts().find(() => true)!;
  expect(post.url).toBe(`${BASE}sectors/`);
  expect(post.body).toEqual({ code: "peche", name: "Pêche" });
  expect(document.body.textContent).toContain("Élément ajouté");
  expect(dialog()).toBeNull();
  expect(calls.filter((c) => c.method === "get" && c.url === `${BASE}sectors/`).length).toBeGreaterThan(gets);
});

test("création : 409 already_exists affiché sur le champ nom, fenêtre conservée", async () => {
  server(FULL);
  write = () => ({ status: 409, data: { code: "already_exists", message: "existe" } });
  const div = await mount("/referentiels/sectors");
  await click(byText(div, "button", "Ajouter un secteur"));
  await type(field("Code"), "mode");
  await type(field("Nom"), "Mode");
  await click(dialogButton("Ajouter"));
  await wait();
  const nameField = field("Nom");
  expect(nameField.getAttribute("aria-invalid")).toBe("true");
  expect(dialog().querySelector(`#${CSS.escape(nameField.id)}-erreur`)?.textContent).toBe("Un élément portant ce nom ou ce code existe déjà.");
  expect(dialog()).not.toBeNull();
});

test("création : validation côté client (nom vide, code incorrect, nom trop long) sans requête", async () => {
  server(FULL);
  const div = await mount("/referentiels/sectors");
  await click(byText(div, "button", "Ajouter un secteur"));
  await click(dialogButton("Ajouter"));
  expect(dialog().textContent).toContain("Nom : champ obligatoire.");
  expect(dialog().textContent).toContain("Code : champ obligatoire.");
  await type(field("Code"), "Pas Bon");
  await type(field("Nom"), "x".repeat(101));
  await click(dialogButton("Ajouter"));
  expect(dialog().textContent).toContain("Le code ne contient que des minuscules");
  expect(dialog().textContent).toContain("Nom : 100 caractères au plus.");
  expect(posts().length > 0).toBe(false);
});

test("création : pas de double envoi", async () => {
  server(FULL);
  write = () => ({ status: 201, data: item(9, "Pêche") });
  const div = await mount("/referentiels/sectors");
  await click(byText(div, "button", "Ajouter un secteur"));
  await type(field("Code"), "peche");
  await type(field("Nom"), "Pêche");
  let release!: () => void;
  gates.set(`${BASE}sectors/`, new Promise<void>((r) => (release = r)));
  const submit = dialogButton("Ajouter");
  await click(submit);
  await click(submit);
  await click(submit);
  release();
  gates.clear();
  await wait();
  expect(posts()).toHaveLength(1);
});

test("modification : seuls les champs changés partent (PATCH) ; le code n'est pas modifiable", async () => {
  server(FULL);
  write = () => ({ status: 200, data: item(1, "Alimentation générale") });
  const div = await mount("/referentiels/sectors");
  await click(rowButton(rowOf(div, 1), "Modifier"));
  expect(Array.from(dialog().querySelectorAll("label")).map((l) => l.textContent)).not.toContain("Code");
  expect(dialog().textContent).toContain("code_1");
  expect((field("Nom") as HTMLInputElement).value).toBe("Alimentation");
  await type(field("Nom"), "Alimentation générale");
  await click(dialogButton("Enregistrer"));
  await wait();
  const patch = calls.find((c) => c.method === "patch")!;
  expect(patch.url).toBe(`${BASE}sectors/1/`);
  expect(patch.body).toEqual({ name: "Alimentation générale" });
  expect(document.body.textContent).toContain("Modification enregistrée");
});

test("désactivation : confirmation, motif facultatif envoyé ; réactivation avec confirmation simple", async () => {
  server(FULL);
  const div = await mount("/referentiels/sectors");
  await click(rowButton(rowOf(div, 1), "Désactiver"));
  expect(dialog().textContent).toContain("Motif (facultatif)");
  await type(dialog().querySelector("textarea") as HTMLTextAreaElement, "Doublon");
  await click(dialogButton("Désactiver"));
  await wait();
  const off = posts().find(() => true)!;
  expect(off.url).toBe(`${BASE}sectors/1/deactivate/`);
  expect(off.body).toEqual({ reason: "Doublon" });
  expect(document.body.textContent).toContain("Élément désactivé");

  // Sans motif : permis.
  await click(rowButton(rowOf(div, 3), "Désactiver"));
  await click(dialogButton("Désactiver"));
  await wait();
  expect(posts()[1]!.body).toEqual({});

  await click(rowButton(rowOf(div, 2), "Réactiver"));
  expect(dialog().querySelector("textarea")).toBeNull();
  await click(dialogButton("Réactiver"));
  await wait();
  const on = posts()[2]!;
  expect(on.url).toBe(`${BASE}sectors/2/reactivate/`);
  expect(document.body.textContent).toContain("Élément réactivé");
});

test("désactivation : erreurs 409 has_active_children, protected_item, parent_inactive, invalid_state", async () => {
  server(FULL);
  const div = await mount("/referentiels/sectors");
  const cases: Array<[string, string, string, number]> = [
    ["has_active_children", "Désactivez d'abord les éléments enfants.", "Désactiver", 1],
    ["protected_item", "La ligne « Autre » est protégée", "Désactiver", 3],
    ["parent_inactive", "Le parent est désactivé", "Réactiver", 2],
  ];
  for (const [code, text, label, id] of cases) {
    write = () => ({ status: 409, data: { code, message: "x" } });
    await click(rowButton(rowOf(div, id), label));
    await click(dialogButton(label));
    await wait();
    expect(document.body.textContent).toContain(text);
  }
  write = () => ({ status: 409, data: { code: "invalid_state", message: "x" } });
  const gets = calls.filter((c) => c.method === "get" && c.url === `${BASE}sectors/`).length;
  await click(rowButton(rowOf(div, 1), "Désactiver"));
  await click(dialogButton("Désactiver"));
  await wait();
  expect(document.body.textContent).toContain("L'état de cet élément a changé");
  expect(dialog()).toBeNull();
  expect(calls.filter((c) => c.method === "get" && c.url === `${BASE}sectors/`).length).toBeGreaterThan(gets);
});

test("aucune suppression : pas de bouton « Supprimer » ni de requête DELETE, dans aucune section", async () => {
  server(FULL);
  for (const type of ["zones", "sectors", "subcategories", "service-categories", "structure-types", "products", "synonyms"]) {
    const div = await mount(`/referentiels/${type}`);
    expect(Array.from(div.querySelectorAll("button")).some((b) => /suppr/i.test(`${b.textContent} ${b.getAttribute("aria-label")}`))).toBe(false);
    await cleanup();
  }
  const div = await mount("/referentiels/sectors");
  await click(rowButton(rowOf(div, 1), "Désactiver"));
  await click(dialogButton("Désactiver"));
  await wait();
  expect(calls.some((c) => c.method === "delete")).toBe(false);
});

test("droits : un Validateur voit « Accès refusé », aucune requête, et pas d'entrée de menu", async () => {
  server(VALIDATEUR);
  for (const path of ["/referentiels", "/referentiels/sectors", "/referentiels/a-examiner", "/referentiels/zones"]) {
    const div = await mount(path);
    expect(div.querySelector("main")!.textContent).toContain("Accès refusé");
    expect(div.querySelector("aside")!.textContent).not.toContain("Référentiels");
    await cleanup();
  }
  expect(refCalls()).toHaveLength(0);
});

test("liste : colonnes, filtre actif/inactif, recherche, filtre propre au type", async () => {
  server(FULL);
  const div = await mount("/referentiels/products");
  expect(Array.from(div.querySelectorAll("main th")).map((t) => t.textContent)).toEqual(["Nom", "Sous-catégorie", "Synonymes", "État", "Actions"]);
  expect(lastGet("products").params).toEqual({ page: 1, page_size: 20 });
  await click(byText(div, "button", "Désactivés"));
  await wait();
  expect(lastGet("products").params).toMatchObject({ is_active: false, page: 1 });
  await click(byText(div, "button", "Actifs"));
  await wait();
  expect(lastGet("products").params).toMatchObject({ is_active: true });
  await type(div.querySelector('input[aria-label="Rechercher un produit"]') as HTMLInputElement, "riz");
  await wait(40);
  expect(lastGet("products").params).toMatchObject({ q: "riz", page: 1 });
  const sub = div.querySelector('select[id$="-select"]') as HTMLSelectElement;
  await act(async () => {
    sub.value = "4";
    sub.dispatchEvent(new Event("change", { bubbles: true }));
  });
  await wait();
  expect(lastGet("products").params).toMatchObject({ category: 4, page: 1 });
});

test("synonymes : le produit est fixé à la création, non modifiable ensuite", async () => {
  server(FULL);
  write = () => ({ status: 201, data: lists.synonyms![0] });
  const div = await mount("/referentiels/synonyms");
  await click(rowButton(rowOf(div, 20), "Modifier"));
  expect(dialog().textContent).toContain("Produit :");
  expect(dialog().querySelector("select")).toBeNull();
  await click(dialogButton("Annuler"));
  await click(byText(div, "button", "Ajouter un synonyme"));
  await type(field("Synonyme"), "Riz local");
  await click(dialogButton("Ajouter"));
  expect(dialog().textContent).toContain("Produit : choisissez une valeur.");
  const pick = dialog().querySelector("select") as HTMLSelectElement;
  await act(async () => {
    pick.value = "10";
    pick.dispatchEvent(new Event("change", { bubbles: true }));
  });
  expect(lastGet("products").params).toMatchObject({ is_active: true });
  await click(dialogButton("Ajouter"));
  await wait();
  expect(posts().find(() => true)!.body).toEqual({ product: 10, term: "Riz local" });
});

test("pagination : page suivante demandée au serveur", async () => {
  server(FULL);
  totals = { products: 45 };
  const div = await mount("/referentiels/products");
  expect(div.textContent).toContain("Page 1 sur 3");
  await click(byText(div, "button", "Suivant"));
  await wait();
  expect(lastGet("products").params).toMatchObject({ page: 2, page_size: 20 });
  expect(div.textContent).toContain("Page 2 sur 3");
});

test("erreur de chargement : message et Réessayer", async () => {
  server(FULL);
  listStatus = 500;
  const div = await mount("/referentiels/sectors");
  expect(div.querySelector("main [role=alert]")?.textContent).toContain("Impossible de charger la liste.");
  listStatus = 200;
  await click(byText(div, "button", "Réessayer"));
  await wait();
  expect(div.textContent).toContain("Alimentation");
});

test("liste vide : message clair", async () => {
  server(FULL);
  lists.sectors = [];
  const div = await mount("/referentiels/sectors");
  expect(div.textContent).toContain("Aucun élément");
});

test("À examiner : valeurs libres avec fréquence ; « Ajouter comme officiel » pré-remplit la création", async () => {
  server(FULL);
  const div = await mount("/referentiels/a-examiner");
  expect(calls.filter((c) => c.url === BASE + "free-values/")).toHaveLength(1);
  expect(div.textContent).toContain("Quincaillerie");
  expect(div.textContent).toContain("7");
  expect(div.textContent).toContain("Kiosque");
  expect(div.textContent).toContain("Aucune valeur à examiner");
  await click(div.querySelector('[aria-label="Ajouter « Quincaillerie » comme officiel"]'));
  await wait();
  expect(dialog().querySelector("h2")?.textContent).toBe("Ajouter un secteur");
  expect(field("Nom").value).toBe("Quincaillerie");
  expect(field("Code").value).toBe("quincaillerie");
  expect(posts().length > 0).toBe(false);
});

test("À examiner : erreur avec Réessayer", async () => {
  server(FULL);
  const ok = handler;
  setHandler((c) => (c.url === BASE + "free-values/" ? { status: 500 } : ok(c)));
  const div = await mount("/referentiels/a-examiner");
  expect(div.querySelector("main [role=alert]")?.textContent).toContain("Impossible de charger les valeurs à examiner.");
  expect(byText(div, "button", "Réessayer")).not.toBeNull();
});

test("type inconnu : message, aucune requête", async () => {
  server(FULL);
  const div = await mount("/referentiels/inconnu");
  expect(div.querySelector("main")!.textContent).toContain("Cette section n'existe pas.");
  expect(refCalls()).toHaveLength(0);
});
