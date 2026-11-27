// Essai navigateur de la PWA NetBuis (Playwright, Chromium).
//
// Usage :
//   node mobile/e2e/pwa.mjs --prod=mobile/build/web --fake=/chemin/vers/build-fake
//   node mobile/e2e/pwa.mjs --prod=mobile/build/web --fake=... --url=http://127.0.0.1:8080/   (site déjà servi, ex. conteneur)
//
//   --prod : build de production (`flutter build web --release --no-web-resources-cdn --dart-define=API_URL=https://...`)
//   --fake : build jetable avec les fausses données (`... -o <dossier> --dart-define=USE_FAKE_API=true`), pour le parcours
//            connexion + recherche (le build de production ne parle qu'à un vrai serveur).
//   --url  : si donné, la partie « prod » est jouée sur cette adresse au lieu du petit serveur Node.
// Variables : PLAYWRIGHT_DIR (défaut /opt/node-tools/node_modules/playwright), FONT_FILE / EMOJI_FONT_FILE (voir plus bas).
//
// Le petit serveur Node reproduit les règles de cache de mobile/nginx.conf.template. Le navigateur d'essai
// n'a pas accès à fonts.gstatic.com (police Roboto de repli de Flutter) : ces demandes sont comptées puis
// servies localement ; elles sont listées dans le compte rendu (elles ne sont PAS mises en cache par le service worker).
import { createRequire } from "node:module";
import { createServer } from "node:http";
import { readFileSync, existsSync, statSync } from "node:fs";
import { extname, join, resolve } from "node:path";
import { gzipSync } from "node:zlib";

const require = createRequire(import.meta.url);
const out = (t) => process.stdout.write(`${t}\n`);
const { chromium } = require(process.env.PLAYWRIGHT_DIR ?? "/opt/node-tools/node_modules/playwright");
const arg = (n) => process.argv.find((a) => a.startsWith(`--${n}=`))?.slice(n.length + 3);
const PROD = arg("prod") && resolve(arg("prod"));
const FAKE = arg("fake") && resolve(arg("fake"));
const EXTERNAL_URL = arg("url");
if (!PROD || !FAKE) { console.error("Il faut --prod=<dossier> et --fake=<dossier>"); process.exit(2); }
const FONT = process.env.FONT_FILE ?? "";
const EMOJI = process.env.EMOJI_FONT_FILE ?? "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf";

const results = [];
const check = (name, ok, detail = "") => { results.push({ name, ok: !!ok, detail }); out(`${ok ? "OK  " : "ECHEC"} ${name}${detail ? " : " + detail : ""}`); };
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

const MIME = { ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript", ".wasm": "application/wasm", ".json": "application/json", ".png": "image/png", ".svg": "image/svg+xml", ".otf": "font/otf", ".ttf": "font/ttf", ".css": "text/css", ".ico": "image/x-icon" };
const SEC = { "X-Content-Type-Options": "nosniff", "X-Frame-Options": "DENY", "Referrer-Policy": "same-origin" };
function cacheFor(path) {
  if (/^\/(index\.html|netbuis_sw\.js|flutter_service_worker\.js|flutter_bootstrap\.js|manifest\.json|version\.json)$/.test(path)) return "no-store";
  if (path === "/main.dart.js") return "no-cache";
  if (path.startsWith("/canvaskit/")) return "public, max-age=604800";
  if (/^\/(assets|icons)\//.test(path)) return "public, max-age=86400";
  return undefined;
}
const COMPRESSIBLE = new Set([".js", ".mjs", ".json", ".wasm", ".css", ".svg"]);
function serve(root) {
  const gz = new Map();
  const srv = createServer((q, r) => {
    const path = new URL(q.url, "http://x").pathname;
    let f = join(root, path);
    let urlPath = path;
    if (!f.startsWith(root) || !existsSync(f) || statSync(f).isDirectory()) { f = join(root, "index.html"); urlPath = "/index.html"; } // repli SPA
    const ext = extname(f);
    const h = { "Content-Type": MIME[ext] ?? "application/octet-stream", ...SEC };
    const c = cacheFor(urlPath); if (c) h["Cache-Control"] = c;
    let body = readFileSync(f);
    if (COMPRESSIBLE.has(ext) && /gzip/.test(q.headers["accept-encoding"] ?? "") && body.length > 1024) {
      if (!gz.has(f)) gz.set(f, gzipSync(body, { level: 6 }));
      body = gz.get(f); h["Content-Encoding"] = "gzip"; h["Vary"] = "Accept-Encoding";
    }
    h["Content-Length"] = body.length;
    r.writeHead(200, h); r.end(body);
  });
  return new Promise((ok) => srv.listen(0, "127.0.0.1", () => ok({ srv, url: `http://127.0.0.1:${srv.address().port}/` })));
}

const browser = await chromium.launch({ args: ["--no-sandbox", "--use-gl=swiftshader", "--enable-unsafe-swiftshader"] });
async function newCtx() {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: "fr-FR", serviceWorkers: "allow" });
  const page = await ctx.newPage();
  const external = new Map(); const sizes = new Map(); const errors = [];
  const origin = () => new URL(page.url() === "about:blank" ? "http://127.0.0.1" : page.url()).origin;
  await ctx.route(/fonts\.gstatic\.com|gstatic\.com\/flutter-canvaskit\//, (r) => {
    const u = r.request().url(); external.set(u, (external.get(u) ?? 0) + 1);
    if (/fonts\.gstatic\.com/.test(u) && FONT && existsSync(FONT)) return r.fulfill({ body: readFileSync(/emoji/i.test(u) ? EMOJI : FONT), contentType: "font/ttf" });
    return r.abort();
  });
  page.on("pageerror", (e) => errors.push(e.message.slice(0, 200)));
  page.on("requestfinished", async (req) => { try { const u = new URL(req.url()); if (u.origin === origin() && !sizes.has(u.pathname)) sizes.set(u.pathname, String((await req.sizes()).responseBodySize)); } catch {} });
  return { ctx, page, external, sizes, errors };
}
const flutterUp = (p) => p.waitForSelector("flt-glass-pane", { state: "attached", timeout: 60000 });

// ---------------------------------------------------------------- 1. Version de production
const prod = EXTERNAL_URL ? { srv: null, url: EXTERNAL_URL } : await serve(PROD);
{
  const { ctx, page, external, sizes, errors } = await newCtx();
  // En-têtes
  const r1 = await ctx.request.get(prod.url);
  const hd = r1.headers();
  check("index.html : Cache-Control no-store", hd["cache-control"] === "no-store", hd["cache-control"]);
  check("en-têtes de sécurité", hd["x-content-type-options"] === "nosniff" && hd["x-frame-options"] === "DENY" && hd["referrer-policy"] === "same-origin");
  for (const [p, want] of [["netbuis_sw.js", "no-store"], ["manifest.json", "no-store"], ["version.json", "no-store"], ["main.dart.js", "no-cache"], ["canvaskit/canvaskit.wasm", /max-age=\d{6,}/], ["icons/Icon-192.png", /max-age=\d+/]]) {
    const r = await ctx.request.get(prod.url + p);
    const cc = r.headers()["cache-control"] ?? "";
    check(`${p} : Cache-Control`, want instanceof RegExp ? want.test(cc) : cc === want, cc);
    if (p.endsWith(".wasm")) check("canvaskit.wasm : type MIME application/wasm", r.headers()["content-type"] === "application/wasm", r.headers()["content-type"]);
  }
  const spa = await ctx.request.get(prod.url + "une/adresse/inconnue");
  check("repli SPA : adresse inconnue -> index.html", spa.status() === 200 && (await spa.text()).includes("flutter_bootstrap.js"));

  // Manifeste
  await page.goto(prod.url);
  const mHref = await page.evaluate(() => document.querySelector('link[rel="manifest"]')?.getAttribute("href"));
  check("index.html lie le manifeste", mHref === "manifest.json", String(mHref));
  const m = await (await ctx.request.get(prod.url + "manifest.json")).json();
  check("manifeste : nom NetBuis / short_name NetBuis / lang fr", m.name === "NetBuis" && m.short_name === "NetBuis" && m.lang === "fr");
  check("manifeste : standalone, portrait, start_url", m.display === "standalone" && m.orientation === "portrait" && m.start_url === ".");
  check("manifeste : couleurs", /^#[0-9A-Fa-f]{6}$/.test(m.theme_color) && /^#[0-9A-Fa-f]{6}$/.test(m.background_color), `${m.theme_color} ${m.background_color}`);
  for (const ic of m.icons) {
    const r = await ctx.request.get(prod.url + ic.src); const b = await r.body();
    const w = b.readUInt32BE(16), h = b.readUInt32BE(20);
    check(`icône ${ic.src} (${ic.purpose}) chargée, ${ic.sizes}`, r.status() === 200 && b.slice(1, 4).toString() === "PNG" && `${w}x${h}` === ic.sizes, `${w}x${h}`);
  }
  const purposes = new Set(m.icons.map((i) => `${i.sizes}/${i.purpose}`));
  check("icônes 192 et 512, any et maskable", ["192x192/any", "512x512/any", "192x192/maskable", "512x512/maskable"].every((x) => purposes.has(x)));
  const apple = await page.evaluate(() => ({ t: document.querySelector('link[rel="apple-touch-icon"]')?.getAttribute("href"), c: document.querySelector('meta[name="apple-mobile-web-app-capable"]')?.content, v: document.querySelector('meta[name="viewport"]')?.content }));
  check("iPhone : apple-touch-icon + apple-mobile-web-app-capable + viewport", apple.t && apple.c === "yes" && /width=device-width/.test(apple.v), JSON.stringify(apple));

  // Chargement, service worker
  await flutterUp(page);
  await wait(3000);
  const sw = await page.evaluate(async () => { const reg = await navigator.serviceWorker.ready; return reg.active?.scriptURL ?? null; });
  check("service worker enregistré et actif", sw && sw.endsWith("netbuis_sw.js"), String(sw));
  // Attendre que le service worker ait rempli son cache (installation terminée)
  let cached = [];
  for (let i = 0; i < 60; i++) {
    cached = await page.evaluate(async () => { const o = []; for (const k of await caches.keys()) { const c = await caches.open(k); for (const q of await c.keys()) o.push(new URL(q.url).pathname); } return o; });
    if (cached.some((p) => p.endsWith("canvaskit.wasm")) && cached.some((p) => p.endsWith("main.dart.js"))) break;
    await wait(1000);
  }
  check("cache du service worker : main.dart.js, canvaskit.wasm, manifeste, icônes", ["main.dart.js", "canvaskit.wasm", "manifest.json", "Icon-192.png"].every((n) => cached.some((p) => p.endsWith(n))), `${cached.length} fichiers`);
  await page.reload(); await flutterUp(page); await wait(2000);
  check("page contrôlée par le service worker après rechargement", await page.evaluate(() => !!navigator.serviceWorker.controller));
  check("première image affichée : écran d'attente retiré", await page.evaluate(() => !document.getElementById("chargement")));
  check("aucune erreur JavaScript au chargement", errors.length === 0, errors.join(" | "));
  const gs = [...external.keys()].filter((u) => /flutter-canvaskit/.test(u));
  check("CanvasKit servi par nous (aucune demande à gstatic.com/flutter-canvaskit)", gs.length === 0, gs.join(", "));

  // Hors connexion
  await ctx.setOffline(true);
  await page.reload(); await flutterUp(page); await wait(3000);
  await page.evaluate(() => document.querySelector("flt-semantics-placeholder")?.click()); await wait(800);
  const labels = await page.evaluate(() => [...document.querySelectorAll("flt-semantics")].map((e) => e.getAttribute("aria-label") || e.textContent || "").join(" | "));
  const offlineOk = /Commencer/.test(labels) || /NetBuis/i.test(labels);
  check("rechargement HORS CONNEXION : l'application s'affiche (écran de lancement)", offlineOk, labels.slice(0, 120));
  await page.screenshot({ path: process.env.SHOT_OFFLINE ?? "/dev/null" }).catch(() => {});
  await ctx.setOffline(false);
  const ext = [...external.entries()].map(([u, n]) => `${new URL(u).host}${new URL(u).pathname.slice(0, 40)} x${n}`);
  out("Demandes externes vues (hors site) : " + (ext.length ? ext.join(" ; ") : "aucune"));
  const total = [...sizes.entries()].filter(([, s]) => s !== "?").reduce((a, [, s]) => a + Number(s), 0);
  out("Poids transféré (corps compressé, première demande de chaque fichier) :");
  for (const [p, s] of [...sizes.entries()].sort((a, b) => Number(b[1]) - Number(a[1])).slice(0, 8)) out(`   ${p} ${(Number(s) / 1024).toFixed(0)} Ko`);
  out(`   total des fichiers vus ${(total / 1048576).toFixed(1)} Mo`);
  await ctx.close();
}
prod.srv?.close();

// ---------------------------------------------------------------- 2. Parcours avec les fausses données
{
  const fake = await serve(FAKE);
  const { ctx, page, errors } = await newCtx();
  await page.goto(fake.url); await flutterUp(page); await wait(5000);
  await page.evaluate(() => document.querySelector("flt-semantics-placeholder")?.click()); await wait(800);
  const btn = (re) => page.getByRole("button", { name: re }).first();
  const typeInto = async (t, clear = false) => { const tb = page.getByRole("textbox").first(); await tb.click(); await wait(300); if (clear) { await page.keyboard.press("Control+A"); await page.keyboard.press("Backspace"); } await page.keyboard.type(t, { delay: 80 }); };
  const semantics = () => page.evaluate(() => [...document.querySelectorAll("flt-semantics")].map((e) => e.getAttribute("aria-label") || e.textContent || "").join(" | "));
  try {
    await btn(/^Commencer$/).click({ timeout: 20000 }); await wait(1200);
    for (let i = 0; i < 5; i++) { await btn(/Suivant|Commencer/).click(); await wait(800); }
    await btn(/Maroua/).click(); await wait(1500);
    await typeInto("600000004"); await wait(500);
    await btn(/Recevoir le code/).click(); await wait(1800);
    await typeInto("123456"); await wait(3500);
    await typeInto("Essai PWA"); await wait(500);
    await btn(/Continuer/).click(); await wait(3000);
    check("connexion (numéro + code de démonstration) : accueil affiché", /Rechercher/.test(await semantics()));
    await btn(/^Rechercher$/).click(); await wait(1500);
    await typeInto("riz"); await wait(1500);
    await page.keyboard.press("Enter"); await wait(3500);
    const s = await semantics();
    check("recherche « riz » : des résultats s'affichent", /riz/i.test(s) && !/Aucun r[ée]sultat/i.test(s), s.slice(0, 160));
    await page.screenshot({ path: process.env.SHOT_RESULTS ?? "/dev/null" }).catch(() => {});
  } catch (e) { check("parcours connexion + recherche", false, String(e).slice(0, 200)); }
  check("parcours : aucune erreur JavaScript", errors.length === 0, errors.join(" | "));
  await ctx.close(); fake.srv.close();
}
await browser.close();
const bad = results.filter((r) => !r.ok);
out(`\n${results.length - bad.length}/${results.length} contrôles réussis`);
process.exit(bad.length ? 1 : 0);
