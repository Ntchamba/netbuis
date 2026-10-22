# CHANGELOG

Historique des changements du contrat

_Orchestrateur_

## 2026-10-22 — T131
- Retiré : `POST /api/calls/initiate/`.
- Ajouté : `POST /api/calls/sessions/`, `GET /api/calls/sessions/<id>/`, `.../events/` (SSE), `.../end/`, `.../cancel/`, `GET /api/calls/history/` (sessions + liens WhatsApp), `POST /api/calls/whatsapp/`.
- Ajouté (équipe, droit `peut_repondre_aux_appels`) : `GET /api/admin/calls/`, `GET /api/admin/calls/stream/` (SSE), `POST /api/admin/calls/presence/`, `.../sessions/<id>/accept|decline/`.
