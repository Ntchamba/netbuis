# NetBuis — Étape 1 (socle) : rapport (2026-10-11)

Agents : A (A1.1–A1.6, A1.13), B (B1.1–B1.8), C3 (C3.1–C3.3). Livré dans `netbuis-etape1.zip` (251 fichiers, à extraire par-dessus le dépôt).

**Rien n'a été exécuté** (pip, npm et Flutter indisponibles ici) : seuls `py_compile`, `ruff` et des tests purs Python (116 cas) ont tourné. À faire chez Jeff : `pip install -r requirements/dev.txt`, `manage.py check`, `makemigrations --check --dry-run`, `pytest` ; `npm install`, `npm run typecheck/test/build` ; `flutter create …`, `flutter pub get`, `flutter analyze`, `flutter test`.

## Décisions à valider
- User : clé primaire UUID (`UUIDTimeStampedModel`), numéros mobiles `6XXXXXXXX` seulement.
- `DATABASE_URL` sans valeur par défaut : à définir dans `backend/.env` (jamais dans le dépôt).
- Limite OTP : par IP dans les réglages ; par numéro (3 / 10 min) à coder en A1.7.
- Jeton de renouvellement : B envoie `{"refresh": …}` ; C3 suppose un cookie HttpOnly (`POST /api/auth/refresh/`, `withCredentials`). Point ouvert à trancher pour A1.10.
- Cache partagé (Redis) et `NUM_PROXIES` à régler avant la production.
- `docker-compose.yml` lit `POSTGRES_PASSWORD` depuis `.env` racine (plus de mot de passe en clair).
- `VITE_API_BASE_URL` = `http://localhost:8000` (sans `/api`) ; `API_URL` mobile reste `…/api`.

## Zones à relire ligne par ligne
`apps/core/exceptions.py`, `config/settings/prod.py`, `mobile/lib/core/network/interceptors/refresh_interceptor.dart`, `dashboard/src/api/client.ts`.

## Suite
Étape 2 (accès) : OTP, SMS (fournisseur à choisir, voir comparatif), jetons, écrans de connexion.
