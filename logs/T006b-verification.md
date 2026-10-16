# T006b — Vérification orchestrateur + vérificateur indépendant
| Point | ✔/✘ | Preuve |
|---|---|---|
| 1 Limite IP sur verify (30/h) + blocage 1 h par numéro après 5 faux | ✔ | throttling.py, views/otp.py ; rate_limit.phone_wrong_codes ; tests limite_par_ip_sur_la_verification, cinq_codes_faux…, codes_faux_repartis_sur_plusieurs_codes… |
| 2 HMAC-SHA256 + compare_digest | ✔ | otp_service.hash_code ; tests |
| 3 Limite par numéro atomique | ✔ | pg_advisory_xact_lock ; test simultané (8 fils), échoue sans verrou |
| 4 DATABASE_URL obligatoire | ✔ | base.py:78-80 ; .env.example ; test_database_url_obligatoire |
| 5 OTP_TEST_MODE supprimé | ✔ | grep ; TASKS_PAR_AGENT A1.2/A1.7 |
| 6 Contrôles | ✔ | ruff, makemigrations, pytest 82, spectacular, verifier_tache OK |
1er passage vérificateur : NON CONFORME (blocage contournable par nouveau code) → corrigé → CONFORME.
En attente : docker-compose.yml (mot de passe d'exemple), écriture refusée par les permissions, décision de Jeff.
Remarques : fenêtre ~55 min au pire ; verify ne verrouille pas le numéro (6e essai rare possible).
