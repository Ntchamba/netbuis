# T001 — vérification orchestrateur (2026-10-11)
| Critère | ✔/✘ | Preuve vue par l'orchestrateur |
|---|---|---|
| pip install, versions notées | ✔ | logs/T001-pip.txt ; requirements figés (Django 5.2.18, DRF 3.18.3) |
| makemigrations --check | ✔ | relancé : « No changes detected » ; accounts/0001 générée par Django |
| migrate, check | ✔ | logs/T001-migrate.txt ; check relancé : 0 issue |
| ruff, pytest | ✔ | relancés : « All checks passed! », pytest exit 0 (29 tests) |
| /api/health/ = 200 | ✔ | runserver 127.0.0.1:8766 relancé par l'orchestrateur : 200 |
| .env ni lu ni versionné | ✔ | git ls-files / git status : aucun .env |
| openapi.yaml généré | ✔ | logs/T001-spectacular.txt |
| verifier_tache.sh | ✔ | OK après renommage du mot de passe de test (test-secret-admin) |
Autorisation exceptionnelle : ligne 1 de apps/business/models/profile.py (docstring > 100 car.).
