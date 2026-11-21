// Essai WebRTC sans NetBuis : deux pages Chromium (micros simulés) s'appellent, avec ou sans relais coturn.
// Mesure le temps « offre créée → connexion établie » et vérifie que de l'audio est bien reçu.
// Usage : TURN_SECRET=... node scripts/e2e_webrtc/relais.mjs [--relay] [--runs=10] [--turn=127.0.0.1:3478]
//   --relay : force le passage par coturn (iceTransportPolicy: "relay").
// coturn doit tourner (docker compose up coturn) avec le même secret ; pour 127.0.0.1 il faut
// --allowed-peer-ip=127.0.0.1 (déjà le cas dans le docker-compose.yml local).
import { createRequire } from "node:module";
import { createHmac } from "node:crypto";
import { createServer } from "node:http";
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE ?? "/opt/node-tools/node_modules/playwright");
const out = (t) => process.stdout.write(`${t}\n`);
const arg = (n, d) => process.argv.find((a) => a.startsWith(`--${n}=`))?.split("=")[1] ?? d;
const RELAY = process.argv.includes("--relay");
const RUNS = Number(arg("runs", "10"));
const TURN = arg("turn", "127.0.0.1:3478");
const SECRET = process.env.TURN_SECRET;
if (RELAY && !SECRET) { out("TURN_SECRET manquant (--relay)"); process.exit(2); }
const pct = (a, p) => [...a].sort((x, y) => x - y)[Math.min(a.length - 1, Math.floor(a.length * p))];

function iceServers() {
  if (!SECRET) return [];
  const user = `${Math.floor(Date.now() / 1000) + 600}:essai`;
  const credential = createHmac("sha1", SECRET).update(user).digest("base64");
  return [{ urls: [`stun:${TURN}`, `turn:${TURN}?transport=udp`], username: user, credential }];
}

const PAGE = `<!doctype html><meta charset=utf-8><body><script>
window.mk = async (servers, relay) => {
  const pc = new RTCPeerConnection({ iceServers: servers, iceTransportPolicy: relay ? "relay" : "all" });
  window.pc = pc; window.cands = []; window.t0 = performance.now();
  pc.onicecandidate = (e) => { if (e.candidate) window.cands.push(e.candidate.toJSON()); };
  window.connected = new Promise((ok) => { pc.onconnectionstatechange = () => { if (pc.connectionState === "connected") ok(performance.now() - window.t0); }; });
  const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  stream.getTracks().forEach((t) => pc.addTrack(t, stream));
};
window.offer = async () => { const o = await pc.createOffer(); await pc.setLocalDescription(o); return o; };
window.answer = async (o) => { await pc.setRemoteDescription(o); const a = await pc.createAnswer(); await pc.setLocalDescription(a); return a; };
window.setAnswer = (a) => pc.setRemoteDescription(a);
window.addCand = (c) => pc.addIceCandidate(c);
window.drain = () => { const c = window.cands; window.cands = []; return c; };
window.stats = async () => { let bytes = 0, type = ""; (await pc.getStats()).forEach((r) => { if (r.type === "inbound-rtp" && r.kind === "audio") bytes = r.bytesReceived; if (r.type === "candidate-pair" && r.state === "succeeded" && r.nominated) type = r.localCandidateId; }); return { bytes }; };
window.pairType = async () => { const s = await pc.getStats(); let lid = null; s.forEach((r) => { if (r.type === "candidate-pair" && r.nominated) lid = r.localCandidateId; }); let t = ""; s.forEach((r) => { if (r.id === lid) t = r.candidateType; }); return t; };
</script></body>`;

// Une page servie sur http://localhost est un contexte sécurisé : le micro (getUserMedia) y est autorisé.
const srv = createServer((q, r) => { r.writeHead(200, { "Content-Type": "text/html" }); r.end(PAGE); });
await new Promise((ok) => srv.listen(0, "127.0.0.1", ok));
const URL_PAGE = `http://localhost:${srv.address().port}/`;
const browser = await chromium.launch({ args: ["--no-sandbox", "--use-fake-device-for-media-stream", "--use-fake-ui-for-media-stream"] });
const times = []; const types = new Set();
for (let i = 0; i < RUNS; i++) {
  const ctx = await browser.newContext(); await ctx.grantPermissions(["microphone"]);
  const A = await ctx.newPage(); const B = await ctx.newPage();
  await A.goto(URL_PAGE); await B.goto(URL_PAGE);
  const servers = iceServers();
  await A.evaluate(([s, r]) => mk(s, r), [servers, RELAY]); await B.evaluate(([s, r]) => mk(s, r), [servers, RELAY]);
  const offer = await A.evaluate(() => offer());
  const answer = await B.evaluate((o) => answer(o), offer);
  await A.evaluate((a) => setAnswer(a), answer);
  // Échange des candidats (comme le fera la signalisation de NetBuis) jusqu'à la connexion.
  const t0 = Date.now(); let done = false;
  const connectedA = A.evaluate(() => connected), connectedB = B.evaluate(() => connected);
  Promise.all([connectedA, connectedB]).then(() => { done = true; });
  while (!done && Date.now() - t0 < 15000) {
    for (const c of await A.evaluate(() => drain())) await B.evaluate((x) => addCand(x), c);
    for (const c of await B.evaluate(() => drain())) await A.evaluate((x) => addCand(x), c);
    await new Promise((r) => setTimeout(r, 20));
  }
  if (!done) {
    out(`ÉCHEC essai ${i + 1} : pas de connexion en 15 s`);
    if (process.env.DEBUG) for (const [n, P] of [["A", A], ["B", B]]) out(`  ${n} : ${await P.evaluate(() => pc.iceConnectionState + " / " + pc.iceGatheringState + " / " + (pc.remoteDescription ? "distant ok" : "distant absent"))}`);
    await ctx.close(); continue;
  }
  const ms = Math.max(await connectedA, await connectedB);
  await new Promise((r) => setTimeout(r, 1500));
  const s1 = await B.evaluate(() => stats()); types.add(await A.evaluate(() => pairType()));
  if (!(s1.bytes > 0)) out(`ÉCHEC essai ${i + 1} : aucun octet audio reçu`);
  times.push(ms);
  await ctx.close();
}
await browser.close(); srv.close();
out(`Mode : ${RELAY ? "relais coturn forcé" : "connexion libre"} ; type de chemin : ${[...types].join(",")}`);
out(`Connexion établie (ms) sur ${times.length}/${RUNS} essais : min ${Math.round(Math.min(...times))} · p50 ${Math.round(pct(times, 0.5))} · p95 ${Math.round(pct(times, 0.95))} · max ${Math.round(Math.max(...times))}`);
process.exit(times.length === RUNS ? 0 : 1);
