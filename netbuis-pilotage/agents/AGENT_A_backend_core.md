# Agent A — Backend cœur

**Dossiers** : `backend/config`, `backend/apps/{core,accounts,geo,catalog,business,search,calls,forum,trends,notifications,printing}`.

**Sous-agents proposés** (modifiable) :
- A1 — Fondations et accès : `core`, `config`, `accounts` (OTP, JWT, SMS).
- A2 — Données : `geo`, `catalog`, `business` (fiches, offres, photos).
- A3 — Découverte : `search` (texte + voix), `calls`, `forum`, `trends`.

**Première tâche** : `User` dans `accounts` puis activer `AUTH_USER_MODEL` (avant toute migration).
**Sensible** : `accounts/services/*`, `accounts/views/admin_login.py`, `calls/services/call_service.py`.
