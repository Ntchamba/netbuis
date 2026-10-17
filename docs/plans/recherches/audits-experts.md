# Audits d'expert successifs (v2 à v199)

> Regroupement automatique (2026-10-17) de 197 fichiers de veille produits par les routines du Projet Claude, du plus ancien au plus récent. Historique seulement : en cas de contradiction, `docs/DECISIONS_JEFF.md` et `docs/BACKLOG.md` font foi.


---

<!-- source : audit-expert-v3-netbuis.md -->

# Audit expert v3 NetBuis (2026-10-05)

Doc complet: https://claude.ai/code/artifact/3d07be7c-bc3f-443e-bf80-048146574b91
Complète les audits v1 et v2 du projet.

- Critique par domaine (UI, UX, ergonomie, frontend, backend, sécurité, mémoire, prix) avec gravité; fonctions à garder/reporter/ajouter; tableau critique -> correctif -> mesure de réussite.
- Orchestration: superviseur + 3 à 5 agents actifs (Osmani), 5 schémas comparés (pipeline, fan-out, superviseur, débat, essaim). Options A solo renforcé, B équipe resserrée (recommandée), C grande flotte (non). Un seul testeur + CI. Garde-fous: propriété de fichiers, plan validé, 8 itérations max, budget jetons, humain sur argent/données/sécurité/architecture.
- Gestion de projet: Scrumban + Lean recommandé (<4 pers.), Shape Up si seniors, Scrum trop lourd. Cycle de vie A à Z en 7 étapes.
- Frais de retrait mobile money ~1 % dès 5 000 FCFA (Max It / MoMo App, nov. 2025).
- Seuils chiffrés (APK 30 Mo, démarrage 3 s, relance 14 jours) = cibles proposées, non normes.
- Décisions en attente: qui paie, pile mobile, ville pilote, v2, orchestration, méthode, budget, juriste.


---

<!-- source : audit-expert-v4-netbuis.md -->

# Audit expert v4 NetBuis — synthèse consolidée et nouveautés (2026-10-05)

Ce rapport consolide les audits v1 à v3 du projet (déjà dans les docs) et ajoute les éléments trouvés lors de cette nouvelle passe web. Rien n'est tranché: les choix restent à Jeff.

## 1. Critique expert (rappel consolidé + nouveautés)

| Domaine | Critique principale | Gravité | Correctif recommandé |
|---|---|---|---|
| Fonctionnalités | MVP trop large (forum, carte 7 niveaux, commandes, 5 types de compte) | Haute | Garder: recherche, appel + WhatsApp, inscription commerçant par photo/voix, validation admin, fraîcheur des fiches. Reporter le reste en v2 |
| Marché | Démarrage à vide: pas de commerçants = pas d'utilisateurs | Critique | Ville/quartier pilote, inscription faite par des agents terrain, objectif de densité avant toute pub |
| Prix | Appel natif + pack payant = double facturation perçue | Haute | Faire payer le commerçant (abonnement, mise en avant), garder l'appel gratuit côté client |
| Données | Fiches périmées (62 % des consommateurs fuient une info fausse, BrightLocal) | Haute | Relance tous les 14 jours (cible proposée), bouton « toujours disponible », signalement |
| Sécurité | OTP pumping, prise de compte par SIM, journal de crédits modifiable, CNI en clair | Haute | Limites de débit OTP, journal append-only, chiffrement des CNI, loi camerounaise 2024/017 sur les données |
| Backend | Webhooks de paiement non idempotents | Haute | File de webhooks (Redis/BD), clés d'idempotence, journal structuré, sandbox avant production (Krexora 2026) |
| UX/ergonomie | Utilisateurs peu lettrés, réseau faible | Haute | Voix, icônes, mode hors-ligne, APK léger (cible 30 Mo proposée, pas une norme) |
| Économie | Risque de suivre des « utilisateurs vanité » au lieu du CAC, LTV, churn | Moyenne | Tableau de bord d'unit economics dès le pilote |

Nouveautés de cette passe:
- Les startups africaines échouent surtout par: absence de validation marché, distribution faible, économie unitaire ignorée, croissance prématurée (Business Tech Africa, mai 2026). Conséquence pour NetBuis: pilote hors-ligne avant de coder les fonctions secondaires.
- Paiement: Orange et MTN offrent des API REST; un accord marchand formel avec l'opérateur est requis, le KYC du portefeuille reste à l'opérateur. Intégration Orange + MTN estimée à 3 à 5 jours sur un projet e-commerce simple (Krexora). Les barèmes de frais et plafonds ne sont pas détaillés dans cette source: à vérifier directement auprès des opérateurs.
- Frais de retrait mobile money ~1 % dès 5 000 FCFA (Max It / MoMo App, nov. 2025): à intégrer dans le calcul de ce que le commerçant accepte de payer.

Ce qui peut déplaire aux utilisateurs: résultats vides ou faux, appel qui échoue, pub envahissante, obligation de créer un compte pour chercher, forum non modéré. Ce qui manque: avis simples, horaires, localisation précise (quartier), signalement, version pour feature phone/USSD ou WhatsApp bot.

## 2. Orchestration d'agents IA: ce que disent les sources

Cinq schémas existent (digitalapplied 2026):
- Fan-out: 2 à 10 branches, bon pour tâches indépendantes; risque d'agrégation partielle silencieuse.
- Pipeline: 3 à 5 étapes; risque de contamination en cascade.
- Débat: 2 modèles + juge, coût ~2,5× (ou ~1,2× en variante critique); réservé aux décisions à enjeu.
- Superviseur: 3 à 7 sous-agents, un seul niveau de profondeur; c'est le défaut de production en 2026.
- Essaim: 50+ agents, pour tâches massivement parallèles; risque d'explosion non contrôlée.

Guide Augment Code: 2 à 4 agents en parallèle est la plage utile, un worktree git par agent, structure Coordinateur / Spécialistes / Vérificateur. Modes d'échec: conflits de fusion, implémentations dupliquées, contradictions sémantiques (le plus dur à voir), épuisement du contexte. Portes avant fusion: tests + lint, revue IA séparée, humain pour la sémantique.

Réponse à « 64 agents? 10 testeurs? »: non pour NetBuis. Un app de cette taille ne contient pas 50 tâches indépendantes; la coordination coûterait plus que le gain.

| Option | Description | Avis |
|---|---|---|
| A | Un agent renforcé + CI + vous comme relecteur | Le moins cher, bon pour démarrer |
| B (recommandée) | Superviseur + 3 à 5 agents actifs (backend, mobile, tests/CI, sécurité, relecteur lecture seule), un worktree chacun | Meilleur équilibre vitesse/contrôle |
| C | Grande flotte / essaim | Non justifié |

Garde-fous communs: propriété de fichiers par agent, plan validé avant code, 8 itérations max par tâche, budget de jetons plafonné, humain obligatoire sur argent, données personnelles, sécurité et architecture. Un seul testeur + la CI comme juge: 10 agents de test multiplient les faux positifs.

## 3. Méthodes de gestion de projet de A à Z

- Scrumban + Lean (recommandé si équipe humaine < 4): flux continu, limite de travaux en cours, pitchs écrits comme spécifications.
- Shape Up: cycles de 6 semaines, adapté à des seniors autonomes; pas de backlog infini.
- Scrum: sprints de 2 semaines, rôles formels; trop lourd à 1-3 personnes.
- Cycle de vie en 7 étapes: découverte/validation marché, cadrage, conception, construction par tranches, test et sécurité, pilote terrain, exploitation et mesure.

## 4. Décisions à prendre (Jeff)
1. Qui paie: commerçant, client ou les deux (taille du pack 50 FCFA).
2. Pile mobile (Flutter proposé).
3. Ville/quartier pilote.
4. Forum et commandes: en v2?
5. Option d'orchestration A, B ou C.
6. Méthode de gestion (Scrumban, Shape Up, Scrum).
7. Budget et équipe.
8. Juriste local (données personnelles, monnaie électronique).

## Sources
- [Multi-Agent Orchestration: 5 Patterns That Work in 2026](https://www.digitalapplied.com/blog/multi-agent-orchestration-5-patterns-that-work)
- [How to Run a Multi-Agent Coding Workspace (2026)](https://www.augmentcode.com/guides/how-to-run-a-multi-agent-coding-workspace)
- [The Code Agent Orchestra, Addy Osmani](https://addyosmani.com/blog/code-agent-orchestra/)
- [Paiement mobile au Cameroun: guide technique 2026, Krexora](https://krexora.com/blog/paiement-mobile-cameroun-guide-technique-2026/)
- [Max It et MoMo App: retraits à 1 % dès 5 000 FCFA](https://www.digitalbusiness.africa/paiement-mobile-au-cameroun-max-it-orange-et-momo-app-mtn-generalisent-les-retraits-a-1-des-5-000-f-cfa/)
- [Learning Fast from Startup Failures in Africa's Tough Markets](https://www.businesstechafrica.co.za/entrepreneurship/2026/05/18/learning-fast-from-startup-failures-in-africas-tough-markets/)


---

<!-- source : audit-expert-v5-netbuis.md -->

# Audit expert v5 NetBuis — compléments et points qui changent la donne (2026-10-05)

Complète les audits v1 à v4 (ne les répète pas). Rien n'est tranché: les choix restent à Jeff. Les chiffres cités viennent des sources en bas; ceux qui ne sont pas confirmés sont signalés « à vérifier ».

## 1. Trois faits nouveaux qui touchent directement le projet

**1. La loi camerounaise 2024/017 sur les données personnelles est applicable depuis le 23 juin 2026** (18 mois après la promulgation du 23 décembre 2024, selon Village de la Justice). Conséquences pour NetBuis:
- Consentement préalable et prouvable pour tout traitement à des fins de contact ou de marketing: prévoir un écran de consentement journalisé (date, version du texte).
- Tout transfert de données personnelles hors du Cameroun demande l'autorisation préalable de l'autorité (amende citée: 10 à 50 millions FCFA). Si la base ou les sauvegardes sont chez un hébergeur étranger (cloud européen ou américain), c'est un point juridique à traiter AVANT le pilote.
- Notification des failles à l'autorité et aux personnes concernées: prévoir un plan d'incident.
- Sanctions citées: 1 à 100 millions FCFA en administratif, jusqu'à 1 milliard pour les sociétés. À faire confirmer par un juriste local (la source est un article de juriste, pas le texte officiel).
- Les CNI des commerçants sont les données les plus sensibles du projet: minimiser, chiffrer, durée de conservation courte.

**2. Le choix « appel natif, sans Twilio » (décision du 30/09) est confirmé par les prix.** Twilio facture aujourd'hui environ 0,79 USD/min vers un mobile camerounais (et 0,41 USD/min vers un fixe), soit de l'ordre de 440 FCFA la minute (conversion approximative). Un appel passé via Twilio coûterait donc plus cher à la plateforme qu'un client ne paierait par le dialer natif. Garder le dialer natif; ne réintroduire le VoIP qu'avec un modèle économique prouvé.

**3. WhatsApp: les règles de facturation changent depuis le 1er octobre 2026** (engagelab). Les réponses de service ne sont gratuites que jusqu'à 1 000 messages par mois et par numéro, et les modèles « utilité » dans la fenêtre de 24 h deviennent payants. Le tarif exact pour le Cameroun n'est pas publié dans la source (à vérifier chez Meta ou Twilio). Conséquence: pour le MVP, utiliser le simple lien « wa.me » (le client ouvre WhatsApp lui-même, aucun coût API) et ne pas bâtir de bot WhatsApp payant avant d'avoir mesuré l'usage.

## 2. Critique supplémentaire de l'application

**Fonctionnalités: ce que personne n'a (encore) demandé.**
- Le bouton « Appeler » natif ne permet de mesurer que le clic, pas l'appel abouti. Sans cette donnée, impossible de prouver la valeur au commerçant (« vous avez reçu 40 appels »). Solution simple: après le clic, afficher 24 h plus tard une question « Avez-vous trouvé le produit ? » (oui / non / pas joint). C'est aussi votre mesure de fraîcheur des fiches.
- Aucun masquage de numéro: les commerçants peuvent être harcelés ou contournés. À accepter en connaissance de cause pour le MVP.
- Recherche: la qualité dépend des synonymes et des noms locaux (surnoms de produits, fautes d'orthographe, français/anglais/langues locales). Une recherche tolérante aux fautes est plus importante que n'importe quelle fonction sociale.

**Canal: l'application seule ne suffit peut-être pas.** Les sources sur l'Afrique (Arkesel, 2026) concluent que l'USSD gagne pour les téléphones basiques et l'absence de données, l'application pour les parcours riches et les notifications, et recommandent un hybride (USSD comme socle, application comme couche d'engagement). Les données restent chères (le forfait d'entrée de 2 Go coûte en moyenne 4,2 % du revenu national par habitant en Afrique, au-dessus de l'objectif de 2 % de l'ONU). Pour NetBuis: la recherche par USSD ou par WhatsApp (côté client, via lien) est une piste v2 à tester sur un petit échantillon, pas un chantier MVP.

**Prix.** Le coût marginal par utilisateur doit rester proche de zéro tant que l'appel est natif. Les vrais coûts sont l'hébergement (hors Cameroun = question juridique), les SMS d'OTP (vecteur de fraude, voir v4), le support et surtout le travail de terrain pour inscrire et rafraîchir les commerçants.

**Ce qui peut ne pas plaire.** Écran d'inscription obligatoire avant de chercher; résultats vides au premier lancement; commerçant qui ne décroche pas (aucune sanction possible sans suivi); publicité; consentement légal long et illisible (obligation nouvelle).

**Ce qu'on a oublié.** Plan d'incident de sécurité; registre des traitements et consentements; politique de conservation des CNI; plan de sauvegarde hébergé conformément à la loi; modération (même minimale) si le forum est gardé; support client en langue locale (un numéro WhatsApp suffit au départ).

## 3. Bonnes pratiques pour corriger (sources)

- **Démarrage à vide**: partir de l'offre, valider avant de coder, créer une valeur pour le commerçant indépendante du réseau (sa fiche visible, ses appels comptés) et opérer à la main au début (The Marketplace Guide). Mesurer la rétention par cohorte et l'activation des deux côtés (inscription puis premier appel utile), pas la croissance mensuelle, « insignifiante » à petite échelle.
- **Inclusion**: concevoir pour peu lettrés avec icônes, voix, parcours courts (recherche Microsoft Research sur interfaces pour utilisateurs novices); tester avec de vrais commerçants avant de figer les écrans.

## 4. Orchestration d'agents IA: précisions de cette passe

Convergence avec v4: pas d'essaim. Guide Claude Code 2026 (Developers Digest): « la plupart des tâches n'ont pas besoin de cinq agents ». Structure type: 1 coordinateur, 1 à 2 agents d'implémentation (back / front), 1 agent de test, 1 agent de revue. N'ajouter un spécialiste que si la séparation de contexte apporte un bénéfice clair. Le parallélisme aide quand les droits d'outils diffèrent, quand les contextes se gêneraient, ou quand le travail se découpe naturellement par responsabilité; il nuit quand les tâches sont fortement couplées ou que le diff final devient impossible à relire. Pièges: personas vagues (« ingénieur senior ») au lieu de rôles précis (relecteur de code, exécuteur de tests), droits d'outils trop larges, sorties non relisibles. Ces sources ne donnent pas de multiplicateur de coût fiable: fixer un plafond de jetons et mesurer dès la première semaine.

Recommandation inchangée à soumettre au choix: option B (superviseur + 3 à 5 agents actifs, un worktree chacun, CI comme juge, humain sur argent, données personnelles, sécurité et architecture). Ajout lié à la loi 2024/017: un « agent » ou une règle de revue dédiée à la conformité des données (consentement, minimisation, hébergement) à chaque fonction touchant des données personnelles.

## 5. Gestion de projet: ajout

Même court-circuit que v4 (Scrumban + Lean si équipe humaine < 4; Shape Up pour seniors autonomes; Scrum trop lourd). Ajout: placer en jalon 0, avant tout code, un « test de demande hors-ligne » (inscrire à la main 30 à 50 commerçants d'un quartier, mesurer combien de recherches réelles aboutissent à un appel utile), avec une décision go/no-go chiffrée.

## 6. Décisions nouvelles pour Jeff
1. Où héberger les données (Cameroun, ou transfert déclaré à l'autorité)? Juriste local requis.
2. Mesure post-appel (« avez-vous trouvé? ») acceptée pour le MVP?
3. Canal USSD / WhatsApp pour client: v2 ou jamais?
4. Rôle de revue conformité données dans le dispositif d'agents?

## Sources
- [Twilio, tarifs voix Cameroun](https://www.twilio.com/en-us/voice/pricing/cm)
- [WhatsApp Business API 2026, changements du 1er octobre (EngageLab)](https://www.engagelab.com/blog/whatsapp-business-api-pricing)
- [Loi camerounaise sur les données personnelles en 10 questions (Village de la Justice)](https://www.village-justice.com/articles/cameroun-comprendre-questions-nouvelle-loi-sur-protection-des-donnees-caractere,52122.html)
- [USSD vs application en Afrique (Arkesel)](https://arkesel.com/ussd-vs-mobile-app-africa/)
- [The Marketplace Guide: cold start](https://themarketplaceguide.com/patterns/cold-start/)
- [Claude Code agent teams et subagents 2026 (Developers Digest)](https://www.developersdigest.tech/blog/claude-code-agent-teams-subagents-2026)
- [Interfaces mobiles pour utilisateurs novices et peu lettrés (Microsoft Research)](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/ToCHI2711_Medhi.pdf)


---

<!-- source : audit-expert-v6-netbuis.md -->

# Audit expert v6 NetBuis: orchestration chiffrée, paiement, pile mobile, méthode (2026-10-05)

Complète v1 à v5 (ne les répète pas). Rien n'est tranché: les choix restent à Jeff. Chiffres tirés des sources en bas; ce qui n'est pas confirmé est marqué « à vérifier ».

## 1. Nouveautés qui changent des décisions

**Orchestration: les chiffres confirment « pas d'essaim ».** Selon Augment Code (2026), les systèmes multi-agents en production échouent entre 41 % et 86,7 % du temps. Taxonomie MAST: 41,8 % des échecs viennent d'une spécification floue (rôles, tâches, contraintes manquantes), 36,9 % d'une coordination défaillante, 21,3 % d'un manque de vérification. Donc 79 % des échecs sont des problèmes d'écriture de consigne et de coordination, pas de puissance. Conséquence: investir dans des spécifications écrites (JSON ou fichiers de contrat d'API), pas dans plus d'agents. Ajouter plus d'agents multiplie les points de coordination, la cause n°2.

Correctifs utiles pour NetBuis:
- Un propriétaire unique par ressource (un agent par table de base, par endpoint, par écran): évite les conflits.
- Spécification vivante: un fichier de contrat (OpenAPI + schéma BD) mis à jour à chaque tâche terminée, lu par tous les agents.
- Un agent juge indépendant, avec un prompt isolé, qui ne voit pas le raisonnement de l'agent qui a codé (PwC cite un passage de 10 % à 70 % de justesse avec des boucles de validation structurées, cas d'entreprise, à prendre avec prudence).
- Coupe-circuit: plafond d'itérations et de jetons par tâche, arrêt automatique et alerte.

Réponse à « 64 agents? 10 testeurs? »: non. Dispositif conseillé en phases (adaptable): phase 0 (cadrage, contrat d'API, modèle de données): 1 agent + vous. Phases de construction: 1 superviseur + 3 agents (backend, mobile, tests/CI) + 1 relecteur lecture seule; sécurité et conformité données = règles de revue appliquées par le relecteur, pas des agents permanents. Monter à 5 agents seulement si la revue humaine n'est pas le goulot d'étranglement (c'est elle qui plafonne le débit réel).

**Paiement: passer par un agrégateur pour le MVP.** NjokaLab (guide 2026) recommande les agrégateurs (Campay, CinetPay, Notch Pay, Monetbil) pour environ 95 % des startups: une seule API pour MTN et Orange, mise en route de 1 à 2 jours selon eux (à vérifier avec chaque agrégateur), bascule automatique en cas de panne d'un opérateur. L'accès direct aux opérateurs évite la commission de l'agrégateur mais impose deux intégrations et la négociation de deux contrats. Règles techniques: ne jamais marquer un paiement réussi à partir de la redirection côté client; vérifier la signature HMAC SHA-256 des webhooks; clé d'idempotence; tâche de relance si le webhook n'arrive pas après 90 secondes. Le flux USSD push affiche la demande de confirmation sur le téléphone en 2 à 5 secondes.

**Frais MTN MoMo Cameroun (MomoCalc, juin 2026):** envoi 0,5 % plafonné à 500 FCFA; retrait 2 % plafonné à 3 500 FCFA; réception gratuite; taxe sur transferts de 0,2 % + 4 FCFA par opération depuis janvier 2025; paiements marchands exemptés de cette taxe. Un pack à 50 FCFA est donc très sensible aux frais fixes: l'agrégateur peut manger une part importante. Calculer la marge nette réelle d'un pack avec les frais de l'agrégateur (non publiés dans les sources, à demander) avant de fixer le prix.

**Pile mobile: Flutter reste cohérent pour téléphones d'entrée de gamme.** Comparatif 2026 (Dream Tech Dynamics): Flutter démarre en 600 à 1000 ms (React Native 800 à 1200 ms), utilise 60 à 100 Mo de mémoire au repos (React Native 80 à 120 Mo), APK 8 à 12 Mo (React Native 12 à 18 Mo). Ce sont des ordres de grandeur de blog, pas des mesures sur vos appareils. Contre-point: les développeurs React Native sont environ 3 fois plus nombreux. Recommandation à valider: Flutter si l'équipe peut s'y former; sinon React Native avec Hermes. Test décisif: construire l'écran de recherche dans les deux sur un téléphone Android à 2 Go de RAM et mesurer.

**Méthode de projet: la cohérence compte plus que le choix.** Sagan Orbit (2026): Kanban convient aux équipes de 3 à 5, Scrum aux équipes de 5 à 15 avec rôles dédiés; Scrumban est un hybride, avec le risque de piocher des morceaux incohérents. Règle: choisir une méthode et s'y tenir au moins 3 mois avant de réévaluer. Cela renforce la reco v4/v5 (Scrumban simple ou Kanban strict tant que l'équipe humaine < 4).

## 2. Critiques de fonctionnalités: angles non encore traités

- **Aucune mesure de qualité de réponse.** Sans taux « recherche aboutie » (recherche → appel → « trouvé »), vous ne saurez pas si l'app marche. À définir comme indicateur n°1 avant le pilote.
- **Équité entre commerçants.** Si le commerçant qui paie apparaît toujours en premier, la confiance des clients baisse. Prévoir une mention « mis en avant » visible et un plafond de placements.
- **Pas de mode « zéro donnée ».** Résultats mis en cache pour les produits récents et appel possible hors connexion de données (le dialer natif n'en a pas besoin): c'est un avantage face aux concurrents, à mettre en avant.
- **Dépendance à un seul canal d'inscription.** Si les agents terrain partent, la base se périme. Prévoir un tarif par fiche vérifiée et une rotation.
- **Modération du forum** (rappel): sans règles ni modérateur, risque de fraude, d'arnaques et de diffamation. Reporter en v2 reste le choix prudent.

## 3. Agents IA: coût et contrôle (à mesurer, pas à supposer)

Les sources ne donnent pas de multiplicateur de coût fiable pour les flottes de codage. Mesurer dès la semaine 1: jetons par tâche acceptée, nombre de retours de revue, taux de tests rouges après fusion. Règle de décision: n'ajouter un agent que si l'indicateur « tâches terminées par jour de revue humaine » monte; sinon retirer.

## 4. Décisions à prendre (Jeff)

1. Agrégateur de paiement ou contrats directs MTN / Orange pour le MVP?
2. Marge nette minimale par pack (après frais agrégateur et taxes)?
3. Flutter ou React Native (test comparatif sur téléphone à 2 Go de RAM)?
4. Dispositif d'agents: 1 superviseur + 3 agents + 1 relecteur pour commencer, ok?
5. Méthode: Kanban strict ou Scrumban, engagement de 3 mois.
6. Indicateur n°1 du pilote: taux de recherche aboutie.
7. Règle de mise en avant payante (plafond, mention visible).

## Sources
- [Multi-Agent AI Systems: Why They Fail and How to Fix Coordination Issues (Augment Code)](https://www.augmentcode.com/guides/why-multi-agent-llm-systems-fail-and-how-to-fix-them)
- [Intégration MTN MoMo et Orange Money au Cameroun (NjokaLab)](https://www.njokalab.com/insights/how-to-integrate-mtn-momo-orange-money-cameroon-api/)
- [Frais MTN MoMo Cameroun 2026 (MomoCalc)](https://momocalc.com/cameroon/mtn-momo-fees)
- [React Native vs Flutter 2026 (Dream Tech Dynamics)](https://www.dreamtechdynamics.com/blog/mobile-development/react-native-vs-flutter-2026)
- [Kanban vs Scrum pour petites équipes 2026 (Sagan Orbit)](https://saganorbit.com/blog/kanban-vs-scrum-for-small-teams)


---

<!-- source : audit-expert-v7-critique-et-corrections-netbuis.md -->

# Audit expert v7 NetBuis: critique par domaine et corrections (2026-10-05)

Complète v2 à v6 sans les répéter (MVP trop large, démarrage à vide, double facturation, loi 2024/017, Twilio trop cher, paiement par agrégateur, WhatsApp wa.me). Rien n'est tranché: les choix restent à Jeff. Ce qui vient d'une source est marqué [S]; ce qui est mon raisonnement est marqué [A] (avis à discuter).

## 1. Données de contexte utiles
- Android pèse 83,34 % des mobiles au Cameroun, iOS 16,64 % (StatCounter, septembre 2026) [S]. Conséquence [A]: lancer Android seul pour le MVP; iOS plus tard (sauf si Flutter, où le coût marginal est faible).
- Une appli « légère » en marché émergent vise typiquement 10 à 15 Mo (Facebook Lite < 2 Mo), images vectorielles, chargement progressif, peu d'animations, fonctions avancées en modules optionnels [S, blog dev.to]. Cible 30 Mo de v4 = plafond haut, à resserrer [A].

## 2. Critique par domaine (ce qui est nouveau)

| Domaine | Critique | Gravité | Correction |
|---|---|---|---|
| UI | Risque d'écrans chargés (carte 7 niveaux, forum, packs) sur petits écrans | Haute | Un seul écran d'accueil: barre de recherche + 3 produits populaires. Icônes et libellés très courts. Test avec 5 vrais utilisateurs peu lettrés avant de figer |
| UX | Premier lancement vide = abandon immédiat | Critique | Ne montrer que les quartiers ayant au moins N commerçants vérifiés; message honnête « pas encore chez vous » + liste d'attente plutôt qu'un écran vide |
| Frontend | Écrans dépendants du réseau | Haute | Hors-ligne d'abord: la base locale est l'unique source de lecture, l'écriture utilise une file avec relance (Android Developers, offline-first) [S]. Résultats récents lisibles sans données |
| Backend | Coût et verrouillage | Moyenne | Postgres managé (type Supabase): prix par paliers fixes (0 / 25 / 599 USD), autorisations par Row Level Security, export `pg_dump` possible, donc peu de verrouillage; Firebase facture à l'opération et peut grimper avec les écoutes temps réel [S, Bytebase]. Attention: hébergement hors Cameroun = question loi 2024/017 (v5) |
| Sécurité | Liste OWASP Mobile Top 10 2024 non couverte explicitement | Haute | Checklist de revue (voir §3) |
| Sécurité | Fausses fiches et arnaques côté commerçants | Haute | Vérification à l'inscription, signalement, gel de compte après plainte, détection de comptes multiples; signaux d'appareil (GPS truqué, appli clonée) en arrière-plan sans friction [S, Incognia]. Fonction à calibrer: signaux d'appareil = données personnelles, consentement requis [A] |
| Mémoire / perf | Téléphones 2 Go de RAM | Haute | Budget mesuré: démarrage, RAM au repos, taille APK, mesurés sur un vrai appareil bas de gamme à chaque version (critère de refus de fusion) [A] |
| Prix | Marge d'un pack à 50 FCFA après frais | Haute | Voir v6; ajouter une feuille de calcul de marge nette par canal de paiement avant tout code de paiement |
| Qualité | Aucun indicateur de réponse | Haute | Taux de recherche aboutie comme indicateur n°1 (v6) |

## 3. Checklist sécurité mobile (OWASP Mobile Top 10 2024) [S, DoveRunner]
M1 identifiants: clés dans Android Keystore, jamais dans le code. M2 chaîne d'approvisionnement: contrôle et mise à jour des bibliothèques (critique si des agents IA ajoutent des dépendances). M3 authentification/autorisation: contrôles côté serveur. M4 validation des entrées côté client et serveur. M5 communication: TLS partout, épinglage de certificat. M6 vie privée: consentement explicite, réglages. M7 protections binaires: obfuscation, détection de falsification. M8 mauvaise configuration: pas de mode debug en production, permissions minimales. M9 stockage: chiffrer ce qui est local. M10 cryptographie: algorithmes standards bien utilisés. Utilisation proposée [A]: cette liste devient la grille de l'agent relecteur et du contrôle avant chaque version.

## 4. Fonctionnalités: ce qui peut ne pas plaire, ce qui manque
- Peut déplaire: compte obligatoire pour chercher; commerçant qui ne répond pas; résultat « en stock » faux; mise en avant payante non signalée; forum non modéré; demandes de permissions inutiles (contacts, micro) [A].
- Inutile pour le MVP [A]: forum, produits « les plus demandés » tant que les volumes sont faibles (faux signal sinon), cartes détaillées.
- Utile mais absent des audits précédents [A]: horaires et jours d'ouverture; « dernière confirmation » affichée sur chaque fiche; signalement en un geste; langue (français, anglais, éventuellement langue locale) et orthographe tolérante; mode économie de données; partage d'une fiche par WhatsApp (croissance sans publicité).
- Trop cher? Avec l'appel natif, le coût par utilisateur est proche de zéro; les vrais coûts sont le terrain (inscrire et rafraîchir), les SMS OTP et le support [v5].
- Pas assez moderne? [A] La modernité utile ici = rapidité, voix, hors-ligne; pas animations ni IA générative. Une IA peut aider à nettoyer les noms de produits et les synonymes côté serveur sans alourdir l'appli.

## 5. Décisions pour Jeff
1. Android seul au MVP, oui ou non?
2. Hébergement de la base (Postgres managé hors Cameroun vs. local) après avis juridique.
3. Adopter la checklist OWASP comme critère de fusion?
4. Budget de performance (RAM, démarrage, taille) fixé sur quel téléphone de référence?
5. Fonctions horaires / dernière confirmation / signalement dans le MVP?

## Sources
- [Part de marché mobile Cameroun (StatCounter)](https://gs.statcounter.com/os-market-share/mobile/cameroon)
- [OWASP Mobile Top 10 2024 (DoveRunner)](https://doverunner.com/blogs/owasp-mobile-top-10-2024/)
- [Build an offline-first app (Android Developers)](https://developer.android.com/topic/architecture/data-layer/offline-first)
- [Lightweight mobile apps for emerging markets (dev.to)](https://dev.to/abhayit2000/lightweight-mobile-apps-building-for-emerging-markets-with-low-bandwidth-and-limited-storage-445m)
- [Supabase vs Firebase 2026 (Bytebase)](https://www.bytebase.com/blog/supabase-vs-firebase/)
- [Seller fraud detection (Incognia)](https://www.incognia.com/blog/seller-fraud-detection)


---

<!-- source : audit-expert-v8-agents-securite-play-tests-voix-netbuis.md -->

# Audit expert v8 NetBuis: sécurité des agents IA, Google Play, tests du code généré, voix locale (2026-10-05)

Complète v2 à v7 sans les répéter. Rien n'est tranché: les choix restent à Jeff. [S] = source, [A] = mon avis à discuter.

## 1. Nouveauté majeure: les agents IA sont eux-mêmes un risque de sécurité
Les audits précédents (v7, M2 d'OWASP) parlaient de la chaîne d'approvisionnement du logiciel. Il manquait le risque lié aux agents qui écrivent le code.

Chiffres [S, Cloud Security Alliance, avril 2026]:
- 19,7 % de 2,23 millions d'échantillons de code générés par IA citaient des paquets qui n'existent pas (205 474 noms inventés). Modèles libres: 21,7 %; modèles commerciaux: 5,2 %.
- 43 % de ces noms inventés reviennent à l'identique d'une exécution à l'autre: un pirate peut donc enregistrer à l'avance un faux paquet portant ce nom (« slopsquatting ») et l'agent l'installera.
- Injection de consignes via le CI: un titre de ticket piégé a suffi à faire exécuter des commandes à un agent (incident « Clinejection », environ 4 000 développeurs touchés en huit heures).

Contrôles proposés [S, CSA et Developers Digest] à adapter [A]:
1. Vérifier chaque paquet suggéré dans le registre officiel avant installation; fichier de verrouillage (lockfile) versionné; installation CI uniquement depuis le lockfile.
2. Délai minimal avant d'utiliser une version toute neuve d'un paquet (ex. réglage `minimumReleaseAge` de pnpm); signaler les paquets enregistrés récemment.
3. Permissions des agents au minimum: règles autoriser / demander / refuser par outil; retirer l'accès large au shell et à l'écriture quand il n'est pas nécessaire.
4. Bac à sable avec limites de fichiers et de réseau (liste de domaines autorisés); fichiers sensibles (hooks git, configuration CI, scripts postinstall) en lecture seule pour les agents.
5. Jetons d'accès courts et à portée étroite; jamais de clés de paiement ou de production dans l'environnement d'un agent.
6. Relire le code d'agent comme une contribution d'un inconnu; contrôle de dépendances et détection de secrets en CI.
Pour NetBuis [A]: c'est une raison de plus de rester à 3 à 5 agents (option B du rapport d'orchestration): chaque agent ajouté élargit la surface d'attaque. Les clés Orange Money / MTN ne doivent exister que chez l'humain et dans le coffre de secrets de production.

## 2. Tests: le piège « 100 % de couverture et rien de vérifié »
Les agents écrivent code et tests; le nombre de tests et la couverture augmentent plus vite que la capacité humaine à relire [S, awesome-testing, août 2026]. Un composant à 100 % de lignes couvertes n'avait que 61 % de force réelle de test (test de mutation).

Méthode [S]: introduire volontairement de petits défauts (mutants) dans le code; si les tests restent verts, ils ne servent à rien. Outils: StrykerJS (JavaScript), PITest (Java). Résultats rapportés: backend Java 81 % → 89 %, front React 60 % → 82 %. Règle citée: pour chaque mutant survivant, écrire un test qui échoue sur lui et passe sur l'original.

Pour NetBuis [A]:
- Remplacer l'idée de « 10 agents testeurs » par: 1 agent testeur + CI + test de mutation limité au code à risque (authentification, quotas d'appels, crédits, webhooks de paiement, vérification d'identité).
- Un humain relit les tests des zones argent et données personnelles.
- Indicateur de qualité à suivre: score de mutation par module sensible, pas la couverture de lignes.
- Les tests sur vrai téléphone 2 Go de RAM (v7) restent hors de portée d'un agent: à faire à la main avant chaque version.

## 3. Google Play: obstacles de publication à planifier
- Compte développeur personnel créé après le 13 novembre 2023: test fermé avec au moins 12 testeurs inscrits en continu pendant 14 jours avant l'accès à la production; demande d'accès, examen en général 7 jours ou moins [S, aide Play Console]. Un compte d'organisation ne semble pas concerné (la page ne le dit pas explicitement, à vérifier) [S/A].
- Vérification d'identité des développeurs: obligatoire pour les nouveaux comptes personnels depuis septembre 2026; comptes existants préavis de 6 à 12 mois, attendu début 2027; pièce d'identité, justificatif de domicile de moins de 90 jours, téléphone; organisation: numéro D-U-N-S et registre du commerce. Le Cameroun n'est pas cité explicitement, déploiement progressif par région à risque [S, TesterBee, blog tiers: à confirmer sur le site officiel de Google].
- Conséquence [A]: prévoir 3 à 4 semaines avant la première publication publique (recrutement de 12 testeurs, 14 jours, examen). Les 12 testeurs peuvent être de vrais commerçants et clients du quartier pilote, ce qui sert aussi au jalon 0. Décider tôt: compte personnel ou compte de société (la société doit exister et avoir un D-U-N-S).
- Distribution parallèle [A]: APK direct partagé par WhatsApp est courant localement, mais à risque (faux APK piégés, pas de mises à jour); à n'utiliser que pour le pilote, avec empreinte (hash) publiée.

## 4. Recherche vocale: ambition à calibrer
Une revue de 71 études (111 langues africaines, environ 11 200 heures de parole) [S, arXiv 2510.01145]: les langues camerounaises sont très peu représentées; environ 10 000 heures étiquetées pour toutes les langues africaines réunies contre 55 000 pour l'anglais seul; Whisper est cité comme le plus robuste pour l'anglais africain accentué; les grands modèles préentraînés peuvent atteindre jusqu'à 53 % d'erreurs sur données déséquilibrées. Il existe un jeu de données Common Voice pour le pidgin camerounais [S, Mozilla].
Pour NetBuis [A]:
- MVP: dictée vocale du système Android en français et en anglais (gratuite, intégrée), avec correction tolérante des fautes côté serveur. Ne pas promettre le support des langues locales.
- Ne pas entraîner de modèle maison au début. Mesurer d'abord sur 50 vraies requêtes enregistrées au jalon 0 (avec consentement) le taux de recherches réussies par la voix.
- Alternative sans reconnaissance: recherche par icônes de catégories et par photo/étiquette de produit (v2).

## 5. Ce qui est nouveau côté « on a oublié quoi »
1. Politique d'usage des agents écrite (permissions, secrets, dépendances): absente des audits jusqu'ici.
2. Plan de publication Play (testeurs, identité, calendrier) absent.
3. Mesure de la qualité des tests (mutation) absente.
4. Budget de temps pour la vérification humaine des zones argent / identité: à compter comme coût principal du projet, pas la génération de code [A].

## 6. Décisions pour Jeff
1. Adopter la politique d'agents du §1 (permissions minimales, lockfile obligatoire, clés de paiement hors de leur portée)?
2. Test de mutation obligatoire sur les modules argent / authentification / crédits?
3. Compte Play personnel ou de société, et qui sont les 12 premiers testeurs?
4. Recherche vocale: français/anglais seulement pour le MVP, oui ou non?

## Sources
- [AI Coding Agents: An Unaudited Supply Chain Node (Cloud Security Alliance)](https://labs.cloudsecurityalliance.org/research/csa-research-note-ai-agents-software-supply-chain-risk-20260/)
- [Securing AI Coding Agents: a threat model for 2026 (Developers Digest)](https://www.developersdigest.tech/blog/securing-ai-coding-agents)
- [Mutation Testing for Agent-Written Code (awesome-testing)](https://www.awesome-testing.com/2026/08/mutation-testing-for-agent-written-code)
- [App testing requirements for new personal developer accounts (Play Console Help)](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Google Play Developer Verification 2026 (TesterBee)](https://testerbee.com/blog/google-play-developer-verification-2026)
- [ASR for African low-resource languages: systematic review (arXiv)](https://arxiv.org/pdf/2510.01145)
- [Common Voice Scripted Speech 25.0, Cameroon Pidgin (Mozilla Data Collective)](https://mozilladatacollective.com/datasets/cmn1qa0u300z4mm07egfgo1k4)


---

<!-- source : audit-expert-v9-marche-paiement-orchestration-netbuis.md -->

# Audit expert v9 NetBuis: pourquoi les places de marché africaines échouent, paiement mobile qui bouge, orchestration d'agents recalibrée (2026-10-05)

Complète v2 à v8 sans les répéter. Rien n'est tranché: les choix restent à Jeff. [S] = source web, [A] = mon avis à discuter. Aucune hypothèse de ce rapport n'a été testée sur le terrain.

## 1. Critique stratégique: les raisons d'échec des places de marché africaines, appliquées à NetBuis

Constats [S, PlanetWeb « Why Marketplaces Fail in Nigeria » et SoftwareSeni « The Platform Trap »]:
- 90 % des plateformes meurent avant la masse critique; il faut en général 2 à 5 ans pour l'atteindre.
- Causes citées en Afrique: démarrage des deux côtés à la fois (problème de l'œuf et de la poule), manque de confiance après des arnaques, coûts logistiques, économie unitaire qui s'effondre quand les subventions s'arrêtent, financement en baisse (-40 % sur un an au T2 2026 pour la tech africaine selon PlanetWeb).
- Les gagnants contrôlent d'abord le côté difficile: Moniepoint a bâti son réseau d'agents avant les paiements marchands; Sabi a numérisé des relations de distribution existantes; Chowdeck a possédé la livraison dans des zones denses.
- Tactiques de démarrage éprouvées [S]: offre d'abord (le côté le plus dur), une seule zone géographique à la fois, utilité immédiate pour un seul côté (OpenTable donnait un outil de gestion aux restaurants avant d'avoir des clients), pré-remplissage de l'offre depuis des sources existantes. Seuil de densité: 50 à 100 établissements concentrés par catégorie et par ville (exemple OpenTable).

Pour NetBuis [A]:
1. NetBuis n'a pas de logistique ni de paiement de commande: c'est un avantage (marge et risque faibles). Le côté difficile est le commerçant (inscrire, garder la fiche à jour). Le budget doit être pensé comme un budget d'agents de terrain, pas de code.
2. « Utilité pour un seul côté »: donner au commerçant quelque chose de valable sans clients (fiche visible, compteur d'appels reçus, lien de partage WhatsApp). C'est déjà évoqué en v5; ici la source le confirme comme tactique centrale.
3. Un seul quartier pilote, un seul secteur au départ (ex. pièces et quincaillerie ou alimentation), seuil de 50 commerçants vérifiés avant d'ouvrir les recherches au public. Indicateur de passage: taux de recherches aboutissant à un appel utile, et usage répété par les clients, pas le nombre de téléchargements.
4. Le risque de financement est réel: prévoir un modèle qui survit sans levée (coûts fixes bas, pas de subvention d'appels illimitée). À relier aux packs de crédits de monetisation-appels-orange-money.md.

## 2. Le vrai concurrent: WhatsApp et le bouche-à-oreille, pas une autre appli
- Les petits commerçants africains vendent déjà par WhatsApp (statuts, catalogue). Un client demande « qui a tel produit à tel endroit » dans un groupe de quartier. NetBuis doit faire mieux sur un point précis: trouver vite, sans attendre une réponse de groupe, avec un numéro vérifié.
- Limite de cette analyse [S/A]: la source trouvée sur le catalogue WhatsApp date de 2019 et ne couvre pas le Cameroun; je n'ai pas trouvé de donnée récente sur l'usage du catalogue par les commerçants camerounais. À tester par 10 entretiens de commerçants au jalon 0 (« comment vos clients vous trouvent-ils aujourd'hui? »).
- Conséquence [A]: NetBuis ne doit pas demander au commerçant de ressaisir son catalogue. Piste: import de produits par photo ou copie depuis WhatsApp (v2), partage d'une fiche NetBuis vers WhatsApp (déjà proposé en v7).

## 3. Paiement mobile: le terrain change, ne pas s'enfermer
Faits [S, Business in Cameroon]:
- MTN Mobile Money et Orange Money traitent ensemble plus de 80 % des transactions électroniques.
- Wave arrive via Commercial Bank Cameroun avec dépôts et retraits gratuits et 1 % sur les transferts.
- Camtel prévoit « Blue Money » en 2026 (capital initial de 500 millions de FCFA).
- Valeur des transactions de paiement mobile: 8,8 mille milliards de FCFA (2019) à 22,1 mille milliards (2023); le Cameroun pèse 62 % des comptes et 76 % de la valeur de la zone CEMAC.
Pour NetBuis [A]:
- Isoler les paiements derrière une interface « fournisseur de paiement » (un module), pour ajouter Wave ou Blue Money sans réécrire la facturation. Cela renforce l'option « agrégateur » de v6.
- Comparer les frais réels par opérateur avant de fixer le prix des packs: si un opérateur devient plus bas, le prix du pack pour l'utilisateur peut changer. À vérifier avec chaque opérateur; je n'ai pas de grille de frais marchands de Wave au Cameroun.
- Ne pas promettre aux utilisateurs « paiement par WhatsApp »: aucune source trouvée ne confirme un paiement natif WhatsApp au Cameroun.

## 4. Orchestration d'agents: recalibrage [S, Addy Osmani « The Code Agent Orchestra »]
- Optimum: 3 à 5 agents en parallèle; trois ciblés battent cinq dispersés; le coût en jetons croît de façon linéaire. Règle: ne pas lancer plus d'agents que ce que l'on peut relire. Cela confirme que « 64 agents » n'est pas adapté et se rapproche de l'option B (3 à 5 agents) de rapport-orchestration-agents-ia-netbuis.md.
- Le goulot n'est plus la génération mais la vérification humaine (déjà noté en v8 §5, ici confirmé par une deuxième source).
- Trois garde-fous obligatoires: approbation du plan avant d'écrire du code; automatismes (hooks) qui lancent tests et lint; un fichier AGENTS.md des règles du projet.
- AGENTS.md rédigé par un humain vaut mieux que généré par IA: la version générée réduit légèrement le taux de réussite (environ 3 %) et augmente le coût de plus de 20 % [S, même source].
- Routage de modèles: modèle économique pour planifier, modèle intermédiaire pour coder, modèle spécialisé pour relire [S]; à tester pour le coût [A].
- Un seul agent suffit si le projet tient dans un contexte, sans gain de spécialisation, ou si la capacité de relecture est limitée [S]. C'est probablement le cas d'un démarrage solo avec Jeff comme seul relecteur [A].
- Sous-agents ou équipes d'agents? Sous-agents: plus simples, dépendances gérées à la main, environ 220 000 jetons pour un projet type [S]. Équipes: liste de tâches partagée, messages entre agents, verrouillage de fichiers; utile si les tâches sont fortement liées [S]. Pour NetBuis [A]: commencer par sous-agents.

Dispositif minimal proposé [A] (à comparer aux options du rapport d'orchestration existant):
1. Agent « architecte/planificateur »: produit le plan, relu par Jeff avant tout code.
2. Agent « développeur » (backend ou appli selon la tâche).
3. Agent « testeur »: écrit les tests; mutation sur les modules argent/authentification (v8).
4. Agent « relecteur sécurité » avec la grille OWASP Mobile (v7) et la politique d'agents (v8).
5. Optionnel: agent « contenu/terrain » (scripts d'import, textes, traductions), sans accès aux clés.
Jeff relit les plans et les zones argent/CNI. Aucun agent n'a accès aux clés de production.

## 5. Gestion de projet: ce que ces nouvelles données changent
- La priorité n°1 n'est pas une méthode logicielle mais le test de demande du jalon 0 (v5): 30 à 50 commerçants inscrits à la main, mesure des recherches abouties. Les méthodes comparées dans rapport-methodes-gestion-projet-netbuis.md restent à choisir par Jeff; critère de choix proposé [A]: la méthode doit permettre un cycle court (1 à 2 semaines) avec décision go/no-go chiffrée, et une revue humaine de chaque lot avant fusion.
- Ajouter une « porte de passage » commerciale en plus des portes techniques: densité atteinte dans le quartier (seuil de 50 commerçants vérifiés), taux de recherche aboutie, coût d'inscription par commerçant.

## 6. Ce qui nous échappait encore («on a oublié quoi»)
1. Une hypothèse de survie sans financement externe (financement tech africain en baisse).
2. Concurrence WhatsApp jamais mesurée sur le terrain.
3. Couche d'abstraction des paiements pour les nouveaux acteurs (Wave, Blue Money).
4. Budget d'agents de terrain (inscription et rafraîchissement) chiffré à côté du budget technique.

## 7. Décisions pour Jeff
1. Quartier et secteur du pilote, et seuil de densité (50 commerçants?) avant d'ouvrir au public?
2. Faire 10 entretiens de commerçants sur « comment vos clients vous trouvent » avant de figer les fonctions?
3. Isoler les paiements derrière un module (prêt pour Wave/Blue Money)?
4. Démarrer avec sous-agents (3 à 5) plutôt qu'équipes d'agents, avec AGENTS.md écrit par un humain?
5. Ajouter la porte « densité et rétention » aux jalons?

## Sources
- [Why Marketplaces Fail in Nigeria (PlanetWeb)](https://planetweb.ng/why-marketplaces-fail-in-nigeria/)
- [The Platform Trap: cold start (SoftwareSeni)](https://www.softwareseni.com/the-platform-trap-why-most-platforms-fail-before-reaching-critical-mass-and-how-to-overcome-the-cold-start-problem/)
- [Camtel plans to enter MoMo market in 2026 (Business in Cameroon)](https://www.businessincameroon.com/public-management/0312-15437-camtel-plans-to-enter-momo-market-in-2026)
- [The Code Agent Orchestra (Addy Osmani)](https://addyosmani.com/blog/code-agent-orchestra/)
- [WhatsApp business catalogue and m-commerce in Africa (Techpoint Africa, 2019, ancienne)](https://techpoint.africa/insight/whatsapp-business-catalog/)


---

<!-- source : audit-expert-v10-agents-specs-pwa-loi-netbuis.md -->

# Audit expert v10 NetBuis: coût réel des équipes d'agents, spécifications, version web légère, loi 2024/017 (2026-10-05)

Complète v2 à v9 sans les répéter. Rien n'est tranché: les choix restent à Jeff. [S] = source web, [A] = mon avis à discuter. Rien n'a été testé sur le terrain. Cette passe s'est limitée à ce que les rapports précédents ne couvraient pas encore; les sujets déjà traités (marché, paiement, sécurité, voix, Play, gestion de projet) ne sont pas refaits.

## 1. Orchestration d'agents: nouveaux chiffres sur les « équipes d'agents » [S, aq.dev, doc Anthropic citée, état juillet 2026]
- Une équipe d'agents consomme environ 7 fois plus de jetons qu'une session normale quand les coéquipiers travaillent en mode plan. Chaque coéquipier est une instance séparée avec son propre contexte: le coût croît à peu près linéairement avec la taille.
- Recommandation officielle: démarrer à 3 à 5 coéquipiers, environ 5 à 6 tâches par coéquipier. Trois ciblés valent souvent mieux que cinq dispersés. Cela confirme que 64 agents n'a pas de justification.
- Quand utiliser quoi [S]: équipe d'agents quand les agents doivent se challenger (revue de code multi-angles, hypothèses de débogage concurrentes, recherche); sessions parallèles avec un worktree git chacune pour des tâches séparables (corrections indépendantes, refactorisations mécaniques), au coût normal par session et avec isolation des fichiers.
- Limites actuelles [S]: fonction expérimentale et désactivée par défaut; une seule équipe par session; les coéquipiers ne peuvent pas en créer d'autres; reprise de session sans restauration des coéquipiers; statut des tâches parfois en retard.
- Pour NetBuis [A]: construire avec des sessions parallèles en worktrees (2 à 3 maximum, un propriétaire par dossier), et réserver l'équipe d'agents aux revues avant version (sécurité, performance téléphone 2 Go, conformité) où le débat entre agents apporte quelque chose. Ne pas payer le facteur 7 pour du code courant. Mesurer jetons par tâche acceptée dès la semaine 1 (déjà proposé en v8).

## 2. Développement piloté par les spécifications (SDD) [S, DEV Community, Thoughtworks cité]
- Trois niveaux: spec d'abord (le code dérive ensuite), spec ancrée (spec et code évoluent ensemble, tests automatiques qui font respecter la spec; « le bon compromis pour la plupart des systèmes de production »), spec comme source (seule la spec est éditée; outillage encore immature).
- Chaîne type: principes, spécification, clarification, plan, découpage en tâches, implémentation, analyse, avec une relecture humaine entre chaque phase. Critères d'acceptation au format EARS qui se traduisent directement en tests.
- Outils cités: GitHub Spec Kit (ouvert, sans dépendance fournisseur), Kiro (AWS), Claude Code, Cursor Plan Mode, Tessl.
- Pièges: sur-spécification qui devient du pseudo-code; des tests qui valident une mauvaise spec donnent une fausse confiance; Thoughtworks place le SDD en « Assess », pas « Adopt »; les gains annoncés par les vendeurs sont directionnels, et le vrai changement est où l'humain passe son temps, pas forcément la vitesse.
- Ne convient pas aux prototypes jetables, aux projets solo très courts, ni au travail exploratoire.
- Pour NetBuis [A]: viser « spec ancrée » allégée, seulement sur les zones argent, identité, consentement et crédits; une page de critères d'acceptation par tranche (recherche, fiche, appel), pas de documents lourds ailleurs. Cela relie le pitch de Shape Up (rapport de gestion de projet) à un test exécutable. À décider avec le choix de méthode de Jeff.

## 3. Canal: application native, version web légère (PWA) ou les deux? [S, testmuai; non tranché]
- PWA: un seul code, mises à jour instantanées sans magasin, très peu d'espace de stockage, pas d'installation obligatoire.
- Limites [S]: sur iOS tous les navigateurs utilisent WebKit, pas d'invite d'installation (il faut passer par Partager puis Sur l'écran d'accueil), notifications push web seulement si la PWA est déjà ajoutée à l'écran d'accueil, hors-ligne partiel par cache. Le natif garde l'avantage de la crédibilité de magasin, des notifications fiables et de l'intégration appareil.
- Pour NetBuis [A, à valider avec les chiffres locaux Android/iOS que je n'ai pas]: la recherche côté client est un contenu simple, ce qui plaide pour une version web légère accessible par lien (partageable sur WhatsApp, donc cohérent avec v7 et v9 §2) en plus de l'application, et pour réserver le natif à l'espace commerçant (notifications, mise à jour de fiche). Un lien web qui s'ouvre sans installer règle aussi une partie du coût de données et de la contrainte d'espace des téléphones 2 Go. Le comparatif Flutter / React Native lancé dans cette passe n'a pas donné de données exploitables pour le contexte africain: je ne tranche pas.

## 4. Voix: confirmation, rien de nouveau pour le Cameroun [S, TechCabal, février 2026]
Google WAXAL (lancé en février 2026): 27 langues africaines, plus de 11 000 heures de parole, licence ouverte commerciale. L'article ne mentionne ni Cameroun, ni français, ni pidgin. Cela confirme la position de v8 §4: dictée système en français et anglais pour le MVP, ne pas promettre les langues locales. À revérifier dans 6 mois, car cette filière avance vite.

## 5. Loi 2024/017: points à ajouter à la liste de v5 [S, TechHive Advisory; un seul article, à confirmer par un juriste local]
- Autorisation préalable de l'autorité de protection avant de commencer un traitement (et pas seulement un transfert).
- Notification de toute faille à l'autorité et aux personnes concernées, sans seuil de gravité; responsables de traitement et sous-traitants sont co-responsables.
- Registre des traitements et rapport annuel de sécurité.
- La période de transition de 18 mois s'est terminée en juin 2026: la loi s'applique maintenant.
- Divergence à signaler: cette source cite des amendes jusqu'à 100 millions FCFA ou jusqu'à 10 ans de prison, alors que v5 cite 1 à 100 millions en administratif et jusqu'à 1 milliard pour les sociétés. Les sources se contredisent; seul le texte officiel ou un juriste tranchera. Ne pas citer de chiffre d'amende dans un document public tant que ce n'est pas vérifié.
- Conséquence [A]: la démarche d'autorisation et le registre sont des tâches du jalon 0, avant tout pilote avec de vraies données (CNI et numéros de téléphone), avec un délai d'instruction inconnu à demander à l'autorité.

## 6. Appels: confirmation du choix « dialer natif » [S, page tarifs Twilio]
Twilio Cameroun: 0,7873 USD/min vers un mobile, 0,41 USD/min vers un fixe, numéro international à partir de 1,15 USD/mois, appel navigateur/application (SIP) à 0,004 USD/min. Même ordre de grandeur que v5: un pont d'appel facturerait deux jambes à la plateforme, donc le dialer natif reste le bon choix du MVP. Le seul levier VoIP bon marché est l'appel de données entre deux comptes actifs, à tester seulement si le suivi d'appel devient indispensable (v2).

## 7. Ce que cette passe n'a pas pu établir
- Prix moyen du Go de données au Cameroun: la source Statista est derrière un paywall; v5 cite une moyenne africaine (4,2 % du revenu par habitant), pas de chiffre camerounais fiable.
- Leçons chiffrées sur les annuaires de commerçants périmés ou la vérification de fiches en Afrique: la recherche n'a renvoyé que des annuaires génériques sans données exploitables. À remplacer par les 10 entretiens du jalon 0 (v9 §7).
- Comparaison Flutter / React Native pour téléphones d'entrée de gamme: pas de source exploitable trouvée.

## 8. Décisions pour Jeff
1. Sessions parallèles en worktrees (2 à 3) pour construire, équipe d'agents seulement pour les revues avant version, oui ou non?
2. Spécification ancrée allégée sur argent, identité, consentement et crédits, oui ou non?
3. Ajouter une version web légère côté client en plus de l'application, ou rester 100 % application au MVP?
4. Lancer maintenant la démarche d'autorisation auprès de l'autorité et un juriste local pour trancher les amendes?

## Sources
- [Claude Code Agent Teams vs Parallel Sessions (aq.dev)](https://aq.dev/guides/claude-code-agent-teams/)
- [Spec-Driven Development in 2026 (DEV Community)](https://dev.to/krlz/spec-driven-development-in-2026-what-it-is-the-tooling-and-how-teams-actually-use-it-2fk2)
- [PWA vs Native App vs Hybrid (testmuai)](https://www.testmuai.com/learning-hub/pwa-vs-native/)
- [Voice is Africa's gateway to AI (TechCabal, 2026)](https://techcabal.com/2026/02/12/voice-is-africas-gateway-to-ai-and-google-wants-to-lead-it/)
- [Operationalising Cameroon's Data Protection Law (TechHive Advisory)](https://www.techhiveadvisory.africa/insights/operationalising-cameroons-data-protection-law-a-review-of-key-provisions-and-impacts)
- [Programmable Voice Pricing in Cameroon (Twilio)](https://www.twilio.com/en-us/voice/pricing/cm)


---

<!-- source : audit-expert-v11-recherche-telephones-simples-revue-dora-netbuis.md -->

# Audit expert v11 NetBuis: téléphones simples, moteur de recherche, cartes, confiance, revue de code comme goulot (2026-10-05)

Complète v2 à v10 sans les répéter. Rien n'est tranché: les choix restent à Jeff. [S] = source web, [A] = mon avis à discuter. Rien n'a été testé sur le terrain. Plusieurs sources sont anciennes ou hors Cameroun: je le signale à chaque fois.

## 1. Critique: qui NetBuis exclut sans le dire (téléphones simples, données chères)
- Les audits précédents supposent un smartphone Android (83 % des mobiles, v7). Ils ne parlent pas des utilisateurs de téléphones à touches, souvent les moins lettrés et les plus nombreux chez les petits clients des marchés.
- Données trouvées, à prendre avec prudence: en 2017, 61 % des téléphones vendus en Afrique étaient des téléphones simples [S, ICTworks, 2018, ancien]; un service africain recevait 96 % de ses signalements par USSD, 3 % par appli, 1 % par le web [S, même source, cas d'un autre service]. GSMA (chiffres de fin 2020, anciens): écart d'usage de 53 % (couverture sans usage), moins de la moitié des connexions sont des smartphones, données = 15,3 % du revenu des plus pauvres [S]. Kenya en 2026: 93 smartphones pour 100 téléphones, les téléphones simples reculent vite [S, Techweez, avril 2026]. Je n'ai trouvé aucun chiffre récent pour le Cameroun: [A] ne pas conclure, mesurer.
- Conséquence [A]: ajouter au jalon 0 une question « quel téléphone avez-vous? » aux 10 entretiens, et une porte d'entrée sans appli à tester: numéro de recherche vocale ou SMS/USSD (« tapez le produit, recevez 3 numéros »). Coût inconnu: devis d'un agrégateur SMS/USSD local à demander avant toute décision. Priorité à décider selon la part de non-smartphones mesurée dans le quartier pilote.
- Le lien web léger (v10 §3) couvre déjà les smartphones d'entrée de gamme; il ne couvre pas les téléphones à touches.

## 2. Moteur de recherche: le cœur du produit mérite un choix explicite
- Postgres seul: la recherche plein texte intégrée est « suffisante pour beaucoup de projets », mais ne gère pas les fautes de frappe; l'extension `pg_trgm` apporte une recherche approximative [S, Supabase]. Typesense et Meilisearch gèrent les fautes par défaut, mais ajoutent un serveur à héberger, surveiller et sécuriser [S, mêmes sources de comparaison].
- Pour NetBuis [A]: au MVP (quelques centaines de commerçants, quelques milliers de produits), `pg_trgm` + table de synonymes locaux (« ciment » / « Dangote », « riz » / « riz parfumé ») dans la base existante, sans nouveau serveur. Passer à Typesense/Meilisearch seulement si le taux de recherche aboutie plafonne à cause des fautes ou du classement. Les synonymes viennent des vraies requêtes du jalon 0, pas d'un modèle de langage inventé.
- Mesure: garder chaque requête sans résultat (avec consentement) pour enrichir synonymes et catalogue: c'est aussi la liste de ce que les utilisateurs veulent et que personne ne vend encore.

## 3. Cartes et localisation
- Prix Google Maps [S, buildmvpfast, 2026]: 7 USD / 1 000 chargements de carte, 5 USD / 1 000 géocodages; le crédit mensuel de 200 USD a été supprimé en mars 2025, remplacé par des seuils gratuits par service (10 000 événements/mois pour l'offre « Essentials »). Mapbox: 5 USD / 1 000, 50 000 chargements gratuits; OpenStreetMap: gratuit (auto-hébergement), mais serveur public de géocodage soumis à limites d'usage.
- Pas de source trouvée sur la qualité des adresses et des repères au Cameroun [limite]. [A] beaucoup de commerces se décrivent par repère (« derrière tel marché »): la fiche doit avoir un champ texte « repère » et un bouton « itinéraire » qui ouvre l'appli de cartes du téléphone (aucun coût d'API pour NetBuis), plutôt qu'une carte intégrée dans l'appli au MVP. Plus léger, moins cher, moins de permissions.
- Si carte intégrée plus tard: MapLibre + tuiles OpenStreetMap, avec zone du pilote téléchargeable (usage hors-ligne), à budgéter après test de la qualité des données OSM du quartier.

## 4. Confiance et sécurité d'une place de marché locale [S, TechVinta, guide vendeur occidental: à adapter]
- Six piliers: identité par paliers (« vérifier selon l'enjeu, pas à l'inscription »), filtrage des fiches avec revue humaine obligatoire pour les nouveaux vendeurs, avis seulement après transaction vérifiée et révélés en double aveugle, blocage des échanges de contacts, règles de paiement, litiges structurés avec délai annoncé [S].
- Ce qui ne s'applique pas à NetBuis [A]: le blocage des coordonnées existe pour empêcher de conclure hors plateforme; chez NetBuis, l'appel direct est le produit. À la place, mesurer l'appel utile (v6) et un retour en un geste après l'appel (« ont-ils eu le produit? oui/non »). C'est à la fois l'avis vérifié et l'indicateur de fraîcheur de la fiche.
- Ce qui s'applique [A]: vérification par paliers (téléphone au départ, pièce ou visite terrain seulement pour les badges « vérifié » ou mise en avant payante); revue humaine de chaque nouvelle fiche; signalement en un geste (v7); gel après plaintes.
- Forum et responsabilité: la recherche de la loi camerounaise de 2010 sur la cybersécurité n'a renvoyé aucune règle précise sur la responsabilité d'un hébergeur de contenu d'utilisateurs ni sur le retrait [limite: la page consultée ne la traitait pas]. Une procédure de modération et de retrait doit être validée par le juriste local (déjà demandé en v10) avant d'ouvrir le forum. Un argument de plus pour repousser le forum après le MVP (v7).

## 5. Orchestration: la revue de code est le vrai plafond [S, DORA 2026, InfoQ mai 2026, Kodus]
- L'IA « amplifie » ce qui existe: bons processus = capacité en plus, mauvais processus = problèmes en plus. Sept capacités fondatrices citées: plateforme interne de qualité, bon contrôle de version, données internes accessibles à l'IA, flux de travail clairs, alignement d'équipe, tests automatisés, intégration continue [S].
- Courbe en J: baisse de productivité au départ (apprentissage + « taxe de vérification » des changements générés), gains ensuite. Chiffres du rapport pour une organisation de 500 ingénieurs (retour de 39 % la première année, remboursement vers 8 mois): non transposables à un projet de 1 à 3 personnes, je ne les utilise pas pour NetBuis.
- Recommandations utiles [S]: suivre délai de livraison, fréquence de déploiement, taux d'échec des changements, temps de revue et taille des demandes de fusion; garder les demandes petites; donner aux agents les règles et motifs du dépôt (plus utile que changer de modèle); automatiser les revues répétitives pour garder l'humain sur l'architecture et la sécurité.
- Pour NetBuis [A]: cela confirme 3 à 5 agents au maximum (v9, v10) et ajoute des règles concrètes: demandes de fusion petites (une tranche = une demande), plafond de taille fixé avec Jeff, métrique « temps de revue humaine » suivie dès la semaine 1, prévoir une baisse de vitesse les premières semaines (courbe en J) pour ne pas conclure trop vite que l'approche échoue.
- Branches: développement sur tronc commun avec drapeaux de fonctionnalité et file de fusion est présenté comme meilleure option pour équipes avec agents, GitFlow restant pour secteurs très réglementés [S, source de blog peu rigoureuse sur l'IA: à traiter comme avis]. [A] pour NetBuis: tronc commun, branches de moins d'un jour, drapeaux pour cacher forum, packs et voix; les worktrees (v10 §1) sont compatibles. Zones argent/identité: revue humaine obligatoire avant fusion, même sous drapeau.

## 6. Gestion de projet: ajouts aux combinaisons déjà proposées
- Mesures de livraison (style DORA) à ajouter au pilotage hebdomadaire de rapport-methodes-gestion-projet: délai entre idée acceptée et appli installée chez un testeur, taux de retour arrière après déploiement, temps de revue. Elles s'ajoutent aux indicateurs produit (recherche aboutie, appels utiles, fiches rafraîchies).
- Ces mesures conviennent à n'importe laquelle des trois combinaisons (Kanban + Lean, Shape Up adapté, Scrum léger): la méthode reste le choix de Jeff.

## 7. Ce que cette passe n'a pas pu établir
- Part réelle de téléphones simples au Cameroun, coût d'un service USSD/SMS local, qualité des données OpenStreetMap dans le quartier pilote, règles précises de responsabilité d'un forum en droit camerounais, prix du Go au Cameroun (déjà noté en v10).
- Les chiffres GSMA et ICTworks sont de 2017 à 2020: ordre de grandeur seulement.

## 8. « On a oublié quoi » (nouveau)
1. Les utilisateurs sans smartphone ou sans forfait de données.
2. Un plan de recherche explicite (fautes de frappe, synonymes locaux, requêtes sans résultat).
3. Les repères en texte et l'itinéraire via l'appli de cartes du téléphone, plutôt qu'une carte payante.
4. Le retour « oui/non » après l'appel comme avis vérifié.
5. Règles de taille des demandes de fusion et mesure du temps de revue.

## 9. Décisions pour Jeff
1. Ajouter « quel téléphone avez-vous? » aux entretiens du jalon 0 et demander un devis SMS/USSD, oui ou non?
2. Recherche: `pg_trgm` + synonymes au MVP, Typesense/Meilisearch seulement si nécessaire?
3. Pas de carte intégrée au MVP (repère texte + itinéraire par l'appli de cartes)?
4. Retour oui/non après appel comme signal de confiance et de fraîcheur?
5. Tronc commun + drapeaux + demandes de fusion petites, avec revue humaine obligatoire sur argent/identité?
6. Suivre le temps de revue humaine dès la semaine 1 et accepter une baisse de vitesse initiale?

## Sources
- [The Feature Phone is Not Yet Dead in African Countries (ICTworks, 2018)](https://www.ictworks.org/feature-phone-not-dead-africa/)
- [Kenya smartphone penetration (Techweez, avril 2026)](https://techweez.com/2026/04/07/kenya-smartphones-penetration-feature-phone-decline/)
- [State of mobile internet connectivity in Sub-Saharan Africa (GSMA, données 2020)](https://www.gsma.com/solutions-and-impact/connectivity-for-good/mobile-for-development/blog/the-state-of-mobile-internet-connectivity-in-sub-saharan-africa/)
- [Postgres Full Text Search vs the rest (Supabase)](https://supabase.com/blog/postgres-full-text-search-vs-the-rest)
- [Google Maps API alternatives and pricing 2026 (buildmvpfast)](https://www.buildmvpfast.com/alternatives/google-maps)
- [Marketplace Trust & Safety Playbook (TechVinta, 2026)](https://techvinta.com/blog/marketplace-trust-and-safety-playbook)
- [DORA: strong foundations drive AI ROI (InfoQ, mai 2026)](https://www.infoq.com/news/2026/05/dora-roi-ai-assisted-dev-report/)
- [DORA 2026: ROI of AI runs through code review (Kodus)](https://kodus.io/en/dora-accelerate-state-of-devops/)
- [Trunk-Based Development vs GitFlow for AI Teams (brics-econ)](https://brics-econ.org/trunk-based-development-vs-gitflow-for-ai-teams-which-strategy-wins)
- [Cybercrime Laws in Cameroon (Kinsmen Advocates)](https://kinsmenadvocates.com/cybersecurity/cybercrime-laws-in-cameroon-2025)


---

<!-- source : audit-expert-v12-verification-android-loi-passerelle-netbuis.md -->

# Audit expert v12 NetBuis: vérification Android, loi 2024/017 après juin 2026, passerelle de paiement, agents (2026-10-05)

Complète v2 à v11 sans les répéter. Rien n'est tranché: les choix restent à Jeff. [S] = source web, [A] = mon avis. Rien n'a été testé sur le terrain. Cette passe est volontairement courte: après 11 audits, j'ai cherché seulement ce qui manquait ou avait changé.

## 1. Vérification des développeurs Android: l'échéance est passée, le Cameroun n'est pas dans la première vague
- Source officielle Google (blog Android Developers, mars 2026) [S]: déploiement à tous les développeurs depuis le 30 mars 2026; application obligatoire à partir du 30 septembre 2026 au Brésil, en Indonésie, à Singapour et en Thaïlande; extension mondiale en 2027 et après. Aucun calendrier propre à l'Afrique n'est donné.
- Les applis non enregistrées ne s'installent plus que par ADB ou un « flux avancé » [S].
- Bonne nouvelle pour le pilote [S]: un compte « distribution limitée », gratuit, sans pièce d'identité officielle, avec seulement un e-mail, permet de partager l'appli sur 20 appareils au maximum.
- Corrige v8 [A]: v8 s'appuyait sur un blog tiers pour les dates; la source officielle confirme la vague 2026 hors Cameroun et 2027+ pour le reste. Conséquence: le pilote par APK direct (v8 §3) reste possible, mais avec le compte à distribution limitée (≤ 20 appareils) ou, au-delà, une vérification complète. Un pilote de 30 à 50 commerçants dépasse 20 appareils: prévoir la vérification complète ou Play (test fermé) dès le pilote. À confirmer sur la page d'aide officielle avant de s'engager.

## 2. Loi camerounaise 2024/017 sur les données personnelles: la période de transition est terminée
- Un guide juridique [S, Afriwise] indique: obligation de consentement et de transparence; une Autorité de protection des données chargée du contrôle, des plaintes et de l'approbation des transferts hors du Cameroun, « pas encore opérationnelle » à la date de l'article; amendes jusqu'à 1 milliard de FCFA et peines de prison pour dirigeants; période de transition jusqu'à juin 2026.
- Nous sommes en octobre 2026: la transition est donc terminée [A]. Je n'ai pas pu vérifier si l'Autorité fonctionne aujourd'hui ni les règles d'enregistrement (la source ne les précise pas). À faire valider par le juriste local (déjà demandé en v10).
- Points concrets pour NetBuis [A]: consentement explicite à l'inscription (numéro, localisation, requêtes); registre des traitements d'une page; serveurs et sous-traitants (Twilio, SMS, hébergeur) = transferts hors Cameroun, donc à lister et à justifier; durée de conservation des requêtes sans résultat (v11 §2) à fixer. Responsabilité conjointe émetteur/destinataire des données: choisir des prestataires qui signent un contrat de traitement.

## 3. Paiement: une troisième voie à comparer (passerelle unique)
- Parts de marché indicatives [S, ElyonPay, blog commercial d'un vendeur de passerelle: à prendre avec prudence]: MTN MoMo ≈ 60 %, Orange Money ≈ 35 %; plus de 15 millions de comptes actifs.
- Deux voies pour encaisser [S, même source]: contrats directs avec chaque opérateur (délais longs, technique plus lourde) ou passerelle unique (2,5 à 3 %, versement en 24 à 48 h).
- Pour NetBuis [A]: le modèle de packs de crédits (monetisation-appels) évite les micro-paiements sous 50 FCFA. Reste à comparer: contrat direct (moins cher à l'échelle, plus long) contre passerelle (plus rapide à lancer, 2,5 à 3 % de marge en moins). Au pilote, la passerelle peut suffire; décision après le jalon 0, quand le volume réel est connu. À vérifier: les frais de la passerelle s'ajoutent-ils à ceux des opérateurs? Demander un devis écrit.

## 4. Agents: ce que les nouvelles sources confirment (aucun changement de recommandation)
- 2 à 4 agents en parallèle, un worktree git par agent, fusions une par une, vérificateur séparé du producteur, routage de modèle selon le risque, revue humaine obligatoire pour les contradictions logiques que les tests ne voient pas [S, Augment, 2026].
- Chiffre à retenir [S, même source]: les meilleurs modèles dépassent 70 % de réussite sur une tâche à un seul problème, mais moins de 25 % sur des correctifs touchant plusieurs fichiers. Argument de plus pour des tranches verticales petites (v11 §5) et contre une grande flotte.
- Spécifications d'abord (« spec-driven development ») [S, plusieurs guides 2026]: déjà retenu en v10 (specs, AGENTS.md). Rien à ajouter, sinon qu'un pitch Shape Up (rapport-methodes) peut servir de spécification.
- Réponse stable à « 64 agents? 10 testeurs? »: non (v9, v10, rapport-orchestration).

## 5. On a oublié quoi (nouveau)
1. Passer de 20 appareils à une vérification complète du développeur avant que le pilote dépasse 20 téléphones.
2. Les obligations de la loi 2024/017 devenues exigibles depuis juin 2026 (consentement, registre, transferts).
3. Le coût de la passerelle de paiement (2,5 à 3 %) dans le calcul de rentabilité des packs.

## 6. Ce que cette passe n'a pas pu établir
- État réel de l'Autorité de protection des données; règles d'enregistrement; sanctions appliquées.
- Calendrier Android pour le Cameroun (2027+ seulement, sans date).
- Tarifs exacts des contrats directs MTN/Orange; fiabilité des chiffres d'un blog de vendeur de passerelle.

## 7. Décisions pour Jeff
1. Pilote: compte Google à distribution limitée (≤ 20 appareils), ou test fermé Play avec 12 testeurs dès le départ?
2. Demander au juriste local un point écrit sur la loi 2024/017 (Autorité, registre, transferts) avant le pilote, oui ou non?
3. Paiement: passerelle au pilote puis contrat direct plus tard, ou contrat direct dès le départ?

## Sources
- [Android developer verification: rolling out to all developers (Android Developers Blog, mars 2026)](https://android-developers.googleblog.com/2026/03/android-developer-verification-rolling-out-to-all-developers.html)
- [Cameroon's evolving data privacy landscape (Afriwise)](https://www.afriwise.com/resources/cameroons-evolving-data-privacy-landscape)
- [Mobile money Cameroun 2026: comparatif des opérateurs (ElyonPay)](https://elyonpay.com/blog/mobile-money-services-cameroun-guide-operateurs.html)
- [How to run a multi-agent coding workspace (Augment Code, 2026)](https://www.augmentcode.com/guides/how-to-run-a-multi-agent-coding-workspace)


---

<!-- source : audit-expert-v13-autorite-donnees-cout-multi-agents-passerelles-netbuis.md -->

# Audit expert v13 NetBuis: Autorité des données, coût réel du multi-agent, passerelles de paiement (2026-10-05)

Complète v2 à v12 et les rapports orchestration / méthodes de gestion de projet, sans les répéter. Rien n'est tranché: les choix restent à Jeff. [S] = source web, [A] = mon avis. Rien n'a été testé sur le terrain. Passe courte: 11 audits existent déjà, je n'ai cherché que ce qui manquait ou pouvait corriger v12.

## 1. Loi 2024/017: nuance sur l'Autorité (précise v12 §2)
- Un juriste camerounais (Village de la Justice, 11 juillet 2025) écrit que l'Autorité de protection des données « n'a été ni créée ni organisée » et n'est donc pas fonctionnelle [S]. Conséquence qu'il décrit: les autorisations prévues par la loi ne peuvent pas être obtenues, mais les sanctions restent applicables en droit, via les tribunaux. Il recommande une conformité volontaire fondée sur la responsabilité (« accountability »).
- Limite [A]: l'article date de plus d'un an. Je n'ai pas trouvé de source de 2026 confirmant que l'Autorité existe maintenant. v12 disait « pas encore opérationnelle »; c'est cohérent, mais l'état actuel reste à vérifier par le juriste local.
- Action pour NetBuis [A]: ne pas attendre l'Autorité. Appliquer dès le pilote: consentement explicite, registre des traitements d'une page, liste des sous-traitants (Twilio, SMS, hébergeur), durée de conservation. Cela coûte peu et sert de preuve de bonne foi.

## 2. Coût réel du multi-agent (renforce la réponse « pas 64 agents »)
Source: Koenig AI Academy, mai 2026 [S, blog; chiffres à prendre comme ordres de grandeur]:
- Multi-agent: 5 à 30 fois plus de jetons qu'un agent seul pour la même tâche.
- Étude Google 2026 (180 configurations): sur le raisonnement séquentiel, toutes les topologies multi-agents dégradent le résultat de 39 à 70 %.
- Coût relatif par schéma: routeur dynamique ×1,1; pipeline séquentiel ×1,5 à 2; fan-out parallèle ×2 à 3 (mais plus rapide); superviseur ×3 à 5 avec 5 à 15 fois plus de latence; évaluateur-optimiseur ×4 à 8.
- Levier souvent oublié: ne passer à chaque agent que la mémoire utile (récupération sélective) réduit les jetons d'environ 93 % [S].
- Pour NetBuis [A]: le code d'une app de ce type est surtout séquentiel (contrat d'API, puis backend, puis mobile). Le fan-out ne vaut que pour les revues parallèles (sécurité, performance, conformité) et la recherche. Cela confirme l'option A puis B du rapport d'orchestration et écarte C (64 agents). Nuance à noter: la ×3 à ×5 du superviseur est un coût plus élevé que l'estimation « ×3 à ×4 » du rapport; mesurer dès la semaine 1 avant de fixer le budget mensuel.

## 3. Passerelles de paiement locales (complète v12 §3)
- Plusieurs passerelles couvrent MTN et Orange au Cameroun: CamPay, Monetbil, Diool, MMGate, ElyonPay, CamerPay [S, résultats de recherche]. Le comparatif détaillé que j'ai pu ouvrir est un blog d'un vendeur (MMGate) et son contenu chiffré n'était pas lisible: je ne peux donc pas donner de frais fiables.
- [A] Ne pas choisir sur un blog de vendeur. Demander un devis écrit à 3 passerelles avec les mêmes questions: frais totaux (passerelle + opérateur), délai de versement, pièces KYC exigées à NetBuis, remboursements/litiges, contrat de traitement des données.

## 4. Ce qui reste à décider (nouveau ou rappel)
1. Budget jetons mensuel après mesure en semaine 1 (hypothèse prudente: ×3 à ×5).
2. Juriste local: confirmer en une page l'état de l'Autorité et la conformité minimale du pilote.
3. Trois devis de passerelle avant tout choix.

## 5. Non établi
- Existence actuelle de l'Autorité (aucune source de 2026 trouvée).
- Frais réels des passerelles.
- Validité des chiffres de blogs (coûts multi-agents) hors contexte NetBuis.

## Sources
- [Inexistence de l'autorité de protection des données personnelles (Village de la Justice, juillet 2025)](https://www.village-justice.com/articles/%EF%81%9Bcameroun%EF%81%9D-inexistence-autorite-protection-des-donnees-personnelles-les,53952.html)
- [The Real Cost of Multi-Agent Orchestration in 2026 (Koenig AI Academy)](https://academy.kspl.tech/blog/2026-05-31-multi-agent-orchestration-real-cost-2026)
- [API de paiement en ligne au Cameroun 2026 (MMGate, blog vendeur)](https://www.mmgate.org/int/blog/api-paiement-en-ligne-cameroun-2026)
- [Guide paiement mobile Cameroun 2026 (Simiz)](https://simiz.io/blog/guide-paiement-mobile-cameroun-2026)


---

<!-- source : audit-expert-v14-play-api36-passerelles-meta-momo-netbuis.md -->

# Audit expert v14 NetBuis: Play API 36, fiabilité du mobile money, rappels de coûts (2026-10-05)

Passe très courte. Après 13 audits et les rapports orchestration / gestion de projet, la plupart des recherches de cette passe ont confirmé l'existant. Je ne note ici que ce qui est nouveau ou précise un point. Rien n'est tranché: les choix restent à Jeff. [S] = source web, [A] = mon avis. Rien n'a été testé sur le terrain.

## 1. Confirmé, sans changement (voir audits cités)
- Twilio Cameroun: 0,7873 USD/min vers mobile, 0,41 USD/min vers fixe, numéro international dès 1,15 USD/mois [S, page tarifs Twilio, relue aujourd'hui]. Le choix « dialer natif » (decision-finale-appels, v5 §1, v10 §6) reste le bon.
- WhatsApp: depuis le 1er octobre 2026, les réponses de service ne sont gratuites que jusqu'à 1 000 messages par numéro et par mois, puis facturées au tarif « utilité »; les entrées par pub « Click to WhatsApp » et boutons de page gardent 72 h gratuites [S, EngageLab, blog]. Nouveau détail: Meta facture aussi les réponses d'un agent IA Meta à 2 USD par million de jetons [S, même blog]. Conclusion inchangée (v5): lien wa.me au MVP, pas de bot payant avant mesure. Le tarif exact pour le Cameroun reste non publié dans la source.
- Test fermé Play (12 testeurs, 14 jours) pour comptes personnels créés après le 13 novembre 2023 [S, sources tierces]: déjà dans v8 §3 et v12.

## 2. Nouveau: niveau d'API cible Android 16 (API 36) pour Google Play
- Depuis le 31 août 2026, les nouvelles applis et mises à jour soumises à Google Play doivent cibler Android 16 (API 36) ou plus; une extension jusqu'au 1er novembre 2026 peut être demandée dans la Play Console [S, page d'aide officielle Play Console, relue aujourd'hui].
- Conséquence pour NetBuis [A]: toute première soumission doit viser API 36 d'emblée. Cela ne veut pas dire exclure les vieux téléphones: le niveau « cible » est distinct du niveau minimum (minSdk). Garder un minSdk bas pour les Android d'entrée de gamme, mais tester les comportements d'Android 16 (permissions, notifications, tâches en arrière-plan) et le dire dans AGENTS.md pour que les agents n'écrivent pas pour une ancienne API.
- Point à vérifier: si l'application est faite avec un framework multiplateforme, confirmer que la version choisie permet de cibler API 36. Je n'ai pas de source sur ce point.

## 3. Nouveau: fiabilité du mobile money au Cameroun
- Un article de presse locale (Kamer-Android, mars 2026) décrit pour MTN MoMo des interruptions en heures de pointe, des transactions retardées ou bloquées et de longues files aux points de retrait, sans dates ni causes précises [S, qualitatif].
- Camtel prépare un mobile money « Blue Money » prévu en 2026 [S, plusieurs titres de presse]. Je n'ai pas vérifié s'il est lancé.
- Conséquence [A]: l'achat de packs de crédits ne doit pas dépendre d'un seul opérateur ni d'une réponse immédiate. Prévoir: état « paiement en attente » visible, rapprochement automatique par webhook et par relance, crédit ajouté une seule fois (idempotence), et bouton « j'ai payé » avec preuve de transaction pour le support. Offrir les deux opérateurs (MTN, Orange) dès le départ. À inscrire dans la spécification ancrée des paiements (v10).

## 4. Réponse stable aux questions de l'équipe
Agents: pas 64, pas 10 testeurs. Une équipe de 3 à 5 agents plus un relecteur, un agent testeur plus la CI, tests de mutation sur les zones argent/identité (rapport-orchestration, v8, v13). Méthode de gestion: voir rapport-methodes-gestion-projet; aucune source nouvelle n'a changé le classement.

## 5. Décisions pour Jeff
1. Viser API 36 dès la première version, avec un minSdk bas à fixer après le test sur téléphone 2 Go?
2. Paiement: état « en attente » + rapprochement + deux opérateurs dès le pilote, oui ou non?
3. Ouvrir les devis de passerelles (v13 §3) avant de coder le module de paiement?

## 6. Non établi
- Tarif WhatsApp pour le Cameroun; état du lancement de Blue Money; dates et causes des pannes MoMo; compatibilité API 36 de la pile choisie.

## Sources
- [Target API level requirements for Google Play apps (Play Console Help)](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [Programmable Voice Pricing in Cameroon (Twilio)](https://www.twilio.com/en-us/voice/pricing/cm)
- [WhatsApp Business API Pricing 2026: Rates & Oct 1 Changes (EngageLab)](https://www.engagelab.com/blog/whatsapp-business-api-pricing)
- [MTN MoMo: 500 milliards USD en 2025, record éclipsé par les pannes au Cameroun (Kamer-Android)](https://kamer-android.com/2026/03/18/mtn-momo-500-milliards-pannes-cameroun/)
- [Camtel prépare le lancement de Blue Money en 2026 (Investir au Cameroun)](https://www.investiraucameroun.com/gestion-publique/0312-22821-mobile-money-camtel-prepare-le-lancement-de-blue-money-en-2026)
- [Google Play Target API 36 Deadline (PrimeTestLab, blog tiers)](https://primetestlab.com/blog/google-play-target-api-level-2026)


---

<!-- source : audit-expert-v15-frais-mobile-money-cout-multi-agents-netbuis.md -->

# Audit expert v15 NetBuis: frais mobile money 2026 et mécanique du coût multi-agents (2026-10-05)

Passe courte, après 14 audits. Seuls deux points nouveaux ressortent; le reste (loi 2024/017, vérification des développeurs Android, API 36, WhatsApp, Twilio) est déjà couvert en v10, v12, v13, v14 et n'a pas changé dans les résultats de recherche d'aujourd'hui. Rien n'est tranché: les choix restent à Jeff. [S] = source web, [A] = mon avis. Rien testé sur le terrain.

## 1. Nouveau: tarifs mobile money côté utilisateur (impact sur les packs de crédits)
- Depuis le 27 février 2026, MTN a harmonisé ses tarifs sur l'appli MoMo, l'ancienne appli et le USSD *126#: dépôts, paiements marchands et transferts gratuits; retraits à 1 % hors taxes; remise de 25 % pour tous les clients, y compris sans smartphone [S, Projecteur Magazine].
- En novembre 2025, Max It (Orange) et MoMo App (MTN) ont généralisé un retrait à 1 % dès 5 000 FCFA [S, Digital Business Africa; l'extrait lu ne détaille pas l'ancien barème].
- Conséquences pour NetBuis [A]:
  1. Payer un pack de crédits depuis un portefeuille est gratuit pour l'utilisateur; le coût reste chez le commerçant ou chez NetBuis (frais d'agrégateur/marchand), à vérifier dans les devis de passerelles (v13 §3). Ne pas promettre « sans frais » dans l'interface avant ce chiffre.
  2. Le retrait à 1 % touche surtout le commerçant qui encaisse puis retire: lui afficher le net reçu, pas seulement le brut.
  3. Les petits montants (packs à 100 à 500 FCFA) sont viables côté utilisateur; le vrai plancher est le frais de la passerelle par transaction. À simuler dans le modèle de monétisation (monetisation-appels-orange-money) avant de fixer le prix du plus petit pack.
- Non établi: grille exacte Orange pour les paiements marchands, frais d'agrégateur, taxes applicables.

## 2. Nouveau: pourquoi « 3 agents coûtent 10 fois plus » et comment le plafonner
Source: guide Augment sur la composition des coûts multi-agents [S].
- Multi-agent ≈ 15 fois plus de jetons qu'un chat simple (mesure de production Anthropic); l'usage de jetons explique 80 % de la variance de performance sur leurs tests.
- Six multiplicateurs: contexte dupliqué (les schémas d'outils pèsent 60 à 80 % des jetons; 10 000 à 60 000 jetons par tour pour des outils MCP), surcoût d'orchestration (un superviseur léger réduit la consommation d'environ 29,7 %), coordination en maillage (dégradation de 39 à 70 %; une chaîne séquentielle reste à peu près linéaire), relances (une relance au tour 15 repaye tout l'historique), auto-vérification empilée (≈ 2,3 fois le coût), dérive du contexte sur les longs flux.
- Atténuations par ordre d'effet [S]: cache de préfixe (50 à 90 % d'économie sur l'entrée mise en cache), budgets par agent, sorties structurées, contexte minimal transmis, coupe-circuits. Citation clé: « le contrôle des coûts est une décision d'architecture, pas d'achat ».
- Pour NetBuis [A]: confirme l'option B du rapport d'orchestration (3 à 5 agents, topologie étoile ou chaîne, jamais maillage). Ajouts concrets: (a) charger seulement les outils nécessaires à chaque agent; (b) prompts système stables en tête pour profiter du cache; (c) plafond de jetons par tâche et arrêt après 3 blocages (déjà en rapport §2); (d) mesurer « jetons par tâche acceptée » dès la semaine 1.

## 3. Réponse stable aux questions de l'équipe
Pas 64 agents, pas 10 testeurs: 3 à 5 agents, 1 relecteur, 1 testeur + CI. Aucun résultat d'aujourd'hui ne change cela. Méthode de gestion de projet: classement inchangé (rapport-methodes-gestion-projet).

## 4. Décisions pour Jeff
1. Demander à MTN et Orange / aux agrégateurs le frais marchand réel avant de fixer le prix du plus petit pack?
2. Afficher au commerçant le montant net après retrait 1 %?
3. Adopter les quatre règles de coût agents (outils limités, préfixe stable, plafond par tâche, métrique jetons/tâche)?

## Sources
- [MTN Cameroon harmonise ses tarifs et accorde 25 % de remise (Projecteur Magazine)](https://projecteurmagazine.cm/2026/02/28/mobile-money-mtn-cameroon-harmonise-ses-tarifs-et-accorde-25-de-remise-a-tous-ses-clients/)
- [Max It et MoMo App généralisent les retraits à 1 % dès 5 000 F.CFA (Digital Business Africa)](https://www.digitalbusiness.africa/paiement-mobile-au-cameroun-max-it-orange-et-momo-app-mtn-generalisent-les-retraits-a-1-des-5-000-f-cfa/)
- [Multi-Agent Cost Compounding: Why 3 Agents Cost 10x (Augment Code)](https://www.augmentcode.com/guides/multi-agent-cost-compounding)


---

<!-- source : audit-expert-v16-securite-superviseur-cout-data-netbuis.md -->

# Audit expert v16 NetBuis: sécurité du superviseur d'agents, coût des données pour l'utilisateur, rendement décroissant (2026-10-05)

Passe courte après 15 audits. Les critiques UI, UX, backend, sécurité, prix, fonctionnalités, la loi 2024/017, les passerelles de paiement, Play/API 36, les deux rapports (orchestration, gestion de projet) sont déjà dans le projet; les recherches d'aujourd'hui n'ont rien changé à leurs conclusions. Rien n'est tranché: les choix restent à Jeff. [S] = source web, [A] = mon avis. Rien testé sur le terrain.

## 1. Nouveau: le superviseur est le point le plus dangereux d'un dispositif d'agents
Source: synthèse « Multi-Agent in Production in 2026 » (Lanham) [S], qui cite trois études:
- Ajouter des étapes de relais entre agents sans information nouvelle a fait chuter la précision de 90,7 % à 22,5 % (étude MIT citée).
- Une consigne malveillante ou erronée injectée au niveau du hub (superviseur) a fait échouer 100 % du système; injectée sur une feuille (un sous-agent), seulement 9,7 %.
- Variantes multi-agents: 39 à 70 % de moins sur la planification séquentielle (déjà noté dans le rapport d'orchestration).
- Verdict de la source: l'orchestration en étoile (hub et branches) est le schéma qui a survécu en production; la collaboration libre entre pairs a surtout échoué; « l'architecture compte, mais la forme de la tâche compte plus ». Règles: commencer avec un seul agent solide, n'ajouter un spécialiste que s'il apporte un signal nouveau, prévoir environ 15 fois plus de jetons.

Conséquences pour NetBuis [A], en complément de l'option B (3 à 5 agents):
1. Le superviseur lit beaucoup de contenu externe (tickets, retours de revue, sorties d'outils): il doit avoir le moins de droits possible (lecture seule du dépôt, aucun accès aux secrets, aucune exécution de shell). Les sous-agents écrivent; lui seulement planifie et route.
2. Tout message sous-agent vers superviseur passe en format structuré (JSON validé), pas en texte libre, pour limiter la propagation d'une injection.
3. Pas d'étapes de relais inutiles: chaque transmission doit ajouter une information (test, diff, résultat), sinon on supprime l'étape.
4. Les décisions humaines (argent, identité, architecture) ne passent jamais par le superviseur seul: porte d'approbation humaine obligatoire.
Cela s'ajoute à la politique d'agents de v8 (permissions minimales, lockfile, clés hors de portée).

## 2. Nouveau: le coût des données chez l'utilisateur fixe un budget par écran
Chiffres [S, Temo Vision, mis à jour mars 2026]: MTN Yamo 500 FCFA pour 1 Go (30 jours); Orange Pulse 1 100 FCFA pour 2,2 Go; Camtel 2 000 FCFA pour 9 Go. Soit environ 0,5 FCFA par Mo chez MTN au meilleur tarif [A, calcul simple: 500 FCFA / 1 000 Mo]; les offres exactes varient et changent souvent, à revérifier avant publication.
Pour NetBuis [A]:
- Un téléchargement d'appli de 30 Mo coûte environ 15 FCFA de données au meilleur tarif; une recherche qui renvoie 300 Ko, environ 0,15 FCFA. Le coût n'est pas le frein principal; la fiabilité du réseau l'est davantage.
- Fixer un budget par écran (par exemple moins de 100 Ko pour une liste de résultats, sans images lourdes par défaut), mesuré en CI. C'est un critère mesurable pour l'agent testeur et pour la revue de performance, dans la ligne de v6 et v11.
- Mettre en avant dans les écrans: « l'appel n'utilise pas vos données » (appel natif).
Limite: ces prix sont ceux de blogs, pas du régulateur; un revendeur ou une promotion peut les changer.

## 3. Constat: rendement décroissant de ces audits
Les audits v3 à v15 répètent surtout les mêmes conclusions (3 à 5 agents, jalon 0 hors-ligne, forum en v2, loi 2024/017, frais de passerelle à demander). Les points qui bloquent réellement le projet ne sont plus des recherches web mais des décisions et des mesures de terrain: choix de méthode, budget de jetons, quartier pilote, devis des passerelles, juriste local. Proposition [A]: suspendre ou espacer (hebdomadaire) la tâche planifiée jusqu'à ce que Jeff tranche les décisions ci-dessous; chaque passe horaire consomme des jetons pour peu de nouveauté.

## 4. Décisions pour Jeff
1. Adopter les quatre règles du superviseur (droits minimaux, messages structurés, pas de relais inutiles, approbation humaine)?
2. Fixer un budget de données par écran (ex. 100 Ko pour la liste de résultats) mesuré en CI?
3. Espacer la tâche d'audit planifiée (passer d'horaire à hebdomadaire ou la suspendre)?
4. Trancher enfin les décisions ouvertes de v15 §4 et des rapports (méthode, dispositif d'agents, quartier pilote, passerelle).

## Sources
- [Multi-Agent in Production in 2026: What Actually Survived (Lanham)](https://medium.com/@Micheal-Lanham/multi-agent-in-production-in-2026-what-actually-survived-f86de8bb1cd1)
- [Forfaits Internet au Cameroun 2026 (Temo Vision)](https://temovision.com/forfaits-internet-au-cameroun/)
- [AI Coding Agents: An Unaudited Supply Chain Node (Cloud Security Alliance)](https://labs.cloudsecurityalliance.org/research/csa-research-note-ai-agents-software-supply-chain-risk-20260/)


---

<!-- source : audit-expert-v17-garde-fous-agents-mobile-money-concurrence-netbuis.md -->

# Audit expert v17 NetBuis: garde-fous chiffrés pour agents, paysage Mobile Money, concurrence (2026-10-05)

Passe courte, après v16 (même jour). Les critiques UI/UX/backend/sécurité/prix/fonctionnalités et les deux rapports (orchestration, gestion de projet) restent valables; cette passe ajoute seulement trois éléments. [S] = source web (lue via résumé automatique, à revérifier), [A] = mon avis. Rien testé sur le terrain. Les choix restent à Jeff.

## 1. Garde-fous chiffrés pour un petit dispositif d'agents (confirme l'option 3 à 5 agents)
Source: Addy Osmani, « The Code Agent Orchestra » [S]:
- Point optimal: 3 à 5 agents simultanés; « trois agents concentrés valent mieux que cinq dispersés »; le coût croît linéairement avec le nombre d'agents. Donc pas 64 agents, pas 10 agents de test pour NetBuis [A].
- Étapes utiles: approbation du plan avant toute implémentation; hooks qui imposent les tests avant la fin d'une tâche; un relecteur dédié sans outil d'écriture; un worktree git par agent (pas de conflit de fusion); boucle courte « choisir, implémenter, valider, committer, repartir de zéro ».
- Limites suggérées: 8 itérations maximum par agent; budget de jetons par domaine (exemple cité: frontend 180 000, backend 280 000); pause automatique à 85 % du budget; réassigner la tâche après 3 itérations bloquées.
- Le fichier de consignes du dépôt (AGENTS.md) doit être écrit par un humain: la source cite une étude (ETH Zurich) donnant environ +4 % de réussite si humain, -3 % si généré par IA.
- À garder pour l'humain: architecture, décisions « ne pas construire », revue contextualisée.
Complète les règles du superviseur de v16 §1. [A] Reprendre ces limites comme valeurs de départ, à ajuster après le jalon 0.

## 2. Paysage Mobile Money 2026: plus d'acteurs, taxes en hausse
Source: mmgate.org [S]: arrivée de Blue Money (Camtel) et entrée de Wave au Cameroun en plus de MTN MoMo et Orange Money; l'article dit que les taxes augmentent. Il ne donne ni parts de marché, ni dates, ni tarifs. Autre titre trouvé: MTN Cameroon a harmonisé ses tarifs avec 25 % de remise (Projecteur Magazine, 28 février 2026) [S, non lu en détail].
Pour NetBuis [A]: ne pas câbler une seule passerelle; garder une couche d'abstraction de paiement (déjà dans l'architecture) pour pouvoir ajouter Wave ou Blue Money sans refonte; refaire le calcul de marge de monétisation avec les frais et taxes actuels avant tout engagement (voir v15).

## 3. Concurrence: ce que les utilisateurs connaissent déjà
Les listes 2026 de sites et d'applications de vente au Cameroun citent Jumia, KiKUU, Jumli (petites annonces gratuites, vente sans frais) et Kuruba (vente en gros, fondée par d'anciens employés de Jumia) [S, titres seulement]. [A] Ces acteurs vendent en ligne avec livraison; NetBuis se différencie par la recherche de commerçants proches et l'appel direct. Le risque à tester: les gens passent déjà par WhatsApp et Facebook pour cela; la preuve de valeur doit venir du quartier pilote, pas d'une analyse de plus.

## 4. Décisions pour Jeff (inchangées depuis v16, toujours ouvertes)
1. Adopter les règles du superviseur (v16) et les limites chiffrées ci-dessus?
2. Budget de données par écran (v16 §2)?
3. Espacer ou suspendre la tâche d'audit planifiée: les passes répètent maintenant les mêmes conclusions.
4. Trancher méthode de gestion, dispositif d'agents, quartier pilote, passerelle de paiement.

## Sources
- [The Code Agent Orchestra (Addy Osmani)](https://addyosmani.com/blog/code-agent-orchestra/)
- [Blue Money, Wave, MTN, Orange: la guerre du Mobile Money au Cameroun en 2026](https://www.mmgate.org/int/blog/guerre-mobile-money-cameroun-2026-blue-money-wave-mtn-orange)
- [MTN Cameroon harmonise ses tarifs (Projecteur Magazine)](https://projecteurmagazine.cm/2026/02/28/mobile-money-mtn-cameroon-harmonise-ses-tarifs-et-accorde-25-de-remise-a-tous-ses-clients/)
- [Top 10 des sites de vente en ligne au Cameroun en 2026 (Djoolah)](https://djoolah.com/top-10-des-sites-de-vente-en-ligne-au-cameroun/)
- [Kuruba (We Are Tech)](https://www.wearetech.africa/fr/fils/actualites/tech/cameroun-danciens-employes-de-jumia-lancent-kuruba-une-plateforme-electronique-de-vente-en-gros)


---

<!-- source : audit-expert-v18-concurrent-offrir-patrons-orchestration-fraude-netbuis.md -->

# Audit expert v18 NetBuis: concurrent direct (Offrir), 5 patrons d'orchestration, fraude Mobile Money (2026-10-05)

Passe courte, après v17. Elle n'ajoute que ce qui est nouveau; les critiques UI/UX/backend/sécurité/prix/fonctionnalités et les rapports de v1 à v17 restent valables. [S] = source web lue via résumé automatique (à revérifier), [A] = mon avis. Rien testé sur le terrain. Les choix restent à Jeff.

## 1. Concurrent direct trouvé: Offrir
Source: offrirapp.com [S]. Application camerounaise d'achat/vente locale, Android et iOS, français et anglais, 50+ villes. Fonctions: recherche avec filtres, carte locale, messagerie intégrée sans partager son numéro, catégories. Le site affirme 100 000+ utilisateurs actifs, 50 000+ articles vendus, 5 000+ annonces par jour (chiffres non vérifiés, auto-déclarés). Aucun tarif affiché.
[A] Différences avec NetBuis: Offrir cache le numéro (messagerie), NetBuis veut l'appel direct; Offrir est centré sur les annonces de particuliers, NetBuis sur « qui vend ce produit près de moi » chez les commerçants. Critique: si les utilisateurs ont déjà un réflexe d'annonces locales, NetBuis doit prouver que la recherche par produit + appel en un geste est plus rapide. À faire: installer Offrir, chronométrer « trouver un produit et joindre le vendeur », et fixer un objectif NetBuis meilleur (ex.: moins de 3 touches).

## 2. Orchestration: 5 patrons et règle de choix
Source: digitalapplied.com [S]. Fan-out (tâches indépendantes, coût ~N×, risque: échec partiel), Pipeline (étapes enchaînées, risque: une erreur contamine la suite, d'où validation à chaque étape), Debate (décisions à enjeu, ~1,2× à 2,5×, risque: juge biaisé), Supervisor (spécialistes + coordinateur, coût ~N+1, risque: sur-délégation; sous-agents d'un seul niveau, environ 25 tours par défaut), Swarm (50+ tâches vraiment indépendantes, risque: création d'agents hors contrôle). Règle citée: commencer par Supervisor, ajouter du fan-out si les tâches sont parallèles, Swarm seulement avec 50+ tâches indépendantes.
[A] Pour NetBuis: Supervisor + 3 à 5 agents (confirme v17), Pipeline pour la chaîne spec → code → tests → revue, Debate uniquement pour les décisions à risque (paiement, données personnelles). Pas de Swarm: nous n'avons pas 50 tâches indépendantes. Cela répond à la question « 64 agents? »: non.

## 3. Fraude Mobile Money: exigence produit
Source: Investir au Cameroun [S], article de janvier 2021 donc ancien: arnaques par faux avis de retrait, faux agent Orange qui appelle pour « mettre à jour » le compte, faux transfert « envoyé par erreur » à rembourser; contre-mesures d'Orange: biométrie, QR, changement de PIN par l'utilisateur. Cible alors: environ 4,5 millions (Orange) et 5 millions (MTN) de clients.
[A] NetBuis facilite l'appel direct vers des inconnus: c'est exactement le canal de ces arnaques. À ajouter au cahier des charges: avertissement visible « ne donnez jamais votre PIN, aucun agent NetBuis ne vous le demandera », signalement d'un commerçant en un geste, badge de commerçant vérifié, aucun paiement demandé avant rencontre ou livraison dans le parcours. Vérifier les chiffres actuels avant de les citer.

## 4. Décisions pour Jeff
1. Faire le test comparatif Offrir (ci-dessus) avant le jalon 0?
2. Adopter Supervisor + 3 à 5 agents et le Pipeline comme chaîne de base?
3. Intégrer les exigences anti-arnaque au MVP?
4. Toujours ouvert: espacer la tâche d'audit planifiée (les passes se répètent), choisir méthode de gestion, quartier pilote, passerelle de paiement.

## Sources
- [Multi-Agent Orchestration: 5 Patterns That Work in 2026](https://www.digitalapplied.com/blog/multi-agent-orchestration-5-patterns-that-work)
- [Offrir - Acheter et Vendre Localement au Cameroun](https://www.offrirapp.com/)
- [Orange Cameroun renforce la sécurité Mobile Money (Investir au Cameroun)](https://www.investiraucameroun.com/finance/2001-15846-suite-aux-plaintes-darnaques-loperateur-orange-cameroun-renforce-la-securite-des-transactions-mobile-money)


---

<!-- source : audit-expert-v19-sdd-garde-fous-agents-loi-donnees-netbuis.md -->

# Audit expert v19 NetBuis: développement par spécifications, garde-fous des agents, chiffres de marché à dater (2026-10-05)

Passe courte après v18. Elle n'ajoute que du nouveau; les critiques (UI/UX, frontend, backend, sécurité, prix, fonctionnalités) et les rapports d'orchestration et de gestion de projet restent valables. [S] = source web lue via résumé automatique (à revérifier), [A] = mon avis. Rien testé sur le terrain. Les choix restent à Jeff.

## 1. Méthode de travail avec les agents: développement par spécifications (SDD)
Source: blog Allegro, juin 2026 [S]. Quatre phases: spécifier, planifier, implémenter, valider. La spécification (le « plan de l'ouvrage ») reste séparée du plan d'exécution, qui change souvent. Elle doit être équilibrée: assez précise pour que l'agent n'invente pas, pas au point de recopier le code. Le niveau de contrôle suit le risque: faible risque, on accélère; finance, spécification complète. Tests (TDD/BDD) comme critères d'acceptation et boucle de retour pour l'agent. Relecture dans une session neuve, avec un autre agent. Mise à jour de la spécification après chaque changement. Limites reconnues: fenêtre de contexte, hallucinations; la méthode ne vaut que pour les problèmes complexes. Chiffres cités par la source: 75 % du nouveau code de Google serait généré par IA (Business Insider, avril 2026); une panne AWS de 13 heures imputée à un agent autonome (décembre 2025). Non vérifiés par moi.
[A] Pour NetBuis: les 31 documents du projet sont déjà une base de spécification. Il manque la mise en forme exécutable: contrat d'API (OpenAPI), critères d'acceptation par fonction, et un niveau de risque par module (paiement et données personnelles = spécification complète et humain obligatoire; forum et écrans de lecture = allégé). C'est le complément le plus utile aux options d'orchestration déjà proposées (superviseur + 3 à 5 agents).

## 2. Garde-fous des agents de code: un risque nouveau pour l'équipe d'agents
Source: Cloud Security Alliance, note publiée le 11 juillet 2026 [S]. Les filtres qui vérifient les commandes shell d'un agent lisent le texte écrit, alors que bash exécute après expansion de variables et substitutions. 10 agents sur 11 très utilisés ont été contournés par au moins une des cinq techniques; seul Continue a résisté aux 21 cas testés. Mesures: désactiver l'exécution automatique, rediriger $HOME vers un dossier restreint, auditer les fichiers de configuration d'agent, préférer une évaluation consciente du shell.
Source complémentaire: Infosecurity Magazine [S], projet « Vibe Security Radar » (Georgia Tech): 74 vulnérabilités (CVE) publiques attribuées à des outils de codage IA confirmées début 2026 (6 en janvier, 15 en février, 35 en mars); les chercheurs estiment 400 à 700 cas non détectés dans l'open source. Méthode par traces (signatures d'outils), donc sous-estimation probable.
[A] Pour NetBuis: ne jamais donner à un agent d'accès aux clés Mobile Money, Twilio ou à la base de production; exécution dans un conteneur jetable sans secrets; fusion du code refusée sans revue humaine sur les dossiers paiement/auth; analyse de sécurité automatique dans la CI. Ajoute un argument contre l'exécution automatique sans bac à sable, que les passes v16 et v17 traitaient surtout côté superviseur.

## 3. Loi 2024/017: échéance de juin 2026 confirmée par une source de décembre 2025
Source: CIOMAG, 23 décembre 2025 [S]. Période de transition de 18 mois, fin le 23 juin 2026; contrôle par l'APDP; obligations pour une appli: consentement explicite, politique de confidentialité claire, registre des traitements, analyse d'impact, procédure en cas de fuite, protection dès la conception, délégué à la protection des données, cartographie des données. Sanctions citées: amendes de plusieurs dizaines de millions de FCFA, pourcentage du chiffre d'affaires pour les cas graves, interdiction temporaire de traitement, responsabilité pénale possible des dirigeants.
[A] Cela confirme v12 et v13 (transition terminée, Autorité d'état incertain). Nouveauté: la liste des obligations est plus complète que ce que j'avais retenu; ajouter au cahier des charges un délégué à la protection des données (même une personne désignée) et une analyse d'impact pour la géolocalisation et les requêtes. Avis du juriste local toujours nécessaire.

## 4. Chiffres de marché: attention aux sources périmées
Une étude citée largement (prix moyen d'un smartphone 27 000 FCFA, internet à 25 %) date de mars 2018 (CIOMAG/Jumia) [S]; elle ne doit pas servir à dimensionner le MVP. Un article de Investir au Cameroun sur le haut débit mobile (39 % de pénétration) est apparu dans la recherche mais je ne l'ai pas lu, et je n'ai pas pu lire les prix de forfaits data 2026 (page en erreur). À faire: relever à la main les prix réels de forfaits MTN et Orange et les téléphones les plus vendus avant de fixer le poids maximal de l'appli et le budget data par session.

## 5. Gestion de projet avec agents: non établi cette fois
J'ai trouvé des pistes (Scrum.org « AI-augmented Scrum », guide Augment Code sur la planification de sprint avec agents, engineeringexec.tech « AI-Scrum ») mais la page Scrum.org est revenue vide et je n'ai pas lu les autres. Je ne conclus donc rien de nouveau; la recommandation de v4/v5 (Scrumban + Lean si l'équipe humaine < 4, Shape Up pour seniors autonomes) reste inchangée. À lire lors d'une passe suivante si Jeff veut approfondir.

## 6. Décisions pour Jeff
1. Adopter le développement par spécifications (OpenAPI + critères d'acceptation + niveau de risque par module) comme cadre de travail des agents?
2. Imposer bac à sable sans secrets et revue humaine sur paiement/auth, oui ou non?
3. Désigner un délégué à la protection des données et faire l'analyse d'impact avant le pilote?
4. Toujours ouvert: espacer la tâche planifiée (19 passes, les nouveautés deviennent rares), choisir la méthode de gestion, le quartier pilote et la passerelle de paiement.

## Sources
- [Spec-Driven Development (SDD): best practices (Allegro, juin 2026)](https://blog.allegro.tech/2026/06/spec-driven-development-best-practices.html)
- [GuardFall: Shell Injection Defeats AI Coding Agent Guardrails (Cloud Security Alliance)](https://labs.cloudsecurityalliance.org/research/csa-research-note-guardfall-ai-coding-agent-shell-injection/)
- [Researchers Sound the Alarm on Vulnerabilities in AI-Generated Code (Infosecurity Magazine)](https://www.infosecurity-magazine.com/news/ai-generated-code-vulnerabilities/)
- [Protection des données au Cameroun: la course contre la montre avant juin 2026 (CIOMAG)](https://cio-mag.com/protection-des-donnees-au-cameroun-la-course-contre-la-montre-avant-juin-2026/)
- [Le prix moyen d'un smartphone au Cameroun est de 27 000 FCFA (CIOMAG, 2018)](https://cio-mag.com/le-prix-moyen-dun-smartphone-au-cameroun-est-de-27-000-fcfa/)


---

<!-- source : audit-expert-v20-prix-data-scrum-agents-orchestration-netbuis.md -->

# Audit expert v20 NetBuis: prix data réels, Scrum avec agents, ce qui survit en production (2026-10-05)

Passe courte après v19. Elle ne comble que les trous que v19 avait signalés (prix data, gestion de projet avec agents) et recoupe l'orchestration. Toutes les critiques précédentes (UI/UX, frontend, backend, sécurité, prix, fonctionnalités) restent valables. [S] = source web lue via résumé automatique (à revérifier), [A] = mon avis. Rien testé sur le terrain. Les choix restent à Jeff.

## 1. Prix data réels au Cameroun (comble le point 4 de v19)
Source: Temo Vision, article mis à jour le 7 mars 2026 [S] (prix de l'opérateur à revérifier sur les sites MTN/Orange):
- MTN Yamo: 500 FCFA = 1 Go pour 30 jours; 1 150 FCFA = 2,5 Go pour 30 jours.
- Orange Pulse: 1 100 FCFA = 2,2 Go; 2 100 FCFA = 4,5 Go.
- Illimité Orange: 25 000 FCFA/30 jours, débit plafonné 2 à 5 Mbit/s (hors cible du MVP).
[A] Ordre de grandeur: environ 0,5 FCFA le Mo sur les petits forfaits. Une session de recherche de 100 Ko coûterait donc environ 0,05 FCFA; une appli de 30 Mo à installer coûte environ 15 FCFA, une mise à jour de 10 Mo environ 5 FCFA. Conclusion: le coût data n'est pas le principal frein; la taille de l'appli l'est surtout pour les téléphones à peu de stockage, et la fiabilité en réseau instable. Garder le budget de poids (v16) mais ne pas le surdimensionner. À confirmer: prix des forfaits sociaux (WhatsApp seul) qui peuvent être plus pertinents pour le pilote.

## 2. Gestion de projet avec agents: Scrum « augmenté » (comble le point 5 de v19)
Source: Agile Leadership Day India, cadre « AI-augmented Scrum », mars 2026 [S]. Idées retenues:
- Le Product Owner reste humain (le « pourquoi » et le « quoi »); les développeurs deviennent « gestionnaires d'agents » et relecteurs; le Scrum Master surveille journaux, limites d'API et obstacles.
- Planification: séparer tâches créatives humaines et tâches automatisables; écrire le prompt technique dans la « Definition of Ready »; planifier un budget de jetons comme des heures humaines.
- Mêlée quotidienne asynchrone: suivi des échecs de tests et des scores de confiance par journaux.
- Revue: mesurer le « retour sur investissement des agents » (coût en jetons contre heures économisées). Rétrospective: déboguer les flux d'agents, améliorer la bibliothèque de prompts.
- Abandonner les points d'effort pour les agents; la validation humaine est le goulot (des agents 24 h/24 dépassent la capacité de relecture).
Autres pistes trouvées mais non lues: Augment Code (planification de sprint avec agents), Spinach.ai (« AI Scrum Master »), formation Scrum « AI-augmented » du 6-7 octobre 2026.
[A] Cohérent avec v4/v5 (Scrumban + Lean pour petite équipe). Ajout utile: limiter le travail en cours par la capacité de relecture humaine de Jeff, pas par le nombre d'agents. Si l'équipe est Jeff seul + agents, c'est la contrainte dominante.

## 3. Orchestration: ce qui a survécu en production en 2026
Source: Medium, « Multi-Agent in Production in 2026: What Actually Survived » [S], qui cite d'autres études:
- Le patron dominant est l'orchestration centrale (un routeur + sous-agents spécialisés). Le système de recherche d'Anthropic: +90,2 % face à un agent seul (cité). La collaboration libre entre pairs survit seulement dans des niches très instrumentées; les systèmes livrés ajoutent portes de phase, contrats d'artefacts ou arbitre final.
- Échecs: une étude MIT citée: ajouter des étapes de relais sans nouveau signal a fait chuter la précision de 90,7 % à 22,5 %. Une autre: l'injection d'une fausse information au centre (hub) provoque 100 % de défaillance du système contre 9,7 % depuis une feuille.
- Coût: environ 15 fois plus de jetons qu'une conversation simple (avertissement d'Anthropic, cité).
- Consensus 2026: commencer par un agent fort seul, n'orchestrer que si la décomposition apporte de la valeur.
Autres sources repérées, non lues: Augment Code « Swarm vs Supervisor », arXiv 2607.02807 (SwarmResearch), digitalapplied « 5 patterns », enquête MDPI sur les frameworks.
[A] Réponse à « 64 agents? 10 agents de test? »: rien dans ces sources ne soutient un grand nombre d'agents. Pour NetBuis, un superviseur + 3 à 5 agents (v16, v17, v19), chacun avec un contrat d'artefact (OpenAPI, tests) et une porte humaine sur paiement/auth, reste l'option la mieux étayée. Le point sur l'injection au centre renforce la règle: le superviseur ne doit pas lire aveuglément des textes non fiables (pages web, retours d'agents) sans validation.

## 4. Ce qui reste non établi
- Pages Temo Vision lues une seule (autres échecs de lecture: iambeezy « too many redirects »); prix des forfaits sociaux et du matériel populaire non relevés.
- Aucune étude trouvée sur le nombre optimal d'agents de test; à chercher si Jeff le demande.

## 5. Décisions pour Jeff
1. Adopter la limite de travail en cours basée sur la capacité de relecture humaine?
2. Garder superviseur + 3 à 5 agents comme point de départ (aucune source ne justifie 64)?
3. Toujours ouvert depuis v19: espacer la tâche planifiée (20 passes, nouveautés rares), méthode de gestion, quartier pilote, passerelle de paiement, délégué à la protection des données.

## Sources
- [Prix forfaits Cameroun 2026 (Temo Vision, mars 2026)](https://temovision.com/forfaits-internet-au-cameroun/)
- [AI-augmented Scrum framework (Agile Leadership Day India)](https://agileleadershipdayindia.org/blogs/ai-augmented-scrum-framework/ai-augmented-scrum-framework.html)
- [Multi-Agent in Production in 2026: What Actually Survived (Medium)](https://medium.com/@Micheal-Lanham/multi-agent-in-production-in-2026-what-actually-survived-f86de8bb1cd1)
- [AI Sprint Planning With Agents (Augment Code)](https://www.augmentcode.com/guides/ai-sprint-planning-with-agents)
- [Swarm vs. Supervisor (Augment Code)](https://www.augmentcode.com/guides/swarm-vs-supervisor)


---

<!-- source : audit-expert-v21-nombre-agents-shape-up-paiement-netbuis.md -->

# Audit expert v21 NetBuis: nombre d'agents, Shape Up, guides paiement (2026-10-05)

Passe courte et honnête: après 20 audits, peu de nouveautés. [S] = source web lue via résumé automatique (à revérifier), [A] = mon avis. Rien testé sur le terrain. Les critiques précédentes (UI/UX, frontend, backend, sécurité, mémoire, prix, fonctionnalités) restent valables; aucune nouvelle critique majeure n'a émergé.

## 1. « Combien d'agents? 64? 10 agents de test? » (trou signalé en v20)
- LangChain, « Agentic Engineering » [S]: l'étude de pilote ne donne AUCUN nombre optimal d'agents, ne définit que deux rôles (agents ouvriers + un agent chef), ne prévoit pas d'agents de test ou de revue dédiés, et ne traite pas les modes d'échec. Les chiffres cités (réduction de 93 % du temps de débogage, 65 % de compression du développement) sont des résultats de pilote d'un éditeur, pas une preuve générale.
- Recherche web générale: aucune étude sérieuse trouvée donnant un nombre optimal d'agents de test. Les résultats sont surtout des comparatifs d'outils de codage.
- [A] Conclusion inchangée et renforcée: aucune source ne justifie 64 agents ni 10 agents de test. Point de départ: 1 superviseur + 3 à 5 agents (spécification/API, backend, mobile, tests, revue sécurité), avec tests automatisés exécutés par des outils (pas par des « agents ») et validation humaine sur paiement/authentification. N'ajouter un agent que si une mesure (taux d'échecs, délai) le justifie.

## 2. Shape Up comme option de méthode
Source: softengbook.org [S].
- Cycles de 6 semaines, « appétit » fixé à l'avance (temps fixe, périmètre variable), pitchs choisis à la « table de paris », 2 semaines de repos (dette technique, bugs), équipes de 1 designer + 1 à 2 développeurs, peu de cérémonies.
- Limites: demande un « façonnage » par une personne expérimentée; pas de backlog; échelle incertaine.
- [A] Ajustement à NetBuis: temps fixe/périmètre variable convient à un budget limité et protège contre l'élargissement du périmètre (ex. forum, paiement). Mais le façonnage des pitchs repose sur Jeff, déjà goulot de relecture (v20). Comparaison à garder dans la liste de choix: Scrumban (v4/v5), Scrum augmenté (v20), Shape Up (v21). Ne pas trancher à la place de Jeff.

## 3. Paiement mobile Cameroun: guides trouvés
Recherche lancée; pages repérées (simiz.io guide 2026, ElyonPay, CamerPay, Krexora, DusuPay, BeOnWeb), mais la lecture de simiz.io a échoué (robots.txt). Aucun frais ni règle nouveau vérifié dans cette passe. Les décisions antérieures (Campay, recherches API/USSD) restent la base; revérifier les frais directement chez les opérateurs avant tout engagement.

## 4. Non établi
- Frais et conditions marchand à jour (pages non lues).
- Études quantifiées sur nombre d'agents de test: introuvables.

## 5. Décisions pour Jeff
1. Valider la règle « on n'ajoute un agent que sur mesure », départ à 1 + 3 à 5.
2. Choisir la méthode: Scrumban, Scrum augmenté ou Shape Up.
3. Toujours ouvert: espacer cette tâche planifiée (21 passes, quasi plus de nouveautés; suggestion: mensuelle), quartier pilote, passerelle de paiement, délégué à la protection des données.

## Sources
- [Agentic Engineering (LangChain)](https://www.langchain.com/blog/agentic-engineering-redefining-software-engineering)
- [Shape Up: A Possible Alternative to Scrum? (softengbook)](https://softengbook.org/articles/shapeup)
- [Guide paiement mobile Cameroun 2026 (simiz.io), non lu](https://simiz.io/blog/guide-paiement-mobile-cameroun-2026)
- [Paiement mobile au Cameroun, guide technique (Krexora), non lu](https://krexora.com/blog/paiement-mobile-cameroun-guide-technique-2026/)
- [2026 Agentic Coding Trends Report (Anthropic), non lu](https://resources.anthropic.com/hubfs/2026%20Agentic%20Coding%20Trends%20Report.pdf?hsLang=en)


---

<!-- source : audit-expert-v22-goulot-revue-verification-play-netbuis.md -->

# Audit expert v22 NetBuis (2026-10-06)

Passe courte. [S] = source web lue via résumé automatique, à revérifier; [A] = mon avis. Rien testé sur le terrain. Les critiques UI/UX, frontend, backend, sécurité, mémoire, prix et fonctionnalités des audits v3 à v21 restent valables; aucune nouvelle critique majeure n'a émergé.

## 1. Orchestration d'agents: le vrai goulot est la relecture, pas le nombre
- Addy Osmani [S]: « 3 à 5 coéquipiers = point optimal », le coût en jetons croît linéairement, 3 agents ciblés valent mieux que 5 dispersés. Le goulot n'est plus la génération mais la vérification. Barrières par priorité: approbation du plan avant code, hooks (tests/lint à la fin de chaque tâche), AGENTS.md/CLAUDE.md, un agent relecteur en lecture seule sur chaque tâche. Une fonctionnalité complète coûte environ 220 000 jetons par sous-agents (chiffre d'un auteur, non généralisable). Routage multi-modèles (modèle moins cher pour planifier) réduit le coût.
- digital-opua [S]: plafond pratique de 4 à 8 worktrees parallèles par développeur (mi-2026); « la bande passante humaine ne se parallélise pas ». Il faut propriété de fichiers disjointe par agent, un worktree git par agent, branches de base documentées, build/typecheck avant relecture humaine.
- [A] Cela confirme v20/v21: démarrer à 1 superviseur + 3 à 5 agents; 64 agents ou 10 agents de test ne sont justifiés par aucune source. Pour Jeff seul relecteur, 2 à 3 flux parallèles maximum au début. Tests = outils automatisés (CI), pas des agents.

## 2. Paiement mobile Cameroun
- njokalab [S]: voie agrégateur (Campay, CinetPay, Notch Pay, Monetbil), intégration typique de 1 à 2 jours; voie directe = comptes marchands séparés chez MTN et Orange. Pièges: ne jamais marquer « payé » sur la seule redirection; jusqu'à 3 % des invites USSD en retard; sondage si pas de webhook après 90 s; idempotence obligatoire; vérification de signature HMAC SHA-256 du webhook. Frais non indiqués.
- [A] Le plan (bloc 10: webhook unique, rapprochement, 90 s) est conforme. Ajouter explicitement la vérification de signature du webhook si CamPay la propose (à confirmer dans leur documentation) et un plan B (Notch Pay/CinetPay) via la couche PaymentProvider déjà prévue. Frais réels toujours à demander à CamPay.

## 3. Google Play: point nouveau pour le plan
primetestlab [S]: test fermé 12 testeurs/14 jours (déjà au plan, bloc 20); cible API 36 pour les nouvelles apps depuis le 31/08/2026 (déjà au plan); NOUVEAU: vérification d'identité des développeurs et enregistrement du paquet à partir du 30/09/2026, appliqués d'abord au Brésil, Indonésie, Singapour, Thaïlande. Le Cameroun n'y figure pas d'après cette source, mais l'extension mondiale est probable.
- [A] Ajouter au bloc 0/20: enregistrer le paquet `cm.netbuis.app` et faire vérifier l'identité du compte dès l'ouverture de la console; revérifier la date d'extension au Cameroun dans la console Play avant le 20/10/26.

## 4. Non établi
Frais marchands à jour; études chiffrées sur le nombre d'agents de test; date d'application de la vérification développeur au Cameroun.

## 5. Décisions pour Jeff (inchangées)
Méthode (Scrumban, Scrum augmenté ou Shape Up); règle « 1 + 3 à 5 agents, ajout sur mesure »; passerelle de paiement; quartier pilote; délégué données. Suggestion renouvelée: passer cette tâche planifiée en mensuelle (22 passes, peu de nouveautés).

## Sources
- [The Code Agent Orchestra (Addy Osmani)](https://addyosmani.com/blog/code-agent-orchestra/)
- [Multi-Agent Orchestration: Review Is the Bottleneck (digital opua)](https://digital-opua.ch/en/blog/agent-orchestration-patterns)
- [Intégrer MTN MoMo et Orange Money au Cameroun (njokalab)](https://www.njokalab.com/insights/how-to-integrate-mtn-momo-orange-money-cameroon-api/)
- [Google Play Policy Updates 2026 (primetestlab)](https://primetestlab.com/blog/google-play-policy-updates-2026)


---

<!-- source : audit-expert-v23-verification-play-2027-frais-patrons-netbuis.md -->

# Audit expert v23 NetBuis (2026-10-06, passe 2 du jour)

Passe courte. [S] = source web lue via résumé automatique, à revérifier; [A] = mon avis. Rien testé sur le terrain. Les critiques UI/UX, frontend, backend, sécurité, mémoire, prix et fonctionnalités des audits v3 à v22 restent valables; aucune nouvelle critique majeure n'a émergé.

## 1. Google Play: précision sur la vérification des développeurs (corrige v22)
- Blog Android Developers (juin 2026) [S]: l'enregistrement obligatoire des apps au 30/09/2026 vaut pour le Brésil, l'Indonésie, Singapour et la Thaïlande (Google Play + 6 autres boutiques). Google dit que 99 % des apps Play sont enregistrées automatiquement; vérifier l'état sur la page d'accueil de la Play Console.
- NOUVEAU [S]: extension mondiale prévue en 2027 sur tous les appareils Android certifiés. Le sideload reste possible (ADB ou parcours avancé), et un compte « distribution limitée » (20 appareils, sans pièce d'identité ni frais) existe pour étudiants/amateurs.
- [A] Le Cameroun est donc concerné en 2027, pas maintenant. Action: créer le compte développeur tôt, faire vérifier l'identité, enregistrer le paquet `cm.netbuis.app`. Pour le pilote de quartier, l'APK en sideload reste un plan B valable, mais l'APK hors Play perdra en confort en 2027: ne pas en faire le canal principal.

## 2. Frais mobile money (contexte de prix pour les utilisateurs)
momocalc [S]: MTN transfert 0,5 % plafonné à 500 FCFA; Orange gratuit jusqu'à 5 000 FCFA puis 1 % à frais fixes; taxe 0,2 % sur envoi et retrait depuis 2022 + 4 FCFA fixes en 2025; paiements marchands exemptés de la taxe. Retrait de 10 000 FCFA ≈ 200 (MTN) ou 150 (Orange) avant taxe.
- [A] Si NetBuis facture un petit montant (ex. mise en avant d'un commerçant), les frais de retrait pèsent beaucoup sur les petits montants: éviter les paiements sous ~500 FCFA, préférer des forfaits hebdomadaires/mensuels. Frais de passerelle CamPay: toujours non publiés dans ce que j'ai lu; à demander.

## 3. Orchestration: cinq patrons (digitalapplied) [S]
Fan-out (≈N× coût), pipeline (cascade d'erreurs), débat (≈2,5×, décisions à fort enjeu seulement), superviseur (« défaut de production 2026 », coût ≈(N+1)×, sous-agents Claude Code d'un seul niveau), essaim (utile seulement à partir de ~50 sous-tâches indépendantes). Recommandation de la source: commencer par superviseur, ajouter du fan-out si tâches réellement parallèles.
- [A] Confirme v22: 64 agents = essaim, sans objet pour une app de cette taille. Pour NetBuis: superviseur + 3 à 5 spécialistes (mobile, backend, paiement/sécurité, relecteur lecture seule); débat réservé à 2 ou 3 décisions (choix passerelle, modèle de données); les tests sont de la CI, pas des agents.

## 4. Non établi
Frais marchands CamPay; date exacte d'application au Cameroun en 2027; études chiffrées sur le nombre d'agents de test.

## 5. Décisions pour Jeff (inchangées)
Méthode (Scrumban, Scrum augmenté ou Shape Up); règle « 1 + 3 à 5 agents »; passerelle de paiement; quartier pilote; délégué données. Les 23 passes montrent des rendements décroissants: passer cette tâche en hebdomadaire ou mensuelle.

## Sources
- [Android developer verification (Android Developers Blog)](https://android-developers.googleblog.com/2026/06/android-developer-verification.html)
- [Frais Mobile Money Cameroun 2026 (momocalc)](https://momocalc.com/fr/cameroon)
- [Multi-Agent Orchestration: 5 Patterns (digitalapplied)](https://www.digitalapplied.com/blog/multi-agent-orchestration-5-patterns-that-work)


---

<!-- source : audit-expert-v24-android17-conformite-antic-agents-netbuis.md -->

# Audit expert v24 NetBuis (2026-10-06, passe 3 du jour)

Passe courte, centrée sur ce qui est NOUVEAU par rapport à v23. [S] = source web lue via résumé automatique, à revérifier; [A] = mon avis. Rien testé sur le terrain. Les critiques UI/UX, frontend, backend, sécurité, mémoire, prix et fonctionnalités des audits v3 à v23 restent valables; aucune nouvelle critique majeure ne les remet en cause.

## 1. Android 17 (API 37): deux points qui touchent NetBuis [S]
- Lecture des SMS: le délai d'accès aux codes OTP passe à 3 heures pour les apps qui les lisent. Google recommande l'API SMS Retriever. [A] Si NetBuis confirme un paiement ou un numéro par SMS/OTP, ne jamais lire la boîte SMS: utiliser SMS Retriever, ou mieux, la confirmation USSD/push côté opérateur déjà étudiée dans les addenda paiement.
- Permission `ACCESS_LOCAL_NETWORK` pour la découverte d'appareils sur le réseau local: sans objet pour NetBuis (aucune découverte locale). À vérifier qu'aucune bibliothèque tierce n'en dépend.
- Calendrier: Google Play impose le ciblage API 37 en août 2027 (donc pas d'urgence). Cibler API 36 maintenant, prévoir API 37 au premier semestre 2027. Les téléphones d'entrée de gamme resteront majoritairement sur Android 12 à 14: tester surtout là.

## 2. Conformité locale: point à ne pas oublier [S, faible confiance]
Une décision du ministre des Postes et Télécommunications du 4 avril 2025 (plateforme nationale d'agrégation NECAP) exigerait, pour les plateformes numériques publiques (dont e-commerce et services financiers), l'approbation d'une agence et un certificat de conformité de l'ANTIC, avec un délai de trois mois. Le résumé lu ne donne ni sanctions ni dates 2026.
- [A] À ne pas considérer comme établi: c'est un blog de cabinet, résumé automatiquement. Action concrète: poser la question par écrit à l'ANTIC (ou à un avocat local) avant le lancement public: « une marketplace d'annuaire de commerçants avec appel et paiement est-elle soumise à certificat de conformité? ». Cela complète la loi 2024/017 sur les données personnelles (déjà traitée en v19) et le choix du délégué données.

## 3. Orchestration d'agents: confirmation par une nouvelle source [S]
Addy Osmani (« The Code Agent Orchestra »): 3 à 5 coéquipiers = point optimal; coûts en tokens à peu près linéaires avec la taille d'équipe; trois garde-fous: approbation du plan avant de coder, hooks automatiques (tests, lint), fichier AGENTS.md rédigé par un humain (un AGENTS.md généré par IA réduirait le taux de succès d'environ 3 %); règle « 3 itérations bloquées = arrêter et réassigner »; le goulot est passé de la génération à la vérification; une spécification vague multipliée par 50 agents donne du chaos.
- [A] Cela renforce la règle « 1 superviseur + 3 à 5 agents » (v21 à v23): 64 agents n'est pas justifiable pour NetBuis. Ajouts utiles: (1) AGENTS.md écrit par Jeff, court; (2) validation humaine du plan avant tout code touchant paiement/appel; (3) plafond de 3 essais par tâche; (4) agents de test = CI + un relecteur en lecture seule, pas dix agents; (5) router les tâches simples (textes, traductions, tests unitaires) vers un modèle moins cher.

## 4. Non établi
Frais marchands CamPay/Monetbil/Diool (la page comparative n'a pas livré de chiffres via le résumé: à demander directement); portée réelle de l'obligation ANTIC; date d'application Play 2027 au Cameroun.

## 5. Décisions pour Jeff (inchangées)
Méthode (Scrumban, Scrum augmenté ou Shape Up); règle « 1 + 3 à 5 agents »; passerelle de paiement; quartier pilote; délégué données; nouvelle question à trancher: qui interroge l'ANTIC.
Rappel: les rendements sont décroissants (24 passes). Passer cette tâche en hebdomadaire ou mensuelle, et commencer à construire.

## Sources
- [The Code Agent Orchestra (Addy Osmani)](https://addyosmani.com/blog/code-agent-orchestra/)
- [Android 17 migration guide (CODERCOPS)](https://blog.codercops.com/blog/android-17-developer-migration-guide-2026)
- [Behavior changes: Android 17 (developer.android.com)](https://developer.android.com/about/versions/17/behavior-changes-17)
- [New Compliance Rules for Digital Platforms in Cameroon (4M Legal Tax)](https://4mlegaltax.com/digital-platforms-in-cameroon/)
- [API de paiement en ligne au Cameroun 2026 (MMGate)](https://www.mmgate.org/int/blog/api-paiement-en-ligne-cameroun-2026)


---

<!-- source : audit-expert-v25-wave-camtel-orchestrateurs-methode-solo-netbuis.md -->

# Audit expert v25 NetBuis (2026-10-06, passe 4 du jour)

Passe courte: uniquement ce qui est NOUVEAU par rapport à v24. [S] = source web lue via résumé automatique, à revérifier; [A] = mon avis. Rien testé sur le terrain. Les critiques UI/UX, frontend, backend, sécurité, mémoire, prix et fonctionnalités des audits v3 à v24 restent valables.

## 1. Paiement: le marché bouge (nouveau) [S]
- **Wave est au Cameroun depuis plus d'un an** (partenariat avec Commercial Bank Cameroon). Tarifs annoncés: dépôt gratuit chez les agents, retrait gratuit, transfert P2P 1 %, factures (eau, électricité, câble) sans frais. Cible déclarée: petits commerçants et femmes de l'informel, c'est-à-dire exactement les commerçants de NetBuis. Interview de juillet 2026; aucune information sur une API marchande.
- **Camtel lance « Blue Money »** (annoncé décembre 2025, service prévu en 2026, capital 500 M FCFA). MTN + Orange = plus de 80 % des transactions électroniques; volume mobile money passé de 8,8 à 22,1 mille milliards FCFA entre 2019 et 2023.
- Mowali (interopérabilité MTN/Orange, 2018) existe déjà: un transfert entre les deux réseaux est possible côté opérateurs.
- [A] Conséquences pour NetBuis: (1) ne pas coder en dur « Orange Money + MTN »: l'abstraction « passerelle de paiement » déjà recommandée doit pouvoir accueillir Wave et Blue Money plus tard; (2) beaucoup de commerçants auront deux ou trois portefeuilles: l'annuaire doit afficher les moyens de paiement acceptés par commerçant (filtre utile pour l'acheteur); (3) la pression sur les frais baisse: ne pas fonder le modèle économique sur une marge de paiement; la monétisation par abonnement/mise en avant du commerçant reste plus robuste; (4) Wave n'a pas d'API marchande confirmée: ne pas bâtir de plan dessus avant vérification directe.

## 2. Orchestration d'agents: précisions nouvelles [S]
- Cinq patrons (Fan-Out, Pipeline, Debate, Supervisor, Swarm). Pour NetBuis, seul Supervisor (1 coordinateur + N sous-agents, un seul niveau de profondeur) et un peu de Pipeline (spec, code, relecture, test) sont justifiés. Coût du Supervisor: environ (N+1) fois un agent seul; plafond conseillé d'environ 25 tours par sous-agent. Swarm (50 à 300 agents) ne vaut que pour 50+ tâches indépendantes: NetBuis n'en a pas. Debate (≈1,2 à 2,5 fois le coût) seulement pour les décisions à risque (paiement, appel).
- Outils d'orchestration open source: presque tous reposent sur un **worktree git par agent**. Piège: les worktrees règlent les conflits de fichiers mais pas les collisions de ports ni de base de données (Emdash injecte une variable $PORT pour cela). Claude Squad est sous licence AGPL-3.0 (à éviter si on l'intègre à un produit); Vibe Kanban n'est plus maintenu que par la communauté depuis l'arrêt de Bloop (avril 2026).
- Trois niveaux de contrôle humain: approbation de chaque modification, validation par jalon (à la PR), plateforme gérée. [A] Pour un développeur seul: validation à la PR, et validation du plan avant tout code touchant paiement/appel.
- **Réponse à « 64 agents ? 10 agents de test ? »** [A]: non. Recommandation inchangée: 1 superviseur + 3 à 5 agents (backend, mobile, tests/relecture en lecture seule, sécurité ponctuelle), chacun dans son worktree, CI automatique comme « agent de test » principal. Les 10 agents de test n'apportent rien qu'une CI bien écrite ne fasse déjà.

## 3. Méthode de travail pour un développeur seul + agents [S]
- Trois flux éprouvés: pipeline piloté par spécification (spec, petites tâches, tests entre chaque étape); flux « borné par PR » (carte d'architecture d'abord, 5 à 10 PR de petite taille, fichiers immuables déclarés, relecture dans une session séparée); « conseil de guerre » (plusieurs agents comparent des approches avant de coder), à réserver aux choix structurants.
- Fichiers de contexte à tenir: CLAUDE.md/AGENTS.md (écrit à la main, court), cartes de domaine (paiement, annuaire, forum), DECISIONS.md (choix + raisons), modèle de menaces propre à NetBuis.
- Avertissement important: une étude contrôlée citée montre des développeurs expérimentés **19 % plus lents** avec l'IA tout en se croyant 20 % plus rapides. [A] Mesurer le temps réel par tâche pendant le premier mois (journal simple), ne pas se fier à la sensation. Le gain réel vient surtout de la capacité à traiter des sujets hors de son domaine (conformité, sécurité, déploiement), qui représenteraient jusqu'à 60 % du travail.
- Limites: refontes transversales à découper par fichier; commit avant chaque changement de l'IA; points de reprise explicites entre sessions; durcissement de sécurité inutile sans modèle de menaces fourni.
- [A] Cela soutient Scrumban ou Shape Up léger (cycles de 2 semaines, 3 à 5 tâches max en cours) plutôt que Scrum complet: pas d'équipe à synchroniser.

## 4. Critiques produit: rien de nouveau, rappel du plus important
Les risques n°1 restent: démarrage à froid de l'annuaire (pas de commerçants = pas d'utilisateurs), données commerçants périmées (stock, prix), appel direct soumis aux règles Android/Play, conformité loi 2024/017 et question ANTIC (v24), faible débit/téléphones d'entrée de gamme. Aucune nouvelle source ne les change.

## 5. Non établi
API marchande de Wave au Cameroun; date réelle et conditions de Blue Money; frais exacts CamPay/Monetbil; portée de l'obligation ANTIC.

## 6. Décisions pour Jeff
1. Méthode: Scrumban léger, Scrum augmenté ou Shape Up.
2. Règle d'agents: 1 superviseur + 3 à 5 (oui/non).
3. Passerelle de paiement abstraite dès le départ (oui/non) et filtre « moyens de paiement acceptés ».
4. Quartier pilote et recrutement des 30 premiers commerçants.
5. Qui interroge l'ANTIC; délégué données.
Rappel: 25 passes, rendements très décroissants. Proposition: passer cette routine en hebdomadaire et commencer à construire le premier jalon.

## Sources
- [Interview Wave Cameroun (Financial Afrik, juil. 2026)](https://www.financialafrik.com/en/2026/07/23/interview-with-joel-bertrand-ndjodo-country-manager-of-wave-cameroon/)
- [Camtel et le mobile money en 2026 (Business in Cameroon)](https://www.businessincameroon.com/public-management/0312-15437-camtel-plans-to-enter-momo-market-in-2026)
- [Orange et MTN: coentreprise Mowali (Business in Cameroon, 2018)](https://www.businessincameroon.com/telecom/2711-8619-cameroon-orange-and-mtn-launch-a-mobile-money-joint-venture)
- [Multi-Agent Orchestration: 5 Patterns (Digital Applied)](https://www.digitalapplied.com/blog/multi-agent-orchestration-5-patterns-that-work)
- [9 Open-Source Agent Orchestrators (Augment Code)](https://www.augmentcode.com/tools/open-source-agent-orchestrators)
- [Solo Developer AI Coding Agent (BuildMVPFast)](https://www.buildmvpfast.com/blog/solo-developer-ai-coding-agent-scale-large-project-2026)


---

<!-- source : audit-expert-v26-whatsapp-payant-verification-android-agents-netbuis.md -->

# Audit expert v26 NetBuis (2026-10-06, passe 5 du jour, routine automatique)

Passe courte: uniquement le NOUVEAU par rapport à v25. [S] = source web lue via résumé automatique, à revérifier; [A] = mon avis. Rien testé sur le terrain. Les critiques UI/UX, frontend, backend, sécurité, mémoire, prix et fonctionnalités des audits v3 à v25 restent valables.

## 1. WhatsApp devient payant pour les réponses (effectif depuis le 1er octobre 2026) [S]
- Depuis le 1er octobre 2026, la plateforme WhatsApp Business facture chaque **message de service** (réponse dans la fenêtre de 24 h) après **1 000 réponses gratuites par mois et par numéro**. Tarif cité pour la plupart des pays d'Afrique de l'Est: 0,0040 $ par message (Nigeria 0,0067 $). Le Cameroun n'est pas cité: il tomberait probablement dans « reste de l'Afrique », à vérifier sur la grille Meta officielle.
- Exemptions citées: les 7 jours après une pub « Click-to-WhatsApp » restent gratuits; gouvernements et ONG éligibles gratuits jusqu'au 31/12/2027.
- Piège: un compte **sans moyen de paiement enregistré cesse d'envoyer** une fois le quota gratuit épuisé.
- [A] Conséquences NetBuis: (1) le **lien wa.me / bouton « Écrire sur WhatsApp »** (ouvre l'appli WhatsApp du client vers le numéro du commerçant) reste hors plateforme et donc gratuit: le garder comme canal par défaut; (2) n'utiliser l'API Business (messages automatiques, confirmations, rappels) que si le volume le justifie; 1 000 réponses/mois/numéro suffisent largement pour un pilote; (3) ajouter une ligne « coût WhatsApp API » au budget avec alerte à 800 réponses; (4) ne jamais promettre « notifications WhatsApp gratuites » aux commerçants.

## 2. Vérification des développeurs Android: le Cameroun n'est PAS dans la première vague [S]
- Source officielle Android: protections lancées le **30 septembre 2026** dans 4 pays seulement (Brésil, Indonésie, Singapour, Thaïlande); **extension mondiale en 2027**. Concerne les appareils Android certifiés 7+ et les installations depuis des magasins participants. Google Play enregistre automatiquement environ 99 % des applis; une inscription à la console est requise pour distribuer hors Play.
- Compte « distribution limitée » (20 appareils, sans pièce d'identité ni frais) réservé aux étudiants, enseignants et amateurs: utile pour les tests, pas pour un lancement public.
- [A] Ceci **adoucit l'urgence signalée en v22/v23** pour le Cameroun en 2026, sans la supprimer: (1) s'inscrire dès maintenant à la console développeur (identité réelle, nom stable) pour ne pas subir l'extension 2027; (2) l'APK hors Play (WhatsApp, bouche à oreille) est une voie importante au Cameroun: prévoir de l'enregistrer comme les autres; (3) garder la même clé de signature sur toutes les voies de distribution.

## 3. Orchestration d'agents: chiffres complémentaires [S]
- Guide communautaire sur les « agent teams » de Claude Code (fonction expérimentale, sans garantie de stabilité): **commencer à 2-3 agents**; plafond habituel 5; plus seulement si les modules sont indépendants sans état partagé. Coût en jetons **1,8 à 2,5 fois** celui d'une session seule (≈ 2 fois pour une fonctionnalité). Règle: ne justifier une équipe que si le temps gagné dépasse le surcoût.
- À éviter: tâches de moins de 5 fichiers, bases de code sous 5 000 lignes, tâches séquentielles, travail fortement écrit en commun (migrations de schéma, contrat d'API). Les équipes sont bonnes pour la lecture (relecture, recherche de bugs), mauvaises pour l'écriture partagée.
- Règle d'or: **un seul agent propriétaire de chaque fichier partagé** (plan, liste de tâches, schéma). L'édition simultanée d'un même fichier de plan est la première cause de corruption silencieuse.
- [A] Réponse définitive à « 64 agents ? 10 agents de test ? »: non. Pour NetBuis (petite base de code au départ): **1 agent principal + 1 à 2 sous-agents en lecture seule (relecteur, sécurité)**, puis 3 à 5 en écriture seulement quand backend et mobile ont des contrats d'API figés. Le schéma de base de données et le fichier de décisions ont un seul propriétaire (vous).

## 4. Frais mobile money: pas de nouveauté fiable
La recherche n'a renvoyé qu'un article de 2021 (projet de taxe de 0,2 % sur envois/retraits) et des calculateurs tiers non vérifiés. Ne pas en tirer de chiffres. Les frais exacts restent à confirmer auprès de CamPay/Monetbil et des opérateurs.

## 5. Non établi
Tarif WhatsApp exact pour le Cameroun; date d'extension de la vérification Android au Cameroun (2027, mois inconnu); API marchande de Wave; portée de l'obligation ANTIC; frais exacts CamPay/Monetbil.

## 6. Décisions pour Jeff
1. Canal WhatsApp par défaut: lien wa.me gratuit (recommandé) ou API Business payante.
2. Règle d'agents: 1 principal + 1-2 lecteurs au démarrage (oui/non).
3. S'inscrire à la console développeur Android maintenant (oui/non).
4. Méthode: Scrumban léger, Scrum augmenté ou Shape Up (voir v25).
5. Quartier pilote et recrutement des 30 premiers commerçants.
Rappel: 26 passes, rendements très décroissants. Proposition renouvelée: passer cette routine en hebdomadaire et commencer le premier jalon.

## Sources
- [WhatsApp Now Charges for Business Replies (Oct 2026)](https://nagmelater.com/blog/whatsapp-service-message-pricing.html)
- [Android developer verification (developer.android.com)](https://developer.android.com/developer-verification)
- [Claude Code Agent Teams guide (GitHub, FlorianBruniaux)](https://github.com/FlorianBruniaux/claude-code-ultimate-guide/blob/main/guide/workflows/agent-teams.md)
- [WhatsApp Business API pricing (Flowcall)](https://www.flowcall.co/blog/whatsapp-business-api-pricing)
- [Journal du Cameroun: frais mobile money (2021, ancien)](https://fr.journalducameroun.com/cameroun-vers-une-nouvelle-augmentation-des-frais-du-mobile-money-cameroun/)


---

<!-- source : audit-expert-v27-confirmations-sans-nouveaute-netbuis.md -->

# Audit expert v27 NetBuis (2026-10-06, passe 6 du jour, routine automatique)

Passe de confirmation. [S] = source web lue via résumé automatique; [A] = mon avis. Résultat: **aucune nouveauté qui change une décision**. Les critiques UI/UX, frontend, backend, sécurité, mémoire, prix et fonctionnalités des audits v3 à v26 restent valables.

## 1. Confirmé (déjà dans le projet)
- **Twilio Cameroun**: 0,7873 USD/min vers mobile, 0,41 USD/min vers fixe [S, page tarifs Twilio]. Identique à v5/v10: le dialer natif reste le bon choix du MVP.
- **Loi 2024/017**: en application depuis le 23 juin 2026 [S, DGB]. Obligations: registre des traitements, consentement explicite (pas de case pré-cochée), minimisation et chiffrement, contrats avec sous-traitants (responsabilité maintenue en cas de faille), droits d'accès/correction/opposition/effacement. DPO obligatoire pour administrations et grandes entreprises (probablement pas NetBuis, mais désigner un responsable reste prudent) [A]. Montants des sanctions toujours contradictoires entre sources: ne pas les citer. Voir v5, v10, v19.
- **Intégration mobile money via agrégateur** (CamPay, CinetPay, Notch Pay, Monetbil): 1 à 2 jours d'intégration annoncés; USSD push en 2 à 5 s; jusqu'à ~3 % de latence USSD [S, blog d'un prestataire, à relativiser]. Bonnes pratiques: ne jamais marquer une commande payée sur la seule redirection côté client; vérifier la signature HMAC SHA-256 du webhook; idempotence par identifiant de transaction; interrogation de rattrapage après ~90 s. [A] À mettre dans le cahier des charges paiement.
- **Mowali** (interopérabilité MTN-Orange): annonce de 2018 [S], pas une nouveauté de 2026; ne pas en déduire d'API ou de frais inter-réseaux actuels.

## 2. Orchestration d'agents: patterns [S, digitalapplied]
Cinq patterns: fan-out, pipeline, débat, **superviseur (défaut 2026)**, essaim. Coûts: fan-out et pipeline ~N fois; superviseur ~(N+1) fois; débat 1,2 à 2,5 fois; essaim réservé à 50+ tâches indépendantes. Échecs typiques: pipeline = une erreur d'étape contamine la suite; superviseur = sur-délégation.
[A] Cohérent avec v26: pour NetBuis, 1 agent principal + 1 à 2 lecteurs en lecture seule. Ni 64 agents ni 10 agents de test.

## 3. Spec-driven development: limites [S, DEV Community, avis d'un auteur, sans données chiffrées]
Charge de maintenance des specs; excessif pour un petit correctif; les agents ignorent parfois des contraintes écrites; risque de sur-spécifier; une spec ne remplace pas la compétence métier. Utile surtout pour équipes, fonctions complexes, reprise de code existant.
[A] Confirme la position « spécification légère uniquement sur argent, identité, consentement, crédits » (v10, v19).

## 4. Non établi
Frais exacts CamPay/Monetbil; tarif WhatsApp API Cameroun; texte officiel des sanctions; date d'extension Android 2027.

## 5. Décisions pour Jeff (inchangées depuis v26)
1. Canal WhatsApp: lien wa.me gratuit par défaut. 2. Règle d'agents: 1 principal + 1-2 lecteurs. 3. Inscription console développeur Android maintenant. 4. Méthode: Scrumban léger / Scrum augmenté / Shape Up. 5. Quartier pilote et 30 premiers commerçants.
Rappel: 27 passes, rendement quasi nul. Recommandation: passer la routine en hebdomadaire (ou la suspendre) et lancer le jalon 0.

## Sources
- [Twilio Voice Pricing Cameroun](https://www.twilio.com/en-us/voice/pricing/cm)
- [Loi sur la protection des données: entrée en vigueur (DGB)](https://www.dgb.cm/la-loi-sur-la-protection-des-donnees-personnelles-entre-officiellement-en-vigueur/)
- [Intégrer MTN MoMo & Orange Money au Cameroun (NjokaLab)](https://www.njokalab.com/insights/how-to-integrate-mtn-momo-orange-money-cameroon-api/)
- [Multi-Agent Orchestration: 5 Patterns (Digital Applied)](https://www.digitalapplied.com/blog/multi-agent-orchestration-5-patterns-that-work)
- [Spec-Driven Development in 2026 (DEV Community)](https://dev.to/alexcloudstar/spec-driven-development-in-2026-the-future-of-ai-coding-or-waterfall-20-2mfg)
- [Mowali, MTN-Orange (Business in Cameroon, 2018)](https://www.businessincameroon.com/telecom/2711-8619-cameroon-orange-and-mtn-launch-a-mobile-money-joint-venture)


---

<!-- source : audit-expert-v28-passe-hebdo-confirmations-netbuis.md -->

# Audit expert v28 NetBuis (2026-10-06, routine automatique)

[S] = source web lue (résumé automatique); [A] = mon avis. Résultat: **aucune nouveauté qui change une décision**. Critiques UI/UX, frontend, backend, sécurité, mémoire, prix et fonctionnalités des audits v3 à v27 restent valables. Aucune notification envoyée: rien d'urgent.

## 1. Orchestration d'agents: deux confirmations utiles
- **Addy Osmani, « Code Agent Orchestra »** [S]: « 3-5 coéquipiers est le point optimal »; coûts en jetons linéaires avec la taille de l'équipe; « le goulot n'est plus la génération mais la vérification »; trois garde-fous: approbation du plan avant code, hooks automatiques (tests à la fin d'une tâche), fichier AGENTS.md **écrit par un humain** (un fichier généré par IA n'apporte rien et baisse le succès d'environ 3 %).
- **Heuristiques « Tall Order »** [S]: privilégier un agent unique avec bon contexte; paralléliser seulement des tâches indépendantes (UI / serveur / etc.); chaque agent ajouté ajoute de la complexité; la planification coûte peu et améliore beaucoup le résultat.
- [A] Cohérent avec v26/v27: pour NetBuis, **1 agent principal + 1 à 2 lecteurs/relecteurs**, plan validé par Jeff avant code, tests automatiques en hook, AGENTS.md rédigé par Jeff. Ni 64 agents, ni 10 agents de test. Le vrai goulot est la relecture humaine de Jeff.

## 2. Mobile money Cameroun: attention aux sources datées
- L'article ecomatin sur Orange Money (frais de retrait 1,5 % plafonnés à 3 500 FCFA; plafonds 5 M/semaine, 10 M/mois; Orange ~70 % de parts de marché) date en réalité de **novembre 2023** [S]. À ne pas présenter comme actuel; à revérifier auprès d'Orange/de l'agrégateur avant de fixer les prix des crédits NetBuis.
- Les articles kolonell.com (paysage paiement 2026, coût d'intégration MoMo/Orange) n'ont pas pu être exploités en détail: chiffres non établis. [A] Ne pas bâtir de budget dessus sans devis agrégateur.

## 3. Non établi (inchangé)
Frais exacts CamPay/Monetbil/Notch Pay; tarif WhatsApp API Cameroun; sanctions officielles de la loi 2024/017; date d'extension de la vérification Android 2027.

## 4. Décisions pour Jeff (inchangées depuis v26)
1. Canal WhatsApp: lien wa.me gratuit par défaut. 2. Règle d'agents: 1 principal + 1-2 lecteurs. 3. Inscription console développeur Android maintenant. 4. Méthode: Scrumban léger / Scrum augmenté / Shape Up. 5. Quartier pilote et 30 premiers commerçants.

**Recommandation répétée**: 28 passes, rendement quasi nul. Passer la routine en hebdomadaire ou la suspendre, et lancer le jalon 0 (choix du quartier pilote + inscription développeur).

## Sources
- [Harness Engineering, étude de 11 agents de code (arXiv)](https://arxiv.org/pdf/2609.00006)
- [The Code Agent Orchestra (Addy Osmani)](https://addyosmani.com/blog/code-agent-orchestra/)
- [Heuristics for agent orchestration in 2026 (Tall Order)](https://tallorder.bearblog.dev/heuristics-for-agent-orchestration-in-2026)
- [Orange Cameroun abaisse ses tarifs (Ecomatin, nov. 2023)](https://ecomatin.net/mobile-money-orange-cameroun-abaisse-ses-tarifs-et-releve-les-plafonds-de-retrait)
- [Paysage paiement mobile Cameroun 2026 (Kolonell)](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : audit-expert-v29-passe-confirmation-netbuis.md -->

# Audit expert v29 NetBuis (2026-10-06, routine automatique)

[S] = source web; [A] = mon avis. Rien testé sur le terrain.

**Résultat: aucune nouveauté qui change une décision.** Recherches refaites: orchestration d'agents de code (octobre 2026), réglementation mobile money Cameroun, vérification des développeurs Android.

## Ce que j'ai revérifié
- **Android** [S, TechRepublic, 21 août 2026]: application effective le 30 septembre 2026 au Brésil, en Indonésie, à Singapour et en Thaïlande; extension mondiale en 2027. Le « flux avancé » impose un délai de 24 h. ADB reste exempté. Déjà couvert en v12 et v26: le Cameroun n'est pas dans la première vague. Action inchangée: s'inscrire à la console développeur avant 2027.
- **Mobile money Cameroun**: la recherche renvoie les mêmes articles (Ecomatin 2023, Kolonell 2026) déjà jugés datés ou non exploitables en v28. Aucune source récente avec des tarifs ou une réglementation nouvelle. Les frais exacts des agrégateurs restent non établis.
- **Orchestration d'agents**: les résultats (Addy Osmani, Tall Order, Augment, Morph, etc.) sont déjà traités dans les audits v21 à v28. Règle inchangée: 1 agent principal + 1 à 2 relecteurs; ni 64 agents, ni 10 agents de test; plan validé par Jeff avant code; AGENTS.md rédigé par Jeff.

## Décisions en attente (inchangées depuis v26)
1. Canal WhatsApp: lien wa.me gratuit par défaut.
2. Règle d'agents: 1 principal + 1 à 2 relecteurs.
3. Inscription à la console développeur Android.
4. Méthode de gestion de projet: Scrumban léger, Scrum augmenté ou Shape Up.
5. Quartier pilote et 30 premiers commerçants.

**Recommandation répétée**: 29 passes, rendement quasi nul depuis v21. Suspendre cette routine ou la passer en hebdomadaire, puis lancer le jalon 0 (quartier pilote + inscription développeur). Aucune notification envoyée: rien d'urgent.

## Sources
- [Google Tightens Android Sideloading (TechRepublic, août 2026)](https://techrepublic.com/article/news-google-android-sideloading-24-hour-wait)
- [The Code Agent Orchestra (Addy Osmani)](https://addyosmani.com/blog/code-agent-orchestra/)
- [Orange Cameroun abaisse ses tarifs (Ecomatin, nov. 2023)](https://ecomatin.net/mobile-money-orange-cameroun-abaisse-ses-tarifs-et-releve-les-plafonds-de-retrait)


---

<!-- source : audit-expert-v30-passe-confirmation-netbuis.md -->

# Audit expert v30 NetBuis (2026-10-06, routine automatique)

[S] = source web; [A] = mon avis. Rien testé sur le terrain.

**Résultat: aucune nouveauté qui change une décision.** Trois recherches refaites (tarifs/réglementation mobile money Cameroun, orchestration d'agents de code, vérification développeurs Android).

- **Mobile money Cameroun**: les résultats sont les mêmes articles Ecomatin / Digital Business Africa (2023-2025) déjà jugés datés en v28 et v29. Aucune source récente avec tarifs ou règle nouvelle. Frais exacts des agrégateurs toujours non établis.
- **Orchestration d'agents**: mêmes références (Addy Osmani "Code Agent Orchestra", Morph, Zencoder, Towards Data Science "100 agents", article "orchestration topology") déjà traitées en v21-v28. Règle inchangée [A]: 1 agent principal + 1 à 2 relecteurs; ni 64 agents ni 10 agents de test pour un projet de cette taille; plan validé par Jeff avant le code.
- **Android**: vérification des développeurs effective depuis le 30 septembre 2026 dans 4 pays, extension mondiale en 2027 (déjà en v12, v26, v29). Action inchangée: s'inscrire à la console développeur avant 2027.

## Décisions en attente (inchangées depuis v26)
1. Canal WhatsApp: lien wa.me gratuit par défaut.
2. Règle d'agents: 1 principal + 1 à 2 relecteurs.
3. Inscription à la console développeur Android.
4. Méthode de gestion de projet: Scrumban léger, Scrum augmenté ou Shape Up.
5. Quartier pilote et 30 premiers commerçants.

**Recommandation**: 30 passes, rendement quasi nul depuis v21. Suspendre cette routine ou la passer en hebdomadaire, puis lancer le jalon 0 (quartier pilote + inscription développeur). Aucune notification envoyée: rien d'urgent.

## Sources
- [The Code Agent Orchestra (Addy Osmani)](https://addyosmani.com/blog/code-agent-orchestra/)
- [Multi Agent Orchestration Patterns](https://codex.danielvaughan.com/2026/05/18/multi-agent-orchestration-patterns/)
- [Google Starts Asking for Developers' Papers on September 30](https://reclaimthenet.org/google-starts-asking-for-developers-papers-on-september-30)
- [Cameroun: tarifs de retrait MTN MoMo 2025](https://www.digitalbusiness.africa/cameroun-les-tarifs-de-retrait-de-mtn-mobile-money-momo-en-2025/)


---

<!-- source : audit-expert-v31-passe-confirmation-netbuis.md -->

# Audit expert v31 NetBuis (2026-10-07, routine automatique)

[S] = source web; [A] = mon avis. Rien testé sur le terrain.

**Résultat: une seule donnée un peu nouvelle, aucune décision modifiée.**

- **Frais mobile money Cameroun [S, faible fiabilité]**: un blog d'agence web (Kolonell, 6 août 2026) donne des ordres de grandeur: commission marchand MTN MoMo 1,5–2,2 %, Orange Money 1,5–1,8 %; coût d'intégration unique 300 000–900 000 FCFA; activation du compte marchand 2–4 semaines (MTN), 2–3 semaines (Orange). La source est une agence qui vend de l'intégration, non l'opérateur: à traiter comme indicatif, à confirmer par devis Campay / opérateurs. Utile pour le budget: à 4 M FCFA/mois traités, ~2 % = ~960 000 FCFA/an de frais. [A] Cela renforce la règle déjà retenue: ne pas faire transiter l'argent au lancement (appel direct + lien wa.me gratuit), paiement en jalon ultérieur.
- **Orchestration d'agents**: nouveaux résultats (Zencoder, Mastra, Momen, ibl.ai) = même contenu générique que v21–v30. Règle inchangée [A]: 1 agent principal + 1 à 2 relecteurs; ni 64 agents ni 10 agents de test; plan validé par Jeff avant le code.
- **Android / vérification développeurs**: inchangé (v30).

## Décisions en attente (inchangées depuis v26)
1. Canal WhatsApp: lien wa.me gratuit par défaut.
2. Règle d'agents: 1 principal + 1 à 2 relecteurs.
3. Inscription à la console développeur Android.
4. Méthode de gestion de projet: Scrumban léger, Scrum augmenté ou Shape Up.
5. Quartier pilote et 30 premiers commerçants.

**Recommandation (répétée)**: 31 passes, rendement quasi nul. Suspendre ou passer la routine en hebdomadaire, puis lancer le jalon 0 (quartier pilote + inscription développeur). Aucune notification envoyée: rien d'urgent.

## Sources
- [Coût d'intégration MTN MoMo / Orange Money Douala 2026 (Kolonell)](https://kolonell.com/fr/blog/cout-integration-mtn-momo-orange-money-douala-2026)
- [6 AI Agent Orchestration Best Practices in 2026 (Zencoder)](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [AI agent orchestration: patterns (Mastra)](https://mastra.ai/articles/ai-agent-orchestration)


---

<!-- source : audit-expert-v32-passe-confirmation-netbuis.md -->

# Audit expert v32 NetBuis (2026-10-07, routine automatique)

[S] = source web; [A] = mon avis. Rien testé sur le terrain.

**Résultat: aucune donnée nouvelle, aucune décision modifiée.**

- **Orchestration d'agents [S]**: les résultats (Morph, Zencoder, Unblocked, Tembo, Addy Osmani « Code Agent Orchestra », amux, CodeMySpec) restent du contenu générique déjà couvert (v21–v31). Règle inchangée [A]: 1 agent principal + 1 à 2 relecteurs; ni 64 agents ni 10 agents de test; plan validé par Jeff avant le code.
- **Paiement mobile Cameroun [S]**: seuls des articles de l'agence Kolonell ressortent (déjà vus en v31, source commerciale, faible fiabilité). Rien d'officiel MTN/Orange. Règle inchangée: pas de flux d'argent au lancement.
- **Android / vérification développeurs [S]**: pas de nouvelle annonce visible; articles datés de 2025 (inchangé depuis v30).

## Décisions en attente (inchangées depuis v26)
1. Canal WhatsApp: lien wa.me gratuit par défaut.
2. Règle d'agents: 1 principal + 1 à 2 relecteurs.
3. Inscription à la console développeur Android.
4. Méthode de gestion de projet: Scrumban léger, Scrum augmenté ou Shape Up.
5. Quartier pilote et 30 premiers commerçants.

**Recommandation (répétée)**: 32 passes, rendement nul. Suspendre la routine ou la passer en hebdomadaire, puis lancer le jalon 0. Aucune notification envoyée: rien d'urgent.

## Sources
- [AI Agent Orchestration (Morph)](https://www.morphllm.com/ai-agent-orchestration)
- [The Code Agent Orchestra (Addy Osmani)](https://addyosmani.com/blog/code-agent-orchestra/)
- [Paysage paiement mobile Cameroun 2026 (Kolonell)](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Android developer verification (9to5Google)](https://9to5google.com/2025/08/25/android-apps-developer-verification/)


---

<!-- source : audit-expert-v33-synthese-consolidee-netbuis.md -->

# Audit expert v33 NetBuis (2026-10-07): synthèse consolidée

Version complète (document vivant): https://claude.ai/code/artifact/dc3cac6c-c405-456d-8e6f-830d08571f19

Nouveautés vérifiées le 2026-10-07:
- WhatsApp: depuis le 1er octobre 2026, certaines réponses via l'API WhatsApp Business sont facturées (ex. Nigeria: ~0,0101 USD message de service, ~0,062 USD marketing). Tarifs Cameroun non vérifiés. Confirme wa.me gratuit par défaut. [MSME Africa](https://msmeafricaonline.com/whatsapp-to-charge-businesses-for-customer-replies-from-october-2026/)
- Android: vérification d'identité des développeurs obligatoire dès sept. 2026 (Brésil, Indonésie, Singapour, Thaïlande), mondiale en 2027; Cameroun non cité. [BleepingComputer](https://www.bleepingcomputer.com/news/security/google-to-verify-all-android-devs-to-protect-users-from-malware/)
- Orchestration: 3 à 5 agents, plan approuvé, relecteur lecture seule, arrêt après 3 blocages; inchangé. [Daniel Vaughan](https://codex.danielvaughan.com/2026/05/18/multi-agent-orchestration-patterns/)

Décisions en attente (inchangées): canal WhatsApp; règle d'agents; compte développeur Android; méthode de gestion; quartier pilote + 30 commerçants + seuil go/no-go.
Recommandation: passer la routine en hebdomadaire ou la suspendre, lancer le jalon 0.


---

<!-- source : audit-expert-v34-passe-confirmation-netbuis.md -->

# Audit expert v34 NetBuis (2026-10-07): passe de confirmation, sans nouveauté

Recherches faites: annonces Twilio/Orange Money/MTN MoMo Cameroun, et orchestration multi-agents pour le développement logiciel. Résultat: aucune annonce nouvelle ni changement de tarif ou de règle. Les résultats sont des articles généraux (kolonell.com sur le paysage paiement Cameroun, zencoder, mastra, arXiv 2601.13671 et 2604.10599) qui confirment les conclusions de la v33.

Conclusions v33 toujours valables: wa.me gratuit par défaut (l'API WhatsApp Business devient payante pour certaines réponses depuis le 1er octobre 2026), 3 à 5 agents avec plan approuvé et relecteur en lecture seule, vérification des développeurs Android à surveiller (Cameroun non cité).

Décisions toujours en attente de Jeff: canal WhatsApp; règle d'agents; compte développeur Android; méthode de gestion de projet; quartier pilote, 30 commerçants et seuil go/no-go.

Recommandation répétée: la routine tourne toutes les heures et ne produit plus de nouveauté. La passer en hebdomadaire ou la suspendre, et lancer le jalon 0.


---

<!-- source : audit-expert-v35-passe-confirmation-netbuis.md -->

# Audit expert v35 NetBuis (2026-10-07): passe de confirmation, sans nouveauté

Recherches refaites: nouveautés Orange Money / MTN MoMo Cameroun, orchestration multi-agents pour le développement logiciel, tarifs WhatsApp/Twilio.

Résultat: aucune annonce nouvelle. Les sources sont les mêmes que pour la v34 (kolonell.com sur le paiement mobile au Cameroun, zencoder, mastra, momen, avis Twilio « Changes to WhatsApp's Pricing October 2026 »). Les conclusions de la v33 restent valables: wa.me gratuit par défaut, 3 à 5 agents avec plan approuvé et relecteur en lecture seule, vérification des développeurs Android à surveiller.

Décisions toujours en attente de Jeff: canal WhatsApp; règle d'agents; compte développeur Android; méthode de gestion de projet; quartier pilote, 30 commerçants et seuil go/no-go.

Recommandation: la routine ne produit plus de nouveauté. La passer en hebdomadaire ou la suspendre, et lancer le jalon 0.


---

<!-- source : audit-expert-v36-passe-confirmation-netbuis.md -->

# Audit expert v36 NetBuis (2026-10-07): passe de confirmation, sans nouveauté

Recherches refaites: nouveautés Orange Money / MTN MoMo Cameroun, orchestration multi-agents pour le développement logiciel.

Résultat: aucune source nouvelle. L'article Ecomatin sur Orange Cameroun date de novembre 2023 (déjà jugé daté en v28/v29). Les articles Kolonell, Zencoder, Mastra et Momen sont les mêmes que pour v34 et v35. Les conclusions de la v33 restent valables: wa.me gratuit par défaut, 1 agent principal + 1 à 2 relecteurs (ni 64 agents, ni 10 agents de test), plan validé par Jeff avant le code, vérification des développeurs Android à anticiper avant 2027.

Décisions toujours en attente de Jeff: canal WhatsApp; règle d'agents; compte développeur Android; méthode de gestion de projet (Scrumban léger / Scrum augmenté / Shape Up); quartier pilote, 30 commerçants et seuil go/no-go.

Recommandation: la routine ne produit plus de nouveauté depuis la v21. La passer en hebdomadaire ou la suspendre, et lancer le jalon 0. Aucune notification envoyée: rien d'urgent.

## Sources
- [Orange Cameroun abaisse ses tarifs (Ecomatin, nov. 2023)](https://ecomatin.net/mobile-money-orange-cameroun-abaisse-ses-tarifs-et-releve-les-plafonds-de-retrait)
- [Paysage paiement mobile Cameroun 2026 (Kolonell)](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [6 AI Agent Orchestration Best Practices (Zencoder)](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [AI agent orchestration (Mastra)](https://mastra.ai/articles/ai-agent-orchestration)


---

<!-- source : audit-expert-v37-concurrent-buyam-netbuis.md -->

# Audit expert v37 NetBuis (2026-10-07): concurrent direct Buyam (nouveauté réelle)

[S] = source web lue (résumé automatique, à revérifier); [A] = mon avis. Rien testé sur le terrain. Les choix restent à Jeff.

## 1. Nouveauté: Buyam, concurrent direct jamais traité dans v1 à v36
Recherche de contrôle dans le projet: aucun document ne mentionne Buyam (v17 cite Jumia, KiKUU, Jumli, Kuruba; v18 cite Offrir).

Ce que dit Buyam sur lui-même [S]:
- Plateforme « e-commerce hyper-locale » camerounaise: discuter avec le vendeur et marchander, « comme au marché ». Fondée en 2014 à Buea (Churchill Mambe Nanje, Kelvin Manjong), lancement complet après huit ans.
- Chiffres auto-déclarés (non vérifiés): 150 000+ utilisateurs, 12 000+ vendeurs inscrits dont 5 000+ vérifiés, 100 000+ produits et services.
- Buyam Search (article du 17 juillet 2025): moteur de recherche IA qui géolocalise 10 000+ boutiques; recherche par mot-clé, par lieu (« casque à Douala »), par budget (« frigo à 150000 FCFA »), filtres combinés et recherche par photo; voir les prix, la localisation exacte et contacter le vendeur; accessible dans l'app et sur le web (search.buyam.co). Une fiche d'application iOS existe.
- Non établi: villes couvertes, financement, modèle économique, présence d'appel direct ou de WhatsApp, paiement.

## 2. Critique [A]
- La fonction centrale de NetBuis (taper un produit, voir les commerçants proches, les contacter) existe déjà chez Buyam, avec 12 000 vendeurs et une recherche par photo. L'hypothèse « personne ne fait ça » est fausse.
- Différences possibles à tester, pas à supposer: appel téléphonique direct en un geste et WhatsApp (Buyam privilégie le chat intégré); fonctionnement sur téléphone 2 Go et connexion faible; forum; produits les plus demandés; quartiers ou marchés précis où Buyam est peu présent.
- Risque principal: vendre à Buyam un second annuaire de commerçants. Les commerçants déjà inscrits chez eux n'auront aucune raison de ressaisir leur stock.

## 3. Actions proposées (avant tout code)
1. Installer Buyam et chronométrer « trouver un produit et joindre le vendeur » (même test que pour Offrir, v18). Fixer un objectif NetBuis plus court.
2. Dans le quartier pilote, compter combien de commerçants sont déjà sur Buyam. Si la majorité l'est, changer d'angle (appel direct, hors-ligne, marchés non couverts) ou viser une complémentarité (import de leur catalogue si possible).
3. Écrire en une phrase la différence de NetBuis; si elle ne tient pas en une phrase, ne pas coder.
4. Mettre à jour le seuil go/no-go du jalon 0 avec ce concurrent.

## 4. Orchestration d'agents: confirmation (aucun changement)
Addy Osmani « Code Agent Orchestra » relu [S]: équipe optimale de 3 à 5 agents; coût en jetons proportionnel à la taille de l'équipe; plan approuvé avant implémentation; relecteur en lecture seule; fichier AGENTS.md écrit par un humain (les fichiers générés par IA n'apportent rien); plafond de 8 itérations; arrêter un agent bloqué 3 fois sur la même erreur; ne jamais deux agents sur le même fichier; la vérification est devenue le goulot, pas la génération. [A] Règle inchangée: 1 agent principal + 1 à 2 relecteurs, ni 64 agents ni 10 agents de test.

## Décisions en attente de Jeff
Canal WhatsApp (wa.me gratuit par défaut); règle d'agents; compte développeur Android avant 2027; méthode de gestion (Scrumban léger / Scrum augmenté / Shape Up); quartier pilote, 30 commerçants et seuil go/no-go (à réviser avec Buyam).

## Sources
- [Buyam Search (blog Buyam, juillet 2025)](https://buyam.co/hq/en/blog/introducing-buyam-search-your-new-digital-compass-for-cameroons-markets-1752751258)
- [À propos de Buyam](https://buyam.co/hq/fr/about)
- [The Code Agent Orchestra (Addy Osmani)](https://addyosmani.com/blog/code-agent-orchestra/)


---

<!-- source : audit-expert-v38-concurrents-youmbia-kaymucm-netbuis.md -->

# Audit expert v38 NetBuis (2026-10-07): deux concurrents locaux de plus, commissions, agents (confirmation)

[S] = source web lue (résumé automatique, à revérifier); [A] = mon avis. Rien testé sur le terrain. Les choix restent à Jeff.

## 1. Nouveautés (absentes de v1 à v37, vérifié par recherche dans le projet)
- Youmbia [S]: application camerounaise de petites annonces (téléphones, immobilier, véhicules, mode, services), mise en ligne le 3 juin 2026, recherche et catégories, contact direct acheteur-vendeur, « espace vendeur professionnel ». Moins de 1 000 téléchargements, 2 notes seulement: très jeune, peu d'adoption. Source: fiche mwm.ai.
- Kaymucm [S, titre seulement]: un article de Camer.be indique qu'elle aurait permis à plus de 2 600 commerçants (pros et amateurs) de vendre; date et détails non lus. À vérifier avant d'en tirer quoi que ce soit.
- Commissions des marketplaces locales à Yaoundé: 5 à 20 %, parfois jusqu'à 30 % [S, blog Kolonell, source commerciale]. Seuil indiqué: au-delà d'environ 50 commandes par mois, une boutique propre devient plus rentable. [A] Argument pour NetBuis: ne prendre aucune commission sur la vente (le commerçant garde sa marge, le contact est l'objet), mais cela coûte le modèle économique: à définir (abonnement léger, mise en avant payante).

## 2. Critique [A]
- Le segment « trouver un produit près de moi » a maintenant au moins Buyam (v37, 12 000 vendeurs déclarés), Youmbia, Offrir (v18), Jumli, plus WhatsApp et Facebook. Trois entrants en peu de temps montrent que l'idée attire, pas que les commerçants paient ou que les clients restent.
- Youmbia à moins de 1 000 téléchargements illustre le vrai risque: la difficulté n'est pas de construire l'application mais de remplir le catalogue et d'obtenir des usages répétés. Le jalon 0 (30 commerçants dans un quartier, mesure d'usage) reste le seul test qui compte.
- Différence à formuler en une phrase avant de coder (même règle que v37): appel direct en un geste + fonctionnement sur petit téléphone/faible connexion + produits les plus demandés. Si Buyam fait déjà cela sur le quartier pilote, changer d'angle.

## 3. Orchestration d'agents: confirmation, aucun changement
Article « orchestrer 100 agents avec Claude Code » (Towards Data Science) [S]: le parallélisme sert à faire plus de travail total sur de gros volumes; pas de chiffre de coût; difficultés = découper les tâches sans chevauchement, suivre les agents, gérer leurs questions; peu utile pour un petit projet en solo. Cohérent avec Addy Osmani et D. Vaughan (v33, v37): 3 à 5 agents au maximum. [A] Règle inchangée: 1 agent principal + 1 à 2 relecteurs en lecture seule; ni 64 agents ni 10 agents de test. La vérification humaine reste le goulot.

## 4. Méthode de gestion de projet: inchangée
Scrumban léger / Scrum augmenté / Shape Up (v21, rapport-methodes-gestion-projet). Pour un développeur solo avec agents: cycles de 2 semaines à périmètre fixe, plan approuvé avant implémentation, démo à des commerçants réels à chaque fin de cycle.

## 5. Recommandation
Ces passes quotidiennes ne produisent plus que des concurrents ou des confirmations. [A] Suspendre ou passer la routine en hebdomadaire, puis lancer le jalon 0. Décisions toujours en attente de Jeff: canal WhatsApp (wa.me gratuit par défaut), règle d'agents, compte développeur Android avant 2027, méthode de gestion, quartier pilote + seuil go/no-go (à réviser avec Buyam et Youmbia), modèle de revenu sans commission.

## Sources
- [Youmbia (mwm.ai)](https://mwm.ai/apps/youmbia/6774914586)
- [Kaymucm, 2 600 commerçants (Camer.be)](https://www.camer.be/39113/12:1/cameroon-cameroun-candace-nkoth-bisseck-kaymucm-a-permis-a-plus-de-2600-commercants-professionnels-et-amateurs-de-vendre-leurs-produits.html)
- [Marketplace locale vs boutique propre, Yaoundé 2026 (Kolonell)](https://kolonell.com/fr/blog/marketplace-locale-vs-boutique-propre-yaounde-2026)
- [Orchestrer 100 agents avec Claude Code (Towards Data Science)](https://towardsdatascience.com/how-to-orchestrate-100-agents-with-claude-code/)


---

<!-- source : audit-expert-v39-saturation-recommandation-arret-netbuis.md -->

# Audit expert v39 NetBuis (2026-10-07): saturation, recommandation d'arrêt de la routine

[S] = source web (titres de résultats seulement, non lus en détail); [A] = mon avis.

## 1. Résultat de la passe
- Recherche concurrents/lancements au Cameroun (produit local + appel direct): aucun nouvel entrant identifié au-delà de Buyam, Youmbia, Offrir, Jumli, Kaymucm (v18, v37, v38). Résultats hors sujet (Camtel, CFAO, Made in Cameroon).
- Recherche orchestration d'agents: résultats génériques (topologie d'orchestration comme goulot, guides 2026, talk d'Addy Osmani). Rien qui contredise la règle déjà retenue: 1 agent principal + 1 à 2 relecteurs en lecture seule, 3 à 5 agents au maximum; ni 64 agents ni 10 agents de test [S: dev.to « orchestration topology », talks.addy.ie, amux.io].
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## 2. Constat [A]
38 audits, ~35 addenda API/USSD et ~37 vérifications d'appel direct en 3 jours: les passes ne produisent plus que des confirmations. Le risque n'est plus technique, il est de marché: remplir le catalogue et obtenir des usages répétés (leçon Youmbia, moins de 1 000 téléchargements).

## 3. Recommandation
1. Suspendre cette routine (ou la passer en hebdomadaire).
2. Lancer le jalon 0: 30 commerçants dans un quartier, mesure d'usage, seuil go/no-go.
3. Trancher les décisions en attente de Jeff: canal WhatsApp (wa.me gratuit par défaut), règle d'agents, compte développeur Android avant 2027, méthode de gestion, quartier pilote, modèle de revenu sans commission, différence face à Buyam en une phrase.

## Sources
- [Orchestration topology (dev.to)](https://dev.to/terminalblog/orchestration-topology-is-the-new-bottleneck-in-agentic-coding-487g)
- [Addy Osmani, O'Reilly CodeCon 2026](https://talks.addy.ie/oreilly-codecon-march-2026/)
- [AI Agent Orchestration 2026 (amux.io)](https://amux.io/guides/ai-agent-orchestration-2026/)


---

<!-- source : audit-expert-v40-concurrent-nkwel-netbuis.md -->

# Audit expert v40 NetBuis (2026-10-07): nouveau concurrent Nkwel, saturation confirmée

[S] = source web lue; [A] = mon avis.

## 1. Nouveauté unique: Nkwel (Yaoundé, mars 2026)
- [S, Business in Cameroon, 12/03/2026] Plateforme numérique de commerce de proximité, présentée à Yaoundé début mars 2026. Promoteur: Davis Ndjana Mengue. Application mobile + interface web, annoncée utilisable sans connexion internet.
- Fonctions citées: commandes à distance (restaurants, boulangeries, traiteurs, marchés), livraison ou retrait, suivi de commande en temps réel, paiement numérique intégré (opérateur non nommé), espèces toujours possibles.
- Non mentionné dans l'article: recherche par produit, appel direct au commerçant, tarifs, éditeur technique.
- [A] Nkwel est un modèle « commande + livraison », pas « trouver qui a le produit et l'appeler ». Il recoupe NetBuis sur le commerce de quartier, pas sur le coeur (recherche produit → appel). À ajouter à la liste Buyam, Youmbia, Offrir, Jumli, Kaymucm. À regarder: son nombre de commerçants et d'utilisateurs (non trouvé), et si la fonction « disponibilité d'un produit » apparaît plus tard.

## 2. Orchestration d'agents
Résultats génériques (Agentsway, zencoder, morphllm, sista.ai, datanorth): rien qui change la règle retenue: 1 agent principal + 1 à 2 relecteurs en lecture seule, 3 à 5 agents au maximum; ni 64 agents ni 10 agents de test.

## 3. Constat [A]
Passe 40: un seul élément nouveau en trois jours de passes, et il ne modifie aucune décision technique. Je maintiens la recommandation de la v39: suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0 (30 commerçants dans un quartier, mesure d'usage, seuil go/no-go). Décisions en attente de Jeff: canal WhatsApp, règle d'agents, compte développeur Android, méthode de gestion, quartier pilote, revenu sans commission, différence face à Buyam et Nkwel en une phrase.

## Sources
- [Nkwel app launched in Cameroon (Business in Cameroon)](https://www.businessincameroon.com/public-management/1203-15883-nkwel-app-launched-in-cameroon-to-digitalise-neighbourhood-commerce)
- [Agentsway (arXiv)](https://arxiv.org/pdf/2510.23664)
- [AI Agent Orchestration best practices (zencoder)](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)


---

<!-- source : audit-expert-v41-aucune-nouveaute-netbuis.md -->

# Audit expert v41 NetBuis (2026-10-07): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

## Passe
- Concurrents Cameroun (produit local, appel, WhatsApp): aucun nouvel entrant. Résultats hors sujet: Express Union mobile money via WhatsApp, une appli SecondMain237 sur l'App Store (seconde main, à vérifier si un jour pertinent), numérotation Camtel [S].
- Orchestration d'agents: guides génériques 2026 (zencoder, dev.to « orchestration trap », heuristiques tallorder). Rien qui change la règle retenue: 1 agent principal + 1 à 2 relecteurs, 3 à 5 agents au maximum; ni 64 agents ni 10 agents de test [S].
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39: les passes ne produisent que des confirmations. Le blocage n'est plus la recherche mais les décisions de Jeff (canal WhatsApp, règle d'agents, compte développeur Android avant 2027, méthode de gestion, quartier pilote, modèle de revenu, différence face à Buyam) et le jalon 0 (30 commerçants dans un quartier). Recommandation inchangée: suspendre ou passer cette routine en hebdomadaire.

## Sources
- [SecondMain237 (App Store)](https://apps.apple.com/app/id6749525599)
- [Express Union mobile money WhatsApp](https://www.digitalbusiness.africa/cameroun-express-union-lance-un-service-de-mobile-money-via-whatsapp)
- [6 AI Agent Orchestration Best Practices 2026 (zencoder)](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Orchestration trap (dev.to)](https://dev.to/arthicksdev/the-orchestration-trap-why-multi-agent-ai-fails-without-a-coordination-strategy-4p6b)
- [Heuristics for agent orchestration 2026](https://tallorder.bearblog.dev/heuristics-for-agent-orchestration-in-2026)


---

<!-- source : audit-expert-v42-aucune-nouveaute-netbuis.md -->

# Audit expert v42 NetBuis (2026-10-07): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents: guides génériques (Osmani Code Agent Orchestra, morphllm, tembo, amux, toolhalla). Aucun ne soutient 64 agents ni 10 agents de test. Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture [S].
- Concurrents Cameroun: Youmbia, SecondMain237, Visit My Business, Chekche (objets perdus). Aucun nouvel entrant sur « chercher un produit chez un commerçant proche + appel » [S].
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 et v41. Rapports de référence: rapport-orchestration-agents-ia-netbuis.md et rapport-methodes-gestion-projet-netbuis.md. Il reste à Jeff de choisir; recommandation inchangée: suspendre cette routine ou la passer en hebdomadaire.

## Sources
- [Multi Agent Orchestration Patterns](https://codex.danielvaughan.com/2026/05/18/multi-agent-orchestration-patterns/)
- [Addy Osmani Code Agent Orchestra](https://codex.danielvaughan.com/2026/05/14/addy-osmani-code-agent-orchestra/)
- [AI Agent Orchestration (morphllm)](https://www.morphllm.com/ai-agent-orchestration)
- [Multi-agent orchestration (tembo)](https://www.tembo.io/blog/multi-agent-orchestration)
- [Youmbia](https://mwm.ai/apps/youmbia/6774914586)


---

<!-- source : audit-expert-v43-aucune-nouveaute-netbuis.md -->

# Audit expert v43 NetBuis (2026-10-08): aucune nouveauté

[S] = source web; [A] = mon avis. Rien testé sur le terrain.

- Orchestration d'agents [S]: la recherche renvoie les mêmes guides (Microsoft Agent Framework 1.0, morphllm, tembo, zencoder, amux, dev.to « orchestration topology »). Aucun ne soutient 64 agents ni 10 agents de test. Règle inchangée: 1 agent principal + 1 à 2 relecteurs (ou superviseur + 3 à 5 au maximum), CI comme juge, humain sur argent, données et architecture.
- Mobile money Cameroun [S]: les articles Ecomatin remontés sont datés (nov. 2023 pour les plafonds Orange; oct. 2025 pour l'arrivée de Wave avec CBC, frais annoncés: dépôt/retrait gratuits, transfert max 1 %, et riposte Orange/MTN). Déjà connus (Wave/Camtel couverts en v25). Rien de 2026 qui change l'intégration: garder l'interface `PaymentProvider`, montants et plafonds paramétrables.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39, v41 et v42. Rapports de référence: rapport-orchestration-agents-ia-netbuis.md et rapport-methodes-gestion-projet-netbuis.md. Décisions en attente de Jeff (inchangées depuis v26): canal WhatsApp (wa.me gratuit), règle d'agents, inscription console développeur Android, méthode de gestion de projet, quartier pilote et 30 premiers commerçants. Recommandation: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification envoyée: rien d'urgent.

## Sources
- [Microsoft Agent Framework 1.0](https://devblogs.microsoft.com/agent-framework/microsoft-agent-framework-version-1-0/)
- [AI Agent Orchestration (morphllm)](https://www.morphllm.com/ai-agent-orchestration)
- [Orchestration topology (dev.to)](https://dev.to/terminalblog/orchestration-topology-is-the-new-bottleneck-in-agentic-coding-487g)
- [Wave / riposte Orange et MTN (Ecomatin, oct. 2025)](https://ecomatin.net/cameroun-comment-orange-et-mtn-preparent-leur-riposte-pour-contrer-loffensive-de-wave)
- [Orange Money plafonds (Ecomatin, nov. 2023)](https://ecomatin.net/mobile-money-orange-cameroun-abaisse-ses-tarifs-et-releve-les-plafonds-de-retrait)


---

<!-- source : audit-expert-v44-aucune-nouveaute-netbuis.md -->

# Audit expert v44 NetBuis (2026-10-08): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v43 (tembo, morphllm, dev.to « orchestration topology », getunblocked, claudefa.st). Rien qui soutienne 64 agents ni 10 agents de test. Règle inchangée: superviseur + 3 à 5 agents au maximum (ou 1 agent principal + 1 à 2 relecteurs au départ), CI comme juge, humain sur argent, données et architecture.
- Mobile money Cameroun [S]: résultats déjà vus (Ecomatin 2023, Kolonell 2026 sur frais Orange/MTN, allAfrica mars 2026 sur l'inclusion financière MTN). Rien de daté octobre 2026 qui change l'intégration: garder l'interface `PaymentProvider`, montants et plafonds paramétrables.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v43. Rapports de référence: rapport-orchestration-agents-ia-netbuis.md et rapport-methodes-gestion-projet-netbuis.md. Décisions toujours en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion de projet, quartier pilote et 30 premiers commerçants. Recommandation: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification envoyée: rien d'urgent.

## Sources
- [Tembo, agentic orchestration](https://www.tembo.io/blog/agentic-orchestration)
- [Morphllm, AI agent orchestration](https://www.morphllm.com/ai-agent-orchestration)
- [Orchestration topology (dev.to)](https://dev.to/terminalblog/orchestration-topology-is-the-new-bottleneck-in-agentic-coding-487g)
- [Kolonell, paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [allAfrica, MTN Cameroun inclusion financière](https://fr.allafrica.com/stories/202603310593.html)


---

<!-- source : audit-expert-v45-aucune-nouveaute-netbuis.md -->

# Audit expert v45 NetBuis (2026-10-08): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v39 à v44 (Addy Osmani « Code Agent Orchestra », morphllm, amux.io, dev.to « orchestration topology », un article Towards Data Science sur 100 agents avec Claude Code). Rien qui contredise la règle retenue: superviseur + 3 à 5 agents au maximum (ou 1 agent principal + 1 à 2 relecteurs au départ), CI comme juge, humain sur argent, données et architecture. Ni 64 agents ni 10 agents de test.
- Concurrents / lancements Cameroun [S]: aucun nouvel entrant (résultats hors sujet: WhatsApp commerce Kolonell, Chekche objets perdus, numérotation).
- Paiement mobile Cameroun [S]: mêmes articles Kolonell et allAfrica déjà vus, Moneroo (agrégateur) en plus; rien de daté octobre 2026 qui change l'intégration. Garder l'interface `PaymentProvider`.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v44. Références: rapport-orchestration-agents-ia-netbuis.md et rapport-methodes-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion de projet, quartier pilote et 30 premiers commerçants. Recommandation: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification envoyée: rien d'urgent.

## Sources
- [Addy Osmani, Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)
- [Towards Data Science, 100 agents avec Claude Code](https://towardsdatascience.com/how-to-orchestrate-100-agents-with-claude-code/)
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Orchestration topology (dev.to)](https://dev.to/terminalblog/orchestration-topology-is-the-new-bottleneck-in-agentic-coding-487g)
- [Moneroo, méthodes disponibles](https://docs.moneroo.io/fr/payments/methodes-disponibles)
- [Kolonell, paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : audit-expert-v46-aucune-nouveaute-netbuis.md -->

# Audit expert v46 NetBuis (2026-10-08): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v39 à v45 (Addy Osmani « Code Agent Orchestra », morphllm, amux.io), plus quelques comparatifs de plateformes (getunblocked, zencoder, tembo) et un rapport Belitsoft (entreprises: 12 agents en moyenne, la moitié travaillent isolés). Rien qui contredise la règle retenue: superviseur + 3 à 5 agents au maximum (ou 1 agent principal + 1 à 2 relecteurs au départ), CI comme juge, humain sur argent, données et architecture. Ni 64 agents ni 10 agents de test.
- Concurrents / lancements Cameroun [S]: aucun nouvel entrant (résultats hors sujet: Made in Cameroon, CFAO, commerçants vs industriels).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v45. Références: rapport-orchestration-agents-ia-netbuis.md et rapport-methodes-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion de projet, quartier pilote et 30 premiers commerçants. Recommandation: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification envoyée: rien d'urgent.

## Sources
- [Addy Osmani, Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [amux.io](https://amux.io/guides/ai-agent-orchestration-2026/)
- [Belitsoft via Barchart](https://www.barchart.com/story/news/1163379/belitsoft-report-2026-ai-agent-trends-enterprises-run-12-ai-agents-on-average-but-half-work-alone)
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)


---

<!-- source : audit-expert-v47-aucune-nouveaute-netbuis.md -->

# Audit expert v47 NetBuis (2026-10-08): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v39 à v46 (Addy Osmani « Code Agent Orchestra », morphllm, Towards Data Science « 100 agents », dev.to « orchestration topology », zencoder, GitHub Agent HQ). Rien qui soutienne 64 agents ni 10 agents de test. Règle inchangée: superviseur + 3 à 5 agents au maximum (ou 1 agent principal + 1 à 2 relecteurs au départ), CI comme juge, humain sur argent, données et architecture.
- Concurrents / lancements Cameroun [S]: aucun nouvel entrant (résultats hors sujet: appels d'offres, Business in Cameroon).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v46. Références: rapport-orchestration-agents-ia-netbuis.md et rapport-methodes-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion de projet, quartier pilote et 30 premiers commerçants. Recommandation: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification envoyée: rien d'urgent.

## Sources
- [Addy Osmani, Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Towards Data Science, 100 agents](https://towardsdatascience.com/how-to-orchestrate-100-agents-with-claude-code/)
- [Orchestration topology (dev.to)](https://dev.to/terminalblog/orchestration-topology-is-the-new-bottleneck-in-agentic-coding-487g)
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)


---

<!-- source : audit-expert-v48-aucune-nouveaute-netbuis.md -->

# Audit expert v48 NetBuis (2026-10-08): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: guides génériques déjà vus (Zencoder, Mastra, momen.app, testmuai, ibl.ai). Rien qui contredise la règle retenue: superviseur + 3 à 5 agents au maximum (ou 1 agent principal + 1 à 2 relecteurs au départ), CI comme juge, humain sur argent, données et architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / concurrents [S]: seulement l'actualité Camtel (entrée dans le mobile money), Orange Cameroun vs MTN, carte virtuelle MoMo, et des guides Kolonell sur le coût d'encaissement Orange Money. Aucun nouvel entrant direct (recherche produit local + appel).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v47. Références: rapport-orchestration-agents-ia-netbuis.md et rapport-methodes-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion de projet, quartier pilote et 30 premiers commerçants. Recommandation: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification envoyée: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Camtel et le mobile money (camer.be)](https://www.camer.be/93232/11:1/societe)
- [Orange Cameroun vs MTN (ITWeb)](https://itweb.africa/article/orange-cameroun-to-challenge-mtn-mobile-money-dominance/j5alrMQAZEgMpYQk)
- [Kolonell, coût d'encaissement Orange Money](https://kolonell.com/fr/blog/cout-reel-encaissement-orange-money-cameroun-commercant-2026)


---

<!-- source : audit-expert-v49-aucune-nouveaute-netbuis.md -->

# Audit expert v49 NetBuis (2026-10-08): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: guides génériques (Addy Osmani « Code Agent Orchestra », Zencoder, amux.io, Morph, Tembo). Rien qui contredise la règle retenue: superviseur + 3 à 5 agents au maximum (ou 1 agent principal + 1 à 2 relecteurs au départ), CI comme juge, humain sur argent, données et architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: résultats sur WhatsApp commerce et e-commerce (Kolonell), numérotation (digitalbusiness.africa), et une app de seconde main « SecondMain237 » (App Store) — marché de l'occasion, pas de recherche produit local + appel direct. À surveiller seulement.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v48. Références: rapport-orchestration-agents-ia-netbuis.md et rapport-methodes-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote et 30 premiers commerçants. Recommandation inchangée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Code Agent Orchestra (Addy Osmani)](https://addyosmani.com/blog/code-agent-orchestra/)
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [amux.io](https://amux.io/guides/ai-agent-orchestration-2026/)
- [Kolonell, WhatsApp commerce vs boutique](https://kolonell.com/fr/blog/whatsapp-commerce-vs-boutique-ecommerce-dediee-cameroun-2026)
- [SecondMain237 (App Store)](https://apps.apple.com/app/id6749525599)


---

<!-- source : audit-expert-v50-aucune-nouveaute-netbuis.md -->

# Audit expert v50 NetBuis (2026-10-08): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides génériques (Addy Osmani « Code Agent Orchestra », Zencoder, amux.io, Morph, Unblocked comparatif de plateformes, rapport Belitsoft « 12 agents en moyenne en entreprise, la moitié travaillent seuls »). Rien qui change la règle retenue: superviseur + 3 à 5 agents maximum (ou 1 agent principal + 1 à 2 relecteurs au départ), CI comme juge, humain sur argent, données et architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun concurrent nouveau « recherche produit local + appel direct » (résultats: actualité économique, annuaires, appels d'offres). 
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v49. Références: rapport-orchestration-agents-ia-netbuis.md et rapport-methodes-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote et 30 premiers commerçants. Recommandation inchangée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Code Agent Orchestra (Addy Osmani)](https://addyosmani.com/blog/code-agent-orchestra/)
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [amux.io](https://amux.io/guides/ai-agent-orchestration-2026/)
- [Unblocked, plateformes comparées](https://getunblocked.com/blog/ai-agent-orchestration-platforms-compared/index.md)
- [Belitsoft via Barchart](https://www.barchart.com/story/news/1163379/belitsoft-report-2026-ai-agent-trends-enterprises-run-12-ai-agents-on-average-but-half-work-alone)


---

<!-- source : audit-expert-v51-aucune-nouveaute-netbuis.md -->

# Audit expert v51 NetBuis (2026-10-08): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides génériques (Zencoder, Mastra, Momen, ibl.ai, fungies.io). Aucun changement à la règle retenue: superviseur + 3 à 5 agents maximum, CI comme juge, humain sur argent, données et architecture. Ni 64 agents ni 10 agents de test.
- Mobile money Cameroun [S]: articles kolonell.com (paysage paiement, coût d'intégration MTN MoMo / Orange Money 2026), baisse des tarifs de retrait Orange Cameroun (ecomatin). Déjà couverts par les addendums paiement; pas de changement d'API signalé.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v50. Références: rapport-orchestration-agents-ia-netbuis.md et rapport-methodes-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation inchangée: suspendre cette routine ou la passer en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Momen](https://momen.app/blogs/7-best-multi-agent-orchestration-tools-in-2026/)
- [Kolonell, paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Ecomatin, tarifs Orange Money Cameroun](https://ecomatin.net/mobile-money-orange-cameroun-abaisse-ses-tarifs-et-releve-les-plafonds-de-retrait)


---

<!-- source : audit-expert-v52-aucune-nouveaute-netbuis.md -->

# Audit expert v52 NetBuis (2026-10-08): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes sources que v51 (Zencoder, Mastra, fungies.io, Rasa, skycrumbs). Aucune nouvelle méthode. Règle retenue inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Mobile money Cameroun [S]: mêmes articles kolonell.com (frais, intégration MoMo/Orange Money 2026) et digitalbusiness.africa (seuils de retrait Orange). Pas de changement d'API signalé.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v51. Références: rapport-orchestration-agents-ia-netbuis.md et rapport-methodes-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Kolonell](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Digital Business Africa](https://www.digitalbusiness.africa/transfert-dargent-cameroun-orange-revoit-les-seuils-de-retrait-oma-la-hausse)


---

<!-- source : audit-expert-v53-aucune-nouveaute-netbuis.md -->

# Audit expert v53 NetBuis (2026-10-08): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes sources que v51-v52 (Zencoder, Mastra, fungies.io, rework.com, n-ix, momen.app). Aucune nouvelle méthode. Règle retenue inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Mobile money Cameroun [S]: uniquement des articles kolonell.com déjà vus. Aucun changement d'API signalé.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v52. Références: rapport-orchestration-agents-ia-netbuis.md et rapport-methodes-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.


---

<!-- source : audit-expert-v54-aucune-nouveaute-netbuis.md -->

# Audit expert v54 NetBuis (2026-10-08): aucune nouveauté

[S] = titres de résultats web (+1 article relu); [A] = mon avis.

- Orchestration d'agents [S]: mêmes sources (morphllm, zencoder, Addy Osmani « Code Agent Orchestra », amux, tembo, codemyspec). Aucune méthode nouvelle. Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Mobile money Cameroun [S]: article Ecomatin sur Wave/riposte Orange-MTN relu: daté du 8 oct. 2025 (pas 2026), déjà intégré en v25/v43 (Wave: dépôt/retrait gratuits, transfert 1 %; Orange retrait QR 1,5→1 %; MTN -25 % frais). Interopérabilité et super-apps côté opérateurs = concurrence potentielle, pas de changement d'API.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v53. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-expert-v33-synthese-consolidee-netbuis.md. Décisions en attente de Jeff: canal WhatsApp (wa.me gratuit), règle d'agents, compte développeur Android, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [AI Agent Orchestration (morphllm)](https://www.morphllm.com/ai-agent-orchestration)
- [The Code Agent Orchestra (Addy Osmani)](https://addyosmani.com/blog/code-agent-orchestra/)
- [Wave / riposte Orange et MTN (Ecomatin, 8 oct. 2025)](https://ecomatin.net/cameroun-comment-orange-et-mtn-preparent-leur-riposte-pour-contrer-loffensive-de-wave)


---

<!-- source : audit-expert-v55-aucune-nouveaute-netbuis.md -->

# Audit expert v55 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides génériques (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, testmuai). Rien de nouveau. Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / WhatsApp [S]: résultats génériques (Kolonell WhatsApp commerce 2026, WhatsApp shopping pour petits commerçants). Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v54. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-expert-v33-synthese-consolidee-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Unblocked](https://getunblocked.com/blog/ai-agent-orchestration-platforms-compared/index.md)
- [Kolonell, WhatsApp commerce Cameroun](https://kolonell.com/fr/blog/whatsapp-commerce-vs-boutique-ecommerce-dediee-cameroun-2026)


---

<!-- source : audit-expert-v56-aucune-nouveaute-netbuis.md -->

# Audit expert v56 NetBuis (2026-10-09): quasi aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides génériques (Zencoder, Mastra, ibl.ai, fungies.io, knowlee, momen). Rien de nouveau. Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: deux pistes à vérifier si pas déjà notées dans les addenda paiement: Camtel prépare son entrée dans le mobile money (concurrent possible de MTN/Orange, donc un 3e canal de paiement à terme), et Express Union propose du mobile money via WhatsApp (confirme que WhatsApp est un canal de paiement/commerce crédible au Cameroun). Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v55. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-expert-v33-synthese-consolidee-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Camtel et le mobile money](https://www.camer.be/93232/11:1/camtel-prepare-son-entree-dans-le-mobile-money-et-bouscule-mtn-et-orange-au-cameroun-cameroon.html)
- [Express Union mobile money via WhatsApp](https://www.digitalbusiness.africa/cameroun-express-union-lance-un-service-de-mobile-money-via-whatsapp)


---

<!-- source : audit-expert-v57-aucune-nouveaute-netbuis.md -->

# Audit expert v57 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, ibl.ai, momen, fungies.io). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: mêmes sources (Camtel mobile money, interview Wave Cameroun juil. 2026, MTN inclusion financière, carte virtuelle MoMo). Déjà couvertes (v25, v43, addendum 40).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v56. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-expert-v33-synthese-consolidee-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Wave Cameroun (Financial Afrik)](https://www.financialafrik.com/2026/07/23/entretien-avec-joel-bertrand-ndjodo-country-manager-de-wave-cameroun/)
- [Camtel et le mobile money](https://www.camer.be/93232/11:1/camtel-prepare-son-entree-dans-le-mobile-money-et-bouscule-mtn-et-orange-au-cameroun-cameroon.html)


---

<!-- source : audit-expert-v58-aucune-nouveaute-netbuis.md -->

# Audit expert v58 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, testmuai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / WhatsApp [S]: mêmes articles Kolonell, Chekche, rien de neuf. Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v57. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-expert-v33-synthese-consolidee-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Kolonell, WhatsApp commerce Cameroun](https://kolonell.com/fr/blog/whatsapp-commerce-vs-boutique-ecommerce-dediee-cameroun-2026)


---

<!-- source : audit-expert-v59-aucune-nouveaute-netbuis.md -->

# Audit expert v59 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, ibl.ai, fungies.io, momen). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Mobile money Cameroun [S]: mêmes articles (Ecomatin baisse tarifs Orange/MTN, Kolonell coûts d'intégration, digitalbusiness.africa). Aucun changement d'API ou de tarif daté d'octobre 2026.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v58. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-expert-v33-synthese-consolidee-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Kolonell, paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Ecomatin, Orange abaisse ses tarifs](https://ecomatin.net/mobile-money-orange-cameroun-abaisse-ses-tarifs-et-releve-les-plafonds-de-retrait)


---

<!-- source : audit-expert-v60-aucune-nouveaute-netbuis.md -->

# Audit expert v60 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, Unblocked, ibl.ai, fungies.io, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Mobile money Cameroun [S]: mêmes articles (Ecomatin, Kolonell x4, digitalbusiness.africa, kamerpower). Aucun changement d'API ou de tarif daté d'octobre 2026.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v59. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-expert-v33-synthese-consolidee-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Kolonell, paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Ecomatin, Orange abaisse ses tarifs](https://ecomatin.net/mobile-money-orange-cameroun-abaisse-ses-tarifs-et-releve-les-plafonds-de-retrait)


---

<!-- source : audit-expert-v61-aucune-nouveaute-netbuis.md -->

# Audit expert v61 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, Ayesa, testmuai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / WhatsApp [S]: mêmes articles (Kolonell WhatsApp commerce 2026, WhatsApp shopping petits commerçants). Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v60. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-expert-v33-synthese-consolidee-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Unblocked](https://getunblocked.com/blog/ai-agent-orchestration-platforms-compared/index.md)
- [Kolonell, WhatsApp commerce Cameroun](https://kolonell.com/fr/blog/whatsapp-commerce-vs-boutique-ecommerce-dediee-cameroun-2026)


---

<!-- source : audit-expert-v62-aucune-nouveaute-netbuis.md -->

# Audit expert v62 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, ibl.ai, fungies.io, Knowlee, Momen, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / paiement [S]: mêmes thèmes (Camtel mobile money, Express Union via WhatsApp, carte virtuelle Momo, entretien Wave Cameroun juillet 2026). Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v61. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-expert-v33-synthese-consolidee-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.


---

<!-- source : audit-expert-v63-aucune-nouveaute-netbuis.md -->

# Audit expert v63 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, Ayesa, testmuai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / paiement [S]: mêmes thèmes (Camtel mobile money, Express Union via WhatsApp, Orange vs MTN, Kolonell). Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v62. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-expert-v33-synthese-consolidee-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.


---

<!-- source : audit-expert-v64-aucune-nouveaute-netbuis.md -->

# Audit expert v64 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: Made in Cameroon, CFAO).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v63. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.


---

<!-- source : audit-expert-v65-aucune-nouveaute-netbuis.md -->

# Audit expert v65 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, ibl.ai, fungies.io, momen.app, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Seuls articles généraux MoMo/Orange Money/Camtel, déjà connus.
- WhatsApp [S]: facturation des réponses API depuis le 1er octobre 2026, déjà traitée en v26/v33 (wa.me gratuit par défaut).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v64. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.


---

<!-- source : audit-expert-v66-aucune-nouveaute-netbuis.md -->

# Audit expert v66 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v65 (Zencoder, Mastra, ibl.ai, fungies.io, knowlee, momen.app, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Seuls articles généraux MoMo/Orange Money déjà connus.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v65. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.


---

<!-- source : audit-expert-v67-aucune-nouveaute-netbuis.md -->

# Audit expert v67 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes familles de guides (metacto, knowlee, toolhalla, arahi, toolradar, lucaberton, boomi, ucstrategies). Aucun fait neuf. Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: mêmes articles MoMo/Orange Money/Camtel déjà connus (carte virtuelle Momo, lutte contre la fraude, Camtel mobile money, kolonell intégration MoMo). Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v66. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.


---

<!-- source : audit-expert-v68-aucune-nouveaute-netbuis.md -->

# Audit expert v68 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, Ayesa, testmuai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: Made in Cameroon, commerçants vs industriels).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v67. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.


---

<!-- source : audit-expert-v69-aucune-nouveaute-netbuis.md -->

# Audit expert v69 NetBuis (2026-10-09): aucune nouveauté décisive

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: littérature académique récente (SPOQ « Specialist Orchestrated Queuing », Agentsway, « Rethinking Software Engineering for Agentic AI Systems », Microsoft AI agent design patterns). Aucune ne contredit la règle retenue: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test. Pistes à lire si Jeff veut approfondir: SPOQ (file d'attente de spécialistes) et Agentsway (méthodologie pour équipes d'agents).
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Seules actualités: MoMo carte virtuelle, lutte anti-fraude MoMo, Fala Mobile Money (paiement), rien de concurrent direct.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v68. Décisions toujours en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire et lancer le jalon 0. Rapports de référence: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Aucune notification: rien d'urgent.

## Sources
- [SPOQ (arXiv)](https://arxiv.org/pdf/2606.03115)
- [Agentsway (arXiv)](https://arxiv.org/pdf/2510.23664)
- [Rethinking Software Engineering for Agentic AI Systems](https://arxiv.org/pdf/2604.10599)
- [Microsoft AI agent design patterns](https://learn.microsoft.com/azure/architecture/ai-ml/guide/ai-agent-design-patterns)


---

<!-- source : audit-expert-v70-aucune-nouveaute-netbuis.md -->

# Audit expert v70 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, Towards AI, Akka, knowlee, toolhalla, lucaberton, fast.io). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: Camtel distributeurs, Chekche objets perdus, CFAO).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v69. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Towards AI](https://pub.towardsai.net/multi-agent-systems-done-right-af91ac04edc4)
- [Chekche (Business in Cameroon)](https://www.businessincameroon.com/ict/1402-6897-cameroonian-start-up-cdi-sarl-launches-chekche-an-app-to-find-objects-you-have-lost)


---

<!-- source : audit-expert-v71-aucune-nouveaute-netbuis.md -->

# Audit expert v71 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Momen, levelup, nuilab, agentsroom, fungies). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: made in Cameroon, commerçants/industriels).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v70. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Momen](https://momen.app/blogs/7-best-multi-agent-orchestration-tools-in-2026/)
- [nuilab](https://agenticai.nuilab.org/patterns/multi-agent-orchestration/)


---

<!-- source : audit-expert-v72-aucune-nouveaute-netbuis.md -->

# Audit expert v72 NetBuis (2026-10-09): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, levelup, Mastra, Momen, fungies, Ayesa, klu). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: seul résultat pertinent = Nkwel (déjà analysé en v40), plus Youmbia, Chekche, hors sujet. Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v71. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Nkwel (Business in Cameroon)](https://www.businessincameroon.com/public-management/1203-15883-nkwel-app-launched-in-cameroon-to-digitalise-neighbourhood-commerce)


---

<!-- source : audit-expert-v73-aucune-nouveaute-netbuis.md -->

# Audit expert v73 NetBuis (2026-10-10): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (n-ix LangGraph/CrewAI/AutoGen, fungies, gocodeo, truefoundry, Google ADK sur dev.to). Rien de nouveau. Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / concurrence [S]: aucun nouvel entrant « recherche produit local + appel direct ». Résultats = blogs Kolonell (WhatsApp commerce vs boutique dédiée, e-commerce Orange Money/MTN), Chekche (hors sujet).
- Paiement [S]: Kolonell (paysage, coût d'intégration, Orange Money Web Payment), ecomatin (Orange Cameroun baisse ses tarifs et relève les plafonds de retrait, déjà connu), digitalbusiness.africa. Aucun changement d'API détecté.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v72. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [n-ix](https://www.n-ix.com/langgraph-vs-crewai-vs-autogen/)
- [fungies](https://fungies.io/multi-agent-orchestration-frameworks-2026/)
- [Kolonell — WhatsApp commerce vs boutique](https://kolonell.com/fr/blog/whatsapp-commerce-vs-boutique-ecommerce-dediee-cameroun-2026)
- [Ecomatin — Orange Money tarifs](https://ecomatin.net/mobile-money-orange-cameroun-abaisse-ses-tarifs-et-releve-les-plafonds-de-retrait)


---

<!-- source : audit-expert-v74-aucune-nouveaute-netbuis.md -->

# Audit expert v74 NetBuis (2026-10-10): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: guides Addy Osmani (Code Agent Orchestra), morphllm, tembo, amux, toolhalla, verdent. Rien de nouveau. Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / concurrence [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats: Made in Cameroon, CFAO, allAfrica, hors sujet).
- Paiement [S]: uniquement les blogs Kolonell déjà connus (Orange Money Web Payment, coûts MoMo). Aucun changement d'API détecté.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v73. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre la routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Addy Osmani — Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)
- [amux.io — AI Agent Orchestration 2026](https://amux.io/guides/ai-agent-orchestration-2026/)
- [Kolonell — Paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : audit-expert-v75-aucune-nouveaute-netbuis.md -->

# Audit expert v75 NetBuis (2026-10-10): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: guides génériques 2026 (zencoder, toolradar, fungies, levelup, GitHub Agent HQ). Rien qui contredise la règle retenue: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / concurrence [S]: aucun nouvel entrant « recherche produit local + appel direct ». Résultats: Camtel, blogs Kolonell (WhatsApp commerce vs boutique, e-commerce Orange Money/MoMo), Chekche (objets perdus, hors sujet).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v74. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre la routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder — AI Agent Orchestration Best Practices](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Toolradar — AI agent orchestration guide](https://toolradar.com/blog/ai-agent-orchestration-guide)
- [Kolonell — WhatsApp commerce vs boutique Cameroun](https://kolonell.com/fr/blog/whatsapp-commerce-vs-boutique-ecommerce-dediee-cameroun-2026)


---

<!-- source : audit-expert-v76-aucune-nouveaute-netbuis.md -->

# Audit expert v76 NetBuis (2026-10-10): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides génériques 2026 (zencoder, mastra, momen, fungies, ibl.ai). Rien ne soutient 64 agents ni 10 agents de test. Règle retenue inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture.
- Mobile money / concurrence Cameroun [S]: carte virtuelle MoMo (allAfrica, fév. 2026), lutte anti-fraude MoMo (sept. 2025), entrée de Camtel, riposte à Wave (oct. 2025). Tout est déjà couvert (v25, v43, v54). Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v75. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-expert-v33-synthese-consolidee-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre la routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder — AI Agent Orchestration Best Practices](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra — AI agent orchestration](https://mastra.ai/articles/ai-agent-orchestration)
- [allAfrica — carte virtuelle Momo](https://fr.allafrica.com/stories/202602040622.html)


---

<!-- source : audit-expert-v77-aucune-nouveaute-netbuis.md -->

# Audit expert v77 NetBuis (2026-10-10): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (morphllm, Zencoder, Addy Osmani, Mastra, amux.io, fungies.io, codewithandrea). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: Camtel Blue, Chekche, vitrine gouvernementale des produits locaux, un listing d'appli « youmbia » non vérifié).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v76. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre la routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Addy Osmani, Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)


---

<!-- source : audit-expert-v78-aucune-nouveaute-netbuis.md -->

# Audit expert v78 NetBuis (2026-10-10): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, Ayesa, testmuai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: Made in Cameroon, commerçants vs industriels, Trésor français).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v77. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre la routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Unblocked](https://getunblocked.com/blog/ai-agent-orchestration-platforms-compared/index.md)


---

<!-- source : audit-expert-v79-aucune-nouveaute-netbuis.md -->

# Audit expert v79 NetBuis (2026-10-10): aucune nouveauté structurante

[S] = source web lue; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Morph, Zencoder, Addy Osmani « Code Agent Orchestra », Unblocked, amux.io, dev.to « orchestration topology »). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Paiement Cameroun [S]: ecomatin (Orange baisse tarifs / relève plafonds) date en réalité de novembre 2023 (retrait 1,5 % plafonné à 3 500 FCFA; plafond hebdo 5 M, mensuel 10 M): déjà connu, à revérifier chez Orange avant de fixer les limites.
- WhatsApp [S, avis Twilio]: précision déjà proche de v26/v33. Depuis le 1er octobre 2026, messages de service payants après 1 000 gratuits/mois/numéro, et messages « utility » envoyés dans la fenêtre de 24 h redevenus payants (gratuits depuis juillet 2025). Marketing/authentification et entrées via pubs Click-to-WhatsApp inchangés. Aucun tarif Cameroun publié dans l'avis. [A] Conclusion inchangée: wa.me gratuit par défaut; ne pas planifier de notifications automatiques via l'API sans ligne budgétaire.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v78. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre la routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Twilio — Changes to WhatsApp's Pricing October 2026](https://support.twilio.com/hc/en-us/articles/53100462475931-Notice-Changes-to-WhatsApp-s-Pricing-October-2026)
- [Ecomatin — Orange Money Cameroun (nov. 2023)](https://ecomatin.net/mobile-money-orange-cameroun-abaisse-ses-tarifs-et-releve-les-plafonds-de-retrait)
- [Addy Osmani — The Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)


---

<!-- source : audit-expert-v80-aucune-nouveaute-netbuis.md -->

# Audit expert v80 NetBuis (2026-10-10): aucune nouveauté structurante

[S] = source web lue (résultats de recherche); [A] = mon avis.

- Orchestration d'agents [S]: mêmes sources que v79 (Morph, Zencoder, Unblocked, amux.io, Addy Osmani « Code Agent Orchestra », Tembo, Belitsoft: entreprises ~12 agents en moyenne, la moitié travaillent isolés). [A] Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents, ni 10 agents de test.
- Paiement Cameroun [S]: seuls des articles de blog d'intégrateurs (kolonell.com: paysage MoMo/Orange 2026, coûts d'intégration, plafonds). Rien de nouveau côté API officielle. [A] Campay reste la décision (voir decision-campay-netbuis.md); revérifier plafonds/frais auprès d'Orange et MTN avant de les fixer dans l'app.
- Google Play [S]: cible Android 16 (API 36) exigée d'ici le 31 août 2026 pour les nouvelles apps/mises à jour; vérification des développeurs Android (blog Android Developers, juin 2026). Déjà couvert par v14, v23, v24. [A] Prévoir le compte développeur vérifié tôt (délai incompressible).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v79. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions toujours en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Unblocked — Orchestration platforms compared](https://getunblocked.com/blog/ai-agent-orchestration-platforms-compared/index.md)
- [Morph — AI agent orchestration](https://www.morphllm.com/ai-agent-orchestration)
- [Zencoder — best practices](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Addy Osmani — The Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)
- [Belitsoft via Barchart — 12 agents en moyenne](https://www.barchart.com/story/news/1163379/belitsoft-report-2026-ai-agent-trends-enterprises-run-12-ai-agents-on-average-but-half-work-alone)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Android Developers Blog — Developer verification (juin 2026)](https://android-developers.googleblog.com/2026/06/android-developer-verification.html)


---

<!-- source : audit-expert-v81-aucune-nouveaute-netbuis.md -->

# Audit expert v81 NetBuis (2026-10-10): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v80 (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: Made in Cameroon, commerçants vs industriels, CFAO).
- Paiement mobile [S]: uniquement les articles Kolonell déjà connus. Rien de nouveau côté API officielle. Campay reste la décision.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v80. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Unblocked](https://getunblocked.com/blog/ai-agent-orchestration-platforms-compared/index.md)
- [Kolonell, paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : audit-expert-v82-aucune-nouveaute-netbuis.md -->

# Audit expert v82 NetBuis (2026-10-10): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, ibl.ai, fungies.io, BairesDev) + un papier arXiv 2604.10599 « Rethinking Software Engineering for Agentic AI Systems » et un article SoftwareSeni sur GitHub Agent HQ, non lus en détail. Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: Made in Cameroon, commerçants vs industriels, Chekche objets perdus, CFAO).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v81. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [arXiv 2604.10599](https://arxiv.org/pdf/2604.10599)


---

<!-- source : audit-expert-v83-aucune-nouveaute-netbuis.md -->

# Audit expert v83 NetBuis (2026-10-10): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, Ayesa, testmuai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: commerçants vs industriels, Made in Cameroon).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v82. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [allAfrica](https://fr.allafrica.com/stories/202601200534.html)


---

<!-- source : audit-expert-v84-aucune-nouveaute-netbuis.md -->

# Audit expert v84 NetBuis (2026-10-10): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Paiement mobile Cameroun [S]: seuls des guides génériques (kolonell.com: paysage MoMo/Orange, coûts, délais de règlement, plafonds). Aucune annonce nouvelle d'API marchand.
- Vérification développeur Android [S]: mêmes sources (developer.android.com/developer-verification, blog Android Developers juin 2026, bayton.org). Rien de nouveau.
- Orchestration d'agents et gestion de projet: inchangé depuis v39-v83.

## Constat [A]
Saturation confirmée. Règle d'agents inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture; pas 64 agents ni 10 agents de test. Méthode: Scrumban léger / Scrum augmenté / Shape Up (voir rapport-methodes-gestion-projet-netbuis.md, rapport-orchestration-agents-ia-netbuis.md).

Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine (ou hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [kolonell](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Android developer verification](https://developer.android.com/developer-verification)


---

<!-- source : audit-expert-v85-aucune-nouveaute-netbuis.md -->

# Audit expert v85 NetBuis (2026-10-10): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (morphllm, zencoder, unblocked, Addy Osmani, tembo, amux, codemyspec). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Concurrents Cameroun [S]: Youmbia, SecondMain237, Nevo Market, Kolonell (WhatsApp commerce): déjà vus (v38, v42). Aucun nouvel entrant.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine (ou hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Addy Osmani, Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)
- [Youmbia](https://mwm.ai/apps/youmbia/6774914586)


---

<!-- source : audit-expert-v86-aucune-nouveaute-netbuis.md -->

# Audit expert v86 NetBuis (2026-10-10): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Unblocked, Mastra, fungies.io, gend.co, Ayesa, aiindigo). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: Made in Cameroon, commerçants vs industriels).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v85. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine (ou hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Unblocked](https://getunblocked.com/blog/ai-agent-orchestration-platforms-compared/index.md)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Ayesa](https://ayesa-digital.com/en/insight/the-era-of-ai-agent-orchestration-taking-artificial-intelligence-to-the-next-level/)


---

<!-- source : audit-expert-v87-aucune-nouveaute-netbuis.md -->

# Audit expert v87 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (morphllm, Zencoder, Addy Osmani, Mastra, amux, fungies.io, Ayesa, codewithandrea). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: seulement Camtel/Blue Money, Wave, Orange vs MTN mobile money: déjà couverts (v25, v57). Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v86. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine (ou hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Addy Osmani, Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Camtel et le mobile money](https://www.camer.be/93232/11:1/camtel-prepare-son-entree-dans-le-mobile-money-et-bouscule-mtn-et-orange-au-cameroun-cameroon.html)


---

<!-- source : audit-expert-v88-aucune-nouveaute-netbuis.md -->

# Audit expert v88 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (morphllm, Zencoder, Addy Osmani, Mastra, amux, fungies.io, codewithandrea). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: seulement Camtel (distributeurs Blue), CFAO, app Chekche (objets perdus, hors sujet). Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v87. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine (ou hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Addy Osmani](https://addyosmani.com/blog/code-agent-orchestra/)
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Chekche](https://www.businessincameroon.com/ict/1402-6897-cameroonian-start-up-cdi-sarl-launches-chekche-an-app-to-find-objects-you-have-lost)


---

<!-- source : audit-expert-v89-aucune-nouveaute-netbuis.md -->

# Audit expert v89 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (morphllm, Addy Osmani, amux.io, fungies.io, codewithandrea, agentsroom) + allstacks « The Orchestration Gap » (rapport Anthropic, non lu en détail). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: Camtel Blue, Chekche (hors sujet), Index Cameroun (vc4a) et une appli iOS « SecondMain237 » (seconde main, non vérifiée). Aucun entrant « recherche produit local + appel direct » confirmé.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v88. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine (ou hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Addy Osmani](https://addyosmani.com/blog/code-agent-orchestra/)
- [allstacks](https://allstacks.com/blog/the-orchestration-gap-what-anthropics-report-means-for-engineering-leaders)
- [SecondMain237](https://apps.apple.com/app/id6749525599)


---

<!-- source : audit-expert-v90-aucune-nouveaute-netbuis.md -->

# Audit expert v90 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, ibl.ai, fungies.io, knowlee, momen.app, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: Camtel Blue, Chekche, SecondMain237, Index Cameroun (déjà vus) + une fiche « Youmbia » (mwm.ai, non ouverte, nature inconnue: à vérifier si place de marché). Aucun entrant « recherche produit local + appel direct » confirmé.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v89. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine (ou hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Youmbia (mwm.ai)](https://mwm.ai/apps/youmbia/6774914586)


---

<!-- source : audit-expert-v91-aucune-nouveaute-netbuis.md -->

# Audit expert v91 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v90 (Zencoder, fungies.io, MindStudio, sista.ai, Azure Cloud Adoption Framework "single agent vs multiple agents", videosdk, nuilab). Aucun chiffre sérieux justifiant 64 agents ni 10 agents de test. Règle inchangée [A]: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture.
- Cameroun [S]: Camtel Blue, SecondMain237, Youmbia (mwm.ai), annonce Codeur.com. Aucun entrant « recherche produit local + appel direct » confirmé.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v90. Rapports de référence: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Azure CAF](https://star-sa1.southeastasia.cloudapp.azure.com/en-us/azure/cloud-adoption-framework/ai-agents/single-agent-multiple-agents)
- [Youmbia (mwm.ai)](https://mwm.ai/apps/youmbia/6774914586)


---

<!-- source : audit-expert-v92-aucune-nouveaute-netbuis.md -->

# Audit expert v92 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que les passes précédentes (Addy Osmani « Code Agent Orchestra », morphllm, amux.io, Tembo, Verdent, toolhalla, agentsroom). Règle inchangée: superviseur + 3 à 5 agents au maximum (ou 1 agent principal + 1 à 2 relecteurs au départ), CI comme juge, humain sur argent, données et architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Résultats hors sujet ou déjà vus (Camtel, Youmbia/SecondMain237 petites annonces, Chekche objets perdus, article allAfrica commerçants/industriels). À garder à l'œil: Youmbia et SecondMain237 (annonces), non analysés.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v91. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Addy Osmani, Code Agent Orchestra](https://codex.danielvaughan.com/2026/05/14/addy-osmani-code-agent-orchestra/)
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [amux.io](https://amux.io/guides/ai-agent-orchestration-2026/)
- [Tembo](https://www.tembo.io/blog/multi-agent-orchestration)
- [Youmbia (App Store ranking)](https://mwm.ai/apps/youmbia/6774914586)
- [SecondMain237](https://apps.apple.com/app/id6749525599)


---

<!-- source : audit-expert-v93-aucune-nouveaute-netbuis.md -->

# Audit expert v93 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, fungies.io, nuilab, videosdk, mindstudio, sista.ai, Azure Cloud Adoption Framework « single agent vs multiple agents »). Règle inchangée: superviseur + 3 à 5 agents au maximum (ou 1 agent principal + 1 à 2 relecteurs au départ), CI comme juge, humain sur argent, données et architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Résultats déjà vus (Youmbia, SecondMain237, Chekche, CFAO, plateforme gouvernementale de promotion des produits locaux via wearetech.africa, jamais analysée en détail, à surveiller comme éventuel acteur institutionnel).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v92. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Azure CAF, single vs multiple agents](https://star-sa1.southeastasia.cloudapp.azure.com/en-us/azure/cloud-adoption-framework/ai-agents/single-agent-multiple-agents)
- [wearetech.africa, plateforme produits locaux](https://www.wearetech.africa/fr/fils/breves/breves-une/cameroun-le-gouvernement-lance-une-plateforme-numerique-pour-promouvoir-les-produits-locaux)
- [Youmbia](https://mwm.ai/apps/youmbia/6774914586)


---

<!-- source : audit-expert-v94-aucune-nouveaute-netbuis.md -->

# Audit expert v94 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (mindstudio, Zencoder, sista.ai, fungies.io, Azure CAF « single agent vs multiple agents », videosdk, nuilab). Règle inchangée: superviseur + 3 à 5 agents au maximum, CI comme juge, humain sur argent, données et architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (Camtel Blue, Chekche, Index Cameroun, CFAO: hors sujet ou déjà vus).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v93. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Azure CAF, single vs multiple agents](https://star-sa1.southeastasia.cloudapp.azure.com/en-us/azure/cloud-adoption-framework/ai-agents/single-agent-multiple-agents)
- [mindstudio](https://www.mindstudio.ai/blog/scaling-ai-agents-best-practices-multi-bot-deployment)


---

<!-- source : audit-expert-v95-aucune-nouveaute-netbuis.md -->

# Audit expert v95 NetBuis (2026-10-11): aucune nouveauté de fond

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes sources (Zencoder, Addy Osmani « Code Agent Orchestra », morphllm « Agent Teams », amux, fungies, Unblocked). Rien qui change la règle: superviseur + 3 à 5 agents, CI comme juge, humain sur argent, données, architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / mobile money [S]: article financialafrik du 2026-10-08 (MTN MoMo réduit son retard sur Orange Money en 2025) : contexte de marché, utile pour justifier le support des DEUX opérateurs, sans impact sur le plan. Camtel mobile money et carte virtuelle MoMo: déjà vus (v25).
- Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v94. Rapports de référence: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, netbuis-decisions-et-points-ouverts.md. Décisions toujours en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Addy Osmani, Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)
- [Financial Afrik, MTN MoMo vs Orange Money](https://www.financialafrik.com/2026/10/08/cameroun-en-2025-mtn-mobile-money-reduit-son-retard-sur-le-leader-orange-money/)


---

<!-- source : audit-expert-v96-aucune-nouveaute-netbuis.md -->

# Audit expert v96 NetBuis (2026-10-11): aucune nouveauté de fond

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes sources (Zencoder, Mastra, levelup, momen, fungies, Ayesa, klu). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / mobile money [S]: Camtel (entrée mobile money), Express Union via WhatsApp, carte virtuelle MoMo, MTN inclusion financière: tous déjà vus (addendum 92, v25, v56). Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v95. Rapports de référence: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, netbuis-decisions-et-points-ouverts.md. Décisions toujours en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Express Union via WhatsApp](https://www.digitalbusiness.africa/cameroun-express-union-lance-un-service-de-mobile-money-via-whatsapp)
- [Camtel mobile money](https://www.camer.be/93232/11:1/camtel-prepare-son-entree-dans-le-mobile-money-et-bouscule-mtn-et-orange-au-cameroun-cameroon.html)


---

<!-- source : audit-expert-v97-aucune-nouveaute-netbuis.md -->

# Audit expert v97 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, Ayesa, getcoai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: Made in Cameroon, commerçants vs industriels).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v96. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, netbuis-decisions-et-points-ouverts.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Ayesa](https://ayesa-digital.com/en/insight/the-era-of-ai-agent-orchestration-taking-artificial-intelligence-to-the-next-level/)


---

<!-- source : audit-expert-v98-aucune-nouveaute-netbuis.md -->

# Audit expert v98 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, getcoai, Unblocked, ibl.ai, fungies.io, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: allAfrica commerçants vs industriels, CFAO Made in Cameroon).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Même conclusion que v39 à v97. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, netbuis-decisions-et-points-ouverts.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Ayesa](https://ayesa-digital.com/en/insight/the-era-of-ai-agent-orchestration-taking-artificial-intelligence-to-the-next-level/)


---

<!-- source : audit-expert-v99-aucune-nouveaute-netbuis.md -->

# Audit expert v99 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, ibl.ai, fungies.io, knowlee, momen, Ayesa 30 juin 2026). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: Camtel Blue, Chekche, Index Cameroun, appli « youmbia » non vérifiée).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v98. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Ayesa](https://ayesa-digital.com/en/insight/the-era-of-ai-agent-orchestration-taking-artificial-intelligence-to-the-next-level/)


---

<!-- source : audit-expert-v100-aucune-nouveaute-netbuis.md -->

# Audit expert v100 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v99 (Zencoder, Mastra, ibl.ai, fungies.io, knowlee, momen, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: allAfrica, Index Cameroun, CFAO, Made in Cameroon).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v99. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Ayesa](https://ayesa-digital.com/en/insight/the-era-of-ai-agent-orchestration-taking-artificial-intelligence-to-the-next-level/)


---

<!-- source : audit-expert-v101-aucune-nouveaute-netbuis.md -->

# Audit expert v101 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v100 (Morphllm, Zencoder, Osmani, Mastra, amux, fungies, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: allAfrica, Made in Cameroon, Trésor).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v100. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Addy Osmani](https://addyosmani.com/blog/code-agent-orchestra/)


---

<!-- source : audit-expert-v102-aucune-nouveaute-netbuis.md -->

# Audit expert v102 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v101 (Zencoder, Mastra, amux, fungies, datanorth, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Résultats connus: Momo carte virtuelle (allAfrica), Camtel mobile money, Orange comptes avec puces concurrentes, Kolonell (intégration MoMo e-commerce).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v101. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, netbuis-decisions-et-points-ouverts.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [amux](https://amux.io/guides/ai-agent-orchestration-2026/)
- [allAfrica Momo](https://fr.allafrica.com/stories/202602040622.html)
- [Camtel mobile money](https://www.camer.be/93232/11:1/camtel-prepare-son-entree-dans-le-mobile-money-et-bouscule-mtn-et-orange-au-cameroun-cameroon.html)


---

<!-- source : audit-expert-v103-aucune-nouveaute-netbuis.md -->

# Audit expert v103 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v102 (Zencoder, Mastra, fungies, ibl.ai, Unblocked, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: commerçants vs industriels, CFAO Made in Cameroon, prix Made in Cameroon 2026).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v102. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, netbuis-decisions-et-points-ouverts.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Ayesa](https://ayesa-digital.com/en/insight/the-era-of-ai-agent-orchestration-taking-artificial-intelligence-to-the-next-level/)
- [allAfrica, commerçants vs industriels](https://fr.allafrica.com/stories/202601200534.html)


---

<!-- source : audit-expert-v104-aucune-nouveaute-netbuis.md -->

# Audit expert v104 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v103 (Zencoder, Mastra, fungies, ibl.ai, Unblocked, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: commerçants vs industriels, Made in Cameroon).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v103. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, netbuis-decisions-et-points-ouverts.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [allAfrica, commerçants vs industriels](https://fr.allafrica.com/stories/202601200534.html)


---

<!-- source : audit-expert-v105-aucune-nouveaute-netbuis.md -->

# Audit expert v105 NetBuis (2026-10-11): aucune nouveauté décisive

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes familles de guides (Zencoder, Unblocked, Morph, amux, Addy Osmani « Code Agent Orchestra », article dev.to « orchestration topology is the new bottleneck »). Aucun fait qui change la règle: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: titre financialafrik du 2026-10-08 « MTN Mobile Money réduit son retard sur Orange Money » (à lire si on arbitre l'ordre d'intégration MTN/Orange; non lu en entier). Carte virtuelle MoMo, Camtel qui prépare son entrée dans le mobile money: déjà connus (v25). Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v104. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, netbuis-decisions-et-points-ouverts.md. Décisions toujours en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Addy Osmani, Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)
- [dev.to, orchestration topology](https://dev.to/terminalblog/orchestration-topology-is-the-new-bottleneck-in-agentic-coding-487g)
- [Financial Afrik, MTN MoMo vs Orange Money](https://www.financialafrik.com/2026/10/08/cameroun-en-2025-mtn-mobile-money-reduit-son-retard-sur-le-leader-orange-money/)


---

<!-- source : audit-expert-v106-aucune-nouveaute-netbuis.md -->

# Audit expert v106 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Morphllm, Zencoder, Addy Osmani, Mastra, amux, fungies, codewithandrea). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: Express Union (mobile money via WhatsApp), carte virtuelle MoMo, Camtel mobile money, UBA: déjà connus. Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation, identique à v39-v105. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, netbuis-decisions-et-points-ouverts.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine (ou hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Addy Osmani](https://addyosmani.com/blog/code-agent-orchestra/)
- [Express Union WhatsApp](https://www.digitalbusiness.africa/cameroun-express-union-lance-un-service-de-mobile-money-via-whatsapp)


---

<!-- source : audit-expert-v107-aucune-nouveaute-netbuis.md -->

# Audit expert v107 NetBuis (2026-10-11): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes sources que v106 (Morphllm, Addy Osmani, Zencoder, amux, fungies, Unblocked, Tembo). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Mobile money Cameroun [S]: MTN (agrément d'établissement de paiement), guides Kolonell d'intégration MoMo/Orange Money: déjà connus. Aucun changement d'API repéré.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Saturation identique à v39-v106. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, netbuis-decisions-et-points-ouverts.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Addy Osmani](https://addyosmani.com/blog/code-agent-orchestra/)
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Kolonell, paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Journal du Cameroun, agrément MTN](https://fr.journalducameroun.com/cameroun-apres-orange-mtn-obtient-son-agrement-detablissement-de-paiement/)


---

<!-- source : audit-expert-v108-aucune-nouveaute-netbuis.md -->

# Audit expert v108 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, Ayesa, testmuai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: Made in Cameroon, CFAO, commerçants vs industriels).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v107. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Unblocked](https://getunblocked.com/blog/ai-agent-orchestration-platforms-compared/index.md)


---

<!-- source : audit-expert-v109-aucune-nouveaute-netbuis.md -->

# Audit expert v109 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, fungies.io, momen.app, levelup/gitconnected, agentsroom). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Seuls résultats: articles généraux paiement mobile (carte virtuelle MoMo, Camtel qui prépare son mobile money, coût d'encaissement Orange Money) déjà couverts par les addendums paiement.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v108. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, netbuis-decisions-et-points-ouverts.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [momen.app](https://momen.app/blogs/7-best-multi-agent-orchestration-tools-in-2026/)
- [Kolonell: coût réel Orange Money](https://kolonell.com/fr/blog/cout-reel-encaissement-orange-money-cameroun-commercant-2026)


---

<!-- source : audit-expert-v110-aucune-nouveaute-netbuis.md -->

# Audit expert v110 NetBuis (2026-10-12): aucune nouveauté majeure

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, levelup/gitconnected, Mastra, momen.app, fungies.io, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Seule info marché récente: Financial Afrik (08/10/2026) indique qu'en 2025 MTN Mobile Money réduit son retard sur Orange Money. Confirme l'intérêt de supporter les deux opérateurs; pas de changement de conception.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v109. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, netbuis-decisions-et-points-ouverts.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Financial Afrik, 08/10/2026](https://www.financialafrik.com/2026/10/08/cameroun-en-2025-mtn-mobile-money-reduit-son-retard-sur-le-leader-orange-money/)


---

<!-- source : audit-expert-v111-aucune-nouveaute-netbuis.md -->

# Audit expert v111 NetBuis (2026-10-12): aucune nouveauté majeure

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes sources (Zencoder, Mastra, Addy Osmani « Code Agent Orchestra », Morph, amux, fungies.io). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Camtel Mobile Money, carte virtuelle MoMo, interconnexion mobile money Cameroun-Côte d'Ivoire-Sénégal: déjà connus (v25 et suivants), pas d'impact sur la conception.
- API Orange Money / MTN MoMo [S]: seulement des guides d'intégration (kolonell.com) et tarifs de retrait; pas de changement d'API signalé.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v110. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, netbuis-decisions-et-points-ouverts.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Addy Osmani](https://addyosmani.com/blog/code-agent-orchestra/)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Camtel mobile money](https://www.camer.be/93232/11:1/camtel-prepare-son-entree-dans-le-mobile-money-et-bouscule-mtn-et-orange-au-cameroun-cameroon.html)


---

<!-- source : audit-expert-v112-aucune-nouveaute-netbuis.md -->

# Audit expert v112 NetBuis (2026-10-12): aucune nouveauté majeure

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: guides déjà connus (Zencoder, BairesDev) + deux titres nouveaux non lus: Morphllm « Claude Code Agent Teams and Multi-Agent Coding (2026) » et Verdent « orchestrate multiple ai coding agents ». Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: deux résultats à vérifier, non lus: une app « Youmbia » (mwm.ai/apps/youmbia) et une fiche App Store id6749525599. Possibles entrants ou hors sujet; à ouvrir lors d'une prochaine passe si Jeff le souhaite. Offrir (v18) reste le concurrent direct connu.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v111. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Verdent](https://www.verdent.ai/guides/orchestrate-multiple-ai-coding-agents)
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Youmbia](https://mwm.ai/apps/youmbia/6774914586)


---

<!-- source : audit-expert-v113-youmbia-verifie-netbuis.md -->

# Audit expert v113 NetBuis (2026-10-12): Youmbia vérifié, un seul fait nouveau

[S] = source lue; [A] = mon avis.

## Fait nouveau [S]
Youmbia (App Store, fiche mwm.ai) est une place de marché mobile pour acheter et vendre produits et services au Cameroun. Sortie le 3 juin 2026. Catégories: annonces classées, véhicules, immobilier, services locaux. Les vendeurs publient des annonces avec photos; les vendeurs professionnels peuvent ouvrir une boutique en ligne. Les acheteurs cherchent des annonces et contactent le vendeur; la fiche ne dit pas si c'est par appel direct ou messagerie.

## Lecture [A]
- Ce n'est pas le même produit: Youmbia = annonces à la Jumia/Avito (objet à vendre, photos). NetBuis = « qui vend ce produit près de moi, j'appelle ou j'écris sur WhatsApp maintenant » (commerce de proximité, fraîcheur des fiches). Chevauchement partiel sur la recherche de produit et les boutiques professionnelles.
- Signal utile: un entrant local existe depuis 4 mois. À vérifier avant le lancement: nombre de téléchargements, notes, présence de commerçants de votre quartier pilote, bouton d'appel.
- Concurrent direct connu inchangé: Offrir (v18).
- Différenciateurs à garder: appel + WhatsApp en un geste, inscription commerçant par photo/voix, fraîcheur vérifiée, mode faible débit/téléphone 2 Go.

## Orchestration et gestion de projet [S: titres seulement]
Mêmes guides (Morphllm, Addy Osmani, amux.io, Tembo, Unblocked, fungies.io, Zencoder). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test. Gestion de projet inchangée (Scrumban léger / Scrum augmenté / Shape Up).

## Décisions en attente de Jeff
Canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Recommandation répétée: passer cette routine en hebdomadaire et lancer le jalon 0.

## Sources
- [Youmbia (fiche App Store via mwm.ai)](https://mwm.ai/apps/youmbia/6774914586)
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Addy Osmani, Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)


---

<!-- source : audit-expert-v114-aucune-nouveaute-netbuis.md -->

# Audit expert v114 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, momen, Ayesa, klu.ai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats: Kolonell WhatsApp commerce, Chekche, index cameroun). Youmbia (v113) et Offrir (v18) restent les seuls concurrents partiels connus.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [fungies.io](https://fungies.io/?p=38513)
- [Kolonell, WhatsApp commerce Cameroun 2026](https://kolonell.com/fr/blog/whatsapp-commerce-vs-boutique-ecommerce-dediee-cameroun-2026)


---

<!-- source : audit-expert-v115-aucune-nouveaute-netbuis.md -->

# Audit expert v115 NetBuis (2026-10-12): aucune nouveauté

[S] = source lue ou titres de résultats; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Unblocked, Belitsoft, Gumloop, Mastra, fungies.io, knowlee, Ayesa, tallorder). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: Nkwel relu (commande + livraison, ni recherche produit ni appel direct; déjà analysé en v40), Youmbia, Chekche, SecondMain237 (déjà vus ou hors sujet). Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113/v114. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Unblocked](https://getunblocked.com/blog/ai-agent-orchestration-platforms-compared/index.md)
- [Nkwel (Business in Cameroon)](https://www.businessincameroon.com/public-management/1203-15883-nkwel-app-launched-in-cameroon-to-digitalise-neighbourhood-commerce)


---

<!-- source : audit-expert-v116-aucune-nouveaute-netbuis.md -->

# Audit expert v116 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes familles de guides (Daniel Vaughan sur Osmani, Morphllm, Tembo, amux.io, toolhalla, agentsroom, Verdent). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: commerçants vs industriels, Made in Cameroon).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113 à v115. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Orchestration patterns (Vaughan)](https://codex.danielvaughan.com/2026/05/18/multi-agent-orchestration-patterns/)
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Tembo](https://www.tembo.io/blog/multi-agent-orchestration)
- [amux.io](https://amux.io/guides/ai-agent-orchestration-2026/)


---

<!-- source : audit-expert-v117-aucune-nouveaute-netbuis.md -->

# Audit expert v117 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes familles de guides (Zencoder, Mastra, Momen, Fungies, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Résultats hors sujet (Orange/MTN mobile money, carte virtuelle MoMo, baisse de tarifs Orange Money). Pas d'impact sur le plan.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113 à v116. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Momen](https://momen.app/blogs/7-best-multi-agent-orchestration-tools-in-2026/)
- [Business in Cameroon](https://www.businessincameroon.com/telecom/2711-8619-cameroon-orange-and-mtn-launch-a-mobile-money-joint-venture)


---

<!-- source : audit-expert-v118-aucune-nouveaute-netbuis.md -->

# Audit expert v118 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v117 (Zencoder, Mastra, Momen, Fungies, Ayesa, amux, ibl.ai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Résultats hors sujet (Orange/MTN mobile money, passerelle bancaire Afriland).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113 à v117. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Momen](https://momen.app/blogs/7-best-multi-agent-orchestration-tools-in-2026/)
- [Business in Cameroon](https://www.businessincameroon.com/telecom/2601-6847-orange-cameroun-joins-mtn-for-transactions-from-bank-to-mobile-accounts-on-the-afriland-first-bank-network)


---

<!-- source : audit-expert-v119-aucune-nouveaute-netbuis.md -->

# Audit expert v119 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides que v118 (Zencoder, Mastra, Fungies, ibl.ai, Unblocked, Ayesa, testmuai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Résultats hors sujet (Made in Cameroon, commerçants vs industriels).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113-v118. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Ayesa](https://ayesa-digital.com/en/insight/the-era-of-ai-agent-orchestration-taking-artificial-intelligence-to-the-next-level/)


---

<!-- source : audit-expert-v120-aucune-nouveaute-netbuis.md -->

# Audit expert v120 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes familles de guides (Zencoder, Mastra, ibl.ai, Fungies, BairesDev, sista.ai, videosdk) + un article arXiv « Rethinking Software Engineering for Agentic AI Systems » (non lu en détail). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats: Camtel Blue, Chekche, Youmbia déjà vérifié en v113, Index Cameroun).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113-v119. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [arXiv 2604.10599](https://arxiv.org/pdf/2604.10599)
- [Chekche](https://www.businessincameroon.com/ict/1402-6897-cameroonian-start-up-cdi-sarl-launches-chekche-an-app-to-find-objects-you-have-lost)


---

<!-- source : audit-expert-v121-aucune-nouveaute-netbuis.md -->

# Audit expert v121 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Morphllm, Zencoder, Addy Osmani, Mastra, amux.io, fungies.io, Ayesa, codewithandrea). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: Made in Cameroon, commerçants vs industriels).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113-v120. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Addy Osmani](https://addyosmani.com/blog/code-agent-orchestra/)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)


---

<!-- source : audit-expert-v122-aucune-nouveaute-netbuis.md -->

# Audit expert v122 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, Ayesa, testmuai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (Kolonell WhatsApp commerce, Chekche: déjà connus).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113-v121. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Unblocked](https://getunblocked.com/blog/ai-agent-orchestration-platforms-compared/index.md)
- [Kolonell](https://kolonell.com/fr/blog/whatsapp-commerce-vs-boutique-ecommerce-dediee-cameroun-2026)


---

<!-- source : audit-expert-v123-aucune-nouveaute-netbuis.md -->

# Audit expert v123 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Unblocked, fungies.io, Ayesa, knowlee, Belitsoft « 12 agents en moyenne en entreprise, la moitié travaillent seuls »). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (CamerAnnonces, SecondMain237, Youmbia: déjà connus ou petites annonces).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113-v122. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Unblocked](https://getunblocked.com/blog/ai-agent-orchestration-platforms-compared/index.md)
- [Belitsoft via Barchart](https://www.barchart.com/story/news/1163379/belitsoft-report-2026-ai-agent-trends-enterprises-run-12-ai-agents-on-average-but-half-work-alone)
- [Youmbia](https://mwm.ai/apps/youmbia/6774914586)


---

<!-- source : audit-expert-v124-aucune-nouveaute-netbuis.md -->

# Audit expert v124 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Belitsoft, fungies.io, knowlee, Ayesa, datanorth). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: seulement des articles mobile money (Orange ouvre ses comptes aux puces concurrentes, Camtel entre sur le mobile money); aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113-v123. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Belitsoft via Barchart](https://www.barchart.com/story/news/1283785/belitsoft-multiagent-systems-surge-1-445-as-enterprises-move-beyond-single-ai-agents-in-2026)
- [knowlee](https://knowlee.ai/blog/ai-agent-orchestration-guide-2026)
- [Orange Cameroun vs MTN](https://itweb.africa/article/orange-cameroun-to-challenge-mtn-mobile-money-dominance/j5alrMQAZEgMpYQk)


---

<!-- source : audit-expert-v125-aucune-nouveaute-netbuis.md -->

# Audit expert v125 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, knowlee, fungies.io, momen, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: articles mobile money seulement (Camtel, carte virtuelle MoMo, interconnexion Cameroun-Côte d'Ivoire-Sénégal, UBA); aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113-v124. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [knowlee](https://knowlee.ai/blog/ai-agent-orchestration-guide-2026)
- [Camtel mobile money](https://www.camer.be/93232/11:1/camtel-prepare-son-entree-dans-le-mobile-money-et-bouscule-mtn-et-orange-au-cameroun-cameroon.html)


---

<!-- source : audit-expert-v126-aucune-nouveaute-netbuis.md -->

# Audit expert v126 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: articles mobile money (carte virtuelle MoMo, Camtel, Express Union) et un entretien avec le country manager de Wave Cameroun (juillet 2026, financialafrik). Wave est un acteur paiement à surveiller pour l'intégration, pas un concurrent « recherche produit local + appel direct ». Aucun nouvel entrant direct.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113-v125. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Wave Cameroun](https://www.financialafrik.com/2026/07/23/entretien-avec-joel-bertrand-ndjodo-country-manager-de-wave-cameroun/)
- [Carte virtuelle MoMo](https://fr.allafrica.com/stories/202602040622.html)


---

<!-- source : audit-expert-v127-aucune-nouveaute-netbuis.md -->

# Audit expert v127 NetBuis (2026-10-12): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: résultats hors sujet (Made in Cameroon, commerçants vs industriels). Aucun nouvel entrant « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113-v126. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Ayesa](https://ayesa-digital.com/en/insight/the-era-of-ai-agent-orchestration-taking-artificial-intelligence-to-the-next-level/)


---

<!-- source : audit-expert-v128-aucune-nouveaute-netbuis.md -->

# Audit expert v128 NetBuis (2026-10-13): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, momen.app, Ayesa, klu.ai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Seule info connexe déjà connue du secteur: Camtel prépare son entrée dans le mobile money (camer.be) et la carte virtuelle MoMo (allAfrica, fév. 2026).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v127. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md, audit-expert-v3/v5. Décisions en attente de Jeff: canal WhatsApp, règle d'agents (A/B/C), méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0 (test de demande hors-ligne). Aucune notification: rien d'urgent.


---

<!-- source : audit-expert-v129-aucune-nouveaute-netbuis.md -->

# Audit expert v129 NetBuis (2026-10-13): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (morphllm, Zencoder, Addy Osmani « Code Agent Orchestra », Mastra, amux.io, fungies.io, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats hors sujet: Made in Cameroon, CFAO, commerçants vs industriels).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v128. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents (A/B/C), méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: suspendre cette routine ou la passer en hebdomadaire, et lancer le jalon 0 (test de demande hors-ligne). Aucune notification: rien d'urgent.


---

<!-- source : audit-expert-v130-aucune-nouveaute-netbuis.md -->

# Audit expert v130 NetBuis (2026-10-13): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, fungies.io, ibl.ai, Unblocked, Ayesa, testmuai). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct » (résultats: Kolonell WhatsApp commerce, Vairified, Chekche, déjà connus ou hors sujet).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v113-v129. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents, méthode de gestion, compte développeur Android, quartier pilote, 30 premiers commerçants. Recommandation: passer cette routine en hebdomadaire et lancer le jalon 0. Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Kolonell](https://kolonell.com/fr/blog/whatsapp-commerce-vs-boutique-ecommerce-dediee-cameroun-2026)


---

<!-- source : audit-expert-v131-aucune-nouveaute-netbuis.md -->

# Audit expert v131 NetBuis (2026-10-13): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Morphllm, Zencoder, Verdent, BairesDev, dev.to). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun [S]: aucun nouvel entrant « recherche produit local + appel direct ». Seuls éléments connexes: plateforme gouvernementale de promotion des produits locaux (wearetech.africa), app Chekche (objets perdus), Youmbia (app, à examiner si besoin).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v130. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents (A/B/C), méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: passer cette routine en hebdomadaire et lancer le jalon 0 (test de demande hors-ligne). Aucune notification: rien d'urgent.

## Sources
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Verdent](https://www.verdent.ai/guides/orchestrate-multiple-ai-coding-agents)
- [Plateforme produits locaux Cameroun](https://www.wearetech.africa/fr/fils/breves/breves-une/cameroun-le-gouvernement-lance-une-plateforme-numerique-pour-promouvoir-les-produits-locaux)


---

<!-- source : audit-expert-v132-aucune-nouveaute-netbuis.md -->

# Audit expert v132 NetBuis (2026-10-13): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes sources (Morphllm, Verdent, GoCodeo) + un article PraisonAI « agent mesh » (contexte partagé et gouvernance), même conclusion. Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / Mobile Money [S]: rien de nouveau sur un concurrent « recherche produit local + appel direct ». Seulement des articles généraux (carte virtuelle MoMo, UBA mobile money, Cameroun leader CEMAC).
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v131. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents (A/B/C), méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: passer cette routine en hebdomadaire et lancer le jalon 0 (test de demande hors-ligne). Aucune notification: rien d'urgent.

## Sources
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Verdent](https://www.verdent.ai/guides/orchestrate-multiple-ai-coding-agents)
- [GoCodeo](https://www.gocodeo.com/post/collaborative-coding-with-ai-managing-multiple-agents-generating-code)
- [PraisonAI agent mesh](https://mer.vin/2026/05/praisonai-agent-mesh-for-multi-agent-coding-from-manual-handoffs-to-shared-context-and-governance/?amp=1)


---

<!-- source : audit-expert-v133-aucune-nouveaute-netbuis.md -->

# Audit expert v133 NetBuis (2026-10-13): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: mêmes sources (Osmani, Morphllm, Verdent, amux.io, dev.to topology) + Tembo, toolhalla, codex.danielvaughan (patterns). Même conclusion. Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / Mobile Money [S]: Camtel (déjà noté addendum 20/92), carte virtuelle MoMo, Monifone (Société Générale). Aucun concurrent « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v132. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents (A/B/C), méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: passer cette routine en hebdomadaire (ou la suspendre) et lancer le jalon 0 (test de demande). Aucune notification: rien d'urgent.

## Sources
- [Addy Osmani](https://addyosmani.com/blog/code-agent-orchestra/)
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Tembo](https://www.tembo.io/blog/multi-agent-orchestration)
- [Patterns](https://codex.danielvaughan.com/2026/05/18/multi-agent-orchestration-patterns/)
- [Monifone](https://societegenerale.com/en/news/newsroom/societe-generale-de-banques-au-cameroun-launching-monifone-first-multi-operator)


---

<!-- source : audit-expert-v134-aucune-nouveaute-netbuis.md -->

# Audit expert v134 NetBuis (2026-10-13): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: résultats identiques (Morphllm, claudefa.st, fast.io, mcp.directory, medium best practices). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / Mobile Money [S]: kolonell (paysage paiement 2026, coût d'intégration MoMo/Orange), ecomatin (Orange baisse tarifs, relève plafonds de retrait), digitalbusiness (tarifs retrait MTN). Pas de changement d'API signalé, aucun concurrent « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v133. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents (A/B/C), méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: passer cette routine en hebdomadaire (ou la suspendre) et lancer le jalon 0 (test de demande). Aucune notification: rien d'urgent.

## Sources
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [claudefa.st](https://claudefa.st/blog/tools/orchestrators/multi-agent-orchestrators)
- [Kolonell paysage paiement Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Ecomatin Orange Money tarifs](https://ecomatin.net/mobile-money-orange-cameroun-abaisse-ses-tarifs-et-releve-les-plafonds-de-retrait)


---

<!-- source : audit-expert-v135-aucune-nouveaute-netbuis.md -->

# Audit expert v135 NetBuis (2026-10-13): aucune nouveauté majeure

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Morphllm, Addy Osmani, amux.io, dev.to topology, Verdent, Tembo, toolhalla, agentsroom). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / Mobile Money [S]: un titre daté du 8 octobre 2026 (Financial Afrik): en 2025, MTN Mobile Money réduit son retard sur Orange Money (leader). Utile pour la marge de monétisation et le choix des passerelles: garder l'interface `PaymentProvider` et supporter les deux. Non lu en détail. Aucun nouveau concurrent « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v134. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents (A/B/C), méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: passer cette routine en hebdomadaire (ou la suspendre) et lancer le jalon 0 (test de demande hors-ligne). Aucune notification: rien d'urgent.

## Sources
- [Morphllm](https://www.morphllm.com/ai-agent-orchestration)
- [Addy Osmani, Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)
- [Financial Afrik, MTN MoMo vs Orange Money](https://www.financialafrik.com/2026/10/08/cameroun-en-2025-mtn-mobile-money-reduit-son-retard-sur-le-leader-orange-money/)


---

<!-- source : audit-expert-v136-aucune-nouveaute-netbuis.md -->

# Audit expert v136 NetBuis (2026-10-13): aucune nouveauté majeure

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Orchestration d'agents [S]: mêmes guides (Zencoder, Mastra, ibl.ai, fungies.io, momen.app, Ayesa). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Cameroun / Mobile Money [S]: titres sur l'entrée de Camtel dans le mobile money (à confirmer, date non vérifiée), Orange Cameroun vs MTN, et l'article Financial Afrik du 8 octobre 2026 (MTN réduit son retard sur Orange Money). Confirme l'intérêt de garder l'interface `PaymentProvider` multi-opérateurs. Aucun nouveau concurrent « recherche produit local + appel direct ».
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v135. Références: rapport-orchestration-agents-ia-netbuis.md, rapport-methodes-gestion-projet-netbuis.md, audit-orchestration-gestion-projet-netbuis.md. Décisions en attente de Jeff: canal WhatsApp, règle d'agents (A/B/C), méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: passer cette routine en hebdomadaire (ou la suspendre) et lancer le jalon 0 (test de demande hors-ligne). Aucune notification: rien d'urgent.

## Sources
- [Zencoder](https://zencoder.ai/blog/ai-agent-orchestration-best-practices)
- [Mastra](https://mastra.ai/articles/ai-agent-orchestration)
- [Financial Afrik, MTN MoMo vs Orange Money](https://www.financialafrik.com/2026/10/08/cameroun-en-2025-mtn-mobile-money-reduit-son-retard-sur-le-leader-orange-money/)
- [Camer.be, Camtel et le mobile money](https://www.camer.be/93232/11:1/camtel-prepare-son-entree-dans-le-mobile-money-et-bouscule-mtn-et-orange-au-cameroun-cameroon.html)


---

<!-- source : audit-expert-v137-aucune-nouveaute-netbuis.md -->

# Audit expert v137 NetBuis (2026-10-13): aucune nouveauté

Passe unique couvrant 4 déclenchements en attente (11:50, 12:50, 13:50, 14:50 UTC), traités ensemble à 15:30 UTC.

[S] = titres de résultats web seulement, non lus en détail; [A] = mon avis.

- Concurrence Cameroun [S]: plateforme gouvernementale de promotion des produits locaux (déjà notée en v17, v93, v131), événements « Made in Cameroon » (CFAO, Semaines communales à Douala). Aucun nouvel entrant « recherche produit local + appel direct ».
- Orchestration d'agents [S]: mêmes guides (Addy Osmani « Code Agent Orchestra », Tembo, morphllm, amux.io). Règle inchangée: superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Gestion de projet: inchangé (Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v136. Décisions toujours en attente de Jeff: canal WhatsApp, règle d'agents (A/B/C), méthode de gestion, quartier pilote, 30 premiers commerçants. Recommandation répétée: passer la routine en hebdomadaire (ou la suspendre) et lancer le jalon 0.

## Sources
- [We Are Tech, plateforme produits locaux](https://www.wearetech.africa/fr/fils/breves/breves-une/cameroun-le-gouvernement-lance-une-plateforme-numerique-pour-promouvoir-les-produits-locaux)
- [Addy Osmani, Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)
- [Tembo, multi-agent orchestration](https://www.tembo.io/blog/multi-agent-orchestration)


---

<!-- source : audit-expert-v138-aucune-nouveaute-netbuis.md -->

# Audit expert v138 NetBuis (2026-10-13 15:51 UTC): aucune nouveauté

Passe 20 minutes après v137. [S] = titres de résultats web seulement; [A] = mon avis.

- Mobile Money Cameroun [S]: série de guides d'intégration MTN MoMo / Orange Money (blog Kolonell, Douala 2026: coûts, frais, intégration web). Rien qui change le choix déjà retenu (agrégateur type Campay derrière une interface `PaymentProvider`, voir decision-campay-netbuis.md).
- Orchestration d'agents et gestion de projet: inchangé depuis v137 (superviseur + 3 à 5 agents; Scrumban léger / Scrum augmenté / Shape Up).

## Constat [A]
Identique à v39-v137. Décisions en attente de Jeff inchangées. Recommandation répétée: passer la routine en hebdomadaire (ou la suspendre) et lancer le jalon 0.

## Sources
- [Kolonell, paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell, coût d'intégration MTN MoMo / Orange Money](https://kolonell.com/fr/blog/cout-integration-mtn-momo-orange-money-douala-2026)


---

<!-- source : audit-expert-v139-aucune-nouveaute-netbuis.md -->

# Audit expert v139 NetBuis (2026-10-13 16:50 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Concurrence Cameroun [S]: résultats déjà connus (Youmbia, déjà vérifié en v113), anciennes startups (réservation de taxis, Index Cameroun, Yenla sur VC4A), guide Kolonell « créer une boutique en ligne à Yaoundé ». Aucun nouvel entrant « recherche produit local + appel direct ».
- Orchestration d'agents et gestion de projet: inchangé depuis v137.

## Constat [A]
Identique à v39-v138. Décisions en attente de Jeff inchangées. Recommandation répétée: passer la routine en hebdomadaire (ou la suspendre) et lancer le jalon 0.

## Sources
- [Youmbia (mwm.ai)](https://mwm.ai/apps/youmbia/6774914586)
- [Kolonell, boutique en ligne Yaoundé 2026](https://kolonell.com/en/blog/create-online-store-cameroon-yaounde-2026)


---

<!-- source : audit-expert-v140-aucune-nouveaute-netbuis.md -->

# Audit expert v140 NetBuis (2026-10-13 17:50 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents [S]: guides « agent teams » (nxcode), rapport de tendances agentiques 2026 d'Anthropic (résumé NYU Shanghai), « un développeur pilote 3 sous-agents » (next-it), itnext « Designing a team of agents ». Tous convergent vers la règle déjà retenue: 1 superviseur + 3 à 5 agents, CI comme juge, humain sur argent/données/architecture. Ni 64 agents ni 10 agents de test.
- Concurrence, paiement, gestion de projet: inchangé depuis v137-v139.

## Constat [A]
Identique à v39-v139. Décisions en attente de Jeff inchangées. Recommandation répétée: passer la routine en hebdomadaire (ou la suspendre) et lancer le jalon 0.

## Sources
- [Rapport tendances agentiques 2026 (NYU Shanghai)](https://rits.shanghai.nyu.edu/ai/anthropics-2026-agentic-coding-trends-report-from-assistants-to-agent-teams/)
- [next-it, 3 sous-agents par développeur](https://next-it.co.id/blog/offshore-development-in-the-age-of-ai-agents-when-your-developer-manages-3-ai-sub-agents)
- [itnext, Designing a team of agents](https://itnext.io/designing-a-team-of-agents-8063852cceb6)


---

<!-- source : audit-expert-v141-aucune-nouveaute-netbuis.md -->

# Audit expert v141 NetBuis (2026-10-13 18:50 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Mobile Money Cameroun [S]: Camtel et le mobile money (déjà noté en v136), carte virtuelle MoMo pour paiements internationaux (février 2026, sans effet sur NetBuis), guides Kolonell déjà vus en v138. Rien qui change l'interface `PaymentProvider` multi-opérateurs.
- Concurrence, orchestration d'agents, gestion de projet: inchangé depuis v137-v140.

## Constat [A]
Identique à v39-v140. Décisions en attente de Jeff inchangées. Recommandation répétée: passer la routine en hebdomadaire (ou la suspendre) et lancer le jalon 0.

## Sources
- [Camer.be, Camtel et le mobile money](https://www.camer.be/93232/11:1/camtel-prepare-son-entree-dans-le-mobile-money-et-bouscule-mtn-et-orange-au-cameroun-cameroon.html)
- [AllAfrica, carte virtuelle MoMo](https://fr.allafrica.com/stories/202602040622.html)


---

<!-- source : audit-expert-v142-concurrent-shoppyms-netbuis.md -->

# Audit expert v142 NetBuis (2026-10-13 19:50 UTC): nouveau concurrent direct, ShoppyMS

[S] = source lue (fiche App Store Cameroun); [A] = mon avis.

## Fait nouveau [S]
**ShoppyMS : Acheter Près De Vous** (Shoppy MarketSpace), éditeur NOVOBYTE SARL, fiche sur l'App Store Cameroun.
- Recherche de produit par texte, voix et image; « Recherche Profonde » sur le réseau de vendeurs si le produit est introuvable.
- Boutiques proches comparées par prix, distance et note.
- Appel direct du vendeur depuis l'app (depuis la v3.0.4).
- Paiement intégré (v3.0.0), paiements internationaux (v3.1.1), livraison « Shoppy Logistics » là où elle existe.
- 50 notes, moyenne 4,1/5. Dernière version 3.4.1 du « 15 août » (année non affichée). App créée vers 2021 (identifiant App Store).
- Non vérifié: présence Android/Play Store, nombre de téléchargements, villes couvertes, modèle de revenu.

## Constat [A]
C'est le concurrent le plus proche trouvé à ce jour: il couvre déjà le cœur de NetBuis (recherche produit, commerçants proches, appel direct, paiement). Buyam, Youmbia, Kaymucm et Nkwel ne combinaient pas les quatre. Sa faible traction (50 notes en environ 4 ans) confirme la leçon Youmbia: le risque est l'adoption, pas la technique.

Conséquences pour NetBuis:
1. La phrase de différenciation face à Buyam doit maintenant aussi répondre à ShoppyMS. Pistes déjà documentées: accessibilité analphabétisme (voix, pictogrammes), téléphones simples / USSD, forum, produits très demandés, couverture terrain d'un quartier pilote.
2. Avant le jalon 0, installer ShoppyMS et tester une recherche réelle à Douala/Yaoundé pour voir si le catalogue est rempli.

## Sources
- [ShoppyMS sur l'App Store Cameroun](https://apps.apple.com/cm/app/shoppyms-acheter-pr%C3%A8s-de-vous/id1596611931)


---

<!-- source : audit-expert-v143-shoppyms-complement-netbuis.md -->

# Audit expert v143 NetBuis (2026-10-13 20:50 UTC): complément ShoppyMS

Suite de v142. [S] = source lue; [A] = mon avis.

## Faits [S]
- Article We Are Tech du 26 août 2026: Tamko Clarence, ingénieur camerounais, cofondateur et directeur de Shoppy MarketSpace; cofondateur de Novobyte (2021), éditeur de logiciels sur mesure (santé, fintech, logistique).
- Côté vendeur, Shoppy propose une boutique en ligne clé en main créée en quelques minutes, un lien partageable, des statistiques, la gestion des commandes, la promotion automatique sur les réseaux sociaux et le paiement Mobile Money + carte.
- Deux apps iOS: « ShoppyMS » (acheteur, id1596611931) et « Shoppy MarketSpace Seller » (id1621591155).
- Toujours non vérifié: version Android, nombre de commerçants, villes, modèle de revenu.

## Constat [A]
Concurrent actif (médiatisé en août 2026), équipe technique locale, double app acheteur/vendeur. Le positionnement de Shoppy est « boutique en ligne pour commerçants » plus que « annuaire de commerçants informels du quartier ». Cela laisse à NetBuis l'angle des commerçants informels peu à l'aise avec le numérique (inscription par agent terrain, voix, USSD) et du forum / produits très demandés. Action inchangée: tester ShoppyMS avant le jalon 0.

## Sources
- [We Are Tech, Tamko Clarence et Shoppy](https://www.wearetech.africa/fr/fils/tech-stars/le-camerounais-tamko-clarence-automatise-la-creation-de-boutiques-en-ligne)
- [Shoppy MarketSpace Seller (App Store)](https://apps.apple.com/us/app/id1621591155)


---

<!-- source : audit-expert-v144-aucune-nouveaute-netbuis.md -->

# Audit expert v144 NetBuis (2026-10-13 21:51 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- ShoppyMS [S]: recherche d'une version Android / Play Store sans résultat; seules les fiches App Store et l'article We Are Tech (v143) ressortent. Présence Android toujours non confirmée (à vérifier directement sur un téléphone Android).
- Orchestration d'agents, gestion de projet, paiement: inchangé depuis v137.

## Constat [A]
Rien de nouveau depuis v143. Actions inchangées: tester ShoppyMS avant le jalon 0; décisions en attente de Jeff; passer la routine en hebdomadaire.

## Sources
- [Shoppy MarketSpace (App Store Cameroun)](https://apps.apple.com/cm/app/shoppy-marketspace/id1596611931)


---

<!-- source : audit-expert-v145-aucune-nouveaute-netbuis.md -->

# Audit expert v145 NetBuis (2026-10-13 22:51 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Concurrence [S]: annuaire ART 2026 des opérateurs télécoms, annuaire de 686 entreprises pour stages, « Catalogue237 » sur Maligah (annuaire d'entreprises), articles anciens sur l'annuaire d'entreprises WhatsApp (Brésil, 2021-2022). Aucun nouvel acteur « recherche produit local + appel direct » au-delà de ShoppyMS (v142-v143).
- [A] Rappel utile: l'annuaire d'entreprises WhatsApp, s'il arrive au Cameroun, serait un concurrent indirect gratuit; à surveiller, rien d'annoncé.
- Orchestration d'agents, gestion de projet, paiement: inchangé depuis v137.

## Constat [A]
Rien de nouveau depuis v143. Actions inchangées.

## Sources
- [Siècle Digital, WhatsApp s'inspire des pages jaunes](https://siecledigital.fr/2022/11/18/au-bresil-whatsapp-sinspire-des-pages-jaunes/)
- [Maligah, Catalogue237](https://maligah.com/entreprises/details/Catalogue237?id=189991)


---

<!-- source : audit-expert-v146-aucune-nouveaute-netbuis.md -->

# Audit expert v146 NetBuis (2026-10-13 23:50 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Gestion de projet [S]: podcast « adapter les méthodologies de gestion de projet à l'IA sans perdre le contrôle » (The Digital Project Manager), guides Kanban (ClickUp, La Fabrique du Net), panorama des méthodologies 2026 (Develop Argentina). Rien qui modifie les trois options déjà présentées à Jeff (Scrumban léger / Scrum augmenté / Shape Up).
- Concurrence: rien après ShoppyMS (v142-v143). Orchestration d'agents, paiement: inchangé.

## Constat [A]
Rien de nouveau depuis v143. Actions inchangées.

## Sources
- [The Digital Project Manager, méthodologies et IA](https://thedigitalprojectmanager.com/fr/podcast/adapter-les-methodologies-de-gestion-de-projet-a-l-ia-sans-perdre-le-controle/)


---

<!-- source : audit-expert-v147-findme-adressage-netbuis.md -->

# Audit expert v147 NetBuis (2026-10-14 00:50 UTC): piste mineure, adressage FindMe

[S] = source lue; [A] = mon avis.

## Fait [S]
- FindMe, startup camerounaise de géolocalisation, déployée depuis juillet 2024: son app génère gratuitement en ~2 minutes une adresse postale (numéro, rue, code postal, ville) pour particuliers et entreprises. Partenariat avec Campost signé le 1er novembre 2024; codes postaux créés sur tout le territoire.
- Aucune API ni accès développeur mentionnés dans l'article.

## Constat [A]
Ce n'est pas un concurrent. C'est une piste pour un problème que NetBuis a déjà: localiser des commerçants informels sans adresse. Option à garder: champ facultatif « adresse FindMe / code postal » à l'inscription du commerçant, en plus du point GPS et du repère texte (« derrière la pharmacie X »). À vérifier plus tard: existence d'une API FindMe.
Autres résultats (Jumia, Cdiscount, réservation de taxis): anciens, sans effet.

## Sources
- [We Are Tech, Campost et FindMe (nov. 2024)](https://www.wearetech.africa/en/fils-uk/news/tech/cameroun-campost-s-associe-a-findme-pour-numeriser-l-adressage-postal)


---

<!-- source : audit-expert-v148-aucune-nouveaute-netbuis.md -->

# Audit expert v148 NetBuis (2026-10-14 01:51 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Suite v147, FindMe [S]: articles Campost/FindMe (Journal du Cameroun, Cameroon Tribune, Digital Business Africa), « adressage numérique, la voie du postpoint », GeoPostcodes (validation d'adresses Cameroun, payant), « Cameroon API » sur dev.to. Aucune API publique FindMe trouvée.
- [A] Garder le champ adresse/repère texte + GPS comme base; FindMe reste optionnel.
- Concurrence, orchestration d'agents, gestion de projet, paiement: inchangé.

## Sources
- [Digital Business Africa, Campost et FindMe](https://www.digitalbusiness.africa/cameroun-la-campost-et-la-startup-findme-unies-pour-optimiser-le-systeme-dadressage-national/)
- [GeoPostcodes, Cameroun](https://www.geopostcodes.com/country/cameroon/address-validation/)


---

<!-- source : audit-expert-v149-aucune-nouveaute-netbuis.md -->

# Audit expert v149 NetBuis (2026-10-14 02:50 UTC): aucune nouveauté

[S] = source lue; [A] = mon avis.

- Twilio Cameroun [S, page tarifs officielle]: appel sortant vers mobile Cameroun 0,7873 $/min, « local calls » 0,41 $/min; numéros « internationaux » à partir de 1,15 $/mois. Tarif identique à celui déjà noté en v10, v14, v27.
- [A] Confirme la décision existante: l'appel direct passe par le composeur natif (`tel:`) ou WhatsApp, pas par Twilio en appel payant à la minute.
- Concurrence, orchestration d'agents, gestion de projet: inchangé.

## Sources
- [Twilio Voice pricing, Cameroun](https://www.twilio.com/voice/pricing/cm)


---

<!-- source : audit-expert-v150-aucune-nouveaute-netbuis.md -->

# Audit expert v150 NetBuis (2026-10-14 03:50 UTC): aucune nouveauté

[S] = source lue; [A] = mon avis.

- WhatsApp Business [S, blog EngageLab]: confirme la facturation des messages de service et des messages utilitaires dans la fenêtre de 24 h depuis le 1er octobre 2026, et l'obligation d'un moyen de paiement dans le Billing Hub depuis le 30 septembre 2026. Déjà documenté en v26. Pas de tarif Cameroun dans la source.
- [A] La décision par défaut reste valable: lien `wa.me` (gratuit, aucun appel API) pour l'appel/discussion client-commerçant; l'API WhatsApp Business seulement plus tard, pour les notifications.
- Concurrence, orchestration d'agents, gestion de projet: inchangé.

## Sources
- [EngageLab, WhatsApp pricing 2026](https://www.engagelab.com/blog/whatsapp-pricing-2026-service-message-cost)


---

<!-- source : audit-expert-v151-aucune-nouveaute-netbuis.md -->

# Audit expert v151 NetBuis (2026-10-14 04:50 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Vérification des développeurs Android [S]: articles Bitdefender, Android Authority (« first wave rollout »), Median (« préparer avant l'échéance de septembre 2026 »). Sujet déjà couvert en v12, v24 et v26; aucune date nouvelle pour l'Afrique centrale dans les titres.
- [A] Action inchangée: créer et vérifier le compte développeur Android de NetBuis avant de distribuer l'APK du pilote, même hors Play Store.
- Concurrence, orchestration d'agents, gestion de projet: inchangé.

## Sources
- [Android Authority, première vague](https://androidauthority.com/android-sideloading-developer-verification-first-wave-rollout-3717921)
- [Median, préparer la vérification Android](https://median.co/blog/android-developer-verification-2026)


---

<!-- source : audit-expert-v152-aucune-nouveaute-netbuis.md -->

# Audit expert v152 NetBuis (2026-10-14 05:51 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Commerce informel et applications mobiles au Cameroun [S]: résultats Digital Business Africa (publication mobile des textes télécoms, ligne contre le commerce illicite), CEA/ZLECAf (portail d'information commerciale), INS (collecte statistique mobile). Aucun nouveau concurrent, aucune règle nouvelle pour une app d'annuaire de commerçants.
- [A] Le portail ZLECAf vise l'import-export, pas le commerce de quartier: sans effet sur NetBuis.
- Concurrence, orchestration d'agents, gestion de projet, paiement: inchangé. Recommandation maintenue: routine hebdomadaire ou suspendue, et lancement du jalon 0 (test de demande hors ligne).

## Sources
- [CapMad, guide et portail ZLECAf à Douala](https://www.capmad.com/article/a-douala-la-cea-et-le-cameroun-valident-un-guide-et-un-portail-pour-doper-linformation-commerciale-zlecaf)
- [Digital Business Africa, ligne contre le commerce illicite](https://www.digitalbusiness.africa/cameroun-une-ligne-telephonique-ouverte-pour-lutter-contre-le-commerce-illicite/)


---

<!-- source : audit-expert-v153-aucune-nouveaute-netbuis.md -->

# Audit expert v153 NetBuis (2026-10-14 06:51 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Suivi v142/v143, ShoppyMS sur Android [S]: la recherche ne renvoie que la fiche App Store (id1596611931) et des homonymes (Shoppy.is, constructeur d'apps sans lien). Aucune fiche Google Play trouvée dans les titres; présence Android non confirmée.
- Résultat isolé « Mougou » (mwm.ai, App Store id6747683454) [S]: une recherche complémentaire ne renvoie que des homonymes (localité, noms de personnes). Rien qui en fasse un concurrent identifiable.
- [A] Si ShoppyMS reste absent de Google Play, l'avantage Android de NetBuis (majorité des téléphones au Cameroun) tient; à vérifier directement sur le Play Store avant d'en faire un argument.
- Concurrence, orchestration d'agents, gestion de projet, paiement: inchangé.

## Sources
- [ShoppyMS sur l'App Store Cameroun](https://apps.apple.com/cm/app/shoppyms-acheter-pr%C3%A8s-de-vous/id1596611931)
- [mwm.ai, fiche Mougou](https://mwm.ai/apps/mougou/6747683454)


---

<!-- source : audit-expert-v154-aucune-nouveaute-netbuis.md -->

# Audit expert v154 NetBuis (2026-10-14 07:51 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Loi camerounaise sur les données personnelles [S]: articles CIO Mag, Droit Médias Finance (« entre en vigueur ce 23 juin 2026 »), Digital Business Africa, formation conformité à Douala. Sujet déjà couvert en v10, v12, v13, v19 et v24; aucun texte d'application ni sanction nouvelle dans les titres.
- [A] Actions inchangées: consentement explicite pour la géolocalisation et le numéro du commerçant, politique de confidentialité en français et en anglais, minimisation des données, journal des accès; déclaration auprès de l'autorité dès qu'elle publie sa procédure.
- Concurrence, orchestration d'agents, gestion de projet, paiement: inchangé.

## Sources
- [Droit Médias Finance, entrée en vigueur le 23 juin 2026](https://droitmediasfinance.com/index.php/actualites/droit-tech-fintech/1297-cameroun-la-loi-sur-la-protection-des-donnees-a-caractere-personnel-entre-en-vigueur-ce-23-juin-2026)
- [CIO Mag, lecture de la loi du 23 décembre 2024](https://cio-mag.com/?p=59861)


---

<!-- source : audit-expert-v155-aucune-nouveaute-netbuis.md -->

# Audit expert v155 NetBuis (2026-10-14 08:51 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Frais mobile money Cameroun [S]: Ecomatin (« Orange Money abaisse ses tarifs et relève les plafonds de retrait », « MTN et Orange baissent conjointement leurs tarifs »), Infos Pratiques (guide MTN MoMo 2026), simulateur Le Fisk, comparatif Kolonell 2026. Sujet déjà couvert en v15; les titres ne donnent ni date ni barème nouveau.
- [A] Sans effet sur les décisions: NetBuis ne fait pas transiter l'argent au pilote (contact direct). Au moment de facturer les commerçants, relire le barème en vigueur via l'agrégateur (Campay) plutôt que les articles de presse.
- Concurrence, orchestration d'agents, gestion de projet: inchangé.

## Sources
- [Ecomatin, baisse des tarifs Orange Money](https://ecomatin.net/mobile-money-orange-cameroun-abaisse-ses-tarifs-et-releve-les-plafonds-de-retrait)
- [Le Fisk, simulateur de frais](https://lefisk.cm/simulateurs/transfert-mobile-money)


---

<!-- source : audit-expert-v156-aucune-nouveaute-netbuis.md -->

# Audit expert v156 NetBuis (2026-10-14 09:50 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Orchestration d'agents de code [S]: Addy Osmani (« The Code Agent Orchestra »), Morph (équipes d'agents Claude Code), Tembo, dev.to (« la topologie d'orchestration est le nouveau goulot »), guides amux.io et Toolhalla 2026. Sources déjà vues (v101, v105, complément v2); rien qui contredise la règle retenue.
- [A] Règle inchangée: 1 superviseur + 3 à 5 agents spécialisés, CI comme juge, humain sur l'argent, les données et l'architecture. Pas 64 agents, pas 10 agents de test.
- Concurrence, gestion de projet, paiement: inchangé.

## Sources
- [Addy Osmani, The Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)
- [dev.to, la topologie d'orchestration](https://dev.to/terminalblog/orchestration-topology-is-the-new-bottleneck-in-agentic-coding-487g)


---

<!-- source : audit-expert-v157-aucune-nouveaute-netbuis.md -->

# Audit expert v157 NetBuis (2026-10-14 10:51 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Coupures internet au Cameroun [S]: Osiris et Digital Business Africa (incident sur la fibre optique, « graves perturbations d'internet » autour de la présidentielle, coupures passées dans l'Ouest). Les titres ne datent pas les événements; le risque de coupure est déjà pris en compte dans les audits précédents (mode hors ligne).
- [A] Confirme un choix déjà acté: cache local des commerçants consultés et des numéros, appel par le composeur natif (`tel:`) qui marche sans données, SMS en secours. Un annuaire inutilisable sans 4G perd l'utilisateur.
- Concurrence, orchestration d'agents, gestion de projet, paiement: inchangé.

## Sources
- [Osiris, incident sur la fibre optique](https://osiris.sn/internet-un-nouvel-incident-sur-la-fibre-optique-perturbe-le-reseau-au-cameroun.html)
- [Digital Business Africa, perturbations autour de la présidentielle](https://www.digitalbusiness.africa/presidentielle-cameroun-graves-perturbations-dinternet-a-quelques-jours-de-la-proclamation-des-resultats/)


---

<!-- source : audit-expert-v158-aucune-nouveaute-netbuis.md -->

# Audit expert v158 NetBuis (2026-10-14 11:50 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Recherche « app de recherche de produit chez les commerçants de proximité, Douala/Yaoundé 2026 » [S]: Business in Cameroon (plan directeur des marchés de Yaoundé, appel à candidatures Promote 2026), Camer.be (projets urbains de Douala), ancien partenariat Carrefour-Jumia, brochure Internet Society CAPF 2026. Aucun nouveau concurrent.
- [A] Piste mineure déjà implicite: un salon type Promote ou un forum tech local peut servir à recruter les 30 premiers commerçants ou des partenaires, mais seulement après le jalon 0.
- Concurrence, orchestration d'agents, gestion de projet, paiement: inchangé.

## Sources
- [Business in Cameroon, plan des marchés de Yaoundé](https://www.businessincameroon.com/public-management/2102-12343-yaounde-to-get-master-markets-and-commercial-centers-plan)
- [Business in Cameroon, Promote 2026](https://www.businessincameroon.com/public-management/2105-16203-cameroon-opens-applications-for-state-support-ahead-of-promote-2026)


---

<!-- source : audit-expert-v159-aucune-nouveaute-netbuis.md -->

# Audit expert v159 NetBuis (2026-10-14 12:51 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Gestion de projet, Shape Up face à Scrum pour une petite équipe avec agents IA [S]: saas.group, introductions à Shape Up (juststeveking, Newroom Media, Userpilot, Innerview), billet LinkedIn « à l'ère du codage IA, que faire sans Scrum ? », compétences Shape Up empaquetées pour agents. Rien de neuf par rapport aux trois options déjà présentées.
- [A] Les trois options pour Jeff restent: Scrumban léger, Scrum augmenté, Shape Up. Pour une équipe de 1 à 3 personnes avec des agents, Shape Up (cycles de 6 semaines, « appétit » fixé avant de coder) ou Scrumban léger restent les plus adaptés; le choix appartient à Jeff.
- Concurrence, orchestration d'agents, paiement: inchangé.

## Sources
- [Shape Up: A Practical Introduction](https://juststeveking.com/articles/shape-up/)
- [Userpilot, la méthode Shape Up](https://userpilot.com/blog/?p=13334)


---

<!-- source : audit-expert-v160-aucune-nouveaute-netbuis.md -->

# Audit expert v160 NetBuis (2026-10-14 13:51 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Modération du forum [S]: Sendbird (« 6 règles communautaires essentielles pour la modération mobile »), CIPESA/AfricTivistes (modération en période électorale), engagements de TikTok, Meta, X et Google devant les régulateurs africains des médias (Abidjan, 2024). Sujet déjà couvert dans 17 audits précédents.
- [A] Rappel inchangé: le forum est le module le plus risqué (arnaques, injures, faux commerçants) pour le moins de valeur au pilote. Le garder hors du jalon 1, ou le limiter à des avis liés à un commerçant, avec signalement en un geste et masquage automatique après N signalements.
- Concurrence, orchestration d'agents, gestion de projet, paiement: inchangé.

## Sources
- [Sendbird, règles de modération mobile](https://sendbird.com/blog/6-essential-community-guidelines-for-content-moderation)
- [Guinéenews, plateformes et régulateurs africains](https://guineenews.org/2024/04/25/abidjan-face-aux-regulateurs-de-medias-africains-tiktok-meta-x-et-google-sengagent-au-renforcement-de-la-politique-de-moderation-des-contenus/?amp=1)


---

<!-- source : audit-expert-v161-aucune-nouveaute-netbuis.md -->

# Audit expert v161 NetBuis (2026-10-14 14:51 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Téléphones d'entrée de gamme au Cameroun [S]: pages StatCounter (parts des versions Android et des OS mobiles au Cameroun, 2026), articles anciens sur Android Go (PhoneArena, YourStory), revue Android Go 2026. Les titres ne donnent pas de chiffres; la contrainte « téléphones modestes » est déjà prise en compte dans les audits précédents.
- [A] Cibles inchangées: APK léger (viser moins de 15 Mo), fonctionnement correct avec 2 Go de RAM, images compressées et chargées à la demande, Android 8 minimum à confirmer d'après StatCounter avant le pilote.
- Concurrence, orchestration d'agents, gestion de projet, paiement: inchangé.

## Sources
- [StatCounter, versions Android au Cameroun](https://gs.statcounter.com/android-version-market-share/mobile/cameroon)
- [StatCounter, OS mobiles au Cameroun 2026](https://gs.statcounter.com/os-market-share/mobile-/cameroon/2026)


---

<!-- source : audit-expert-v162-loi-finances-2026-netbuis.md -->

# Audit expert v162 NetBuis (2026-10-14 15:50 UTC): piste mineure, loi de finances 2026

[S] = source lue (résumé Deloitte via outil de lecture); [A] = mon avis.

## Faits [S]
- Loi n° 2025/012 du 17 décembre 2025 (exercice 2026).
- Entreprises numériques **non résidentes**: imposables en cas de présence économique significative, réputée atteinte au-delà de 1 000 utilisateurs/clients au Cameroun ou d'un seuil de chiffre d'affaires. Le résumé indique « 75 k€ (m FCFA) », ce qui est ambigu et reste à vérifier dans le texte officiel. Obligations: déclarations mensuelles en ligne; sanction possible: suspension du service.
- Start-up: **exonération des droits de douane** sur les équipements destinés à leur développement (sans durée ni conditions précisées dans le résumé).
- **Crédit d'impôt de 20 %** des charges de formation, d'encadrement et d'insertion de jeunes diplômés.
- Comptabilité informatisée: fichier des écritures non modifiable, conservation 10 ans. Cessation d'activité: déclaration 3 mois avant, contrôle fiscal automatique.
- Mobile money: non cité directement. Le résumé mentionne un précompte sur les achats dans le secteur numérique et télécom, ainsi qu'une « taxation en temps réel » dont les modalités restent à préciser.

## Constat [A]
- Si NetBuis est immatriculé au Cameroun, le régime des non-résidents ne le vise pas. Il compte en revanche si la société est créée à l'étranger (France, Delaware...): le seuil de 1 000 utilisateurs est atteint dès le pilote.
- L'exonération start-up et le crédit d'impôt de 20 % sont à vérifier avec un comptable au moment de l'immatriculation. Ils peuvent alléger le coût des téléphones de test et des premiers recrutements.
- Rien ne change pour la concurrence, l'orchestration d'agents ou la gestion de projet.

## Sources
- [Deloitte, principales innovations de la loi de finances 2026](https://blog.avocats.deloitte.fr/cameroun-les-principales-innovations-de-la-loi-de-finances-pour-2026/)
- [Digital Business Africa, taxation des entreprises numériques étrangères](https://www.digitalbusiness.africa/loi-de-finances-2026-comment-le-cameroun-encadre-et-taxe-desormais-les-entreprises-du-numerique-operant-depuis-letranger/)
- [Le Fisk, circulaire d'application 2026](https://lefisk.cm/blog/circulaire-application-loi-finances-2026-cameroun-mesures-fiscales)


---

<!-- source : audit-expert-v163-aucune-nouveaute-netbuis.md -->

# Audit expert v163 NetBuis (2026-10-14 16:51 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- TVA numérique et magasins d'applications au Cameroun [S]: aucun résultat ciblé. Les résultats portent sur Max it TV d'Orange Cameroun (« le smartphone transformé en télévision portable » pour le Mondial 2026, Ecomatin, Camer.be, AllAfrica) et sur des alternatives à Google Play (PayPro Global).
- [A] La super-app Max it d'Orange est déjà suivie (v3, v4, v15). Elle continue d'ajouter des services; le risque qu'elle intègre un annuaire de commerçants reste à surveiller, sans action immédiate. L'app NetBuis restant gratuite pour l'acheteur, la TVA sur les achats intégrés ne la concerne pas au pilote.
- Concurrence, orchestration d'agents, gestion de projet, paiement: inchangé.

## Sources
- [Ecomatin, Max it TV d'Orange Cameroun](https://ecomatin.net/innovation-orange-cameroun-transforme-le-smartphone-en-tele-de-poche-avec-max-it-tv)
- [AllAfrica, Max it TV et le Mondial 2026](https://fr.allafrica.com/stories/202606120495.html)


---

<!-- source : audit-expert-v164-aucune-nouveaute-netbuis.md -->

# Audit expert v164 NetBuis (2026-10-14 17:50 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Recherche vocale en langues locales [S]: revue systématique arXiv sur la reconnaissance vocale des langues africaines peu dotées (oct. 2025), corpus « Pidgin Science Voices » (NeurIPS 2025), Afluence VoicePilot (MIT Solve), blog Google sur la « décennie numérique » africaine. Sujet déjà largement couvert dans les audits précédents.
- [A] Position inchangée: au pilote, la recherche vocale passe par la dictée du clavier Android (français/anglais, gratuite). Le pidgin camerounais et les langues locales restent hors périmètre tant qu'aucun modèle fiable n'existe; un dictionnaire de synonymes locaux (« pagne », « wax », noms pidgin des produits) apporte plus, pour moins cher.
- Concurrence, orchestration d'agents, gestion de projet, paiement: inchangé.

## Sources
- [arXiv, ASR pour les langues africaines peu dotées](https://arxiv.org/pdf/2510.01145)
- [NeurIPS 2025, Pidgin Science Voices](https://neurips.cc/virtual/2025/133854)


---

<!-- source : audit-expert-v165-aucune-nouveaute-netbuis.md -->

# Audit expert v165 NetBuis (2026-10-14 18:50 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Arnaques en ligne au Cameroun [S]: Digital Business Africa (cyberarnaque à 50 millions de FCFA, « arnaqueur VIP » interpellé, brouteurs vendant des « porte-monnaie magiques »), Cameroon Tribune (« Arnaques en ligne : ça prospère »), alerte du CERT togolais sur les fausses plateformes de vente. Camtel prépare son entrée dans le mobile money (déjà noté en v25).
- [A] Confirme un risque déjà identifié: la confiance est le cœur du produit. Mesures inchangées: commerçant vérifié par visite ou photo de la boutique avec repère GPS, badge « vérifié », signalement en un geste, aucun paiement à l'avance via l'app au pilote, message de prudence avant le premier appel.
- Concurrence, orchestration d'agents, gestion de projet: inchangé.

## Sources
- [Digital Business Africa, cyberarnaque à 50 millions de FCFA](https://www.digitalbusiness.africa/cameroun-une-cyberarnaque-a-50-millions-de-fcfa-des-suspects-interpelles/)
- [Cameroon Tribune, arnaques en ligne](https://cameroon-tribune.cm/article.html/66452/fr.html/details_2)


---

<!-- source : audit-expert-v166-aucune-nouveaute-netbuis.md -->

# Audit expert v166 NetBuis (2026-10-14 19:50 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- E-commerce et livraison au Cameroun [S]: ancien partenariat Jumia-Campost (Business in Cameroon), Glotelho (Camer.be), guide Kolonell 2026 sur l'e-commerce avec Orange Money/MTN MoMo et la livraison à Douala/Yaoundé, TechCabal. Sources déjà vues (v102, v107, v109); aucun retour de Jumia ni lancement de Glovo au Cameroun dans les titres.
- [A] Positionnement inchangé: NetBuis n'est pas un site d'e-commerce avec livraison. Il trouve le commerçant de quartier qui a le produit en stock et met en contact. La livraison reste hors périmètre au pilote; on pourra plus tard ajouter un lien vers un livreur moto local.
- Concurrence, orchestration d'agents, gestion de projet, paiement: inchangé.

## Sources
- [Kolonell, e-commerce au Cameroun 2026](https://kolonell.com/fr/blog/ecommerce-cameroun-orange-money-cm-mtn-momo-livraison-douala-yaounde-2026)
- [Business in Cameroon, Jumia et Campost](https://www.businessincameroon.com/telecom/0804-6119-jumia-expands-its-operations-in-cameroon-through-the-network-of-public-operator-campost)


---

<!-- source : audit-expert-v167-aucune-nouveaute-netbuis.md -->

# Audit expert v167 NetBuis (2026-10-14 20:50 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Pile mobile [S]: Expo SDK 56 avec React Native 0.85 et React 19.2 (issoh.co.jp, Hashnode), page « latest » de la doc Expo, notes de version de SDK tiers. Déjà relevé dans l'addendum recherche-apis-github 174 du 13/10.
- [A] Inchangé: démarrer sur la dernière version stable d'Expo, et vérifier dans les notes de version la version minimale d'Android supportée avant de figer la cible du pilote (voir v161, parc de téléphones d'entrée de gamme).
- Concurrence, orchestration d'agents, gestion de projet, paiement: inchangé.

## Sources
- [Hashnode, Expo SDK 56 et React Native 0.85](https://hashnode.com/posts/react-native-updates/6a1fb64e8491d4ac1252f633)
- [Expo, documentation à jour](https://docs.expo.dev/more/latest/)


---

<!-- source : audit-expert-v168-aucune-nouveaute-netbuis.md -->

# Audit expert v168 NetBuis (2026-10-14 21:51 UTC): aucune nouveauté

[S] = titres de résultats web seulement; [A] = mon avis.

- Coût du backend, Supabase 2026 [S]: guides tarifaires Jetadmin, Makerkit (avec calculateur), Activepieces (limites du gratuit, coût Pro, egress), Toolradar (« quand Firebase ou Neon l'emporte »), Costbench (coûts cachés). Les titres n'annoncent aucun changement de grille; Supabase est déjà cité dans 6 audits.
- [A] Inchangé: l'offre gratuite suffit pour le jalon 0 et le début du pilote. Le premier poste de coût à surveiller est l'egress (images des produits), pas la base. On compresse les images côté client et on les sert depuis un CDN; l'option payante (environ 25 $/mois en Pro, à vérifier sur la page officielle) ne se justifie qu'au-delà du pilote.
- Concurrence, orchestration d'agents, gestion de projet, paiement: inchangé.

## Sources
- [Makerkit, Supabase pricing 2026](https://makerkit.dev/blog/saas/supabase-pricing)
- [Activepieces, limites du gratuit et egress](https://www.activepieces.com/blog/supabase-pricing-free-tier-limits-pro-costs-egress.md)


---

<!-- source : audit-expert-v169-frais-agregateurs-netbuis.md -->

# Audit expert v169 NetBuis (2026-10-14 22:50 UTC): piste mineure, frais des agrégateurs de paiement

[S] = source lue (blog Kolonell, via l'outil de lecture); [A] = mon avis.

## Faits [S], ordres de grandeur, taux exacts selon contrat
| Agrégateur | Commission agrégateur | Frais opérateur | Total à l'encaissement |
|---|---|---|---|
| PayDunya | ~1,0 % | ~1,5 % | ~2,5 % |
| NotchPay | ~0,5 à 1 % | ~1,5 % | ~2,0 à 2,5 % |
| Fapshi | ~0,5 à 1 % | ~1,5 % | ~2,0 à 2,5 % |
| Intégration directe MTN/Orange | 0 % | ~1,5 % | ~1,5 % (développement à la charge du marchand) |
- Les versements vers un compte (retraits ou disbursements) sont souvent facturés à part, autour de 0,5 à 1 %.
- Campay n'est pas cité dans cet article.
- Autre résultat, titre seulement: un texte de 2025 précise les modalités d'agrément et de cessation d'activité des prestataires de services de paiement électronique au Cameroun (La Base Lextenso).

## Constat [A]
- La décision Campay (decision-campay-netbuis.md) ne change pas: l'interface `PaymentProvider` permet de changer d'agrégateur. NotchPay et Fapshi deviennent des solutions de repli crédibles; il faut comparer leurs devis avec celui de Campay au moment de facturer les commerçants.
- Pour un abonnement commerçant de 2 000 à 5 000 FCFA par mois, compter environ 2 à 3,5 % de frais au total (encaissement puis versement), soit 50 à 175 FCFA par abonnement. C'est acceptable; inutile de se lancer dans une intégration directe avant d'avoir du volume.
- Vérifier que l'agrégateur retenu dispose bien de l'agrément de prestataire de paiement électronique exigé par le texte de 2025.

## Sources
- [Kolonell, grille tarifaire des agrégateurs de paiement 2026](https://kolonell.com/fr/blog/grille-tarifaire-agregateur-paiement-cameroun-2026)
- [Kolonell, frais cachés des agrégateurs](https://kolonell.com/fr/blog/frais-caches-agregateurs-paiement-cameroun-2026)
- [La Base Lextenso, agrément des prestataires de paiement électronique](https://www.labase-lextenso.fr/l-essentiel-droits-africains-des-affaires/2025-n5/cameroun-precision-des-modalites-d-agrement-et-de-cessation-d-activites-des-prestataires-de-services-de-paiement-par-voie-electronique-DAA203a0)


---

<!-- source : audit-expert-v170-onboarding-commercants-netbuis.md -->

# Audit expert v170 NetBuis (2026-10-14 23:51 UTC): onboarding des commerçants
[S] = source web; [A] = mon avis.

## Fait(s) [S]
- Les guides 2026 sur les marketplaces africaines (Lagos, Kigali) traitent l'onboarding vendeur comme un flux à part : KYC par paliers, acquisition des 100 premiers vendeurs à la main. Je n'ai lu que les titres et extraits de ces pages.
- Sabi (B2B, Nigeria) a atteint 150 000 commerçants en s'appuyant sur des agents de terrain (titre de presse Janngo, non relu en détail).

## Constat [A]
- Le risque n°1 de NetBuis n'est pas la technique : c'est un catalogue vide dans le quartier pilote. Sans stock à jour, la recherche ne renvoie rien et l'utilisateur ne revient pas.
- Onboarding recommandé :
  - Inscription du commerçant en moins de 3 minutes : téléphone + OTP, nom de la boutique, position GPS, 5 produits.
  - Saisie possible par un agent de terrain pour le compte du commerçant, avec un KYC léger d'abord (téléphone) et la vérification CNI seulement pour le badge « vérifié ».
  - Les 30 premiers commerçants sont recrutés en personne, pas via l'app.
- Rétention :
  - Chaque semaine, envoyer un SMS au commerçant avec le nombre de recherches et d'appels qu'il a reçus. C'est la preuve de valeur.
  - Mettre à jour le stock en un geste : « encore en stock ? oui/non ».
  - Si un produit n'est pas confirmé depuis 14 jours, le masquer automatiquement.
- Indicateur à suivre au jalon 0 : la part des commerçants qui mettent à jour leur stock au moins une fois par semaine.

## Sources
- https://kolonell.com/en/blog/seller-acquisition-marketplace-first-100-2026
- https://kolonell.com/en/blog/seller-kyc-onboarding-marketplace-lagos-2026
- https://www.janngo.com/media/page/2/


---

<!-- source : audit-expert-v171-aucune-nouveaute-netbuis.md -->

# Audit expert v171 NetBuis (2026-10-15 00:51 UTC): aucune nouveauté
[S] = source web; [A] = mon avis.

- [S] Une recherche sur Buyam (Cameroun, octobre 2026) n'a rien renvoyé de pertinent : aucune actualité ni mise à jour concurrente trouvée.
- [A] Rien ne change dans les recommandations. Le point le plus utile reste celui de la v170 : recruter à la main les 30 premiers commerçants et leur envoyer chaque semaine un SMS avec leurs recherches et appels reçus.
- [A] Je recommande toujours de passer cette routine en hebdomadaire ou de la suspendre, et de lancer le jalon 0.

## Sources
- Recherche web « Buyam Cameroun application octobre 2026 » : aucun résultat pertinent.


---

<!-- source : audit-expert-v172-notifications-push-netbuis.md -->

# Audit expert v172 NetBuis (2026-10-15 01:51 UTC): notifications push
[S] = source web; [A] = mon avis.

## Fait(s) [S]
- Les plateformes de push (CleverTap, MoEngage, Netcore) donnent les mêmes causes principales de non-livraison sur Android :
  - économiseurs de batterie des constructeurs, qui tuent l'app en arrière-plan ;
  - app « forcée à l'arrêt » par l'utilisateur ;
  - jetons FCM expirés ;
  - téléphone hors ligne longtemps.
- Firebase distingue deux priorités de message : normale et haute. La priorité haute réveille l'appareil en mode Doze. Elle est réservée aux messages qui entraînent une action visible de l'utilisateur ; si elle est abusée, Android peut la rabaisser.

## Constat [A]
- Au Cameroun, beaucoup de téléphones viennent de Tecno, Infinix, itel ou Xiaomi, dont les surcouches sont agressives sur la batterie. Il faut donc s'attendre à ce qu'une partie notable des push n'arrive jamais. Je n'ai pas trouvé de chiffre fiable propre au Cameroun.
- Pour NetBuis :
  - Ne jamais faire dépendre une fonction critique du push (alerte stock commerçant, réponse au forum).
  - Doubler les messages importants par SMS ou WhatsApp utility. Les messages WhatsApp sont payants : les garder rares.
  - Côté commerçant, afficher dans l'app un écran « Autoriser NetBuis en arrière-plan », avec la marche à suivre par marque.
  - Purger les jetons FCM invalides côté backend.
  - Mesurer le taux d'ouverture par modèle de téléphone.
  - Rester en priorité normale, sauf pour une demande d'appel client.
- Jalon 0 : pas de push du tout, le SMS hebdomadaire de la v170 suffit.

## Sources
- https://clevertap.com/blog/why-push-notifications-go-undelivered-and-what-to-do-about-it/
- https://firebase.google.com/docs/cloud-messaging/android/message-priority
- https://help.moengage.com/hc/en-us/articles/213367903-Why-Aren-t-End-Users-Receiving-Push-Notifications


---

<!-- source : audit-expert-v173-recherche-synonymes-netbuis.md -->

# Audit expert v173 NetBuis (2026-10-15 02:51 UTC): recherche floue et synonymes locaux
[S] = source web; [A] = mon avis.

- [S] Rien de nouveau. La recherche floue (pg_trgm sur Postgres/Supabase, Typesense) est déjà traitée dans le backlog et dans le plan de réalisation. Typesense documente une migration depuis le plein texte Postgres, et un modèle Railway existe pour l'héberger.
- [A] Ce qui manque encore, ce sont les synonymes locaux. Une recherche floue tolère les fautes de frappe, mais elle ne relie pas « miondo » à « bâton de manioc », ni « plantain » à « banane plantain ».
  - Il faut un petit dictionnaire de synonymes français, pidgin et noms de marque, maintenu à la main.
  - Il doit être enrichi chaque semaine à partir des recherches sans résultat.
- [A] Au pilote, garder pg_trgm avec une table de synonymes dans Supabase. Passer à Typesense seulement si les recherches deviennent lentes ou si le catalogue dépasse quelques dizaines de milliers de produits. C'est une estimation, pas une mesure.

## Sources
- https://typesense.org/docs/guide/postgres-typesense-migration-fts.html
- https://chat2db.ai/resources/blog/postgres-pg-trgm-fuzzy-text-search


---

<!-- source : audit-expert-v174-supabase-rls-fuite-netbuis.md -->

# Audit expert v174 NetBuis (2026-10-15 03:51 UTC): sécurité Supabase (RLS)
[S] = source web; [A] = mon avis.

## Fait(s) [S]
- Le 28 septembre 2026, UpGuard a publié une étude portant sur environ 300 000 domaines qui utilisent Supabase.
  - Plus de 16 000 bases avaient des tables lisibles par n'importe qui.
  - Certaines contenaient des données personnelles, des mots de passe en clair et des jetons.
- Cause : Row Level Security (RLS) absente ou inefficace, et clés publiques mal utilisées.
- Selon UpGuard, beaucoup de ces sites auraient été générés par des agents IA de codage, sans que ce soit confirmé dans tous les cas.

## Constat [A]
- NetBuis cumule exactement ces deux facteurs : Supabase et un développement par agents IA. Le risque est donc direct.
- Comme la loi camerounaise sur les données personnelles est en vigueur depuis le 23 juin 2026, une fuite des numéros des clients ou des commerçants aurait aussi des conséquences juridiques.
- Règles à ajouter au cahier des agents, vérifiées par la CI :
  1. RLS activée sur chaque table du schéma public. La CI échoue si une table n'en a pas : on peut lire `pg_tables.rowsecurity`, ou utiliser le Security Advisor de Supabase.
  2. Aucune clé `service_role` dans l'app Expo ni dans le dépôt, avec un scan de secrets en CI.
  3. Aucune colonne mot de passe ou jeton dans les tables métier : tout passe par Supabase Auth.
  4. Un test automatique qui lit chaque table avec la clé anon et vérifie qu'il ne reçoit rien de privé.
- Ce point justifie à lui seul que l'agent « sécurité/revue » existe, et que l'humain valide toute migration de schéma.

## Sources
- https://startwithidentity.com/blog/2026-09-28-16000-supabase-databases-readable-because-row-level-security-was-off/
- https://unpwned.io/qa/supabase/common-supabase-security-mistakes
- https://www.penetrify.cloud/en/blog/supabase-service-role-key-exposed/


---

<!-- source : audit-expert-v175-aucune-nouveaute-netbuis.md -->

# Audit expert v175 NetBuis (2026-10-15 04:51 UTC): aucune nouveauté
[S] = source web; [A] = mon avis.

- [S] Exigences Google Play sur le niveau d'API cible : déjà couvertes en v14 (API 36) et en v24 (Android 17). La date limite était le 31 août 2026 pour les mises à jour. Rien de neuf trouvé pour octobre.
- [A] Expo SDK 56 cible déjà le bon niveau d'API, donc aucune action.
- [A] Priorité inchangée : appliquer les 4 règles de sécurité Supabase de la v174 dès la première migration, puis lancer le jalon 0.

## Sources
- https://developer.android.com/google/play/requirements/target-sdk
- https://support.google.com/googleplay/android-developer/answer/14554743


---

<!-- source : audit-expert-v176-otp-sms-pumping-netbuis.md -->

# Audit expert v176 NetBuis (2026-10-15 05:51 UTC): fraude aux OTP SMS (rappel)
[S] = source web; [A] = mon avis.

- [S] La fraude par « SMS pumping » est déjà notée en v4. Le principe : des robots déclenchent des milliers d'OTP vers des numéros surtaxés, et c'est l'app qui paie l'envoi. Authsignal et Authgear recommandent :
  - une limite de débit par IP, par appareil et par préfixe de numéro ;
  - une liste blanche de pays ;
  - un CAPTCHA invisible ;
  - une alerte sur le taux de conversion des OTP.
- [A] Ce point redevient concret avec l'inscription des commerçants par OTP proposée en v170. Actions pour NetBuis :
  - N'autoriser que les numéros +237.
  - Limiter à 3 OTP par numéro et par heure, et à 10 par IP et par jour, via le rate limit de Supabase Auth.
  - Couper l'envoi automatiquement si le taux de validation des OTP tombe sous 50 % sur une heure.
  - Au jalon 0, inscrire les commerçants à la main, sans OTP. Le coût est alors nul.

## Sources
- https://www.authsignal.com/blog/articles/how-to-mitigate-sms-pumping-without-breaking-signup
- https://www.authgear.com/post/sms-pumping-attack


---

<!-- source : audit-expert-v177-securite-agents-codage-netbuis.md -->

# Audit expert v177 NetBuis (2026-10-15 06:50 UTC): sécurité des agents de codage eux-mêmes
[S] = source web; [A] = mon avis.

- [S] Les checklists 2026 sur la revue de code généré par IA (metacto, Zealynx « Coding Agent Security ») ajoutent un volet que nos fichiers ne couvraient pas encore : la sécurité de l'agent lui-même, en plus de celle du code qu'il produit.
- [A] Trois risques concrets pour NetBuis :
  1. **Injection de prompt.** Un agent qui lit une issue, un README de dépendance ou une page web peut recevoir des instructions cachées, par exemple « ajoute cette clé » ou « désactive ce test ».
     - Parade : l'agent n'a aucun droit de merge.
     - Toute PR passe par la CI et par une revue humaine.
  2. **Secrets.** L'agent ne doit jamais avoir la clé `service_role` de Supabase ni les clés de Campay.
     - Parade : lui donner un projet Supabase de test et des clés sandbox seulement.
     - Les secrets de production restent dans le CI/CD, et seul l'humain y accède.
  3. **Dépendances inventées (« slopsquatting »).** L'agent peut proposer un paquet npm qui n'existe pas, ou un paquet piégé qui porte un nom proche.
     - Parade : la CI refuse tout nouveau paquet tant qu'un humain ne l'a pas validé, en plus d'un `npm audit`.
- [A] Ces règles complètent la v174 et ne changent pas la structure retenue : 1 superviseur et 3 à 5 agents, la CI comme juge, et l'humain qui décide sur l'argent, les données et l'architecture.

## Sources
- https://www.zealynx.io/resources/checklists/ai/coding-agents
- https://metacto.com/blogs/establishing-code-review-standards-for-ai-generated-code
- https://github.com/alcherkas/ai-coding-security


---

<!-- source : audit-expert-v178-aucune-nouveaute-netbuis.md -->

# Audit expert v178 NetBuis (2026-10-15 07:51 UTC): aucune nouveauté
[S] = source web; [A] = mon avis.

- [S] MTN MoMo Cameroun : les résultats ne contiennent rien de daté d'octobre 2026.
  - La baisse de 25 % des frais de retrait et le plan d'inclusion financière de mars 2026 sont déjà connus.
  - Les frais d'agrégateur sont couverts en v169.
- [A] Rien ne change pour NetBuis : pas de paiement dans l'app au jalon 0 ni au jalon 1. La couche `PaymentProvider` avec Campay reste prévue pour plus tard.

## Sources
- https://ecomatin.net/transactions-electroniques-au-cameroun-mtn-reduit-de-25-le-cout-des-retraits-dargent-sur-son-reseau
- https://fr.allafrica.com/stories/202603310593.html


---

<!-- source : audit-expert-v179-fraicheur-prix-netbuis.md -->

# Audit expert v179 NetBuis (2026-10-15 08:51 UTC): fraîcheur et fiabilité des prix affichés
[S] = source web; [A] = mon avis.

## Fait(s) [S]
- Au Nigeria, une étude du CGIAR et des travaux publiés sur PMC portent sur la collecte participative des prix alimentaires par mobile. La donnée brute est bruitée ; il faut un pré-traitement statistique pour la rendre « crowd-trusted » : écarter les valeurs aberrantes et pondérer selon la fiabilité de chaque contributeur.
- Il existe déjà des apps africaines de comparaison de prix, par exemple PriceSenseNG et celles listées sur startuplist.africa.

## Constat [A]
- Un prix faux ou périmé est pire que pas de prix du tout. L'utilisateur appelle le commerçant, découvre un autre prix et n'a plus confiance.
- Pour NetBuis :
  - Afficher l'âge du prix à côté du prix, par exemple « prix confirmé il y a 3 jours ».
  - Après 14 jours sans confirmation, griser le prix ou le remplacer par « prix à demander ». La règle est la même que pour le stock en v170.
  - Ajouter un bouton « le prix n'était pas le bon » après un appel. Au bout de 3 signalements, le commerçant est invité à mettre à jour son prix.
  - Ne pas faire saisir les prix par les clients au pilote : il y a trop de bruit et un risque de conflit avec les commerçants. Les prix viennent seulement des commerçants.
- Indicateur au jalon 0 : la part des appels où le prix annoncé correspondait au prix réel, mesurée par une question courte après l'appel.

## Sources
- https://cgspace.cgiar.org/items/2d50001b-d36c-447b-8638-c76c5ea85e7b
- https://pmc.ncbi.nlm.nih.gov/articles/PMC10338426
- https://startuplist.africa/industry/price-comparison


---

<!-- source : audit-expert-v180-fiche-play-store-netbuis.md -->

# Audit expert v180 NetBuis (2026-10-15 09:51 UTC): fiche Google Play (ASO)
[S] = source web; [A] = mon avis.

## Fait(s) [S]
- D'après le guide ASO Cameroun d'appdrift :
  - 13,5 M d'internautes, soit 46,3 % de la population (Banque mondiale/UIT, 2024).
  - Google Play est le store dominant.
  - Le français (fr-CM) est la langue principale et l'anglais la langue secondaire. Le guide conseille des métadonnées dans les deux langues.
  - La concurrence ASO est jugée « faible ».
  - Catégories en tête : réseaux sociaux, communication, finance, divertissement, jeux.

## Constat [A]
- Aucun de nos fichiers ne traitait encore de la fiche Play Store. Or c'est souvent le premier contact avec NetBuis.
- Recommandations :
  - Une fiche en français et une en anglais. Le titre contient le bénéfice, par exemple « NetBuis : trouve le produit près de toi ».
  - Mots-clés à couvrir : « où acheter », « boutique près de moi », « Douala », « Yaoundé », plus les noms de produits locaux (voir les synonymes en v173).
  - 4 captures d'écran, chacune avec une phrase courte : chercher, voir les commerçants, appeler, signaler. Mettre en avant « gratuit, pas de paiement d'avance », ce qui répond à la peur des arnaques (v165).
  - Afficher la taille de l'APK, sous 15 Mo, et le fait que l'app marche hors ligne. Ce sont deux arguments décisifs pour un public qui paie ses données mobiles.
  - Catégorie : « Shopping » plutôt que « Business ».
- Le guide n'apporte pas de chiffre propre à la catégorie Shopping ; le niveau « faible » de concurrence vient du guide et n'a pas été vérifié par moi.

## Sources
- https://appdrift.co/app-store-optimization/cameroon


---

<!-- source : audit-expert-v181-aucune-nouveaute-netbuis.md -->

# Audit expert v181 NetBuis (2026-10-15 10:51 UTC): aucune nouveauté
[S] = source web; [A] = mon avis.

- [S] Suivi des plantages (Sentry et alternatives) : déjà prévu dans le plan de réalisation et dans les recherches d'API GitHub. Expo documente l'intégration de Sentry. Les comparatifs 2026 (OneUptime, Dupple) ne changent rien d'important.
- [A] Rester sur l'offre gratuite de Sentry ou sur Firebase Crashlytics au pilote. Ajouter le modèle du téléphone et la RAM aux rapports, pour vérifier la cible de 2 Go de RAM.
- [A] Rien de neuf à signaler. La recommandation reste la même : passer cette routine en hebdomadaire et lancer le jalon 0.

## Sources
- https://docs.expo.dev/guides/using-sentry
- https://oneuptime.com/blog/post/2026-03-12-10-best-sentry-alternatives-2026/markdown


---

<!-- source : audit-expert-v182-aucune-nouveaute-netbuis.md -->

# Audit expert v182 NetBuis (2026-10-15 11:51 UTC): aucune nouveauté
[S] = source web; [A] = mon avis.

- [S] Je n'ai trouvé aucune étude 2026 sur l'usage de WhatsApp Business par les commerçants camerounais. Les résultats sont des statistiques mondiales (Infobip, Landbot) et des articles anciens.
- [A] Rien ne change. Le canal WhatsApp attend toujours la décision de Jeff. Le fait que ces messages sont payants depuis le 1er octobre 2026 est déjà noté.
- [A] La question pourra être tranchée au jalon 0 : demander à chacun des 30 premiers commerçants s'il préfère être contacté par appel, SMS ou WhatsApp.

## Sources
- https://www.infobip.com/blog/whatsapp-statistics


---

<!-- source : audit-expert-v183-aucune-nouveaute-netbuis.md -->

# Audit expert v183 NetBuis (2026-10-15 12:51 UTC): aucune nouveauté
[S] = source web; [A] = mon avis.

- [S] Supabase en octobre 2026 : je n'ai trouvé aucune annonce ni aucun changement de prix. Les seules traces sont des historiques de pannes (isdown, uptimerobot : incidents des 4 et 16 septembre 2026) et un ajout d'offre en février 2026.
- [A] Ces pannes rappellent la recommandation de la v157 : un cache local hors ligne et un repli vers le composeur ou le SMS. Ainsi, une panne de Supabase n'empêche pas d'appeler un commerçant déjà affiché.
- [A] Aucune action nouvelle.

## Sources
- https://isdown.app/status/supabase/outage-history
- https://www.costbench.com/changelog/supabase-plan-added-2026-02/


---

<!-- source : audit-expert-v184-douala-huawei-netbuis.md -->

# Audit expert v184 NetBuis (2026-10-15 13:51 UTC): piste mineure, Douala et Huawei
[S] = source web; [A] = mon avis.

## Fait(s) [S]
- Le 28 avril 2026, la mairie de Douala a signé un protocole d'accord avec Huawei pour la « modernisation numérique » de la ville :
  - vidéosurveillance et capteurs de trafic ;
  - informatique municipale ;
  - numérisation de 200 000 titres fonciers ;
  - fibre et éclairage public ;
  - formation via l'ICT Academy.
- Le financement et le calendrier n'ont pas été publiés. L'article ne parle ni des marchés, ni des commerçants, ni de données ouvertes.

## Constat [A]
- Cet accord n'a pas d'impact direct sur NetBuis. La fibre étendue pourrait améliorer la connexion des commerçants de Douala à moyen terme, mais rien n'est daté.
- Je n'en tire aucune action. Le concurrent Nkwel, qui digitalise le commerce de quartier, est déjà suivi.

## Sources
- https://www.businessincameroon.com/public-management/0105-16108-douala-partners-huawei-to-advance-digital-transformation-plans


---

<!-- source : audit-expert-v185-expo-sdk57-correction-netbuis.md -->

# Audit expert v185 NetBuis (2026-10-15 14:51 UTC): correction, Expo SDK 57 existe déjà
[S] = source web; [A] = mon avis.

## Fait(s) [S]
- Expo SDK 57 est sorti le 30 juin 2026, avec React Native 0.86 et React 19.2.
- La mise à jour depuis SDK 56 se fait sans changement cassant.
- Nouveautés :
  - `expo prebuild` régénère les dossiers natifs par défaut ;
  - nouvelles fonctions de cache dans `expo-image` ;
  - corrections pour l'affichage bord à bord sur Android.
- Deux régressions Hermes V1 :
  - une hausse de mémoire avec Reanimated ou Worklets, corrigée dans `expo@57.0.9` ;
  - une hausse du temps de démarrage en mode développement, corrigée dans `expo@57.0.17` et sans effet en production.

## Constat [A]
- **Correction de la v167**, qui partait de SDK 56 / RN 0.85 comme version actuelle. Il faut démarrer le projet sur SDK 57, en version `57.0.17` ou plus récente.
- La régression de mémoire concerne directement notre cible de 2 Go de RAM. Il faut verrouiller une version au moins égale à 57.0.9 et mesurer la RAM sur un téléphone d'entrée de gamme avant le jalon 1.
- Le reste ne change pas. SDK 58 rendra un changement de cycle de vie iOS obligatoire, mais iOS n'est pas prioritaire.

## Sources
- https://expo.dev/changelog/sdk-57
- https://releases.sh/release/rel_aH7NaXbDXMlY2_I-Ak0D0


---

<!-- source : audit-expert-v186-aucune-nouveaute-netbuis.md -->

# Audit expert v186 NetBuis (2026-10-15 15:51 UTC): aucune nouveauté
[S] = source web; [A] = mon avis.

- [S] Orchestration d'agents : les guides 2026 de morphllm et Tembo sur les sous-agents, les « agent teams » et les worktrees parallèles de Claude Code sont déjà cités en v10, v101 et v106. Je n'ai rien trouvé de neuf.
- [A] La règle retenue ne change pas : 1 superviseur et 3 à 5 agents spécialisés, chacun dans son propre worktree, la CI comme juge, et l'humain qui décide sur l'argent, les données et l'architecture.
- [A] On y ajoute les garde-fous des v174 et v177 : sécurité Supabase et sécurité des agents.

## Sources
- https://www.morphllm.com/agent-teams-vs-subagents
- https://www.tembo.io/blog/claude-code-multi-agent-orchestration


---

<!-- source : audit-expert-v187-aucune-nouveaute-netbuis.md -->

# Audit expert v187 NetBuis (2026-10-15 16:51 UTC): aucune nouveauté
[S] = source web; [A] = mon avis.

- [S] Synchronisation hors ligne : PowerSync et Supabase sont déjà notés dans l'addendum 190 des recherches d'API (13 octobre). Les résultats de ce jour sont des annuaires sans chiffre de prix récent.
- [A] Au pilote, pas de moteur de synchronisation. Un cache en lecture seule, avec AsyncStorage ou SQLite, suffit pour afficher les commerçants déjà vus et les appeler hors ligne (v157). PowerSync ne devient utile que si les commerçants modifient leur stock hors ligne, donc pas avant le jalon 2.

## Sources
- https://toolradar.com/tools/powersync


---

<!-- source : audit-expert-v188-accessibilite-netbuis.md -->

# Audit expert v188 NetBuis (2026-10-15 17:50 UTC): accessibilité

Légende : [S] = source web ; [A] = mon avis.

## Fait(s) [S]
- React Native respecte par défaut la taille de police système (`allowFontScaling`). `maxFontSizeMultiplier` permet de plafonner sans désactiver.
- Sur Android, TalkBack lit `accessibilityLabel` et `accessibilityRole`. Les zones tactiles doivent faire au moins 48 dp.
- Les tests d'accessibilité peuvent être automatisés (requêtes `getByRole` / `getByLabelText` de React Native Testing Library) et vérifiés à la main avec TalkBack et Accessibility Scanner.

## Constat [A]
- Sujet non couvert jusqu'ici (seules la voix et la lisibilité pour faible alphabétisation l'étaient, v8, v11).
- Beaucoup d'utilisateurs camerounais grossissent la police sur des téléphones d'entrée de gamme. Un écran de résultat qui casse à 1,3x fait perdre l'appel au commerçant.
- Corrections à bas coût :
  - ne jamais mettre `allowFontScaling={false}` ; plafonner à `maxFontSizeMultiplier={1.6}` sur les titres seulement ;
  - bouton « Appeler » de 48 dp minimum, avec `accessibilityRole="button"` et un label « Appeler <commerçant> » ;
  - contraste 4,5:1 minimum, prix grisé (v179) doit rester lisible ;
  - utiliser `getByRole` dans les tests : cela rend les tests et l'accessibilité solidaires.
- Pour l'orchestration : ajouter une vérification (lint `eslint-plugin-react-native-a11y`) à l'agent de test, pas un agent de plus.

## Sources
- [OneUptime : dynamic font scaling](https://oneuptime.com/blog/post/2026-01-15-react-native-dynamic-font-scaling/view)
- [Callstack : Android accessibility tips](https://www.callstack.com/blog/react-native-android-accessibility-tips)
- [OneUptime : tester l'accessibilité](https://oneuptime.com/blog/post/2026-01-15-react-native-accessibility-testing/markdown)
- [AccessibilityChecker : guide 2026](https://www.accessibilitychecker.org/blog/react-native-accessibility/)


---

<!-- source : audit-expert-v189-recherche-sans-resultat-netbuis.md -->

# Audit expert v189 NetBuis (2026-10-15 18:51 UTC): recherche sans résultat

Légende : [S] = source web ; [A] = mon avis.

## Fait(s) [S]
- Baymard : une page « aucun résultat » qui ne propose rien fait abandonner l'utilisateur. Les bonnes pages proposent une correction d'orthographe, des catégories proches et une autre façon d'avancer.
- Les guides e-commerce recommandent de journaliser chaque recherche sans résultat pour savoir quoi ajouter au catalogue.

## Constat [A]
- Pour NetBuis, l'écran vide est le moment le plus probable du pilote : avec 30 commerçants, la plupart des recherches ne trouveront rien.
- Ce qu'il faut afficher au lieu d'un écran vide :
  - « Vous vouliez dire… » via pg_trgm et la table de synonymes (v173) ;
  - les commerçants du quartier qui vendent la catégorie la plus proche, avec le bouton Appeler ;
  - un bouton « Prévenez-moi par SMS quand quelqu'un l'a » (SMS, pas push, v172).
- Chaque recherche vide alimente la vue « forte demande » et le SMS hebdomadaire aux commerçants (« 12 personnes ont cherché du gaz 12,5 kg cette semaine »). C'est l'argument de recrutement des commerçants suivants.
- Indicateur pilote à suivre : taux de recherches sans résultat par quartier. S'il reste au-dessus de 50 %, recruter avant de développer.

## Sources
- [Baymard : no results page](https://baymard.com/research-articles/no-results-page)
- [Poper : zero results page best practices](https://www.poper.ai/blog/zero-results-page-best-practices/)
- [UX Magazine : is your UI causing zero results](https://uxmag.com/articles/is-your-ui-causing-zero-search-results-pages)


---

<!-- source : audit-expert-v190-sauvegardes-base-netbuis.md -->

# Audit expert v190 NetBuis (2026-10-15 19:50 UTC): sauvegardes de la base

Légende : [S] = source web ; [A] = mon avis.

## Fait(s) [S]
- Recherche « Supabase backups PITR pricing 2026 » : les guides tarifaires 2026 (Jetadmin, Makerkit, selfhost.dev) et la page officielle supabase.com/pricing traitent le sujet. Les extraits ne donnaient pas les chiffres ; à relire sur la page officielle avant décision.

## Constat [A] (de mémoire, à vérifier sur supabase.com/pricing)
- Le plan gratuit ne donne pas de sauvegarde restaurable par l'équipe et met le projet en pause après une semaine sans activité. Il convient au développement, pas au pilote.
- Le plan Pro (environ 25 $/mois) inclut des sauvegardes quotidiennes gardées quelques jours. La restauration à la minute (PITR) est une option payante en plus, inutile au pilote.
- Ce qui manque au plan actuel (le sujet n'était cité qu'en passant, v-loi données) :
  - un `pg_dump` chiffré chaque nuit par une tâche planifiée (GitHub Actions), conservé 30 jours ;
  - un test de restauration une fois par mois sur une base vide. Une sauvegarde jamais restaurée n'est pas une sauvegarde ;
  - le lieu de stockage de ce dump doit respecter la loi camerounaise sur les données (transfert hors du pays soumis à autorisation, déjà noté) ;
  - les agents n'ont jamais accès à la base de production ni aux dumps (cohérent avec v174 et v177).
- Coût : quasi nul en plus du plan Pro. À décider par Jeff : passer en Pro au lancement du pilote, pas avant.

## Sources
- [Supabase pricing (officiel)](https://supabase.com/pricing)
- [Jetadmin : Supabase pricing 2026](https://www.jetadmin.io/blog/supabase-pricing-2026-guide-to-plans-limits-and-real-world-costs/)
- [Makerkit : Supabase pricing](https://makerkit.dev/blog/saas/supabase-pricing)
- [selfhost.dev : what $25 really gets you](https://selfhost.dev/blog/supabase-pricing-explained/)


---

<!-- source : audit-expert-v191-mode-sombre-netbuis.md -->

# Audit expert v191 NetBuis (2026-10-15 20:50 UTC): mode sombre

Légende : [S] = source web ; [A] = mon avis.

## Fait(s) [S]
- Purdue (2022) : le mode sombre économise surtout à forte luminosité et seulement sur écran OLED. À luminosité moyenne, le gain est faible (quelques pour cent).
- Les tests récents (PhoneArena, Android Authority, Chargie 2026) confirment : gain réel sur OLED, quasi nul sur LCD.

## Constat [A]
- Sujet jamais traité dans les audits précédents.
- La plupart des Tecno, Infinix et itel d'entrée de gamme ont un écran LCD. Le mode sombre n'y fait pas économiser de batterie ; ce n'est pas un argument produit.
- Il reste utile pour le confort et parce que beaucoup d'utilisateurs l'activent dans Android. Une app qui reste blanche ou qui casse en mode sombre paraît datée.
- Recommandation à bas coût : suivre le thème du système (`userInterfaceStyle: "automatic"` dans app.json, `useColorScheme()`), avec des couleurs en jetons dès le départ. Pas d'interrupteur dans l'app au pilote.
- Piège à tester : en plein soleil au marché, le mode clair est plus lisible. Vérifier le contraste du prix et du bouton Appeler dans les deux thèmes (lien avec v188).
- Priorité basse : à faire au jalon 1, pas au jalon 0.

## Sources
- [Purdue : shedding light on dark mode](https://engineering.purdue.edu/ECE/News/2022/shedding-light-on-dark-mode-to-save-energy)
- [Android Authority : dark mode study](https://www.androidauthority.com/dark-mode-study-battery-2026759/)
- [PhoneArena : OLED battery test](https://www.phonearena.com/news/dark-mode-oled-display-battery-life-test_id134036)
- [Chargie : does dark mode save battery (2026)](https://chargie.org/does-dark-mode-save-battery/)


---

<!-- source : audit-expert-v192-notation-commercants-netbuis.md -->

# Audit expert v192 NetBuis (2026-10-15 21:50 UTC): notation des commerçants

Légende : [S] = source web ; [A] = mon avis.

## Fait(s) [S]
- Les guides d'architecture d'avis (LowCode Agency, Clarity Ventures, Xgenious) recommandent de n'autoriser un avis qu'après une interaction vérifiée, de modérer avant publication et de laisser le vendeur répondre publiquement.
- Les marketplaces de services affichent souvent plusieurs critères simples plutôt qu'une seule note globale.

## Constat [A]
- Sujet non traité dans les audits précédents.
- Au pilote, des étoiles seraient une erreur : avec 30 commerçants et peu d'appels, une seule mauvaise note détruit un commerçant que l'on a eu du mal à recruter, et les faux avis entre concurrents sont faciles.
- Proposition en deux temps :
  - jalon 0 et 1 : pas d'étoiles. Après un appel passé depuis l'app, une question SMS ou in-app le lendemain : « Le produit était-il disponible ? Oui / Non ». C'est lié à un appel réel, donc vérifié ;
  - le résultat sert d'abord en interne (fiabilité du stock, alerte au commerçant si plusieurs « Non »), puis s'affiche comme badge positif seulement (« Stock confirmé par 12 clients ce mois »).
- Plus tard, si besoin : avis courts limités aux numéros ayant appelé, publiés après modération, avec droit de réponse du commerçant.
- Lien avec v179 (fraîcheur des prix) : le « Non » vaut un signalement de prix ou de stock faux.

## Sources
- [LowCode Agency : ratings and reviews system architecture](https://www.lowcode.agency/blog/ratings-reviews-system-architecture)
- [Clarity Ventures : best ratings and reviews workflows](https://www.clarity-ventures.com/marketplace/best-ratings-and-reviews-workflows)
- [Xgenious : rating systems for service marketplaces](https://xgenious.com/quality-control-and-rating-systems-service-marketplaces/)


---

<!-- source : audit-expert-v193-mesure-produit-netbuis.md -->

# Audit expert v193 NetBuis (2026-10-15 22:50 UTC): mesure d'usage dans l'app

Légende : [S] = source web ; [A] = mon avis.

## Fait(s) [S]
- PostHog propose un SDK React Native compatible Expo et une offre gratuite mensuelle (de l'ordre d'un million d'événements, à confirmer sur la page officielle). Comparatifs 2026 : Costbench, AgentDeals, Toolradar.
- Alternatives mobiles citées : Vexo (spécialisé React Native), Firebase Analytics (gratuit, Google).

## Constat [A]
- Les audits citent des indicateurs (taux de recherches vides v189, appels, validation OTP), mais aucun ne dit comment les mesurer. Rien n'est prévu dans l'app.
- Proposition minimale au jalon 0, sans outil tiers :
  - une table `events` dans Supabase avec 6 événements seulement : `search`, `search_empty`, `merchant_view`, `call_tap`, `sms_tap`, `price_report` ;
  - RLS en écriture seule pour l'app (lecture interdite à la clé anon, cohérent avec v174) ;
  - aucune donnée personnelle : pas de numéro de téléphone, quartier plutôt que GPS précis ;
  - envoi groupé quand le réseau revient, pour ne pas coûter de data.
- Un outil comme PostHog seulement au jalon 1, et seulement s'il est hébergé en conformité avec la loi camerounaise sur les données (transfert hors pays soumis à autorisation, déjà noté).
- L'indicateur nord du pilote : nombre d'appels à un commerçant par semaine. Tout le reste est secondaire.

## Sources
- [Costbench : PostHog free plan 2026](https://costbench.com/software/product-analytics/posthog/free-plan/)
- [AgentDeals : analytics free tier comparison 2026](https://agentdeals.dev/analytics-free-tier-comparison-2026)
- [Vexo vs PostHog](https://www.vexo.co/blogs/vexo-vs-posthog-pricing-comparison)
- [Toolradar : best free product analytics tools](https://toolradar.com/guides/best-free-product-analytics-tools)


---

<!-- source : audit-expert-v194-suppression-compte-play-netbuis.md -->

# Audit expert v194 NetBuis (2026-10-15 23:50 UTC): suppression de compte et formulaire Data safety

Légende : [S] = source web ; [A] = mon avis.

## Fait(s) [S]
- Google Play exige, pour toute app qui permet de créer un compte, un moyen de demander la suppression du compte et des données associées, à la fois depuis l'app et via un lien web accessible sans réinstaller l'app (aide Google Play Console, réponse 13327111 ; Android Authority, 9to5Google, SC World).
- Ce lien web se déclare dans le formulaire Data safety de la Play Console. Une déclaration manquante ou fausse peut bloquer la publication.

## Constat [A]
- Jamais traité dans les audits précédents, alors que c'est bloquant pour la mise en ligne (v180, fiche Play Store).
- Ce qu'il faut prévoir au jalon 0 :
  - un bouton « Supprimer mon compte » dans Profil, avec confirmation par OTP (on réutilise l'OTP +237, v176) ;
  - une page web simple (ex. netbuis.cm/suppression) où l'on saisit son numéro, reçoit un OTP, et confirme ;
  - côté Supabase, une fonction qui supprime l'utilisateur Auth, ses messages du forum (ou les anonymise) et ses événements (v193). Pour un commerçant : retirer sa fiche des résultats immédiatement ;
  - une durée de conservation écrite (ex. journaux de sécurité gardés 90 jours, puis effacés).
- Formulaire Data safety, réponses probables : numéro de téléphone (compte), localisation approximative (quartier), messages du forum, données d'usage. Pas de partage avec des tiers ; chiffrement en transit : oui.
- Lien avec la loi camerounaise sur les données personnelles : le droit à l'effacement va dans le même sens. Une seule fonction couvre les deux.

## Sources
- [Aide Google Play Console : exigences de suppression de compte](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Android Authority : Google Play data safety](https://androidauthority.com/google-play-data-safety-3309792)
- [SC World : Google deletion requirement for Play Store apps](https://www.scworld.com/news/privacy/google-deletion-play-store-apps)
- [PTKD : Google Play account data deletion requirement](https://ptkd.com/journal/google-play-account-data-deletion-requirement)


---

<!-- source : audit-expert-v195-partage-fiche-whatsapp-netbuis.md -->

# Audit expert v195 NetBuis (2026-10-16 00:51 UTC): partager une fiche commerçant par WhatsApp

Légende : [S] = source web ; [A] = mon avis.

## Fait(s) [S]
- Expo documente les Android App Links : un lien https vers votre domaine ouvre directement l'app si elle est installée, à condition de publier un fichier `/.well-known/assetlinks.json` sur ce domaine et de déclarer `intentFilters` dans app.json.
- Expo Router mappe chaque URL à un écran (ex. `/c/[id]` → fiche commerçant), sans code de routage supplémentaire.

## Constat [A]
- Sujet jamais traité. C'est pourtant le canal de croissance le plus naturel au Cameroun : « Je l'ai trouvé chez qui ? » se règle dans un groupe WhatsApp.
- Fonction proposée au jalon 1 : bouton « Partager » sur chaque fiche, qui envoie un lien `https://netbuis.cm/c/<id>` :
  - app installée : le lien ouvre la fiche dans l'app ;
  - app non installée : une page web légère (moins de 50 Ko) montre le nom, le quartier, le produit, le bouton Appeler (`tel:`) et un lien vers le Play Store ;
  - balises Open Graph (titre, image) pour que WhatsApp affiche un aperçu propre.
- Sécurité : l'identifiant dans l'URL doit être un identifiant public non devinable, et la page web ne lit que les champs publics de la fiche (même règle RLS que v174).
- Mesure : ajouter `share_tap` et `share_open` à la table `events` (v193). Un partage qui mène à un appel est le meilleur indicateur de bouche-à-oreille.
- Coût : un domaine et une page statique, quasi nul. Les commerçants le partageront eux-mêmes sur leur statut WhatsApp, ce qui sert aussi le recrutement.

## Sources
- [Expo : Android App Links](https://docs.expo.dev/linking/android-app-links/)
- [Expo : overview of linking](https://docs.expo.dev/guides/linking)
- [Expo Router : link preview](https://docs.expo.dev/router/reference/link-preview.md)


---

<!-- source : audit-expert-v196-environnements-staging-netbuis.md -->

# Audit expert v196 NetBuis (2026-10-16 01:51 UTC): environnement de test séparé de la production

Légende : [S] = source web ; [A] = mon avis.

## Fait(s) [S]
- Supabase propose le « branching » : une base de prévisualisation créée par pull request, à partir des migrations du dépôt (docs Supabase, page features/branching). C'est une option payante, réservée aux plans payants.
- Le guide Supabase « vibe coder's guide to environments » recommande au minimum deux projets séparés (développement et production) et des migrations versionnées dans le dépôt, appliquées par la CLI.

## Constat [A]
- Sujet jamais traité. Avec des agents qui écrivent du code et des migrations, c'est pourtant la protection la plus importante après RLS (v174, v177).
- Proposition pour le pilote, sans coût :
  - deux projets Supabase : `netbuis-dev` (gratuit, données fictives) et `netbuis-prod` (plan Pro au pilote, v190) ;
  - toute modification du schéma passe par un fichier dans `supabase/migrations/`, testé en CI sur une base locale (`supabase start`), jamais par l'éditeur SQL de la console ;
  - les agents n'ont que les clés de `netbuis-dev` ; la migration vers prod est lancée par un humain (cohérent avec la règle : l'humain décide sur les données) ;
  - côté app, deux profils EAS (`preview` pointe sur dev, `production` sur prod), pour que les testeurs du pilote ne touchent jamais la vraie base.
- Le branching payant n'est utile que s'il y a plusieurs PR de schéma par semaine. Pas au jalon 0.

## Sources
- [Supabase : branching (docs)](https://supabase.com/docs/guides/deployment/branching)
- [Supabase : branching (page produit)](https://supabase.com/features/branching)
- [Supabase blog : guide to environments](https://supabase.com/blog/the-vibe-coders-guide-to-supabase-environments.md)
- [Autonoma : Supabase branching for previews](https://getautonoma.com/blog/supabase-branching-for-previews)


---

<!-- source : audit-expert-v197-photos-poids-data-netbuis.md -->

# Audit expert v197 NetBuis (2026-10-16 02:51 UTC): photos des commerçants et coût en data

Légende : [S] = source web ; [A] = mon avis.

## Fait(s) [S]
- Supabase Storage sait redimensionner les images à la volée et les servir en WebP selon le navigateur, avec un cache CDN (docs « image transformations », blog « smart CDN »). La fonction est réservée aux plans payants et facturée au nombre d'images d'origine transformées (chiffres à vérifier sur la page officielle).

## Constat [A]
- Sujet non traité : les audits parlent de la taille de l'APK (moins de 15 Mo) mais pas du poids des écrans. Une liste de résultats avec 10 photos de 2 Mo prises au téléphone coûte 20 Mo de data, soit une bonne part d'un forfait journalier.
- Recommandations, valables même sur le plan gratuit :
  - compresser sur le téléphone du commerçant avant l'envoi (`expo-image-manipulator`) : 800 px de large maximum, JPEG ou WebP qualité 70, cible moins de 120 Ko ;
  - générer en plus une vignette de 200 px (moins de 15 Ko) pour les listes ; la grande image seulement sur la fiche ;
  - afficher avec `expo-image` (cache disque, placeholder flou `blurhash`) pour ne jamais retélécharger une photo vue ;
  - mode « économie de data » dans les réglages : pas de photos dans les listes, seulement sur demande ;
  - pas de photo obligatoire : une fiche sans photo mais avec prix frais (v179) vaut mieux qu'une belle photo périmée.
- Sécurité : un bucket `merchant-photos` en lecture publique, écriture réservée au commerçant propriétaire via RLS sur `storage.objects` ; supprimer les métadonnées EXIF (position GPS du domicile) avant l'envoi.
- Mesure : suivre la data moyenne par session dans les tests du pilote (cible : moins de 1 Mo).

## Sources
- [Supabase : storage image transformations](https://supabase.com/docs/guides/storage/serving/image-transformations)
- [Supabase : image transformations (page produit)](https://supabase.com/features/image-transformations)
- [Supabase blog : image resizing and smart CDN](https://supabase.com/blog/storage-image-resizing-smart-cdn.md)


---

<!-- source : audit-expert-v198-cgu-responsabilite-netbuis.md -->

# Audit expert v198 NetBuis (2026-10-16 03:50 UTC): conditions d'utilisation et responsabilité

Légende : [S] = source web ; [A] = mon avis.

## Fait(s) [S]
- Recherche ciblée sur le Cameroun sans résultat utile : les sources trouvées portent sur le droit français (avocat.fr, Captain Contrat, Lexing). Elles distinguent la plateforme « intermédiaire » (qui ne vend pas, responsabilité limitée si elle retire vite un contenu signalé) de la plateforme « vendeur ».

## Constat [A] (à faire valider par un juriste camerounais)
- Aucun audit ne traitait des conditions d'utilisation (CGU), alors qu'elles sont exigées par le Play Store avec la politique de confidentialité (v180, v194).
- De mémoire, le Cameroun a une loi de 2010 sur le commerce électronique (n° 2010/021) ; à vérifier avant rédaction.
- NetBuis est un intermédiaire : il ne vend rien, ne fixe aucun prix et ne prend pas de paiement (jalons 0 et 1). Les CGU doivent le dire clairement :
  - les prix et stocks sont déclarés par les commerçants, avec leur date (v179) ; NetBuis ne les garantit pas ;
  - la vente se fait directement entre l'acheteur et le commerçant, par appel ou SMS ;
  - le commerçant s'engage à ne publier que des produits légaux et des prix réels ; produits interdits listés (médicaments sans autorisation, armes, contrefaçons) ;
  - tout contenu signalé (prix faux, arnaque, message du forum) est examiné et peut être retiré, et le compte suspendu ;
  - lien vers la politique de confidentialité et la page de suppression de compte (v194).
- Deux textes courts en français et en anglais, rédigés simplement, plutôt qu'un long copier-coller d'un site étranger.
- Coût : une consultation juridique locale ponctuelle avant le pilote. À décider par Jeff.

## Sources
- [avocat.fr : responsabilité des plateformes, intermédiaires ou vendeurs](https://consultation.avocat.fr/blog/murielle-isabelle-cahen/article-2981907-responsabilite-des-plateformes-de-commerce-intermediaires-ou-vendeurs.html)
- [Captain Contrat : sécuriser la conformité d'une plateforme numérique](https://www.captaincontrat.com/articles-gestion-entreprise/securiser-conformite-plateforme-numerique)


---

<!-- source : audit-expert-v199-favoris-retour-netbuis.md -->

# Audit expert v199 NetBuis (2026-10-16 04:50 UTC): favoris et raison de revenir

Légende : [S] = source web ; [A] = mon avis.

## Fait(s) [S]
- Les outils de fidélisation e-commerce (Shop Circle, BigCommerce « save for later », listes de souhaits Shopify) reposent sur trois mécanismes : enregistrer un vendeur ou un produit, être prévenu d'un changement (prix, stock), et retrouver vite ce qu'on a déjà acheté.

## Constat [A]
- Aucun audit ne traitait des favoris. Sans eux, NetBuis ne sert qu'une fois par besoin ; l'utilisateur garde ensuite le numéro du commerçant dans son répertoire et n'ouvre plus l'app.
- C'est acceptable, et même sain : le but est l'appel. Mais deux fonctions légères donnent une raison de revenir :
  - « Mes commerçants » : une étoile sur la fiche, liste stockée sur le téléphone (pas de compte requis, fonctionne hors ligne avec le cache hors ligne déjà prévu) ;
  - « Prévenez-moi » sur un produit (déjà proposé pour les recherches vides, v189) : un SMS quand le prix baisse ou que le produit revient en stock chez un favori.
- À ne pas faire : panier, liste d'achats partagée, historique détaillé. C'est trop pour le pilote et ça suppose un paiement dans l'app, exclu aux jalons 0 et 1.
- Mesure : part des appels qui viennent de la liste « Mes commerçants » (événement `call_tap` avec `source=favori`, v193). Si elle dépasse 30 % au pilote, la fonction mérite plus d'effort.
- Priorité : jalon 1.

## Sources
- [Shop Circle : boost repeat purchases](https://shopcircle.co/blogs/news/boost-repeat-purchases-shopify)
- [BigCommerce : save for later](https://www.bigcommerce.com/apps/save-for-later-by-intuitsolutions/)
- [EasyStore : shopping app customer experience](https://blog.easystore.co/en-my/easystore-shopping-app-customer-experience)

