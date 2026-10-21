# À relire par Jeff (zones 🔒 passées sans arrêt, sur sa décision du 2026-10-21)
Chaque tâche ci-dessous a été validée par l'agent vérificateur mais pas relue par Jeff. Relecture à faire avant toute mise en service.

## T050 — lancer un appel (le numéro du commerçant)
Fichiers : backend/apps/calls/services/call_service.py (seul endroit qui lit phone_anchor, ordre des contrôles), views/initiate.py (no-store, erreurs d'authentification), services/rate_limit.py, serializers/initiate.py, tests/test_initiate.py (non-fuite dans les logs), models/call_log.py.
Décision à valider : FREE_CALLS_PER_DAY = 3 (valeur d'essai, active seulement si CREDITS_ENABLED=True) ; quota dépassé = 429 RATE_LIMITED ; commerce inexistant = BUSINESS_NOT_ACTIVE.

## T051 — WhatsApp, retour d'appel, historique
Fichiers : backend/apps/calls/services/{whatsapp_service,feedback_service,call_service}.py, views/{feedback,whatsapp_report}.py, tests/e2e/test_flow_search_call.py.
Décisions à valider : message WhatsApp pré-rempli « Bonjour, je vous contacte depuis NetBuis au sujet de « {nom} ». » (prefilled_message) ; seuil de 3 signalements en constante ; le signalement « pas de WhatsApp » exige d'avoir reçu un lien ; « mauvais numéro » n'a pas encore d'effet de masquage (champ needs_fix absent).
