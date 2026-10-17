# NetBuis — Super-App Métier

Trouver un produit auprès des commerçants locaux (Cameroun), voir la liste, appeler directement
(téléphone / WhatsApp), payer par Mobile Money (CamPay, reporté), forum, tendances, dashboard d'administration.

## Pour un agent (Claude Code, en local ou dans le cloud) : par où commencer

1. `CLAUDE.md` — qui tu es (l'orchestrateur), ce que tu fais, les règles absolues, le mode cloud.
2. `docs/ORCHESTRATION.md` — la méthode : une tâche à la fois, brief à un sous-agent, vérification critère par critère.
3. `docs/PROGRESS.md` — l'état réel (fait foi). `docs/BACKLOG.md` — les tâches T000 → T125 et leurs critères « Terminé quand ».
4. `AGENTS.md` — qui possède quel dossier, et l'ordre de priorité des documents.
5. `.claude/agents/` — les neuf sous-agents et le vérificateur (lus automatiquement par Claude Code).

## La méthode des neuf agents

| Agent | Rôle | Périmètre |
|---|---|---|
| orchestrateur | la session principale : choisit la tâche, briefe, vérifie, met à jour `PROGRESS.md`, commite | `docs/`, `agents/`, racine, `scripts/` |
| `a1-fondations-acces` | réglages Django, compte, OTP, jetons, connexion admin | `backend/config`, `apps/{core,accounts}` |
| `a2-donnees` | lieux, catalogues, compte business, offres, photos | `apps/{geo,catalog,business}` |
| `a3-decouverte` | recherche, appel, forum, tendances | `apps/{search,calls,forum,trends,…}` |
| `b1-socle-acces-mobile` | socle Flutter, thème, connexion | `mobile/` (socle, accès) |
| `b2-decouverte-mobile` | accueil, recherche, fiche, appel, carte | `mobile/` (découverte) |
| `b3-commercant-communaute` | création du commerce, espace commerçant, forum | `mobile/` (commerçant) |
| `c1-paiements-reporte` | paiements CamPay — **reporté, jamais appelé** | `apps/payments` |
| `c2-api-admin` | API d'administration | `apps/admin_panel` |
| `c3-dashboard-react` | dashboard web | `dashboard/` |
| `verificateur` | relecture indépendante en lecture seule (obligatoire pour les tâches 🔒) | aucun |

Le périmètre exact de chaque agent est en tête de son fichier dans `.claude/agents/`. Les fiches `agents/AGENT_*.md`
décrivent le découpage d'origine en 3 grands agents (A backend, B mobile, C paiements/admin) dont les neuf sont issus.

## Où est quoi

| Dossier | Contenu | Techno |
|---|---|---|
| `backend/` | API, base de données, règles métier | Django 5.2 LTS + DRF + PostgreSQL |
| `mobile/` | Application Android | Flutter |
| `dashboard/` | Administration web | React (Vite + TypeScript + Tailwind) |
| `docs/` | Méthode, backlog, état, décisions, spécifications, maquettes, contrat d'API | Markdown / OpenAPI / HTML |
| `docs/verifications/` | Tableaux de vérification des tâches validées (copies versionnées de `logs/Txxx-verification.md`) | Markdown |
| `docs/plans/` | Historique du Projet Claude : études, audits, veille (référence, ne fait pas foi) | Markdown |
| `.claude/` | Sous-agents et réglages de sécurité de Claude Code | Markdown / JSON |
| `agents/` | Fiches d'origine de l'orchestrateur et des agents A/B/C, modèles de brief et de revue | Markdown |
| `deploy/` | Réservé (déploiement reporté) | — |

**Règle d'or** : un dossier = un propriétaire (voir `AGENTS.md`). Lire `docs/MODULES.md` pour savoir où écrire quoi.

## Démarrage local

```
docker compose up -d db        # ou une base PostgreSQL locale : createdb netbuis
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements/dev.txt
cp .env.example .env           # puis renseigner DATABASE_URL (jamais versionné)
python manage.py migrate && pytest -q
```

Dashboard : `cd dashboard && npm install && npm test`. Mobile : `cd mobile && flutter pub get && flutter test`.
Guide pas à pas pour lancer l'orchestrateur : `LANCER_AVEC_CLAUDE_CODE.md`.

## État

Voir `docs/PROGRESS.md` (au 2026-10-11 : T000 à T006 validées, T006b en attente de la relecture de Jeff, prochaine tâche T007).
Paiements et déploiement : reportés. Points relevés lors de la mise sur GitHub : `docs/AUDIT-2026-10-17.md`.
