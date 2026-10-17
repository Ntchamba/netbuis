# NetBuis — Plan de réalisation de A à Z (copie du document vivant)

Document vivant (à jour, modifiable) : https://claude.ai/code/artifact/4c402652-5ccf-4462-b2f9-a14d5563ebb4
Copie générée le 06/10/2026. Hypothèses : Jeff seul avec Claude, Django + Flutter, début 06/10/2026, Android d'abord, paiement via CamPay. Version 1.0 sur Google Play vers le 14/05/2027 ; version 1.1 (forum, tendances, parrainage, commandes) jusqu'au 10/06/2027. Aucune marge incluse : prévoir +20 %.
Points à confirmer : équipe, Flutter/Dart, moyen de paiement des 25 USD du compte Play (pas de carte bancaire), création du compte CamPay.

## Bloc 0 — Comptes, accès et activations (à faire avant de coder)

Ce bloc ouvre les comptes dont tout le reste dépend et ne contient aucun code. 11 tâches et 3 attentes, du 06/10/26 au 20/10/26.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 0.1 | Adresse e-mail du projet, gestionnaire de mots de passe, double authentification | E-mail dédié ; Bitwarden ; 2FA par application (pas par SMS) sur tous les comptes ci-dessous | Jeff | 06/10/26 |
| 0.2 | Organisation GitHub et dépôts privés | `netbuis-backend`, `netbuis-mobile`, `netbuis-docs` ; branche `main` protégée (revue + tests verts obligatoires), branche `develop` | Jeff | 06/10/26 |
| 0.3 | Nom de domaine et DNS | `netbuis.cm` (bureau d'enregistrement .cm) ou repli `.app` ; DNS Cloudflare : `api.`, `staging-api.`, `admin.`, `www.` | Jeff | 07/10/26 |
| 0.3w | Attente : enregistrement du domaine | après 0.3 | Attente | 07/10/26 → 12/10/26 |
| 0.4 | Compte d'hébergement serveur | 2 VPS Ubuntu 24.04 LTS (≥ 2 vCPU, 4 Go RAM, 80 Go SSD) : staging et production ; hébergeur à choisir (OVHcloud, Hetzner, Scaleway) ; mesurer la latence vers Douala ; voir loi 2024/017 (hébergement hors Cameroun) | Jeff | 07/10/26 |
| 0.5 | Stockage objet compatible S3 | 2 compartiments privés `netbuis-media` et `netbuis-backups` ; clés d'accès séparées ; versioning activé | Jeff | 08/10/26 |
| 0.6 | Compte CamPay de démonstration | Inscription sur demo.campay.net/en/signup/ ; récupérer `app_username`/`app_password` ou le jeton permanent (section APP KEYS) ; noter les pièces demandées pour la production | Jeff | 08/10/26 |
| 0.6w | Attente : validation du compte CamPay | après 0.6 | Attente | 09/10/26 → 15/10/26 |
| 0.7 | Fournisseur de SMS pour les codes OTP | Nexah (passerelle locale) en premier choix, Twilio Verify en repli ; clé d'API dans le gestionnaire de mots de passe ; test d'envoi vers un numéro Orange et un numéro MTN | Jeff | 09/10/26 |
| 0.8 | Projet Firebase | Projets `netbuis-dev` et `netbuis-prod` ; activer Cloud Messaging (FCM) et Crashlytics ; télécharger `google-services.json` | Jeff | 12/10/26 |
| 0.9 | Compte Sentry | Projets `netbuis-backend` et `netbuis-mobile` ; noter les deux DSN | Jeff | 12/10/26 |
| 0.10 | Compte Google Play Console | Frais d'inscription unique de 25 USD, payés par carte bancaire : vous n'en avez pas, donc vérifier d'abord quel moyen de paiement Google accepte pour vous ; identité, téléphone et appareil Android à vérifier | Jeff | 13/10/26 |
| 0.10w | Attente : vérification Google du compte développeur | après 0.10 | Attente | 13/10/26 → 20/10/26 |
| 0.11 | Matériel de test | 1 téléphone Android 16 réel ; 1 téléphone bas de gamme 2 Go de RAM ; 2 SIM (Orange et MTN) avec Orange Money / MTN MoMo ; un téléphone double SIM | Jeff | 13/10/26 → 14/10/26 |

## Bloc 1 — Outillage, dépôt de code, CI/CD et configuration de Claude

Ce bloc installe l'atelier : dépôts, tests automatiques, trois environnements, et la configuration de Claude et de ses agents. 14 tâches, du 06/10/26 au 15/10/26.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 1.1 | Installer l'environnement de développement | Python 3.12, `uv`, Docker, PostgreSQL 16, Redis 7, Git ; Flutter stable + Android Studio (SDK Android 36), JDK 17 | Backend | 06/10/26 |
| 1.2 | Dépôt backend et `docker-compose.yml` | Services `db` (postgres:16), `redis`, `web` ; `.env.example` ; `Makefile` (`make run`, `make test`, `make lint`) | Backend | 07/10/26 |
| 1.3 | Qualité du code backend | `ruff` (lint + format), `mypy`, `pre-commit`, `pytest`, `pytest-django`, `factory_boy`, `coverage` (seuil 80 % sur les règles métier) | Backend | 07/10/26 |
| 1.4 | CI backend (GitHub Actions) | `.github/workflows/backend.yml` : lint → tests (services postgres:16 + redis) → build de l'image Docker, sur chaque pull request | Backend | 08/10/26 |
| 1.5 | Dépôt mobile Flutter | `flutter create --org cm.netbuis --project-name netbuis_mobile .` ; identifiant d'application `cm.netbuis.app` ; `flutter_lints` | Mobile | 08/10/26 |
| 1.6 | Structure du projet Flutter par fonctionnalité | `lib/core/` (réseau, thème, erreurs) ; `lib/features/{auth,search,map,business,calls,billing,forum,referral,orders,help}/{data,domain,presentation}` ; Riverpod + `go_router` | Mobile | 08/10/26 → 09/10/26 |
| 1.7 | CI mobile | `.github/workflows/mobile.yml` : `flutter analyze`, `flutter test`, `flutter build apk --debug`, cache pub | Mobile | 09/10/26 → 12/10/26 |
| 1.8 | Trois environnements (dev, staging, prod) | Django `config.settings.{dev,staging,prod}` ; Flutter `--dart-define-from-file=env/{dev,staging,prod}.json` (URL de l'API) ; aucun secret dans le code | Backend | 09/10/26 |
| 1.9 | Écrire `CLAUDE.md` (backend et mobile) | Pile, commandes, règles non négociables : numéro jamais dans les listes, PIN jamais saisi dans l'application, une migration par changement, pas de secret dans le dépôt ; définition de « fini » | Backend | 09/10/26 → 12/10/26 |
| 1.10 | Définir les agents Claude | `.claude/agents/backend-dev.md`, `mobile-dev.md`, `test-writer.md`, `reviewer-securite.md` (grille OWASP Mobile Top 10 2024) ; un contrat d'entrée/sortie par agent ; 1 superviseur + 3 à 5 agents au plus (audit v20) | Backend | 12/10/26 → 13/10/26 |
| 1.11 | Permissions et garde-fous de Claude Code | `.claude/settings.json` : autoriser `make test`, `git diff` ; refuser la lecture de `.env*`, `rm -rf`, `git push --force` ; hook qui bloque l'écriture de secrets | Backend | 13/10/26 |
| 1.12 | Outils connectés à Claude | `.mcp.json` (GitHub, base de données en lecture seule sur dev uniquement) ; projet Claude « NetBuis » avec les documents de référence (`modele-donnees`, `decision-finale-appels`, `decision-campay`) | Backend | 14/10/26 |
| 1.13 | Contrat d'API d'abord (OpenAPI) | `drf-spectacular` génère `openapi.yaml` ; sert de contrat entre Django et Flutter ; client Dart écrit à partir de ce contrat | Backend | 14/10/26 → 15/10/26 |
| 1.14 | Tableau de suivi des tâches | GitHub Projects : À faire / En cours / Revue / Fait ; limite de travail en cours = capacité de relecture de Jeff ; importer ce plan | Jeff | 14/10/26 |

## Bloc 2 — Socle backend Django

Ce bloc crée le squelette Django (8 apps), la base PostgreSQL, Redis, Celery, le stockage S3 et un premier serveur de test. 13 tâches, du 15/10/26 au 04/11/26.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 2.1 | Projet Django 5 et les 8 apps | `django-admin startproject config .` ; `startapp` dans `apps/` : `accounts`, `business`, `geo`, `forum`, `calls`, `billing`, `referral`, `admin_panel` ; poser tout de suite un `accounts.Account` minimal et `AUTH_USER_MODEL` avant le premier `migrate` (complété en 3.1) | Backend | 15/10/26 |
| 2.2 | Réglages par environnement | `config/settings/{base,dev,staging,prod}.py` ; `django-environ` ; psycopg 3 ; `TIME_ZONE='Africa/Douala'` ; `LANGUAGE_CODE='fr'` ; options `SECURE_*` en production | Backend | 16/10/26 |
| 2.3 | Extensions PostgreSQL par migration | `TrigramExtension()` et `UnaccentExtension()` (`django.contrib.postgres.operations`) dans `0001_extensions.py` | Backend | 19/10/26 |
| 2.4 | Django REST Framework | `REST_FRAMEWORK` : pagination par défaut (20), authentification JWT, limitation de débit (`DEFAULT_THROTTLE_RATES`), gestionnaire d'erreurs uniforme `{code, message}` | Backend | 19/10/26 → 20/10/26 |
| 2.5 | Modèles abstraits communs | `core.models.TimeStampedModel` (created_at, updated_at) ; clés publiques en UUID ; `SoftDeleteModel` | Backend | 20/10/26 |
| 2.6 | Redis et cache Django | `CACHES['default']` avec `django_redis` ; clés de cache pour les référentiels | Backend | 21/10/26 |
| 2.7 | Celery et Celery Beat | `config/celery.py` ; `CELERY_BROKER_URL` ; `django-celery-beat` ; une tâche de test planifiée | Backend | 21/10/26 → 22/10/26 |
| 2.8 | Stockage de fichiers S3 | `django-storages[s3]` ; médias publics d'un côté, fichiers privés (CNI, diplômes) de l'autre avec URL signées de 5 minutes | Backend | 22/10/26 → 23/10/26 |
| 2.9 | Journaux et suivi des erreurs | `sentry-sdk[django]` ; journaux JSON ; endpoint `GET /health/` | Backend | 23/10/26 |
| 2.10 | Documentation de l'API | `/api/schema/` et `/api/docs/` (désactivé en production) | Backend | 26/10/26 |
| 2.11 | Modèle `Zone` et chargement initial | `geo.Zone(name, level, parent, official_code)` ; commande `load_zones` : 10 régions, 58 départements, 360 arrondissements ; éditable depuis l'admin | Backend | 26/10/26 → 29/10/26 |
| 2.12 | Référentiels | `Secteur`, `SousCategorie`, `CategorieService`, `TypeStructure` ; commande `seed_referentials` (10 secteurs, sous-catégories, 7 catégories de service, 5 types de structure) | Backend | 29/10/26 → 02/11/26 |
| 2.13 | Premier déploiement en staging | Image Docker ; `docker compose -f compose.staging.yml up -d` ; HTTPS par Caddy ; `https://staging-api.netbuis.cm/health/` répond | Backend | 02/11/26 → 04/11/26 |

## Bloc 3 — Inscription et connexion par code SMS (OTP)

Ce bloc permet de créer un compte et de se connecter avec un numéro de téléphone et un code SMS, sans mot de passe. 16 tâches, du 04/11/26 au 17/11/26.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 3.1 | Modèle `Account` personnalisé | `accounts.Account(AbstractBaseUser)` avec `phone` (E.164, unique) comme `USERNAME_FIELD`, `name`, `is_equipe_netbuis`, `equipe_status`, `is_admin` ; `AUTH_USER_MODEL = 'accounts.Account'` (réglage posé dès 2.1, avant toute migration) | Backend | 04/11/26 → 05/11/26 |
| 3.2 | Modèle `OtpChallenge` | `phone`, `code_hash` (jamais en clair), `expires_at` (5 min), `attempts`, `ip` | Backend | 05/11/26 |
| 3.3 | Service d'envoi de SMS abstrait | `SmsProvider.send(phone, message)` ; `NexahProvider`, `TwilioVerifyProvider`, `ConsoleProvider` (développement) ; choix par `SMS_PROVIDER` | Backend | 06/11/26 → 09/11/26 |
| 3.4 | `POST /api/v1/auth/otp/request/` | Validation du numéro `+237` + 9 chiffres ; limites : 3 envois/heure/numéro, 10/heure/IP (`ScopedRateThrottle`) | Backend | 09/11/26 → 10/11/26 |
| 3.5 | `POST /api/v1/auth/otp/verify/` | Vérifie hash, expiration, 5 essais maximum ; crée ou retrouve le compte ; renvoie `access` (15 min) + `refresh` (30 jours) via `djangorestframework-simplejwt` | Backend | 10/11/26 → 11/11/26 |
| 3.6 | SMS compatible avec l'auto-remplissage | Format SMS Retriever : `<#> Votre code NetBuis : 123456` + saut de ligne + hash d'application de 11 caractères | Backend | 11/11/26 |
| 3.7 | Rafraîchissement et déconnexion | `POST /auth/token/refresh/`, `POST /auth/logout/` ; `rest_framework_simplejwt.token_blacklist` | Backend | 12/11/26 |
| 3.8 | Anti-abus à l'inscription | `device_id` signé ; plus de 3 numéros sur un même appareil → drapeau pour revue admin (empêche de cumuler des appels gratuits) | Backend | 12/11/26 → 13/11/26 |
| 3.9 | Tests d'authentification | pytest : code expiré, 5 mauvais essais, limite de débit, jeton révoqué ; couverture ≥ 90 % de `accounts` | Backend | 13/11/26 → 16/11/26 |
| 3.10 | Écran de lancement (Splash) | `SplashPage` lit le jeton dans `flutter_secure_storage` ; `go_router` redirige vers `/login` ou `/home` | Mobile | 06/11/26 |
| 3.11 | Écran de découverte (5 vues) | `OnboardingPage` avec `PageView` ; drapeau `onboarding_done` ; texte sur le numéro corrigé (voir 15.8) | Mobile | 09/11/26 |
| 3.12 | Client HTTP et gestion des jetons | `dio` + `AuthInterceptor` (ajoute `Authorization: Bearer`, rafraîchit sur 401) ; jetons dans `flutter_secure_storage` (Android Keystore) | Mobile | 10/11/26 → 11/11/26 |
| 3.13 | Écran de connexion : saisie du numéro | `LoginPage`, préfixe `+237` fixe, clavier numérique, validation locale, appelle `/auth/otp/request/` | Mobile | 11/11/26 → 12/11/26 |
| 3.14 | Écran du code OTP et auto-remplissage | Package `sms_autofill` (SMS Retriever, sans permission SMS) ; compte à rebours de 60 s avant « Renvoyer le code » | Mobile | 12/11/26 → 13/11/26 |
| 3.15 | Messages d'erreur sans jargon | `AppFailure` → phrases simples en français (« Pas de réseau », « Code incorrect ») ; jamais de code technique | Mobile | 16/11/26 |
| 3.16 | Tests Flutter de l'authentification | Tests de widgets (saisie, erreurs) + test d'intégration avec faux serveur | Mobile | 16/11/26 → 17/11/26 |

## Bloc 4 — Modification et gestion du compte

Ce bloc permet de modifier son profil, de changer de numéro et de supprimer son compte, ce que Google Play exige. 10 tâches, du 16/11/26 au 24/11/26.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 4.1 | `GET/PATCH /api/v1/me/` | `MeSerializer` (nom, photo, langue, préférences) ; le numéro n'est pas modifiable ici | Backend | 16/11/26 |
| 4.2 | Changement de numéro | `POST /me/phone/change/request/` et `/verify/` : code envoyé au NOUVEAU numéro ; invalide les anciens jetons | Backend | 17/11/26 |
| 4.3 | Photo de profil | `POST /me/photo/` multipart ; type et poids contrôlés (≤ 2 Mo) ; redimensionnement 512 px avec Pillow ; stockage S3 | Backend | 18/11/26 |
| 4.4 | Suppression de compte et export des données | `DELETE /me/` (anonymisation, suppression définitive après 30 jours par tâche Celery) ; `GET /me/export/` (JSON) ; exigé par Google Play et par la loi sur les données | Backend | 19/11/26 → 20/11/26 |
| 4.5 | Écran Profil | `ProfilePage` : nom, photo, appels gratuits restants, liens (Aide, Mes appels, Mes publications, Devenir business) | Mobile | 18/11/26 → 19/11/26 |
| 4.6 | Écran Modifier le profil | Formulaire nom + photo (`image_picker` + `flutter_image_compress`, ≤ 300 Ko) ; envoi multipart | Mobile | 19/11/26 → 20/11/26 |
| 4.7 | Écran Changer de numéro | `ChangePhonePage` en 2 étapes (nouveau numéro, code) | Mobile | 20/11/26 → 23/11/26 |
| 4.8 | Écran Supprimer mon compte | Confirmation en 2 étapes, texte clair sur les conséquences ; appelle `DELETE /me/` | Mobile | 23/11/26 |
| 4.9 | Paramètres : langue, taille du texte, économie de données | `shared_preferences` ; `LocaleController` ; `MediaQuery.textScaler` | Mobile | 24/11/26 |
| 4.10 | Tests du bloc compte | pytest (profil, changement de numéro, suppression) + tests Flutter des 4 écrans | Backend | 20/11/26 → 23/11/26 |

## Bloc 5 — Compte business : cinq types, parcours et validation

Ce bloc est le plus long de l'application : il permet de créer un compte business selon l'un des cinq types, jusqu'à la validation par un administrateur. 19 tâches, du 23/11/26 au 11/12/26.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 5.1 | Modèle `BusinessProfile` | `owner` (OneToOne), `display_name`, `type_compte` (boutique, entreprise, particulier_vendeur, prestataire_service, structure), `forme_juridique`, `rccm`, `categorie_service`, `structure_type`, `zone`, `description`, `rep_name`, `rep_photo`, `phone_business`, `landmark` (repère), `opening_hours`, `status` | Backend | 23/11/26 → 24/11/26 |
| 5.2 | Sous-catégories et détails de structure | Table de liaison `BusinessSousCategorie` ; `StructureDetails` (JSON validé par schéma selon le type : rayons, cuisine, standing, spécialités) | Backend | 25/11/26 → 26/11/26 |
| 5.3 | Fichiers sensibles : CNI et diplôme | `cni_photo` en stockage privé, `cni_verifiee`, `diplome_photo` ; URL signée de 5 min, réservée aux admins | Backend | 26/11/26 → 27/11/26 |
| 5.4 | Plafond de sous-catégories selon l'abonnement | `business/rules.py::max_sous_categories(profile)` = 3 sans abonnement actif ; contrôlé dans le sérialiseur ET dans `clean()` du modèle | Backend | 27/11/26 → 30/11/26 |
| 5.5 | Création en étapes | `POST /business/` (brouillon), `PATCH /business/{id}/`, `POST /business/{id}/submit/` → `en_attente_validation` ; champs obligatoires différents selon le type | Backend | 30/11/26 → 02/12/26 |
| 5.6 | `GET /api/v1/referentials/` | Secteurs, sous-catégories, catégories de service, types de structure ; cache Redis + `ETag` | Backend | 02/12/26 |
| 5.7 | Zone obligatoire jusqu'au niveau Ville/Village | Validateur : `zone.level in {Ville_Village, Quartier}` à la soumission | Backend | 03/12/26 |
| 5.8 | Décision de validation ou de rejet | Passe le statut à `actif` ou `rejeté` et crée une `Notification` (envoyée en 15.3). En attendant le dashboard (bloc 16), valider depuis l'admin Django intégré | Backend | 03/12/26 |
| 5.9 | Tests des règles par type de compte | pytest paramétré sur les 5 types, plafond de 3, zone trop haute | Backend | 04/12/26 → 07/12/26 |
| 5.10 | Écran Devenir business : choix du type | `BusinessInfosPage` : Commerce / Entreprise / Structure / Particulier / Prestataire ; libellés qui changent selon le type | Mobile | 25/11/26 → 26/11/26 |
| 5.11 | Écran Forme juridique (Entreprise) | Liste à choix unique + champ RCCM facultatif | Mobile | 27/11/26 |
| 5.12 | Écran Secteur | Grille de 10 secteurs depuis `/referentials/` | Mobile | 27/11/26 |
| 5.13 | Écran Détails du secteur | Sous-catégories avec plafond de 3 ; à la 4e sélection : invitation à s'abonner | Mobile | 30/11/26 |
| 5.14 | Écran Prestataire : catégorie, CNI, diplôme | Photo via `image_picker` ; compression ; envoi TLS ; aperçu avant envoi | Mobile | 01/12/26 → 02/12/26 |
| 5.15 | Écrans Structure : type et détails | `StructureTypePage`, `StructureDetailsPage` (supermarché, restaurant, hôtel, centre de santé) | Mobile | 02/12/26 → 04/12/26 |
| 5.16 | Écran de choix de la zone | `ZonePickerPage` récursive (Région → … → Ville/Village/Quartier) ; bloque « Suivant » si le niveau est trop haut | Mobile | 04/12/26 → 07/12/26 |
| 5.17 | Écran Récapitulatif et envoi | `BusinessRecapPage` ; appelle `submit` ; état « En attente de validation » | Mobile | 08/12/26 |
| 5.18 | Écran Mon compte business | Statut, modification, photos | Mobile | 09/12/26 |
| 5.19 | Tests Flutter du parcours de création | Test d'intégration des 5 parcours | Mobile | 10/12/26 → 11/12/26 |

## Bloc 6 — Catalogue de produits et photos

Ce bloc permet à un commerçant validé de publier ses produits avec photos et d'être consulté sans que son numéro soit exposé. 9 tâches, du 07/12/26 au 17/12/26.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 6.1 | Modèles `Product` et `ProductPhoto` | `Product(business, name, description, price_fcfa:int, is_available)` ; `ProductPhoto` ordonnées | Backend | 07/12/26 → 08/12/26 |
| 6.2 | CRUD des produits | `/api/v1/business/{id}/products/` ; permission `IsBusinessOwner` ; seulement pour les comptes `actif` | Backend | 08/12/26 → 09/12/26 |
| 6.3 | Traitement des photos | Pillow : miniature 200 px et image 800 px en WebP ; suppression des données EXIF/GPS ; tâche Celery `process_image` | Backend | 09/12/26 → 10/12/26 |
| 6.4 | Compteurs d'activité | `ProductStat(views, calls)` incrémentés par lot (Celery) pour ne pas ralentir la lecture | Backend | 11/12/26 |
| 6.5 | Fiche publique d'un commerçant | `GET /business/{id}/` SANS numéro de téléphone ; horaires, repère, produits paginés | Backend | 14/12/26 |
| 6.6 | Écrans Mes produits et formulaire produit | `MyProductsPage`, `ProductFormPage` (photo, nom, prix, disponibilité) | Mobile | 11/12/26 → 15/12/26 |
| 6.7 | Écran Fiche commerçant | `BusinessDetailPage` : photos, produits, repère, bouton Appeler, Partager (`share_plus`, WhatsApp) | Mobile | 15/12/26 → 17/12/26 |
| 6.8 | Cache d'images | `cached_network_image` ; miniatures sur réseau faible | Mobile | 17/12/26 |
| 6.9 | Tests du catalogue | pytest (permissions, absence du numéro dans les réponses) + tests Flutter | Backend | 15/12/26 |

## Bloc 7 — Recherche intelligente (PostgreSQL)

Ce bloc construit le cœur du produit : taper un produit, voir les commerçants qui l'ont, même avec des fautes ou des accents oubliés. 12 tâches, du 16/12/26 au 30/12/26.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 7.1 | Colonne normalisée et index GIN | Fonction SQL `f_unaccent` déclarée IMMUTABLE (`RunSQL`) ; `search_text` = `f_unaccent(lower(name))` ; `GinIndex(opclasses=['gin_trgm_ops'])` ; colonne `SearchVectorField` avec index GIN | Backend | 16/12/26 → 17/12/26 |
| 7.2 | Table de synonymes locaux | `SearchSynonym(term, alias)` ; par exemple « ciment » ↔ « Dangote » ; alimentée avec les vraies requêtes du pilote | Backend | 17/12/26 → 18/12/26 |
| 7.3 | Service de recherche par niveaux | `search/services.py` : exact > préfixe > mot > approximatif (`TrigramSimilarity` ≥ 0,3) combiné à `SearchQuery` ; tri par pertinence puis fraîcheur | Backend | 18/12/26 → 23/12/26 |
| 7.4 | `GET /api/v1/search/?q=&zone=&page=` | Liste des commerçants qui proposent le produit, SANS numéro ; filtre de zone ; pagination ; `select_related`/`prefetch_related` | Backend | 23/12/26 → 24/12/26 |
| 7.5 | Journal des recherches sans résultat | `SearchLog(query, results_count, zone, created_at)` avec consentement | Backend | 28/12/26 |
| 7.6 | Tests de pertinence | 50 requêtes camerounaises (fautes, accents, mots inversés) avec résultat attendu ; mesure du taux de recherche aboutie | Backend | 28/12/26 → 29/12/26 |
| 7.7 | Test de charge | k6 ou Locust : 50 requêtes/s sur 10 000 produits ; objectif p95 < 300 ms ; `EXPLAIN ANALYZE` | Backend | 30/12/26 |
| 7.8 | Écran d'accueil et barre de recherche | `HomePage`, `SearchBar` (debounce 300 ms), historique local, suggestions | Mobile | 18/12/26 → 21/12/26 |
| 7.9 | Écran des résultats | `SearchResultsPage` avec `ListView.builder` et pagination infinie ; filtres zone et secteur | Mobile | 22/12/26 → 23/12/26 |
| 7.10 | Recherche vocale (option) | `speech_to_text` en `fr-FR` ; permission `RECORD_AUDIO` demandée à l'usage | Mobile | 24/12/26 |
| 7.11 | Cache local des recherches | `drift` : table `recent_searches` ; résultats déjà vus consultables hors ligne | Mobile | 28/12/26 |
| 7.12 | Tests Flutter de la recherche | Tests de widgets et d'intégration | Mobile | 29/12/26 |

## Bloc 8 — Carte et zones

Ce bloc affiche la carte par région, ville et quartier, et seulement là où au moins un commerce actif est enregistré. 8 tâches, du 31/12/26 au 11/01/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 8.1 | Arbre de zones actif | `GET /api/v1/map/zones/?parent=` ne renvoie que les `Ville_Village`/`Quartier` ayant au moins un `BusinessProfile.status='actif'`, avec le nombre ; requête agrégée, cache 5 min | Backend | 31/12/26 → 04/01/27 |
| 8.2 | Commerces d'un quartier | `GET /api/v1/map/zones/{id}/businesses/` paginé, sans numéro | Backend | 05/01/27 |
| 8.3 | Curation des villes et quartiers | Commande `import_osm_places` : extrait Geofabrik du Cameroun, `place=city/town/village/suburb/neighbourhood` → brouillons à valider dans l'admin | Backend | 06/01/27 → 08/01/27 |
| 8.4 | Écran Carte : niveau Villes | `MapPage` : régions → villes ; pastille avec le nombre de commerces | Mobile | 05/01/27 → 06/01/27 |
| 8.5 | Écran Détail d'un quartier | `NeighborhoodPage` : liste des commerces du quartier | Mobile | 07/01/27 → 08/01/27 |
| 8.6 | État « pas encore de détail par quartier » | Message simple quand une ville n'a pas de quartiers actifs | Mobile | 08/01/27 |
| 8.7 | Bouton Itinéraire | `url_launcher` avec `geo:` ou `https://maps.google.com/?q=` : ouvre l'application cartes du téléphone, aucun coût d'API | Mobile | 11/01/27 |
| 8.8 | Tests de la règle de visibilité | pytest : une ville sans commerce actif n'apparaît pas ; un commerce rejeté n'est pas compté | Backend | 11/01/27 |

## Bloc 9 — Appel direct Orange / MTN

Ce bloc lance l'appel en un clic sur Android après le choix de la ligne Orange ou MTN, sans jamais afficher le numéro dans NetBuis. 13 tâches, du 12/01/27 au 28/01/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 9.1 | Modèle `CallLog` | `caller`, `business`, `plateforme` (android/ios), `operateur` (orange/mtn/null), `type` (gratuit/crédit), `created_at` | Backend | 12/01/27 |
| 9.2 | Quota gratuit et solde | `CreditWallet(account, free_used_today, balance)` ; remise à zéro quotidienne par Celery Beat | Backend | 12/01/27 → 13/01/27 |
| 9.3 | `POST /api/v1/calls/initiate/` | Contrôle connexion, business `actif` non bloqué, quota/solde (transaction atomique + `select_for_update`), limite de débit (à trancher, ex. 5/min et 30/jour) ; crée le `CallLog` ; SEUL endroit qui renvoie le numéro | Backend | 13/01/27 → 15/01/27 |
| 9.4 | `POST /api/v1/calls/{id}/outcome/` | Retour en un geste : « Avez-vous eu le produit ? oui / non » | Backend | 15/01/27 |
| 9.5 | Détection d'aspiration de numéros | Plus de N commerçants différents appelés en 10 minutes → gel temporaire du compte + alerte admin | Backend | 18/01/27 |
| 9.6 | Tests des appels | Quota épuisé, solde insuffisant, business bloqué, deux appels simultanés | Backend | 19/01/27 → 20/01/27 |
| 9.7 | Module Kotlin `CallChannel` | `android/app/src/main/kotlin/cm/netbuis/app/CallChannel.kt` ; `MethodChannel("cm.netbuis/call")` : méthodes `getSims` et `placeCall(number, simSlot)` | Mobile | 14/01/27 → 15/01/27 |
| 9.8 | Lecture des SIM actives | `SubscriptionManager.getActiveSubscriptionInfoList()` → `carrierName`, `simSlotIndex`, `subscriptionId` ; correspondance « Orange » / « MTN » insensible à la casse | Mobile | 18/01/27 → 19/01/27 |
| 9.9 | Lancement de l'appel | `TelecomManager.placeCall(Uri.parse("tel:" + n), extras)` avec `EXTRA_PHONE_ACCOUNT_HANDLE` ; repli sur `ACTION_DIAL` si permission refusée | Mobile | 19/01/27 → 21/01/27 |
| 9.10 | Manifeste et permissions | `android.permission.CALL_PHONE` et `READ_PHONE_STATE` dans `AndroidManifest.xml` ; demande à l'exécution avec `permission_handler` et une explication simple | Mobile | 21/01/27 |
| 9.11 | Feuille de choix Orange / MTN | `CallSheet` : deux boutons de 64 px, Annuler, état « Appel en cours… » ; une seule SIM → choix sauté | Mobile | 22/01/27 → 25/01/27 |
| 9.12 | Cas particuliers des SIM | Ligne choisie absente → message + autre ligne ; eSIM ou SIM renommée → repli ; mémorisation du dernier choix (à trancher) | Mobile | 25/01/27 → 26/01/27 |
| 9.13 | Tests sur téléphones réels | Double SIM Orange + MTN, une seule SIM, permission refusée, Android 16 | Mobile | 26/01/27 → 28/01/27 |

## Bloc 10 — Paiement CamPay, crédits et abonnement

Ce bloc encaisse les achats de crédits et les abonnements par Mobile Money avec CamPay, sans que le code secret passe par l'application. 18 tâches, du 18/01/27 au 21/04/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 10.1 | Installer et configurer le SDK CamPay | `pip install campay` ; réglages `CAMPAY_USERNAME`, `CAMPAY_PASSWORD`, `CAMPAY_ENV` (`DEV` ou `PROD`) en variables d'environnement | Backend | 20/01/27 |
| 10.2 | Couche `PaymentProvider` | `billing/providers/base.py` (`collect`, `status`, `payout`) ; `campay.py` : `initCollect`, `get_transaction_status`, `disburse`, `get_balance` | Backend | 21/01/27 → 22/01/27 |
| 10.3 | Modèles de facturation | `CreditPack(name, price_xaf, credits)`, `PaymentTransaction(reference UUID = external_reference, account, operator, amount, status, campay_reference)`, `Subscription` | Backend | 25/01/27 → 26/01/27 |
| 10.4 | `GET /api/v1/billing/packs/` | Packs de 100, 300, 500 FCFA (minimum 50) ; à valider avec la marge nette | Backend | 26/01/27 |
| 10.5 | `POST /api/v1/billing/purchase/` | Numéro Mobile Money (pré-rempli, modifiable), pack ; crée une transaction `pending` ; `initCollect(amount, currency='XAF', from='237…', external_reference=ref)` | Backend | 27/01/27 → 28/01/27 |
| 10.6 | `GET /api/v1/billing/transactions/{id}/` | Interroge `get_transaction_status` si la transaction est en attente depuis plus de 20 s | Backend | 29/01/27 |
| 10.7 | Webhook de notification CamPay | `POST /billing/webhook/campay/` (format à confirmer dans le tableau de bord) ; vérifie l'origine ; crédite UNE seule fois (`select_for_update`) | Backend | 01/02/27 → 02/02/27 |
| 10.8 | Rapprochement automatique | Celery Beat chaque minute : transactions `pending` depuis plus de 90 s → statut CamPay ; expiration à 10 min | Backend | 03/02/27 → 04/02/27 |
| 10.9 | Abonnement commerçant | `Subscription(business, plan, starts_at, ends_at, status)` ; expiration : on garde les contenus, on perd seulement les avantages | Backend | 04/02/27 → 08/02/27 |
| 10.10 | Tarifs et marge nette | Feuille de calcul : frais CamPay (à demander) par pack et par opérateur ; Jeff valide les prix | Jeff | 18/01/27 |
| 10.11 | Tests avec le bac à sable CamPay | Succès, échec, expiration, double notification ; numéros de test MTN et Orange de demo.campay.net | Backend | 08/02/27 → 10/02/27 |
| 10.12 | Écran Solde et packs | `WalletPage` : appels gratuits restants, solde, packs | Mobile | 28/01/27 → 29/01/27 |
| 10.13 | Écran Paiement : numéro Mobile Money | `PayPage` : opérateur détecté par le préfixe, numéro modifiable (cas multi-SIM) | Mobile | 01/02/27 |
| 10.14 | Écran d'attente « Confirmez sur votre téléphone » | Minuteur 90 s ; sondage de `/billing/transactions/{id}/` toutes les 3 s ; le code secret n'est JAMAIS saisi dans l'application | Mobile | 02/02/27 → 03/02/27 |
| 10.15 | États d'échec et « J'ai payé » | Messages clairs ; bouton « J'ai payé » avec capture d'écran vers le support | Mobile | 03/02/27 → 04/02/27 |
| 10.16 | Écran Abonnement commerçant | Plans, avantages, achat par le même flux | Mobile | 04/02/27 → 05/02/27 |
| 10.17 | Tests Flutter du paiement | Tests de widgets + faux serveur | Mobile | 05/02/27 → 08/02/27 |
| 10.18 | Passer CamPay en production | Pièces KYC, `CAMPAY_ENV=PROD`, jeton de production en variable d'environnement ; un vrai paiement de 100 FCFA par opérateur | Backend | 21/04/27 |

## Bloc 11 — Forum et publications

Ce bloc ouvre le forum aux comptes business (publications image ou vidéo) et à tous pour commenter, avec modération ; il est livré dans la version 1.1. 11 tâches, du 23/04/27 au 07/05/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 11.1 | Modèles `Post`, `Comment`, `PostMedia` | `Post(business, type image/video, caption, product?)`, `Comment(post, author, text)` ; n'importe quel compte peut commenter | Backend | 23/04/27 |
| 11.2 | Plafond de publications selon l'abonnement | 5 publications actives sans abonnement, illimité avec (chiffre à confirmer) ; contrôle côté serveur | Backend | 26/04/27 |
| 11.3 | Endpoints du fil et des commentaires | `/api/v1/forum/posts/` (pagination par curseur), `/posts/{id}/comments/`, suppression par l'auteur | Backend | 26/04/27 → 28/04/27 |
| 11.4 | Téléversement d'images et de vidéos | Vidéo ≤ 30 s et ≤ 20 Mo ; transcodage `ffmpeg` en 480p par tâche Celery ; miniature automatique | Backend | 28/04/27 → 30/04/27 |
| 11.5 | Signalement et masquage | `Report` (voir 15.7) ; masquage automatique à 3 signalements ; file de revue dans le dashboard | Backend | 03/05/27 → 04/05/27 |
| 11.6 | Filtres de base | Liste de mots interdits, limite de 5 publications par heure et par compte | Backend | 04/05/27 → 05/05/27 |
| 11.7 | Écran Forum (fil) | `ForumPage` : `ListView.builder`, chargement progressif, lecture vidéo à la demande | Mobile | 27/04/27 → 28/04/27 |
| 11.8 | Écran Publication et commentaires | `PostDetailPage` ; saisie d'un commentaire ; signaler | Mobile | 29/04/27 → 30/04/27 |
| 11.9 | Écran Nouvelle publication | Choix image ou vidéo (`image_picker`), compression avant envoi, légende, produit associé | Mobile | 30/04/27 → 04/05/27 |
| 11.10 | Écran Mes publications | Liste + compteur du plafond + invitation à s'abonner | Mobile | 04/05/27 → 05/05/27 |
| 11.11 | Tests du forum | pytest (plafond, masquage, droits) + tests Flutter | Backend | 05/05/27 → 07/05/27 |

## Bloc 12 — Produits et vendeurs très sollicités (tendances)

Ce bloc montre les produits et vendeurs les plus demandés, calculés chaque nuit à partir des vraies recherches et appels ; livré dans la version 1.1. 4 tâches, du 10/05/27 au 13/05/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 12.1 | Calcul nocturne des tendances | `TrendingProduct` calculé par Celery Beat à partir de `SearchLog` et `CallLog` sur 7 jours glissants ; seuil minimal de volume pour éviter un faux signal | Backend | 10/05/27 → 11/05/27 |
| 12.2 | `GET /api/v1/trending/products/` et `/businesses/` | Cache 1 h, filtre par zone | Backend | 12/05/27 |
| 12.3 | Section « Les plus demandés » | Carrousel sur l'accueil, masqué tant que le volume est trop faible | Mobile | 12/05/27 → 13/05/27 |
| 12.4 | Tests des tendances | pytest avec jeux de données simulés | Backend | 13/05/27 |

## Bloc 13 — Parrainage et équipe NetBuis

Ce bloc fait grandir le réseau de commerçants par l'équipe NetBuis, avec QR de parrainage et primes payées par CamPay ; livré dans la version 1.1. 9 tâches, du 14/05/27 au 02/06/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 13.1 | Candidature à l'équipe NetBuis | `POST /api/v1/team/apply/` (vidéo de la CNI) ; `equipe_status` ; stockage privé | Backend | 14/05/27 → 18/05/27 |
| 13.2 | Écran Candidature équipe | Enregistrement vidéo ≤ 30 s via `image_picker` ; envoi ; suivi du statut | Mobile | 19/05/27 → 21/05/27 |
| 13.3 | Code et QR de parrainage | `Referral` ; code unique par agent ; `GET /team/me/qr/` ; lien profond `https://netbuis.cm/r/<code>` | Backend | 18/05/27 → 19/05/27 |
| 13.4 | Création d'un compte business avec parrain | L'agent saisit ou fait scanner son code ; `Referral(reward_status='en_attente')` | Backend | 21/05/27 → 24/05/27 |
| 13.5 | Règle de la prime | Passe à `du` quand le business devient `actif` (et critère d'abonnement à fixer) ; `annulé` si rejet ; montant dans `PlatformSetting` | Backend | 24/05/27 → 25/05/27 |
| 13.6 | Écran Mon équipe (agent) | Solde de primes, liste des comptes parrainés, QR à montrer | Mobile | 21/05/27 → 24/05/27 |
| 13.7 | Retrait des primes par CamPay | `disburse()` avec validation humaine, plafond par jour, journal ; option « API withdrawal » activée dans CamPay | Backend | 26/05/27 → 27/05/27 |
| 13.8 | Parcours de secours sans smartphone | L'agent crée le profil (`created_by`, `owner` vide) puis le commerçant le réclame par code SMS (`claimed_at`) | Backend | 28/05/27 → 31/05/27 |
| 13.9 | Tests du parrainage | pytest (prime due une seule fois, annulation, plafonds) | Backend | 01/06/27 → 02/06/27 |

## Bloc 14 — Commandes

Ce bloc permet de commander chez un commerçant et de suivre la commande ; livré dans la version 1.1. 6 tâches, du 02/06/27 au 10/06/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 14.1 | Modèles `Order` et `OrderLine` | Acheteur, business vendeur, lignes (produit, quantité, prix figé), statut, date | Backend | 02/06/27 → 03/06/27 |
| 14.2 | Endpoints des commandes | `POST /orders/`, `GET /orders/mine/`, `GET /business/orders/`, `PATCH /orders/{id}/status/` | Backend | 03/06/27 → 07/06/27 |
| 14.3 | Notifications de commande | Push FCM au commerçant (nouvelle commande) et à l'acheteur (changement de statut) | Backend | 07/06/27 |
| 14.4 | Écran Commander | Choix des produits et quantités, confirmation | Mobile | 04/06/27 → 08/06/27 |
| 14.5 | Écrans Mes commandes (client et commerçant) | Listes + détail + changement de statut | Mobile | 08/06/27 → 10/06/27 |
| 14.6 | Tests des commandes | pytest + tests Flutter | Backend | 08/06/27 |

## Bloc 15 — Historique d'appels, notifications, aide et signalement

Ce bloc ajoute l'historique des appels, les notifications, l'aide et le signalement, dont l'application a besoin dès la version 1.0. 8 tâches, du 10/02/27 au 23/02/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 15.1 | `GET /api/v1/calls/mine/` | Historique paginé de l'utilisateur | Backend | 10/02/27 |
| 15.2 | Écran Historique de mes appels | `CallHistoryPage` ; bouton « Rappeler » qui repasse par `/calls/initiate/` | Mobile | 15/02/27 → 16/02/27 |
| 15.3 | Notifications push (serveur) | `Notification`, `DeviceToken` ; `firebase-admin` ; envoi via tâche Celery | Backend | 12/02/27 → 15/02/27 |
| 15.4 | Notifications push (mobile) | `firebase_core`, `firebase_messaging`, `flutter_local_notifications` ; permission `POST_NOTIFICATIONS` (Android 13 et plus) | Mobile | 17/02/27 → 18/02/27 |
| 15.5 | Écran Aide et support | FAQ en accordéon servie par `GET /help/faq/` (modifiable depuis l'admin) | Mobile | 19/02/27 → 22/02/27 |
| 15.6 | Contact support | `url_launcher` : `https://wa.me/<numéro>`, `tel:` support, `mailto:` | Mobile | 23/02/27 |
| 15.7 | Signalement d'un compte, produit ou publication | `Report(target_type, target_id, reason)` ; `POST /api/v1/reports/` ; bouton visible partout | Backend | 16/02/27 → 17/02/27 |
| 15.8 | Corriger le texte sur le numéro | Onboarding et FAQ : « NetBuis n'affiche pas le numéro ; votre téléphone peut le montrer pendant et après l'appel ; sur iPhone il apparaît avant l'appel » | Mobile | 23/02/27 |

## Bloc 16 — Dashboard admin web

Ce bloc construit le tableau de bord web par lequel l'équipe valide les comptes, modère et règle la plateforme ; sans lui, aucune fiche ne devient active. 13 tâches, du 17/02/27 au 22/04/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 16.1 | Choix technique du dashboard | Pages Django (templates) + HTMX + Tailwind compilé, dans l'app `admin_panel` : une seule pile à maintenir | Backend | 17/02/27 |
| 16.2 | Connexion admin et rôles | Groupes Django « Validateur » et « Administrateur complet » ; `AuditLog` (`attribution_role`, `retrait_role`…) ; double authentification TOTP (`django-otp`) | Backend | 18/02/27 → 22/02/27 |
| 16.3 | Page Vue d'ensemble | Indicateurs : comptes, business, appels par jour, revenus, agents ; requêtes agrégées mises en cache | Backend | 22/02/27 → 25/02/27 |
| 16.4 | Page Demandes : comptes business | Dossier avec pièces (URL signées), boutons Valider / Rejeter avec motif, notification à l'utilisateur | Backend | 25/02/27 → 02/03/27 |
| 16.5 | Demandes : candidatures équipe NetBuis | Lecture de la vidéo CNI ; valider / rejeter | Backend | 02/03/27 → 03/03/27 |
| 16.6 | Page Comptes | Filtres (Tous, Simple, Business, Équipe, Bloqués) ; Bloquer / Débloquer / Supprimer | Backend | 04/03/27 → 05/03/27 |
| 16.7 | Page Équipe et abonnements | Agents, primes, abonnements actifs et expirants | Backend | 08/03/27 → 09/03/27 |
| 16.8 | Gestion des zones et référentiels | CRUD `Zone` ; validation des brouillons issus d'OpenStreetMap ; secteurs et sous-catégories | Backend | 10/03/27 → 12/03/27 |
| 16.9 | Modération et signalements | File de revue : masquer, restaurer, bloquer | Backend | 12/03/27 → 16/03/27 |
| 16.10 | Paramètres de la plateforme | `PlatformSetting` : plafonds (3 sous-catégories, 5 publications), quotas d'appels, packs, montant de la prime | Backend | 16/03/27 → 17/03/27 |
| 16.11 | Journal d'audit | Qui a validé ou modifié quoi, avec date ; lecture seule | Backend | 18/03/27 |
| 16.12 | Tests et revue de sécurité du dashboard | CSRF, permissions par rôle, accès aux pièces d'identité uniquement pour les rôles autorisés | Backend | 19/03/27 → 22/03/27 |
| 16.13 | Mise en ligne du dashboard | `admin.netbuis.cm` ; restriction par adresse IP ou VPN ; 2FA obligatoire | Backend | 22/04/27 |

## Bloc 17 — Accessibilité, langues et faible réseau

Ce bloc rend l'application utilisable par des personnes peu lettrées, sur réseau lent et sur téléphone d'entrée de gamme. 7 tâches, du 24/02/27 au 18/03/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 17.1 | Audit d'accessibilité des écrans | Cibles tactiles ≥ 48 dp ; contraste 4,5:1 ; étiquettes `Semantics` ; TalkBack testé | Mobile | 24/02/27 → 25/02/27 |
| 17.2 | Mode pour utilisateurs peu lettrés | Icônes et photos d'abord, boutons larges, audio de guidage (fichiers MP3 pré-enregistrés au lieu d'une voix synthétique) | Mobile | 26/02/27 → 02/03/27 |
| 17.3 | Français et anglais | `flutter_localizations` ; `lib/l10n/app_fr.arb` et `app_en.arb` ; aucun texte en dur | Mobile | 03/03/27 → 04/03/27 |
| 17.4 | Mode économie de données | `connectivity_plus` : images basse résolution par défaut en 2G/3G | Mobile | 05/03/27 → 08/03/27 |
| 17.5 | Cache local et actions différées | `drift` (SQLite) pour les données stables ; `workmanager` pour renvoyer les actions non critiques | Mobile | 08/03/27 → 11/03/27 |
| 17.6 | Budget de performance | APK < 30 Mo (`--split-per-abi`), démarrage < 3 s sur un téléphone 2 Go de RAM ; mesuré à chaque version | Mobile | 11/03/27 → 15/03/27 |
| 17.7 | Test d'usage avec de vrais utilisateurs | 5 à 10 personnes dont des non-lettrés ; observer sans aider ; noter les blocages | Jeff | 15/03/27 → 18/03/27 |

## Bloc 18 — Sécurité, conformité et tests

Ce bloc ferme les risques de sécurité et de conformité avant de montrer l'application au public. 12 tâches, du 04/01/27 au 02/04/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 18.1 | Checklist OWASP Mobile Top 10 2024 | M1 à M10 appliquées par l'agent relecteur ; clés dans l'Android Keystore, jamais dans le code | Backend | 23/03/27 → 24/03/27 |
| 18.2 | Durcissement du réseau mobile | `android:usesCleartextTraffic="false"` ; `network_security_config.xml` ; épinglage de certificat dans `dio` | Mobile | 25/03/27 |
| 18.3 | Obfuscation et protection du binaire | `flutter build appbundle --obfuscate --split-debug-info=build/symbols` ; `minifyEnabled true` (R8) | Mobile | 29/03/27 |
| 18.4 | Durcissement de Django | `SECURE_SSL_REDIRECT`, HSTS, cookies sécurisés, `DEBUG=False` ; `python manage.py check --deploy` sans alerte | Backend | 25/03/27 |
| 18.5 | Audit des dépendances | `pip-audit`, `flutter pub outdated`, Dependabot activé sur les deux dépôts | Backend | 29/03/27 |
| 18.6 | Conformité à la loi camerounaise sur les données (2024/017) | Registre des traitements, consentement, durées de conservation, démarches auprès de l'autorité ; à valider par un juriste local | Jeff | 04/01/27 → 06/01/27 |
| 18.7 | Politique de confidentialité et conditions d'utilisation | Pages publiques `https://netbuis.cm/confidentialite` et `/conditions` (exigées par Google Play) | Jeff | 07/01/27 → 08/01/27 |
| 18.8 | Avis juridique : forum et paiement | Responsabilité d'hébergeur de contenus ; statut si NetBuis envoie des fonds (primes) | Jeff | 11/01/27 → 12/01/27 |
| 18.9 | Tests de charge globaux | Recherche + appel + paiement ensemble ; objectif p95 < 500 ms | Backend | 29/03/27 → 31/03/27 |
| 18.10 | Test d'intrusion léger | OWASP ZAP sur l'API de staging ; correction des alertes moyennes et hautes | Backend | 31/03/27 → 02/04/27 |
| 18.11 | Compatibilité Android 16 | Affichage bord à bord (edge-to-edge), geste retour prédictif, tâches planifiées ; test sur un vrai appareil | Mobile | 30/03/27 → 31/03/27 |
| 18.12 | Relecture humaine des modules sensibles | Jeff relit : authentification, paiement, appel (le goulot de relecture est humain) | Jeff | 30/03/27 → 01/04/27 |

## Bloc 19 — Déploiement du backend en production

Ce bloc met le serveur en production, avec sauvegardes testées en restauration, déploiement automatique et surveillance. 10 tâches, du 06/04/27 au 20/04/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 19.1 | Durcir le serveur | Utilisateur non-root, SSH par clé uniquement, `ufw` (22, 80, 443), `fail2ban`, mises à jour de sécurité automatiques | Backend | 06/04/27 |
| 19.2 | Docker Compose de production | Services `web` (gunicorn), `worker`, `beat`, `redis`, `caddy` ; limites de mémoire | Backend | 07/04/27 → 08/04/27 |
| 19.3 | PostgreSQL de production | PostgreSQL 16, extensions `pg_trgm` et `unaccent`, utilisateur dédié, réglage `shared_buffers` | Backend | 08/04/27 → 09/04/27 |
| 19.4 | HTTPS et domaine | Caddy + Let's Encrypt pour `api.netbuis.cm` ; redirection HTTP → HTTPS | Backend | 09/04/27 |
| 19.5 | Variables d'environnement et secrets | Fichier `.env` hors dépôt, droits 600 ; rotation des clés documentée | Backend | 12/04/27 |
| 19.6 | Déploiement automatisé | `deploy.yml` sur étiquette `v*` : build, envoi au registre, `ssh` + `docker compose pull && up -d`, `migrate`, `collectstatic` ; retour arrière en une commande | Backend | 12/04/27 → 14/04/27 |
| 19.7 | Sauvegardes quotidiennes | `pg_dump` chiffré (`age`) vers `netbuis-backups` ; rétention 7 quotidiennes + 4 hebdomadaires + 3 mensuelles | Backend | 14/04/27 → 15/04/27 |
| 19.8 | Test de restauration complet | Restaurer sur un serveur vierge et chronométrer ; obligatoire avant le lancement | Backend | 16/04/27 |
| 19.9 | Supervision | UptimeRobot sur `/health/` ; alertes par e-mail ; Sentry ; tableau de bord des erreurs | Backend | 19/04/27 |
| 19.10 | Données initiales en production | `migrate`, `load_zones`, `seed_referentials`, `createsuperuser` (premier admin créé à la main) | Backend | 20/04/27 |

## Bloc 20 — Publication sur Google Play

Ce bloc mène l'application de la version signée au test interne, au test fermé obligatoire de 14 jours, puis à la production sur Google Play. 15 tâches et 2 attentes, du 20/10/26 au 25/05/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 20.1 | Finaliser la vérification du compte développeur | Identité, téléphone, appareil Android ; attendre l'e-mail de validation de Google | Jeff | 20/10/26 |
| 20.2 | Choisir le type de compte Play | D'après les sources lues, un compte personnel créé après le 13/11/2023 doit faire un test fermé avec au moins 12 testeurs pendant 14 jours consécutifs ; à vérifier dans la console pour votre compte | Jeff | 21/10/26 |
| 20.3 | Clé d'upload et signature | `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload` ; `android/key.properties` hors dépôt ; activer Play App Signing | Backend | 02/04/27 → 05/04/27 |
| 20.4 | Configuration du build de production | `android/app/build.gradle` : `compileSdk 36`, `targetSdk 36`, `minSdk 24`, `versionCode`, `versionName` ; `flutter build appbundle --release` | Mobile | 06/04/27 → 07/04/27 |
| 20.5 | Icône, bannière et captures d'écran | Icône 512×512 ; image de présentation 1024×500 ; au moins 4 captures de téléphone | Jeff | 15/03/27 → 17/03/27 |
| 20.6 | Fiche du Play Store (français et anglais) | Titre ≤ 30 caractères, description courte ≤ 80, description complète ≤ 4 000 | Jeff | 17/03/27 → 18/03/27 |
| 20.7 | Formulaire « Sécurité des données » | Déclarer : numéro de téléphone, nom, photos, pièces d'identité (prestataires), journal d'activité ; données chiffrées en transit ; suppression possible sur demande | Jeff | 19/03/27 |
| 20.8 | Contenu de l'application et public visé | Questionnaire de classification ; public 18 ans et plus ; déclaration des annonces (aucune) | Jeff | 22/03/27 |
| 20.9 | Déclaration des permissions sensibles | Justification de `CALL_PHONE` et `READ_PHONE_STATE` ; vidéo de démonstration de l'appel si Google la demande | Jeff | 22/03/27 → 23/03/27 |
| 20.10 | Page web de suppression de compte | `https://netbuis.cm/supprimer-mon-compte` ; le lien est demandé dans la console | Backend | 05/04/27 |
| 20.11 | Test interne | Téléverser l'AAB sur la piste « Test interne » ; activer le rapport de pré-lancement ; installer sur 3 téléphones | Mobile | 12/04/27 |
| 20.12 | Recruter au moins 15 testeurs | 12 minimum requis + marge pour les départs ; ajouter leurs e-mails Google à la liste de la piste « Test fermé » | Jeff | 13/04/27 → 14/04/27 |
| 20.13 | Test fermé : 14 jours consécutifs | Garder au moins 12 testeurs inscrits sans interruption ; recueillir les retours ; corriger | Attente | 15/04/27 → 28/04/27 |
| 20.14 | Demande d'accès à la production | Décrire comment le test s'est déroulé, les retours reçus, les changements faits | Jeff | 29/04/27 |
| 20.15 | Revue Google | Compter environ 7 jours calendaires d'après les sources | Attente | 30/04/27 → 07/05/27 |
| 20.16 | Déploiement progressif | Pourcentage croissant : 5 % → 20 % → 50 % → 100 % ; surveiller avant chaque palier | Jeff | 10/05/27 → 14/05/27 |
| 20.17 | Surveillance après publication | Android Vitals (plantages, ANR), Crashlytics, avis des utilisateurs ; correctif rapide si le taux de plantage dépasse 1 % | Jeff | 18/05/27 → 25/05/27 |

## Bloc 21 — Pilote terrain, après le lancement et évolutions

Ce bloc couvre le pilote sur le terrain, la mesure du produit et les évolutions après le lancement (iPhone, Camtel et Nexttel, niveau d'API). 6 tâches, du 02/11/26 au 03/08/27.

| N° | Tâche | Détail technique (code, API, réglages) | Voie | Dates |
| --- | --- | --- | --- | --- |
| 21.1 | Inscrire 30 à 50 commerçants du quartier pilote | Parcours de secours ou QR ; vérifier chaque fiche ; produits avec photos | Jeff | 21/04/27 → 27/04/27 |
| 21.2 | 10 entretiens avec de futurs utilisateurs | Demander le téléphone utilisé ; noter les produits cherchés (alimente les synonymes) ; mesurer le taux de recherche aboutie | Jeff | 02/11/26 → 04/11/26 |
| 21.3 | Mesure du produit | Tableau de bord interne : taux de recherche aboutie, appels utiles (retour oui/non), temps de réponse | Backend | 09/06/27 → 10/06/27 |
| 21.4 | Variante iPhone | Apple Developer (99 USD/an) ; `tel://` via `url_launcher` ; pas de feuille Orange/MTN ; piste CallKit ou WhatsApp pour la suite | Mobile | 15/06/27 → 21/06/27 |
| 21.5 | Camtel et Nexttel | Ajouter les deux lignes à la feuille d'appel si le besoin est confirmé | Backend | 11/06/27 → 15/06/27 |
| 21.6 | Mise à jour annuelle du niveau d'API cible | Google exige un niveau cible plus récent chaque année (API 36 depuis le 31/08/2026) ; prévoir la montée vers le suivant | Mobile | 02/08/27 → 03/08/27 |