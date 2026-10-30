// Parcours COMPTES : recherche, détail audité, blocage, restauration.
import { expect, test } from "vitest";
import { act } from "react";
import { byText, calls, click, dialog, dialogButton, installCommonHooks, mountApp, startWorld, storageDump, textarea, toastText, type, wait } from "./harness";
import { ADMIN_COMPLET, FULL_PHONE, VALIDATEUR } from "./world";

installCommonHooks();

const row = (div: HTMLElement, id: number) => div.querySelector(`[data-testid="account-row-${id}"]`) as HTMLElement | null;

test("recherche → détail audité (numéro complet) → blocage avec motif → débloquer → supprimer → restaurer", async () => {
  const world = startWorld(ADMIN_COMPLET);
  const app = await mountApp("/comptes");
  const main = app.main();
  expect(row(app.div, 1)).not.toBeNull();
  expect(row(app.div, 2)).not.toBeNull();
  expect(main.textContent).not.toMatch(/\+237 6\d/); // liste : numéros masqués

  // Recherche : envoyée après une courte pause, le serveur filtre.
  await type(main.querySelector('input[aria-label="Rechercher un compte"]') as HTMLInputElement, "  Mama ");
  await act(async () => new Promise((r) => setTimeout(r, 400)));
  await wait(2);
  expect(calls.filter((c) => c.url === "/api/admin/accounts/").at(-1)!.params).toMatchObject({ q: "Mama", page: 1 });
  expect(row(app.div, 2)).not.toBeNull();
  expect(row(app.div, 1)).toBeNull();
  expect(storageDump()).not.toContain("Mama"); // la recherche n'est stockée nulle part

  // Détail : le numéro complet n'apparaît que là, et la consultation est enregistrée par le serveur.
  expect(world.audit).toHaveLength(0);
  await click(row(app.div, 2)!.querySelectorAll("td")[0]!);
  await wait();
  expect(main.textContent).toContain("← Comptes");
  expect(main.textContent).toContain(FULL_PHONE);
  expect(app.div.querySelector("header")!.textContent).not.toContain(FULL_PHONE);
  expect(storageDump()).not.toContain("600 00 00");
  expect(world.audit.map((a) => a.action)).toEqual(["consultation_numero"]);

  // Blocage : motif obligatoire.
  await click(byText(main, "button", "Bloquer"));
  expect(dialogButton("Bloquer").disabled).toBe(true);
  await type(textarea(), "   ");
  expect(dialogButton("Bloquer").disabled).toBe(true);
  expect(calls.some((c) => c.url.includes("/block/"))).toBe(false);
  await type(textarea(), "Fausses annonces");
  await click(dialogButton("Bloquer"));
  await wait();
  expect(calls.find((c) => c.url === "/api/admin/accounts/2/block/")?.body).toEqual({ reason: "Fausses annonces" });
  expect(toastText()).toContain("Compte bloqué");
  expect(main.textContent).toContain("Motif du blocage");
  expect(main.textContent).toContain("Fausses annonces");
  expect(byText(main, "button", "Débloquer")).not.toBeNull();
  expect(world.audit.find((a) => a.action === "blocage_compte")).toMatchObject({ reason: "Fausses annonces", target_id: 2 });

  // Débloquer (confirmation simple), puis supprimer (motif obligatoire), puis restaurer.
  await click(byText(main, "button", "Débloquer"));
  expect(dialog()!.querySelector("textarea")).toBeNull();
  await click(dialogButton("Débloquer"));
  await wait();
  expect(world.accounts[1]).toMatchObject({ is_blocked: false });

  await click(byText(main, "button", "Supprimer"));
  expect(dialogButton("Supprimer").disabled).toBe(true);
  await type(textarea(), "Demande du titulaire");
  await click(dialogButton("Supprimer"));
  await wait();
  const del = calls.find((c) => c.method === "delete" && c.url === "/api/admin/accounts/2/");
  expect(del?.body).toEqual({ reason: "Demande du titulaire" });
  expect(world.accounts[1]).toMatchObject({ is_deleted: true });
  expect(byText(main, "button", "Restaurer")).not.toBeNull();
  expect(byText(main, "button", "Bloquer")).toBeNull(); // un compte supprimé ne se bloque pas

  await click(byText(main, "button", "Restaurer"));
  await click(dialogButton("Restaurer"));
  await wait();
  expect(toastText()).toContain("Compte restauré");
  expect(world.accounts[1]).toMatchObject({ is_deleted: false, status: "actif" });
  expect(byText(main, "button", "Bloquer")).not.toBeNull();
  // Tout est dans le journal, dans l'ordre (le plus récent en premier). Chaque rechargement du détail
  // est lui-même une consultation du numéro, donc auditée : on les écarte pour lire les décisions.
  expect(world.audit.map((a) => a.action).filter((a) => a !== "consultation_numero")).toEqual(["restauration_compte", "suppression_compte", "deblocage_compte", "blocage_compte"]);
  expect(world.audit.filter((a) => a.action === "consultation_numero").length).toBeGreaterThanOrEqual(1);
});

test("depuis la liste : bloquer puis restaurer un compte supprimé, et le statut de la ligne suit", async () => {
  const world = startWorld(ADMIN_COMPLET);
  world.accounts[2]!.is_deleted = true;
  world.accounts[2]!.status = "supprime";
  const app = await mountApp("/comptes");
  expect(row(app.div, 3)!.textContent).toContain("Supprimé");
  await click(byText(row(app.div, 1)!, "button", "Bloquer"));
  await type(textarea(), "Spam");
  await click(dialogButton("Bloquer"));
  await wait();
  expect(row(app.div, 1)!.textContent).toContain("Bloqué");
  await click(byText(row(app.div, 3)!, "button", "Restaurer"));
  await click(dialogButton("Restaurer"));
  await wait();
  expect(row(app.div, 3)!.textContent).toContain("Actif");
  expect(world.audit.map((a) => a.action)).toEqual(["restauration_compte", "blocage_compte"]);
});

test("Validateur : liste et détail lisibles, numéro masqué seulement, aucune action", async () => {
  const world = startWorld(VALIDATEUR);
  const app = await mountApp("/comptes/1");
  const main = app.main();
  expect(main.textContent).not.toContain(FULL_PHONE);
  expect(main.textContent).toContain("+237 6•• •• •• 41");
  expect(byText(main, "button", "Bloquer")).toBeNull();
  expect(byText(main, "button", "Supprimer")).toBeNull();
  expect(world.accounts[0]).toMatchObject({ is_blocked: false });
});

test("le serveur refuse un blocage sans motif même si l'interface était contournée : rien ne change", async () => {
  const world = startWorld(ADMIN_COMPLET);
  const { api } = await import("../../src/api/client");
  await mountApp("/comptes");
  await expect(api.post("/api/admin/accounts/1/block/", { reason: "" })).rejects.toMatchObject({ response: { status: 400 } });
  expect(world.accounts[0]).toMatchObject({ is_blocked: false });
});
