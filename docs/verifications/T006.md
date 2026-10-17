# T006 — Vérification orchestrateur + vérificateur indépendant
| Critère | ✔/✘ | Preuve |
|---|---|---|
| 1 Numéros 6XXXXXXXX, 400 FR | ✔ | phone.py:19-33 ; tests numero_* |
| 2 6 chiffres, haché, 5 min, unique, 5 essais | ✔ | otp_service.py:21-22,82,87,97-113 ; tests |
| 3 3/10 min par numéro, 10/h par IP, 429 + Retry-After | ✔ | rate_limit.py, throttling.py, NUM_PROXIES=0 ; tests limite_* |
| 4 Interface SMS, console si DEBUG, réel avec clé | ✔ | sms/* ; tests console/fournisseur |
| 5 Pas de code ni numéro dans les logs | ✔ | log_filters.py ; tests |
| 6 8 cas de test | ✔ | test_otp.py, 75 passed |
| 7 openapi | ✔ | spectacular --validate OK, identique |
1er passage verifier_tache : 2 écarts (NotImplementedError, print) → corrigés ; 2e passage OK.
Vérificateur : CONFORME. À reprendre avant mise en service : cache partagé (limite IP par processus), limite IP sur verify, verrou sur limite par numéro. Remarques : OTP_TEST_MODE mort, verify sans objet user (T007/T008).
