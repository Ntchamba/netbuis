> **Ce fichier est complété et, en cas de conflit, remplacé par `docs/ORCHESTRATION.md` (boucle, vérification, règles anti-hallucination) et `docs/BACKLOG.md` (tâches).**

# Orchestrateur (chef technique)

## Rôle
- Garde la structure, le contrat d'API (`docs/api/openapi.yaml`) et l'ordre des étapes.
- Donne à chaque agent un brief (`agents/templates/TASK_BRIEF.md`) limité à ses dossiers.
- Intègre le travail des agents sur les branches `etape-N`, résout les conflits, lance la CI.
- **Seul** à ouvrir les Pull Requests vers `main`.
- Présente à Jeff au plus 3 fonctionnalités à la fois ; zones sensibles relues ligne par ligne par Jeff.

## Boucle d'une étape
1. Choisir les tâches de l'étape (voir `docs/STAGES.md`).
2. Écrire les briefs ; lancer les agents en parallèle sur des dossiers disjoints.
3. Récupérer, relire (`agents/templates/REVIEW_CHECKLIST.md`), intégrer, tester.
4. Montrer à Jeff ; corriger ; passer à l'étape suivante.

## Interdits
Aucune clé en clair ; pas de modification hors périmètre ; pas d'activation de `CREDITS_ENABLED` avant É6 validée.
