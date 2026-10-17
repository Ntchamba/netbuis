# Rapport: méthodes de gestion de projet de A à Z pour NetBuis (2026-10-05)

But: présenter les options pour que Jeff choisisse. [S] = source, [A] = avis.

## 1. Méthodes comparées
| Méthode | Taille d'équipe | Force | Faiblesse | Pour NetBuis |
|---|---|---|---|---|
| Kanban | moins de 4 [S] | Léger, absorbe le travail variable | Devient une liste de tâches sans limites de travaux en cours [S] | Bon défaut si équipe < 4 |
| Scrum | 4 et plus [S] | Cadence, démos, prévisions | Réunions trop lourdes sous 4 personnes [S] | Trop lourd au début |
| Lean | toutes | Valider à moindre coût, mesurer le comportement plutôt que les chiffres de vanité [S] | Dit quoi construire, pas quand | À superposer à une autre méthode (surtout avant d'avoir un marché) |
| Shape Up | seniors autonomes [v4] | Cycles de 6 semaines, périmètre limité, pas de backlog infini | Exige des pitchs bien écrits | Intéressant si écrit pour agents IA (un pitch = une spécification) [A] |
| Scrumban (hybride) | petites équipes | Flux continu + rituels courts | Risque de piocher des morceaux incohérents [S, Sagan Orbit] | Option raisonnable avec règle écrite |
| Cascade / CPM / PRINCE2 | grosses équipes ou contrat fixe [S] | Phases et validations | Découverte tardive des problèmes; trop de documents | À éviter, sauf exigence d'un financeur |

Règle commune [S]: choisir une méthode et la garder au moins 3 mois avant de réévaluer. Défaut pour la plupart des startups: Kanban ou Scrum + pensée Lean [S, t0ggles].

## 2. Cycle de vie de A à Z (proposition) [A]
0. Test de demande hors-ligne: inscrire à la main 30 à 50 commerçants d'un quartier, mesurer les recherches qui aboutissent à un appel utile; décision go/no-go chiffrée (v5).
1. Cadrage: périmètre MVP, indicateur n°1 (taux de recherche aboutie), budget, juriste local.
2. Conception: contrat d'API, modèle de données, maquettes testées avec de vrais commerçants.
3. Construction par tranches verticales (recherche → fiche → appel), chaque tranche testable.
4. Test et sécurité: grille OWASP, performance sur téléphone 2 Go, conformité loi 2024/017.
5. Pilote terrain dans un quartier ou une ville, mesure hebdomadaire.
6. Exploitation: support, rafraîchissement des fiches, révision des prix, décision v2 (forum, packs).

## 3. Trois combinaisons proposées [A]
- Combinaison 1, Kanban strict + Lean: 1 à 3 humains, limite de 1 à 2 cartes par personne et par colonne [S]. La plus simple.
- Combinaison 2, Shape Up adapté: cycles de 6 semaines, un pitch écrit par cycle qui sert de spécification aux agents. Bon si Jeff veut piloter par résultats.
- Combinaison 3, Scrum léger: seulement si l'équipe humaine atteint 4+; sprints de 1 à 2 semaines, planification et rétrospective regroupées [S].
Mon penchant: 1 pour démarrer, 2 si le périmètre se stabilise; mais c'est votre choix.

## 4. Pilotage commun à toutes les méthodes [A]
- Indicateurs hebdomadaires: recherches, taux d'aboutissement, fiches rafraîchies, appels, coût de jetons, tests rouges.
- Registre des risques court (10 lignes) revu chaque semaine.
- Journal de décisions (une ligne par décision, date, raison) lisible aussi par les agents.
- Critères d'arrêt écrits à l'avance (go/no-go du jalon 0).

## 5. Décisions pour Jeff
1. Combinaison 1, 2 ou 3?
2. Combien d'humains, et qui relit le code?
3. Date et seuil chiffré du go/no-go du jalon 0?
4. Engagement de 3 mois sur la méthode choisie?

## Sources
- [7 méthodologies pour startups (t0ggles, 2026)](https://t0ggles.com/blog/top-7-project-management-methodologies-for-startups)
- [Kanban vs Scrum petites équipes (Sagan Orbit)](https://saganorbit.com/blog/kanban-vs-scrum-for-small-teams)
- [Shape Up vs Scrum (ideaplan)](https://www.ideaplan.io/compare/shape-up-vs-scrum)
