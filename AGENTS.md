# Règles pour tous les agents (lire avant d'écrire une ligne)

1. **Un dossier = un propriétaire.** Ne modifie jamais un dossier qui n'est pas le tien (voir tableau ci-dessous).
   Besoin d'un changement ailleurs ? Écris-le dans ta Pull Request pour l'orchestrateur.
2. **Contrat d'abord.** `docs/api/openapi.yaml` est la source de vérité. Le mobile code contre des dépôts « fake »
   (`--dart-define=USE_FAKE_API=true`) tant que le backend n'est pas prêt.
3. **Structure figée.** Les dossiers et fichiers existent déjà. Tu remplis les fichiers ; tu n'en inventes pas
   d'autres sans l'accord de l'orchestrateur (et mise à jour de `docs/MODULES.md`).
4. **Branches.** Chaque agent travaille sur `etape-N/<agent>-<sujet>`. Seul l'orchestrateur ouvre une PR vers `main`.
5. **Secrets.** Jamais de clé, mot de passe, jeton dans le code, les tests, les logs ou une conversation.
   Tout passe par les variables d'environnement (`.env.example` liste les noms, sans valeurs).
6. **Zones sensibles** (revue ligne par ligne par Jeff) : OTP/JWT/admin-login, appel (`calls/services/call_service.py`),
   tout le dossier `payments/`, permissions admin.
7. **Le numéro de téléphone d'un commerçant** n'est renvoyé que par `POST /api/calls/whatsapp/` (dans `wa_url`) et par la route de fiche de T132b à l'agent qui a décroché pendant l'appel (D-30) ; les appels passent par Jitsi vers l'équipe (D-25). Jamais dans la recherche
   ni dans la fiche publique.
8. **Le code PIN Mobile Money** n'est jamais saisi dans l'app ni transmis au serveur.
9. **Paiements** : `CREDITS_ENABLED=False` tant que l'étape É6 n'est pas validée. Le webhook n'est jamais cru seul :
   on revérifie le statut auprès du fournisseur.
10. **Tests.** Chaque fonctionnalité arrive avec ses tests (`apps/<app>/tests/`, `mobile/test/`, `dashboard/tests/`).

## Propriétaires

| Zone | Propriétaire |
|---|---|
| `backend/apps/{core,accounts,geo,catalog,business,search,calls,forum,trends,notifications,printing}`, `backend/config` | Agent A |
| `mobile/` | Agent B |
| `backend/apps/{payments,admin_panel}`, `dashboard/` | Agent C |
| `docs/`, `agents/`, `.github/`, racine, `deploy/` | Orchestrateur |

Détails : `agents/ORCHESTRATOR.md`, `agents/AGENT_A_backend_core.md`, `agents/AGENT_B_mobile.md`,
`agents/AGENT_C_payments_admin.md`.

## Priorité des documents (en cas de contradiction)

1. `docs/DECISIONS_JEFF.md` · 2. `docs/ORCHESTRATION.md` · 3. `docs/spec/` · 4. `docs/design/maquettes/` (pour tout ce qui est visuel) · 5. `docs/BACKLOG.md` · 6. `docs/TASKS_PAR_AGENT.md`, `docs/STAGES.md` · 7. `docs/plans/` (historique).
Les tâches s'exécutent dans l'ordre de `docs/BACKLOG.md`, une à la fois ; l'état est dans `docs/PROGRESS.md`.
Branches : une par phase, `etape-<N>/<nom>`, un commit par tâche validée (l'orchestrateur commite ; les sous-agents ne commitent pas).

