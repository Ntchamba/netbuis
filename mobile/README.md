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
