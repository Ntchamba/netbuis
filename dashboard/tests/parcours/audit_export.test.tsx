// Parcours AUDIT et EXPORT : les décisions prises dans l'interface se retrouvent dans le journal ; l'export est audité.
import { expect, test, vi } from "vitest";
import { act } from "react";
import { byText, calls, click, dialog, dialogButton, installCommonHooks, mountApp, startWorld, storageDump, textarea, toastText, type, wait } from "./harness";
import { ADMIN_COMPLET, VALIDATEUR } from "./world";

installCommonHooks();

const input = (div: HTMLElement, label: string) => {
  const l = Array.from(div.querySelectorAll("label")).find((e) => e.textContent === label)!;
  return div.querySelector(`#${CSS.escape(l.getAttribute("for")!)}`) as HTMLInputElement & HTMLSelectElement;
};

test("valider, bloquer puis exporter : chaque geste apparaît dans le journal, du plus récent au plus ancien, et se filtre", async () => {
  const world = startWorld(ADMIN_COMPLET);
  const downloads: Array<{ name: string; blob: Blob }> = [];
  const created: Blob[] = [];
  URL.createObjectURL = (b: Blob | MediaSource) => {
    created.push(b as Blob);
    return `blob:test/${created.length}`;
  };

  const app = await mountApp("/demandes");
  // 1. Valider une demande.
  await click(byText(app.main().querySelector("article")!, "button", "Valider"));
  await wait();
  // 2. Bloquer un compte.
  await app.goTo("Comptes");
  await click(byText(app.div.querySelector('[data-testid="account-row-1"]')!, "button", "Bloquer"));
  await type(textarea(), "Spam");
  await click(dialogButton("Bloquer"));
  await wait();
  // 3. Exporter (confirmation d'abord, rien ne part avant). Seul le clic de téléchargement est intercepté.
  const anchor = vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(function (this: HTMLAnchorElement) {
    downloads.push({ name: this.download, blob: created.at(-1)! });
  });
  await click(byText(app.main(), "button", "Exporter les comptes (CSV)"));
  expect(dialog()!.textContent).toContain("Chaque export est enregistré dans le journal d'audit.");
  expect(calls.some((c) => c.url.includes("/export/"))).toBe(false);
  await click(dialogButton("Exporter"));
  await wait(5);
  expect(toastText()).toContain("Export téléchargé");
  const exp = calls.filter((c) => c.url === "/api/admin/export/accounts.csv");
  expect(exp).toHaveLength(1);
  expect(exp[0]!.auth).toBe(`Bearer ${world.access}`);
  expect(downloads).toHaveLength(1);
  anchor.mockRestore(); // les liens du menu doivent de nouveau naviguer
  expect(downloads[0]!.name).toMatch(/^netbuis-comptes-\d{4}-\d{2}-\d{2}\.csv$/);
  const text = await downloads[0]!.blob.text();
  expect(text).toContain("Jeff N.");
  expect(text).toContain("+237 6•• •• •• 41"); // numéros masqués dans le fichier
  expect(text).not.toMatch(/\+237 6\d/);
  expect(storageDump()).not.toContain("Jeff N.");
  expect(document.body.textContent).not.toContain("netbuis-comptes"); // le contenu n'est pas affiché

  // 4. Journal : trois lignes, l'export en tête.
  await app.goTo("Journal d'audit");
  const rows = Array.from(app.div.querySelectorAll("tbody tr"));
  expect(rows.map((r) => r.textContent)).toEqual([
    expect.stringContaining("Export CSV des comptes"),
    expect.stringContaining("Blocage d'un compte"),
    expect.stringContaining("Validation d'un compte business"),
  ]);
  expect(rows[1]!.textContent).toContain("Spam");
  expect(rows[1]!.textContent).toContain("Awa Test");
  expect(rows[1]!.querySelector("a")?.getAttribute("href")).toBe("/comptes/1");
  expect(calls.filter((c) => c.url === "/api/admin/audit/")[0]!.params).toEqual({ page: 1, page_size: 20 });

  // 5. Filtre par action : envoyé au serveur, une seule ligne reste.
  const select = input(app.div, "Action");
  await act(async () => {
    select.value = "blocage_compte";
    select.dispatchEvent(new Event("change", { bubbles: true }));
  });
  await wait();
  expect(calls.filter((c) => c.url === "/api/admin/audit/").at(-1)!.params).toMatchObject({ action: "blocage_compte", page: 1 });
  const left = Array.from(app.div.querySelectorAll("tbody tr"));
  expect(left).toHaveLength(1);
  expect(left[0]!.textContent).toContain("Blocage d'un compte");
});

test("export annulé : aucune requête, aucun fichier, aucune ligne d'audit", async () => {
  const world = startWorld(ADMIN_COMPLET);
  const app = await mountApp("/comptes");
  await click(byText(app.main(), "button", "Exporter les comptes (CSV)"));
  await click(dialogButton("Annuler"));
  await wait(2);
  expect(calls.some((c) => c.url.includes("/export/"))).toBe(false);
  expect(world.audit).toHaveLength(0);
});

test("export refusé par le serveur (403) : message clair, rien de téléchargé", async () => {
  const world = startWorld(ADMIN_COMPLET);
  const app = await mountApp("/comptes");
  world.permissions = ADMIN_COMPLET.filter((p) => p !== "peut_exporter"); // droit retiré depuis la connexion
  const click1 = vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(() => {});
  await click(byText(app.main(), "button", "Exporter les comptes (CSV)"));
  await click(dialogButton("Exporter"));
  await wait(4);
  expect(app.main().textContent).toContain("Droit insuffisant");
  expect(click1).not.toHaveBeenCalled();
  expect(world.audit).toHaveLength(0);
});

test("Validateur : ni bouton d'export dans la page Comptes, et le journal reste lisible", async () => {
  const world = startWorld(VALIDATEUR);
  world.record("blocage_compte", "accounts.user", 5, "Motif fictif");
  const app = await mountApp("/comptes");
  expect(byText(app.div, "button", "Exporter les comptes (CSV)")).toBeNull();
  await app.goTo("Journal d'audit");
  expect(app.div.querySelectorAll("tbody tr")).toHaveLength(1);
  expect(app.div.querySelector("tbody tr")!.textContent).toContain("Motif fictif");
});
