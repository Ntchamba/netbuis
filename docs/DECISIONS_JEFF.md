# Décisions et points ouverts — à relire par Jeff

> **Règle pour l'orchestrateur** : une décision « ouverte » ne bloque jamais le travail. On applique la **valeur par défaut** indiquée, on l'écrit dans la colonne « Valeur appliquée », et on la signale à Jeff dans le rapport de la tâche. Jeff peut changer d'avis à tout moment en modifiant ce fichier : l'orchestrateur ouvre alors une tâche corrective.
> Ce fichier **l'emporte** sur `TASKS_PAR_AGENT.md` et `plan-*.md` quand ils se contredisent.

| Id | Sujet | Défaut retenu (recommandé) | Statut | Valeur appliquée |
|---|---|---|---|---|
| D-01 | Jeton de rafraîchissement du **dashboard** | Cookie `HttpOnly` + `SameSite=Lax`, route `POST /api/auth/refresh/` lisant le cookie ; le **mobile** envoie `{"refresh": …}` dans le corps ; jeton d'accès toujours en mémoire côté dashboard | défaut retenu | Cookie HttpOnly + SameSite=Lax (dashboard), corps JSON (mobile) ; appliqué en T007 (T005, 2026-10-11) |
| D-02 | Fournisseur de SMS (code OTP) | Interface `SmsBackend` ; `console_backend` en développement ; fournisseur réel choisi par Jeff (recommandation : API SMS d'Orange, voir `comparatif-fournisseurs-sms-otp-cameroun-netbuis.md` dans le Projet). **Aucune clé n'est demandée avant la fin des tâches sans SMS réel** | défaut retenu | `console_backend` en dev ; fournisseur réel quand Jeff donne la clé (T005, 2026-10-11) |
| D-03 | Quota d'appels gratuits tant que les paiements n'existent pas | **Aucun quota** (`CREDITS_ENABLED=False`) : seule la limite anti-aspiration s'applique. Le code du quota existe derrière l'interrupteur et est testé | décidé par défaut | Aucun quota, `CREDITS_ENABLED=False` (déjà dans `config/settings/base.py`) (T005, 2026-10-11) |
| D-04 | Maquettes contre l'ancien cahier | **Les maquettes l'emportent** : thème sombre/clair, accent orange `#F2942E`, onglets Accueil · Carte · Forum · Profil, forum = fil de publications de commerçants + commentaires, 5 types de compte business, hiérarchie de zones, RBAC. Les « produits très sollicités » sont une **bande sur l'Accueil**, pas un onglet | décidé (Jeff peut s'y opposer) | |
| D-05 | Limites anti-aspiration des numéros | 5 appels / minute et 50 / jour par compte (réglables dans `PlatformSetting`) | valeur d'essai | 5/min, 50/jour, réglables dans `PlatformSetting` (T008b) (T005, 2026-10-11) |
| D-06 | Coordonnées du support (WhatsApp, téléphone, e-mail) | Variables de configuration avec la valeur `À REMPLACER` ; l'e-mail `support@netbuis.cm` des maquettes est **fictif** | à fournir par Jeff | `À REMPLACER` en attendant (T005, 2026-10-11) |
| D-07 | Honnêteté sur le numéro | Textes : « NetBuis n'affiche jamais le numéro. Votre téléphone peut cependant l'afficher pendant l'appel et le garder dans son journal d'appels. Sur iPhone, le système demande une confirmation qui montre le numéro. » à utiliser dans l'Onboarding (2ᵉ diapositive) et la FAQ. iOS : `tel://` avec confirmation système, accepté | décidé | |
| D-08 | Modification d'un compte business déjà validé | Description et photos : sans nouvelle validation. Nom, type, zone, numéro : retour en `en_attente_validation` | valeur par défaut | |
| D-09 | Suppression d'un compte | **Suppression douce**, aussi pour la suppression faite par l'utilisateur lui-même (`DELETE /me/`) ; jamais d'effacement définitif depuis le dashboard ; un numéro supprimé qui se reconnecte reçoit « contactez le support » | décidé (recommandation de la spec) | |
| D-10 | Forme juridique pour le type « Structure » (point X) | Non demandée en v1 | valeur par défaut | |
| D-11 | Seuil d'appels quotidiens qui déclenche la proposition d'abonnement | `10` **uniquement comme valeur technique d'essai** (le Projet précise qu'aucun chiffre n'est choisi) ; réglable dans le dashboard ; Jeff doit le fixer avant la mise en service | à confirmer | 10 (valeur d'essai) (T005, 2026-10-11) |
| D-12 | Plafonds | 3 sous-catégories / rayons / spécialités et 5 publications actives sans abonnement | 3 confirmé, 5 à confirmer | 3 et 5 (T005, 2026-10-11) |
| D-13 | Règle de la carte (point Y) | « Enregistrés » = profil `actif` rattaché à `ville_village` ou `quartier` | interprétation à confirmer | `actif` + `ville_village` ou `quartier` (T005, 2026-10-11) |
| D-14 | Premier administrateur | Créé en ligne de commande (`createsuperuser`) puis `is_admin=True` + groupe « Administrateur complet » ; les autres sont créés depuis le dashboard | décidé | |
| D-15 | Mot de passe PostgreSQL | Uniquement dans `backend/.env` (non versionné) et jamais dans un exemple, un test, un journal, un commit ou une conversation | décidé | |
| D-16 | Reporté | Paiements (CamPay, crédits, abonnements payants, paiements sortants), déploiement, publication Play Store, équipe/parrainage, commandes, notifications push, impression, GPS | décidé | |
| D-17 | Stockage des photos et pièces | Dossier local en développement derrière l'interface `StorageService` ; stockage compatible S3 plus tard. CNI et diplôme : espace privé, URL temporaire pour l'admin seulement | décidé | |
| D-19 | Accueil | Avant toute recherche : les commerces de la ville choisie (abonnés d'abord). Puces = secteurs de l'API. **Pas** de promotion plein écran après une recherche (la maquette en montre trois : jugé intrusif) ; seule la bannière « Aidez NetBuis à grandir » reste. Bouton « Appeler » sans prix tant que `CREDITS_ENABLED=False` | décidé par défaut | |
| D-20 | Contraste du thème clair | Texte/icônes d'accent `#A85A00`, texte secondaire `#6B6B70` en clair ; boutons inchangés | décidé par défaut | |
| D-21 | Lecture vocale (« 🔊 Écouter ») | Synthèse vocale du téléphone (`flutter_tts`) ; sans voix française installée, les boutons sont masqués | décidé par défaut | |
| D-22 | Choix de la ligne Orange/MTN | Redemandé à chaque appel (pas de mémorisation) | décidé par défaut | |
| D-23 | Badge « Abonné » public | Non (point ouvert du Projet) ; l'abonné est seulement placé en premier | décidé par défaut | |
| D-24 | Numéro affiché dans le dashboard | Masqué dans les listes (comme les maquettes) ; complet seulement dans la page de détail, pour l'Administrateur complet | décidé par défaut | |
| D-18 | Numéros de test | Les données de démonstration utilisent `6 00 00 00 XX` et des noms visiblement fictifs | décidé | |

## Données à fournir par Jeff (le projet ne les invente pas)

| Donnée | Utilisée à partir de | En attendant |
|---|---|---|
| Liste des villes/villages et quartiers desservis (au moins Maroua et ses quartiers) | T020 | 4 quartiers vus dans les maquettes |
| Sous-catégories des secteurs non détaillés dans la spec (Pharmacie & Santé, Mode & Beauté, Électronique & Informatique, Immobilier, Agriculture & Élevage) | T021 | « Autre » seulement, signalé « à compléter » |
| Liste de produits du catalogue et synonymes | T021, T040 | petit jeu de départ dans `seed_referentials` |
| Clé du fournisseur SMS | T006 (réel) | console |
| Coordonnées du support | T101 | `À REMPLACER` |
| Textes légaux (conditions, confidentialité) | T100 | texte provisoire `À REMPLACER` |

## Interrupteurs de configuration

| Nom | Défaut | Où il est lu | Effet |
|---|---|---|---|
| `CREDITS_ENABLED` | `False` | backend (`settings`) et `/api/me/` ; mobile via `/me/` | quota d'appels, crédits, prix sur le bouton Appeler : masqués ou inactifs |
| `TEAM_ENABLED` | `False` | backend (`settings`) ; mobile `core/config/feature_flags.dart` (T004) ; dashboard `VITE_TEAM_ENABLED` | équipe NetBuis, parrainage : bannières, onglets, textes masqués |
| `USE_FAKE_API` | `false` | mobile (`--dart-define`) | dépôts factices |
| `VITE_USE_MOCKS` | `false` | dashboard | données factices |

Un statut **« ouvert »** signifie : Jeff n'a pas répondu, le défaut s'applique et reste modifiable. **« décidé par défaut »** : choix de l'orchestrateur, modifiable. **« décidé »** : choix de Jeff ou imposé par un document du Projet.
