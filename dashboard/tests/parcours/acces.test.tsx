// Parcours ACCÈS : connexion, jeton en mémoire, rafraîchissement, déconnexion, droits.
import { expect, test } from "vitest";
import { getAccessToken } from "../../src/auth/tokenStorage";
import { byText, calls, click, installCommonHooks, mountApp, startWorld, storageDump, type, wait, type App } from "./harness";
import { ADMIN_COMPLET, PASSWORD, VALIDATEUR } from "./world";

installCommonHooks();

async function signIn(app: App, phone = "+237 677 12 34 56", password = PASSWORD) {
  await type(app.div.querySelector('input[type="tel"]')!, phone);
  await type(app.div.querySelector('input[type="password"]')!, password);
  await click(app.div.querySelector('button[type="submit"]'));
  await wait();
}
const title = (app: App) => app.div.querySelector("header h2")?.textContent;

test("connexion par téléphone + mot de passe : retour à la page demandée, jeton en mémoire seulement", async () => {
  const world = startWorld(VALIDATEUR, false);
  const app = await mountApp("/demandes");
  expect(app.div.querySelector("h1")?.textContent).toBe("Connexion"); // pas de cookie : redirigé
  expect(calls.some((c) => c.url === "/api/admin/requests/")).toBe(false);
  await signIn(app);
  expect(title(app)).toBe("Demandes en attente");
  expect(app.main().textContent).toContain("Boutique Mama");
  expect(calls.find((c) => c.url === "/api/auth/admin/login/")?.body).toEqual({ phone: "+237677123456", password: PASSWORD });
  expect(getAccessToken()).toBe(world.access);
  expect(calls.filter((c) => c.url === "/api/admin/requests/").every((c) => c.auth === `Bearer ${world.access}`)).toBe(true);
  // Le jeton et le mot de passe ne sont ni dans le stockage, ni dans un cookie lisible, ni dans la page.
  expect(storageDump()).not.toContain(world.access);
  expect(storageDump()).not.toContain(PASSWORD);
  expect(document.body.innerHTML).not.toContain(PASSWORD);
  expect(location.href).not.toContain(world.access);
});

test("mauvais mot de passe : message unique, mot de passe vidé, aucun jeton", async () => {
  startWorld(VALIDATEUR, false);
  const app = await mountApp("/connexion");
  await signIn(app, "+237 677 12 34 56", "pas-le-bon");
  expect(app.div.querySelector('[role="alert"]')?.textContent).toBe("Numéro ou mot de passe incorrect.");
  expect((app.div.querySelector('input[type="password"]') as HTMLInputElement).value).toBe("");
  expect(getAccessToken()).toBeNull();
  await signIn(app, "+237 699 00 00 00", "autre");
  expect(app.div.querySelector('[role="alert"]')?.textContent).toBe("Numéro ou mot de passe incorrect.");
  expect(calls.some((c) => c.url === "/api/admin/me/")).toBe(false);
});

test("session restaurée au démarrage par le cookie de rafraîchissement, sans ressaisie", async () => {
  const world = startWorld(VALIDATEUR);
  const app = await mountApp("/comptes");
  expect(title(app)).toBe("Comptes");
  expect(getAccessToken()).toBe(world.access);
  expect(world.refreshCount).toBe(1);
  expect(calls.find((c) => c.url === "/api/auth/refresh/")?.withCredentials).toBe(true);
  expect(calls.some((c) => c.url === "/api/auth/admin/login/")).toBe(false);
});

test("jeton expiré en cours de route : un seul rafraîchissement, la page se charge sans que l'agent le voie", async () => {
  const world = startWorld(VALIDATEUR);
  const app = await mountApp("/demandes");
  const before = world.refreshCount;
  const old = world.access;
  world.expire();
  await app.goTo("Comptes");
  expect(app.main().textContent).toContain("Jeff N.");
  expect(world.refreshCount).toBe(before + 1);
  expect(getAccessToken()).toBe(world.access);
  expect(getAccessToken()).not.toBe(old);
  const accountCalls = calls.filter((c) => c.url === "/api/admin/accounts/");
  expect(accountCalls.map((c) => c.auth)).toEqual([`Bearer ${old}`, `Bearer ${world.access}`]); // refusé, puis repris UNE fois
  expect(storageDump()).not.toContain(world.access);
});

test("refresh refusé en cours de session : retour à la connexion, données effacées de la page et du cache", async () => {
  const world = startWorld(VALIDATEUR);
  const app = await mountApp("/demandes");
  expect(app.main().textContent).toContain("Boutique Mama");
  world.cookie = false;
  world.expire();
  await app.goTo("Comptes");
  expect(app.div.querySelector("h1")?.textContent).toBe("Connexion");
  expect(getAccessToken()).toBeNull();
  expect(app.qc.getQueryCache().getAll()).toHaveLength(0);
  expect(app.div.textContent).not.toContain("Boutique Mama");
  expect(app.div.textContent).not.toContain("Jeff N.");
});

test("déconnexion : serveur prévenu, jeton, cache, stockage et page nettoyés ; la route protégée est refermée", async () => {
  const world = startWorld(ADMIN_COMPLET);
  const app = await mountApp("/comptes");
  expect(app.main().textContent).toContain("Jeff N.");
  expect(byText(app.div, "button", "Déconnexion")).not.toBeNull();
  await click(byText(app.div, "button", "Déconnexion"));
  await wait();
  expect(world.logoutCount).toBe(1);
  expect(app.div.querySelector("h1")?.textContent).toBe("Connexion");
  expect(getAccessToken()).toBeNull();
  expect(app.qc.getQueryCache().getAll()).toHaveLength(0);
  expect(app.div.textContent).not.toContain("Jeff N.");
  expect(app.div.textContent).not.toContain("Awa Test");
  expect(app.div.querySelector("aside")).toBeNull(); // plus de menu
  expect(storageDump()).not.toContain("jeton");
  // Un nouvel accès à une page protégée est refusé : le cookie a disparu côté serveur.
  const count = calls.filter((c) => c.url === "/api/admin/accounts/").length;
  const again = await mountApp("/comptes");
  expect(again.div.querySelector("h1")?.textContent).toBe("Connexion");
  expect(calls.filter((c) => c.url === "/api/admin/accounts/").length).toBe(count);
});

test("accès refusé selon les droits : pages réservées, menu et requêtes", async () => {
  startWorld(VALIDATEUR);
  for (const path of ["/reglages", "/administrateurs", "/moderation", "/referentiels"]) {
    const app = await mountApp(path);
    expect(app.main().textContent, path).toContain("Accès refusé");
    const nav = Array.from(app.div.querySelectorAll("aside nav > *")).map((e) => e.textContent ?? "");
    for (const hidden of ["Réglages", "Administrateurs", "Modération", "Référentiels"]) expect(nav.join("|"), path).not.toContain(hidden);
    expect(nav.join("|")).toContain("Demandes");
  }
  const forbidden = calls.filter((c) => /\/(settings|admins|reports|referentials)\//.test(c.url));
  expect(forbidden).toHaveLength(0);
});

test("l'Administrateur complet voit toutes les sections réservées", async () => {
  startWorld(ADMIN_COMPLET);
  const app = await mountApp("/reglages");
  const nav = Array.from(app.div.querySelectorAll("aside nav > *")).map((e) => e.textContent ?? "").join("|");
  for (const shown of ["Réglages", "Administrateurs", "Modération", "Référentiels"]) expect(nav).toContain(shown);
  expect(app.main().textContent).not.toContain("Accès refusé");
});

test("compte connecté mais sans droit d'administration (403 sur /admin/me/) : « Accès non autorisé », jeton effacé", async () => {
  const world = startWorld(VALIDATEUR);
  world.me403 = true;
  const app = await mountApp("/demandes");
  expect(app.div.querySelector("h1")?.textContent).toBe("Accès non autorisé");
  expect(getAccessToken()).toBeNull();
  expect(calls.some((c) => c.url === "/api/admin/requests/")).toBe(false);
  await click(byText(app.div, "button", "Se déconnecter"));
  await wait();
  expect(app.div.querySelector("h1")?.textContent).toBe("Connexion");
});
