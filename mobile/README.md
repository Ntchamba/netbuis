# NetBuis — application mobile (Flutter, Android)

## Installer

```
flutter pub get
flutter analyze && flutter test --dart-define=USE_FAKE_API=true
```

## Construire l'APK (Android)

```
flutter build apk --release --dart-define=API_URL=https://VOTRE-SERVEUR/api --dart-define=SUPPORT_WHATSAPP=… --dart-define=SUPPORT_PHONE=… --dart-define=SUPPORT_EMAIL=…
```

Prérequis : le SDK Android (variable `ANDROID_HOME`), Java 17. L'APK se signe pour l'instant avec la **clé de débogage** : avant toute publication il faut créer une vraie clé de signature, gardée hors du dépôt. En release, l'adresse du serveur doit être en `https`. Le SDK Jitsi alourdit l'APK (WebRTC pour toutes les architectures) : mesurer la taille et envisager `--split-per-abi`.

## Version web installable (PWA)

La même application tourne dans le navigateur et s'installe sur l'écran d'accueil (Android : menu de Chrome > « Installer l'application » ; iPhone : Safari > Partager > « Sur l'écran d'accueil »).

```
flutter build web --release --no-web-resources-cdn --dart-define=API_URL=https://VOTRE-SERVEUR/api
```

- `--no-web-resources-cdn` : le moteur de dessin (CanvasKit) est servi par notre site et non par gstatic.com ; sans cela, le service worker ne peut pas le garder pour le mode hors connexion.
- Fichiers : `web/` (page d'entrée, manifeste, icônes ; logo source `web/icons/icon.svg`), `web/netbuis_sw.js` (service worker de NetBuis : « réseau d'abord », copie gardée pour le hors connexion ; le service worker de Flutter, obsolète, n'est pas utilisé), `nginx.conf.template` (en-têtes de cache et de sécurité).
- Limites de la version web : l'appel à l'équipe et WhatsApp depuis l'application affichent « utilisez l'application Android » (Jitsi et le code natif n'existent pas dans un navigateur) ; partage et lecture des SMS indisponibles ; recherche vocale et lecture à voix haute selon le navigateur.
- Risque connu : dans le navigateur, `flutter_secure_storage` garde les jetons dans le stockage du navigateur (chiffrés avec une clé WebCrypto rangée au même endroit) : une faille XSS pourrait les lire. Ce n'est pas l'équivalent du Keystore Android. Mesures : l'adresse d'API doit être en https (refusée sinon, aussi sur le web), aucune page tierce ni script externe n'est chargé, `X-Frame-Options: DENY`.
- Image Docker pour Railway : `Dockerfile` (variable `API_URL`, lue à la construction). Essai navigateur : `node e2e/pwa.mjs --prod=build/web --fake=<dossier du build USE_FAKE_API>` (Playwright ; voir l'en-tête du fichier).

## Construire l'APK dans Docker (sans installer Flutter ni Android Studio)

Depuis la racine du dépôt (aucune clé dans l'image) :

```
docker build --target apk -f mobile/Dockerfile.apk \
  --build-arg API_URL=https://VOTRE-SERVEUR/api \
  --output type=local,dest=./sortie mobile
```

Résultat : `./sortie/app-release.apk` (signé avec la clé de **débogage**). Facultatif : `--build-arg SUPPORT_WHATSAPP=… --build-arg SUPPORT_PHONE=… --build-arg SUPPORT_EMAIL=…`. L'adresse d'API est obligatoire et doit être en `https://`. Une vraie clé de signature n'est pas encore gérée par `build.gradle.kts` (tâche T124) : quand elle le sera, elle devra passer par un secret de build (`docker build --secret`), jamais par un `COPY` ni un `ARG`.

## Lancer avec de fausses données (sans backend)

```
flutter run --dart-define=USE_FAKE_API=true
```

## Organisation

- `lib/core/` : réseau, stockage, routes, thème, widgets communs.
- `lib/features/<fonction>/` : `data/` (modèles + dépôts : interface, fake, api), `application/` (contrôleurs Riverpod),
  `presentation/` (écrans + widgets).
- La recherche contient deux sous-modules : `text_search/` (écrite) et `voice_search/` (vocale).
- `payments/` reste vide jusqu'à l'étape É6.
