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
import { api } from "../../src/api/client";
import { defaultExportName, REVOKE_DELAY_MS, safeExportName } from "../../src/modules/users/exportAccounts";
import { calls, gates, resetServer, setHandler, type Call, type Reply } from "../auth/fakeServer";
import { byText, cleanup, click, render } from "../components/helpers";

const EXPORT_URL = "/api/admin/export/accounts.csv";
// Contenu FICTIF, numéros masqués.
const CSV = "﻿id,nom,telephone,type,statut\r\n1,Jeff N.,+237 6•• •• •• 41,simple,actif\r\n";
const FULL = ["peut_voir_comptes", "peut_voir_demandes", "peut_exporter"];
const VALIDATEUR = ["peut_voir_comptes", "peut_voir_demandes", "peut_valider_demande"];

let exportReply: Reply;
let created: Blob[];
let revoked: string[];
let downloads: Array<{ href: string; name: string; order: string[] }>;
let order: string[];
// Minuteurs de révocation interceptés (les autres setTimeout restent réels).
let timers: Map<number, () => void>;

function server(permissions: string[]) {
  const me = { id: 1, name: "Awa Test", phone_masked: "+237 6•• •• •• 12", roles: ["x"], permissions };
  setHandler((c: Call): Reply => {
    if (c.url === "/api/auth/refresh/") return { status: 200, data: { access: "jeton-fictif" } };
    if (c.url === "/api/admin/me/") return { status: 200, data: me };
    if (c.url === "/api/admin/stats/") return { status: 200, data: { pending_requests: 0 } };
    if (c.url === "/api/admin/requests/") return { status: 200, data: { count: 0, next: null, results: [] } };
    if (c.url === "/api/zones/") return { status: 200, data: { count: 0, next: null, results: [] } };
    if (c.url === "/api/admin/accounts/") return { status: 200, data: { count: 0, next: null, results: [] } };
    if (c.url === EXPORT_URL) return exportReply;
    return { status: 404 };
  });
}

async function wait(n = 4) {
  for (let i = 0; i < n; i++) await act(async () => new Promise((r) => setTimeout(r, 15)));
}

let qc: QueryClient;
async function mount() {
  qc = new QueryClient();
  const div = await render(
    <QueryClientProvider client={qc}>
      <ThemeProvider>
        <ToastProvider>
          <MemoryRouter initialEntries={["/comptes"]}>
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

const exportCalls = () => calls.filter((c) => c.url === EXPORT_URL);
const exportButton = (div: HTMLElement) => byText(div, "button", "Exporter les comptes (CSV)") as HTMLButtonElement | null;
const dialog = () => document.querySelector("[role=dialog]");
const confirmExport = async () => {
  await click(byText(dialog()!, "button", "Exporter"));
  await wait(4);
};
const csvReply = (text = CSV, headers: Record<string, string> = {}): Reply => ({
  status: 200,
  data: new Blob([text], { type: "text/csv" }),
  headers,
});
async function blobHex(b: Blob) {
  return new Promise<string>((res) => {
    const r = new FileReader();
    r.onload = () => res(Array.from(new Uint8Array(r.result as ArrayBuffer), (x) => x.toString(16).padStart(2, "0")).join(""));
    r.readAsArrayBuffer(b);
  });
}

beforeEach(() => {
  resetServer();
  clearAccessToken();
  localStorage.clear();
  sessionStorage.clear();
  exportReply = csvReply();
  created = [];
  revoked = [];
  downloads = [];
  order = [];
  timers = new Map();
  const realSet = globalThis.setTimeout.bind(globalThis);
  const realClear = globalThis.clearTimeout.bind(globalThis);
  let tid = 100000;
  vi.spyOn(globalThis, "setTimeout").mockImplementation(((fn: () => void, ms?: number, ...a: unknown[]) => {
    if (ms === REVOKE_DELAY_MS) {
      timers.set(++tid, fn);
      return tid as unknown as ReturnType<typeof setTimeout>;
    }
    return realSet(fn, ms, ...a);
  }) as typeof setTimeout);
  vi.spyOn(globalThis, "clearTimeout").mockImplementation(((id: number) => {
    if (timers.delete(id)) return;
    realClear(id);
  }) as typeof clearTimeout);
  let n = 0;
  URL.createObjectURL = (b: Blob | MediaSource) => {
    created.push(b as Blob);
    order.push("create");
    return `blob:test/${++n}`;
  };
  URL.revokeObjectURL = (u: string) => {
    revoked.push(u);
    order.push("revoke");
  };
  vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(function (this: HTMLAnchorElement) {
    order.push("click");
    downloads.push({ href: this.href, name: this.download, order: [...order] });
  });
});
afterEach(async () => {
  await cleanup();
  vi.restoreAllMocks();
});

test("bouton visible avec peut_exporter, absent (pas seulement désactivé) pour un Validateur", async () => {
  server(FULL);
  expect(exportButton(await mount())).not.toBeNull();
  await cleanup();
  server(VALIDATEUR);
  const div = await mount();
  expect(exportButton(div)).toBeNull();
  expect(div.textContent).not.toContain("Exporter");
});

test("annulation de la confirmation : aucune requête", async () => {
  server(FULL);
  const div = await mount();
  await click(exportButton(div));
  expect(dialog()!.textContent).toContain("L'export contient la liste des comptes avec numéros masqués. Chaque export est enregistré dans le journal d'audit.");
  await click(byText(dialog()!, "button", "Annuler"));
  await wait(2);
  expect(exportCalls().length).toBe(0);
  expect(created.length).toBe(0);
});

test("téléchargement : route unique avec jeton, blob identique, nom daté, révocation juste après", async () => {
  server(FULL);
  const div = await mount();
  await click(exportButton(div));
  await confirmExport();
  expect(exportCalls().length).toBe(1);
  expect(exportCalls()[0].auth).toBe("Bearer jeton-fictif");
  expect(exportCalls()[0].params).toBeUndefined();
  expect(exportCalls()[0].body).toBeFalsy();
  expect(calls.filter((c) => c.url.includes("export")).length).toBe(1);
  expect(created.length).toBe(1);
  expect(await blobHex(created[0])).toBe(Array.from(new TextEncoder().encode(CSV), (x) => x.toString(16).padStart(2, "0")).join("")); // aucune transformation
  expect(downloads.length).toBe(1);
  expect(downloads[0].name).toBe(defaultExportName());
  expect(downloads[0].name).toMatch(/^netbuis-comptes-\d{4}-\d{2}-\d{2}\.csv$/);
  expect(downloads[0].href).toBe("blob:test/1");
  expect(order).toEqual(["create", "click"]);
  expect(revoked).toEqual([]); // pas de révocation immédiate
  expect(timers.size).toBe(1);
  timers.forEach((f) => f());
  expect(revoked).toEqual(["blob:test/1"]); // exactement une fois après le délai
  timers.clear();
  expect(order).toEqual(["create", "click", "revoke"]);
  expect(document.querySelector("a[download]")).toBeNull();
  expect(div.ownerDocument.body.textContent).toContain("Export téléchargé");
});

test("contenu jamais conservé : ni cache react-query, ni stockage, ni affichage", async () => {
  server(FULL);
  const logs = (["log", "error", "warn"] as const).map((k) => vi.spyOn(console, k));
  const div = await mount();
  await click(exportButton(div));
  await confirmExport();
  expect(downloads.length).toBe(1);
  await wait(3);
  // La mutation ne garde qu'un résultat court, jamais le fichier ; gcTime 0 : rien n'est conservé après elle.
  const mutations = qc.getMutationCache().getAll();
  expect(mutations.every((m) => m.state.data === "downloaded" && m.gcTime === 0)).toBe(true);
  expect(JSON.stringify(mutations.map((m) => m.state))).not.toContain("Jeff N.");
  expect(JSON.stringify(qc.getQueryCache().getAll().map((q) => q.state.data))).not.toContain("Jeff N.");
  expect(JSON.stringify({ ...localStorage })).not.toContain("Jeff N.");
  expect(JSON.stringify({ ...sessionStorage })).not.toContain("Jeff N.");
  expect(document.body.textContent).not.toContain("Jeff N.");
  for (const l of logs) expect(l).not.toHaveBeenCalled();
});

test("nom de fichier du serveur : repris s'il est sûr, sinon assaini vers le nom par défaut", async () => {
  server(FULL);
  exportReply = csvReply(CSV, { "content-disposition": 'attachment; filename="comptes-2026-01-02.csv"' });
  const div = await mount();
  await click(exportButton(div));
  await confirmExport();
  expect(downloads[0].name).toBe("comptes-2026-01-02.csv");
  const def = defaultExportName();
  for (const bad of [
    'attachment; filename="../../etc/passwd.csv"',
    'attachment; filename="..\\evil.csv"',
    'attachment; filename="a/b.csv"',
    'attachment; filename="x\u0007.csv"',
    'attachment; filename="run.exe"',
    'attachment; filename=".hidden.csv"',
    "attachment",
    "",
  ]) {
    expect(safeExportName(bad)).toBe(def);
  }
  expect(safeExportName(undefined)).toBe(def);
});

test("double clic : un seul export, bouton désactivé pendant la requête", async () => {
  server(FULL);
  let release!: () => void;
  gates.set(EXPORT_URL, new Promise<void>((r) => (release = r)));
  const div = await mount();
  await click(exportButton(div));
  await click(byText(dialog()!, "button", "Exporter"));
  await wait(2);
  expect(exportButton(div)!.disabled).toBe(true);
  await click(exportButton(div));
  expect(dialog()).toBeNull();
  await wait(2);
  expect(exportCalls().length).toBe(1);
  release();
  await wait(4);
  expect(exportCalls().length).toBe(1);
  expect(downloads.length).toBe(1);
  expect(exportButton(div)!.disabled).toBe(false);
});

test.each([
  [{ status: 403 }, "Droit insuffisant"],
  [{ status: 0, network: true }, "Connexion impossible"],
  [{ status: 503 }, "Le service est indisponible"],
] as Array<[Reply, string]>)("erreur %j : message simple, Réessayer, aucun téléchargement", async (reply, text) => {
  server(FULL);
  exportReply = reply;
  const div = await mount();
  await click(exportButton(div));
  await confirmExport();
  const alert = div.querySelector('[role=alert]')!;
  expect(alert.textContent).toContain(text);
  expect(downloads.length).toBe(0);
  expect(created.length).toBe(0);
  exportReply = csvReply();
  await click(byText(alert as HTMLElement, "button", "Réessayer"));
  await wait(4);
  expect(exportCalls().length).toBe(2);
  expect(downloads.length).toBe(1);
  expect(div.querySelector("[role=alert]")).toBeNull();
});

test.each(["id,nom,CNI_url", 'id,"Token",nom', "id;nom;jeton_acces", "id,nom,Password", "id,mot_de_passe"])(
  "en-têtes interdits (%s) : avertissement, rien téléchargé",
  async (header) => {
    server(FULL);
    exportReply = csvReply(`${header}\r\n1,a,b\r\n`);
    const div = await mount();
    await click(exportButton(div));
    await confirmExport();
    expect(div.querySelector("[role=alert]")!.textContent).toContain("Fichier non téléchargé");
    expect(created.length).toBe(0);
    expect(downloads.length).toBe(0);
    expect(revoked.length).toBe(0);
  },
);

test("le CSV fictif de référence n'a aucun en-tête interdit", () => {
  const head = CSV.replace("﻿", "").split("\r\n")[0].toLowerCase();
  for (const w of ["cni", "token", "jeton", "password"]) expect(head).not.toContain(w);
});

test("démontage avant le délai : blob URL révoquée une seule fois, sans fuite", async () => {
  server(FULL);
  const div = await mount();
  await click(exportButton(div));
  await confirmExport();
  expect(revoked).toEqual([]);
  await cleanup();
  expect(revoked).toEqual(["blob:test/1"]);
  timers.forEach((f) => f()); // un minuteur resté en vie révoquerait une 2e fois
  expect(revoked).toEqual(["blob:test/1"]);
});

test("échec du clic de téléchargement : une seule révocation, aucun minuteur", async () => {
  server(FULL);
  vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(() => {
    throw new Error("clic refusé");
  });
  const div = await mount();
  await click(exportButton(div));
  await confirmExport();
  expect(revoked).toEqual(["blob:test/1"]);
  expect(timers.size).toBe(0);
  expect(div.querySelector("[role=alert]")).not.toBeNull();
  await cleanup();
  expect(revoked).toEqual(["blob:test/1"]);
});

test.each(["id,C.N.I,nom", "id,Carte nationale,nom", "id,ＣＮＩ,nom", "id,Carte_Nationale", "id,ＴＯＫＥＮ"])(
  "garde-fou normalisé (%s) : refusé",
  async (header) => {
    server(FULL);
    exportReply = csvReply(`${header}\r\n1,a,b\r\n`);
    const div = await mount();
    await click(exportButton(div));
    await confirmExport();
    expect(div.querySelector("[role=alert]")!.textContent).toContain("Fichier non téléchargé");
    expect(created.length).toBe(0);
  },
);

test("401 sur l'export puis refresh réussi : la requête est relancée en responseType blob", async () => {
  server(FULL);
  const seen: unknown[] = [];
  api.interceptors.request.use((c) => {
    if (c.url === EXPORT_URL) seen.push(c.responseType);
    return c;
  });
  let n = 0;
  const base = (await import("../auth/fakeServer")).handler;
  setHandler((c) => {
    if (c.url === EXPORT_URL && ++n === 1) return { status: 401 };
    return base(c);
  });
  const div = await mount();
  await click(exportButton(div));
  await confirmExport();
  expect(exportCalls().length).toBe(2);
  expect(seen[0]).toBe("blob");
  expect(downloads.length).toBe(1);
  expect(await blobHex(created[0])).toContain("efbbbf");
});
