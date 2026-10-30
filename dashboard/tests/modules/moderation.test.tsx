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
import { validateWord } from "../../src/modules/forum_moderation/components/ForbiddenWords";
import { calls, gates, resetServer, setHandler, type Call, type Reply } from "../auth/fakeServer";
import { byText, cleanup, click, render, type } from "../components/helpers";

// Données FICTIVES.
const REPORTS = "/api/admin/reports/";
const WORDS = "/api/admin/forbidden-words/";
const FULL = ["peut_voir_comptes", "peut_voir_demandes", "peut_moderer_contenu"];
const VALIDATEUR = ["peut_voir_comptes", "peut_voir_demandes", "peut_valider_demande"];
const ISO = "2026-10-20T10:30:00Z";

const row = (id: number, over: Record<string, unknown> = {}) => ({
  target_type: "post", target_id: id, content_status: "actif", preview: `Texte du message ${id}`, media_type: null, post_id: null,
  business_id: 5, business_name: "Boutique Test", author_id: 9, author_name: "Awa Test", author_phone_masked: "+237 6•• •• •• 41",
  reasons: [{ reason: "spam", count: 2 }, { reason: "arnaque", count: 1 }], reporters_count: 3, first_reported_at: ISO, last_reported_at: ISO, ...over,
});

let rows: unknown[];
let total: number;
let words: Array<{ id: number; word: string; created_at: string }>;
let reply: ((c: Call) => Reply | null) | null;

function server(permissions: string[]) {
  const me = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return { status: 200, data: { pending_requests: 0 } };
    const custom = reply?.(c);
    if (custom) return custom;
    if (c.url === REPORTS) {
      const p = Number(c.params?.page ?? 1);
      if (p > Math.max(1, Math.ceil(total / 20))) return { status: 404, data: { detail: "Invalid page." } };
      return { status: 200, data: { count: total, next: null, results: rows } };
    }
    if (c.method === "post" && c.url.startsWith(REPORTS)) return { status: 200, data: row(1) };
    if (c.url === WORDS && c.method === "get") return { status: 200, data: { count: words.length, next: null, results: words } };
    if (c.url === WORDS && c.method === "post") {
      const w = (c.body as { word: string }).word;
      const created = { id: 100 + words.length, word: w.toLowerCase(), created_at: ISO };
      words = [...words, created];
      return { status: 201, data: created };
    }
    if (c.url.startsWith(WORDS) && c.method === "delete") {
      const id = Number(c.url.slice(WORDS.length).replace("/", ""));
      words = words.filter((w) => w.id !== id);
      return { status: 204 };
    }
    return { status: 404 };
  });
}

async function wait(n = 4) {
  for (let i = 0; i < n; i++) await act(async () => new Promise((r) => setTimeout(r, 15)));
}

async function mount(path = "/moderation") {
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

const reportCalls = () => calls.filter((c) => c.url === REPORTS);
const posts = () => calls.filter((c) => c.method === "post" && c.url.startsWith(REPORTS));
const dialog = () => document.querySelector('[role="dialog"]') as HTMLElement;
const firstRow = (div: HTMLElement) => div.querySelector("tbody tr") as HTMLElement;
const btn = (root: ParentNode, text: string) => byText(root, "button", text) as HTMLButtonElement | null;

beforeEach(() => {
  resetServer();
  clearAccessToken();
  localStorage.clear();
  sessionStorage.clear();
  rows = [row(1)];
  total = 1;
  words = [{ id: 1, word: "arnaque", created_at: ISO }];
  reply = null;
});
afterEach(cleanup);

test("file : colonnes, cible, aperçu, auteur masqué, motifs avec compteur, signalants, statut", async () => {
  server(FULL);
  const div = await mount();
  const heads = Array.from(div.querySelectorAll("th")).map((h) => h.textContent);
  expect(heads).toEqual(["Cible", "Aperçu", "Auteur", "Motifs", "Signalants", "Statut", "Actions"]);
  const tr = firstRow(div);
  const cells = Array.from(tr.querySelectorAll("td")).map((c) => c.textContent);
  expect(cells[0]).toBe("Publication");
  expect(cells[1]).toContain("Texte du message 1");
  expect(cells[2]).toContain("Awa Test");
  expect(cells[2]).toContain("+237 6•• •• •• 41");
  expect(cells[3]).toContain("Spam ×2");
  expect(cells[3]).toContain("Arnaque ×1");
  expect(cells[4]).toBe("3");
  expect(cells[5]).toBe("Actif");
  expect(div.querySelector("h2")?.textContent).toBe("Modération");
  expect(reportCalls()[0]!.params).toEqual({ page: 1, page_size: 20 });
});

test("état vide : « Aucun signalement en attente »", async () => {
  server(FULL);
  rows = [];
  total = 0;
  const div = await mount();
  expect(div.textContent).toContain("Aucun signalement en attente");
});

test("aperçu en texte simple : les balises sont affichées telles quelles, aucun média chargé", async () => {
  server(FULL);
  rows = [row(1, { preview: '<img src="http://externe.invalide/x.png" onerror="alert(1)"><b>gras</b>', media_type: "image" })];
  const div = await mount();
  const tr = firstRow(div);
  expect(tr.textContent).toContain('<img src="http://externe.invalide/x.png" onerror="alert(1)"><b>gras</b>');
  expect(tr.textContent).toContain("Photo jointe");
  expect(div.querySelector("tbody img, tbody video, tbody b")).toBeNull();
});

test("aperçu trop long : tronqué", async () => {
  server(FULL);
  rows = [row(1, { preview: "x".repeat(300) })];
  const div = await mount();
  expect(div.querySelectorAll("tbody td")[1]!.textContent!.length).toBeLessThan(160);
});

test("filtres statut et type envoyés au serveur, retour à la page 1", async () => {
  server(FULL);
  const div = await mount();
  await click(btn(div, "Masqués"));
  await wait();
  expect(reportCalls().at(-1)!.params).toMatchObject({ status: "masque", page: 1 });
  await click(btn(div, "Commentaires"));
  await wait();
  expect(reportCalls().at(-1)!.params).toMatchObject({ status: "masque", type: "comment" });
  await click(div.querySelector('[aria-label="Filtrer par type"] button')!);
  await wait();
  expect(reportCalls().at(-1)!.params).toMatchObject({ status: "masque" });
  expect(reportCalls().at(-1)!.params).not.toHaveProperty("type");
});

test("actions par statut : actif, masqué, supprimé", async () => {
  server(FULL);
  rows = [row(1), row(2, { content_status: "masque" }), row(3, { content_status: "supprime" })];
  total = 3;
  const div = await mount();
  const trs = div.querySelectorAll("tbody tr");
  const labels = (i: number) => Array.from(trs[i]!.querySelectorAll("button")).map((b) => b.textContent);
  expect(labels(0)).toEqual(["Masquer", "Supprimer"]);
  expect(labels(1)).toEqual(["Restaurer", "Supprimer"]);
  expect(labels(2)).toEqual([]);
  expect(trs[1]!.textContent).toContain("Masqué");
  expect(trs[2]!.textContent).toContain("Supprimé");
});

test("commerce : aucune action de masquage, message et lien vers /comptes", async () => {
  server(FULL);
  rows = [row(1, { target_type: "business", target_id: 5, content_status: "actif" })];
  const div = await mount();
  const tr = firstRow(div);
  expect(tr.querySelectorAll("button")).toHaveLength(0);
  expect(tr.textContent).toContain("Utilisez la page Comptes pour bloquer ce commerce");
  expect(tr.querySelector("a")!.getAttribute("href")).toBe("/comptes");
  expect(tr.textContent).toContain("Commerce");
});

test("masquer : confirmation avec motif facultatif, requête, rafraîchissement de la file", async () => {
  server(FULL);
  const div = await mount();
  await click(btn(firstRow(div), "Masquer"));
  expect(dialog().textContent).toContain("Masquer le contenu");
  expect(posts()).toHaveLength(0);
  const before = reportCalls().length;
  await click(btn(dialog(), "Masquer"));
  await wait();
  expect(posts()).toHaveLength(1);
  expect(posts()[0]!.url).toBe("/api/admin/reports/post/1/hide/");
  expect(posts()[0]!.body).toEqual({});
  expect(reportCalls().length).toBeGreaterThan(before);
  expect(document.querySelector('[role="dialog"]')).toBeNull();
});

test("masquer avec motif : le motif est envoyé", async () => {
  server(FULL);
  const div = await mount();
  await click(btn(firstRow(div), "Masquer"));
  await type(dialog().querySelector("textarea")!, "  Publicité répétée  ");
  await click(btn(dialog(), "Masquer"));
  await wait();
  expect(posts()[0]!.body).toEqual({ reason: "Publicité répétée" });
});

test("restaurer un contenu masqué : requête restore", async () => {
  server(FULL);
  rows = [row(2, { target_type: "comment", content_status: "masque" })];
  const div = await mount();
  await click(btn(firstRow(div), "Restaurer"));
  await click(btn(dialog(), "Restaurer"));
  await wait();
  expect(posts()[0]!.url).toBe("/api/admin/reports/comment/2/restore/");
});

test("supprimer sans motif impossible : bouton désactivé, aucune requête", async () => {
  server(FULL);
  const div = await mount();
  await click(btn(firstRow(div), "Supprimer"));
  const confirm = btn(dialog(), "Supprimer")!;
  expect(confirm.disabled).toBe(true);
  await click(confirm);
  await type(dialog().querySelector("textarea")!, "   ");
  expect(btn(dialog(), "Supprimer")!.disabled).toBe(true);
  expect(posts()).toHaveLength(0);
});

test("supprimer avec motif : requête delete avec le motif", async () => {
  server(FULL);
  const div = await mount();
  await click(btn(firstRow(div), "Supprimer"));
  await type(dialog().querySelector("textarea")!, "Arnaque avérée");
  await click(btn(dialog(), "Supprimer"));
  await wait();
  expect(posts()).toHaveLength(1);
  expect(posts()[0]!.url).toBe("/api/admin/reports/post/1/delete/");
  expect(posts()[0]!.body).toEqual({ reason: "Arnaque avérée" });
});

test("double clic : une seule requête", async () => {
  server(FULL);
  let open!: () => void;
  gates.set("/api/admin/reports/post/1/hide/", new Promise<void>((r) => (open = r)));
  const div = await mount();
  await click(btn(firstRow(div), "Masquer"));
  const confirm = btn(dialog(), "Masquer")!;
  await click(confirm);
  await click(confirm);
  await click(confirm);
  expect(posts()).toHaveLength(1);
  open();
  await wait();
  expect(posts()).toHaveLength(1);
});

test("409 invalid_state : message et file actualisée", async () => {
  server(FULL);
  reply = (c) => (c.method === "post" && c.url.startsWith(REPORTS) ? { status: 409, data: { code: "invalid_state" } } : null);
  const div = await mount();
  const before = reportCalls().length;
  await click(btn(firstRow(div), "Masquer"));
  await click(btn(dialog(), "Masquer"));
  await wait();
  expect(document.body.textContent).toContain("Le statut de ce contenu a changé entre-temps");
  expect(reportCalls().length).toBeGreaterThan(before);
  expect(document.querySelector('[role="dialog"]')).toBeNull();
});

test("404 : contenu disparu, file actualisée", async () => {
  server(FULL);
  reply = (c) => (c.method === "post" && c.url.startsWith(REPORTS) ? { status: 404, data: { code: "not_found" } } : null);
  const div = await mount();
  const before = reportCalls().length;
  await click(btn(firstRow(div), "Masquer"));
  await click(btn(dialog(), "Masquer"));
  await wait();
  expect(document.body.textContent).toContain("Ce contenu n'existe plus");
  expect(reportCalls().length).toBeGreaterThan(before);
});

test("403 et réseau : message, la fenêtre reste ouverte", async () => {
  server(FULL);
  let net = false;
  reply = (c) => (c.method === "post" && c.url.startsWith(REPORTS) ? (net ? { status: 0, network: true } : { status: 403, data: {} }) : null);
  const div = await mount();
  await click(btn(firstRow(div), "Masquer"));
  await click(btn(dialog(), "Masquer"));
  await wait();
  expect(document.body.textContent).toContain("Vous n'avez pas le droit de modérer le contenu");
  expect(dialog()).not.toBeNull();
  net = true;
  await click(btn(dialog(), "Masquer"));
  await wait();
  expect(document.body.textContent).toContain("Connexion impossible");
});

test("400 reason_required du serveur : message clair", async () => {
  server(FULL);
  reply = (c) => (c.method === "post" && c.url.startsWith(REPORTS) ? { status: 400, data: { code: "reason_required" } } : null);
  const div = await mount();
  await click(btn(firstRow(div), "Supprimer"));
  await type(dialog().querySelector("textarea")!, "Motif");
  await click(btn(dialog(), "Supprimer"));
  await wait();
  expect(document.body.textContent).toContain("Le motif est obligatoire");
});

test("erreur de chargement de la file : message et Réessayer", async () => {
  server(FULL);
  let fail = true;
  reply = (c) => (c.url === REPORTS && fail ? { status: 500, data: {} } : null);
  const div = await mount();
  expect(div.querySelector('[role="alert"]')!.textContent).toContain("Impossible de charger les signalements");
  fail = false;
  await click(btn(div, "Réessayer"));
  await wait();
  expect(firstRow(div).textContent).toContain("Texte du message 1");
});

test("pagination : page suivante, puis repli quand la page n'existe plus", async () => {
  server(FULL);
  total = 45;
  rows = [row(1)];
  const div = await mount();
  expect(div.textContent).toContain("Page 1 sur 3");
  await click(btn(div, "Suivant"));
  await wait();
  await click(btn(div, "Suivant"));
  await wait();
  expect(div.textContent).toContain("Page 3 sur 3");
  expect(reportCalls().at(-1)!.params).toMatchObject({ page: 3 });
  total = 21; // la file a diminué : la page 3 n'existe plus
  await click(btn(div, "Précédent"));
  await wait();
  await click(btn(div, "Suivant"));
  await wait(8);
  expect(div.textContent).toContain("Page 2 sur 2");
  expect(div.textContent).toContain("Texte du message 1");
});

test("mots interdits : liste, ajout (requête), doublon 409, validation 2 à 60", async () => {
  server(FULL);
  const div = await mount();
  const section = div.querySelector('section[aria-label="Mots interdits"]') as HTMLElement;
  expect(section.textContent).toContain("arnaque");
  const input = section.querySelector("input")!;
  await type(input, "a");
  await click(btn(section, "Ajouter"));
  expect(section.textContent).toContain("2 à 60 caractères");
  expect(calls.filter((c) => c.url === WORDS && c.method === "post")).toHaveLength(0);
  await type(input, "Gratuit");
  await click(btn(section, "Ajouter"));
  await wait();
  const added = calls.filter((c) => c.url === WORDS && c.method === "post");
  expect(added).toHaveLength(1);
  expect(added[0]!.body).toEqual({ word: "Gratuit" });
  expect(section.textContent).toContain("gratuit");
  reply = (c) => (c.url === WORDS && c.method === "post" ? { status: 409, data: { code: "word_exists" } } : null);
  await type(input, "gratuit");
  await click(btn(section, "Ajouter"));
  await wait();
  expect(section.textContent).toContain("Ce mot est déjà dans la liste");
});

test("validateWord : bornes 2 et 60", () => {
  expect(validateWord("a").error).toBeDefined();
  expect(validateWord("  ab ").word).toBe("ab");
  expect(validateWord("ab").error).toBeUndefined();
  expect(validateWord("x".repeat(60)).error).toBeUndefined();
  expect(validateWord("x".repeat(61)).error).toBeDefined();
  expect(validateWord("    ").error).toBeDefined();
});

test("mots interdits : suppression avec confirmation (annuler = aucune requête)", async () => {
  server(FULL);
  const div = await mount();
  const section = div.querySelector('section[aria-label="Mots interdits"]') as HTMLElement;
  await click(section.querySelector('[aria-label="Retirer le mot arnaque"]'));
  expect(dialog().textContent).toContain("arnaque");
  await click(btn(dialog(), "Annuler"));
  expect(calls.filter((c) => c.method === "delete")).toHaveLength(0);
  await click(section.querySelector('[aria-label="Retirer le mot arnaque"]'));
  await click(btn(dialog(), "Retirer"));
  await wait();
  expect(calls.filter((c) => c.method === "delete").map((c) => c.url)).toEqual(["/api/admin/forbidden-words/1/"]);
  expect(section.textContent).toContain("Aucun mot interdit");
});

test("droits : le Validateur voit « Accès refusé » et aucune requête de modération ; entrée de menu masquée", async () => {
  server(VALIDATEUR);
  const div = await mount();
  expect(div.textContent).toContain("Accès refusé");
  expect(calls.filter((c) => c.url === REPORTS || c.url === WORDS)).toHaveLength(0);
  const labels = Array.from(div.querySelectorAll("nav a")).map((a) => a.textContent);
  expect(labels).not.toContain("Modération");
});

test("droits : l'Administrateur complet voit l'entrée « Modération »", async () => {
  server(FULL);
  const div = await mount();
  const link = Array.from(div.querySelectorAll("nav a")).find((a) => a.textContent === "Modération")!;
  expect(link.getAttribute("href")).toBe("/moderation");
});

test("aucune identité de signalant ni numéro complet à l'écran", async () => {
  server(FULL);
  rows = [row(1, { reporters: [{ id: 77, name: "Signalant Secret", phone: "+237 677 00 00 00" }] })];
  const div = await mount();
  expect(div.textContent).not.toContain("Signalant Secret");
  expect(div.textContent).not.toContain("677 00 00 00");
  expect(div.textContent).not.toMatch(/\+237\s?6\d\d/);
  expect(div.textContent).toContain("+237 6•• •• •• 41");
});
