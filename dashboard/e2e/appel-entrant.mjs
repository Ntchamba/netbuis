// Essai dans un vrai navigateur (Playwright + Chromium) : faux serveur d'API local + faux flux SSE
// + faux Jitsi (script `external_api.js` factice). Mesure le délai « événement serveur → fenêtre affichée ».
// Lancer : npm run build && node e2e/appel-entrant.mjs   (Playwright déjà installé ; PLAYWRIGHT_MODULE=chemin si besoin)
import { createRequire } from "node:module";
import { createServer } from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { extname, join, resolve } from "node:path";

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE ?? "playwright");
const DIST = resolve(new URL("../dist", import.meta.url).pathname);
const RUNS = Number(process.env.RUNS ?? 30);
const JITSI_DOMAIN = "jitsi.exemple.test"; // domaine fictif, intercepté par le navigateur
const SESSION = "11111111-1111-4111-8111-111111111111";
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".svg": "image/svg+xml" };

let stream = null; // flux SSE de l'agent (une seule connexion)
let accepted = 0;
let ended = 0;
let seenAuth = [];
let contextReads = 0;
const PHONE_BUSINESS = "+237600000001"; // numéros fictifs (essai seulement)
const PHONE_CALLER = "+237600000002";
const json = (res, status, data) => {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(data));
};

const server = createServer((req, res) => {
  const url = new URL(req.url, "http://x");
  if (url.pathname === "/api/auth/refresh/") return json(res, 200, { access: "jeton-acces-fictif" });
  if (url.pathname === "/api/admin/me/")
    return json(res, 200, { id: 4, name: "Agent Test", phone_masked: "+237 6•• •• •• 12", roles: ["Validateur"], permissions: ["peut_voir_demandes", "peut_voir_comptes", "peut_repondre_aux_appels"] });
  if (url.pathname === "/api/admin/requests/") return json(res, 200, { count: 0, next: null, results: [] });
  if (url.pathname === "/api/admin/calls/stream/") {
    seenAuth.push(req.headers.authorization);
    res.writeHead(200, { "Content-Type": "text/event-stream", "Cache-Control": "no-store" });
    res.write('retry: 2000\n\nevent: presence\ndata: {"available":true}\n\n');
    stream = res;
    req.on("close", () => { if (stream === res) stream = null; });
    return;
  }
  if (url.pathname === "/api/admin/calls/presence/") return json(res, 200, { available: true });
  if (url.pathname.endsWith("/accept/")) {
    accepted += 1;
    return json(res, 200, { session_id: SESSION, caller_name: "Awa", business: { id: 7, name: "Boutique Test", type_label: "Entreprise", kind: "entreprise" }, jitsi: { domain: JITSI_DOMAIN, room: "salle-fictive", jwt: "jeton-fictif" } });
  }
  if (url.pathname.endsWith("/context/")) {
    contextReads += 1;
    return json(res, 200, {
      session_id: SESSION, state: "answered", caller: { name: "Awa", phone: PHONE_CALLER },
      business: {
        id: 7, name: "Boutique Test", type_compte: "entreprise", type_label: "Entreprise", kind: "entreprise", phone: PHONE_BUSINESS,
        owner_name: "Mme Ngo", category: "Alimentation", sous_categories: [], zone_name: "Domayo", zone_parent_name: "Maroua", repere: "Près du marché",
        description: "Vente de riz.", representant_nom: "", forme_juridique: "", rccm: "", photo_url: null, representant_photo_url: null, status: "actif",
        cni_verifiee: false, motif_rejet: "", subscription: { active: false, end: null }, reports_count: 0, whatsapp_reports_count: 0,
        calls_count: 0, views_count: 0, created_at: "2026-01-01T00:00:00Z", history: [],
      },
    });
  }
  if (url.pathname.endsWith("/end/")) { ended += 1; return json(res, 200, { session_id: SESSION, state: "ended" }); }
  if (url.pathname === "/__ring") {
    // Date.now() juste avant l'écriture sur le flux = « événement serveur ».
    const sentAt = Date.now();
    stream?.write(`event: ringing\ndata: ${JSON.stringify({ session_id: SESSION, state: "ringing", caller_name: "Awa", business: { id: 7, name: "Boutique Test", type_label: "Entreprise", kind: "entreprise" }, expires_at: null, ring_seconds_left: 30 })}\n\n`);
    return json(res, 200, { sentAt });
  }
  if (url.pathname === "/__taken") { stream?.write(`event: taken\ndata: {"session_id":"${SESSION}","state":"answered","reason":""}\n\n`); return json(res, 200, {}); }
  if (url.pathname === "/api/admin/calls/") return json(res, 200, { count: 0, next: null, previous: null, results: [] });
  if (url.pathname.startsWith("/api/")) return json(res, 404, {});
  // Fichiers statiques du dashboard (repli sur index.html).
  let file = join(DIST, url.pathname);
  if (!file.startsWith(DIST) || !existsSync(file) || url.pathname === "/") file = join(DIST, "index.html");
  res.writeHead(200, { "Content-Type": TYPES[extname(file)] ?? "application/octet-stream" });
  res.end(readFileSync(file));
});
await new Promise((ok) => server.listen(0, "127.0.0.1", ok));
const origin = `http://127.0.0.1:${server.address().port}`;

// Faux Jitsi : un script qui crée une iframe factice et garde ce qu'il a reçu dans window.__jitsi.
const FAKE_API = `
window.JitsiMeetExternalAPI = class {
  constructor(domain, options) {
    window.__jitsi = { domain, roomName: options.roomName, jwt: options.jwt, config: options.configOverwrite, disposed: false };
    this.frame = document.createElement("iframe");
    this.frame.title = "Jitsi factice";
    this.frame.srcdoc = "<p>Salle factice</p>";
    this.frame.style.cssText = "width:100%;height:100%;border:0";
    options.parentNode.appendChild(this.frame);
  }
  addListener() {}
  executeCommand() {}
  dispose() { window.__jitsi.disposed = true; this.frame.remove(); }
};`;

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH, args: ["--no-sandbox"] });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
await page.route(`https://${JITSI_DOMAIN}/external_api.js`, (route) => route.fulfill({ contentType: "text/javascript", body: FAKE_API }));
const consoleLines = [];
page.on("console", (m) => consoleLines.push(m.text()));
page.on("pageerror", (e) => { console.error("ERREUR PAGE :", e.message); process.exitCode = 1; });

// Mesure dans la page : l'instant (Date.now) où la fenêtre apparaît dans le DOM, puis au premier affichage (rAF).
await page.addInitScript(() => {
  window.__seen = [];
  new MutationObserver(() => {
    const el = document.querySelector('[data-testid="incoming-call"]');
    if (el && !el.dataset.t) {
      el.dataset.t = "1";
      const dom = Date.now();
      requestAnimationFrame(() => window.__seen.push({ dom, paint: Date.now() }));
    }
  }).observe(document, { childList: true, subtree: true });
});

await page.goto(`${origin}/demandes`);
await page.waitForSelector('[role="switch"]');
await page.waitForFunction(() => document.querySelector('[role="switch"]')?.getAttribute("aria-checked") === "true");
const results = [];
let failures = 0;
const out = (t) => process.stdout.write(`${t}\n`);
const check = (ok, msg) => { out(`${ok ? "OK " : "ÉCHEC"} ${msg}`); if (!ok) failures += 1; };

for (let i = 0; i < RUNS; i++) {
  await page.evaluate(() => { window.__seen = []; document.querySelector('[data-testid="incoming-call"]')?.remove(); });
  const { sentAt } = await (await fetch(`${origin}/__ring`)).json();
  await page.waitForFunction(() => window.__seen.length > 0, null, { polling: "raf" });
  const seen = await page.evaluate(() => window.__seen[0]);
  results.push({ dom: seen.dom - sentAt, paint: seen.paint - sentAt });
  await fetch(`${origin}/__taken`); // ferme la fenêtre pour l'essai suivant
  await page.waitForSelector('[data-testid="incoming-call"]', { state: "detached" });
}
const pct = (arr, p) => [...arr].sort((a, b) => a - b)[Math.min(arr.length - 1, Math.ceil(arr.length * p) - 1)];
const dom = results.map((r) => r.dom);
const paint = results.map((r) => r.paint);
out(`Délai événement serveur -> fenêtre dans le DOM (ms) sur ${RUNS} essais : min ${Math.min(...dom)} · p50 ${pct(dom, 0.5)} · p95 ${pct(dom, 0.95)} · max ${Math.max(...dom)}`);
out(`Délai événement serveur -> fenêtre peinte (ms)  : min ${Math.min(...paint)} · p50 ${pct(paint, 0.5)} · p95 ${pct(paint, 0.95)} · max ${Math.max(...paint)}`);
check(pct(paint, 0.95) < 200 && Math.max(...paint) < 200, "toutes les mesures < 200 ms (fenêtre peinte)");

// Parcours : sonnerie -> contenu -> Répondre -> salle -> Raccrocher.
await fetch(`${origin}/__ring`);
const dialog = page.getByRole("alertdialog");
await dialog.waitFor();
const dialogText = dialog.textContent();
check((await dialog.textContent()).includes("Awa") && (await dialog.textContent()).includes("Boutique Test"), "la fenêtre montre l'appelant et le commerce");
check(await page.evaluate(() => document.activeElement?.textContent === "Répondre"), "le focus est sur Répondre (clavier)");
const heights = await dialog.getByRole("button").evaluateAll((els) => els.map((e) => e.getBoundingClientRect().height));
check(heights.every((h) => h >= 44), `boutons >= 44 px (${heights.join(", ")})`);
await page.keyboard.press("Enter"); // Répondre au clavier
await page.getByTestId("call-room").waitFor();
await page.frameLocator("iframe[title='Jitsi factice']").getByText("Salle factice").waitFor();
const j = await page.evaluate(() => window.__jitsi);
check(j.domain === JITSI_DOMAIN && j.roomName === "salle-fictive" && j.jwt === "jeton-fictif", "la salle utilise le domaine, la salle et le jeton de l'API");
check(j.config.startWithVideoMuted === true && j.config.startAudioOnly === true, "audio seul, vidéo coupée");
const stored = await page.evaluate(() => JSON.stringify({ ...localStorage }) + JSON.stringify({ ...sessionStorage }));
check(!stored.includes("salle-fictive") && !stored.includes("jeton-fictif"), "aucune salle ni jeton dans localStorage / sessionStorage");
check(seenAuth.length >= 1 && seenAuth.every((a) => a === "Bearer jeton-acces-fictif"), "le flux SSE s'authentifie avec le jeton d'accès (en-tête)");
// T132b (D-30) : Voir la fiche -> numéros visibles -> l'appel reste en cours.
check((await dialogText).includes("Entreprise"), "la fenêtre d'appel entrant indique le type (Entreprise)");
check(contextReads === 0 && !(await page.content()).includes("600000001"), "avant de répondre : aucune lecture de fiche, aucun numéro dans la page");
const target = page.getByTestId("call-target");
check((await target.textContent()).includes("Boutique Test") && (await target.textContent()).includes("Entreprise"), "la salle montre le nom et le type du commerce visé");
const ficheRequest = page.waitForResponse((r) => r.url().endsWith("/context/"));
await page.getByRole("button", { name: "Voir la fiche" }).click();
await ficheRequest;
const panel = page.getByTestId("call-fiche");
await panel.waitFor();
check((await panel.getByTestId("phone-business").textContent()) === "+237 600 000 001", "numéro du commerce visible dans le panneau");
check((await panel.getByTestId("phone-caller").textContent()) === "+237 600 000 002", "numéro de l'appelant visible dans le panneau");
check((await panel.textContent()).includes("Domayo, Maroua") && (await panel.textContent()).includes("Près du marché"), "fiche complète affichée");
const boxes = await page.evaluate(() => {
  const r = (t) => document.querySelector(`[data-testid="${t}"]`).getBoundingClientRect();
  const a = r("call-fiche"), b = r("call-room");
  return { overlap: a.right > b.left && a.left < b.right && a.bottom > b.top && a.top < b.bottom, hangUpVisible: !!document.querySelector('[data-testid="call-room"] button') };
});
check(!boxes.overlap && boxes.hangUpVisible, "le panneau est à côté de la salle (aucun recouvrement)");
check(ended === 0 && accepted === 1 && (await page.evaluate(() => window.__jitsi.disposed)) === false, "l'appel reste en cours : ni end, ni nouvelle réponse, salle Jitsi toujours ouverte");
check(await page.getByTestId("call-room").isVisible() && (await page.frameLocator("iframe[title='Jitsi factice']").getByText("Salle factice").isVisible()), "la salle est toujours visible");
const stored2 = await page.evaluate(() => JSON.stringify({ ...localStorage }) + JSON.stringify({ ...sessionStorage }));
check(!stored2.includes("600000001") && !stored2.includes("600000002") && !consoleLines.join("\n").includes("600000001"), "aucun numéro dans le stockage ni dans la console");
await panel.getByRole("button", { name: "Fermer la fiche" }).click();
await panel.waitFor({ state: "detached" });
check(await page.getByTestId("call-room").isVisible(), "fermer la fiche ne coupe pas la salle");
await page.getByRole("button", { name: "Raccrocher" }).click();
await page.getByTestId("call-room").waitFor({ state: "detached" });
check(accepted === 1 && ended === 1 && (await page.evaluate(() => window.__jitsi.disposed)), "accept et end envoyés, salle fermée");
check(!(await page.content()).includes("600 000 001") && !(await page.content()).includes("600 000 002"), "après avoir raccroché : plus aucun numéro dans la page");

// Reconnexion : le serveur coupe le flux, le navigateur se reconnecte et la sonnerie rejouée s'affiche.
const old = stream;
stream = null;
old?.end();
const start = Date.now();
while (!stream && Date.now() - start < 8000) await new Promise((r) => setTimeout(r, 50));
check(stream !== null && stream !== old, `reconnexion automatique du flux (${Date.now() - start} ms)`);
await fetch(`${origin}/__ring`);
await page.getByRole("alertdialog").waitFor();
check(true, "la fenêtre s'affiche sur le nouveau flux");
await browser.close();
server.close();
if (failures) process.exitCode = 1;
out(failures ? `${failures} échec(s)` : "Essai navigateur : OK");
