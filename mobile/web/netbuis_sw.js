// Service worker de NetBuis (PWA) : permet de rouvrir l'application sans connexion.
// Stratégie : « réseau d'abord » (on a toujours la dernière version quand on est en ligne), avec
// repli sur la copie gardée en cache quand le réseau manque ou répond trop lentement (> 5 s).
// Seules les requêtes GET du même site sont gérées : l'API (autre adresse) n'est jamais touchée ni
// mise en cache, donc aucun jeton ni donnée de compte n'est copié par ce fichier.
'use strict';

const CACHE = 'netbuis-pwa-v1';
const SLOW_NETWORK_MS = 5000;

// Chromium (Chrome, Edge, Android) charge canvaskit/chromium/ ; les autres navigateurs canvaskit/.
const ua = self.navigator.userAgent;
const chromium = /Chrome\/|Chromium|Edg\//.test(ua) && !/CriOS|FxiOS|iPhone|iPad/.test(ua);
const ENGINE = chromium ? 'canvaskit/chromium/' : 'canvaskit/';

// Copiés à l'installation. Un fichier absent n'empêche pas l'installation ; tout le reste est
// copié à la première utilisation.
const PRECACHE = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'main.dart.js',
  'manifest.json',
  'version.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/apple-touch-icon.png',
  ENGINE + 'canvaskit.js',
  ENGINE + 'canvaskit.wasm',
  'assets/AssetManifest.bin',
  'assets/AssetManifest.bin.json',
  'assets/FontManifest.json',
  'assets/fonts/MaterialIcons-Regular.otf',
  'assets/fonts/fallback/Roboto-Regular.ttf',
  'assets/assets/l10n/fr.json',
  'assets/assets/l10n/en.json',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      await Promise.allSettled(PRECACHE.map((url) => cache.add(new Request(url, { cache: 'reload' }))));
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) {
        if (key !== CACHE) await caches.delete(key);
      }
      await self.clients.claim();
    })(),
  );
});

async function networkFirst(request, cacheKey) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(cacheKey, { ignoreSearch: true });
  const fresh = fetch(request).then((response) => {
    if (response.status === 200 && response.type === 'basic') {
      cache.put(cacheKey, response.clone());
    }
    return response;
  });
  if (!cached) return fresh;
  const slow = new Promise((resolve) => setTimeout(() => resolve(cached), SLOW_NETWORK_MS));
  return Promise.race([fresh.catch(() => cached), slow]);
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || request.headers.has('range')) return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (url.pathname.endsWith('/netbuis_sw.js')) return;
  // Une page de l'application : toutes les adresses mènent à index.html (application monopage).
  if (request.mode === 'navigate') {
    const index = new URL('index.html', self.registration.scope).href;
    event.respondWith(networkFirst(request, index).catch(() => caches.match(index)));
    return;
  }
  event.respondWith(networkFirst(request, request));
});
