// Essai dans un vrai navigateur (Playwright + Chromium) : faux serveur d'API local (à état) qui sert aussi le dashboard construit.
// Parcours : connexion -> demandes -> valider une demande -> déconnexion. Toute erreur de console ou de page = échec.
// Lancer : npm run build && node e2e/parcours-admin.mjs   (Playwright déjà installé ; PLAYWRIGHT_MODULE=chemin si besoin)
import { createRequire } from "node:module";
import { createServer } from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { extname, join, resolve } from "node:path";

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE ?? "playwright");
const DIST = resolve(new URL("../dist", import.meta.url).pathname);
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".svg": "image/svg+xml" };
const PHONE = "+237600000003"; // numéros et mot de passe fictifs (essai seulement)
const PASSWORD = "mdp-fictif-123";
const ACCESS = "jeton-acces-fictif";

// État du faux serveur.
let cookie = false; // le « cookie de rafraîchissement » est-il présent ?
let requests = [
  { id: 1, type: "business", type_compte: "boutique", name: "Boutique Mama", status: "en_attente_validation", owner_id: 101, owner_name: "Mama Test", phone_masked: "+237 6•• •• •• 41", zone: 1, zone_name: "Quartier Test", repere: "Près du marché", description: "", representant_nom: "", forme_juridique: "", rccm: "", categorie_service: null, categorie_service_name: null, categorie_service_libre: "", cni_verifiee: false, photo_url: null, representant_photo_url: null, cni_url: null, diplome_url: null, created_at: new Date().toISOString() },
  { id: 2, type: "business", type_compte: "boutique", name: "Chez Paul", status: "en_attente_validation", owner_id: 102, owner_name: "Paul Test", phone_masked: "+237 6•• •• •• 42", zone: 1, zone_name: "Quartier Test", repere: "Face à l'école", description: "", representant_nom: "", forme_juridique: "", rccm: "", categorie_service: null, categorie_service_name: null, categorie_service_libre: "", cni_verifiee: false, photo_url: null, representant_photo_url: null, cni_url: null, diplome_url: null, created_at: new Date().toISOString() },
];
const seen = []; // « METHODE chemin » de chaque appel d'API, dans l'ordre
const log = { logout: 0, approvedBodies: [] };
const json = (res, status, data) => {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(data));
};
const authed = (req) => req.headers.authorization === `Bearer ${ACCESS}`;

const server = createServer((req, res) => {
  const url = new URL(req.url, "http://x");
  const p = url.pathname;
  if (p.startsWith("/api/")) seen.push(`${req.method} ${p}`);
  let body = "";
  req.on("data", (d) => (body += d));
  req.on("end", () => {
    if (p === "/api/auth/refresh/") return cookie ? json(res, 200, { access: ACCESS }) : json(res, 401, { code: "token_invalid", message: "x" });
    if (p === "/api/auth/admin/login/") {
      const b = JSON.parse(body || "{}");
      if (b.phone !== PHONE || b.password !== PASSWORD) return json(res, 401, { code: "invalid_credentials", message: "Numéro ou mot de passe incorrect." });
      cookie = true;
      return json(res, 200, { access: ACCESS });
    }
    if (p === "/api/auth/logout/") { log.logout += 1; cookie = false; res.writeHead(204); return res.end(); }
    if (p.startsWith("/api/")) {
      if (!authed(req)) return json(res, 401, { code: "token_invalid", message: "x" });
      if (p === "/api/admin/me/") return json(res, 200, { id: 4, name: "Agent Test", phone_masked: "+237 6•• •• •• 12", roles: ["Validateur"], permissions: ["peut_voir_demandes", "peut_voir_comptes", "peut_valider_demande"] });
      if (p === "/api/admin/stats/") return json(res, 200, { pending_requests: requests.length });
      if (p === "/api/admin/requests/") return json(res, 200, { count: requests.length, next: null, results: requests });
      const m = /^\/api\/admin\/requests\/(\d+)\/approve\/$/.exec(p);
      if (m && req.method === "POST") {
        const id = Number(m[1]);
        if (!requests.some((r) => r.id === id)) return json(res, 409, { code: "already_processed", message: "x" });
        requests = requests.filter((r) => r.id !== id);
        return json(res, 200, { id, status: "actif", cni_verifiee: false, motif_rejet: "" });
      }
      return json(res, 404, {});
    }
    // Fichiers statiques du dashboard (repli sur index.html).
    let file = join(DIST, p);
    if (!file.startsWith(DIST) || !existsSync(file) || p === "/") file = join(DIST, "index.html");
    res.writeHead(200, { "Content-Type": TYPES[extname(file)] ?? "application/octet-stream" });
    res.end(readFileSync(file));
  });
});
await new Promise((ok) => server.listen(0, "127.0.0.1", ok));
const origin = `http://127.0.0.1:${server.address().port}`;

let failures = 0;
const out = (t) => process.stdout.write(`${t}\n`);
const check = (ok, msg) => { out(`${ok ? "OK " : "ÉCHEC"} ${msg}`); if (!ok) failures += 1; };

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH, args: ["--no-sandbox"] });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
const problems = [];
let expected401Count = 0;
page.on("console", (m) => {
  if (m.type() !== "error" && m.type() !== "warning") return;
  // Seules exceptions : les 401 ATTENDUS que le navigateur journalise lui-même (rafraîchissement sans session,
  // mauvais mot de passe volontaire). Tout autre message est un échec.
  const where = m.location().url ?? "";
  const expected401 = where.endsWith("/api/auth/refresh/") || where.endsWith("/api/auth/admin/login/");
  if (m.type() === "error" && expected401 && m.text().includes("401")) { expected401Count += 1; return; }
  problems.push(`console.${m.type()} : ${m.text()} [${where}]`);
});
page.on("pageerror", (e) => problems.push(`erreur de page : ${e.message}`));
page.on("requestfailed", (r) => problems.push(`requête échouée : ${r.url()}`));

try {
  // 1. Accès à une page protégée sans session : retour à la connexion.
  await page.goto(`${origin}/demandes`);
  await page.getByRole("heading", { name: "Connexion" }).waitFor();
  check(!seen.includes("GET /api/admin/requests/"), "sans session : la liste des demandes n'est pas demandée");

  // 2. Mauvais mot de passe : message unique, on reste sur la connexion.
  await page.getByLabel("Téléphone").fill("+237 600 00 00 03");
  await page.getByLabel("Mot de passe").fill("pas-le-bon");
  await page.getByRole("button", { name: "Se connecter" }).click();
  await page.getByRole("alert").filter({ hasText: "Numéro ou mot de passe incorrect." }).waitFor();
  check((await page.getByLabel("Mot de passe").inputValue()) === "", "mot de passe vidé après l'échec");

  // 3. Bonne connexion : retour à la page demandée.
  await page.getByLabel("Mot de passe").fill(PASSWORD);
  await page.getByRole("button", { name: "Se connecter" }).click();
  await page.getByRole("heading", { name: "Demandes en attente" }).waitFor();
  await page.getByText("Boutique Mama").waitFor();
  check(page.url() === `${origin}/demandes`, "après la connexion : retour sur /demandes");
  check((await page.getByText("Comptes business (2)").count()) === 1, "deux demandes en attente");
  check((await page.locator("aside [aria-label$='en attente']").getAttribute("aria-label")) === "2 en attente", "pastille « 2 en attente »");
  const storage = await page.evaluate(() => JSON.stringify({ ...localStorage }) + JSON.stringify({ ...sessionStorage }) + document.cookie);
  check(!storage.includes(ACCESS) && !storage.includes(PASSWORD), "jeton et mot de passe absents du stockage et des cookies lisibles");

  // 4. Valider la première demande.
  const card = page.locator("article", { hasText: "Boutique Mama" });
  await card.getByRole("button", { name: "Valider" }).click();
  await page.getByText("✓ Compte validé — actif sur NetBuis").waitFor();
  await page.getByText("Comptes business (1)").waitFor();
  check((await page.getByText("Boutique Mama").count()) === 0, "la demande validée a disparu de la liste");
  check((await page.getByText("Chez Paul").count()) === 1, "l'autre demande est toujours là");
  await page.locator("aside [aria-label='1 en attente']").waitFor();
  check(seen.includes("POST /api/admin/requests/1/approve/"), "POST approve envoyé pour la bonne demande");

  // 5. Déconnexion : tout est nettoyé, l'accès est refermé.
  await page.getByRole("button", { name: "Déconnexion" }).click();
  await page.getByRole("heading", { name: "Connexion" }).waitFor();
  check(log.logout === 1 && cookie === false, "le serveur a été prévenu de la déconnexion");
  check((await page.getByText("Chez Paul").count()) === 0 && (await page.locator("aside").count()) === 0, "plus aucune donnée ni menu après la déconnexion");
  const calls = seen.length;
  await page.goto(`${origin}/demandes`);
  await page.getByRole("heading", { name: "Connexion" }).waitFor();
  check(!seen.slice(calls).includes("GET /api/admin/requests/"), "page rechargée après la déconnexion : retour à la connexion, aucune liste demandée");
} catch (e) {
  out(`ÉCHEC parcours : ${e.message}`);
  failures += 1;
}

check(expected401Count === 3, `seuls 3 refus 401 attendus journalisés (2 rafraîchissements sans session + 1 mauvais mot de passe) : ${expected401Count}`);
check(problems.length === 0, `aucune erreur ni avertissement de console / page${problems.length ? " : " + problems.join(" | ") : ""}`);
await browser.close();
server.close();
if (failures) process.exitCode = 1;
out(failures ? `${failures} échec(s)` : "Parcours admin navigateur : OK");
