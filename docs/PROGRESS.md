# Suivi d'avancement — NetBuis

> **Fichier d'état de l'orchestrateur.** Il fait foi (pas la mémoire de la conversation). À mettre à jour et à commiter après **chaque** tâche.
> Statuts : `☐` à faire · `🔄` en cours · `✅` validée (preuve dans `logs/`) · `🔒` validée techniquement, **en attente de la relecture de Jeff** · `⛔` bloquée (voir `logs/Txxx-blocage.md`) · `↩` à corriger.

## EN COURS

- **Tâche en cours** : T111
- **Prochaine tâche** : T112
- **Dernière mise à jour** : 2026-10-21
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
| ✅ | T009 | Mobile : données et état de la connexion | b1 | 2026-10-17 | logs/T009-verification.md ; 60 tests ; API_URL (défaut http://10.0.2.2:8000/api) ; AuthAuthenticated porte isNew, pas de rôle ; refresh_interceptor (401 → renouvellement unique) reste une coquille, à faire avant T012 ; délai de renvoi 30 s à confirmer en T011 |
| ✅ | T010 | Mobile : Lancement et Découverte | b1 | 2026-10-17 | logs/T010-verification.md ; 69 tests ; sous-texte de la diapositive 5 écrit sans maquette ; bouton de thème de la maquette Splash non reproduit (T100) ; redirection provisoire vers /home (T011 y insère la connexion) |
| ✅ | T011 | Mobile : écran Connexion (numéro puis code) | b1 | 2026-10-17 | logs/T011-verification.md ; 134 tests ; délai de renvoi 30 s (à confirmer) ; lien « conditions d'utilisation » non cliquable (écran légal É8, textes légaux À REMPLACER) ; lecture auto du SMS non testée sur téléphone ; Splash/Découverte ouverts sans session, le reste exige une session ; à relire par Jeff à T012 : otp_screen, otp_input, guards, loginPhoneProvider |
| ✅ | T011b | Mobile : coquille de l'écran Profil et saisie du nom | b1 | 2026-10-17 | logs/T011b-verification.md ; 166 tests ; route /your-name après une première connexion ; Profil branché sur /profile ; sans maquette : écran de saisie du nom ; non reproduit : bouton de thème (T100) ; le jeton n'est pas encore renouvelé sur 401 |
| ✅ | T011c | Mobile : renouvellement automatique du jeton (ajoutée par l'orchestrateur : exigée par T012) | b1 | 2026-10-17 | logs/T011c-verification.md ; 179 tests ; SessionRefresher partagé avec AuthController ; rejeu sans FormData (à revoir pour l'envoi de photos, T027/T030) |
| ✅ | T012 | Vérification de tranche : connexion de bout en bout | orchestrateur (aucun nouvel agent) | 2026-10-17 | logs/T012-tranche.md ; serveur local + code mobile réel contre ce serveur (expiration forcée, rotation, déconnexion) : OK ; reste à Jeff : essai sur téléphone Android, lecture auto du SMS, relecture de la zone OTP/jetons mobile ; validé par Jeff le 2026-10-17 (l'essai sur téléphone reste à faire) |
| | | **PHASE 2 — Référentiels : lieux et catalogues (Étape 3)** | | | |
| ✅ | T020 | Backend : zones (Pays → Quartier) | a2 | 2026-10-17 | logs/T020-verification.md ; 238 tests ; modèle Zone unique (Ville/Quartier supprimés) ; /api/zones/ paginé (20, max 50) ; Maroua rattachée au département Diamaré, pas à ses 3 arrondissements ; zones.csv = 20 lignes, coordonnées et codes vides |
| ✅ | T021 | Backend : secteurs, sous-catégories, catégories de service, types de structure, catalogue de produits | a2 | | 2026-10-17 | logs/T021-verification.md ; 307 tests ; noms de code anglais (Sector…) ; 43 sous-catégories dont 6 « Autre » à compléter ; catalogue et synonymes VIDES (aucun produit inventé) : DECISIONS_JEFF prévoit un « petit jeu de départ » → à trancher avant T040 (jeu tiré des seuls produits visibles dans les maquettes, ou liste de Jeff) |
| ✅ | T022 | Mobile : référentiels et choix de la ville | b1 | | 2026-10-17 | logs/T022-verification.md ; 218 tests ; dépôts partagés dans lib/core/data/ (zones, référentiels) ; ville dans les préférences simples (city_id, city_name) ; flux Découverte → Choisir ma ville (si aucune ville) → Accueil/connexion ; entrée « Ma ville » dans Profil |
| ✅ | T023 | Vérification de tranche : référentiels | orchestrateur | 2026-10-17 | logs/T023-tranche.md ; le mobile réel lit les vraies villes, quartiers, secteurs, catégories de service et types de structure du backend local ; reste à Jeff : données manquantes, essai de l'écran sur téléphone |
| | | **PHASE 3 — Compte business : création et fiche (Étape 3)** | | | |
| ✅ | T025 | Backend : modèles du compte business | a2 | | 2026-10-17 | logs/T025-verification.md ; 416 tests ; BusinessProfile (owner OneToOne, related_name business_profile ; phone_anchor et cni_photo protégés par un test sur tous les sérialiseurs) ; photos = clés de stockage (CharField, T027) ; plafonds de 3 laissés à T026 ; codes des listes de détails de structure choisis par a2 depuis les libellés de la spec |
| ✅ | T025b | Backend : abonnement (modèle et service `is_subscribed`) | a2 | | 2026-10-17 | logs/T025b-verification.md ; 443 tests ; règle unique dans services/subscription.py (is_subscribed, subscribed_profiles, annotate_subscribed) ; statuts actif/expire seulement (pas d'« impayé ») ; passage à « expiré » par commande en T110 |
| ✅ | T026 | Backend : API de création et de modification du compte business | a2 | | 2026-10-18 | logs/T026-verification.md ; 532 tests ; corps de requête : référentiels par id entier, listes d'établissement par codes ; photos = clés de stockage (format contrôlé seulement, propriété de la clé à contrôler en T027) ; détails de structure obligatoires choisis par a2 : supermarché ≥ 1 rayon, restaurant cuisine + livraison, hôtel standing, santé ≥ 1 spécialité ; changement de type : champs de l'ancien type à vider dans la même requête ; BusinessProfile.objects.visible() = règle unique de visibilité publique |
| ✅ | T027 | 🔒 Backend : envoi des photos et pièces d'identité | a2 | | 2026-10-18 | logs/T027-verification.md ; 707 tests ; vérificateur CONFORME (1 incohérence mineure corrigée) ; clés u<id>/<kind>/<uuid>.<ext> générées par le serveur ; espace privé backend/private_media (hors dépôt) ; lien de lecture admin 5 min (route à faire en T071) ; MP4 seulement pour la vidéo ; réglages config/ touchés avec autorisation exceptionnelle (STORAGE_BACKEND, PRIVATE_MEDIA_ROOT, UPLOAD_SIGNING_KEY, UPLOAD_TOKEN_TTL, PRIVATE_DOWNLOAD_TTL, taux uploads 60/h, static() en DEBUG) ; validé par Jeff le 2026-10-18 |
| ✅ | T028 | Backend : données de démonstration | a2 | | 2026-10-18 | logs/T028-verification.md ; 730 tests ; seed_demo --count N (1 à 5 000, 40 s pour 5 000) et --flush ; numéros +237 600… réservés aux données fictives ; photos = clés sans fichier ; prérequis load_zones + seed_referentials ; à étendre en T037, T090, T110 |
| ✅ | T030 | Mobile : création du compte business, étapes 1 et forme juridique | b3 | | 2026-10-19 | logs/T030-verification.md ; 279 tests ; brouillon BusinessDraft + BusinessCreationFlow partagés (features/business) ; totaux d'étapes : Commerce/Particulier/Structure 4, Entreprise 5, Prestataire 3 ; flutter_tts 4.2.5 ; encart Profil = texte de la maquette ; account_screen en SingleChildScrollView ; AndroidManifest <queries> TTS_SERVICE à ajouter (b2/T124) |
| ✅ | T031 | Mobile : secteur et détails d'activité | b3 | | 2026-10-19 | logs/T031-verification.md ; 307 tests ; plafond 3 = constante freeSubcategoryLimit (subcategoryLimitProvider prêt pour la valeur du serveur) ; aucun secteur présélectionné ; 3 tests existants adaptés (étape suivante construite) |
| ✅ | T032 | Mobile : prestataire de service | b3 | | 2026-10-19 | logs/T032-verification.md ; 331 tests ; à trancher par Jeff : le diplôme est-il affichable publiquement (maquette) ou privé (D-17) ? ; CNI et diplôme restent des chemins locaux en mémoire jusqu'à T035 |
| ✅ | T033 | Mobile : structure (supermarché, restaurant, hôtel, centre de santé) | b3 | | 2026-10-19 | logs/T033-verification.md ; 363 tests ; composants de plafond partagés (capped_choice.dart) ; codes = ceux du serveur ; à confirmer par Jeff : livraison d'un restaurant présélectionnée sur « oui » (maquette) |
| ✅ | T034 | Mobile : choix précis du lieu (ville/village puis quartier) — écran sans maquette | b3 | | 2026-10-19 | logs/T034-verification.md ; 407 tests ; écran sans maquette décrit (ville avec recherche, puis quartier facultatif) ; règle de niveau unique isBusinessZoneLevel ; champ Ville / Quartier obligatoire, prérempli depuis la ville de T022 ; refactor minimal de choose_city_screen.dart (CityCard publique) |
| ✅ | T035 | Mobile : récapitulatif et envoi | b3 | | 2026-10-19 | logs/T035-verification.md, logs/T035-blocage.md ; 525 tests (mobile OK avec faux serveur) ; contrat corrigé en T026c et T035c (numéro ancré imposé par le serveur, photo du commerce facultative, lieu « Ville, Quartier ») ; essai réel en T036 |
| ✅ | T036 | Vérification de tranche : créer un commerce de bout en bout | orchestrateur | 2026-10-19 | logs/T036-tranche.md ; parcours réel mobile → serveur local pour un prestataire (CNI + diplôme en espace privé) et un commerce ; plafond SUBSCRIPTION_REQUIRED, 409, clé d'un autre compte refusée ; reste à Jeff : essai sur téléphone, écrans sans maquette, décisions en attente |
| | | **PHASE 4 — Espace commerçant : produits et offres** | | | |
| ✅ | T037 | Backend : offres du commerçant | a2 | 2026-10-21 | docs/verifications/T037.md ; vérificateur CONFORME ; reste : offres dans seed_demo |
| ✅ | T038 | Mobile : « Mes produits » | b3 | 2026-10-21 | docs/verifications/T038.md ; vérificateur CONFORME |
| | | **PHASE 5 — Recherche et écran d'Accueil (Étape 4, chemin critique)** | | | |
| ✅ | T040 | Backend : moteur de recherche | a3 | 2026-10-21 | docs/verifications/T040.md ; vérificateur CONFORME |
| ✅ | T041 | Backend : route de recherche, suggestions, recherche vocale | a3 | 2026-10-21 | docs/verifications/T041.md ; vérificateur CONFORME |
| ✅ | T043 | Mobile : données et état de la recherche | b2 | 2026-10-21 | docs/verifications/T043.md ; vérificateur CONFORME |
| ✅ | T044 | Mobile : écran d'Accueil | b2 | 2026-10-21 | docs/verifications/T044.md ; vérificateur CONFORME |
| ✅ | T045 | Mobile : recherche écrite et résultats | b2 | 2026-10-21 | docs/verifications/T045.md ; vérificateur CONFORME |
| ✅ | T046 | Mobile : recherche vocale | b2 | 2026-10-21 | docs/verifications/T046.md ; vérificateur CONFORME |
| ✅ | T047b | Backend : fiche publique | a2 | 2026-10-21 | docs/verifications/T047b.md ; vérificateur CONFORME |
| ✅ | T047 | Mobile : fiche publique du commerçant | b2 | 2026-10-21 | docs/verifications/T047.md ; vérificateur CONFORME |
| ✅ | T048 | Vérification de tranche : trouver un commerçant | orchestrateur | 2026-10-21 | docs/verifications/T048.md ; vérificateur CONFORME |
| | | **PHASE 6 — Appeler et écrire sur WhatsApp (Étape 4, zone la plus sensible)** | | | |
| ✅ | T050 | 🔒 Backend : lancer un appel | a3 | 2026-10-21 | docs/verifications/T050.md ; vérificateur CONFORME |
| ✅ | T051 | Backend : WhatsApp, retour d'appel, historique | a3 | 2026-10-21 | docs/verifications/T051.md ; vérificateur CONFORME |
| ✅ | T052 | 🔒 Mobile : bouton Appeler, feuille Orange / MTN, appel direct Android | b2 | 2026-10-21 | docs/verifications/T052.md ; vérificateur CONFORME |
| ✅ | T053 | Mobile : historique des appels | b2 | 2026-10-21 | docs/verifications/T053.md ; vérificateur CONFORME |
| ✅ | T054 | Mobile : WhatsApp et retour d'appel | b2 | 2026-10-21 | docs/verifications/T054.md ; vérificateur CONFORME |
| ✅ | T055 | Mobile : dernier résultat hors connexion | b2 | 2026-10-21 | docs/verifications/T055.md ; vérificateur CONFORME |
| ✅ | T056 | Tests du bloc recherche et appel | b2 | 2026-10-21 | docs/verifications/T056.md ; vérificateur CONFORME |
| ✅ | T057 | Vérification de tranche CRITIQUE : de la recherche à l'appel | orchestrateur | 2026-10-21 | docs/verifications/T057.md ; vérificateur CONFORME |
| | | **PHASE 7 — Explorer par quartier (Étape 4)** | | | |
| ✅ | T060 | Backend : carte par zones | a2 | 2026-10-21 | docs/verifications/T060.md ; vérificateur CONFORME |
| ✅ | T061 | Mobile : écran Carte | b2 | 2026-10-21 | docs/verifications/T061.md ; vérificateur CONFORME |
| ✅ | T062 | Mobile : détail d'un quartier | b2 | 2026-10-21 | docs/verifications/T062.md ; vérificateur CONFORME |
| ✅ | T063 | Vérification de tranche : carte | orchestrateur | 2026-10-21 | docs/verifications/T063.md ; vérificateur CONFORME |
| | | **PHASE 8 — Administration : API puis dashboard (Étape 5)** | | | |
| ✅ | T070 | 🔒 Backend : droits d'administration et journal d'audit | c2 | 2026-10-21 | docs/verifications/T070.md ; vérificateur CONFORME |
| ✅ | T071 | 🔒 Backend : demandes de compte business (validation) | c2 + a2 | 2026-10-21 | docs/verifications/T071.md ; vérificateur CONFORME |
| ✅ | T072 | Backend : comptes (liste, blocage, suppression douce, restauration) | c2 | 2026-10-21 | docs/verifications/T072.md ; vérificateur CONFORME |
| ✅ | T073 | Backend : chiffres du tableau de bord | c2 | 2026-10-21 | docs/verifications/T073.md ; vérificateur CONFORME |
| ✅ | T074 | Backend : réglages, administrateurs, export | c2 | 2026-10-21 | docs/verifications/T074.md ; vérificateur CONFORME |
| ✅ | T074b | Backend : référentiels modifiables par l'administration | c2 | 2026-10-21 | docs/verifications/T074b.md ; vérificateur CONFORME |
| ✅ | T074c | Backend : analyses, abonnements, lecture de l'audit | c2 | 2026-10-21 | docs/verifications/T074c.md ; vérificateur CONFORME |
| ✅ | T075 | Backend : tests et contrat de l'administration | c2 | 2026-10-21 | docs/verifications/T075.md ; vérificateur CONFORME ; contrat admin T070-T074c relu par le vérificateur (70 routes) |
| ✅ | T076 | Dashboard : kit de composants et thème | c3 | 2026-10-21 | docs/verifications/T076.md ; vérificateur CONFORME |
| ✅ | T077 | 🔒 Dashboard : connexion de l'administrateur | c3 | 2026-10-21 | docs/verifications/T077.md ; vérificateur CONFORME |
| ✅ | T078 | Dashboard : mise en page | c3 | 2026-10-21 | docs/verifications/T078.md ; vérificateur CONFORME |
| ✅ | T081 | Dashboard : Vue d'ensemble | c3 | 2026-10-21 | docs/verifications/T081.md ; vérificateur CONFORME |
| ✅ | T082 | Dashboard : Demandes | c3 | 2026-10-21 | docs/verifications/T082.md ; vérificateur CONFORME |
| ✅ | T083 | Dashboard : Comptes | c3 | 2026-10-21 | docs/verifications/T083.md ; vérificateur CONFORME |
| ✅ | T085 | Dashboard : référentiels | c3 | 2026-10-21 | docs/verifications/T085.md ; vérificateur CONFORME |
| ✅ | T086 | Dashboard : réglages et administrateurs | c3 | 2026-10-21 | docs/verifications/T086.md ; vérificateur CONFORME |
| ✅ | T087 | Dashboard : journal d'audit | c3 + c2 | 2026-10-21 | docs/verifications/T087.md ; vérificateur CONFORME |
| ✅ | T088 | Dashboard : export | c3 | 2026-10-21 | docs/verifications/T088.md ; vérificateur CONFORME |
| ✅ | T089 | Vérification de tranche : administration de bout en bout | orchestrateur | 2026-10-21 | docs/verifications/T089.md ; vérificateur CONFORME |
| | | **PHASE 9 — Forum : publications et commentaires (Étape 7)** | | | |
| ✅ | T090 | Backend : publications, commentaires, signalements | a3 | 2026-10-21 | docs/verifications/T090.md ; vérificateur CONFORME |
| ✅ | T091 | Mobile : Publier et Mes publications | b3 | 2026-10-21 | docs/verifications/T091.md ; vérificateur CONFORME |
| ✅ | T092 | Mobile : Forum et page d'une publication | b3 | 2026-10-21 | docs/verifications/T092.md ; vérificateur CONFORME |
| ✅ | T093 | Mobile : signaler | b3 | 2026-10-21 | docs/verifications/T093.md ; vérificateur CONFORME |
| ✅ | T094 | Backend : modération | a3 + c2 | 2026-10-21 | docs/verifications/T094.md ; vérificateur CONFORME |
| ✅ | T095 | Dashboard : modération du forum | c3 | 2026-10-21 | docs/verifications/T095.md ; vérificateur CONFORME |
| ✅ | T096 | Vérification de tranche : forum | orchestrateur | 2026-10-21 | docs/verifications/T096.md ; vérificateur CONFORME |
| | | **PHASE 10 — Profil, aide, langue** | | | |
| ✅ | T100 | Mobile : réglages (langue et thème) | b3 | 2026-10-21 | docs/verifications/T100.md ; vérificateur CONFORME |
| ✅ | T101 | Mobile : Aide et support | b3 | 2026-10-21 | docs/verifications/T101.md ; vérificateur CONFORME |
| ✅ | T102 | Mobile : finition de l'écran Profil | b1 | 2026-10-21 | docs/verifications/T102.md ; vérificateur CONFORME |
| ✅ | T102b | Mobile : modifier ma boutique | b3 | 2026-10-21 | docs/verifications/T102b.md ; vérificateur CONFORME |
| ✅ | T103 | Vérification de tranche : profil | orchestrateur | 2026-10-21 | docs/verifications/T103.md ; vérificateur CONFORME |
| | | **PHASE 11 — Produits très sollicités et abonnements (sans paiement)** | | | |
| ✅ | T104 | Backend : tendances | a3 | 2026-10-21 | docs/verifications/T104.md ; vérificateur CONFORME |
| ✅ | T105 | Mobile : produits très sollicités | b3 (dépôt et état des tendances) puis b2 (bande sur l'Accueil), dans cet ordre | 2026-10-21 | docs/verifications/T105.md ; vérificateur CONFORME |
| ✅ | T106 | Dashboard : analyses | c3 | 2026-10-21 | docs/verifications/T106.md ; vérificateur CONFORME |
| ✅ | T110 | Backend : accorder, faire expirer, proposer un abonnement (sans paiement) | a2 (expiration, proposition) puis c2 (route d'administration), dans cet ordre | 2026-10-21 | docs/verifications/T110.md ; vérificateur CONFORME |
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
| backend/apps/geo/data/zones.csv | Les 57 autres départements, ~357 autres arrondissements, villes et villages (avec leur rattachement), quartiers des autres villes et les autres quartiers de Maroua, repères | T020 |
| backend/apps/catalog/data/categories.json | Sous-catégories de Pharmacie & Santé, Mode & Beauté, Électronique & Informatique, Immobilier, Agriculture & Élevage | T021 |
| backend/apps/catalog/data/{products,synonyms}.csv | Produits du catalogue et synonymes (vides aujourd'hui) | T021 |
| backend/apps/geo/data/zones.csv | Codes officiels et coordonnées (latitude, longitude) pour l'écran Carte | T020 |

## Écrans créés sans maquette

| Écran | Tâche | Choix fait |
|---|---|---|
| Choix du lieu du commerce (ville / village puis quartier, écran complet, 2 écrans) | T034 | cartes de T022, bouton retour rond des maquettes CreationBusiness ; quartier facultatif (« Je ne trouve pas mon quartier ») ; textes business.create.location.* écrits par b3 |
| Création du compte business, étape Informations : feuille de choix de photo, messages d'erreur, « Cette étape arrive bientôt » | T030 | textes courts écrits par b3 (FR/EN) ; le bouton de bascule de thème de la maquette n'est pas reproduit |
| Choisir ma ville (écran entier) + textes city.* + « Ma ville » / « Non choisie » dans Profil | T022 | cartes du Profil (fond, bordure, rayon 16), titre 21 px gras, accent #F2942E, icône générique de ville ; une carte par ville de niveau ville_village |
| Saisie du nom après la première connexion (titre, aide, champ, boutons) | T011b | « Comment vous appelez-vous ? » / « Votre prénom ou votre nom, comme vous voulez qu'on vous appelle. C'est facultatif. » / « Prénom ou nom » / « Continuer » / « Passer » |
| Connexion : textes d'erreur, compte à rebours « Renvoyer le code dans N s », libellés d'accessibilité | T011 | textes courts écrits sans maquette (ex. « Code incorrect », « Code expiré », « Trop d'essais, réessayez plus tard », « Contactez le support », « Pas de connexion. Vérifiez votre réseau et réessayez. ») |
| Découverte, diapositive 5 (sous-texte) | T010 | « Publiez vos produits ou services pour être trouvé près de chez vous. » (la maquette n'a que la version équipe/parrainage, reportée) |

## Journal

| Date | Événement |
|---|---|
| 2026-10-11 | Pilotage copié dans netbuis/ ; Flutter 3.47.7 installé dans ~/development/flutter (SDK Android absent) ; Jeff demande T001–T003 en parallèle (dossiers séparés). |
| 2026-10-11 | Coupure du PC pendant la construction de l'APK (T003) ; reprise, APK debug construit, T003 validée. |
| 2026-10-16 | Reprise en session cloud sur le dépôt GitHub Ntchamba/netbuis (branche etape-2/acces). T006b validée par Jeff. Dépôt assaini : `.gitignore` ajouté ; `backend/.env`, `backend/.venv`, `logs/` et caches Python retirés du suivi (fichiers conservés sur le disque) ; agents copiés de `netbuis-pilotage/.claude/` vers `.claude/`. ⚠️ `backend/.env` avait été poussé sur GitHub : Jeff doit changer son mot de passe PostgreSQL. |
| 2026-10-16 | T007 validée par Jeff. Jeff : le backend et sa base PostgreSQL sont hébergés sur Railway (pas en local) ; le mot de passe reste dans `backend/.env` (dépôt privé), à ne jamais lire. |
| 2026-10-17 | T012 : la connexion de bout en bout fonctionne entre le mobile (code réel) et le backend local ; pas d'émulateur dans la session cloud, l'essai sur téléphone reste à faire par Jeff. |
| 2026-10-17 | Jeff valide T012 et demande de pousser la branche etape-2/acces. |
| 2026-10-17 | T023 : le mobile (dépôts réels) affiche les vraies villes et secteurs du backend local. |
| 2026-10-19 | T026c (correction de contrat trouvée par T035) : le numéro ancré est toujours owner.phone, imposé par le serveur ; la photo du commerce est facultative (maquette). Docs mises à jour (MODELE_DONNEES, D-08). Reste à corriger côté mobile : retrait du refus d'envoi sans photo du commerce et ordre du lieu « Maroua, Hardé ». |
| 2026-10-19 | T036 : un commerce se crée de bout en bout entre le mobile (code réel) et le backend local ; pas d'émulateur dans la session cloud, l'essai sur téléphone reste à faire par Jeff. |
