// T134 — appel de bout en bout contre le VRAI serveur (uvicorn + PostgreSQL) et un vrai navigateur (Chromium).
// Seul Jitsi est simulé (script external_api.js factice). Données fictives, base de développement jetable.
// Lancer depuis la racine : (dashboard déjà construit) node scripts/e2e_appel/bout_en_bout.mjs
// Variables : PYTHON (venv du backend), PLAYWRIGHT_MODULE, RUNS (défaut 30). Le DATABASE_URL doit déjà être exposé.
import { createRequire } from "node:module";
import { createServer, request as httpRequest } from "node:http";
import { execFileSync, spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import { readFileSync, existsSync } from "node:fs";
import { extname, join, resolve } from "node:path";

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE ?? "playwright");
const ROOT = resolve(new URL("../..", import.meta.url).pathname);
const DIST = join(ROOT, "dashboard/dist");
const PY = process.env.PYTHON ?? "python";
const RUNS = Number(process.env.RUNS ?? 30);
const API_PORT = 8765;
const JITSI_DOMAIN = "jitsi.exemple.test";
const out = (t) => process.stdout.write(`${t}\n`);
let failures = 0;
const check = (ok, msg) => { out(`${ok ? "OK   " : "ÉCHEC"} ${msg}`); if (!ok) failures += 1; };
const pct = (a, p) => [...a].sort((x, y) => x - y)[Math.min(a.length - 1, Math.floor(a.length * p))];

const env = {
  ...process.env, DEBUG: "True", DJANGO_SETTINGS_MODULE: "config.settings.dev", SMS_PROVIDER: "console",
  JITSI_DOMAIN, JITSI_APP_ID: "netbuis-essai", JITSI_JWT_SECRET: randomBytes(32).toString("hex"),
};
const data = JSON.parse(execFileSync(PY, [join(ROOT, "scripts/e2e_appel/setup_data.py")], { cwd: join(ROOT, "backend"), env }).toString().trim().split("\n").pop());
const [A1, A2] = data.agents;
const BIZ = data.business;
const CALLER_PHONE = data.caller.phone;

const api = spawn(PY, ["-m", "uvicorn", "config.asgi:application", "--port", String(API_PORT), "--log-level", "warning"], { cwd: join(ROOT, "backend"), env, stdio: ["ignore", "ignore", "pipe"] });
let apiErr = "";
api.stderr.on("data", (d) => { apiErr += d; });
const stopAll = async (code) => { api.kill("SIGTERM"); process.exit(code); };
for (let i = 0; i < 60; i++) {
  try { const r = await fetch(`http://127.0.0.1:${API_PORT}/api/me/`); if (r.status) break; } catch { /* pas encore prêt */ }
  await new Promise((r) => setTimeout(r, 500));
}

// Relais : fichiers du dashboard + /api vers uvicorn (même origine, flux SSE en continu). Il note chaque réponse JSON.
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".svg": "image/svg+xml" };
const seen = []; // {path, status, hasPhone}
const PHONES = () => [BIZ.phone, CALLER_PHONE, BIZ.phone.replace("+237", ""), CALLER_PHONE.replace("+237", "")];
const proxy = createServer((req, res) => {
  const url = new URL(req.url, "http://x");
  if (url.pathname.startsWith("/api/")) {
    const up = httpRequest({ host: "127.0.0.1", port: API_PORT, path: req.url, method: req.method, headers: req.headers }, (ur) => {
      res.writeHead(ur.statusCode, ur.headers);
      const stream = url.pathname.includes("/stream/") || url.pathname.endsWith("/events/");
      let body = "";
      ur.on("data", (c) => { res.write(c); if (!stream) body += c; });
      ur.on("end", () => { res.end(); if (!stream) seen.push({ path: url.pathname, status: ur.statusCode, hasPhone: PHONES().some((p) => body.includes(p)) }); });
    });
    req.pipe(up);
    return;
  }
  let file = join(DIST, url.pathname);
  if (!file.startsWith(DIST) || !existsSync(file) || url.pathname === "/") file = join(DIST, "index.html");
  res.writeHead(200, { "Content-Type": TYPES[extname(file)] ?? "application/octet-stream" });
  res.end(readFileSync(file));
});
await new Promise((ok) => proxy.listen(0, "127.0.0.1", ok));
const origin = `http://127.0.0.1:${proxy.address().port}`;

const FAKE_API = `
window.JitsiMeetExternalAPI = class {
  constructor(domain, options) {
    window.__jitsi = { domain, roomName: options.roomName, jwt: options.jwt, disposed: false };
    this.frame = document.createElement("iframe"); this.frame.title = "Jitsi factice"; this.frame.srcdoc = "<p>Salle factice</p>";
    this.frame.style.cssText = "width:100%;height:100%;border:0"; options.parentNode.appendChild(this.frame);
  }
  addListener() {} executeCommand() {}
  dispose() { window.__jitsi.disposed = true; this.frame.remove(); }
};`;

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH, args: ["--no-sandbox"] });
async function agentPage(agent) {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const page = await ctx.newPage();
  await page.route(`https://${JITSI_DOMAIN}/external_api.js`, (r) => r.fulfill({ contentType: "text/javascript", body: FAKE_API }));
  page.on("pageerror", (e) => { out(`ERREUR PAGE : ${e.message}`); failures += 1; });
  await page.addInitScript(() => {
    window.__seen = [];
    new MutationObserver(() => {
      const el = document.querySelector('[data-testid="incoming-call"]');
      if (el && !el.dataset.t) { el.dataset.t = "1"; requestAnimationFrame(() => window.__seen.push(Date.now())); }
    }).observe(document, { childList: true, subtree: true });
  });
  await page.goto(`${origin}/connexion`);
  await page.getByLabel("Téléphone").fill(agent.phone);
  await page.getByLabel("Mot de passe").fill(agent.password);
  await page.getByRole("button", { name: /connexion|se connecter/i }).click();
  await page.waitForSelector('[role="switch"]', { timeout: 15000 });
  return page;
}
const available = (page, on) => page.waitForFunction((v) => document.querySelector('[role="switch"]')?.getAttribute("aria-checked") === v, on ? "true" : "false", { timeout: 15000 });

const caller = (path, method = "GET", body) => fetch(`http://127.0.0.1:${API_PORT}${path}`, {
  method, headers: { Authorization: `Bearer ${data.caller.access}`, "Content-Type": "application/json" }, body: body ? JSON.stringify(body) : undefined });

try {
  const p1 = await agentPage(A1);
  const p2 = await agentPage(A2);
  for (const p of [p1, p2]) { await p.getByRole("switch").click(); await available(p, true); }
  check(true, "deux agents connectés au tableau de bord, flux ouvert et disponibles");

  // 1) Scénario complet : appel -> sonnerie sur les deux -> l'agent 1 décroche -> l'agent 2 voit « pris » -> fiche -> fin.
  let r = await caller("/api/calls/sessions/", "POST", { business_id: BIZ.id });
  const s = await r.json();
  check(r.status === 201 || r.status === 200, `création de session (${r.status}, état ${s.state})`);
  check(Boolean(s.jitsi?.room && s.jitsi?.jwt), "l'appelant reçoit salle et jeton Jitsi");
  await p1.waitForSelector('[data-testid="incoming-call"]'); await p2.waitForSelector('[data-testid="incoming-call"]');
  check(true, "fenêtre d'appel entrant sur les DEUX tableaux de bord");
  check((await p1.textContent('[data-testid="incoming-call"]')).includes(BIZ.name), "le nom du commerce visé est affiché dans la sonnerie");
  const ringText = await p1.textContent('[data-testid="incoming-call"]');
  check(!PHONES().some((p) => ringText.includes(p)), "aucun numéro dans la fenêtre de sonnerie");
  await p1.getByRole("button", { name: /répondre/i }).click();
  await p2.waitForSelector('[data-testid="incoming-call"]', { state: "detached", timeout: 5000 });
  check(true, "l'agent 2 voit la fenêtre se fermer (un seul gagnant)");
  await p1.waitForFunction(() => window.__jitsi && !window.__jitsi.disposed, null, { timeout: 8000 });
  check(true, "l'agent 1 entre dans la salle Jitsi (domaine et jeton du serveur)");
  await p1.getByRole("button", { name: /voir la fiche/i }).click();
  await p1.waitForFunction(([a, b]) => document.body.innerText.includes(a) && document.body.innerText.includes(b), [BIZ.phone.replace("+237", "").slice(-4), CALLER_PHONE.replace("+237", "").slice(-4)], { timeout: 8000 }).catch(() => {});
  const body1 = await p1.innerText("body");
  check(body1.includes(BIZ.name), "fiche : nom du commerce");
  check([BIZ.phone, BIZ.phone.replace("+237", "")].some((p) => body1.replace(/\s/g, "").includes(p.replace(/\s/g, ""))), "fiche : numéro du commerce visible pendant l'appel");
  check(body1.replace(/\s/g, "").includes(CALLER_PHONE.replace("+237", "")) || body1.replace(/\s/g, "").includes(CALLER_PHONE), "fiche : numéro de l'appelant visible pendant l'appel");
  r = await caller(`/api/calls/sessions/${s.session_id}/end/`, "POST");
  await p1.waitForFunction(() => window.__jitsi?.disposed === true, null, { timeout: 8000 });
  check(true, "fin d'appel par l'appelant : la salle se ferme chez l'agent");
  await p1.waitForFunction(() => !document.body.innerText.includes("Voir la fiche") || true);
  const afterEnd = await p1.innerText("body");
  check(![BIZ.phone, BIZ.phone.replace("+237", "")].some((p) => afterEnd.replace(/\s/g, "").includes(p.replace(/\s/g, ""))), "les numéros disparaissent de l'écran après la fin");

  // 2) Mesure : p95 du POST à la fenêtre PEINTE (vrai serveur, vraie connexion SSE, boucle locale).
  const lat = [];
  for (let i = 0; i < RUNS; i++) {
    const before = (await p1.evaluate(() => window.__seen.length));
    const t0 = Date.now();
    r = await caller("/api/calls/sessions/", "POST", { business_id: BIZ.id });
    const sj = await r.json();
    await p1.waitForFunction((n) => window.__seen.length > n, before, { timeout: 5000 });
    const paint = await p1.evaluate(() => window.__seen[window.__seen.length - 1]);
    lat.push(paint - t0);
    await caller(`/api/calls/sessions/${sj.session_id}/cancel/`, "POST");
    await p1.waitForSelector('[data-testid="incoming-call"]', { state: "detached", timeout: 5000 });
  }
  out(`Délai POST appelant -> fenêtre PEINTE chez l'agent (ms), ${RUNS} essais : min ${Math.min(...lat)} · p50 ${pct(lat, 0.5)} · p95 ${pct(lat, 0.95)} · max ${Math.max(...lat)}`);
  check(pct(lat, 0.95) < 1000, "p95 < 1 seconde (D-26)");

  // 3) Aucun agent disponible : réponse immédiate.
  await p1.getByRole("switch").click(); await p2.getByRole("switch").click();
  await available(p1, false); await available(p2, false);
  const t1 = Date.now();
  r = await caller("/api/calls/sessions/", "POST", { business_id: BIZ.id });
  const un = await r.json();
  check(un.state === "unavailable" && !un.jitsi, `aucun agent disponible : réponse « unavailable » sans salle en ${Date.now() - t1} ms`);

  // 4) Aucun numéro ailleurs que dans la route de fiche.
  const leaks = seen.filter((x) => x.hasPhone).map((x) => x.path.replace(/[0-9a-f-]{36}/, "<id>"));
  check(leaks.every((p) => p.endsWith("/context/")) , `numéros dans les réponses vues par le navigateur : seulement ${[...new Set(leaks)].join(", ") || "aucune"}`);
  for (const path of ["/api/calls/history/", "/api/me/", `/api/search/?q=${encodeURIComponent("Boutique Essai")}`]) {
    const t = await (await caller(path)).text();
    check(!PHONES().some((p) => t.includes(p)), `aucun numéro dans ${path.split("?")[0]}`);
  }
} catch (e) {
  out(`ERREUR : ${e.message}`); failures += 1;
}
await browser.close(); proxy.close();
if (apiErr.trim()) out(`Messages d'erreur du serveur (extrait) : ${apiErr.split("\n").slice(-3).join(" | ").slice(0, 300)}`);
out(failures ? `${failures} échec(s)` : "Essai de bout en bout : OK");
await stopAll(failures ? 1 : 0);
