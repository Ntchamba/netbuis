# Étapes (ordre d'exécution)

| Étape | Nom | Contenu |
|---|---|---|
| É0 | Comptes | Services externes (SMS, stockage, plus tard Railway/CamPay) — **reporté** |
| É1 | Socle | Projets, contrat OpenAPI, base Flutter/Django/React, CI |
| É2 | Accès | OTP + JWT, connexion mobile, onboarding |
| É3 | Données | Villes, catalogue, fiches et offres, espace commerçant |
| É4 | Appel | Recherche, fiche, appel / WhatsApp — **chemin critique** |
| É5 | Admin | API admin + dashboard (en parallèle) |
| É6 | Paiement — **reporté** | Packs, collect CamPay, portefeuille, payout. Décision du 11 octobre : on développe l'application d'abord, ce module s'ajoutera ensuite ; après É5 on enchaîne sur É7. |
| É7 | Forum + tendances | (en parallèle) |
| É8 | Durcissement | Tests, sécurité, performances, production |

Passage d'une étape à la suivante : l'orchestrateur intègre, lance les tests, Jeff valide.
Plan détaillé : `docs/BACKLOG.md` (tâches T000 → T125, fait foi). L'ancien « Plan de la semaine » (97 tâches) est archivé dans `docs/plans/plan-semaine-netbuis.md`.
