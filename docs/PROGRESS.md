# Suivi d'avancement — NetBuis

> **Fichier d'état de l'orchestrateur.** Il fait foi (pas la mémoire de la conversation). À mettre à jour et à commiter après **chaque** tâche.
> Statuts : `☐` à faire · `🔄` en cours · `✅` validée (preuve dans `logs/`) · `🔒` validée techniquement, **en attente de la relecture de Jeff** · `⛔` bloquée (voir `logs/Txxx-blocage.md`) · `↩` à corriger.

## EN COURS

- **Tâche en cours** : T009
- **Prochaine tâche** : T010
- **Dernière mise à jour** : 2026-10-16
- **Branche** : etape-2/acces

## Tâches (dans l'ordre d'exécution)

| Statut | Id | Titre | Agent | Date | Preuve / notes |
|---|---|---|---|---|---|
| | | **PHASE 0 — Vérifier le socle et caler le projet** | | | |
| ✅ | T000 | Préparer le dépôt Git | orchestrateur | 2026-10-11 | dépôt dans netbuis/, commit f07f697, branche etape-1/socle, 10 agents, aucun .env versionné |
| ✅ | T001 | Faire tourner le socle backend (étape 1) | a1 | 2026-10-11 | logs/T001-verification.md ; User avec `role` (converti en T005b) ; .env.example à compléter (OTP_TEST_MODE, CSRF_TRUSTED_ORIGINS) |
| ✅ | T002 | Faire tourner le socle dashboard (étape 1) | c3 | 2026-10-11 | logs/T002-verification.md ; versions figées (React 19.3, Vite 8.3, TS 7.0) ; Node 24.15+ conseillé |
| ✅ | T003 | Faire tourner le socle mobile (étape 1) | b1 | 2026-10-11 | logs/T003-verification.md ; pas d'émulateur → `flutter build apk --debug` OK ; SDK Android 36, NDK 28.2 |
| ✅ | T004 | Caler le mobile sur les maquettes (thème, logo, barre du bas) | b1 | 2026-10-11 | logs/T004-verification.md ; routes /home /map /forum /profile ; libellés barre 10 sp (maquette) ; onglets inactifs en texte secondaire (contraste) ; couleurs hors README prises des maquettes (bordure claire E3E3E7, texte clair 18181B, barre 121214, erreur E25C4A/D1452F) ; langue fixée FR jusqu'à T100 ; netbuis_logo.dart à ajouter dans docs/MODULES.md |
| ✅ | T005 | Appliquer les décisions de départ | orchestrateur (aucun code à changer) | 2026-10-11 | Jeff n'a pas répondu → défauts retenus et écrits dans DECISIONS_JEFF.md (D-01 → T007, D-02 console → T006, D-03 déjà en place) ; remarque : `TEAM_ENABLED` absent du code, reporté (D-16) |
| | | **PHASE 1 — Accès : compte par numéro de téléphone (Étape 2)** | | | |
| ✅ | T005b | Backend : champs de compte pour l'administration et le blocage | a1 | 2026-10-11 | logs/T005b-verification.md ; migration 0002 ; à reprendre : can_login() sur l'admin Django (T007), champ langue (T008), IsMerchant supprimée → IsActiveBusinessOwner (T008) |
| ✅ | T006 | 🔒 Backend : code SMS (OTP) | a1 | 2026-10-11 | logs/T006-verification.md ; vérificateur CONFORME ; validé par Jeff le 2026-10-11 (corrections en T006b) ; avant mise en service : cache partagé, limite IP sur verify, verrou limite par numéro ; OTP_TEST_MODE inutilisé |
| ✅ | T006b | 🔒 Backend : durcissement du code SMS (demandé par Jeff) | a1 | 2026-10-11 | logs/T006b-verification.md ; vérificateur CONFORME après 1 correction ; taux IP verify 30/h (choix à valider) ; docker-compose.yml en attente de Jeff ; validé par Jeff le 2026-10-16 |
| ✅ | T007 | 🔒 Backend : jetons et connexion administrateur | a1 | 2026-10-16 | logs/T007-verification.md ; vérificateur CONFORME après 1 correction (limite admin-login en simultané) ; refresh à usage unique (rotation), mobile reçoit {access, refresh}, dashboard {access} + cookie netbuis_refresh ; compteur admin-login en base (AdminLoginAttempt, migration 0005) ; nouveaux fichiers accounts/backends.py et models/login_attempt.py (accordés par l'orchestrateur) ; CORS_ALLOW_CREDENTIALS=True ; à faire : jeton d'accès ≤ 15 min après blocage (T008), NUM_PROXIES au déploiement, nettoyage des jetons expirés ; validé par Jeff le 2026-10-16 |
| ✅ | T008 | Backend : compte, droits et admin Django | a1 | 2026-10-16 | logs/T008-verification.md ; 176 tests, couverture accounts 99 % ; IsAuthenticatedNotBlocked = permission par défaut (jeton d'accès refusé dès le blocage) ; IsAdminRole déplacé de core vers accounts ; champ `language` (fr/en, migration 0006) ; compteurs crédits = null (critère 6 retenu contre le « 0 » du critère 1) ; `free_call_available` entier nullable (« 0 / 1 restant » de la maquette) — à confirmer ; contrat pour T025 : OneToOne `related_name="business_profile"`, `status="actif"` ; masquage du profil d'un propriétaire supprimé à faire dans recherche/carte/fiche (T026) ; backend/README.md créé |
| ✅ | T008b | Backend : réglages de plateforme (`PlatformSetting`) | a1 | 2026-10-16 | logs/T008b-verification.md ; 210 tests ; minimum 1 pour les 5 clés (0 refusé — à confirmer par Jeff pour `plafond_publications_non_abonne`) ; pas de borne haute (T074) ; cache LocMem 60 s : autres workers à jour en ≤ 60 s ; T074 devra écrire via save() (pas .update()) ; droit « Administrateur complet » appliqué en T074 |
| ☐ | T009 | Mobile : données et état de la connexion | b1 | | |
| ☐ | T010 | Mobile : Lancement et Découverte | b1 | | |
| ☐ | T011 | Mobile : écran Connexion (numéro puis code) | b1 | | |
| ☐ | T011b | Mobile : coquille de l'écran Profil et saisie du nom | b1 | | |
| ☐ | T012 | Vérification de tranche : connexion de bout en bout | orchestrateur (aucun nouvel agent) | | |
| | | **PHASE 2 — Référentiels : lieux et catalogues (Étape 3)** | | | |
| ☐ | T020 | Backend : zones (Pays → Quartier) | a2 | | |
| ☐ | T021 | Backend : secteurs, sous-catégories, catégories de service, types de structure, catalogue de produits | a2 | | |
| ☐ | T022 | Mobile : référentiels et choix de la ville | b1 | | |
| ☐ | T023 | Vérification de tranche : référentiels | orchestrateur | | |
| | | **PHASE 3 — Compte business : création et fiche (Étape 3)** | | | |
| ☐ | T025 | Backend : modèles du compte business | a2 | | |
| ☐ | T025b | Backend : abonnement (modèle et service `is_subscribed`) | a2 | | |
| ☐ | T026 | Backend : API de création et de modification du compte business | a2 | | |
| ☐ | T027 | 🔒 Backend : envoi des photos et pièces d'identité | a2 | | |
| ☐ | T028 | Backend : données de démonstration | a2 | | |
| ☐ | T030 | Mobile : création du compte business, étapes 1 et forme juridique | b3 | | |
| ☐ | T031 | Mobile : secteur et détails d'activité | b3 | | |
| ☐ | T032 | Mobile : prestataire de service | b3 | | |
| ☐ | T033 | Mobile : structure (supermarché, restaurant, hôtel, centre de santé) | b3 | | |
| ☐ | T034 | Mobile : choix précis du lieu (ville/village puis quartier) — écran sans maquette | b3 | | |
| ☐ | T035 | Mobile : récapitulatif et envoi | b3 | | |
| ☐ | T036 | Vérification de tranche : créer un commerce de bout en bout | orchestrateur | | |
| | | **PHASE 4 — Espace commerçant : produits et offres** | | | |
| ☐ | T037 | Backend : offres du commerçant | a2 | | |
| ☐ | T038 | Mobile : « Mes produits » | b3 | | |
| | | **PHASE 5 — Recherche et écran d'Accueil (Étape 4, chemin critique)** | | | |
| ☐ | T040 | Backend : moteur de recherche | a3 | | |
| ☐ | T041 | Backend : route de recherche, suggestions, recherche vocale | a3 | | |
| ☐ | T043 | Mobile : données et état de la recherche | b2 | | |
| ☐ | T044 | Mobile : écran d'Accueil | b2 | | |
| ☐ | T045 | Mobile : recherche écrite et résultats | b2 | | |
| ☐ | T046 | Mobile : recherche vocale | b2 | | |
| ☐ | T047b | Backend : fiche publique | a2 | | |
| ☐ | T047 | Mobile : fiche publique du commerçant | b2 | | |
| ☐ | T048 | Vérification de tranche : trouver un commerçant | orchestrateur | | |
| | | **PHASE 6 — Appeler et écrire sur WhatsApp (Étape 4, zone la plus sensible)** | | | |
| ☐ | T050 | 🔒 Backend : lancer un appel | a3 | | |
| ☐ | T051 | Backend : WhatsApp, retour d'appel, historique | a3 | | |
| ☐ | T052 | 🔒 Mobile : bouton Appeler, feuille Orange / MTN, appel direct Android | b2 | | |
| ☐ | T053 | Mobile : historique des appels | b2 | | |
| ☐ | T054 | Mobile : WhatsApp et retour d'appel | b2 | | |
| ☐ | T055 | Mobile : dernier résultat hors connexion | b2 | | |
| ☐ | T056 | Tests du bloc recherche et appel | b2 | | |
| ☐ | T057 | Vérification de tranche CRITIQUE : de la recherche à l'appel | orchestrateur | | |
| | | **PHASE 7 — Explorer par quartier (Étape 4)** | | | |
| ☐ | T060 | Backend : carte par zones | a2 | | |
| ☐ | T061 | Mobile : écran Carte | b2 | | |
| ☐ | T062 | Mobile : détail d'un quartier | b2 | | |
| ☐ | T063 | Vérification de tranche : carte | orchestrateur | | |
| | | **PHASE 8 — Administration : API puis dashboard (Étape 5)** | | | |
| ☐ | T070 | 🔒 Backend : droits d'administration et journal d'audit | c2 | | |
| ☐ | T071 | 🔒 Backend : demandes de compte business (validation) | c2 + a2 | | |
| ☐ | T072 | Backend : comptes (liste, blocage, suppression douce, restauration) | c2 | | |
| ☐ | T073 | Backend : chiffres du tableau de bord | c2 | | |
| ☐ | T074 | Backend : réglages, administrateurs, export | c2 | | |
| ☐ | T074b | Backend : référentiels modifiables par l'administration | c2 | | |
| ☐ | T074c | Backend : analyses, abonnements, lecture de l'audit | c2 | | |
| ☐ | T075 | Backend : tests et contrat de l'administration | c2 | | |
| ☐ | T076 | Dashboard : kit de composants et thème | c3 | | |
| ☐ | T077 | 🔒 Dashboard : connexion de l'administrateur | c3 | | |
| ☐ | T078 | Dashboard : mise en page | c3 | | |
| ☐ | T081 | Dashboard : Vue d'ensemble | c3 | | |
| ☐ | T082 | Dashboard : Demandes | c3 | | |
| ☐ | T083 | Dashboard : Comptes | c3 | | |
| ☐ | T085 | Dashboard : référentiels | c3 | | |
| ☐ | T086 | Dashboard : réglages et administrateurs | c3 | | |
| ☐ | T087 | Dashboard : journal d'audit | c3 + c2 | | |
| ☐ | T088 | Dashboard : export | c3 | | |
| ☐ | T089 | Vérification de tranche : administration de bout en bout | orchestrateur | | |
| | | **PHASE 9 — Forum : publications et commentaires (Étape 7)** | | | |
| ☐ | T090 | Backend : publications, commentaires, signalements | a3 | | |
| ☐ | T091 | Mobile : Publier et Mes publications | b3 | | |
| ☐ | T092 | Mobile : Forum et page d'une publication | b3 | | |
| ☐ | T093 | Mobile : signaler | b3 | | |
| ☐ | T094 | Backend : modération | a3 + c2 | | |
| ☐ | T095 | Dashboard : modération du forum | c3 | | |
| ☐ | T096 | Vérification de tranche : forum | orchestrateur | | |
| | | **PHASE 10 — Profil, aide, langue** | | | |
| ☐ | T100 | Mobile : réglages (langue et thème) | b3 | | |
| ☐ | T101 | Mobile : Aide et support | b3 | | |
| ☐ | T102 | Mobile : finition de l'écran Profil | b1 | | |
| ☐ | T102b | Mobile : modifier ma boutique | b3 | | |
| ☐ | T103 | Vérification de tranche : profil | orchestrateur | | |
| | | **PHASE 11 — Produits très sollicités et abonnements (sans paiement)** | | | |
| ☐ | T104 | Backend : tendances | a3 | | |
| ☐ | T105 | Mobile : produits très sollicités | b3 (dépôt et état des tendances) puis b2 (bande sur l'Accueil), dans cet ordre | | |
| ☐ | T106 | Dashboard : analyses | c3 | | |
| ☐ | T110 | Backend : accorder, faire expirer, proposer un abonnement (sans paiement) | a2 (expiration, proposition) puis c2 (route d'administration), dans cet ordre | | |
| ☐ | T111 | Mobile : propositions d'abonnement | b3 | | |
| ☐ | T112 | Vérification de tranche : plafonds et abonnement | orchestrateur | | |
| ☐ | T113 | Dashboard : Équipe & abonnements — écran sans maquette | c3 | | |
| | | **PHASE 12 — Durcissement et recette (Étape 8)** | | | |
| ☐ | T120 | Accessibilité de tous les écrans mobiles | b1 (conduit l'audit) + b2 + b3 pour leurs dossiers | | |
| ☐ | T121 | Revue de sécurité | a1 (backend), c3 (dashboard), b1 (mobile) | | |
| ☐ | T122 | Performances | a1, a2, a3 (chacun ses index, un à la fois) puis b1 (mesures mobiles) | | |
| ☐ | T123 | Tests de bout en bout et intégration continue | orchestrateur (fichiers `.github/`, documentation) ; les scénarios sont écrits un domaine après l'autre par l'agent propriétaire du domaine (a1 accès, a2 création de commerce, a3 recherche/appel/forum, b1/b2/b3 mobile, c2/c3 administration) | | |
| ☐ | T124 | Construction de l'application et documentation d'exploitation | b1 (construction) puis orchestrateur (`README`, `docs/RECETTE.md`) | | |
| ☐ | T125 | Recette finale contre le cahier de charge | orchestrateur seul | | |

## Cahier de charge → tâches → preuve (rempli à T125)

| Fonctionnalité demandée | Tâches | Preuve (test / journal) | Statut |
|---|---|---|---|
| Barre de recherche : entrer le nom d'un produit | T040–T046 | | ☐ |
| Liste des commerçants locaux qui ont ce produit (abonnés en premier) | T040, T041, T045 | | ☐ |
| Recherche vocale | T041, T046 | | ☐ |
| Appel téléphonique direct, ligne Orange / MTN, numéro jamais affiché | T050, T052, T057 | | ☐ |
| Contact WhatsApp | T051, T054 | | ☐ |
| Historique des appels | T051, T053 | | ☐ |
| Exploration par ville / quartier (carte) | T060–T063 | | ☐ |
| Compte par numéro de téléphone + code SMS | T006–T012 | | ☐ |
| Compte business, 5 types, avec validation | T025–T036, T070–T083 | | ☐ |
| Produits du commerçant | T037, T038 | | ☐ |
| Forum : publications, commentaires, signalement, modération | T090–T096 | | ☐ |
| Produits très sollicités sur le marché | T104–T106 | | ☐ |
| Abonnements (accord manuel) et plafonds | T110–T113 | | ☐ |
| Dashboard d'administration (demandes, comptes, rôles, audit, réglages, référentiels, export) | T070–T089, T074b, T074c | | ☐ |
| Accessibilité (peu lecteurs) | T120 | | ☐ |
| Sécurité, performances, tests de bout en bout, APK | T121–T124 | | ☐ |
| **Reporté** : paiements, déploiement, équipe/parrainage, commandes, notifications, impression, GPS | V01–V10 | — | ⏸ |

## Données `À REMPLACER` à fournir par Jeff

| Où | Quoi | Tâche |
|---|---|---|
| | | |

## Écrans créés sans maquette

| Écran | Tâche | Choix fait |
|---|---|---|
| | | |

## Journal

| Date | Événement |
|---|---|
| 2026-10-11 | Pilotage copié dans netbuis/ ; Flutter 3.47.7 installé dans ~/development/flutter (SDK Android absent) ; Jeff demande T001–T003 en parallèle (dossiers séparés). |
| 2026-10-11 | Coupure du PC pendant la construction de l'APK (T003) ; reprise, APK debug construit, T003 validée. |
| 2026-10-16 | Reprise en session cloud sur le dépôt GitHub Ntchamba/netbuis (branche etape-2/acces). T006b validée par Jeff. Dépôt assaini : `.gitignore` ajouté ; `backend/.env`, `backend/.venv`, `logs/` et caches Python retirés du suivi (fichiers conservés sur le disque) ; agents copiés de `netbuis-pilotage/.claude/` vers `.claude/`. ⚠️ `backend/.env` avait été poussé sur GitHub : Jeff doit changer son mot de passe PostgreSQL. |
| 2026-10-16 | T007 validée par Jeff. Jeff : le backend et sa base PostgreSQL sont hébergés sur Railway (pas en local) ; le mot de passe reste dans `backend/.env` (dépôt privé), à ne jamais lire. |
