# Rapport: orchestration d'agents IA pour développer NetBuis (2026-10-05)

But: aider Jeff à choisir. Rien n'est imposé. [S] = source, [A] = avis.

## 1. Réponse courte à « 64 agents? 10 testeurs? »
Non. Les sources convergent: 3 à 5 agents sous un orchestrateur, un relecteur pour 3 à 4 constructeurs [S, Addy Osmani]. Le goulot n'est plus la génération mais la vérification: « les agents dépassent la capacité humaine à valider » [S]. Plus d'agents = plus de code à relire par vous.

## 2. Chiffres clés
- Multi-agent: 4 à 220 fois plus de jetons d'entrée qu'un agent seul (étude UIUC); environ 15 fois plus qu'un chat chez Anthropic (production) [S, Augment].
- Tâches séquentielles: dégradation de 39 à 70 % en multi-agent (Google Research, cité par Augment) [S]. Gain réel seulement sur le travail vraiment parallèle (recherche large: +90,2 %) [S].
- Échecs en production 41 à 86,7 %; 41,8 % dus à une spécification floue, 36,9 % à la coordination, 21,3 % au manque de vérification (v6) [S].
- Budget de référence: sous-agents ≈ 220 000 jetons au total, pause automatique à 85 % du budget par agent, 8 itérations maximum, réassignation après 3 blocages sur la même erreur [S, Osmani].
- Un fichier AGENTS.md écrit par l'humain aide; généré par IA, il baisse la réussite d'environ 3 % [S, Osmani].

## 3. Les cinq schémas (digitalapplied 2026) [S]
Fan-out (parallèle indépendant), Pipeline (étapes successives, risque de contamination), Débat (≈ 2,5 fois le coût, pour décisions à enjeu), Superviseur (3 à 10 sous-agents, un seul niveau, défaut 2026), Essaim (50+ tâches indépendantes, croissance non maîtrisée). Pour NetBuis [A]: Superviseur pour la construction, Fan-out ponctuel pour la revue (sécurité, performance, conformité en parallèle), Débat seulement pour 2 ou 3 décisions d'architecture.

## 4. Trois dispositifs à comparer
| Option | Composition | Coût relatif | Quand |
|---|---|---|---|
| A. Solo renforcé | 1 agent de code + tests automatiques (CI) + vous en relecteur | Faible | Phase 0 et début. Meilleur rapport tant que le contrat d'API n'existe pas |
| B. Équipe resserrée (mon avis: la plus adaptée) | 1 superviseur, backend, mobile, tests/CI, 1 relecteur lecture seule; sécurité et conformité = grilles du relecteur (OWASP, loi 2024/017); un worktree git par agent | Moyen (≈ x3 à x4 jetons, à mesurer) | Construction du MVP |
| C. Grande flotte / essaim (64 agents) | 50+ agents | Très élevé | Non justifié: l'appli ne contient pas 50 tâches indépendantes |
Répartition des tests [A]: un agent testeur + la CI comme juge. Dix agents testeurs produisent surtout des faux positifs et des tests redondants.

## 5. Règles qui comptent plus que le nombre d'agents
1. Spécification écrite d'abord (six zones: commandes, tests, structure, style, flux git, limites; trois niveaux « toujours / demander / jamais ») [S, Osmani sur les specs].
2. Un propriétaire par fichier ou ressource; contexte limité à son périmètre [S].
3. Contrat d'API (OpenAPI) + schéma de base mis à jour à chaque tâche [v6].
4. Relecteur indépendant, accès en lecture seule, sans voir le raisonnement du code [S].
5. Plafonds: 8 itérations, budget de jetons, arrêt et alerte [S].
6. L'humain décide: architecture, priorités, argent (paiement), données personnelles, sécurité [S].
7. Journal de décisions et fichier de leçons après chaque tâche (REFLECTION.md, décisions versionnées) [S].
8. Mesurer dès la semaine 1: jetons par tâche acceptée, retours de revue, tests rouges après fusion; ajouter un agent seulement si « tâches terminées par jour de revue humaine » augmente [A].

## 6. Séquence conseillée [A]
Phase 0 (cadrage, contrat d'API, modèle de données): option A. Phases de construction: option B. Avant chaque version: fan-out de revues (sécurité, performance sur téléphone 2 Go, conformité). Si la revue humaine sature: rester à 3 agents.

## 7. Décisions pour Jeff
1. Option A puis B, ou B directement?
2. Plafond mensuel de jetons (budget en euros)?
3. Qui relit (vous, un développeur humain)? C'est lui qui fixe la vitesse.
4. Modèle le plus puissant réservé au relecteur et à l'architecture?

## Sources
- [The Code Agent Orchestra (Addy Osmani)](https://addyosmani.com/blog/code-agent-orchestra/)
- [Single-Agent vs Multi-Agent AI (Augment Code)](https://www.augmentcode.com/guides/single-agent-vs-multi-agent-ai)
- [Multi-Agent Orchestration: 5 Patterns (digitalapplied)](https://www.digitalapplied.com/blog/multi-agent-orchestration-5-patterns-that-work)
- [How to write a good spec for AI agents (Addy Osmani)](https://addyosmani.com/blog/good-spec/)
- [Why Multi-Agent Systems Fail (Augment Code)](https://www.augmentcode.com/guides/why-multi-agent-llm-systems-fail-and-how-to-fix-them)
