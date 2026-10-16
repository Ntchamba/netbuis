# NetBuis — application mobile (Flutter, Android)

## Première tâche (B.1)

Les dossiers `lib/` et `assets/` existent déjà. Il manque les dossiers de plateforme (`android/`, etc.).
Depuis ce dossier :

```
flutter create --org cm.netbuis --platforms=android .
flutter pub get
```

Vérifier ensuite avec `git status` que `lib/main.dart`, `lib/app.dart` et `pubspec.yaml` n'ont pas été écrasés
(sinon les restaurer avec `git checkout`).

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
