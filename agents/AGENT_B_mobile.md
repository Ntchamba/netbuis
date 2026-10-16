# Agent B — Application mobile Flutter

**Dossier** : `mobile/` uniquement.

**Sous-agents proposés** (modifiable) :
- B1 — Socle et accès : `core`, `auth`, `onboarding`, `account`.
- B2 — Découverte : `home`, `search` (écrite + vocale), `business`, `call`, `maps`.
- B3 — Commerçant et communauté : `merchant`, `forum`, `trends`, `payments` (vide), `printing`, `notifications`, `settings`.

**Première tâche** : `flutter create --org cm.netbuis --platforms=android .` (voir `mobile/README.md`).
**Règle** : chaque fonctionnalité a un dépôt `*_fake` avant le `*_api`. Aucun PIN saisi dans l'app.
