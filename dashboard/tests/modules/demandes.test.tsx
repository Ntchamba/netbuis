import "../auth/fakeServer";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act } from "react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { AuthProvider } from "../../src/auth/AuthProvider";
import { clearAccessToken } from "../../src/auth/tokenStorage";
import { ThemeProvider } from "../../src/components/theme/ThemeProvider";
import { ToastProvider } from "../../src/components/ui/Toast";
import { fetchPrivateFile, privateFilePath } from "../../src/modules/businesses/api";
import { AppRoutes } from "../../src/routes";
import { calls, resetServer, setHandler, type Call, type Reply } from "../auth/fakeServer";
import { byText, cleanup, click, render, type } from "../components/helpers";

const SIGNED_CNI = "/api/admin/private-files/jeton-cni-fictif/";
const SIGNED_DIPLOME = "/api/admin/private-files/jeton-diplome-fictif/";
const ago = (h: number) => new Date(Date.now() - h * 3_600_000).toISOString();

function request(id: number, over: Record<string, unknown> = {}) {
  return {
    id,
    type: "business",
    type_compte: "boutique",
    name: `Commerce Test ${id}`,
    status: "en_attente_validation",
    owner_id: 100 + id,
    owner_name: `Propriétaire ${id}`,
    phone_masked: "+237 6•• •• •• 41",
    zone: 1,
    zone_name: "Quartier Test",
    repere: "À côté du grand arbre",
    description: "",
    representant_nom: "",
    forme_juridique: "",
    rccm: "",
    categorie_service: null,
    categorie_service_name: null,
    categorie_service_libre: "",
    cni_verifiee: false,
    photo_url: "https://media.test/commerce.jpg",
    representant_photo_url: null,
    cni_url: null,
    diplome_url: null,
    created_at: ago(2),
    ...over,
  };
}

const PRESTATAIRE = request(2, { type_compte: "prestataire_service", name: "Prestataire Test", cni_url: SIGNED_CNI, diplome_url: SIGNED_DIPLOME });

let list: unknown[];
let total: number;
let stats: number;
let decision: (c: Call) => Reply;
let fileReply: Reply;

function server(permissions: string[]) {
  const me = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return { status: 200, data: { pending_requests: stats } };
    if (c.url === "/api/admin/requests/") return { status: 200, data: { count: total, next: null, results: list } };
    if (c.url.startsWith("/api/admin/private-files/")) return fileReply;
    if (c.method === "post") return decision(c);
    return { status: 404 };
  });
}

async function wait(n = 4) {
  for (let i = 0; i < n; i++) await act(async () => new Promise((r) => setTimeout(r, 15)));
}

async function mount(path = "/demandes") {
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

const ALL = ["peut_voir_demandes", "peut_voir_comptes", "peut_valider_demande"];
const created: string[] = [];
const revoked: string[] = [];

beforeEach(() => {
  resetServer();
  clearAccessToken();
  list = [request(1), PRESTATAIRE];
  total = 2;
  stats = 2;
  decision = () => ({ status: 200, data: { id: 1, status: "actif", cni_verifiee: false, motif_rejet: "" } });
  fileReply = { status: 200, data: new Blob(["image-fictive"], { type: "image/png" }) };
  created.length = 0;
  revoked.length = 0;
  let n = 0;
  URL.createObjectURL = () => {
    const u = `blob:test/${++n}`;
    created.push(u);
    return u;
  };
  URL.revokeObjectURL = (u: string) => {
    revoked.push(u);
  };
});
afterEach(async () => {
  await cleanup();
  vi.restoreAllMocks();
});

const textarea = () => document.querySelector("[role=dialog] textarea") as HTMLTextAreaElement;
const dialogButton = (label: string) => byText(document.querySelector("[role=dialog]")!, "button", label) as HTMLButtonElement;

test("file : cartes, numéro masqué seulement, pas d'onglet Équipe ni de parrain, aucune pièce préchargée", async () => {
  server(ALL);
  const div = await mount();
  const main = div.querySelector("main")!;
  expect(div.querySelector("header h2")?.textContent).toBe("Demandes en attente");
  expect(main.textContent).not.toContain("Cette page arrive bientôt");
  expect(main.textContent).toContain("Comptes business (2)");
  expect(main.textContent).not.toContain("Équipe NetBuis");
  expect(main.textContent).not.toContain("parrainé");
  expect(main.textContent).toContain("Commerce Test 1");
  expect(main.textContent).toContain("+237 6•• •• •• 41 · Quartier Test");
  expect(main.textContent).not.toMatch(/\+237 6\d/);
  expect(main.querySelector('img[alt="Photo du commerce"]')?.getAttribute("src")).toBe("https://media.test/commerce.jpg");
  // CNI : seulement pour le prestataire, sous forme de bouton (jamais de lien ni d'image).
  const labels = Array.from(main.querySelectorAll("button")).map((b) => b.textContent);
  expect(labels.filter((l) => l === "Valider")).toHaveLength(2);
  expect(labels.filter((l) => l === "Rejeter")).toHaveLength(2);
  expect(labels).toContain("Voir le diplôme");
  expect(Array.from(main.querySelectorAll("button")).filter((b) => b.textContent === "Voir la CNI")).toHaveLength(1);
  expect(main.querySelector(`a[href*="private-files"], img[src*="private-files"]`)).toBeNull();
  expect(calls.some((c) => c.url.startsWith("/api/admin/private-files/"))).toBe(false);
  expect(calls.find((c) => c.url === "/api/admin/requests/")?.params).toMatchObject({ type: "business", page: 1 });
});

test("sans peut_valider_demande : Valider et Rejeter masqués", async () => {
  server(["peut_voir_demandes", "peut_voir_comptes"]);
  const div = await mount();
  expect(div.textContent).toContain("Commerce Test 1");
  expect(byText(div, "button", "Valider")).toBeNull();
  expect(byText(div, "button", "Rejeter")).toBeNull();
});

test("sans peut_voir_demandes : la page n'est pas affichée", async () => {
  server(["peut_voir_comptes"]);
  const div = await mount();
  expect(div.textContent).not.toContain("Comptes business");
  expect(calls.some((c) => c.url === "/api/admin/requests/")).toBe(false);
});

test("Valider : POST, toast « Compte validé », la demande disparaît et la pastille se met à jour", async () => {
  server(ALL);
  const div = await mount();
  expect(div.querySelector('[aria-label="2 en attente"]')).not.toBeNull();
  const before = calls.filter((c) => c.url === "/api/admin/stats/").length;
  list = [PRESTATAIRE];
  total = 1;
  stats = 1;
  await click(div.querySelector("article")!.querySelectorAll("button")[0]);
  await wait();
  expect(calls.some((c) => c.method === "post" && c.url === "/api/admin/requests/1/approve/" && c.auth === "Bearer jeton-fictif")).toBe(true);
  expect(div.textContent).toContain("✓ Compte validé — actif sur NetBuis");
  expect(div.textContent).not.toContain("Commerce Test 1");
  expect(div.textContent).toContain("Comptes business (1)");
  expect(calls.filter((c) => c.url === "/api/admin/stats/").length).toBeGreaterThan(before);
  expect(div.querySelector('[aria-label="1 en attente"]')).not.toBeNull();
});

test("Rejeter sans motif impossible : bouton désactivé, aucune requête", async () => {
  server(ALL);
  const div = await mount();
  await click(byText(div.querySelector("article")!, "button", "Rejeter"));
  expect(dialogButton("Rejeter").disabled).toBe(true);
  await click(dialogButton("Rejeter"));
  await type(textarea(), "     ");
  expect(dialogButton("Rejeter").disabled).toBe(true);
  await click(dialogButton("Rejeter"));
  await wait(2);
  expect(calls.some((c) => c.url.includes("/reject/"))).toBe(false);
});

test("Rejeter avec motif : POST avec le motif, toast « Demande rejetée », fenêtre fermée", async () => {
  server(ALL);
  const div = await mount();
  await click(byText(div.querySelector("article")!, "button", "Rejeter"));
  await type(textarea(), "  Photo illisible  ");
  expect(dialogButton("Rejeter").disabled).toBe(false);
  list = [PRESTATAIRE];
  total = 1;
  await click(dialogButton("Rejeter"));
  await wait();
  const post = calls.find((c) => c.method === "post" && c.url === "/api/admin/requests/1/reject/");
  expect(post?.body).toEqual({ reason: "Photo illisible" });
  expect(div.ownerDocument.querySelector("[role=dialog]")).toBeNull();
  expect(div.ownerDocument.body.textContent).toContain("✕ Demande rejetée");
  expect(div.textContent).not.toContain("Commerce Test 1");
});

test("un motif de plus de 1000 caractères n'est pas envoyé", async () => {
  server(ALL);
  const div = await mount();
  await click(byText(div.querySelector("article")!, "button", "Rejeter"));
  await type(textarea(), "x".repeat(1001));
  await click(dialogButton("Rejeter"));
  await wait(2);
  expect(calls.some((c) => c.url.includes("/reject/"))).toBe(false);
  expect(document.body.textContent).toContain("Le motif est trop long");
});

test("409 : message « déjà traitée » et la liste est rechargée", async () => {
  server(ALL);
  decision = () => ({ status: 409, data: { code: "already_processed", message: "x" } });
  const div = await mount();
  const before = calls.filter((c) => c.url === "/api/admin/requests/").length;
  list = [PRESTATAIRE];
  total = 1;
  await click(div.querySelector("article")!.querySelectorAll("button")[0]);
  await wait();
  expect(document.body.textContent).toContain("Cette demande a déjà été traitée");
  expect(calls.filter((c) => c.url === "/api/admin/requests/").length).toBeGreaterThan(before);
  expect(div.textContent).not.toContain("Commerce Test 1");
});

test("erreurs 400, 403 et réseau : messages clairs, la demande reste", async () => {
  server(ALL);
  const div = await mount();
  const approve = () => click(div.querySelector("article")!.querySelectorAll("button")[0]);
  decision = () => ({ status: 403, data: { code: "forbidden", message: "x" } });
  await approve();
  await wait(2);
  expect(document.body.textContent).toContain("Vous n'avez pas le droit de traiter cette demande.");
  decision = () => ({ status: 0, network: true });
  await approve();
  await wait(2);
  expect(document.body.textContent).toContain("Connexion impossible");
  expect(div.textContent).toContain("Commerce Test 1");
});

test("400 reason_required renvoyé par le serveur : message du motif, la fenêtre reste ouverte", async () => {
  server(ALL);
  decision = () => ({ status: 400, data: { code: "reason_required", message: "x" } });
  const div = await mount();
  await click(byText(div.querySelector("article")!, "button", "Rejeter"));
  await type(textarea(), "Motif");
  await click(dialogButton("Rejeter"));
  await wait(2);
  expect(document.body.textContent).toContain("Le motif du rejet est obligatoire.");
  expect(document.querySelector("[role=dialog]")).not.toBeNull();
});

test("double clic impossible : les boutons sont désactivés pendant l'envoi", async () => {
  server(ALL);
  const { gates } = await import("../auth/fakeServer");
  let open!: () => void;
  gates.set("/api/admin/requests/1/approve/", new Promise<void>((r) => (open = r)));
  const div = await mount();
  const buttons = () => Array.from(div.querySelectorAll("article button")).filter((b) => ["Valider", "Rejeter"].includes(b.textContent ?? "")) as HTMLButtonElement[];
  await click(buttons()[0]);
  expect(buttons().every((b) => b.disabled)).toBe(true);
  await click(buttons()[0]);
  await act(async () => open());
  await wait();
  expect(calls.filter((c) => c.url === "/api/admin/requests/1/approve/")).toHaveLength(1);
});

test("CNI : ouverte seulement au clic, avec le jeton d'accès, en blob ; révoquée à la fermeture", async () => {
  server(ALL);
  const setItem = vi.spyOn(Storage.prototype, "setItem");
  const div = await mount();
  expect(calls.some((c) => c.url.startsWith("/api/admin/private-files/"))).toBe(false);
  await click(byText(div, "button", "Voir la CNI"));
  await wait(2);
  const file = calls.filter((c) => c.url.startsWith("/api/admin/private-files/"));
  expect(file).toHaveLength(1);
  expect(file[0].url).toBe(SIGNED_CNI);
  expect(file[0].auth).toBe("Bearer jeton-fictif");
  const dialog = document.querySelector("[role=dialog]")!;
  expect(dialog.querySelector("img")?.getAttribute("src")).toBe(created[0]);
  expect(dialog.textContent).not.toContain("blob:");
  expect(dialog.textContent).not.toContain("private-files");
  expect(document.querySelector("h2")?.textContent).toBeTruthy();
  expect(setItem).not.toHaveBeenCalled();
  expect(revoked).toHaveLength(0);
  await click(dialogButton("Fermer"));
  expect(revoked).toEqual([created[0]]);
  expect(document.querySelector("[role=dialog]")).toBeNull();
});

test("CNI : le blob est aussi révoqué si la page est quittée", async () => {
  server(ALL);
  const div = await mount();
  await click(byText(div, "button", "Voir la CNI"));
  await wait(2);
  await cleanup();
  expect(revoked).toEqual([created[0]]);
});

test("diplôme : ouvert à la demande de la même façon", async () => {
  server(ALL);
  const div = await mount();
  await click(byText(div, "button", "Voir le diplôme"));
  await wait(2);
  expect(calls.some((c) => c.url === SIGNED_DIPLOME && c.auth === "Bearer jeton-fictif")).toBe(true);
  expect(document.querySelector("[role=dialog] img")).not.toBeNull();
});

test("lien expiré (403) : message clair, « Actualiser la demande » recharge la file", async () => {
  server(ALL);
  fileReply = { status: 403, data: { code: "invalid_link", message: "x" } };
  const div = await mount();
  await click(byText(div, "button", "Voir la CNI"));
  await wait(2);
  const dialog = document.querySelector("[role=dialog]")!;
  expect(dialog.textContent).toContain("Ce lien a expiré");
  expect(dialog.querySelector("img")).toBeNull();
  expect(created).toHaveLength(0);
  const before = calls.filter((c) => c.url === "/api/admin/requests/").length;
  await click(dialogButton("Actualiser la demande"));
  await wait(2);
  expect(calls.filter((c) => c.url === "/api/admin/requests/").length).toBeGreaterThan(before);
  expect(document.querySelector("[role=dialog]")).toBeNull();
});

test("autre erreur d'ouverture : message sans adresse", async () => {
  server(ALL);
  fileReply = { status: 500 };
  const div = await mount();
  await click(byText(div, "button", "Voir la CNI"));
  await wait(2);
  const text = document.querySelector("[role=dialog]")!.textContent ?? "";
  expect(text).toContain("Impossible d'ouvrir cette pièce");
  expect(text).not.toContain("jeton-cni");
});

test("une URL qui ne pointe pas vers les pièces privées n'est jamais appelée avec le jeton", async () => {
  server(ALL);
  list = [request(2, { type_compte: "prestataire_service", cni_url: "https://autre.test/fichier.png" })];
  const div = await mount();
  await click(byText(div, "button", "Voir la CNI"));
  await wait(2);
  expect(calls.some((c) => c.url.includes("autre.test") || c.url.includes("fichier.png"))).toBe(false);
  expect(document.querySelector("[role=dialog]")!.textContent).toContain("Impossible d'ouvrir cette pièce");
});

test("prestataire sans CNI fournie par le serveur : mention, pas de bouton", async () => {
  server(ALL);
  list = [request(2, { type_compte: "prestataire_service", cni_url: null })];
  const div = await mount();
  expect(div.textContent).toContain("CNI non disponible");
  expect(byText(div, "button", "Voir la CNI")).toBeNull();
});

test("état vide", async () => {
  server(ALL);
  list = [];
  total = 0;
  const div = await mount();
  expect(div.querySelector("main")!.textContent).toContain("Aucune demande en attente");
});

test("erreur de chargement : message et Réessayer", async () => {
  server(ALL);
  setHandler((c) => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: { id: 1, name: "A", phone_masked: "", roles: ["x"], permissions: ALL } };
    if (c.url === "/api/admin/requests/") return { status: 500 };
    return { status: 404 };
  });
  const div = await mount();
  expect(div.querySelector("main [role=alert]")?.textContent).toContain("Impossible de charger les demandes.");
  expect(byText(div, "button", "Réessayer")).not.toBeNull();
});

test("pagination : 45 demandes = 3 pages, « Suivant » demande la page 2", async () => {
  server(ALL);
  total = 45;
  const div = await mount();
  expect(div.textContent).toContain("Page 1 sur 3");
  await click(byText(div, "button", "Suivant"));
  await wait(2);
  expect(calls.some((c) => c.url === "/api/admin/requests/" && c.params?.page === 2)).toBe(true);
  expect(div.textContent).toContain("Page 2 sur 3");
});

test("privateFilePath : seules les adresses de la route des pièces privées sont gardées, réécrites en relatif", () => {
  const ok = "/api/admin/private-files/abc/";
  expect(privateFilePath(ok)).toBe(ok);
  expect(privateFilePath("//evil.example/api/admin/private-files/abc/")).toBe(ok);
  expect(privateFilePath("https://evil.example/api/admin/private-files/abc/")).toBe(ok);
  expect(privateFilePath("/api/admin/private-files/../x")).toBeNull();
  expect(privateFilePath("/api/admin/private-files/%2e%2e/x")).toBeNull();
  expect(privateFilePath("/api/admin/private-files/a/b/")).toBeNull();
  expect(privateFilePath("/api/admin/private-files/")).toBeNull();
  expect(privateFilePath("javascript:alert(1)")).toBeNull();
  expect(privateFilePath("data:image/png;base64,AAAA")).toBeNull();
  expect(privateFilePath("https://evil.example/autre/chemin.png")).toBeNull();
});

test("fetchPrivateFile : jamais d'appel vers un autre hôte, le jeton part vers l'API seulement", async () => {
  server(ALL);
  await mount(); // installe la session (jeton en mémoire)
  const before = calls.length;
  for (const bad of ["/api/admin/private-files/../x", "javascript:alert(1)", "data:text/html,x", "https://evil.example/x.png"]) {
    await expect(fetchPrivateFile(bad)).rejects.toThrow();
  }
  expect(calls.length).toBe(before);
  for (const url of ["//evil.example/api/admin/private-files/abc/", "https://evil.example/api/admin/private-files/abc/"]) {
    await fetchPrivateFile(url);
  }
  const sent = calls.slice(before);
  expect(sent.map((c) => c.url)).toEqual(["/api/admin/private-files/abc/", "/api/admin/private-files/abc/"]);
  expect(sent.every((c) => !c.url.includes("evil.example"))).toBe(true);
});

test("course : A (lente) ouverte puis fermée, B (rapide) ouverte, A résolue ensuite : B reste affichée", async () => {
  server(ALL);
  const A = "/api/admin/private-files/jeton-a-fictif/";
  const B = "/api/admin/private-files/jeton-b-fictif/";
  list = [
    request(3, { type_compte: "prestataire_service", name: "Prestataire A", cni_url: A }),
    request(4, { type_compte: "prestataire_service", name: "Prestataire B", cni_url: B }),
  ];
  total = 2;
  const { gates } = await import("../auth/fakeServer");
  let openA!: () => void;
  gates.set(A, new Promise<void>((r) => (openA = r)));
  const div = await mount();
  const cniButtons = () => Array.from(div.querySelectorAll("article button")).filter((b) => b.textContent === "Voir la CNI");
  await click(cniButtons()[0]);
  await click(dialogButton("Fermer"));
  await click(cniButtons()[1]);
  await wait(2);
  const shown = document.querySelector("[role=dialog] img")?.getAttribute("src");
  expect(shown).toBe(created[0]);
  await act(async () => openA());
  await wait(2);
  expect(created).toHaveLength(1); // le fichier de A n'est jamais converti en blob
  expect(document.querySelector("[role=dialog] img")?.getAttribute("src")).toBe(shown);
  expect(revoked).not.toContain(shown);
  await click(dialogButton("Fermer"));
  expect(revoked).toEqual(created);
});
