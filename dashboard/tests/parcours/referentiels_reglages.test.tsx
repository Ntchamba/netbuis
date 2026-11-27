// Parcours RÉFÉRENTIELS et RÉGLAGES : création, modification, refus d'un doublon, valeurs hors bornes.
import { expect, test } from "vitest";
import { byText, calls, click, dialog, dialogButton, installCommonHooks, mountApp, startWorld, toastText, type, wait } from "./harness";
import { ADMIN_COMPLET } from "./world";

installCommonHooks();

const field = (label: string) => {
  const l = Array.from(dialog()!.querySelectorAll("label")).find((e) => e.textContent === label)!;
  return dialog()!.querySelector(`#${CSS.escape(l.getAttribute("for")!)}`) as HTMLInputElement;
};
const rowOf = (div: HTMLElement, id: number) => div.querySelector(`[data-testid="ref-row-${id}"]`)!.closest("tr") as HTMLElement;

test("référentiels : créer un secteur, le modifier, et se voir refuser un doublon (création et modification)", async () => {
  const world = startWorld(ADMIN_COMPLET);
  const app = await mountApp("/referentiels/sectors");
  const main = app.main();
  expect(main.textContent).toContain("Alimentation");

  // Création.
  await click(byText(main, "button", "Ajouter un secteur"));
  await type(field("Code"), "peche");
  await type(field("Nom"), "Pêche");
  await click(dialogButton("Ajouter"));
  await wait();
  expect(calls.find((c) => c.method === "post" && c.url === "/api/admin/referentials/sectors/")?.body).toEqual({ code: "peche", name: "Pêche" });
  expect(toastText()).toContain("Élément ajouté");
  expect(dialog()).toBeNull();
  expect(main.textContent).toContain("Pêche");
  expect(world.sectors).toHaveLength(3);

  // Doublon à la création (même nom, casse différente) : refusé, fenêtre gardée, rien d'ajouté.
  await click(byText(main, "button", "Ajouter un secteur"));
  await type(field("Code"), "peche2");
  await type(field("Nom"), "PÊCHE");
  await click(dialogButton("Ajouter"));
  await wait();
  const name = field("Nom");
  expect(name.getAttribute("aria-invalid")).toBe("true");
  expect(dialog()!.querySelector(`#${CSS.escape(name.id)}-erreur`)?.textContent).toBe("Un élément portant ce nom ou ce code existe déjà.");
  expect(world.sectors).toHaveLength(3);
  await click(dialogButton("Annuler"));

  // Modification : seul le nom change (PATCH), le code n'est pas modifiable.
  await click(byText(rowOf(app.div, 1), "button", "Modifier"));
  expect(Array.from(dialog()!.querySelectorAll("label")).map((l) => l.textContent)).not.toContain("Code");
  await type(field("Nom"), "Alimentation générale");
  await click(dialogButton("Enregistrer"));
  await wait();
  const patch = calls.find((c) => c.method === "patch" && c.url === "/api/admin/referentials/sectors/1/");
  expect(patch?.body).toEqual({ name: "Alimentation générale" });
  expect(main.textContent).toContain("Alimentation générale");

  // Doublon à la modification : renommer « Mode » en « Pêche » est refusé.
  await click(byText(rowOf(app.div, 2), "button", "Modifier"));
  await type(field("Nom"), "Pêche");
  await click(dialogButton("Enregistrer"));
  await wait();
  expect(dialog()!.textContent).toContain("existe déjà");
  expect(world.sectors.find((s) => s.id === 2)).toMatchObject({ name: "Mode" });
  expect(world.audit.map((a) => a.action)).toEqual(["modification_referentiel", "creation_referentiel"]);
});

test("référentiels : champs vides ou code invalide refusés avant tout envoi", async () => {
  const world = startWorld(ADMIN_COMPLET);
  const app = await mountApp("/referentiels/sectors");
  await click(byText(app.main(), "button", "Ajouter un secteur"));
  await click(dialogButton("Ajouter"));
  expect(dialog()!.textContent).toContain("Nom : champ obligatoire.");
  await type(field("Code"), "Pas Bon");
  await type(field("Nom"), "Test");
  await click(dialogButton("Ajouter"));
  expect(dialog()!.textContent).toContain("Le code ne contient que des minuscules");
  expect(calls.some((c) => c.method === "post" && c.url.includes("/referentials/"))).toBe(false);
  expect(world.sectors).toHaveLength(2);
});

test("réglages : modification confirmée, valeur hors bornes refusée sans requête, journal d'audit alimenté", async () => {
  const world = startWorld(ADMIN_COMPLET);
  const app = await mountApp("/reglages");
  const box = app.div.querySelector('[data-testid="setting-limite_appels_par_jour"]') as HTMLElement;
  const input = box.querySelector("input") as HTMLInputElement;
  expect(app.div.querySelector('[data-testid="setting-value-limite_appels_par_jour"]')?.textContent).toBe("50");

  for (const bad of ["1001", "-1", "2.5", "abc", ""]) {
    await type(input, bad);
    await click(byText(box, "button", "Enregistrer"));
    expect(box.querySelector("[role=alert]"), bad).not.toBeNull();
    expect(dialog()).toBeNull();
  }
  expect(calls.some((c) => c.method === "patch")).toBe(false);
  expect(world.settings[0]).toMatchObject({ value: 50 });

  await type(input, "80");
  await click(byText(box, "button", "Enregistrer"));
  expect(calls.some((c) => c.method === "patch")).toBe(false); // confirmation d'abord
  expect(dialog()!.textContent).toContain("50 → 80");
  await click(dialogButton("Enregistrer"));
  await wait();
  expect(calls.find((c) => c.method === "patch")?.body).toEqual({ value: 80 });
  expect(world.settings[0]).toMatchObject({ value: 80, modified_by: "Awa Test" });
  expect(app.div.querySelector('[data-testid="setting-value-limite_appels_par_jour"]')?.textContent).toBe("80");
  expect(world.audit[0]).toMatchObject({ action: "modification_reglage" });
});
