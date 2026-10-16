# Sécurité — rappels

- Secrets uniquement en variables d'environnement ; `.env` ignoré par git.
- JWT court + refresh ; OTP hashé, limité par numéro et par IP.
- Numéro du commerçant uniquement via `POST /api/calls/initiate/` (journalisé, limité).
- Permissions vérifiées côté serveur (jamais seulement dans l'app).
- Paiements : idempotence, `select_for_update`, ledger append-only, webhook revérifié.
- Admin : connexion séparée, `AuditLog` sur chaque action sensible.
- Code PIN Mobile Money : jamais dans l'app.
