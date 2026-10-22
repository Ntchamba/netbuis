# T123 — dashboard : parcours de bout en bout

## Ce qui est automatisé

Vitest (`dashboard/tests/parcours/`, API simulée à état `world.ts`, application entière montée) : 35 tests, 7 fichiers.

| Fichier | Domaine | Tests |
|---|---|---|
| acces.test.tsx | connexion, jeton en mémoire, rafraîchissement, déconnexion, droits | 9 |
| demandes.test.tsx | liste, pièce privée, valider, rejeter avec motif, 409 | 4 |
| comptes.test.tsx | recherche, détail audité, blocage, débloquer, supprimer, restaurer | 4 |
| moderation.test.tsx | masquer, restaurer, supprimer avec motif, 404 | 4 |
| appels_equipe.test.tsx | Disponible, sonnerie, fiche, raccrocher, 2 sonneries, prise par un collègue, reconnexion | 7 |
| referentiels_reglages.test.tsx | création, modification, doublon refusé, bornes des réglages | 3 |
| audit_export.test.tsx | décisions retrouvées dans le journal, filtre, export audité | 4 |

Playwright / Chromium (`npm run test:e2e`) : `e2e/appel-entrant.mjs` (inchangé) et `e2e/parcours-admin.mjs` (nouveau, 14 contrôles dont « aucune erreur de console »).

## Couverture

Non mesurée : le paquet `@vitest/coverage-v8` n'est pas installé (`MISSING DEPENDENCY`), et il n'a pas été ajouté.

## Commandes (sorties dans `logs/T123-dashboard-*.txt`)

`npm run typecheck` OK · `npm test` : 25 fichiers, 347 tests OK · `npm run build` OK · `npm run test:e2e` OK.
