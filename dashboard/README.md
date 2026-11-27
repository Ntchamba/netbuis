# NetBuis — dashboard d'administration (React)

Vite + React + TypeScript + Tailwind. Un dossier = un module dans `src/modules/`.

```
npm install
npm run dev        # http://localhost:5173
npm run typecheck
npm run build
```

## Tests (T123)

```
npm test           # Vitest : tests unitaires par module + parcours de bout en bout dans tests/parcours/
npm run test:e2e   # construit le dashboard, puis rejoue deux essais dans un vrai Chromium
```

- `tests/parcours/` : une API simulée **à état** (`world.ts`) branche l'application entière (routes, session, menus).
  Un fichier par domaine : accès, demandes, comptes, modération, appels de l'équipe, référentiels et réglages, audit et export.
- `npm run test:e2e` lance `e2e/appel-entrant.mjs` (délai « événement serveur → fenêtre d'appel », salle, fiche, reconnexion)
  puis `e2e/parcours-admin.mjs` (connexion → demandes → valider → déconnexion). Chacun démarre un faux serveur local qui sert
  aussi le dossier `dist/` ; toute erreur de console ou de page fait échouer le second.
- **Playwright n'est pas une dépendance du projet.** Il est pris dans l'installation globale (`NODE_PATH`) ou à l'endroit donné par
  `PLAYWRIGHT_MODULE=/chemin/vers/playwright`. Chromium est cherché dans `PLAYWRIGHT_BROWSERS_PATH` (ex. `/opt/pw-browsers`)
  ou donné par `CHROMIUM_PATH=/chemin/vers/chrome`.

Le module `payments/` reste vide jusqu'à l'étape É6.

## Sécurité : en-têtes à poser sur l'hébergement statique (T121)

Le tableau de bord est un site statique (Vercel prévu). Rien n'est déployé ici : voici la configuration à appliquer le jour venu (`vercel.json` > `headers`, ou le réglage équivalent de l'hébergeur). Remplacer `API` par l'adresse exacte du serveur (même valeur que `VITE_API_BASE_URL`) et `JITSI` par le domaine Jitsi (`JITSI_DOMAIN`, ex. `8x8.vc` pour JaaS ; domaine propre si auto-hébergé).

```
Content-Security-Policy:
  default-src 'none';
  script-src 'self' https://JITSI;
  connect-src 'self' https://API;
  frame-src https://JITSI;
  img-src 'self' blob: https:;
  style-src 'self';
  style-src-attr 'unsafe-inline';
  font-src 'self';
  media-src 'self' blob:;
  base-uri 'none';
  form-action 'self';
  object-src 'none';
  frame-ancestors 'none'
Permissions-Policy: microphone=(self "https://JITSI"), camera=(), geolocation=(), payment=()
Strict-Transport-Security: max-age=31536000
X-Content-Type-Options: nosniff
Referrer-Policy: same-origin
Cross-Origin-Opener-Policy: same-origin
Cache-Control: no-store            (sur index.html uniquement ; les fichiers /assets/ sont versionnés)
```

Points à savoir :
- **Aucun script en ligne** : le thème est appliqué par `public/theme-init.js` (test `tests/securite.test.tsx`), donc `script-src` n'a pas besoin de `'unsafe-inline'`. `style-src-attr 'unsafe-inline'` ne sert que pour les `style=""` des graphiques.
- **Jitsi** : `external_api.js` est chargé dynamiquement depuis `https://JITSI/` (`script-src`), la salle s'ouvre dans une iframe du même domaine (`frame-src`) ; l'iframe reçoit `allow="microphone; …"` de `external_api.js`, et la `Permissions-Policy` ci-dessus doit autoriser le micro pour ce domaine, sinon l'audio est coupé. Auto-hébergé : le serveur Jitsi doit aussi autoriser la connexion WebSocket/UDP (voir `docs/deployment/JITSI.md`) ; ajouter `wss://JITSI` à `connect-src` si le navigateur bloque la signalisation.
- **Autre domaine pour l'API** : `CORS_ALLOWED_ORIGINS` et `CSRF_TRUSTED_ORIGINS` du serveur doivent contenir l'adresse exacte du tableau de bord, et le cookie de rafraîchissement doit être `Secure` + `SameSite` adapté (voir `docs/deployment/DEPLOYMENT.md`). Pour lire `Retry-After`, le serveur doit l'exposer (`CORS_EXPOSE_HEADERS`).
- **Réalité du navigateur** : le flux d'appels (SSE) passe par `fetch` vers `API` : couvert par `connect-src`.
- Variables lues par le navigateur : **seulement** `VITE_API_BASE_URL` (adresse publique). `VITE_USE_MOCKS` n'a d'effet que sur une page d'essai ; ne jamais y mettre de secret : tout ce qui commence par `VITE_` est lisible par tout le monde.
