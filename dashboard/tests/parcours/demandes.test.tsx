// Parcours DEMANDES : liste → fiche → pièces privées → valider ; refuser avec motif obligatoire.
import { expect, test } from "vitest";
import { byText, calls, click, dialog, dialogButton, installCommonHooks, mountApp, startWorld, storageDump, textarea, toastText, type, wait } from "./harness";
import { SIGNED_CNI, VALIDATEUR } from "./world";

installCommonHooks();

const card = (main: HTMLElement, name: string) => Array.from(main.querySelectorAll("article")).find((a) => a.textContent?.includes(name)) as HTMLElement;
const badge = (div: HTMLElement) => div.querySelector("aside [aria-label$='en attente']")?.getAttribute("aria-label");

test("liste → pièce privée sur demande → valider : la demande sort de la file, la pastille et l'audit suivent", async () => {
  const world = startWorld(VALIDATEUR);
  const app = await mountApp("/demandes");
  const main = app.main();
  expect(main.textContent).toContain("Comptes business (2)");
  expect(badge(app.div)).toBe("2 en attente");
  expect(main.textContent).not.toMatch(/\+237 6\d/); // numéros masqués seulement
  // Aucune pièce privée n'est chargée tant qu'on ne la demande pas.
  expect(calls.some((c) => c.url.startsWith("/api/admin/private-files/"))).toBe(false);
  expect(main.querySelector('a[href*="private-files"], img[src*="private-files"]')).toBeNull();

  // Pièce privée : récupérée avec le jeton d'accès, montrée en blob local, jamais stockée.
  await click(byText(card(main, "Prestataire Paul"), "button", "Voir la CNI"));
  await wait(2);
  const file = calls.filter((c) => c.url.startsWith("/api/admin/private-files/"));
  expect(file).toHaveLength(1);
  expect(file[0]!.url).toBe(SIGNED_CNI);
  expect(file[0]!.auth).toBe(`Bearer ${world.access}`);
  expect(dialog()!.querySelector("img")?.getAttribute("src")).toMatch(/^blob:/);
  expect(dialog()!.textContent).not.toContain("private-files");
  expect(storageDump()).not.toContain("jeton-cni-fictif");
  await click(dialogButton("Fermer"));
  expect(dialog()).toBeNull();

  // Valider.
  await click(byText(card(main, "Boutique Mama"), "button", "Valider"));
  await wait();
  const approve = calls.find((c) => c.method === "post" && c.url === "/api/admin/requests/1/approve/");
  expect(approve?.auth).toBe(`Bearer ${world.access}`);
  expect(toastText()).toContain("✓ Compte validé — actif sur NetBuis");
  expect(main.textContent).not.toContain("Boutique Mama");
  expect(main.textContent).toContain("Comptes business (1)");
  expect(badge(app.div)).toBe("1 en attente");
  expect(world.audit[0]).toMatchObject({ action: "validation_business", target_id: 1 });
});

test("refuser : motif obligatoire (bouton bloqué, aucune requête), puis refus avec motif enregistré", async () => {
  const world = startWorld(VALIDATEUR);
  const app = await mountApp("/demandes");
  const main = app.main();
  await click(byText(card(main, "Boutique Mama"), "button", "Rejeter"));
  expect(dialogButton("Rejeter").disabled).toBe(true);
  await click(dialogButton("Rejeter"));
  await type(textarea(), "     ");
  expect(dialogButton("Rejeter").disabled).toBe(true);
  await click(dialogButton("Rejeter"));
  await wait(2);
  expect(calls.some((c) => c.url.includes("/reject/"))).toBe(false);
  expect(world.requests).toHaveLength(2);

  await type(textarea(), "  Photo illisible  ");
  await click(dialogButton("Rejeter"));
  await wait();
  expect(calls.find((c) => c.url === "/api/admin/requests/1/reject/")?.body).toEqual({ reason: "Photo illisible" });
  expect(dialog()).toBeNull();
  expect(toastText()).toContain("✕ Demande rejetée");
  expect(main.textContent).not.toContain("Boutique Mama");
  expect(world.audit[0]).toMatchObject({ action: "rejet_business", reason: "Photo illisible" });
});

test("un collègue a déjà traité la demande : message clair et la liste est rechargée", async () => {
  const world = startWorld(VALIDATEUR);
  const app = await mountApp("/demandes");
  world.requests = world.requests.filter((r) => r.id !== 1); // traitée ailleurs, entre-temps
  await click(byText(card(app.main(), "Boutique Mama"), "button", "Valider"));
  await wait();
  expect(toastText()).toContain("Cette demande a déjà été traitée");
  expect(app.main().textContent).not.toContain("Boutique Mama");
  expect(world.audit).toHaveLength(0);
});

test("sans le droit de valider : la liste se lit, mais ni Valider ni Rejeter", async () => {
  startWorld(["peut_voir_comptes", "peut_voir_demandes"]);
  const app = await mountApp("/demandes");
  expect(app.main().textContent).toContain("Boutique Mama");
  expect(byText(app.main(), "button", "Valider")).toBeNull();
  expect(byText(app.main(), "button", "Rejeter")).toBeNull();
});
