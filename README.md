# NetBuis — Super-App Métier

Trouver un produit ou un commerce auprès des commerçants locaux (Cameroun), voir la liste, **appeler l'équipe NetBuis par Jitsi depuis l'application** (l'équipe répond depuis le tableau de bord), ouvrir WhatsApp, forum, tendances, compte business, tableau de bord d'administration. Les paiements (packs de crédits CamPay) sont prévus mais reportés.

## Où est quoi

| Dossier | Contenu | Techno |
|---|---|---|
| `backend/` | API, base de données, règles métier, appels temps réel | Django 5.2 LTS + DRF + PostgreSQL (ASGI : uvicorn) |
| `mobile/` | Application Android | Flutter 3.47 |
| `dashboard/` | Administration web et réception des appels | React (Vite + TypeScript + Tailwind) |
| `docs/` | Contrat d'API, spécifications, décisions, vérifications, déploiement | Markdown / OpenAPI |
| `scripts/` | Contrôle de fin de tâche, essai de bout en bout de l'appel | bash / Node |

**Règle d'or** : un dossier = un propriétaire (voir `AGENTS.md`). L'état réel du projet est dans `docs/PROGRESS.md`, les décisions de Jeff dans `docs/DECISIONS_JEFF.md`.

## Installer et lancer (développement)

Serveur (PostgreSQL requis, voir `backend/README.md`) :

```
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements/dev.txt
cp .env.example .env          # puis remplir backend/.env (jamais versionné)
python manage.py migrate
python manage.py runserver     # ou : uvicorn config.asgi:application (voir docs/deployment/APPELS_ASGI.md)
```

Tableau de bord : `cd dashboard && npm install && npm run dev` (variable `VITE_API_BASE_URL`, voir `dashboard/.env.example`).

Application mobile : `cd mobile && flutter pub get && flutter run --dart-define=USE_FAKE_API=true` (fausses données, sans serveur). Avec un serveur : `--dart-define=API_URL=https://VOTRE-SERVEUR/api (avec /api)` (en production l'adresse doit être en `https`).

## Vérifier

| Partie | Commandes |
|---|---|
| Serveur | `ruff check . && python manage.py makemigrations --check --dry-run && pytest -q` |
| Tableau de bord | `npm run typecheck && npm test && npm run build` (essais navigateur : `npm run test:e2e`) |
| Mobile | `flutter analyze && flutter test --dart-define=USE_FAKE_API=true` |
| Appel de bout en bout (serveur réel + navigateur) | `node scripts/e2e_appel/bout_en_bout.mjs` (voir `docs/verifications/T134.md`) |
| Contrôle de fin de tâche | `scripts/verifier_tache.sh` |

L'intégration continue (`.github/workflows/ci.yml`) lance les trois jeux de tests et l'essai de l'appel.

## Variables d'environnement (noms seulement — les valeurs ne vont jamais dans le dépôt)

Serveur : `DEBUG`, `SECRET_KEY`, `ALLOWED_HOSTS`, `DATABASE_URL`, `CORS_ALLOWED_ORIGINS`, `CSRF_TRUSTED_ORIGINS`, `SMS_PROVIDER`, `SMS_API_KEY`, `JITSI_DOMAIN`, `JITSI_APP_ID`, `JITSI_JWT_SECRET`, `CREDITS_ENABLED`, `PAYMENT_PROVIDER`, `CAMPAY_*` (paiements reportés). Liste commentée : `backend/.env.example`. Réglages exigés en production : `docs/deployment/DEPLOYMENT.md`.

## Documentation utile

- Appels Jitsi : `docs/spec/APPELS_JITSI.md`, `docs/deployment/JITSI.md`, `docs/deployment/APPELS_ASGI.md`
- Déploiement : `docs/deployment/DEPLOYMENT.md` (rien n'est déployé à ce jour)
- Recette manuelle sur téléphone : `docs/RECETTE.md` et `docs/TESTS_JEFF.md`
- À relire par Jeff : `docs/A_RELIRE_PAR_JEFF.md`

## État

Voir `docs/PROGRESS.md`. Reportés : paiements CamPay, déploiement, parrainage / équipe, commandes, notifications, impression, GPS, iOS.
