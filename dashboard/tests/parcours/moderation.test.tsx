// Parcours MODÉRATION DU FORUM : file → masquer → restaurer ; supprimer avec motif obligatoire.
import { expect, test } from "vitest";
import { byText, calls, click, dialog, dialogButton, installCommonHooks, mountApp, startWorld, textarea, toastText, type, wait } from "./harness";
import { ADMIN_COMPLET, VALIDATEUR } from "./world";

installCommonHooks();

const tr = (div: HTMLElement, text: string) => Array.from(div.querySelectorAll("tbody tr")).find((r) => r.textContent?.includes(text)) as HTMLElement;

test("file → masquer (motif facultatif) → filtre Masqués → restaurer", async () => {
  const world = startWorld(ADMIN_COMPLET);
  const app = await mountApp("/moderation");
  const main = app.main();
  expect(main.querySelectorAll("tbody tr")).toHaveLength(3);
  expect(tr(main, "Texte du message 1").textContent).toContain("Spam ×2");
  expect(tr(main, "Texte du message 1").textContent).toContain("+237 6•• •• •• 41"); // auteur masqué

  await click(byText(tr(main, "Texte du message 1"), "button", "Masquer"));
  expect(dialog()!.textContent).toContain("Masquer le contenu");
  expect(calls.some((c) => c.url.includes("/hide/"))).toBe(false); // rien avant la confirmation
  await type(textarea(), "  Publicité répétée ");
  await click(dialogButton("Masquer"));
  await wait();
  const hide = calls.find((c) => c.url === "/api/admin/reports/post/1/hide/");
  expect(hide?.body).toEqual({ reason: "Publicité répétée" });
  expect(world.reports[0]).toMatchObject({ content_status: "masque" });
  expect(tr(main, "Texte du message 1").textContent).toContain("Masqué");
  expect(world.audit[0]).toMatchObject({ action: "moderation_contenu", reason: "Publicité répétée" });

  await click(byText(main, "button", "Masqués"));
  await wait();
  expect(calls.filter((c) => c.url === "/api/admin/reports/").at(-1)!.params).toMatchObject({ status: "masque", page: 1 });
  expect(main.querySelectorAll("tbody tr")).toHaveLength(1);

  await click(byText(tr(main, "Texte du message 1"), "button", "Restaurer"));
  await click(dialogButton("Restaurer"));
  await wait();
  expect(calls.some((c) => c.url === "/api/admin/reports/post/1/restore/")).toBe(true);
  expect(world.reports[0]).toMatchObject({ content_status: "actif" });
  expect(main.textContent).toContain("Aucun signalement en attente"); // le filtre Masqués est maintenant vide
});

test("supprimer (rejet définitif) : motif obligatoire, puis le contenu quitte la file", async () => {
  const world = startWorld(ADMIN_COMPLET);
  const app = await mountApp("/moderation");
  const main = app.main();
  await click(byText(tr(main, "Texte du message 2"), "button", "Supprimer"));
  expect(dialogButton("Supprimer").disabled).toBe(true);
  await click(dialogButton("Supprimer"));
  await type(textarea(), "    ");
  expect(dialogButton("Supprimer").disabled).toBe(true);
  expect(calls.some((c) => c.url.includes("/delete/"))).toBe(false);
  await type(textarea(), "Arnaque avérée");
  await click(dialogButton("Supprimer"));
  await wait();
  expect(calls.find((c) => c.url === "/api/admin/reports/post/2/delete/")?.body).toEqual({ reason: "Arnaque avérée" });
  expect(world.reports[1]).toMatchObject({ content_status: "supprime" });
  expect(main.textContent).not.toContain("Texte du message 2");
  expect(main.querySelectorAll("tbody tr")).toHaveLength(2);
  expect(world.audit[0]).toMatchObject({ action: "moderation_contenu", reason: "Arnaque avérée", target_id: 2 });
});

test("un autre modérateur a déjà supprimé le contenu : message clair, file actualisée", async () => {
  const world = startWorld(ADMIN_COMPLET);
  const app = await mountApp("/moderation");
  world.reports.splice(0, 1); // disparu entre-temps
  await click(byText(tr(app.main(), "Texte du message 1"), "button", "Masquer"));
  await click(dialogButton("Masquer"));
  await wait();
  expect(toastText()).toContain("Ce contenu n'existe plus");
  expect(app.main().textContent).not.toContain("Texte du message 1");
});

test("sans le droit de modérer : page refusée, aucune requête vers la file", async () => {
  startWorld(VALIDATEUR);
  const app = await mountApp("/moderation");
  expect(app.main().textContent).toContain("Accès refusé");
  expect(calls.some((c) => c.url === "/api/admin/reports/")).toBe(false);
});
