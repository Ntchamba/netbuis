# Veille : API et projets GitHub gratuits (addenda)

> Regroupement automatique (2026-10-17) de 230 fichiers de veille produits par les routines du Projet Claude, du plus ancien au plus récent. Historique seulement : en cas de contradiction, `docs/DECISIONS_JEFF.md` et `docs/BACKLOG.md` font foi.


---

<!-- source : recherche-apis-github-addendum-2-2026-10-06-netbuis.md -->

# Addendum 2 : APIs et dépôts GitHub (2026-10-06, passage 2) — NetBuis

Complète v2, v3 et l'addendum du jour. [S] = page lue ; [N] = non vérifié. Aucune décision existante ne change (CamPay REST direct, Django + pg_trgm/PostGIS, tel: et wa.me, MapLibre, FCM, forum natif).

## 1. TranZak : vérifié (repli de paiement)

- Documentation lue : API de **collecte** (demande de paiement avec redirection web, ou **débit direct mobile money MTN Cameroun et Orange Money Cameroun**) et **décaissement** (virements) [S].
- Authentification par jeton bearer (`/auth/token`) ; **sandbox séparé** (`sandbox.dsapi.tranzak.me`, clés `SAND_` / `PROD_`) ; **webhooks** `REQUEST.COMPLETED` et `TRANSFER.COMPLETED` avec clé de vérification [S].
- Frais : déduits au règlement, montants non lus (page partiellement lue : 17 000 caractères restants) ; paiements sortants en multiples de 10 XAF [S].
- Verdict : **bon candidat de repli** derrière l'interface `PaymentProvider`, même modèle que CamPay (REST + webhook), donc intégrable en un adaptateur. À faire : lire la page de tarifs (`tranzak.net/pricing`), l'agrément et les conditions de compte marchand [N].

## 2. Cartes hors ligne : fichier Cameroun

- Protomaps : planète complète ≈ **120 Go** (zooms 0-15), licence ODbL avec attribution OpenStreetMap ; extraction régionale avec l'outil `pmtiles extract` (région + option `--maxzoom`, chaque zoom supplémentaire double environ la taille) [S].
- Conséquence : produire **un PMTiles Cameroun** à zoom max 14 environ, l'héberger sur Cloudflare R2 (sortie gratuite) ; mesurer la taille réelle avant de promettre le hors-ligne [N : taille non confirmée].

## 3. Paiement : repères du marché (PayAtlas)

Frais typiques 2,5 à 4 % par transaction ; sortants 500 à 2 000 XAF ; onboarding 4 à 8 semaines (KYC en français, immatriculation locale préférée) ; CinetPay et PayDunya couvrent MTN/Orange [S, source secondaire]. À retenir : **lancer la démarche KYC de CamPay et de TranZak en parallèle dès maintenant**, car le délai est le vrai goulot, pas le code.

## 4. SMS / OTP

Africa's Talking, Plivo, Boxis, eSMS Africa et l'API SMS Orange Cameroun existent ; les tarifs Cameroun n'ont pas pu être lus (pages non détaillées) [N]. Décision inchangée : Nexah principal ; essai réel MTN + Orange avant tout autre repli. Piste à tester : API SMS d'Orange (developer.orange.com/apis/sms-cm), mais limitée à son réseau pour la variante « Orange only ».

## 5. Modèles de départ GitHub (lecture seule)

Marketplaces localisées trouvées (UWU-Group12 location-based-service-marketplace, openflutterecommerceapp, rhmni/marketplace Django) : projets étudiants ou génériques, sans licence ni maintenance vérifiées. **Aucun à adopter** ; utiles seulement comme exemples de structure. Rien de mûr pour « annuaire de commerçants + appel direct ».

## 6. Ordre le plus rapide

1. Ouvrir les dossiers KYC CamPay + TranZak (délai 4-8 semaines).
2. Django + `pg_trgm`/PostGIS + `django-phonenumber-field` + OTP Nexah.
3. `url_launcher` (`tel:` et `wa.me`), `flutter-maplibre-gl` + PMTiles Cameroun sur R2.
4. FCM + Crashlytics ; R2 + `django-storages` pour les photos.
5. Voix (`speech_to_text`, `flutter_tts`) après tests terrain.

## Sources
- [TranZak (API Evangelist)](https://github.com/api-evangelist/tranzak)
- [API Reference Tranzak](https://docs.developer.tranzak.me/)
- [Tarifs Tranzak](https://test.tranzak.me/pricing/)
- [Protomaps : téléchargements](https://docs.protomaps.com/basemaps/downloads)
- [PayAtlas Cameroun](https://payatlas.com/countries/cameroon-cm)
- [Africa's Talking](https://africastalking.com/pricing)
- [SMS Cameroun Orange](https://developer.orange.com/apis/sms-cm)
- [location-based-service-marketplace](https://github.com/UWU-Group12/location-based-service-marketplace)


---

<!-- source : recherche-apis-github-addendum-3-2026-10-06-netbuis.md -->

# Addendum 3 : APIs et dépôts GitHub gratuits (2026-10-06, passage 3, exécution planifiée) — NetBuis

Complète v2, v3, addendum et addendum 2. [S] = page lue ; [N] = non vérifié (résultat de recherche seulement). Aucune décision existante ne change (CamPay REST direct, Django + pg_trgm/PostGIS, tel: et wa.me, MapLibre, FCM, forum natif).

## 1. Paiement : zignpay (nouveau, à surveiller seulement)

- `kevelino/zignpay` : paquet Python, licence MIT, « API unifiée MTN MoMo + Orange Money » pour le Cameroun (collectes), `pip install zignpay`, Python 3.10+ [S].
- Maturité très faible : 8 commits, 0 étoile, 2 forks, documentation « en cours d'amélioration », date du dernier commit non affichée [S]. Appelle directement les API MTN/Orange (pas CamPay) [S].
- Verdict : **ne pas adopter** comme dépendance de production. Utile comme exemple de code pour l'adaptateur `PaymentProvider`. Les autres SDK trouvés (lepresk/momo-api PHP, Foris-master/mtn-mobile-money-sdk PHP, aipd506/mobile-money Stellar) ne sont pas dans notre pile (Django) ou hors sujet [N].

## 2. WhatsApp : Evolution API (alternative, risque)

- `EvolutionAPI/evolution-api` : ~9,8 k étoiles, Apache 2.0 avec clause de marque (conserver le logo, prévenir l'auteur) [S]. Deux modes : **Baileys (non officiel, gratuit, risque de bannissement du numéro)** et **Cloud API officielle Meta (frais par message possibles)** [S]. Autres passerelles : OpenWA (auto-hébergée, non officielle) [N].
- Verdict : pour NetBuis, **rester sur `wa.me` (lien, gratuit, aucun risque)**. N'utiliser Evolution/OpenWA qu'en mode Cloud API officielle si l'on veut un jour des messages automatiques ; **jamais Baileys sur le numéro principal** (risque de bannissement, conforme à nos audits précédents).

## 3. Recherche et géocodage

- Typesense (alternative open source à Algolia, tolérante aux fautes, en mémoire) et Meilisearch existent ; comparatif 2026 disponible [N, titres lus seulement]. Photon (Komoot, géocodeur OSM avec recherche à la frappe) existe [N].
- Verdict : **inchangé**, PostgreSQL `pg_trgm` + PostGIS suffisent au démarrage (un seul service). Typesense seulement si la recherche devient lente au-delà de ~100 k produits. Photon/Nominatim seulement si l'on a besoin de chercher des quartiers par nom.

## 4. Ordre le plus rapide (inchangé)

1. Dossiers KYC CamPay + TranZak en parallèle (4-8 semaines : vrai goulot).
2. Django + `pg_trgm`/PostGIS + OTP Nexah.
3. `url_launcher` (`tel:`, `wa.me`) + MapLibre + PMTiles Cameroun sur R2.
4. FCM + Crashlytics ; voix après tests terrain.

## Sources
- [zignpay](https://github.com/kevelino/zignpay)
- [Evolution API](https://github.com/EvolutionAPI/evolution-api)
- [OpenWA](https://github.com/rmyndharis/OpenWA)
- [GitHub topic mtn-momo](https://github.com/topics/mtn-momo)
- [GitHub topic orange-money](https://github.com/topics/orange-money)
- [Photon](https://github.com/komoot/photon)
- [Typesense](https://github.com/typesense/typesense)
- [Meilisearch vs Typesense 2026](https://apiscout.dev/guides/meilisearch-vs-typesense-api-2026)


---

<!-- source : recherche-apis-github-addendum-4-2026-10-06-netbuis.md -->

# Addendum 4 : APIs et dépôts GitHub gratuits (2026-10-06, passage 4, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 3. [S] = page lue ; [N] = non vérifié (résultat de recherche seulement). Aucune décision existante ne change.

## Résultat : rien de nouveau qui justifie un changement

Les recherches de ce passage (SDK mobile money Cameroun, apps Flutter open source de marketplace/annuaire, forums open source, passerelles SMS/OTP Afrique) ne font ressortir que des éléments déjà évalués ou hors pile.

## 1. Paiement (inchangé)
- Les sujets GitHub `mtn-momo`, `orange-money`, `mtn-mobile-money` ne montrent que des SDK PHP/Python peu mûrs (zignpay, lepresk/momo-api, aipd506/mobile-money) déjà jugés dans l'addendum 3 [N]. Décision : **CamPay REST direct** derrière l'interface `PaymentProvider`.

## 2. Forum : Discourse écarté
- `discourse/discourse` : GPL-2.0, ~47,9 k étoiles, actif en 2026, API REST JSON [S]. Mais pile Ruby 3.4 + PostgreSQL 15 + Redis 7 : un service lourd en plus de Django, serveur à gérer pour peu de gain. Des alternatives open source existent (liste comparative 2026) [N].
- Verdict : **garder le forum natif** (tables Django + FCM), plus léger et intégré à l'app. Discourse seulement si le forum devient un produit à part entière avec modération avancée.

## 3. Exemples Flutter
- `fluttergems/awesome-open-source-flutter-apps` : liste d'apps open source (POS, chat, contacts) ; aucune marketplace de commerçants locaux directement réutilisable [S, 100 000 premiers caractères sur 148 000]. `4seer/openflutterecommerceapp` (e-commerce générique) [N]. Utiles comme **inspiration d'interface seulement**, pas de dépendance.

## 4. SMS/OTP
- Africa's Talking (SDK officiels sur GitHub) et passerelles « free SMS » existent ; les services gratuits d'OTP sont peu fiables et risqués [N]. Verdict : **rester sur Nexah** (déjà décidé) ; Africa's Talking en secours si la couverture Cameroun est confirmée.

## 5. Ordre le plus rapide (inchangé)
1. KYC CamPay + TranZak en parallèle (goulot réel).
2. Django + `pg_trgm`/PostGIS + OTP Nexah.
3. `url_launcher` (`tel:`, `wa.me`) + MapLibre + PMTiles.
4. FCM + Crashlytics ; voix après tests terrain.

## Sources
- [mtn-momo topic](https://github.com/topics/mtn-momo)
- [orange-money topic](https://github.com/topics/orange-money)
- [zignpay](https://github.com/kevelino/zignpay)
- [Discourse](https://github.com/discourse/discourse)
- [Discourse alternatives 2026](https://openalternative.co/alternatives/discourse)
- [awesome-open-source-flutter-apps](https://github.com/fluttergems/awesome-open-source-flutter-apps)
- [openflutterecommerceapp](https://github.com/4seer/openflutterecommerceapp)
- [Africa's Talking GitHub](https://github.com/AfricasTalkingLtd)


---

<!-- source : recherche-apis-github-addendum-5-2026-10-06-netbuis.md -->

# Addendum 5 : APIs et dépôts GitHub gratuits (2026-10-06, passage 5, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 4. [S] = page lue ; [N] = résultat de recherche seulement. Aucune décision existante ne change.

## Résultat : une option de recherche à noter, le reste est confirmé

### 1. Moteur de recherche produit (barre de recherche) : Meilisearch en option
- `meilisearch/meilisearch` : licence MIT (édition Enterprise séparée en BSL 1.1), ~59,2 k étoiles, tolérance aux fautes de frappe, filtre/tri géographique, Docker fourni [S].
- Typesense est l'alternative équivalente (en mémoire, tolérante aux fautes) [N].
- Verdict : la décision actuelle reste **PostgreSQL `pg_trgm` + PostGIS** (un seul service). Passer à Meilisearch seulement si le catalogue dépasse environ quelques centaines de milliers de produits ou si la pertinence devient insuffisante. Gratuit, mais un service de plus à héberger.

### 2. Géocodage / recherche d'adresses : Photon écarté pour l'auto-hébergement
- `komoot/photon` : Apache-2.0, ~3,1 k étoiles, géocodeur OSM [S]. Auto-hébergement : Java 21+, ~95 Go de disque et 64 Go de RAM conseillés (base mondiale) : **inutilisable sur un petit serveur**.
- Le serveur de démonstration `photon.komoot.io` est limité (« usage extensif throttlé ou banni, aucune garantie ») : acceptable en prototype, pas en production [S].
- Verdict : garder **MapLibre + PMTiles** pour la carte, et la position du commerçant saisie par GPS à l'inscription (pas de géocodage de masse). Pour une saisie d'adresse occasionnelle : Nominatim public avec cache, ou paquets Flutter `location_picker_flutter_map` / `flutter_location_search` (OSM) [N].

### 3. Paiement mobile money (inchangé)
- Les sujets GitHub `mobile-money`, `mtn-momo` ne montrent toujours que des clients peu mûrs : `kevelino/zignpay` (Python, Cameroun MTN/Orange), `lepresk/momo-api` (PHP), `pixels26/mobile-money` (backend Stellar, hors besoin) [N]. Décision maintenue : **CamPay REST direct** derrière `PaymentProvider`.

### 4. Géolocalisation mobile
- Paquet `geolocator` (pub.dev) pour la position de l'utilisateur, déjà dans la pile [N].

## Ordre le plus rapide (inchangé)
1. KYC CamPay + TranZak en parallèle (vrai goulot).
2. Django + `pg_trgm`/PostGIS + OTP Nexah.
3. `url_launcher` (`tel:`, `wa.me`) + MapLibre + PMTiles.
4. FCM + Crashlytics ; voix après tests terrain.

## Sources
- [Meilisearch](https://github.com/meilisearch/meilisearch)
- [Typesense](https://github.com/typesense/typesense)
- [Meilisearch vs Typesense 2026](https://apiscout.dev/guides/meilisearch-vs-typesense-api-2026)
- [Photon](https://github.com/komoot/photon)
- [location_picker_flutter_map](https://github.com/Michael-M-aher/location_picker_flutter_map)
- [flutter_location_search](https://github.com/KomInc/flutter_location_search)
- [geolocator](https://pub.dev/packages/geolocator)
- [mobile-money topic](https://github.com/topics/mobile-money?o=asc&s=stars)
- [zignpay](https://github.com/kevelino/zignpay)
- [lepresk/momo-api](https://github.com/lepresk/momo-api)


---

<!-- source : recherche-apis-github-addendum-6-2026-10-06-netbuis.md -->

# Addendum 6 : APIs et dépôts GitHub gratuits (2026-10-06, passage 6, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 5. [S] = page lue ; [N] = résultat de recherche seulement. **Aucune décision existante ne change.**

## Résultat : rien de nouveau qui change le plan

### 1. Paiement mobile money (Cameroun)
Les recherches GitHub (`mtn-momo`, `orange-money`, `mobile-money`) renvoient les mêmes dépôts que l'addendum 5 : `kevelino/zignpay` (Python, MTN/Orange Cameroun, peu mûr), et des copies d'un backend Stellar hors besoin [N]. La page du sujet `orange-money` a renvoyé une erreur 429 (non lue). Décision maintenue : CamPay REST derrière `PaymentProvider`.

### 2. Forum : options open source (déjà un module prévu, à confirmer)
Alternatives à Discourse listées par OpenAlternative [S] : **Apache Answer** (Q&R, API REST + webhooks), **Flarum** (léger, extensible), **Storyden** (forum moderne, API complète). Licences et étoiles non précisées sur la page : à vérifier avant tout choix. Pour aller vite, la décision actuelle (forum natif simple dans le backend Django : sujets, réponses, modération) reste la plus rapide ; ces projets ne deviennent utiles que si l'on veut un forum prêt à l'emploi à intégrer par API.

### 3. Applications marketplace Flutter de référence
`4seer/openflutterecommerceapp` et les sujets `ecommerce-app` / `flutter-market` donnent des modèles d'interface (catalogue, fiche produit, panier) [N]. Utiles comme inspiration d'écrans uniquement ; aucun ne couvre recherche par commerçants locaux + appel direct.

### 4. WhatsApp / appel
Paquet pub.dev `whatsapp` apparu dans les résultats [N] : inutile, `url_launcher` (`tel:`, `wa.me`) couvre déjà le besoin gratuitement.

## Ordre le plus rapide (inchangé)
1. KYC CamPay + TranZak en parallèle (vrai goulot).
2. Django + `pg_trgm`/PostGIS + OTP Nexah.
3. `url_launcher` + MapLibre + PMTiles.
4. FCM + Crashlytics ; voix après tests terrain.

## Sources
- [Discourse alternatives (OpenAlternative)](https://openalternative.co/alternatives/discourse)
- [openflutterecommerceapp](https://github.com/4seer/openflutterecommerceapp)
- [ecommerce-app topic](https://github.com/topics/ecommerce-app)
- [mtn-momo topic](https://github.com/topics/mtn-momo)
- [zignpay](https://github.com/kevelino/zignpay)
- [whatsapp (pub.dev)](https://pub.dev/packages/whatsapp)


---

<!-- source : recherche-apis-github-addendum-7-2026-10-06-netbuis.md -->

# Addendum 7 : APIs et dépôts GitHub gratuits (2026-10-06, passage 7, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 6. [S] = page lue ; [N] = résultat de recherche seulement. **Aucune décision existante ne change.**

## Seule nouveauté : SDK Flutter Notch Pay
- `BorisGautier/flutter_notchpay` [S] : licence MIT, version 0.1.0, 1 étoile, 0 fork (très peu mûr). Paiement mobile money (MTN, Orange, Moov, Wave, Airtel) + carte, détection automatique de l'opérateur, FR/EN, clé publique seule dans l'app (méthodes à clé privée refusées côté mobile : bon réflexe sécurité). Disponible sur pub.dev (`flutter_notchpay`).
- Verdict : utile comme **plan B** de collecte si CamPay tarde (KYC) ; Notch Pay est déjà noté comme secours dans les addenda paiement. Ne pas en dépendre : SDK d'un seul auteur, version 0.1.0. Garder l'appel d'API côté backend Django derrière `PaymentProvider` ; le SDK ne servirait qu'à l'écran de paiement.

## Autres résultats (déjà connus ou sans intérêt)
- `lepresk/momo-api` (client PHP MTN/Airtel) : hors stack (Django) [N].
- Cartographie : `awesome-flutter-map` et `flutter_map` [N] confirment l'option MapLibre/flutter_map déjà retenue ; rien de nouveau.
- Sujets GitHub `cameroon`, `mobile-money`, `mobile-money-api` : mêmes dépôts que les passages précédents [N].

## Ordre le plus rapide (inchangé)
1. KYC CamPay + TranZak en parallèle (vrai goulot).
2. Django + `pg_trgm`/PostGIS + OTP Nexah.
3. `url_launcher` + MapLibre + PMTiles.
4. FCM + Crashlytics ; voix après tests terrain.

## Sources
- [flutter_notchpay](https://github.com/BorisGautier/flutter_notchpay)
- [mobile-money-api topic](https://github.com/topics/mobile-money-api)
- [lepresk/momo-api](https://github.com/lepresk/momo-api)
- [awesome-flutter-map](https://github.com/josxha/awesome-flutter-map)


---

<!-- source : recherche-apis-github-addendum-8-2026-10-06-netbuis.md -->

# Addendum 8 : APIs et dépôts GitHub gratuits (2026-10-06, passage 8, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 7. [S] = page lue ; [N] = résultat de recherche seulement. **Aucune décision existante ne change.**

## Deux dépôts nouveaux, aucun n'est à adopter
- `kevelino/zignpay` [S] : paquet Python, MIT, 0 étoile, 2 forks, documentation « en cours ». API unifiée de collecte MTN MoMo + Orange Money au Cameroun, qui appelle directement les API officielles (clés du portail développeur MTN). Intéressant comme **exemple de code** pour notre adaptateur `PaymentProvider` Django (structure collecte/statut). Trop immature pour en dépendre ; CamPay reste le choix (décision-campay).
- `agus-works/agus-maps-flutter` [S] : widget Flutter de carte hors ligne (CoMaps/OSM, rendu C++ via FFI), Apache 2.0, 15 étoiles, v0.1.17, preuve de concept ; couverture Cameroun non documentée. Alternative à surveiller seulement ; MapLibre + PMTiles reste retenu.

## Déjà connus / sans intérêt
- `maplibre/flutter-maplibre-gl` (PMTiles, régions hors ligne) [N] : confirme le choix existant.
- Sujets GitHub `mtn-momo`, `orange-money`, `mobile-money` [N] : dépôts génériques ou hors stack (Stellar, PHP), rien d'utilisable de plus.

## Ordre le plus rapide (inchangé)
1. KYC CamPay + TranZak en parallèle (vrai goulot).
2. Django + `pg_trgm`/PostGIS + OTP Nexah.
3. `url_launcher` + MapLibre + PMTiles.
4. FCM + Crashlytics ; voix après tests terrain.

## Sources
- [zignpay](https://github.com/kevelino/zignpay)
- [agus-maps-flutter](https://github.com/agus-works/agus-maps-flutter)
- [flutter-maplibre-gl](https://github.com/maplibre/flutter-maplibre-gl)
- [mtn-momo topic](https://github.com/topics/mtn-momo)


---

<!-- source : recherche-apis-github-addendum-9-2026-10-06-netbuis.md -->

# Addendum 9 : APIs et dépôts GitHub gratuits (2026-10-06, passage 9, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 8. [N] = résultat de recherche seulement. **Aucune décision existante ne change. Rien de réellement nouveau.**

## Résultats
- Sujets GitHub `mtn-momo`, `orange-money`, `mobile-money-payment`, `cameroon` [N] : mêmes dépôts que l'addendum 8 (zignpay, clients PHP/npm génériques `lepresk/momo-api`, `ogwok/mtn-momo`, `Chipdeals/Momo-Api`, pont Stellar). Rien d'adoptable ; CamPay reste le choix.
- `rmyndharis/OpenWA` et WAHA (passerelles WhatsApp auto-hébergées, non officielles) [N] : **à ne pas utiliser** (risque de bannissement du numéro, contraire aux CGU WhatsApp). On garde le lien officiel `wa.me` via `url_launcher` (gratuit, sans API).
- `fluttergems/awesome-open-source-flutter-apps` [N] : liste utile pour piocher des exemples d'UI (recherche, forum), pas une dépendance.

## Ordre le plus rapide (inchangé)
1. KYC CamPay + TranZak en parallèle (vrai goulot).
2. Django + `pg_trgm`/PostGIS + OTP Nexah.
3. `url_launcher` (tel:, wa.me) + MapLibre + PMTiles.
4. FCM + Crashlytics ; voix après tests terrain.

## Sources
- [mtn-momo topic](https://github.com/topics/mtn-momo)
- [zignpay](https://github.com/kevelino/zignpay)
- [OpenWA](https://github.com/rmyndharis/OpenWA)
- [awesome-open-source-flutter-apps](https://github.com/fluttergems/awesome-open-source-flutter-apps)


---

<!-- source : recherche-apis-github-addendum-10-2026-10-06-netbuis.md -->

# Addendum 10 : APIs et dépôts GitHub gratuits (2026-10-06, passage 10, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 9. [N] = résultat de recherche seulement. **Aucune décision existante ne change. Rien de réellement nouveau.**

## Résultats
- Sujets GitHub `cameroon`, `mobile-money`, `mobile-money-api`, `mtn-mobile-money` [N] : mêmes types de dépôts que les addenda 8 et 9 (clients génériques, plugin `mycosoft/Mobile-Money-Flutter-wave` lié à Flutterwave, non adapté au Cameroun). Rien d'adoptable ; CamPay reste le choix.
- `bigdatacloudapi/flutter-reverse-geocode-client` [N] : géocodage inverse gratuit sans clé (GPS + repli IP). Utile en secours pour afficher la ville/quartier de l'utilisateur ; à vérifier (conditions d'usage gratuit) avant adoption. Sinon, `geolocator` (pub.dev) suffit.
- `mikemwai/localbiz`, `UWU-Group12/location-based-service-marketplace` [N] : exemples Flutter d'annuaire local / marketplace géolocalisée, à consulter pour l'UI uniquement, pas des dépendances.
- Comparatif « 6 Best Local Business Data APIs 2026 » (scrapfly) [N] : APIs payantes/scraping, inutiles car les commerçants NetBuis sont inscrits dans notre propre base.

## Ordre le plus rapide (inchangé)
1. KYC CamPay + TranZak en parallèle (vrai goulot).
2. Django + `pg_trgm`/PostGIS + OTP Nexah.
3. `url_launcher` (tel:, wa.me) + MapLibre + PMTiles.
4. FCM + Crashlytics ; voix après tests terrain.

## Sources
- [cameroon topic](https://github.com/topics/cameroon?o=asc&s=stars)
- [mobile-money-api topic](https://github.com/topics/mobile-money-api)
- [flutter-reverse-geocode-client](https://github.com/bigdatacloudapi/flutter-reverse-geocode-client)
- [localbiz](https://github.com/mikemwai/localbiz)
- [location-based-service-marketplace](https://github.com/UWU-Group12/location-based-service-marketplace)
- [Best Local Business Data APIs 2026](https://scrapfly.io/blog/posts/best-local-business-data-apis)


---

<!-- source : recherche-apis-github-addendum-11-2026-10-06-netbuis.md -->

# Addendum 11 : APIs et dépôts GitHub gratuits (2026-10-06, passage 11, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 10. [N] = résultat de recherche seulement. **Aucune décision ne change.**

## Résultats
- Paquet PyPI `campay` (client Python CamPay) [N] : utilisable côté Django pour gagner du temps, à relire (code court) avant adoption ; l'API REST CamPay reste la référence.
- Packagist `camerpay/php-sdk`, `ekolotech/mobilemoney-gateway` [N] : PHP/Laravel, hors stack (Django) ; inutile.
- Paquets pub.dev `whatsapp` [N] : ciblent l'API Cloud WhatsApp (payante par conversation) ; inutile, `url_launcher` + `wa.me` suffit et reste gratuit.
- Comparatif « Top 10 WhatsApp API Solutions in Africa 2026 » [N] : solutions payantes, hors besoin.

## Ordre le plus rapide (inchangé)
1. KYC CamPay + TranZak en parallèle.
2. Django + `pg_trgm`/PostGIS + OTP Nexah (+ `campay` PyPI en option).
3. `url_launcher` (tel:, wa.me) + MapLibre + PMTiles.
4. FCM + Crashlytics.

## Sources
- [campay (PyPI)](https://pypi.org/project/campay)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [whatsapp (pub.dev)](https://pub.dev/packages/whatsapp)
- [Top 10 WhatsApp API Africa 2026](https://chakrahq.com/article/top-10-whatsapp-api-solutions-in-africa-2026/)


---

<!-- source : recherche-apis-github-addendum-12-2026-10-06-netbuis.md -->

# Addendum 12 : APIs et dépôts GitHub gratuits (2026-10-06, passage 12, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 11. [N] = résultat de recherche seulement. **Aucune décision ne change.**

## Résultats
- `mtn_momo_sdk` (pub.dev) [N] : client Dart/Flutter pour MTN MoMo ; à éviter côté mobile (clés secrètes), la collecte reste côté Django via CamPay/TranZak.
- `elgiopay-php-sdk`, `camerpay/php-sdk`, `pay_unit_sdk` [N] : PHP ou agrégateurs hors stack ; inutiles.
- `flutter_photon` 1.2.0 et `flutter_nominatim` [N] : clients de géocodage OSM (Photon/Nominatim) ; option légère pour l'autocomplétion de quartiers, à héberger soi-même ou à usage faible (quotas du serveur public).
- `free_map` 2.5.0 [N] : alternative OSM sans clé ; MapLibre + PMTiles reste le choix retenu.

## Ordre le plus rapide (inchangé)
1. KYC CamPay + TranZak en parallèle.
2. Django + `pg_trgm`/PostGIS + OTP Nexah.
3. `url_launcher` (tel:, wa.me) + MapLibre + PMTiles.
4. FCM + Crashlytics.

## Sources
- [mtn_momo_sdk](https://pub.dev/documentation/mtn_momo_sdk/0.0.1/)
- [flutter_photon](https://pub.dev/packages/flutter_photon)
- [free_map](https://pub.dev/packages/free_map)
- [campay (PyPI)](https://pypi.org/project/campay)


---

<!-- source : recherche-apis-github-addendum-13-2026-10-06-netbuis.md -->

# Addendum 13 : APIs et dépôts GitHub gratuits (2026-10-06, passage 13, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 12. [N] = résultat de recherche seulement. **Aucune décision ne change.**

## Résultats
- `django-momoapi` (GitHub mwanjajoel, PyPI) [N] : wrapper Django pour l'API MTN MoMo (sandbox). Utile pour tester vite côté Django ; en production Cameroun, la collecte reste via CamPay/TranZak.
- `django-mobile-money` (readthedocs) [N] : bibliothèque Django multi-opérateurs ; à évaluer, maintenance non vérifiée.
- `camerpay/php-sdk` [N] : PHP, hors stack.
- Recherche « Flutter marketplace/commerçants locaux » : uniquement des templates e-commerce génériques (marketky, uShop, hotdeals) [N], utiles comme inspiration UI seulement, pas de nouvelle API.

## Conclusion
Rien de nouveau qui change le plan. Ordre le plus rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics.

## Sources
- [django-momoapi](https://github.com/mwanjajoel/django-momoapi)
- [django-mobile-money](https://django-mobile-money.readthedocs.io)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [marketky](https://github.com/mrezkys/marketky)


---

<!-- source : recherche-apis-github-addendum-14-2026-10-06-netbuis.md -->

# Addendum 14 : APIs et dépôts GitHub gratuits (2026-10-06, passage 14, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 13. [N] = résultat de recherche seulement. **Aucune décision ne change.**

## Résultats
- `campay` (PyPI 1.0.1), `camerpay/php-sdk`, `lepresk/momo-api` v1.2.0 (PHP), `ekolotech/mobilemoney-gateway`, `elgiopay php-sdk` [N] : déjà connus ou hors stack (PHP). Pour Django : campay (PyPI) reste le plus direct.
- Article kolonell « MTN MoMo API Ghana / Côte d'Ivoire 2026 » [N] : pas de Cameroun, pas d'impact.
- Twilio « WhatsApp Business Calling » [N] : confirme que l'appel WhatsApp via Twilio est une offre payante ; l'appel direct gratuit reste url_launcher (tel:, wa.me).
- Templates annuaire Flutter (listplace sur CodeCanyon, payant ; digidirectory) [N] : inspiration UI seulement.

## Conclusion
Rien de nouveau. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics.

## Sources
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)
- [lepresk/momo-api](https://phpfreaks.com/news/20216)
- [Twilio WhatsApp Business Calling](https://www.twilio.com/en-us/voice/whatsapp-business-calling)
- [kolonell MoMo 2026](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)


---

<!-- source : recherche-apis-github-addendum-15-2026-10-06-netbuis.md -->

# Addendum 15 : APIs et dépôts GitHub gratuits (2026-10-06, passage 15, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 14. [N] = résultat de recherche seulement. **Aucune décision ne change.**

## Résultats
- `campay` (PyPI), `camerpay/php-sdk`, `ekolotech/mobilemoney-gateway`, `elgiopay php-sdk` [N] : déjà connus ou hors stack (PHP).
- `pay_unit_sdk` 3.0.1 (pub.dev, Flutter) [N] : SDK Flutter pour PayUnit (agrégateur Cameroun, MTN/Orange). Alternative à étudier si KYC CamPay/TranZak est lent ; frais à vérifier avant adoption.
- `lengopay_flutter` 1.3.0 [N] : agrégateur RDC/Afrique centrale, hors Cameroun, pas d'impact.
- `flutter_nominatim`, `geodb_flutter` [N] : géocodage OSM / villes. Utile en secours pour recherche de lieux, mais MapLibre + PostGIS reste le choix.

## Conclusion
Seule piste marginale : `pay_unit_sdk` comme 3e option de paiement. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics.

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [pay_unit_sdk](https://depscope.dev/pkg/pub/pay_unit_sdk)
- [lengopay_flutter](https://pub-web-s1.flutter-io.cn/packages/lengopay_flutter/license)
- [flutter_nominatim](https://fluttergems.dev/packages/flutter_nominatim/)


---

<!-- source : recherche-apis-github-addendum-16-2026-10-06-netbuis.md -->

# Addendum 16 : APIs et dépôts GitHub gratuits (2026-10-06, passage 16, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 15. [N] = résultat de recherche seulement. **Aucune décision ne change.**

## Résultats
- Recherche « marketplace Flutter commerçants locaux + appel + WhatsApp + Mobile Money Cameroun » : rien de nouveau (paquets pub.dev `whatsapp` 4.x, déjà couverts par url_launcher/wa.me) [N].
- Recherche « MTN MoMo / Orange Money sandbox SDK 2026 » : `mtn-momo-sdk` 0.1.5 (PyPI), un SDK open source React Native/TypeScript MTN MoMo (dev.to), et des guides kolonell.com (frais Orange Money vs MTN MoMo Cameroun 2026, intégration API) [N]. Tous redondants avec les addenda précédents ; les guides de frais sont à recouper avec les sources officielles avant toute décision.

## Conclusion
Aucune nouvelle piste. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle (PayUnit en option), Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics.

## Sources
- [mtn-momo-sdk PyPI](https://pypi.org/project/mtn-momo-sdk/0.1.5/)
- [SDK MTN MoMo React Native (dev.to)](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [Orange Money vs MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)


---

<!-- source : recherche-apis-github-addendum-17-2026-10-06-netbuis.md -->

# Addendum 17 : APIs et dépôts GitHub gratuits (2026-10-06, passage 17, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 16. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Recherche « Cameroun mobile money Flutter marketplace GitHub » : seulement des index génériques (ecosyste.ms, collectif OSS Cameroon, paquet pub.dev flutterwave). Rien de nouveau pour CamPay/TranZak/PayUnit [N].
- Recherche « alternative à Twilio voix, Afrique, open source » : Fonoster (alternative open source à Twilio, auto-hébergeable, SIP/voix programmable), alternatives à Africa's Talking Voice (helloduty), liste ossalt « best open source alternatives to twilio 2026 », topic GitHub programmable-voice [N]. Piste de repli éventuelle si Twilio est trop coûteux ou limité au Cameroun, mais auto-hébergement = charge d'exploitation ; l'appel direct via url_launcher (tel:) reste la voie rapide et gratuite.

## Conclusion
Aucune nouvelle piste à adopter. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle (PayUnit en option), Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster noté comme plan B voix.

## Sources
- [Fonoster README](https://cdn.jsdelivr.net/gh/fonoster/fonoster@main/README.md)
- [Alternatives open source à Twilio 2026](https://ossalt.com/guides/best-open-source-alternatives-to-twilio-2026)
- [Alternatives Africa's Talking Voice](https://helloduty.com/blogs/africas-talking-voice-api-alternatives-kenya)
- [GitHub topic programmable-voice](https://github.com/topics/programmable-voice)
- [OSS Cameroon (ecosyste.ms)](https://opencollective.ecosyste.ms/collectives/osscameroon)


---

<!-- source : recherche-apis-github-addendum-18-2026-10-06-netbuis.md -->

# Addendum 18 : APIs et dépôts GitHub gratuits (2026-10-06, passage 18, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 17. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Recherche « annuaire entreprises Cameroun, carte, open source » : annuaires commerciaux payants (Infobel, companydata), Yoomee (annuaire en ligne), jeux de données cartes open.africa. Rien de gratuit/API exploitable en plus d'OpenStreetMap/Overpass déjà retenu [N].
- Recherche « forum intégré open source » : Flarum (PHP, dépôt flarum/flarum, déploiements Railway/Zeabur). Option de repli si l'on ne veut pas coder le forum soi-même, mais le forum natif Django (modèles Thread/Post) reste plus rapide à intégrer à l'app et à l'authentification OTP [N].

## Conclusion
Aucune nouvelle piste à adopter. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle (PayUnit en option), Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [Flarum (GitHub)](https://github.com/flarum/flarum/)
- [Yoomee annuaire Cameroun](https://www.businessincameroon.com/telecom/1712-4539-cameroon-yoomee-launches-its-on-line-directory-of-national-companies)
- [open.africa cameroon maps](https://open.africa/el/dataset/cameroon-maps)


---

<!-- source : recherche-apis-github-addendum-19-2026-10-06-netbuis.md -->

# Addendum 19 : APIs et dépôts GitHub gratuits (2026-10-06, passage 19, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 18. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Recherche « SDK mobile money Cameroun (MTN MoMo, Orange Money) » : SDK déjà connus ou équivalents : campay (PyPI), camerpay/php-sdk, ekolotech/mobilemoney-gateway (Packagist), pytekmomoapi (docs readthedocs). Aucun nouvel acteur par rapport à CamPay/TranZak déjà retenus [N].
- Recherche « starter marketplace Flutter + Django » : seulement des boilerplates génériques (GeekyAnts flutter-starter, afzalimdad9 flutter-boilerplate, app-generator). Rien de spécifique commerçants locaux/recherche produit [N].

## Conclusion
Aucune nouvelle piste à adopter. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle (PayUnit en option), Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [campay (PyPI)](https://pypi.org/project/campay)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [GeekyAnts flutter-starter](https://awesome.ecosyste.ms/projects/github.com%2FGeekyAnts%2Fflutter-starter)


---

<!-- source : recherche-apis-github-addendum-20-2026-10-06-netbuis.md -->

# Addendum 20 : APIs et dépôts GitHub gratuits (2026-10-06, passage 20, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 19. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Recherche « mobile money Cameroun MTN/Orange, open source » : paquets Packagist `camerpay/php-sdk` et `ekolotech/mobilemoney-gateway` (SDK PHP, hors pile Django), SDK PyPI `campay` (déjà retenu avec CamPay). Rien de nouveau pour notre pile [N].
- Recherche « SDK appel VoIP Flutter » : twilio_voice_flutter, PortSIP, Siprix, Telnyx WebRTC. Tous déjà couverts par le plan voix (appel direct `tel:` d'abord, Fonoster en plan B) ; aucun n'est gratuit à l'usage en production [N].

## Conclusion
Aucune nouvelle piste. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle (PayUnit en option), Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay (PyPI)](https://pypi.org/project/campay)
- [Siprix VoIP SDK Flutter](https://pub.dev/documentation/siprix_voip_sdk/1.0.41/)


---

<!-- source : recherche-apis-github-addendum-21-2026-10-06-netbuis.md -->

# Addendum 21 : APIs et dépôts GitHub gratuits (2026-10-06, passage 21, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 20. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Recherche « Cameroun MTN MoMo / Orange Money SDK open source 2026 » : SDK React Native/TypeScript MTN MoMo (dev.to, forum MTN Rwanda), `lickayemassane/momo-payment` et `zaz-aangaraa/pay` (PHP/Laravel), `pytekmomoapi` (Python, déjà vu). Hors pile Django/Flutter ou déjà couverts par CamPay/TranZak [N].
- Recherche « annuaire local + géolocalisation Flutter » : flutter_nominatim, open_street_map_search_and_pick, geolocator, maimaps_flutter. Redondants avec MapLibre/PMTiles + PostGIS déjà retenus [N].

## Conclusion
Aucune nouvelle piste. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle (PayUnit en option), Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [DEV : SDK open source MTN MoMo React Native](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [momo-payment (Packagist)](https://packagist.org/packages/lickayemassane/momo-payment)
- [flutter_nominatim](https://fluttergems.dev/packages/flutter_nominatim/)


---

<!-- source : recherche-apis-github-addendum-22-2026-10-07-netbuis.md -->

# Addendum 22 : APIs et dépôts GitHub gratuits (2026-10-06, passage 22, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 21. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- « MoMo / Orange Money SDK Cameroun 2026 » : packages Packagist (`catidegla/laravel-mobile-money`, `camerpay/php-sdk`, `ekolotech/mobilemoney-gateway`, `elgiosoft/elgiopay-php-sdk`), `campay` sur PyPI (déjà retenu), `pytekmomoapi` (déjà vu), article Kolonell sur MTN MoMo Ghana/Côte d'Ivoire 2026. PHP/Laravel hors pile Django/Flutter ; le reste est déjà couvert par CamPay/TranZak [N].
- « géocodage/recherche locale OSM 2026 » : Photon (komoot/photon), Nominatim, Open Places API (openplacesapi.com). Redondants avec MapLibre/PMTiles + PostGIS déjà retenus [N].

## Conclusion
Aucune nouvelle piste. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle (PayUnit en option), Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [catidegla/laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay (PyPI)](https://pypi.org/project/campay)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [Kolonell : MTN MoMo API 2026](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)
- [komoot/photon](https://github.com/komoot/photon)
- [Nominatim](https://nominatim.org/)
- [Open Places API](https://openplacesapi.com/blog)


---

<!-- source : recherche-apis-github-addendum-23-2026-10-07-netbuis.md -->

# Addendum 23 : APIs et dépôts GitHub gratuits (2026-10-07, passage 23, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 22. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements Cameroun / Flutter : `mtn_momo_sdk` et `simplypaye` (pub.dev), `pay_unit_sdk` (déjà vu, PayUnit), `campay` PyPI (déjà retenu), `enkap_mobile_money` (module Odoo, hors pile). Le SDK Dart MTN MoMo est une option côté client mais la logique de paiement reste côté serveur Django [N].
- Appel/WhatsApp/forum : `OpenWp`, `whatsapp_chat_sdk`, `flutter_chat_ui`, Appwrite. Redondants avec url_launcher (tel:, wa.me), Flarum (plan B forum) [N].

## Conclusion
Aucune nouvelle piste. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle (PayUnit en option), Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [mtn_momo_sdk](https://pub.dev/documentation/mtn_momo_sdk/0.0.1/)
- [simplypaye](https://pub.dev/packages/simplypaye)
- [pay_unit_sdk](https://depscope.dev/pkg/pub/pay_unit_sdk)
- [campay (PyPI)](https://pypi.org/project/campay)
- [enkap_mobile_money](https://apps.odoo.com/apps/modules/18.0/enkap_mobile_money)
- [OpenWp](https://github.com/swarupbhc/OpenWp)
- [flutter_chat_ui](https://github.com/WebTrit/flutter_chat_ui)


---

<!-- source : recherche-apis-github-addendum-24-2026-10-07-netbuis.md -->

# Addendum 24 : APIs et dépôts GitHub gratuits (2026-10-07, passage 24, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 23. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements Cameroun : `ekolotech/mobilemoney-gateway` et `camerpay/php-sdk` (Packagist, PHP, hors pile Django), `dohone-sdk` (npm, Dohone), SDK open source MTN MoMo React Native/TypeScript (dev.to), `campay` PyPI 1.0.1 (déjà retenu). Aucun n'apporte mieux que CamPay + TranZak côté serveur [N].
- Annuaire/appel/WhatsApp Flutter : package pub.dev `whatsapp` 3.0.0 (API Cloud, payant côté Meta), modèles commerciaux CodeCanyon/FluxStore (payants). Redondants avec url_launcher (tel:, wa.me) [N].

## Conclusion
Aucune nouvelle piste. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle (PayUnit en option), Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [SDK MTN MoMo RN/TS](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [campay PyPI](https://pypi.org/project/campay)
- [whatsapp (pub.dev)](https://pub.dev/packages/whatsapp)


---

<!-- source : recherche-apis-github-addendum-25-2026-10-07-netbuis.md -->

# Addendum 25 : APIs et dépôts GitHub gratuits (2026-10-07, passage 25, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 24. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements : `catidegla/laravel-mobile-money` et `elgiosoft/elgiopay-php-sdk` (Packagist, PHP/Laravel, hors pile Django), `zaz-aangaraa/pay` (Laravel). Déjà vus : `camerpay/php-sdk`, `ekolotech/mobilemoney-gateway`, `campay` PyPI. Rien de mieux que CamPay + TranZak côté serveur [N].
- Annuaire/géoloc Flutter : modèles CodeCanyon (Listplace, Listygo, Business Listing), Bulistio (payants), `geoflutterfire_plus` (Firestore, redondant avec PostGIS) [N].

## Conclusion
Aucune nouvelle piste. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle (PayUnit en option), Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [elgiopay-php-sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [Listplace Flutter](https://codecanyon.net/item/listplace-business-directory-listing-flutter-app-android-ios/57380835)
- [geoflutterfire_plus](https://packages.ecosyste.ms/api/v1/registries/pub.dev/packages/geoflutterfire_plus/codemeta)


---

<!-- source : recherche-apis-github-addendum-26-2026-10-07-netbuis.md -->

# Addendum 26 : APIs et dépôts GitHub gratuits (2026-10-07, passage 26, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 25. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements : nouveaux noms vus seulement en résultat de recherche : `dohone-sdk` et `trustpayway-sdk` (npm), non vérifiés, aucune preuve de maintenance ni de couverture Cameroun [N]. Déjà connus : `campay` PyPI, `camerpay/php-sdk`, `ekolotech/mobilemoney-gateway`, `elgiopay-php-sdk`, `zaz-aangaraa/pay`. Rien de mieux que CamPay + TranZak côté serveur.
- Annuaire / appel / WhatsApp Flutter : seulement modèles payants CodeCanyon (Listplace, Business Listing) et `hoosierhub/open-business-directory` (ancien, peu utile) [N].

## Conclusion
Aucune nouvelle piste exploitable. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [trustpayway-sdk](https://app.unpkg.com/trustpayway-sdk@1.0.7/files/README.md)
- [campay PyPI](https://pypi.org/project/campay)
- [open-business-directory](https://github.com/hoosierhub/open-business-directory/blob/master/README.md)
- [Listplace Flutter](https://codecanyon.net/item/listplace-business-directory-listing-flutter-app-android-ios/57380835)


---

<!-- source : recherche-apis-github-addendum-27-2026-10-07-netbuis.md -->

# Addendum 27 : APIs et dépôts GitHub gratuits (2026-10-07, passage 27, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 26. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements : seuls nouveaux noms vus en résultat de recherche : `pay_unit_sdk` (pub.dev, Flutter) et un article dev.to sur un SDK open source MTN MoMo React Native/TypeScript. Non vérifiés, couverture Cameroun/maintenance inconnues [N]. Déjà connus : `campay` PyPI, `camerpay/php-sdk`, `ekolotech/mobilemoney-gateway`, `elgiopay-php-sdk`, `zaz-aangaraa/pay`.
- Annuaire / appel / WhatsApp Flutter : toujours seulement modèles payants CodeCanyon (Listplace, Business Listing) et dépôts WhatsApp-clone sans intérêt (muhammad-fiaz/whatsapp-flutter, sayhi) [N].

## Conclusion
Aucune nouvelle piste exploitable. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [pay_unit_sdk](https://depscope.dev/pkg/pub/pay_unit_sdk)
- [SDK MTN MoMo open source (dev.to)](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [campay PyPI](https://pypi.org/project/campay)
- [Listplace Flutter](https://codecanyon.net/item/listplace-business-directory-listing-flutter-app-android-ios/57380835)


---

<!-- source : recherche-apis-github-addendum-28-2026-10-07-netbuis.md -->

# Addendum 28 : APIs et dépôts GitHub gratuits (2026-10-07, passage 28, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 27. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements : seuls noms nouveaux en résultat : `lickayemassane/momo-payment` (Packagist) et `pytekmomoapi` (readthedocs, Python MoMo). Couverture Cameroun et maintenance inconnues [N]. Déjà connus : `campay` PyPI, `camerpay/php-sdk`, `ekolotech/mobilemoney-gateway`, `zaz-aangaraa/pay`.
- Annuaire / appel / WhatsApp Flutter : toujours uniquement des modèles payants CodeCanyon (Listplace) ; rien de libre sur GitHub [N].

## Conclusion
Aucune nouvelle piste exploitable. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [momo-payment](https://packagist.org/packages/lickayemassane/momo-payment)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [campay PyPI](https://pypi.org/project/campay)
- [Listplace Flutter](https://codecanyon.net/item/listplace-business-directory-listing-flutter-app-android-ios/57380835)


---

<!-- source : recherche-apis-github-addendum-29-2026-10-07-netbuis.md -->

# Addendum 29 : APIs et dépôts GitHub gratuits (2026-10-07, passage 29, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 28. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements (MTN MoMo / Orange Money / Cameroun) : mêmes résultats que l'addendum 28 (`campay` PyPI, `camerpay/php-sdk`, `ekolotech/mobilemoney-gateway`, `lickayemassane/momo-payment`, `pytekmomoapi`, adaptateur OpenFn `mtn-momo`). Aucun nom nouveau [N].
- Annuaire / appel / WhatsApp Flutter : toujours uniquement des modèles payants (Listplace, Bulistio, FluxStore) ; rien de libre exploitable [N].

## Conclusion
Aucune nouvelle piste. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [OpenFn mtn-momo](https://docs.openfn.org/adaptors/mtn-momo)
- [Listplace Flutter](https://codecanyon.net/item/listplace-business-directory-listing-flutter-app-android-ios/57380835)


---

<!-- source : recherche-apis-github-addendum-30-2026-10-07-netbuis.md -->

# Addendum 30 : APIs et dépôts GitHub gratuits (2026-10-07, passage 30, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 29. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements (MTN MoMo / Orange Money / Cameroun) : mêmes résultats que l'addendum 29 (`campay` PyPI, `camerpay/php-sdk`, `lickayemassane/momo-payment`). Seules mentions marginales : plugin Laravel `zaz-aangaraa/pay` et `pay_unit_sdk` (pub.dev) — non évalués [N].
- Annuaire / appel / WhatsApp Flutter : toujours uniquement des modèles payants (Listplace, Bulistio, Listygo) ; rien de libre exploitable [N].

## Conclusion
Aucune nouvelle piste. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [zaz-aangaraa/pay](https://laraplugins.io/plugins/zaz-aangaraa/pay)
- [pay_unit_sdk](https://depscope.dev/pkg/pub/pay_unit_sdk)
- [Listygo](https://codecanyon.net/item/listygo-directory-android-ios-app/53090685)


---

<!-- source : recherche-apis-github-addendum-31-2026-10-07-netbuis.md -->

# Addendum 31 : APIs et dépôts GitHub gratuits (2026-10-07, passage 31, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 30. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements (MTN MoMo / Orange Money / Cameroun) : mêmes pistes qu'avant (`campay` PyPI, `camerpay/php-sdk`). Mentions marginales nouvelles, non évaluées [N] : `ekolotech/mobilemoney-gateway` (Packagist), `kouyatekarim/momoapi` (Packagist), `pytekmomoapi` (Python, readthedocs). Articles Kolonell 2026 sur l'intégration Orange Money / MTN MoMo au Cameroun (contenu éditorial, à lire pour les frais).
- Annuaire / appel / WhatsApp Flutter : toujours uniquement des modèles payants (Listplace, Bulistio, CodeCanyon) ; rien de libre exploitable [N].

## Conclusion
Aucune piste nouvelle décisive. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [kouyatekarim/momoapi](https://packagist.org/packages/kouyatekarim/momoapi)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [Kolonell Orange Money Cameroun](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [Listplace](https://codecanyon.net/item/listplace-business-directory-listing-flutter-app-android-ios/57380835)


---

<!-- source : recherche-apis-github-addendum-32-2026-10-07-netbuis.md -->

# Addendum 32 : APIs et dépôts GitHub gratuits (2026-10-07, passage 32, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 31. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements (MTN MoMo / Orange Money / Cameroun) : mêmes pistes (`campay` PyPI 1.0.1, `ekolotech/mobilemoney-gateway`, `zaz-aangaraa/pay` Laravel [N], sujet GitHub « mtn » sur ecosyste.ms). Articles Kolonell 2026 sur les frais MTN MoMo / Orange Money à Douala et le coût d'intégration : éditorial, à lire pour budgéter.
- WhatsApp / appel Flutter : paquet pub.dev `whatsapp` (v3/v4, API Cloud officielle, [N] à valider) et `OpenWp` (ouvrir un chat sans enregistrer le numéro, idée wa.me déjà retenue). Annuaires Flutter : uniquement des modèles payants CodeCanyon (Listplace) [N].

## Conclusion
Aucune piste nouvelle décisive. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [zaz-aangaraa/pay](https://laraplugins.io/plugins/zaz-aangaraa/pay)
- [GitHub topic mtn](https://repos.ecosyste.ms/hosts/GitHub/topics/mtn)
- [Kolonell frais Douala](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)
- [Kolonell coût intégration](https://kolonell.com/fr/blog/cout-integration-mtn-momo-orange-money-douala-2026)
- [pub.dev whatsapp](https://pub.dev/packages/whatsapp)
- [OpenWp](https://github.com/swarupbhc/OpenWp)
- [Listplace](https://codecanyon.net/item/listplace-business-directory-listing-flutter-app-android-ios/57380835)


---

<!-- source : recherche-apis-github-addendum-33-2026-10-07-netbuis.md -->

# Addendum 33 : APIs et dépôts GitHub gratuits (2026-10-07, passage 33, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 32. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements Cameroun : nouvelles pistes mineures à valider [N] — `camerpay/php-sdk` (Packagist), `pytekmomoapi` (client Python MTN MoMo, readthedocs), crate Rust `mtnmomo`. Pistes déjà connues : `campay` PyPI, `ekolotech/mobilemoney-gateway`, `zaz-aangaraa/pay`. Fil communauté MTN : SDK React Native open source pour MoMo (sandbox, erreur 499) — utile en lecture, pas pour le Cameroun directement.
- Flutter / géolocalisation : `geoflutterfire_plus` (requêtes géo Firestore), `flutter_location_search2`, `gplaces` (Google Places, payant au-delà du quota : écarté), `hexfa/CloseByNow` (exemple d'app « à proximité »), `transformatek/flutter-examples`. Rien qui remplace MapLibre/PMTiles + PostGIS déjà retenus.

## Conclusion
Aucune piste nouvelle décisive. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [mtnmomo crate](https://packages.ecosyste.ms/registries/crates.io/packages/mtnmomo)
- [SDK React Native MoMo](https://momodevelopercommunity.mtn.com/momo-rwanda-developers-36/open-source-react-native-sdk-for-momo-plus-what-i-found-in-the-sandbox-499)
- [geoflutterfire_plus](https://packages.ecosyste.ms/api/v1/registries/pub.dev/packages/geoflutterfire_plus/codemeta)
- [flutter_location_search2](https://pub.dev/packages/flutter_location_search2)
- [CloseByNow](https://backiee.wasmer.app/https_github_com/hexfa/CloseByNow)


---

<!-- source : recherche-apis-github-addendum-34-2026-10-07-netbuis.md -->

# Addendum 34 : APIs et dépôts GitHub gratuits (2026-10-07, passage 34, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 33. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements Cameroun : mêmes pistes que l'addendum 33 (`campay` PyPI, `camerpay/php-sdk`, `ekolotech/mobilemoney-gateway`, `zaz-aangaraa/pay`, `pytekmomoapi`). Nouveau mineur [N] : `elgiosoft/elgiopay-php-sdk` (Packagist) ; article kolonell.com sur MTN MoMo API 2026 (Ghana/Côte d'Ivoire, pas le Cameroun).
- WhatsApp / Flutter : package pub.dev `whatsapp` (v4.0.0) [N] — client API Cloud, payant côté Meta au-delà du quota ; on garde `url_launcher` (wa.me, tel:) gratuit.

## Conclusion
Rien de nouveau décisif. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [MTN MoMo API 2026](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)
- [whatsapp pub.dev](https://pub.dev/packages/whatsapp)


---

<!-- source : recherche-apis-github-addendum-35-2026-10-07-netbuis.md -->

# Addendum 35 : APIs et dépôts GitHub gratuits (2026-10-07, passage 35, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 34. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements Cameroun : mêmes pistes que l'addendum 34 (`campay` PyPI, `camerpay/php-sdk`, `ekolotech/mobilemoney-gateway`, `zaz-aangaraa/pay`, `pytekmomoapi`). Nouveaux mineurs [N] : `dohone-sdk` (npm, agrégateur Dohone), `catidegla/laravel-mobile-money` (Packagist). Aucun n'apporte mieux que CamPay + TranZak.
- Voix / appel : `siprix_voip_sdk` (pub.dev) [N] — SDK SIP Flutter, option plan B voix avec Fonoster ; les SDK Twilio/Vonage/Telnyx restent payants à l'usage. On garde `url_launcher` (tel:, wa.me), gratuit.

## Conclusion
Rien de nouveau décisif. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum.

## Sources
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [campay PyPI](https://pypi.org/project/campay)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [siprix_voip_sdk](https://pub.dev/documentation/siprix_voip_sdk/latest/)
- [Voice API providers Flutter (SourceForge)](https://sourceforge.net/software/voice-calling-api-sdk/integrates-with-flutter/)


---

<!-- source : recherche-apis-github-addendum-36-2026-10-07-netbuis.md -->

# Addendum 36 – APIs/GitHub (2026-10-07): passe de confirmation, rien de nouveau

[S] = titres de résultats web seulement (non lus en détail).

## Résultats
- Bibliothèques MoMo/Orange Money (GitHub/Packagist): ngambmicheal/mobilemoney, regisbamba/momoapi-java, ogwok/mtn-momo, rewriteapi/mobilemoney.py, kouyatekarim/momoapi, fannypack/momo, ekolotech/mobilemoney-gateway, catidegla/laravel-mobile-money. Wrappers communautaires déjà connus ou équivalents; à vérifier (maintenance, licence) avant usage [S].
- Agrégateurs: camerpay/php-sdk, elgiopay php sdk, FeexPay, pawaPay (PROMOTE 2026), Africa's Talking (SMS/USSD/Voix/Paiements) [S]. Déjà couverts dans les addenda précédents.
- Aucune API gratuite récente (2026) nouvelle identifiée qui change les choix existants.

## Conclusion
Saturation confirmée (cf. audit v39). Recommandation inchangée: suspendre ou passer la routine en hebdomadaire, et lancer le jalon 0 (30 commerçants dans un quartier pilote).

## Sources
- [ngambmicheal/mobilemoney](https://github.com/ngambmicheal/mobilemoney)
- [regisbamba/momoapi-java](https://github.com/regisbamba/momoapi-java)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [pawaPay at PROMOTE 2026](https://pawapay.io/blog/pawapay-at-promote-2026)
- [Africa's Talking (apitracker)](https://apitracker.io/a/africastalking)


---

<!-- source : recherche-apis-github-addendum-37-2026-10-07-netbuis.md -->

# Addendum 37 – APIs/GitHub (2026-10-07): confirmation, rien de nouveau

[S] = titres de résultats seulement (non lus en détail).

- Paiement Cameroun: campay (PyPI), dohone-sdk (npm), camerpay/php-sdk, ekolotech/mobilemoney-gateway, elgiopay php sdk. Déjà connus; vérifier maintenance/licence avant usage [S].
- WhatsApp: la Cloud API est payante par message (changements tarifaires 2026); inchangé: wa.me gratuit par défaut, API officielle plus tard seulement si nécessaire [S].
- Aucune API gratuite récente nouvelle qui change les choix existants.

Conclusion: saturation (cf. audit v39). Pas de notification envoyée. Recommandation inchangée: suspendre/passer en hebdomadaire et lancer le jalon 0.

## Sources
- [campay (PyPI)](https://pypi.org/project/campay)
- [dohone-sdk (npm)](https://www.npmjs.org/package/dohone-sdk)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [WhatsApp Business API pricing 2026](https://chakrahq.com/article/whatsapp-api-pricing-guide/amp/)


---

<!-- source : recherche-apis-github-addendum-38-2026-10-07-netbuis.md -->

# Addendum 38 – APIs/GitHub (2026-10-07): confirmation, quelques pistes mineures

[S] = titres de résultats seulement (non lus en détail).

## Pistes mineures (à vérifier licence/maintenance avant usage)
- Paiement MoMo: pytekmomoapi (Python, readthedocs) et catidegla/laravel-mobile-money (PHP) [S]. Les SDK déjà connus restent: campay, dohone-sdk, camerpay/php-sdk, ekolotech/mobilemoney-gateway.
- Appels: Fonoster, alternative open source à Twilio (auto-hébergeable) [S]. Utile seulement si Twilio devient trop cher; sinon appel direct via tel: (gratuit) reste le choix par défaut.
- Un fil de la communauté MTN MoMo mentionne un SDK React Native open source (sandbox) [S].

## Conclusion
Rien qui change les choix existants (wa.me gratuit, tel: gratuit, Campay/Dohone pour le paiement). Saturation confirmée (cf. audit v39). Pas de notification envoyée. Recommandation inchangée: suspendre la routine ou la passer en hebdomadaire et lancer le jalon 0 (30 commerçants).

## Sources
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [campay (PyPI)](https://pypi.org/project/campay)
- [Fonoster](https://glama.ai/mcp/servers/@fonoster/fonoster/blob/5059d7fccad562fe9161530d4830f9808308cd5f/README.md)
- [Twilio API Alternatives 2026](https://publicapis.io/alternatives/twilio-api)


---

<!-- source : recherche-apis-github-addendum-39-2026-10-07-netbuis.md -->

# Addendum 39 – APIs/GitHub (2026-10-07): passage de confirmation

[S] = titres de résultats seulement (non lus en détail).

## Résultats
- Paiement MoMo/Orange Cameroun: mêmes SDK déjà connus (campay PyPI, dohone-sdk npm, camerpay/php-sdk, ekolotech/mobilemoney-gateway, elgiopay-php-sdk [S]). Un article Kolonell compare Orange Money vs MTN MoMo à Douala (frais 2026) [S] – utile pour le modèle économique.
- Cartographie/géolocalisation gratuite: OpenStreetMap + Nominatim (open source, auto-hébergeable) [S], déjà retenu.
- Aucune nouvelle API ou dépôt changeant les choix existants.

## Conclusion
Saturation confirmée. Rien de nouveau => pas de notification. Recommandation inchangée: suspendre/passer la routine en hebdomadaire et lancer le jalon 0 (30 commerçants).

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay (PyPI)](https://pypi.org/project/campay)
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [elgiopay-php-sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [Orange Money vs MTN MoMo Douala 2026](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)
- [Nominatim](https://gittrend.io/repo/osm-search/Nominatim)


---

<!-- source : recherche-apis-github-addendum-40-2026-10-07-netbuis.md -->

# Addendum 40 : APIs et dépôts GitHub gratuits (2026-10-07, passage 40, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 39. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements Cameroun : mêmes pistes que les addenda précédents (`ekolotech/mobilemoney-gateway`, `zaz-aangaraa/pay`, `pay_unit_sdk`). Nouveau mineur [N] : `lengopay_flutter` 1.3.0 (pub.dev) — plugin Flutter qui parle directement à la passerelle, donc contraire à la règle « l'application ne parle qu'à Django ». Écarté.
- Marketplace / WhatsApp Flutter : modèles `marketky`, `sayhi` (exemples d'interface, [N]) et package `whatsapp` 4.0.0 (API Cloud, payante au-delà du quota). On garde `url_launcher` (`tel:`, `wa.me`), gratuit.

## Conclusion
Saturation confirmée (cf. audit v39) : rien de nouveau décisif. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum. Recommandation : arrêter les passages de recherche et passer à la construction.

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [lengopay_flutter](https://pub-web-s2.flutter-io.cn/packages/lengopay_flutter/license)
- [pay_unit_sdk](https://depscope.dev/pkg/pub/pay_unit_sdk)
- [zaz-aangaraa/pay](https://laraplugins.io/plugins/zaz-aangaraa/pay)
- [marketky](https://github.com/mrezkys/marketky)
- [whatsapp pub.dev](https://pub.dev/documentation/whatsapp/latest/)


---

<!-- source : recherche-apis-github-addendum-41-2026-10-07-netbuis.md -->

# Addendum 41 : APIs et dépôts GitHub gratuits (2026-10-07, passage 41, exécution planifiée) — NetBuis

Complète v2, v3, addenda 1 à 40. [N] = résultat de recherche seulement, non vérifié. **Aucune décision ne change.**

## Résultats
- Paiements : seules pistes déjà connues (`campay` PyPI, `camerpay/php-sdk`, `catidegla/laravel-mobile-money`, `lengopay_flutter` écarté car l'appli ne parle qu'à Django). Article kolonell « MTN MoMo API 2026 » [N] : généraliste, rien de nouveau.
- Annuaire / géorecherche : `django-storelocator` [N] (alternative à PostGIS direct, inutile), Apify « OSM local business finder » [N] (données OSM pour pré-remplir des commerçants, option d'amorçage seulement), modèles Flutter d'annuaire payants (CodeCanyon) écartés.

## Conclusion
Saturation confirmée. Ordre rapide inchangé : KYC CamPay + TranZak en parallèle, Django + pg_trgm/PostGIS + OTP Nexah, url_launcher (tel:, wa.me) + MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix ; Flarum = plan B forum. Recommandation : arrêter la recherche, construire.

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [catidegla/laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [django-storelocator](https://django-storelocator.readthedocs.io/en/latest/_sources/index.txt)
- [OSM Local Business Finder](https://apify.com/technicaldost/osm-local-business-finder/api)


---

<!-- source : recherche-apis-github-addendum-42-2026-10-07-netbuis.md -->

# Addendum 42 – APIs/GitHub NetBuis (2026-10-07)

[S] = titres de résultats seulement, non lus en détail.

## Passe
- Mobile money Cameroun (MTN MoMo, Orange Money): résultats déjà connus: SDK Campay (PyPI `campay`), `camerpay/php-sdk`, `ekolotech/mobilemoney-gateway` (Packagist), sujets GitHub « mtn » [S]. Rien de nouveau par rapport aux addenda précédents.
- Appel / WhatsApp: guides 2026 sur la WhatsApp Business Calling API (Cloud API Calling, doc Meta, Chakra, YCloud) [S]. Déjà couvert.

## Constat
Aucune nouvelle API gratuite ou dépôt GitHub pertinent. Même conclusion que l'audit v41: la recherche est saturée. Le blocage est dans les décisions de Jeff et le jalon 0 (30 commerçants dans un quartier pilote). Recommandation: suspendre cette routine ou la passer en hebdomadaire.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay (PyPI)](https://pypi.org/project/campay/1.0.1/)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [WhatsApp Cloud API Calling (Meta)](https://developers.facebook.com/documentation/business-messaging/whatsapp/calling.md)
- [WhatsApp Business Calling API 2026 (Chakra)](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)


---

<!-- source : recherche-apis-github-addendum-43-2026-10-07-netbuis.md -->

# Addendum 43 – APIs/GitHub NetBuis (2026-10-07)

[S] = titres de résultats seulement, non lus en détail.

## Passe
- Mobile money: déjà connus: Campay (PyPI), camerpay/php-sdk, ekolotech/mobilemoney-gateway. Pistes mineures vues pour la première fois dans ces titres (à vérifier avant usage): `pytekmomoapi` (Python, MTN MoMo), `catidegla/laravel-mobile-money` (Laravel), article DEV « open-source SDK for MTN Mobile Money (React Native/TypeScript) » [S].
- Appel / WhatsApp: WhatsApp Cloud API Calling (déjà couvert); alternatives open source à Twilio listées sur opensource.builders (FreeSWITCH, Kamailio) : utiles seulement si le coût Twilio devient bloquant [S].

## Constat
Aucune API gratuite majeure nouvelle. La recherche reste saturée (voir audit v39/v42). Le blocage reste le jalon 0 (30 commerçants en quartier pilote) et les décisions de Jeff. Recommandation inchangée: suspendre la routine ou la passer en hebdomadaire.

## Sources
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)
- [catidegla/laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [SDK MTN MoMo React Native (DEV)](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [Alternatives open source à Twilio](https://opensource.builders/alternatives/twilio)
- [WhatsApp Business Calling API 2026](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)


---

<!-- source : recherche-apis-github-addendum-44-2026-10-08-netbuis.md -->

# Addendum 44 – APIs/GitHub NetBuis (2026-10-08)

[S] = titres de résultats seulement, non lus en détail.

## Passe
- Mobile money: seules pistes jamais citées avant: `escarter/openapimomo` (Packagist, MTN MoMo) et `elgiosoft/elgiopay-php-sdk` [S]. Mineures, PHP uniquement, à vérifier (licence, maintenance) avant usage. Le reste est déjà connu (Campay, camerpay, ekolotech, catidegla, SDK MTN React Native).
- Appel / WhatsApp: rien de neuf (FreeSWITCH, Kamailio, Plivo comme alternatives à Twilio, déjà connues) [S].

## Constat
Aucune API gratuite majeure nouvelle. Recherche saturée (audits v39/v42). Recommandation inchangée: suspendre la routine ou la passer en hebdomadaire; le blocage est le jalon 0 (30 commerçants pilotes) et les décisions de Jeff.

## Sources
- [escarter/openapimomo](https://root.packagist.org/packages/escarter/openapimomo)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [Alternatives open source à Plivo/Twilio](https://opensource.builders/os-alternatives/plivo)


---

<!-- source : recherche-apis-github-addendum-45-2026-10-08-netbuis.md -->

# Addendum 45 – APIs/GitHub NetBuis (2026-10-08, 2e passage du jour)

[S] = titres de résultats seulement, non lus en détail.

## Passe
- Paiements Cameroun: résultats identiques aux addenda 24/35/38/44 (campay, camerpay/php-sdk, ekolotech, dohone-sdk, pytekmomoapi, catidegla, zaz-aangaraa/pay). Seule nouveauté: article kolonell.com « MTN MoMo API Ghana/Côte d'Ivoire 2026 » [S], hors Cameroun, sans intérêt direct.
- Appel / WhatsApp / annuaire: rien de neuf (articles ChakraHQ sur WhatsApp API Afrique, payants côté Meta; annuaire WhatsApp au Zimbabwe, inspiration seulement) [S].

## Constat
Aucune API gratuite nouvelle. Saturation confirmée (audits v39/v42). Aucune décision ne change: tel: et wa.me (gratuits), CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation inchangée: suspendre la routine ou la passer en hebdomadaire; le blocage est le jalon 0 (30 commerçants pilotes).

## Sources
- [MTN MoMo API 2026 (kolonell)](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)
- [Top 10 WhatsApp API Africa 2026](https://chakrahq.com/article/top-10-whatsapp-api-solutions-in-africa-2026/)
- [Annuaire WhatsApp (Techzim)](https://techzim.co.zw/local-company-develops-free-business-directory-thats-accessible-via-whatsapp)


---

<!-- source : recherche-apis-github-addendum-46-2026-10-08-netbuis.md -->

# Addendum 46 – APIs/GitHub NetBuis (2026-10-08, 3e passage du jour)

[S] = titres de résultats seulement, non lus en détail.

## Passe
- Paiements Cameroun: mêmes résultats que addenda 44/45 (campay PyPI, camerpay/php-sdk, ekolotech/mobilemoney-gateway, zaz-aangaraa/pay). Deux pistes mineures à vérifier si besoin: elgiosoft/elgiopay-php-sdk [S] (Packagist) et un article dev.to « open-source SDK MTN Mobile Money React Native/TypeScript » [S] — utile uniquement comme inspiration côté mobile; la logique de paiement doit rester côté serveur.
- Appel / WhatsApp / annuaire: rien de neuf (guide WhatsApp Business Calling API 2026 de ChakraHQ, pywa docs « calls » — payant/Meta, non adapté au MVP) [S].

## Constat
Aucune API gratuite nouvelle déterminante. Saturation confirmée. Décisions inchangées: tel: et wa.me (gratuits), CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation inchangée: suspendre la routine ou la passer en hebdomadaire; le blocage est le jalon 0 (30 commerçants pilotes).

## Sources
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [SDK open source MTN MoMo RN/TS (dev.to)](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [campay (PyPI)](https://pypi.org/project/campay)
- [WhatsApp Business Calling API 2026](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)
- [pywa calls](https://pywa.readthedocs.io/en/3.0.0-rc.2/_sources/content/calls/overview.rst)


---

<!-- source : recherche-apis-github-addendum-47-2026-10-08-netbuis.md -->

# Addendum 47 – APIs/GitHub NetBuis (2026-10-08, 4e passage)

Deux recherches (paiements Cameroun/GitHub ; annuaire/géoloc Afrique). Résultats identiques aux addenda 44-46 : campay (PyPI), camerpay/php-sdk, ekolotech/mobilemoney-gateway, elgiopay php-sdk, zaz-aangaraa/pay. Seule nouveauté de surface : article kolonell « MTN MoMo API Ghana / Côte d'Ivoire 2026 » (hors Cameroun, non pertinent). Géoloc : uniquement des marketplaces payantes (Zyla, AfriGIS) – inutiles vs MapLibre/PMTiles/OSM.

## Constat
Aucune API gratuite nouvelle. Saturation confirmée. Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation : passer la routine en hebdomadaire ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay (PyPI)](https://pypi.org/project/campay)
- [kolonell MTN MoMo 2026](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)
- [AfriGIS](https://developers.afrigis.co.za/?p=5415)


---

<!-- source : recherche-apis-github-addendum-48-2026-10-08-netbuis.md -->

# Addendum 48 – APIs/GitHub NetBuis (2026-10-08, 5e passage)

Deux recherches (mobile money Cameroun/GitHub ; annuaire local/click-to-call Afrique). Résultats identiques aux addenda 44-47 : camerpay/php-sdk, campay (PyPI), ekolotech/mobilemoney-gateway, zaz-aangaraa/pay, articles kolonell. Seul élément vu : pytekmomoapi (wrapper MTN MoMo Python, readthedocs) – redondant avec CamPay/TranZak. Annuaire : apify OSM local business finder (payant à l'usage), rien de plus utile qu'OSM/Overpass + PostGIS.

## Constat
Aucune API gratuite nouvelle. Saturation confirmée. Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation : passer la routine en hebdomadaire ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay (PyPI)](https://pypi.org/project/campay)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [OSM Local Business Finder](https://apify.com/technicaldost/osm-local-business-finder/api)


---

<!-- source : recherche-apis-github-addendum-49-2026-10-08-netbuis.md -->

# Addendum 49 – APIs/GitHub NetBuis (2026-10-08, 6e passage)

Deux recherches (mobile money Cameroun ; annuaire local / WhatsApp Cloud API Afrique). Résultats quasi identiques aux addenda 44-48 (camerpay/php-sdk, campay PyPI, ekolotech/mobilemoney-gateway, zaz-aangaraa/pay, articles kolonell).

Éléments mineurs vus : dohone-sdk (npm, passerelle Dohone), catidegla/laravel-mobile-money et elgiosoft/elgiopay-php-sdk (wrappers PHP/Laravel, redondants avec CamPay/TranZak). WhatsApp Business Calling API (guides 2026) : utile plus tard, mais payant à l'usage et soumis à validation Meta, donc wa.me reste la solution pour le MVP.

## Constat
Aucune API gratuite nouvelle. Saturation confirmée. Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation : passer la routine en hebdomadaire ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [elgiopay-php-sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [WhatsApp Business Calling API 2026](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)


---

<!-- source : recherche-apis-github-addendum-50-2026-10-08-netbuis.md -->

# Addendum 50 – APIs/GitHub NetBuis (2026-10-08, 7e passage)

Deux recherches (SDK mobile money Cameroun ; annuaire local React Native/Expo). Résultats identiques aux addenda 44-49 : camerpay/php-sdk, campay (PyPI), ekolotech/mobilemoney-gateway, catidegla/laravel-mobile-money, zaz-aangaraa/pay. Seul élément mineur : pytekmomoapi (wrapper Python MTN MoMo, redondant avec CamPay). Côté annuaire/Expo : aucun dépôt pertinent (WorkManGH, FinDev = démos sans intérêt).

## Constat
Aucune API gratuite nouvelle. Saturation confirmée. Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation (déjà faite en addendum 49) : passer la routine en hebdomadaire ou la suspendre ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)


---

<!-- source : recherche-apis-github-addendum-51-2026-10-08-netbuis.md -->

# Addendum 51 – APIs/GitHub NetBuis (2026-10-08, 8e passage)

Deux recherches (SDK mobile money Cameroun ; annuaire local / WhatsApp / alternative Twilio Afrique). Résultats identiques aux addenda 44-50 : camerpay/php-sdk, campay, ekolotech/mobilemoney-gateway, zaz-aangaraa/pay, pytekmomoapi. Seul nom non vu avant : elgiosoft/elgiopay-php-sdk (SDK PHP, redondant avec CamPay, non retenu). Annuaire/WhatsApp : rien d'exploitable (digidirectory = démo).

## Constat
Aucune API gratuite nouvelle. Saturation confirmée. Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation maintenue : suspendre/passer la routine en hebdomadaire ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [elgiopay-php-sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)


---

<!-- source : recherche-apis-github-addendum-52-2026-10-08-netbuis.md -->

# Addendum 52 – APIs/GitHub NetBuis (2026-10-08, 9e passage)

Deux recherches (mobile money/USSD/annuaire Cameroun ; recherche locale/cartes hors-ligne). Résultats déjà connus : ekolotech/mobilemoney-gateway, elgiopay-php-sdk, Africa's Talking, Mojaloop, Organic Maps/OSM. Noms vus mais non retenus (démos/peu maintenus, redondants avec CamPay/TranZak) : pluspeople/pesaPi, aristideman/MobileTransactionAPI.

## Constat
Aucune API gratuite nouvelle. Saturation confirmée. Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation maintenue : passer la routine en hebdomadaire ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [pesaPi](https://github.com/pluspeople/pesaPi)
- [MobileTransactionAPI](https://github.com/aristideman/MobileTransactionAPI)
- [mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)


---

<!-- source : recherche-apis-github-addendum-53-2026-10-08-netbuis.md -->

# Addendum 53 – APIs/GitHub NetBuis (2026-10-08, 10e passage)

Deux recherches (SDK mobile money Cameroun ; annuaire local/géoloc/click-to-call). Résultats déjà connus : camerpay/php-sdk, campay (PyPI), ekolotech/mobilemoney-gateway, elgiopay-php-sdk, zaz-aangaraa/pay, pytekmomoapi, mtnmomo (crate), SDK MoMo React Native (dev.to). Côté annuaire/géoloc : uniquement des plugins WordPress/store-locator génériques, sans intérêt.

## Constat
Aucune API gratuite nouvelle. Saturation confirmée. Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation maintenue : passer la routine en hebdomadaire ou la suspendre ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)


---

<!-- source : recherche-apis-github-addendum-54-2026-10-08-netbuis.md -->

# Addendum 54 – APIs/GitHub NetBuis (2026-10-08, 11e passage)

Deux recherches (mobile money Cameroun open source ; annuaire local/géoloc). Seuls éléments nouveaux mineurs : catidegla/laravel-mobile-money (package Laravel générique, hors stack Django) et un blog Kolonell (MoMo Ghana/CI, comparatif Orange Money vs MTN MoMo Douala) – informatif, pas une API. Côté géoloc : scrapers Apify OSM payants/limités, sans intérêt face à Overpass/Nominatim/PostGIS.

## Constat
Aucune API gratuite nouvelle. Saturation confirmée. Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation maintenue : passer la routine en hebdomadaire ou la suspendre ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [catidegla/laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [Kolonell – Orange Money vs MTN MoMo Cameroun](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)


---

<!-- source : recherche-apis-github-addendum-55-2026-10-08-netbuis.md -->

# Addendum 55 – APIs/GitHub NetBuis (2026-10-08, 12e passage)

Deux recherches (mobile money Cameroun open source ; annuaire local/géoloc Afrique).

Éléments aperçus, tous mineurs et hors stack Django/Python : camerpay/php-sdk, ekolotech/mobilemoney-gateway, zaz-aangaraa/pay (paquets PHP/Laravel, wrappers de passerelles déjà connues). Le paquet PyPI `campay` (déjà retenu) reste le seul wrapper pertinent. Géoloc : marketplaces Zyla/AfriGIS (payants, Afrique du Sud), scraper Apify OSM (limité) – rien qui égale Overpass/Nominatim/PostGIS.

## Constat
Aucune API gratuite nouvelle. Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation maintenue : passer la routine en hebdomadaire ou la suspendre ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay (PyPI)](https://pypi.org/project/campay)
- [Zyla Labs – location APIs](https://zylalabs.com/api-marketplace/top-search/Geolocation%20APIs?page=3)


---

<!-- source : recherche-apis-github-addendum-56-2026-10-08-netbuis.md -->

# Addendum 56 – APIs/GitHub NetBuis (2026-10-08, 13e passage)

Deux recherches (mobile money Cameroun open source ; WhatsApp/SMS/voix/annuaire Afrique).

Résultats : mêmes paquets déjà vus (camerpay/php-sdk, ekolotech/mobilemoney-gateway, campay PyPI, elgiopay PHP SDK, zaz-aangaraa/pay) ; netflie/whatsapp-cloud-api (PHP, wrapper de la WhatsApp Cloud API, hors stack) ; Africa's Talking (SMS/USSD/voix/paiements, déjà connu, payant à l'usage). Articles de comparatif (Chakra, Kolonell) sans API gratuite nouvelle.

## Constat
Aucune API gratuite nouvelle. Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation maintenue : suspendre/espacer la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [netflie/whatsapp-cloud-api](https://gittrend.io/repo/netflie/whatsapp-cloud-api)
- [Africa's Talking](https://www.apitracker.io/a/africastalking)
- [Top 10 WhatsApp API Africa 2026](https://chakrahq.com/article/top-10-whatsapp-api-solutions-in-africa-2026/)


---

<!-- source : recherche-apis-github-addendum-57-2026-10-08-netbuis.md -->

# Addendum 57 – APIs/GitHub NetBuis (2026-10-08, 14e passage)

Deux recherches (mobile money Cameroun / annuaire / géorecherche ; click-to-call / WhatsApp / USSD).

Résultats : mêmes paquets déjà vus (camerpay/php-sdk, elgiopay, campay PyPI, zaz-aangaraa/pay). Seules mentions marginales : pluspeople/pesaPi (client mobile money East Africa, hors Cameroun) et le module Odoo « enkap mobile money » (hors stack). Rien de nouveau sur WhatsApp (API Cloud payante à la conversation, déjà documentée).

## Constat
Aucune API gratuite nouvelle. Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation maintenue : espacer/suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [pluspeople/pesaPi](https://github.com/pluspeople/pesaPi)
- [enkap mobile money (Odoo)](https://apps.odoo.com/apps/modules/18.0/enkap_mobile_money)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [Is the WhatsApp API Free in 2026](https://www.unipile.com/fr/lapi-whatsapp-est-elle-gratuite/)


---

<!-- source : recherche-apis-github-addendum-58-2026-10-08-netbuis.md -->

# Addendum 58 – APIs/GitHub NetBuis (2026-10-08, 15e passage)

Deux recherches (mobile money Cameroun ; annuaire local / géolocalisation / click-to-call).

Résultats : mêmes paquets déjà connus (camerpay/php-sdk, campay PyPI, elgiopay, zaz-aangaraa/pay). Mentions marginales : ekolotech/mobilemoney-gateway (wrapper PHP générique, redondant avec CamPay/TranZak) et pytekmomoapi (client MTN MoMo Python, déjà couvert par l'API MoMo officielle). Rien de nouveau côté annuaire/géo (OSM/Overpass, PostGIS déjà retenus) ni WhatsApp.

## Constat
Aucune API gratuite nouvelle. Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation : suspendre/espacer la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [Intégrer Orange Money API Cameroun 2026](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)


---

<!-- source : recherche-apis-github-addendum-59-2026-10-08-netbuis.md -->

# Addendum 59 – APIs/GitHub NetBuis (2026-10-08, 16e passage)

Deux recherches (nouveautés GitHub Cameroun/mobile money/annuaire ; SDK Orange Money/MTN MoMo Afrique 2026).

Mentions marginales : @tecafrik/africa-payment-sdk (npm, SDK multi-opérateurs Afrique, redondant avec CamPay/TranZak) et lepresk/momo-api v1.2.0 (PHP, wrapper MTN MoMo, déjà couvert par l'API MoMo officielle). Guides kolonell.com déjà connus. Rien de nouveau pour annuaire/géo/WhatsApp/appel.

## Constat
Aucune API gratuite nouvelle. Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [@tecafrik/africa-payment-sdk](https://www.jsdelivr.com/package/npm/@tecafrik/africa-payment-sdk?tab=stats)
- [lepresk/momo-api v1.2.0](https://phpfreaks.com/news/20216)
- [kolonell – MTN MoMo API 2026](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)


---

<!-- source : recherche-apis-github-addendum-60-2026-10-08-netbuis.md -->

# Addendum 60 – APIs/GitHub NetBuis (2026-10-08, 17e passage)

Deux recherches (nouveautés GitHub mobile money/annuaire/WhatsApp Cameroun ; alternatives Orange Money/MTN MoMo/Twilio 2026).

## Constat
Aucune API gratuite nouvelle. Résultats déjà connus : Orange Messaging Pro Cameroon (RapidAPI), CamPay (gem/SDK), elgiopay PHP SDK (redondant CamPay/TranZak), lepresk/momo-api v1.2.0, guides kolonell, annuaire afrotools des API africaines.

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [Annuaire des API africaines](https://afrotools.com/fr/tools/annuaire-api-africaines/)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [lepresk/momo-api](https://phpfreaks.com/news/20216)
- [Orange Messaging Pro Cameroon](https://orange-evaluation.hub.rapidapi.com/orange-orange-default/api/messaging-pro-cameroon)


---

<!-- source : recherche-apis-github-addendum-61-2026-10-08-netbuis.md -->

# Addendum 61 – APIs/GitHub NetBuis (2026-10-08, 18e passage)

Deux recherches (SDK mobile money Cameroun ; API gratuites annuaire/géocodage/WhatsApp).

## Constat
Aucune API gratuite réellement nouvelle ni changement de décision. Seuls wrappers mineurs repérés, tous redondants avec CamPay/TranZak/MTN MoMo officiel :
- camerpay/php-sdk, catidegla/laravel-mobile-money, ekolotech/mobilemoney-gateway (Packagist, PHP/Laravel – hors stack Django)
- pytekmomoapi (Python, wrapper MTN MoMo – à comparer au SDK officiel si besoin)
- SDK open source MTN MoMo React Native/TypeScript (article DEV) – à surveiller côté app mobile
- Geokeo (géocodage gratuit) : alternative secondaire à Nominatim/PostGIS, non nécessaire.

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)
- [SDK MTN MoMo React Native](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [Geokeo](https://www.saysimple.com/integrations/geokeo)


---

<!-- source : recherche-apis-github-addendum-62-2026-10-09-netbuis.md -->

# Addendum 62 – APIs/GitHub NetBuis (2026-10-09, 19e passage)

Deux recherches (SDK mobile money Cameroun ; annuaire local/géocodage/WhatsApp).

## Constat
Aucune API gratuite nouvelle. Résultats identiques aux addenda précédents : camerpay/php-sdk, catidegla/laravel-mobile-money, ekolotech/mobilemoney-gateway (PHP, hors stack), pytekmomoapi, campay (PyPI). Annuaire/OSM : Apify OSM Local Business Finder (payant/limité, non nécessaire) ; rien qui remplace PostGIS/Nominatim.

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [Apify OSM Local Business Finder](https://apify.com/technicaldost/osm-local-business-finder/api)


---

<!-- source : recherche-apis-github-addendum-63-2026-10-09-netbuis.md -->

# Addendum 63 – APIs/GitHub NetBuis (2026-10-09, 20e passage)

Deux recherches (nouveautés GitHub gratuites Cameroun/mobile money/WhatsApp ; SDK Orange Money/MTN MoMo oct. 2026).

## Constat
Aucune API gratuite nouvelle pertinente. Résultats déjà connus : campay (PyPI), pytekmomoapi, elgiopay-php-sdk (PHP, hors stack), mesomb-js-client (agrégateur, option de secours), Klasha MoMo payout (B2B, payant, inutile au MVP), MTN MoMo SDK community (sandbox).

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [mesomb-js-client](https://github.com/hachther/mesomb-js-client)
- [MTN MoMo SDKs](https://momodevelopercommunity.mtn.com/product-updates/momo-sdks-133)
- [Klasha MoMo payout](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)


---

<!-- source : recherche-apis-github-addendum-64-2026-10-09-netbuis.md -->

# Addendum 64 – APIs/GitHub NetBuis (2026-10-09, 21e passage)

Deux recherches (nouveautés GitHub gratuites Cameroun/mobile money/WhatsApp ; annuaires/géolocalisation commerces open source).

## Constat
Aucune API gratuite nouvelle pertinente. Seuls résultats : paquets Packagist génériques (laravel-mobile-money, mobilemoney-gateway – PHP, hors stack), campay PyPI (déjà retenu), Apify OSM Local Business Finder (scraping OSM, payant à l'usage, inutile : on a notre propre base commerçants), guides kolonell.com Orange Money/MTN (déjà couverts).

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)
- [Orange Money vs MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)
- [OSM Local Business Finder](https://apify.com/technicaldost/osm-local-business-finder/api)


---

<!-- source : recherche-apis-github-addendum-65-2026-10-09-netbuis.md -->

# Addendum 65 – APIs/GitHub NetBuis (2026-10-09, 22e passage)

Deux recherches (SDK mobile money Cameroun open source ; annuaires/géolocalisation commerces).

## Constat
Aucune API gratuite nouvelle pertinente. Résultats déjà connus ou hors stack : campay PyPI (retenu), camerpay/php-sdk et ekolotech/mobilemoney-gateway (PHP, hors stack), pytekmomoapi (MTN MoMo Python, déjà évalué), guide GSMA SDK (informatif), scrapers OSM/Apify et Lead-Finder (inutiles : base commerçants propre).

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Pas de notification envoyée (rien de nouveau).
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [GSMA Mobile Money API SDK](https://www.gsma.com/mobilefordevelopment/mobile/unveiling-the-gsma-mobile-money-api-sdk-adoption-guide-a-catalyst-for-fintech-evolution/)


---

<!-- source : recherche-apis-github-addendum-66-2026-10-09-netbuis.md -->

# Addendum 66 – APIs/GitHub NetBuis (2026-10-09, 23e passage)

Deux recherches (SDK mobile money Cameroun ; WhatsApp Cloud API / annuaires + appel).

## Constat
Aucune nouveauté pertinente. Résultats déjà connus : campay PyPI, camerpay/php-sdk, ekolotech/mobilemoney-gateway (PHP, hors stack). Nouveaux noms mineurs sans intérêt : elgiopay php-sdk, trustpayway-sdk (npm), norrisboat/MobileMoneySDK (Kotlin multiplateforme générique, non Cameroun). Guides WhatsApp Cloud API 2026 : informatifs, rien qui change wa.me.

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Aucune notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [elgiopay php-sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [trustpayway-sdk](https://app.unpkg.com/trustpayway-sdk@1.0.7/files/README.md)
- [MobileMoneySDK](https://github.com/norrisboat/MobileMoneySDK)
- [WhatsApp Cloud API 2026 update](https://achiya-automation.com/en/blog/whatsapp-cloud-api-2026-update.md)


---

<!-- source : recherche-apis-github-addendum-67-2026-10-09-netbuis.md -->

# Addendum 67 – APIs/GitHub NetBuis (2026-10-09, 24e passage)

Deux recherches (SDK mobile money Cameroun ; annuaire local / géoloc open source).

## Constat
Aucune nouveauté. Mobile money : campay (PyPI), camerpay/php-sdk, ekolotech/mobilemoney-gateway, pytekmomoapi (déjà connus), articles kolonell.com (informatifs). Annuaire/géoloc : OSM/Overpass, scrapers Apify, marketplaces Zyla (payants) – rien qui remplace PostGIS + MapLibre/PMTiles.

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Aucune notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [OSM POI scraper](https://apify.com/logiover/openstreetmap-business-poi-scraper)


---

<!-- source : recherche-apis-github-addendum-68-2026-10-09-netbuis.md -->

# Addendum 68 – APIs/GitHub NetBuis (2026-10-09, 25e passage)

Deux recherches (SDK mobile money Cameroun ; annuaire local / WhatsApp Afrique).

## Constat
Aucune nouveauté décisive. Mobile money : camerpay/php-sdk, ekolotech/mobilemoney-gateway, pytekmomoapi (déjà connus) ; mentions mineures : elgiosoft/elgiopay-php-sdk (PHP, non pertinent pour stack Django) et un article dev.to sur un SDK MTN MoMo React Native/TypeScript (à regarder seulement si besoin d'un client côté mobile ; le paiement reste côté serveur). WhatsApp : guides payants (chatdaddy, chakrahq) – wa.me gratuit suffit.

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Aucune notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [dev.to SDK MTN MoMo RN/TS](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [pytekmomoapi](https://pypi.org/project/pytekmomoapi)


---

<!-- source : recherche-apis-github-addendum-69-2026-10-09-netbuis.md -->

# Addendum 69 – APIs/GitHub NetBuis (2026-10-09, 26e passage)

Deux recherches (SDK mobile money Cameroun ; annuaire local / APIs gratuites).

## Constat
Aucune nouveauté décisive. Seules mentions mineures : dohone-sdk (npm, agrégateur Dohone, alternative possible à CamPay/TranZak, non prioritaire) et un article kolonell.com sur l'API MTN MoMo 2026 (Ghana/Côte d'Ivoire, hors Cameroun). Le reste est déjà connu (camerpay/php-sdk, campay PyPI, pytekmomoapi, ekolotech/mobilemoney-gateway, elgiopay). Annuaire local : rien de gratuit et supérieur à OSM/Nominatim/Overpass + PostGIS déjà retenus.

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Aucune notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [MTN MoMo API 2026](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)
- [campay PyPI](https://pypi.org/project/campay)


---

<!-- source : recherche-apis-github-addendum-70-2026-10-09-netbuis.md -->

# Addendum 70 – APIs/GitHub NetBuis (2026-10-09, 27e passage)

Deux recherches (SDK mobile money Cameroun ; annuaire local / alternatives Twilio-WhatsApp gratuites).

## Constat
Aucune nouveauté décisive. Mentions mineures : module Odoo « enkap mobile money » (hors périmètre, ERP) et article dev.to sur un SDK open source MTN MoMo React Native/TypeScript (utile seulement comme référence, collecte MTN déjà couverte par CamPay/TranZak). Alternatives Twilio open source (FreeSWITCH, Kamailio) : trop lourdes ; `tel:` et `wa.me` restent la solution la plus rapide et gratuite.

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Aucune notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [SDK MTN MoMo RN/TS](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [enkap mobile money](https://apps.odoo.com/apps/modules/18.0/enkap_mobile_money)
- [Alternatives Twilio open source](https://opensource.builders/alternatives/twilio)


---

<!-- source : recherche-apis-github-addendum-71-2026-10-09-netbuis.md -->

# Addendum 71 – APIs/GitHub NetBuis (2026-10-09, 28e passage)

Deux recherches (mobile money Cameroun open source ; annuaire/click-to-call/WhatsApp Afrique).

## Constat
Aucune nouveauté décisive. Résultats mineurs : packages PHP (ekolotech/mobilemoney-gateway, elgiopay), pytekmomoapi (Python, MoMo), article Kolonell sur MTN MoMo API 2026 — tous redondants avec CamPay/TranZak déjà retenus. Aucun nouvel annuaire/API gratuite pertinente.

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Aucune notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [mobilemoney gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)
- [MTN MoMo API 2026](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)


---

<!-- source : recherche-apis-github-addendum-72-2026-10-09-netbuis.md -->

# Addendum 72 – APIs/GitHub NetBuis (2026-10-09, 29e passage)

Deux recherches (mobile money Cameroun open source ; annuaire/recherche commerçants Afrique).

## Constat
Aucune nouveauté. Mêmes résultats que l'addendum 71 (ekolotech/mobilemoney-gateway, elgiopay, kolonell MTN MoMo/Orange Money 2026, package PyPI campay). Côté annuaires : AfriGIS (payant, Afrique du Sud), allbusiness.africa, OSM local business finder (Apify) — non retenus, OSM/Overpass déjà couvert.

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Aucune notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [mobilemoney gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)
- [Orange Money API Cameroun 2026](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [AfriGIS business search](https://developers.afrigis.co.za/portfolio/business-search/)


---

<!-- source : recherche-apis-github-addendum-73-2026-10-09-netbuis.md -->

# Addendum 73 – APIs/GitHub NetBuis (2026-10-09, 30e passage)

Deux recherches (mobile money Cameroun open source ; annuaire commerçants + appel/WhatsApp Afrique).

## Constat
Aucune nouveauté. Mêmes résultats que les addendums 71-72 (ekolotech/mobilemoney-gateway, campay PyPI/RubyGems, kolonell MTN MoMo/Orange Money 2026). Nouveau seulement côté annuaire : guide WhatsApp Business Calling API 2026 (chakrahq) et un annuaire WhatsApp au Zimbabwe (techzim) — informatifs, non retenus (WhatsApp Calling API payante/soumise à approbation Meta ; wa.me suffit).

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Aucune notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [mobilemoney gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)
- [Orange Money vs MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)
- [WhatsApp Business Calling API 2026](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)
- [Annuaire WhatsApp gratuit (techzim)](https://techzim.co.zw/local-company-develops-free-business-directory-thats-accessible-via-whatsapp)


---

<!-- source : recherche-apis-github-addendum-74-2026-10-09-netbuis.md -->

# Addendum 74 – APIs/GitHub NetBuis (2026-10-09, 31e passage)

Deux recherches (mobile money Cameroun open source ; annuaire commerçants + appel/WhatsApp Afrique).

## Constat
Aucune nouveauté. Mêmes résultats que l'addendum 73 (ekolotech/mobilemoney-gateway, campay PyPI, camerpay/php-sdk, pytekmomoapi, catidegla/laravel-mobile-money ; WhatsApp Calling API payante, techzim annuaire WhatsApp). Aucun nouveau dépôt GitHub exploitable.

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Aucune notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [mobilemoney gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [WhatsApp Business Calling API 2026](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)


---

<!-- source : recherche-apis-github-addendum-75-2026-10-09-netbuis.md -->

# Addendum 75 – APIs/GitHub NetBuis (2026-10-09, 32e passage)

Deux recherches (SDK mobile money Cameroun ; annuaire commerçants Afrique open source).

## Constat
Aucune nouveauté exploitable. Mêmes résultats que l'addendum 74 (camerpay/php-sdk, ekolotech/mobilemoney-gateway, campay PyPI, catidegla/laravel-mobile-money). Seul nom marginal : elgiosoft/elgiopay-php-sdk (non évalué, PHP, à vérifier seulement si Laravel retenu). Annuaire : uniquement scrapers Apify / AfriGIS (payants ou Afrique du Sud), sans intérêt.

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Aucune notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [mobilemoney gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [AfriGIS business search](https://developers.afrigis.co.za/portfolio/business-search/)


---

<!-- source : recherche-apis-github-addendum-76-2026-10-09-netbuis.md -->

# Addendum 76 – APIs/GitHub NetBuis (2026-10-09, 33e passage)

Deux recherches (SDK mobile money Cameroun ; annuaire/API commerçants Afrique open source).

## Constat
Aucune nouveauté exploitable. Mêmes résultats que l'addendum 75 (ekolotech/mobilemoney-gateway, campay PyPI). Seul nom marginal : regisbamba/momoapi-java (client MTN MoMo Java, non évalué, utile seulement si backend Java). Annuaire : AfriGIS (Afrique du Sud), Apify OSM Local Business Finder (payant), Zylalabs (payant) – sans intérêt.

Décisions inchangées : tel: et wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS, MapLibre/PMTiles, FCM. Aucune notification envoyée.
Recommandation : suspendre la routine ; priorité = jalon 0 (30 commerçants pilotes).

## Sources
- [mobilemoney gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)
- [momoapi-java](https://github.com/regisbamba/momoapi-java)
- [AfriGIS business search](https://developers.afrigis.co.za/portfolio/business-search/)
- [Apify OSM Local Business Finder](https://apify.com/technicaldost/osm-local-business-finder/api)


---

<!-- source : recherche-apis-github-addendum-78-2026-10-09-netbuis.md -->

# Addendum 78 — APIs GitHub gratuites 2026 (run planifié, 2026-10-09)

## Verdict
Saturation quasi totale (addenda 57–77). Deux recherches : seules pistes marginales ci-dessous, aucune ne change l'architecture.

## Pistes (à vérifier avant usage, non testées)
- **SDK React Native open source pour MTN MoMo** (article DEV Community + fil MTN MoMo Developer Community Rwanda) : utile pour accélérer l'intégration mobile côté client ; le backend reste responsable des appels Collection/Disbursement (jamais de clés dans l'app).
- **opensource.builders — alternatives open source à Twilio/Plivo** (FreeSWITCH, Kamailio) : option de repli si le coût Twilio devient un frein ; lourd à opérer, à ne considérer qu'après le MVP. Pour aller vite : appel direct via lien `tel:` + WhatsApp `wa.me` (gratuit, sans API).
- **Packages PHP/Python/Java MoMo** (ekolotech/mobilemoney-gateway, pytekmomoapi, regisbamba/momoapi-java, ogwok/mtn-momo) : wrappers communautaires ; vérifier date du dernier commit et licence avant adoption.
- **Comparatif WhatsApp API Afrique 2026 (Chakra)** : confirme WhatsApp Cloud API (Meta) comme voie standard ; sinon `wa.me`.

## Recommandation
Pour livrer vite : recherche produit → liste commerçants → boutons `tel:` / `wa.me` ; paiement via agrégateur (Campay/pawaPay/Flutterwave) ; Twilio seulement pour appels masqués/tracés. Passer la routine en hebdomadaire ou la suspendre. Pas de notification.

## Sources
- [DEV — SDK open source MTN MoMo React Native](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [MTN MoMo community — SDK RN](https://momodevelopercommunity.mtn.com/momo-rwanda-developers-36/open-source-react-native-sdk-for-momo-plus-what-i-found-in-the-sandbox-499)
- [opensource.builders — alternatives Twilio](https://opensource.builders/alternatives/twilio)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [momoapi-java](https://github.com/regisbamba/momoapi-java)
- [mtn-momo (ogwok)](https://github.com/ogwok/mtn-momo)
- [Chakra — WhatsApp API Afrique 2026](https://chakrahq.com/article/top-10-whatsapp-api-solutions-in-africa-2026/)


---

<!-- source : recherche-apis-github-addendum-79-2026-10-09-netbuis.md -->

# Addendum 79 — APIs GitHub gratuites 2026 (run planifié, 2026-10-09)

## Verdict
Saturation confirmée (addenda 57–78). Deux recherches : rien qui change l'architecture. Pas de notification.

## Pistes marginales (non testées, vérifier licence et dernier commit)
- **elgiosoft/elgiopay-php-sdk** (Packagist) : SDK PHP communautaire pour paiements mobile money Cameroun.
- **zaz-aangaraa/pay** (Laravel, laraplugins.io) : package Laravel de paiement mobile money.
- **enkap_mobile_money** (Odoo 18) : module d'intégration mobile money ; utile seulement si Odoo est utilisé.
- **Campay (ClickGems)** : fiche de suivi confirmant Campay comme agrégateur Cameroun (MTN + Orange).
- **cult-directory-template (nolly-studio)** : modèle open source d'annuaire, source d'inspiration pour la liste commerçants (stack web, pas React Native).
- **Kolonell — comparatif Orange Money vs MTN MoMo Cameroun 2026** : aide au choix des frais.

## Recommandation (inchangée)
Recherche produit → liste commerçants → boutons `tel:` / `wa.me` ; paiement via agrégateur (Campay/pawaPay/Flutterwave) ; Twilio seulement pour appels masqués/tracés. Suspendre ou passer la routine en hebdomadaire.

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [zaz-aangaraa/pay](https://laraplugins.io/plugins/zaz-aangaraa/pay)
- [Odoo enkap mobile money](https://apps.odoo.com/apps/modules/18.0/enkap_mobile_money)
- [Campay — ClickGems](https://clickgems.clickhouse.com/dashboard/campay)
- [Kolonell — Orange Money vs MTN MoMo Cameroun](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)
- [cult-directory-template](https://www.sourcepulse.org/projects/1842085)


---

<!-- source : recherche-apis-github-addendum-80-2026-10-09-netbuis.md -->

# Addendum 80 — APIs GitHub gratuites 2026 (run planifié, 2026-10-09)

## Verdict
Saturation (addenda 57–79). Une recherche : seule nouveauté mineure = **camerpay/php-sdk** (Packagist, SDK PHP Cameroun) et le SDK **campay** (PyPI) déjà connu. Architecture inchangée. Pas de notification.

## Pistes (vérifier licence et dernier commit)
- camerpay/php-sdk — SDK PHP paiements Cameroun (backend PHP seulement).
- campay (PyPI) — client Python Campay (MTN + Orange Money).
- DEV.to : « Open-source SDK for MTN Mobile Money, React Native/TypeScript » — directement pertinent pour l'app mobile (à auditer avant usage).

## Recommandation (inchangée)
Recherche produit → liste commerçants → `tel:` / `wa.me` ; paiement via agrégateur (Campay/pawaPay/Flutterwave) ; Twilio seulement pour appels masqués. Suspendre la routine ou la passer en hebdomadaire.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [SDK MTN MoMo React Native — DEV](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)


---

<!-- source : recherche-apis-github-addendum-81-2026-10-09-netbuis.md -->

# Addendum 81 — APIs GitHub gratuites 2026 (run planifié, 2026-10-09)

## Verdict
Saturation confirmée (addenda 57–80). Architecture inchangée. Pas de notification.

## Pistes mineures nouvelles (vérifier licence et dernier commit avant usage)
- dohone-sdk (npm) — SDK JS pour l'agrégateur Dohone (Cameroun / Afrique centrale) ; utilisable côté backend Node.
- pytekmomoapi (PyPI/readthedocs) — client Python MTN MoMo.
- ekolotech/mobilemoney-gateway (Packagist) — passerelle Mobile Money PHP.
- elgiosoft/elgiopay-php-sdk (Packagist) — SDK PHP paiements.

## Recommandation (inchangée)
Recherche produit -> liste commerçants -> `tel:` / `wa.me` ; paiement via agrégateur (Campay/pawaPay/Flutterwave/Dohone) ; Twilio seulement pour appels masqués. Suspendre la routine ou la passer en hebdomadaire.

## Sources
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [elgiopay-php-sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)


---

<!-- source : recherche-apis-github-addendum-82-2026-10-09-netbuis.md -->

# Addendum 82 — APIs GitHub gratuites 2026 (run planifié, 2026-10-09)

## Verdict
Saturation confirmée (addenda 57–81). Architecture inchangée. Pas de notification.

## Pistes mineures nouvelles (vérifier licence et dernier commit avant usage)
- camerpay/php-sdk (Packagist) — SDK PHP paiements Cameroun.
- catidegla/laravel-mobile-money (Packagist) — package Laravel Mobile Money.
- SDK open source MTN MoMo React Native/TypeScript (article dev.to par frankcdr) — utile pour l'app mobile.
- campay (PyPI, v1.0.1) — déjà connu (Campay), client Python.

## Recommandation (inchangée)
Recherche produit -> liste commerçants -> `tel:` / `wa.me` ; paiement via agrégateur (Campay/pawaPay/Flutterwave/Dohone) ; Twilio seulement pour appels masqués. Suspendre la routine ou la passer en hebdomadaire.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [campay PyPI](https://pypi.org/project/campay)
- [SDK MTN MoMo React Native](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)


---

<!-- source : recherche-apis-github-addendum-83-2026-10-09-netbuis.md -->

# Addendum 83 — APIs GitHub gratuites 2026 (run planifié, 2026-10-09)

## Verdict
Saturation confirmée (addenda 57–82). Architecture inchangée. Pas de notification.

## Pistes mineures nouvelles (vérifier licence et dernier commit avant usage)
- ekolotech/mobilemoney-gateway (Packagist) — passerelle PHP multi-opérateurs Mobile Money.
- lepresk/momo-api v1.2.0 — client PHP MTN MoMo.
- zaz-aangaraa/pay (Laravel) — plugin paiement Laravel.
- Guides kolonell.com 2026 : intégration Orange Money API pour boutique au Cameroun, comparatif frais Orange Money vs MTN MoMo à Douala.
- WhatsApp Cloud API : doc « Calling » désormais disponible (appels via Cloud API) — à évaluer ; le lien `wa.me` reste suffisant et gratuit pour le MVP.

## Recommandation (inchangée)
Recherche produit -> liste commerçants -> `tel:` / `wa.me` ; paiement via agrégateur (Campay/pawaPay/Flutterwave/Dohone) ; Twilio seulement pour appels masqués. Suspendre la routine ou la passer en hebdomadaire.

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [lepresk/momo-api](https://phpfreaks.com/news/20216)
- [zaz-aangaraa/pay](https://laraplugins.io/plugins/zaz-aangaraa/pay)
- [Intégrer Orange Money API Cameroun 2026](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [Orange Money vs MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)
- [WhatsApp Cloud API calling](https://www.ycloud.com/blog/whatsapp-business-calling-api.md)


---

<!-- source : recherche-apis-github-addendum-84-2026-10-09-netbuis.md -->

# Addendum 84 — APIs GitHub gratuites 2026 (run planifié, 2026-10-09)

## Verdict
Saturation confirmée. Architecture inchangée. Pas de notification.

## Pistes mineures (vérifier licence/dernier commit avant usage)
- camerpay/php-sdk (Packagist) — SDK PHP paiements Cameroun.
- catidegla/laravel-mobile-money — package Laravel Mobile Money.
- campay (PyPI 1.0.1) — client Python Campay (déjà retenu comme agrégateur).
- DEV.to : SDK open source MTN MoMo React Native/TypeScript — utile pour l'app mobile.
- pytekmomoapi — client Python MoMo.

## Recommandation (inchangée)
Recherche produit -> liste commerçants -> `tel:` / `wa.me`; paiement via Campay/pawaPay/Flutterwave/Dohone; Twilio uniquement pour appels masqués. Suspendre la routine ou la passer en hebdomadaire.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [catidegla/laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [campay PyPI](https://pypi.org/project/campay)
- [SDK MTN MoMo React Native](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)


---

<!-- source : recherche-apis-github-addendum-85-2026-10-10-netbuis.md -->

# Addendum 85 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté majeure. Architecture inchangée. Pas de notification.

## Pistes mineures nouvelles / confirmées
- ekolotech/mobilemoney-gateway (Packagist) — passerelle Mobile Money PHP (à vérifier licence/dernier commit).
- WhatsApp Business Calling API (Cloud API) : guide 2026 — appels via WhatsApp possibles, mais payants/soumis à approbation Meta ; pour aller vite garder `wa.me`.
- Déjà connus : camerpay/php-sdk, campay (PyPI), SDK MTN MoMo React Native (DEV.to), laravel-mobile-money.

## Recommandation (inchangée)
Recherche -> liste commerçants -> `tel:` / `wa.me`; paiement Campay/pawaPay/Flutterwave/Dohone; Twilio seulement pour appels masqués. Passer la routine en hebdomadaire.

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [WhatsApp Business Calling API 2026](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)
- [SDK MTN MoMo RN](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)


---

<!-- source : recherche-apis-github-addendum-86-2026-10-10-netbuis.md -->

# Addendum 86 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté. Mêmes résultats que l'addendum 85. Pas de notification.

## Confirmé (déjà connu)
- Paiement : camerpay/php-sdk, campay (PyPI), ekolotech/mobilemoney-gateway, catidegla/laravel-mobile-money, regisbamba/momoapi-java, pytekmomoapi (MTN MoMo).
- Recherche de commerces locaux : OpenStreetMap/Overpass/Nominatim (gratuit) ; alternatives Apify "Local Business Finder (OSM)" ; marketplaces payantes (Zyla) non nécessaires.

## Recommandation (inchangée)
Recherche produit -> liste commerçants -> `tel:` / `wa.me`; paiement Campay/pawaPay/Flutterwave; Twilio seulement pour appels masqués. Passer la routine en hebdomadaire/mensuelle (rendements nuls depuis de nombreux passages).

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [momoapi-java](https://github.com/regisbamba/momoapi-java)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)
- [Local Business Finder OSM](https://apify.com/technicaldost/osm-local-business-finder/api)


---

<!-- source : recherche-apis-github-addendum-87-2026-10-10-netbuis.md -->

# Addendum 87 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté. Mêmes résultats que l'addendum 86 (camerpay/php-sdk, campay, ekolotech/mobilemoney-gateway, guides Kolonell Orange Money vs MTN MoMo Cameroun 2026, WhatsApp Business Calling API). Pas de notification.

## Recommandation (inchangée)
Recherche produit -> liste commerçants (OSM/Overpass) -> `tel:` / `wa.me`; paiement Campay/pawaPay/Flutterwave; Twilio seulement pour appels masqués. Passer la routine en hebdomadaire/mensuelle : rendement nul depuis de nombreux passages.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay)
- [Orange Money vs MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)
- [WhatsApp Business Calling API 2026](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)


---

<!-- source : recherche-apis-github-addendum-88-2026-10-10-netbuis.md -->

# Addendum 88 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté significative. Mêmes résultats que l'addendum 87 (camerpay/php-sdk, campay PyPI, guides Kolonell, WhatsApp Business Calling). Paquets secondaires revus, sans changement de recommandation : catidegla/laravel-mobile-money, elgiosoft/elgiopay-php-sdk, dohone-sdk (npm). Pas de notification.

## Recommandation (inchangée)
Recherche produit -> liste commerçants (OSM/Overpass) -> `tel:` / `wa.me`; paiement Campay/pawaPay/Flutterwave; Twilio seulement pour appels masqués. Routine à passer en hebdomadaire/mensuelle : rendement nul.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [elgiopay-php-sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [WhatsApp Business Calling (Twilio)](https://www.twilio.com/en-us/voice/whatsapp-business-calling)


---

<!-- source : recherche-apis-github-addendum-89-2026-10-10-netbuis.md -->

# Addendum 89 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté décisive. Mêmes résultats que l'addendum 88 (camerpay/php-sdk, campay PyPI, elgiopay). Pistes secondaires revues : hachther/mesomb-js-client (agrégateur MeSomb, MTN/Orange Cameroun, client JS), ekolotech/mobilemoney-gateway (Packagist), module Odoo enkap_mobile_money. Côté recherche locale : Nominatim / Overpass (OSM) restent la base gratuite pour la liste des commerçants. Pas de notification.

## Recommandation (inchangée)
Recherche produit -> liste commerçants (OSM/Overpass) -> `tel:` / `wa.me`; paiement Campay/MeSomb/pawaPay/Flutterwave; Twilio seulement pour appels masqués. Routine à espacer (hebdo/mensuel).

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [mesomb-js-client](https://github.com/hachther/mesomb-js-client)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [enkap_mobile_money (Odoo)](https://apps.odoo.com/apps/modules/18.0/enkap_mobile_money)
- [Nominatim](https://github.com/osm-search/nominatim)


---

<!-- source : recherche-apis-github-addendum-90-2026-10-10-netbuis.md -->

# Addendum 90 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté décisive. Mêmes résultats que l'addendum 89 (camerpay/php-sdk, campay PyPI, elgiopay, ekolotech/mobilemoney-gateway, enkap_mobile_money). Pistes secondaires vues : catidegla/laravel-mobile-money (Packagist), norrisboat/MobileMoneySDK (GitHub, SDK Kotlin multiplateforme MoMo, à vérifier avant usage). Côté liste de commerçants : OSM/Overpass reste la base gratuite (connecteurs Apify payants non nécessaires). Pas de notification.

## Recommandation (inchangée)
Recherche produit -> commerçants (OSM/Overpass) -> `tel:` / `wa.me`; paiement Campay/MeSomb/pawaPay/Flutterwave; Twilio seulement pour appels masqués. Routine à espacer (hebdo/mensuel).

## Sources
- [catidegla/laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [norrisboat/MobileMoneySDK](https://github.com/norrisboat/MobileMoneySDK)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [Is there an OSM POI API?](https://openplacesapi.com/blog/openstreetmap-poi-api)


---

<!-- source : recherche-apis-github-addendum-91-2026-10-10-netbuis.md -->

# Addendum 91 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté décisive. Mêmes résultats que l'addendum 90 (camerpay/php-sdk, campay PyPI, elgiopay, ekolotech/mobilemoney-gateway, enkap_mobile_money). Pistes secondaires seulement : regisbamba/momoapi-java (SDK MTN MoMo Java), article DEV.to sur un SDK open source MTN MoMo React Native/TypeScript (utile pour l'app mobile, à vérifier avant usage). Annuaire commerçants : OSM/Overpass reste la base gratuite. Pas de notification.

## Recommandation (inchangée)
Recherche produit -> commerçants (OSM/Overpass) -> `tel:` / `wa.me`; paiement Campay/MeSomb/pawaPay/Flutterwave; Twilio seulement pour appels masqués. Routine à espacer (hebdo/mensuel).

## Sources
- [regisbamba/momoapi-java](https://github.com/regisbamba/momoapi-java)
- [SDK MTN MoMo React Native/TS](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)


---

<!-- source : recherche-apis-github-addendum-92-2026-10-10-netbuis.md -->

# Addendum 92 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté décisive. Résultats identiques aux addenda 90-91 (camerpay/php-sdk, campay PyPI, ekolotech/mobilemoney-gateway). Seul point à noter : pytekmomoapi (docs readthedocs, wrapper Python MTN MoMo) et la page "MoMo SDKs" du MTN MoMo Developer Community — à vérifier avant usage. Annuaire commerçants : OSM Overpass / Nominatim restent la base gratuite (pas de clé).

## Recommandation (inchangée)
Recherche produit -> commerçants (OSM/Overpass) -> `tel:` / `wa.me`; paiement Campay/MeSomb/pawaPay/Flutterwave; Twilio seulement pour appels masqués. Routine à espacer (hebdo/mensuel). Pas de notification.

## Sources
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)
- [MoMo SDKs (MTN community)](https://momodevelopercommunity.mtn.com/product-updates/momo-sdks-133)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [Nominatim API](https://nominatim.org/release-docs/4.3/api/Overview/)


---

<!-- source : recherche-apis-github-addendum-93-2026-10-10-netbuis.md -->

# Addendum 93 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté décisive. Mêmes résultats que les addenda 90-92 (ekolotech/mobilemoney-gateway, camerpay/php-sdk, campay PyPI, pytekmomoapi). Seul ajout mineur : norrisboat/MobileMoneySDK (GitHub, SDK mobile money générique — à évaluer, non vérifié pour le Cameroun) et un article DEV sur un SDK open source MTN MoMo React Native/TypeScript (utile pour l'app mobile).

## Recommandation (inchangée)
Recherche produit -> commerçants (OSM/Overpass/Nominatim) -> `tel:` / `wa.me`; paiement Campay/MeSomb/pawaPay/Flutterwave; Twilio seulement pour appels masqués. Routine à espacer (hebdo/mensuel) : les recherches sont saturées.

## Sources
- [norrisboat/MobileMoneySDK](https://github.com/norrisboat/MobileMoneySDK)
- [SDK MTN MoMo React Native/TS (DEV)](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)


---

<!-- source : recherche-apis-github-addendum-94-2026-10-10-netbuis.md -->

# Addendum 94 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Recherche saturée, aucune nouveauté décisive. Résultats identiques aux addenda 90-93 (camerpay/php-sdk, ekolotech/mobilemoney-gateway, campay PyPI, pytekmomoapi). Seuls ajouts mineurs, non vérifiés pour le Cameroun : elgiosoft/elgiopay-php-sdk (Packagist), crate Rust `mtnmomo`, et l'article Kolonell sur l'API MTN MoMo (Ghana/Côte d'Ivoire 2026). Recherche WhatsApp/annuaire local : rien de pertinent (templates payants CodeCanyon, paquets npm WhatsApp Cloud API génériques).

## Recommandation (inchangée)
Recherche produit -> commerçants (OSM/Overpass/Nominatim) -> `tel:` / `wa.me`; paiement Campay/MeSomb/pawaPay/Flutterwave; Twilio seulement pour appels masqués. Espacer la routine (hebdo/mensuel).

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)
- [elgiosoft/elgiopay-php-sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [crate mtnmomo](https://packages.ecosyste.ms/registries/crates.io/packages/mtnmomo)
- [Kolonell MTN MoMo API 2026](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)


---

<!-- source : recherche-apis-github-addendum-95-2026-10-10-netbuis.md -->

# Addendum 95 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Recherche saturée, aucune nouveauté décisive. Mêmes résultats que les addenda 90-94 (camerpay/php-sdk, ekolotech/mobilemoney-gateway, campay PyPI, pytekmomoapi).

Ajouts mineurs non vérifiés pour le Cameroun :
- SDK open source MTN MoMo React Native/TypeScript (article DEV Community) — potentiellement utile côté app mobile.
- zaz-aangaraa/pay (plugin Laravel, laraplugins.io).
- Article Kolonell : Orange Money vs MTN MoMo Cameroun/Douala, frais 2026.
- Annuaire WhatsApp / scrapers annuaires : rien de pertinent et réutilisable.

## Recommandation (inchangée)
Recherche produit -> commerçants (OSM/Overpass/Nominatim) -> `tel:` / `wa.me`; paiement Campay/MeSomb/pawaPay/Flutterwave; Twilio seulement pour appels masqués. Espacer la routine (hebdo/mensuel) : les passages quotidiens n'apportent plus rien.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)
- [SDK MTN MoMo RN/TS (DEV)](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [zaz-aangaraa/pay](https://laraplugins.io/plugins/zaz-aangaraa/pay)
- [Kolonell Orange Money vs MTN MoMo Cameroun](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)


---

<!-- source : recherche-apis-github-addendum-96-2026-10-10-netbuis.md -->

# Addendum 96 — APIs GitHub gratuites 2026 — 2026-10-10 (run planifié)

## Verdict
Aucune nouveauté. Deux recherches (alternatives open source WhatsApp/Twilio/telephonie ; annonces pawaPay/Campay/Notch Pay) ne renvoient que des familles déjà couvertes : WAHA / Evolution API (WhatsApp non officiel, risque de ban → préférer WhatsApp Cloud API officielle), FreeSWITCH / Kamailio (VoIP auto-hébergé, alternatives à Twilio), changelog Notch Pay sans élément exploitable.

## Recommandation
Saturation confirmée : suspendre ou passer ce run en hebdomadaire. Aucune notification envoyée (rien de nouveau).

## Sources
- [WAHA API](https://railway.com/deploy/waha-api.md)
- [Evolution API alternatives 2026](https://www.indiehackers.com/post/best-10-evolution-api-alternatives-in-2026-tested-9fc702d744)
- [FreeSWITCH alternatives](https://opensource.builders/os-alternatives/freeswitch)
- [7 best WhatsApp APIs 2026](https://dev.to/kevin_menesesgonzlez/7-best-whatsapp-apis-for-developers-in-2026-compared-f6)


---

<!-- source : recherche-apis-github-addendum-97-2026-10-10-netbuis.md -->

# Addendum 97 — APIs GitHub gratuites 2026 — 2026-10-10 (run planifié)

## Verdict
Aucune nouveauté. Deux recherches (SDK mobile money Cameroun MTN/Orange ; alternatives open source à Twilio / click-to-call) ne renvoient que des éléments déjà couverts : campay, camerpay/php-sdk, ekolotech/mobilemoney-gateway, laravel-mobile-money, SDK React Native MoMo (paiement) ; Fonoster, neoms/tiniyo, FreeSWITCH (voix, plan B, cf. addenda 17, 20, 38).

## Décisions inchangées
Appel direct tel: + wa.me (gratuits), CamPay + TranZak (PayUnit en option), Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix.

## Recommandation
Saturation confirmée : suspendre la routine ou la passer en hebdomadaire et lancer le jalon 0 (30 commerçants). Aucune notification envoyée.

## Sources
- [campay (PyPI)](https://pypi.org/project/campay)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [Fonoster](https://blog.brightcoding.dev/2026/10/03/fonosterfonoster-the-open-source-alternative-to-twilio-for-programmable-voice)
- [SDK MTN MoMo React Native](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)


---

<!-- source : recherche-apis-github-addendum-98-2026-10-10-netbuis.md -->

# Addendum 98 — APIs GitHub gratuites 2026 — 2026-10-10 (run planifié)

## Verdict
Aucune nouveauté. Deux recherches (APIs/SDK Cameroun Orange Money/MTN MoMo/WhatsApp ; nouveaux SDK mobile money Afrique oct. 2026) ne renvoient que des éléments déjà connus : campay (PyPI), payunit (RubyGems), zaz-aangaraa/pay (Laravel), elgiosoft/elgiopay-php-sdk, SDK MTN MoMo React Native, pesaPi, ultraner/sdk, Klasha payout (hors périmètre : décaissements multi-pays).

## Décisions inchangées
Appel direct tel: + wa.me (gratuits), CamPay + TranZak (PayUnit en option), Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix.

## Recommandation
Saturation confirmée : suspendre la routine ou la passer en hebdomadaire et lancer le jalon 0 (30 commerçants). Aucune notification envoyée.

## Sources
- [campay (PyPI)](https://pypi.org/project/campay)
- [payunit (RubyGems)](https://rubygems.org/gems/payunit)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [pesaPi](https://github.com/pluspeople/pesaPi)
- [SDK MTN MoMo React Native](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)


---

<!-- source : recherche-apis-github-addendum-99-2026-10-10-netbuis.md -->

# Addendum 99 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté. Deux recherches (SDK mobile money Cameroun ; annuaire local / WhatsApp / click-to-call) ne renvoient que des éléments déjà documentés : catidegla/laravel-mobile-money, digitalpaye-php, camerpay/php-sdk, dohone-sdk, campay (PyPI), ekolotech/mobilemoney-gateway, pytekmomoapi, cauris, SDK MTN MoMo React Native. Annuaire : rien de supérieur à OSM/Overpass + PostGIS (Apify « OSM local business finder » = payant à l'usage, inutile).

## Décisions inchangées
tel: + wa.me (gratuits), CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix.

## Recommandation
Suspendre la routine ou la passer en hebdomadaire ; lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [Apify OSM local business finder](https://apify.com/technicaldost/osm-local-business-finder/api)


---

<!-- source : recherche-apis-github-addendum-101-2026-10-10-netbuis.md -->

# Addendum 101 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Pas de changement de décision. Seuls éléments non listés avant (mineurs, agrégateurs/SDK redondants avec CamPay/TranZak) : elgiosoft/elgiopay-php-sdk, zaz-aangaraa/pay (Laravel), enkap_mobile_money (module Odoo 18), pay_unit_sdk (Dart/Flutter, à vérifier avant usage). Côté voix/WhatsApp : WhatsApp Business Calling API (Cloud API) existe mais payant/vérification entreprise ; garder tel: + wa.me gratuits.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix.

## Recommandation
Suspendre la routine ou la passer en hebdomadaire ; lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [elgiopay-php-sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [zaz-aangaraa/pay](https://laraplugins.io/plugins/zaz-aangaraa/pay)
- [enkap mobile money (Odoo)](https://apps.odoo.com/apps/modules/18.0/enkap_mobile_money)
- [pay_unit_sdk](https://depscope.dev/pkg/pub/pay_unit_sdk)
- [WhatsApp Business Calling API 2026](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)


---

<!-- source : recherche-apis-github-addendum-102-2026-10-10-netbuis.md -->

# Addendum 102 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté décisive. Les recherches (mobile money Cameroun, annuaire/géoloc commerces) ne remontent que des éléments déjà listés ou redondants : campay (PyPI), dohone-sdk (npm), camerpay/php-sdk, ekolotech/mobilemoney-gateway (Packagist), elgiopay-php-sdk, enkap_mobile_money (Odoo), SDK MTN MoMo React Native/TypeScript (dev.to), scrapers OSM/Google Maps (non recommandés : CGU/fragilité).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix.

## Recommandation
Suspendre cette routine (rendement nul depuis plusieurs passages) et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [SDK MTN MoMo RN/TS](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)


---

<!-- source : recherche-apis-github-addendum-103-2026-10-10-netbuis.md -->

# Addendum 103 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté décisive. Seuls éléments mineurs repérés : gem Ruby `payunit` et `campay` (RubyGems), `lepresk/momo-api` v1.2.0 (PHP, MTN MoMo), agrégateurs Zylalabs / AfriGIS (payants ou hors Cameroun, non retenus).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix.

## Recommandation
Suspendre cette routine (rendement nul) et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [lepresk/momo-api v1.2.0](https://phpfreaks.com/news/20216)
- [payunit gem](https://rubygems.org/gems/payunit)
- [campay gem](https://rubygems.org/gems/campay)
- [elgiopay-php-sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)


---

<!-- source : recherche-apis-github-addendum-104-2026-10-10-netbuis.md -->

# Addendum 104 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté décisive. Éléments mineurs repérés : `camerpay/php-sdk` et `ekolotech/mobilemoney-gateway` (Packagist, PHP), `campay` PyPI (déjà retenu), `pywa` (module Calls WhatsApp Business, 3.0 RC — utile seulement si appel via WhatsApp Cloud API un jour), articles Kolonell sur MoMo/Orange Money Cameroun (frais 2026).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix.

## Recommandation
Routine à rendement nul : la suspendre et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay)
- [pywa Calls](https://pywa.readthedocs.io/en/3.0.0-rc.3/_sources/content/calls/overview.rst)
- [Kolonell Orange Money vs MoMo Cameroun 2026](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)


---

<!-- source : recherche-apis-github-addendum-105-2026-10-10-netbuis.md -->

# Addendum 105 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté. Les recherches (SDK mobile money Cameroun, alternatives Twilio/WhatsApp Afrique) ne remontent que des projets déjà connus : ngambmicheal/mobilemoney, catidegla/laravel-mobile-money, camerpay/php-sdk, ekolotech/mobilemoney-gateway, campay (PyPI), MobileMoneySDK (norrisboat), momoapi-java, pytekmomoapi, guides Chakra HQ / YCloud sur WhatsApp API.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix.

## Recommandation
Routine à rendement nul depuis plusieurs passages : la suspendre et démarrer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [ngambmicheal/mobilemoney](https://github.com/ngambmicheal/mobilemoney)
- [catidegla/laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [norrisboat/MobileMoneySDK](https://github.com/norrisboat/MobileMoneySDK)
- [regisbamba/momoapi-java](https://github.com/regisbamba/momoapi-java)
- [Top 10 WhatsApp API Africa 2026](https://chakrahq.com/article/top-10-whatsapp-api-solutions-in-africa-2026/)


---

<!-- source : recherche-apis-github-addendum-106-2026-10-10-netbuis.md -->

# Addendum 106 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté. Les recherches ne remontent que des projets déjà connus : camerpay/php-sdk, ekolotech/mobilemoney-gateway, campay (PyPI), pytekmomoapi, elgiopay php-sdk, netflie/whatsapp-cloud-api, guides Chakra HQ sur WhatsApp API Afrique 2026.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix.

## Recommandation
Routine à rendement nul : suspendre et démarrer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay)
- [netflie/whatsapp-cloud-api](https://gittrend.io/repo/netflie/whatsapp-cloud-api)
- [Top 10 WhatsApp API Africa 2026](https://chakrahq.com/article/top-10-whatsapp-api-solutions-in-africa-2026/)


---

<!-- source : recherche-apis-github-addendum-107-2026-10-10-netbuis.md -->

# Addendum 107 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté décisive. Mêmes résultats que l'addendum 106 (camerpay/php-sdk, ekolotech/mobilemoney-gateway, campay PyPI, pytekmomoapi). Seuls éléments mineurs, non bloquants : un SDK MTN MoMo React Native/TypeScript open source (article dev.to), momoapi-java (regisbamba), plugin Laravel zaz-aangaraa/pay. À garder comme références d'implémentation, sans changer les décisions.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics. Fonoster = plan B voix.

## Recommandation
Rendement quasi nul : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [momoapi-java](https://github.com/regisbamba/momoapi-java)
- [SDK MTN MoMo React Native (dev.to)](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [zaz-aangaraa/pay](https://laraplugins.io/plugins/zaz-aangaraa/pay)


---

<!-- source : recherche-apis-github-addendum-108-2026-10-10-netbuis.md -->

# Addendum 108 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté décisive. Résultats identiques à l'addendum 107, avec deux références mineures supplémentaires : dohone-sdk (npm, agrégateur paiement Cameroun/Afrique francophone) et elgiosoft/elgiopay-php-sdk (Packagist). Utiles uniquement comme plan B de paiement si CamPay/TranZak posent problème. Africa's Talking Voice API reste une alternative voix déjà connue (plan B avec Fonoster).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Rendement nul : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [dohone-sdk (npm)](https://www.npmjs.org/package/dohone-sdk)
- [elgiopay-php-sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [Africa's Talking Voice API](https://dev.to/arseytech/from-code-to-conversation-mastering-africas-talking-voice-api-4aa8)


---

<!-- source : recherche-apis-github-addendum-109-2026-10-10-netbuis.md -->

# Addendum 109 — APIs GitHub gratuites 2026 (run planifié, 2026-10-10)

## Verdict
Aucune nouveauté décisive. Trois références mineures en plus de l'addendum 108 :
- ekolotech/mobilemoney-gateway (Packagist) : passerelle Mobile Money générique PHP.
- trustpayway-sdk (npm) : SDK paiement, plan B uniquement.
- SDK open source MTN MoMo pour React Native/TypeScript (dev.to) : utile comme exemple d'intégration côté app.
WhatsApp Cloud API / Twilio WhatsApp Calling : pas de changement par rapport aux notes précédentes.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Rendement quasi nul : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [trustpayway-sdk](https://app.unpkg.com/trustpayway-sdk@1.0.7/files/README.md)
- [SDK MTN MoMo React Native](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [campay PyPI](https://pypi.org/project/campay)
- [Twilio WhatsApp Calling](https://static0.twilio.com/en-us/changelog/whatsapp_business_calling_available)


---

<!-- source : recherche-apis-github-addendum-110-2026-10-11-netbuis.md -->

# Addendum 110 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté décisive. Deux références mineures nouvelles par rapport à l'addendum 109 :
- camerpay/php-sdk (Packagist) : SDK PHP pour paiements Cameroun, plan B si backend PHP (non retenu : backend Django).
- mtn_momo_sdk (pub.dev) : SDK Flutter MTN MoMo, version 0.0.1 très jeune ; à n'utiliser que comme exemple si l'app est en Flutter.
Rien de nouveau côté WhatsApp / appel direct.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Rendement quasi nul : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [mtn_momo_sdk](https://pub.dev/packages/mtn_momo_sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)


---

<!-- source : recherche-apis-github-addendum-111-2026-10-11-netbuis.md -->

# Addendum 111 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté décisive. Mêmes résultats que l'addendum 110. Références mineures (non retenues) :
- SDK open source MTN MoMo React Native/TypeScript (article DEV Community) : exemple si l'app est en React Native.
- elgiosoft/elgiopay-php-sdk (Packagist) : agrégateur PHP, hors stack Django.
- pub.dev `whatsapp` 4.0.0 : package Flutter pour l'API WhatsApp Cloud ; inutile tant que wa.me suffit.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Rendement nul : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [DEV Community — SDK MTN MoMo RN/TS](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [pub.dev whatsapp changelog](https://pub-web-s1.flutter-io.cn/packages/whatsapp/changelog)
- [campay PyPI](https://pypi.org/project/campay)


---

<!-- source : recherche-apis-github-addendum-112-2026-10-11-netbuis.md -->

# Addendum 112 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté. Les recherches (mobile money Cameroun / CamPay / TranZak ; API recherche commerces locaux / click-to-call Afrique) ne renvoient que des résultats déjà connus : campay (PyPI), camerpay/php-sdk et elgiopay (Packagist, hors stack Django), plugins WordPress CamPay, Africa's Talking, AfriGIS (Afrique du Sud, payant), Apify OSM Local Business Finder (scraper, non retenu).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Rendement nul (cf. addendum 111) : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [TranZak — API Evangelist](https://providers.apievangelist.com/providers/tranzak/)
- [Annuaire des API africaines](https://afrotools.com/fr/tools/annuaire-api-africaines/)
- [Apify OSM Local Business Finder](https://apify.com/technicaldost/osm-local-business-finder/api)


---

<!-- source : recherche-apis-github-addendum-113-2026-10-11-netbuis.md -->

# Addendum 113 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté exploitable. Deux recherches (SDK mobile money Cameroun ; géocodage / recherche commerces / click-to-call Afrique) ne renvoient que des éléments déjà connus ou hors stack.

## Éléments vus (non retenus)
- catidegla/laravel-mobile-money, ekolotech/mobilemoney-gateway, camerpay/php-sdk, elgiopay : PHP/Laravel, hors stack Django.
- pytekmomoapi : wrapper Python MTN MoMo, redondant avec CamPay/TranZak.
- Geokeo (2500 requêtes/jour gratuites) : géocodage, redondant avec Nominatim/MapLibre/PostGIS déjà décidés.
- Apify OSM Local Business Finder : scraper, non retenu.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Rendement nul (cf. addenda 111-112) : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [Geokeo](https://public-api.org/api/675/geokeo)
- [campay PyPI](https://pypi.org/project/campay)


---

<!-- source : recherche-apis-github-addendum-114-2026-10-11-netbuis.md -->

# Addendum 114 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté exploitable. Deux recherches (SDK mobile money Cameroun ; recherche commerces / click-to-call / WhatsApp Afrique) ne renvoient que des éléments déjà vus (camerpay/php-sdk, ekolotech/mobilemoney-gateway, campay PyPI, pytekmomoapi) ou des articles marketing de BSP WhatsApp payants (ChakraHQ), hors périmètre gratuit.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Rendement nul (cf. addenda 111-113) : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [ChakraHQ WhatsApp Africa 2026](https://chakrahq.com/article/top-10-whatsapp-api-solutions-in-africa-2026/)


---

<!-- source : recherche-apis-github-addendum-115-2026-10-11-netbuis.md -->

# Addendum 115 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Quasi aucune nouveauté. Deux recherches (wrappers Orange Money/MTN MoMo ; recherche commerces / click-to-call / WhatsApp en React Native). Seuls éléments non listés avant, à titre indicatif (non vérifiés en profondeur, usage secondaire) :
- roazagba/apimtnmomo (Packagist) — wrapper PHP MTN MoMo, utile seulement si backend PHP (notre choix = Django).
- lickayemassane/momo-payment (Packagist) — idem, PHP.
- mtn_momo_sdk (pub.dev) — SDK Dart/Flutter MTN MoMo v0.0.1, trop immature ; paiement doit rester côté serveur (CamPay/TranZak).
- DEV.to : SDK open source MTN MoMo React Native/TypeScript — à surveiller, mais clés API ne doivent jamais être dans l'app mobile.
Le reste = déjà vu (camerpay/php-sdk, ekolotech/mobilemoney-gateway) ; la recherche WhatsApp/RN ne retourne que du bruit (pages RapidNative génériques).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Rendement quasi nul (cf. addenda 111-114) : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [roazagba/apimtnmomo](https://packagist.org/packages/roazagba/apimtnmomo)
- [lickayemassane/momo-payment](https://packagist.org/packages/lickayemassane/momo-payment)
- [mtn_momo_sdk Dart/Flutter](https://pub.dev/documentation/mtn_momo_sdk/0.0.1/)
- [SDK MTN MoMo React Native (DEV)](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)


---

<!-- source : recherche-apis-github-addendum-116-2026-10-11-netbuis.md -->

# Addendum 116 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Quasi aucune nouveauté. Deux recherches (mobile money Cameroun / click-to-call ; recherche marketplace / WhatsApp Cloud API).
Éléments à titre indicatif, non vérifiés en profondeur, usage secondaire :
- elgiosoft/elgiopay-php-sdk (Packagist) — SDK PHP, hors stack (Django).
- lepresk/momo-api v1.2.0 — wrapper PHP MTN MoMo, idem.
- enkap mobile money (module Odoo 18) — hors périmètre.
- Gem Ruby `campay` — confirme l'écosystème CamPay, sans intérêt pour Django.
- Articles kolonell.com (Orange Money vs MTN MoMo Douala, frais 2026) — à lire éventuellement pour la comparaison de frais.
La 2e recherche ne renvoie que du bruit (GitHub Marketplace génériques).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Rendement nul (cf. addenda 111-115) : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [lepresk/momo-api](https://phpfreaks.com/news/20216)
- [enkap mobile money](https://apps.odoo.com/apps/modules/18.0/enkap_mobile_money)
- [campay gem](https://rubygems.org/gems/campay?locale=fr)
- [Orange Money vs MTN MoMo Douala 2026](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)


---

<!-- source : recherche-apis-github-addendum-117-2026-10-11-netbuis.md -->

# Addendum 117 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Rendement quasi nul (cf. addenda 111-116). Deux recherches (SDK mobile money Cameroun ; alternatives open source Twilio / WhatsApp).
Éléments indicatifs, non vérifiés en profondeur :
- pytekmomoapi (Python, readthedocs) — wrapper MTN MoMo en Python, compatible Django ; à comparer avec CamPay/TranZak avant tout usage, secondaire.
- camerpay/php-sdk, ekolotech/mobilemoney-gateway — PHP, hors stack.
- Fonoster — alternative open source à Twilio (voix programmable) ; piste de repli si les coûts Twilio deviennent un problème, pas nécessaire pour le MVP (tel: + wa.me).
- SDK React Native/TypeScript MTN MoMo (dev.to) — exemple, non retenu.
- Gem/paquet `campay` (PyPI) — confirme l'écosystème CamPay.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay)
- [Fonoster](https://glama.ai/mcp/servers/@fonoster/fonoster/tree)
- [MTN MoMo SDK RN/TS](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)


---

<!-- source : recherche-apis-github-addendum-118-2026-10-11-netbuis.md -->

# Addendum 118 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté. Deux recherches (SDK mobile money Cameroun ; annuaires locaux / WhatsApp / click-to-call) ne renvoient que des résultats déjà vus dans les addenda 111-117 : camerpay/php-sdk, ekolotech/mobilemoney-gateway, pytekmomoapi, campay (PyPI), SDK MTN MoMo RN/TS. Rien d'exploitable en plus.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Suspendre cette routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)


---

<!-- source : recherche-apis-github-addendum-119-2026-10-11-netbuis.md -->

# Addendum 119 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté. Deux recherches (SDK mobile money Cameroun ; annuaire local / WhatsApp Business / click-to-call) ne renvoient que des résultats déjà vus : camerpay/php-sdk, ekolotech/mobilemoney-gateway, campay (PyPI), pytekmomoapi, SDK MTN MoMo RN, guides WhatsApp Business génériques. Rien d'exploitable en plus.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Suspendre cette routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)


---

<!-- source : recherche-apis-github-addendum-120-2026-10-11-netbuis.md -->

# Addendum 120 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté exploitable. Deux recherches (SDK/marketplace/annuaire Cameroun ; géoloc/click-to-call/WhatsApp Cloud API) ne renvoient que du déjà vu (camerpay/php-sdk, CamPay, agrégateurs génériques d'API de géolocalisation IP). Seul nom non listé : elgiosoft/elgiopay-php-sdk (SDK PHP générique, non prioritaire, stack Django retenue).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Suspendre cette routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [Kolonell e-commerce Cameroun 2026](https://kolonell.com/fr/blog/ecommerce-cameroun-orange-money-cm-mtn-momo-livraison-douala-yaounde-2026)


---

<!-- source : recherche-apis-github-addendum-121-2026-10-11-netbuis.md -->

# Addendum 121 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté exploitable. Deux recherches (SDK Orange Money/MTN MoMo Cameroun ; annuaire local/géoloc/WhatsApp Afrique) ne renvoient que du déjà connu : CamPay (PyPI campay), SDK MTN MoMo générique (Dart/Flutter, Python pytekmomoapi), articles comparatifs WhatsApp API Afrique. Rien qui change les décisions.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Suspendre cette routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [mtn_momo_sdk Dart](https://pub.dev/packages/mtn_momo_sdk)
- [WhatsApp API Afrique 2026](https://chakrahq.com/article/top-10-whatsapp-api-solutions-in-africa-2026/)


---

<!-- source : recherche-apis-github-addendum-122-2026-10-11-netbuis.md -->

# Addendum 122 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté qui change les décisions. Deux recherches (SDK mobile money Cameroun ; annuaire local/WhatsApp/géoloc Afrique).

## Éléments secondaires repérés (à ne pas adopter, simple veille)
- dohone-sdk (npm) : agrégateur Dohone, alternative de repli à CamPay/TranZak.
- camerpay/php-sdk (Packagist), ekolotech/mobilemoney-gateway, catidegla/laravel-mobile-money : wrappers PHP/Laravel, inutiles avec la stack Django.
- DEV.to : SDK open source MTN MoMo React Native/TypeScript (utile seulement si front RN).
- Annuaires WhatsApp (Techzim, DigiDirectory) : confirment le modèle, aucune API réutilisable.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Suspendre cette routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [SDK MTN MoMo RN/TS](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [Techzim annuaire WhatsApp](https://techzim.co.zw/local-company-develops-free-business-directory-thats-accessible-via-whatsapp)


---

<!-- source : recherche-apis-github-addendum-123-2026-10-11-netbuis.md -->

# Addendum 123 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté. Deux recherches (SDK mobile money Cameroun ; annuaire local / géoloc / WhatsApp Afrique) : mêmes résultats que l'addendum 122 (camerpay php-sdk, ekolotech/mobilemoney-gateway, catidegla/laravel-mobile-money, campay PyPI, pytekmomoapi, annuaires WhatsApp Techzim/DigiDirectory, marketplace Zyla).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Suspendre cette routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [Techzim annuaire WhatsApp](https://techzim.co.zw/local-company-develops-free-business-directory-thats-accessible-via-whatsapp)


---

<!-- source : recherche-apis-github-addendum-124-2026-10-11-netbuis.md -->

# Addendum 124 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté décisive. Mêmes résultats que l'addendum 123 (camerpay php-sdk, ekolotech/mobilemoney-gateway, catidegla/laravel-mobile-money, campay PyPI).

Pistes mineures à titre indicatif (non retenues, hors Cameroun ou non vérifiées) :
- SDK open source MTN MoMo React Native/TypeScript (article DEV Community) : utile comme référence de code pour l'intégration côté app, à vérifier avant usage.
- Apify « Local Business Finder (OSM) » et AllBusiness.africa (plan Explorer gratuit) : sources possibles pour pré-remplir l'annuaire de commerçants, à tester au jalon 0.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Suspendre cette routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée (rien de nouveau).

## Sources
- [Packagist catidegla/laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [Packagist camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [Packagist ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay)
- [DEV: SDK open source MTN MoMo React Native](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [Apify OSM Local Business Finder](https://apify.com/technicaldost/osm-local-business-finder/api)
- [AllBusiness.africa Explorer](https://allbusiness.africa/plan-explorer)


---

<!-- source : recherche-apis-github-addendum-125-2026-10-11-netbuis.md -->

# Addendum 125 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté décisive. Mêmes résultats que l'addendum 124. Seul élément marginal : elgiosoft/elgiopay-php-sdk (Packagist), non vérifié, non retenu ; OpenStreetMap Scraper (Apify) déjà couvert par la piste OSM.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Suspendre cette routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée (rien de nouveau).

## Sources
- [Packagist elgiosoft/elgiopay-php-sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [Packagist camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [Apify OpenStreetMap POI Scraper](https://apify.com/logiover/openstreetmap-business-poi-scraper)


---

<!-- source : recherche-apis-github-addendum-126-2026-10-11-netbuis.md -->

# Addendum 126 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté. Les recherches (SDK mobile money Cameroun ; annuaire local/géoloc/click-to-call) renvoient les mêmes résultats que les addenda 124-125 : CamPay (PyPI/Packagist/WordPress), TranZak, elgiopay (non vérifié), OSM Local Business Finder (Apify, piste OSM déjà couverte).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Suspendre cette routine de recherche (rendements nuls) et lancer le jalon 0 : 30 commerçants pilotes. Aucune notification envoyée (rien de nouveau).

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [TranZak (apis.io)](https://apis.io/providers/tranzak/)
- [OSM Local Business Finder](https://apify.com/technicaldost/osm-local-business-finder/api)


---

<!-- source : recherche-apis-github-addendum-127-2026-10-11-netbuis.md -->

# Addendum 127 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Quasi aucune nouveauté. Trois pistes mineures vues (non vérifiées en profondeur) :
- ekolotech/mobilemoney-gateway (Packagist) : passerelle PHP multi-opérateurs mobile money, alternative à CamPay si backend Laravel/PHP.
- pytekmomoapi (ReadTheDocs) : wrapper Python MTN MoMo (sandbox gratuit), utile pour prototyper.
- SDK open source MTN MoMo React Native/TypeScript (DEV Community) : à évaluer pour l'app mobile, vérifier licence et maintenance.
- Geoapify Open Geospatial Program : quota gratuit géocodage/cartes, alternative à MapLibre/PMTiles si besoin d'API hébergée.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)
- [SDK MTN MoMo RN/TS](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [Geoapify Open Geospatial Program](https://www.geoapify.com/open-geospatial-program/)
- [campay PyPI](https://pypi.org/project/campay)


---

<!-- source : recherche-apis-github-addendum-128-2026-10-11-netbuis.md -->

# Addendum 128 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté majeure. Décisions inchangées (tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics).

## Pistes mineures revues (non vérifiées en profondeur : licence/maintenance à contrôler)
- camerpay/php-sdk (Packagist) : SDK PHP paiement Cameroun, alternative si backend PHP.
- dohone-sdk (npm) : SDK Node pour Dohone (agrégateur mobile money), repli possible à CamPay/TranZak.
- catidegla/laravel-mobile-money (Packagist) : package Laravel mobile money multi-opérateurs.
- Déjà notés : ekolotech/mobilemoney-gateway, pytekmomoapi, campay (PyPI).
- WhatsApp Business Calling API (Cloud API) : existe en 2026, mais appels soumis à conditions Meta ; wa.me reste le chemin gratuit rapide.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [WhatsApp Calling API 2026](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)


---

<!-- source : recherche-apis-github-addendum-129-2026-10-11-netbuis.md -->

# Addendum 129 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté. Deux recherches (SDK mobile money Cameroun ; WhatsApp Cloud API / click-to-call / annuaires) ne renvoient que des éléments déjà documentés (campay, dohone-sdk, camerpay/php-sdk, ekolotech/mobilemoney-gateway, elgiopay, SDK MTN MoMo RN/TS, WhatsApp Calling API).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Rendement nul (saturation depuis les addenda ~57+) : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [WhatsApp Business Calling API](https://www.ycloud.com/blog/whatsapp-business-calling-api.md)


---

<!-- source : recherche-apis-github-addendum-130-2026-10-11-netbuis.md -->

# Addendum 130 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté exploitable. Deux recherches (SDK mobile money Cameroun ; annuaire local / click-to-call open source) ne renvoient que des éléments déjà documentés (campay, dohone-sdk, camerpay/php-sdk, ekolotech/mobilemoney-gateway, mtn-momo-sdk). Seul nom marginal : norrisboat/MobileMoneySDK (Kotlin Multiplatform générique, non spécifique Cameroun, sans intérêt vs CamPay/TranZak). Les résultats « annuaire » sont des apps commerciales ou scrapers Google Maps, hors périmètre.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [norrisboat/MobileMoneySDK](https://github.com/norrisboat/MobileMoneySDK)


---

<!-- source : recherche-apis-github-addendum-131-2026-10-11-netbuis.md -->

# Addendum 131 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté exploitable. Deux recherches (mobile money Cameroun ; WhatsApp Cloud API / click-to-call / annuaire) renvoient les mêmes SDK déjà documentés (campay, camerpay/php-sdk, ekolotech/mobilemoney-gateway).

Noms marginaux vus, non retenus :
- elgiosoft/elgiopay-php-sdk, zaz-aangaraa/pay (Laravel) : wrappers PHP, stack Django retenue.
- enkap_mobile_money (module Odoo 18) : hors périmètre.
- gokapso/whatsapp-cloud-inbox : boîte de réception WhatsApp, inutile tant que wa.me suffit.
- Articles WhatsApp Calling API 2026 : API payante/soumise à approbation Meta ; wa.me reste le choix gratuit.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [elgiopay](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [gokapso/whatsapp-cloud-inbox](https://gittrend.io/repo/gokapso/whatsapp-cloud-inbox)


---

<!-- source : recherche-apis-github-addendum-132-2026-10-11-netbuis.md -->

# Addendum 132 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté majeure. Les recherches mobile money Cameroun et annuaire/géolocalisation renvoient les mêmes SDK déjà documentés (campay, camerpay/php-sdk, ekolotech/mobilemoney-gateway, elgiopay, zaz-aangaraa/pay).

Deux éléments marginaux, à titre de veille :
- Article DEV Community sur un SDK open source MTN MoMo en React Native/TypeScript : utile seulement comme référence de code client ; les appels de paiement doivent rester côté serveur (Django) pour ne pas exposer les clés.
- Apify « OSM Local Business Finder » : extraction de commerces depuis OpenStreetMap, pistes pour pré-remplir l'annuaire (à vérifier : licence ODbL, quotas gratuits Apify, couverture Cameroun faible).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [SDK MTN MoMo React Native (DEV)](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [OSM Local Business Finder (Apify)](https://apify.com/technicaldost/osm-local-business-finder/api)


---

<!-- source : recherche-apis-github-addendum-133-2026-10-11-netbuis.md -->

# Addendum 133 — APIs GitHub gratuites 2026 (run planifié, 2026-10-11)

## Verdict
Aucune nouveauté exploitable. Mobile money Cameroun : mêmes SDK (camerpay/php-sdk, campay PyPI, ekolotech/mobilemoney-gateway, elgiopay, zaz-aangaraa/pay). Seul élément marginal : module Odoo « Enkap Mobile Money » (orienté ERP, hors périmètre NetBuis). Annuaire/WhatsApp : uniquement des articles commerciaux (WhatsApp Business API payante) ; wa.me reste gratuit et suffisant.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [Enkap Mobile Money (Odoo)](https://apps.odoo.com/apps/modules/18.0/enkap_mobile_money)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)


---

<!-- source : recherche-apis-github-addendum-134-2026-10-12-netbuis.md -->

# Addendum 134 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté. Les recherches « mobile money Cameroun SDK » et « annuaire commerçants + click-to-call/WhatsApp Afrique » renvoient exactement les mêmes paquets déjà notés (camerpay/php-sdk, campay PyPI, dohone-sdk, ekolotech/mobilemoney-gateway, elgiopay, zaz-aangaraa/pay, Enkap Odoo). Côté WhatsApp : uniquement des comparatifs commerciaux (API payante) ; wa.me reste gratuit.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine (ou hebdomadaire) et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [Top WhatsApp API Africa 2026](https://chakrahq.com/article/top-10-whatsapp-api-solutions-in-africa-2026/)


---

<!-- source : recherche-apis-github-addendum-135-2026-10-12-netbuis.md -->

# Addendum 135 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté exploitable. Paquets déjà connus revenus (camerpay/php-sdk, campay PyPI, ekolotech/mobilemoney-gateway). Deux mentions mineures : catidegla/laravel-mobile-money (wrapper Laravel, hors stack Django) et un SDK React Native/TypeScript open source pour MTN MoMo (article DEV, sandbox Rwanda) — à surveiller seulement, non retenus. WhatsApp Business Calling API : payante, wa.me reste la solution gratuite.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [catidegla/laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [SDK MTN MoMo React Native (DEV)](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [campay PyPI](https://pypi.org/project/campay)
- [WhatsApp Business Calling API 2026](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)


---

<!-- source : recherche-apis-github-addendum-136-2026-10-12-netbuis.md -->

# Addendum 136 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté exploitable. Résultats : ekolotech/mobilemoney-gateway, camerpay/php-sdk, campay PyPI, kouyatekarim/momoapi (PHP), SDK MTN MoMo React Native (DEV) — tous déjà connus ou hors stack. Recherche annuaire local/géoloc Afrique : seulement des offres payantes (Zyla, AfriGIS) ; OSM/Overpass + MapLibre/PMTiles restent la voie gratuite.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)
- [kouyatekarim/momoapi](https://packagist.org/packages/kouyatekarim/momoapi)


---

<!-- source : recherche-apis-github-addendum-137-2026-10-12-netbuis.md -->

# Addendum 137 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté exploitable. Les recherches (mobile money Cameroun MTN/Orange ; annuaire local + WhatsApp/click-to-call Afrique) ne renvoient que des résultats déjà connus (ekolotech/mobilemoney-gateway, OpenFn MTN MoMo adaptor, topics GitHub mtn) ou des templates payants (CodeCanyon Listplace) hors stack.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée (cf. addendum 136) : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [OpenFn MTN MoMo](https://docs.openfn.org/adaptors/mtn-momo)
- [GitHub topic mtn](https://www.github.com/topics/mtn)


---

<!-- source : recherche-apis-github-addendum-138-2026-10-12-netbuis.md -->

# Addendum 138 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Peu de nouveauté. Deux pistes mineures à garder en réserve (non prioritaires) :
- **pay_unit_sdk** (pub.dev, Flutter, v3.1.x) : SDK PayUnit (agrégateur Cameroun MTN/Orange) — alternative/secours à CamPay + TranZak, à vérifier (frais, KYC).
- **pywa** (Python, WhatsApp Cloud API, module « calls » en 3.0 RC) : utile si on passe un jour à l'appel WhatsApp Business via le backend Django ; pas nécessaire pour wa.me au MVP.
- lengopay_flutter / elgiopay-php-sdk : agrégateurs régionaux, pertinence Cameroun non confirmée.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation (cf. 136-137) : suspendre la routine, lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [pay_unit_sdk](https://pub-web-s1.flutter-io.cn/packages/pay_unit_sdk/versions/2.0.10)
- [lengopay_flutter](https://pub-web-s2.flutter-io.cn/packages/lengopay_flutter/license)
- [pywa calls](https://pywa.readthedocs.io/en/3.0.0-rc.3/_sources/content/calls/overview.rst)


---

<!-- source : recherche-apis-github-addendum-139-2026-10-12-netbuis.md -->

# Addendum 139 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté exploitable. Seuls éléments revus (réserve, non prioritaires) :
- **camerpay/php-sdk**, **ekolotech/mobilemoney-gateway** (Packagist) : wrappers PHP MoMo/OM, inutiles avec backend Django.
- **campay (PyPI)** : déjà retenu (CamPay).
- SDK open source MTN MoMo React Native/TS (dev.to) : non pertinent (stack Flutter).
- Recherche « annuaire local Flutter » : uniquement des templates payants (CodeCanyon), rien de réutilisable.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée (cf. 136-138) : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [campay](https://pypi.org/project/campay)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [SDK MoMo RN](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)


---

<!-- source : recherche-apis-github-addendum-140-2026-10-12-netbuis.md -->

# Addendum 140 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté exploitable. Éléments vus (réserve) :
- **elgiosoft/elgiopay-php-sdk**, **zaz-aangaraa/pay** (Laravel) : wrappers PHP paiements Cameroun, inutiles avec backend Django.
- **Apify « OSM Local Business Finder »** : scraper OSM, payant à l'usage ; Overpass/Nominatim directs suffisent.
- CamPay (ClickGems) : déjà retenu.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée (cf. 136-139) : suspendre la routine, lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [elgiopay](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [zaz-aangaraa/pay](https://laraplugins.io/plugins/zaz-aangaraa/pay)
- [OSM Local Business Finder](https://apify.com/technicaldost/osm-local-business-finder/api)
- [CamPay](https://clickgems.clickhouse.com/dashboard/campay)


---

<!-- source : recherche-apis-github-addendum-141-2026-10-12-netbuis.md -->

# Addendum 141 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté exploitable. Vus (réserve) :
- **lepresk/momo-api (v1.2.0)** : wrapper PHP MTN MoMo, inutile avec backend Django.
- **E-nkap Mobile Money (module Odoo 18)** : lié à Odoo, hors périmètre.
- **Apify OSM scrapers (logiover, chrisp1211)** : payants à l'usage ; Overpass/Nominatim directs suffisent.
- Zylalabs « Business Locator API » : payant.
- CamPay (PyPI campay 1.0.1) : déjà retenu.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée (cf. 136-140) : suspendre la routine, lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)
- [lepresk/momo-api](https://phpfreaks.com/news/20216)
- [E-nkap Odoo](https://apps.odoo.com/apps/modules/18.0/enkap_mobile_money)
- [OSM scraper Apify](https://apify.com/logiover/openstreetmap-business-poi-scraper)


---

<!-- source : recherche-apis-github-addendum-142-2026-10-12-netbuis.md -->

# Addendum 142 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté exploitable. Résultats vus : camerpay/php-sdk, ekolotech/mobilemoney-gateway, elgiopay (Packagist, PHP : inutiles avec backend Django), campay PyPI (déjà retenu), guides WhatsApp Business Calling API (payant/BSP, hors besoin : wa.me suffit).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée (cf. 136-141) : suspendre la routine, lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)
- [WhatsApp Calling API 2026](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)


---

<!-- source : recherche-apis-github-addendum-143-2026-10-12-netbuis.md -->

# Addendum 143 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté exploitable. Résultats : catidegla/laravel-mobile-money et camerpay/ekolotech (PHP/Laravel, inutiles avec backend Django), campay PyPI (déjà retenu), SDK MTN MoMo React Native (dev.to, déjà connu), regisbamba/momoapi-java (Java, hors stack), Botble store-locator / Lead-Finder / scrapers Google Maps (payants ou contraires aux CGU, OSM + PostGIS suffit).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée (cf. 136-142) : suspendre la routine, lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [catidegla laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [campay PyPI](https://pypi.org/project/campay)
- [SDK MTN MoMo RN](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [momoapi-java](https://github.com/regisbamba/momoapi-java)


---

<!-- source : recherche-apis-github-addendum-144-2026-10-12-netbuis.md -->

# Addendum 144 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté exploitable. Résultats : ekolotech/mobilemoney-gateway et elgiopay-php-sdk (PHP, hors stack Django), pytekmomoapi (Python, MTN MoMo générique, déjà couvert par CamPay/TranZak), SDK MTN MoMo React Native (déjà connu), articles Kolonell (frais Orange Money vs MTN MoMo), annuaires WhatsApp génériques (techzim, digidirectory : pas d'API réutilisable).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée (cf. 136-143) : suspendre la routine, lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [ekolotech mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [SDK MTN MoMo RN](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [Kolonell Orange Money vs MTN MoMo](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)


---

<!-- source : recherche-apis-github-addendum-145-2026-10-12-netbuis.md -->

# Addendum 145 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté exploitable. Résultats déjà connus : elgiopay-php-sdk (PHP), campay (PyPI, déjà retenu), lepresk/momo-api (PHP), enkap mobile money (module Odoo), pesaPi, whatsapp-python (wrapper Cloud API, déjà couvert par wa.me), articles Kolonell et comparatifs WhatsApp API.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée (cf. 136-144) : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [enkap mobile money](https://apps.odoo.com/apps/modules/18.0/enkap_mobile_money)
- [whatsapp-python](https://pypi.org/project/whatsapp-python/2.9.3)
- [Kolonell Orange Money vs MTN MoMo](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)


---

<!-- source : recherche-apis-github-addendum-146b-2026-10-12-netbuis.md -->

# Addendum 147 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté décisive. Seuls éléments non listés avant : camerpay/php-sdk et ekolotech/mobilemoney-gateway (Packagist, PHP, wrappers Mobile Money), pytekmomoapi (wrapper Python MTN MoMo), pywa 3.0 rc (calls Cloud API WhatsApp, Python). Aucun ne change la stack (Django/Python) : CamPay + TranZak restent les choix de paiement ; pytekmomoapi à évaluer seulement en secours MTN direct ; pywa calls inutile tant que wa.me suffit.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine, lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [pywa calls](https://pywa.readthedocs.io/en/3.0.0-rc.3/_sources/content/calls/overview.rst)


---

<!-- source : recherche-apis-github-addendum-148-2026-10-12-netbuis.md -->

# Addendum 148 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12 ~14:00 UTC)

## Verdict
Aucune nouveauté décisive. Seul élément non listé : elgiosoft/elgiopay-php-sdk (Packagist, PHP) — hors stack Django/Python, sans impact. campay (PyPI), camerpay et ekolotech déjà connus. Recherche annuaire local / click-to-call / alternatives Twilio : rien de nouveau.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [campay PyPI](https://pypi.org/project/campay)


---

<!-- source : recherche-apis-github-addendum-149-2026-10-12-netbuis.md -->

# Addendum 149 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté décisive. Nouveaux paquets vus, tous PHP/Laravel donc hors stack Django : catidegla/laravel-mobile-money, lickayemassane/momo-payment, zaz-aangaraa/pay. Déjà connus : campay (PyPI), camerpay, ekolotech, elgiopay. Appel WhatsApp Business (pywa 3.0 RC, Calling API) : réservé aux comptes Business, inutile pour le MVP ; wa.me reste suffisant.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [momo-payment](https://packagist.org/packages/lickayemassane/momo-payment)
- [campay PyPI](https://pypi.org/project/campay)
- [pywa calls](https://pywa.readthedocs.io/en/3.0.0-rc.3/_sources/content/calls/overview.rst)


---

<!-- source : recherche-apis-github-addendum-150-2026-10-12-netbuis.md -->

# Addendum 150 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté utile. Seul élément nouveau vu : module Odoo « enkap mobile money » (apps.odoo.com), hors stack (Django) et orienté ERP, donc non retenu. Le reste (ekolotech, elgiopay, zaz-aangaraa/pay) est déjà connu. Recherche annuaire local/géoloc : uniquement des API payantes (Zyla, Apify) ou déjà couvertes (OSM/MapLibre/PostGIS).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée depuis plusieurs addenda : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée (rien de nouveau).

## Sources
- [enkap mobile money](https://apps.odoo.com/apps/modules/18.0/enkap_mobile_money)
- [ekolotech mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)


---

<!-- source : recherche-apis-github-addendum-152-2026-10-12-netbuis.md -->

# Addendum 152 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté utile. Recherches : SDK mobile money Cameroun (MTN/Orange) et annuaires locaux / WhatsApp Business Calling.
Résultats déjà connus ou hors stack : ekolotech/mobilemoney-gateway, camerpay/php-sdk (PHP, hors Django), campay (PyPI), pytekmomoapi (MTN MoMo), WhatsApp Business Calling (payant, via BSP).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée (rien de nouveau).

## Sources
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [WhatsApp Business Calling 2026](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)


---

<!-- source : recherche-apis-github-addendum-153b-2026-10-12-netbuis.md -->

# Addendum 153b — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté. Recherches : SDK mobile money Cameroun et annuaires locaux/géoloc Afrique. Résultats identiques à l'addendum 152 (camerpay php-sdk, ekolotech/mobilemoney-gateway, campay PyPI, pytekmomoapi, elgiopay php-sdk) ; annuaire : seulement Apify OSM Local Business Finder (scraping OSM, utile pour pré-remplir des commerçants) et marketplaces payantes (Zyla, AfriGIS).

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [Apify OSM Local Business Finder](https://apify.com/technicaldost/osm-local-business-finder/api)


---

<!-- source : recherche-apis-github-addendum-155-2026-10-12-netbuis.md -->

# Addendum 155 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté décisionnelle. Mobile money : mêmes SDK que l'addendum 153b (camerpay, ekolotech/mobilemoney-gateway, campay PyPI, pytekmomoapi, elgiopay). Seul élément marginal : un article DEV.to sur un SDK open source MTN MoMo React Native/TypeScript (utile comme référence de code côté mobile, pas un changement de stack). Annuaire/appel : uniquement marketplaces payantes (Zyla) et scrapers Apify ; notes de version WhatsApp Business (Cloud API calling) à surveiller.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine, lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [DEV.to SDK MTN MoMo RN/TS](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [WhatsApp Business release notes](https://releasebot.io/updates/meta/whatsapp-business-messaging)


---

<!-- source : recherche-apis-github-addendum-156-2026-10-12-netbuis.md -->

# Addendum 156 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté. Les recherches mobile money (Cameroun/MTN/Orange) renvoient les mêmes paquets que les addendums 153b/155 : ekolotech/mobilemoney-gateway, pytekmomoapi, campay (PyPI), regisbamba/momoapi-java, catidegla/laravel-mobile-money, plus un SDK React Native MTN MoMo (forum développeurs MTN). Annuaire local / click-to-call : aucun dépôt ou API gratuite pertinente nouvelle.

## Décisions inchangées
tel: + wa.me, CamPay + TranZak, Django + pg_trgm/PostGIS + OTP Nexah, MapLibre/PMTiles, FCM + Crashlytics.

## Recommandation
Saturation confirmée : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io/en/latest/)
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)
- [momoapi-java](https://github.com/regisbamba/momoapi-java)
- [SDK RN MTN MoMo](https://momodevelopercommunity.mtn.com/momo-rwanda-developers-36/open-source-react-native-sdk-for-momo-plus-what-i-found-in-the-sandbox-499)


---

<!-- source : recherche-apis-github-addendum-158-2026-10-12-netbuis.md -->

# Addendum 158 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Quasi aucune nouveauté. Deux paquets mineurs repérés : camerpay/php-sdk (Packagist, SDK PHP Cameroun) et kouyatekarim/momoapi (PHP MTN MoMo). Utiles seulement si backend PHP/Laravel ; le choix Django + CamPay/TranZak reste inchangé. WhatsApp : rien de nouveau (conversations de service gratuites, wa.me suffit pour le MVP).

## Recommandation
Saturation confirmée : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [kouyatekarim/momoapi](https://packagist.org/packages/kouyatekarim/momoapi)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)


---

<!-- source : recherche-apis-github-addendum-160-2026-10-12-netbuis.md -->

# Addendum 160 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté majeure. Mêmes paquets paiement déjà recensés (campay PyPI, camerpay/php-sdk, ekolotech/mobilemoney-gateway, elgiosoft/elgiopay-php-sdk, enkap Odoo). Côté appel : Fonoster (alternative open source à Twilio, programmable voice) et NEOMS (Tiniyo) déjà connus comme options auto-hébergées ; non nécessaires pour le MVP (appel direct via tel: / wa.me).

## Recommandation
Inchangée : suspendre la routine, lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée (rien de nouveau).

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [fonoster](https://github.com/fonoster/fonoster)
- [tiniyo/neoms](https://www.github.com/tiniyo/neoms)


---

<!-- source : recherche-apis-github-addendum-162-2026-10-12-netbuis.md -->

# Addendum 162 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Peu de nouveauté. Paquets paiement déjà connus (camerpay/php-sdk, campay PyPI, ekolotech/mobilemoney-gateway). Pistes secondaires repérées, à garder en réserve :
- SDK open source MTN MoMo React Native/TypeScript (article DEV Community, auteur frankcdr) : utile si l'app mobile est en React Native.
- pytekmomoapi (Python, readthedocs) : wrapper MTN MoMo API côté backend.
- pywa (Python) : module Calls pour l'API WhatsApp Business Calling (appels via Cloud API) ; netflie/whatsapp-cloud-api (PHP) pour l'envoi de messages.

## Recommandation
Inchangée : MVP avec appel direct (tel: / wa.me), paiement via Campay ; lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée (rien de décisif).

## Sources
- [dev.to MTN MoMo RN SDK](https://dev.to/frankcdr__1325e131e4a8390/building-an-open-source-sdk-for-mtn-mobile-money-react-nativetypescript-5756)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [pywa calls](https://pywa.readthedocs.io/en/3.0.0-rc.2/_sources/content/calls/overview.rst)
- [netflie/whatsapp-cloud-api](https://gittrend.io/repo/netflie/whatsapp-cloud-api)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)


---

<!-- source : recherche-apis-github-addendum-164-2026-10-12-netbuis.md -->

# Addendum 164 — APIs GitHub gratuites 2026 (run planifié, 2026-10-12)

## Verdict
Aucune nouveauté décisive. Résultats déjà connus : campay (PyPI), ekolotech/mobilemoney-gateway, elgiosoft/elgiopay-php-sdk, catidegla/laravel-mobile-money (Packagist). Pistes mineures : annuaire des API africaines (afrotools.com), AfriGIS business search (Afrique du Sud, hors cible), Africa's Talking marketplace (SMS/USSD, alternative à Twilio).

## Recommandation
Inchangée : MVP avec appel direct (tel: / wa.me), paiement via Campay, jalon 0 avec 30 commerçants pilotes. Aucune notification envoyée.

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [Annuaire des API africaines](https://afrotools.com/fr/tools/annuaire-api-africaines/)
- [Africa's Talking marketplace](https://AfricasTalking.com/marketplace/showcase)


---

<!-- source : recherche-apis-github-addendum-166-2026-10-13-netbuis.md -->

# Addendum 166 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13)

## Verdict
Aucune nouveauté. Les recherches (mobile money Cameroun MTN/Orange open source ; API recherche commerçants / WhatsApp click-to-chat) renvoient uniquement des résultats déjà connus : campay (PyPI), ekolotech/mobilemoney-gateway, elgiosoft/elgiopay-php-sdk, plus des guides génériques WhatsApp Business et un comparatif Orange Money vs MTN MoMo Cameroun (kolonell.com, 2026).

## Recommandation
Inchangée : MVP avec appel direct (tel: / wa.me), paiement via Campay, jalon 0 avec 30 commerçants pilotes. Aucune notification envoyée.

## Sources
- [campay PyPI](https://pypi.org/project/campay)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [Orange Money vs MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)


---

<!-- source : recherche-apis-github-addendum-168-2026-10-13-netbuis.md -->

# Addendum 168 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13)

## Verdict
Aucune nouveauté. Recherches (SDK mobile money Cameroun MTN/Orange ; annuaire local + WhatsApp click-to-call Afrique) : uniquement des résultats déjà documentés (camerpay/php-sdk, ekolotech/mobilemoney-gateway, kouyatekarim/momoapi, campay PyPI, pytekmomoapi, guides WhatsApp Business Calling API 2026, annuaire WhatsApp Techzim).

## Recommandation
Inchangée : MVP recherche produit -> liste commerçants -> tel: / wa.me ; paiement via Campay (+ TranZak en parallèle) ; Twilio seulement pour appels masqués. Saturation : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay)
- [WhatsApp Business Calling API 2026](https://chakrahq.com/article/whatsapp-cloud-api-calling-feature-details/amp/)


---

<!-- source : recherche-apis-github-addendum-170-2026-10-13-netbuis.md -->

# Addendum 170 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13)

## Verdict
Aucune nouveauté exploitable. Deux recherches (SDK mobile money Cameroun ; annuaire local + click-to-call WhatsApp Afrique) : résultats déjà documentés (camerpay/php-sdk, ekolotech/mobilemoney-gateway, campay PyPI, pytekmomoapi, annuaire WhatsApp Techzim). Seuls éléments « nouveaux » : catidegla/laravel-mobile-money, lickayemassane/momo-payment, elgiosoft/elgiopay-php-sdk — wrappers PHP génériques, sans intérêt pour une stack mobile.

## Recommandation
Inchangée : MVP recherche produit -> liste commerçants -> tel: / wa.me ; paiement via Campay (+ TranZak) ; Twilio seulement pour appels masqués. Saturation atteinte : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay PyPI](https://pypi.org/project/campay)
- [Techzim WhatsApp directory](https://techzim.co.zw/local-company-develops-free-business-directory-thats-accessible-via-whatsapp)


---

<!-- source : recherche-apis-github-addendum-172-2026-10-13-netbuis.md -->

# Addendum 172 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13)

## Verdict
Aucune nouveauté exploitable. Deux recherches (SDK mobile money Cameroun ; recherche/géocodage open source Typesense, Meilisearch, Photon) : résultats déjà connus (camerpay/php-sdk, ekolotech/mobilemoney-gateway, pytekmomoapi, mtnmomo crate, guides Kolonell MTN MoMo/Orange Money Cameroun 2026). Typesense/Meilisearch (recherche produit auto-hébergée, gratuite) et Photon/Nominatim (géocodage OSM) restent les options déjà retenues.

## Recommandation
Inchangée : MVP recherche produit -> liste commerçants -> tel: / wa.me ; paiement via Campay (+ TranZak) ; Twilio seulement pour appels masqués. Saturation confirmée : suspendre la routine et lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée (rien de nouveau).

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [Kolonell — MTN MoMo API Cameroun 2026](https://kolonell.com/en/blog/integrate-mtn-momo-api-collection-cameroon-ghana-2026)
- [Typesense geo search](https://railway.com/deploy/typesense-geo-search.md)


---

<!-- source : recherche-apis-github-addendum-174-2026-10-13-netbuis.md -->

# Addendum 174 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13)

## Verdict
Aucune nouveauté exploitable. Deux recherches (SDK mobile money / WhatsApp / annuaire local ; stack React Native-Expo 2026) : résultats déjà connus (camerpay/php-sdk, campay PyPI, guides Kolonell MTN MoMo / Orange Money 2026). Seul élément marginal : elgiosoft/elgiopay-php-sdk (SDK PHP de paiement, non prioritaire, Campay déjà retenu). Expo SDK 56 / React Native 0.85 : mise à jour d'écosystème, aucun impact sur le choix d'APIs.

## Recommandation
Inchangée : MVP recherche produit -> liste commerçants -> tel: / wa.me ; paiement via Campay (+ TranZak) ; Twilio seulement pour appels masqués ; Typesense/Meilisearch + Photon/Nominatim pour recherche et géocodage. Saturation confirmée : lancer le jalon 0 (30 commerçants pilotes) plutôt que poursuivre la recherche. Aucune notification envoyée.

## Sources
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [elgiopay php sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [campay (PyPI)](https://pypi.org/project/campay)
- [Kolonell — MTN MoMo API Cameroun 2026](https://kolonell.com/fr/blog/integrer-mtn-momo-api-collecte-cameroun-ghana-2026)
- [Expo SDK 56 / RN 0.85](https://hashnode.com/posts/react-native-updates/6a1fb64e8491d4ac1252f633)


---

<!-- source : recherche-apis-github-addendum-176-2026-10-13-netbuis.md -->

# Addendum 176 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13)

## Verdict
Nouveauté marginale seulement. Deux recherches (SDK mobile money Cameroun ; annuaire/recherche locale open source Afrique).

Éléments à noter (non prioritaires) :
- ekolotech/mobilemoney-gateway (Packagist) : passerelle PHP multi-opérateurs mobile money.
- dohone-sdk (npm) : SDK Node pour Dohone (agrégateur paiement Cameroun/Afrique de l'Ouest) — alternative de secours à Campay.
- Rien de nouveau côté annuaire/recherche produit (AfriGIS = Afrique du Sud, payant ; Overpass/OSM déjà connu).

Déjà connus : camerpay/php-sdk, campay (PyPI), guides Kolonell Orange Money / MTN MoMo 2026.

## Recommandation
Inchangée : MVP recherche -> liste commerçants -> tel: / wa.me ; paiement Campay (+ TranZak, Dohone en secours) ; Twilio uniquement pour appels masqués ; Typesense/Meilisearch + Photon/Nominatim. Saturation confirmée : lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay (PyPI)](https://pypi.org/project/campay)
- [Kolonell — Orange Money API 2026](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)


---

<!-- source : recherche-apis-github-addendum-178-2026-10-13-netbuis.md -->

# Addendum 178 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13)

## Verdict
Saturation confirmée. Deux recherches (SDK mobile money Cameroun ; annuaire local / appel / WhatsApp open source Afrique). Aucune nouveauté structurante.

Éléments mineurs (non prioritaires) :
- elgiosoft/elgiopay-php-sdk (Packagist) : SDK PHP de paiement, à évaluer seulement si backend PHP.
- pytekmomoapi (ReadTheDocs) : wrapper Python MTN MoMo, redondant avec l'API officielle MTN MoMo.
- Rien de pertinent côté annuaire de commerçants / recherche produit (résultats hors sujet).

Déjà connus : camerpay/php-sdk, campay (PyPI), ekolotech/mobilemoney-gateway, dohone-sdk, guides Kolonell.

## Recommandation
Inchangée : MVP recherche -> liste commerçants -> tel: / wa.me ; paiement Campay (+ TranZak, Dohone en secours) ; Twilio uniquement pour appels masqués ; Typesense/Meilisearch + Photon/Nominatim. Lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [elgiopay-php-sdk](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [pytekmomoapi](https://pytekmomoapi.readthedocs.io)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [ekolotech/mobilemoney-gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [campay (PyPI)](https://pypi.org/project/campay)


---

<!-- source : recherche-apis-github-addendum-180-2026-10-13-netbuis.md -->

# Addendum 180 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13)

## Verdict
Saturation confirmée. Deux recherches (annuaire/mobile money/USSD Afrique ; WhatsApp Cloud API calling). Aucune nouveauté structurante.

Mentions mineures, déjà couvertes ou hors priorité :
- Africa's Talking (SMS/USSD/Voice/Paiements) : alternative à Twilio pour la voix/USSD, déjà connue.
- UseHover/Stax (open source, Android) : lecture d'USSD côté client, intéressant seulement pour automatisation USSD.
- afrotools.com : annuaire d'API africaines, utile comme veille.
- WhatsApp Cloud API Calling : documentation tierce, rien de nouveau vs. wa.me.

## Recommandation
Inchangée : MVP recherche -> liste commerçants -> tel: / wa.me ; paiement Campay (+ TranZak, Dohone en secours) ; Twilio uniquement pour appels masqués ; Typesense/Meilisearch + Photon/Nominatim. Lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [Africa's Talking (apitracker)](https://apitracker.io/a/africastalking)
- [UseHover/Stax](https://www.github.com/UseHover/Stax)
- [Annuaire des API africaines](https://afrotools.com/fr/tools/annuaire-api-africaines/)
- [Cloud API calling doc](https://support.chatarchitect.com/books/meta-whatsapp/page/cloud-api-calling-developer-documentation)


---

<!-- source : recherche-apis-github-addendum-182-2026-10-13-netbuis.md -->

# Addendum 182 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13)

## Verdict
Saturation confirmée. Deux recherches (mobile money Cameroun/GitHub ; annuaire commerces Afrique). Aucune nouveauté structurante.

Mentions mineures déjà connues : Campay (listé sur ClickGems), paquets PHP/crates MTN MoMo (ekolotech/mobilemoney-gateway, elgiopay, mtnmomo), AfriGIS business search (payant, Afrique du Sud), Africa's Talking marketplace.

## Recommandation
Inchangée : MVP recherche -> liste commerçants -> tel: / wa.me ; paiement Campay (+ TranZak, Dohone en secours) ; Twilio uniquement pour appels masqués ; Typesense/Meilisearch + Photon/Nominatim. Lancer le jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [mobilemoney gateway](https://packagist.org/packages/ekolotech/mobilemoney-gateway)
- [ClickGems Campay](https://clickgems.clickhouse.com/dashboard/campay)
- [MTN MoMo API 2026](https://kolonell.com/fr/blog/mtn-momo-api-ghana-cote-ivoire-2026)
- [AfriGIS business search](https://developers.afrigis.co.za/portfolio/business-search/)


---

<!-- source : recherche-apis-github-addendum-184-2026-10-13-netbuis.md -->

# Addendum 184 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13)

## Verdict
Saturation confirmée. Deux recherches (SDK mobile money Cameroun ; annuaire commerces + WhatsApp Afrique). Aucune nouveauté structurante.

Mentions mineures : SDK PHP camerpay/php-sdk, SDK npm dohone-sdk, paquet PyPI campay (client Python Campay), ekolotech/mobilemoney-gateway et elgiopay déjà connus. Annuaire WhatsApp gratuit (Techzim, Zimbabwe) = idée d'inspiration, pas d'API réutilisable.

## Recommandation
Inchangée : MVP recherche -> liste commerçants -> tel: / wa.me ; paiement Campay (+ TranZak, Dohone en secours) ; Twilio uniquement pour appels masqués ; Typesense/Meilisearch + Photon/Nominatim. Lancer le jalon 0 (30 commerçants pilotes).

## Sources
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [dohone-sdk](https://www.npmjs.org/package/dohone-sdk)
- [campay PyPI](https://pypi.org/project/campay)
- [Techzim WhatsApp directory](https://techzim.co.zw/local-company-develops-free-business-directory-thats-accessible-via-whatsapp)


---

<!-- source : recherche-apis-github-addendum-186-2026-10-13-netbuis.md -->

# Addendum 186 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13)

## Verdict
Saturation confirmée. Deux recherches (annuaire commerces/WhatsApp Afrique ; wrappers Orange Money/MTN MoMo Cameroun). Aucune nouveauté structurante.

Déjà connus ou mineurs : camerpay/php-sdk, campay (PyPI), ekolotech/mobilemoney-gateway, lepresk/momo-api, roazagba/apimtnmomo, lickayemassane/momo-payment, cashkdiopen/payments (Laravel). Guides WhatsApp Business API Afrique 2026 = documentation payante/commerciale, pas d'API gratuite nouvelle.

## Recommandation
Inchangée : MVP recherche -> liste commerçants -> tel: / wa.me ; paiement Campay (+ TranZak, Dohone en secours) ; Twilio uniquement pour appels masqués ; Typesense/Meilisearch + Photon/Nominatim. Lancer le jalon 0 (30 commerçants pilotes) plutôt que de poursuivre la recherche.

## Sources
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [campay PyPI](https://pypi.org/project/campay/1.0.1/)
- [lepresk/momo-api](https://phpfreaks.com/news/20216)
- [roazagba/apimtnmomo](https://packagist.org/packages/roazagba/apimtnmomo)
- [Techzim WhatsApp directory](https://techzim.co.zw/local-company-develops-free-business-directory-thats-accessible-via-whatsapp)


---

<!-- source : recherche-apis-github-addendum-187-2026-10-13-netbuis.md -->

# Addendum 187 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13, couvre 4 déclenchements en file 11:57–14:57 UTC)

## Verdict
Saturation confirmée. Deux recherches (marketplace Flutter « vendeurs proches » open source ; API mobile money Cameroun). Aucune nouveauté structurante.

Mentions mineures : module Odoo `enkap_mobile_money` (Enkap/Smobilpay, Cameroun) = autre agrégateur local à garder en repli éventuel, pile Odoo inutilisable telle quelle [N] ; guide Kolonell « intégrer Orange Money Cameroun 2026 » (documentation, pas d'API) ; templates Flutter e-commerce (marketky, uShop, hotdeals) = maquettes UI, pas de recherche géolocalisée. camerpay, campay PyPI, elgiopay, aangaraa déjà connus.

## Recommandation
Inchangée : MVP recherche -> liste commerçants -> tel: / wa.me ; paiement Campay (+ TranZak, Dohone en secours) ; Typesense/Meilisearch + Photon/Nominatim. Lancer le jalon 0 (30 commerçants pilotes) plutôt que de poursuivre la recherche horaire.

## Sources
- [enkap_mobile_money (Odoo)](https://apps.odoo.com/apps/modules/18.0/enkap_mobile_money)
- [Kolonell Orange Money Cameroun 2026](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [marketky](https://github.com/mrezkys/marketky)
- [hotdeals](https://github.com/halildurmus/hotdeals)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)


---

<!-- source : recherche-apis-github-addendum-188-2026-10-13-netbuis.md -->

# Addendum 188 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13 15:58 UTC)

## Verdict
Aucune nouveauté structurante. Une recherche (module forum Django/Flutter open source).

Seule piste utile : **django-machina** (openfun, BSD, forum intégrable dans Django : catégories, sujets, permissions, modération). Projet ancien, pas « récent 2026 » ; à évaluer seulement si le forum natif minimal (Post/Comment) ne suffit pas. **flutter-djangoflow** (djangoflow) = boîte à outils Flutter+Django, maturité non vérifiée [N].

## Recommandation
Inchangée. Forum natif minimal d'abord ; django-machina en repli si la modération devient lourde. Lancer le jalon 0 plutôt que poursuivre la recherche horaire.

## Sources
- [django-machina (code.gouv.fr)](https://repos.data.code.gouv.fr/hosts/GitHub/repositories/openfun%2Fdjango-machina)
- [flutter-djangoflow](https://github.com/djangoflow/flutter-djangoflow/)


---

<!-- source : recherche-apis-github-addendum-189-2026-10-13-netbuis.md -->

# Addendum 189 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13 16:57 UTC)

## Verdict
Aucune nouveauté structurante. Une recherche (données ouvertes prix/produits tendance Afrique, pour la section « produits très sollicités »).

Trouvé : African Market Observatory (AMO) Price Tracker (Commission de la concurrence sud-africaine) = tableau de prix alimentaires multi-pays, sans API ouverte confirmée [N] ; scrapers Jumia (Apify) et offres Zyla/Actowiz = payants ou scraping, à écarter. Pas de source gratuite fiable pour le Cameroun : les « produits sollicités » doivent venir des recherches internes de l'app (journal des requêtes agrégé).

## Recommandation
Inchangée. Calculer les tendances à partir des recherches NetBuis (table de comptage par produit/ville/jour).

## Sources
- [AMO Price Tracker](https://competition.org.za/africanmarketobservatory-amo-price-tracker)
- [Jumia Scraper (Apify)](https://apify.com/logiover/jumia-scraper)


---

<!-- source : recherche-apis-github-addendum-190-2026-10-13-netbuis.md -->

# Addendum 190 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13 17:57 UTC)

## Verdict
Aucune nouveauté structurante. Une recherche (synchronisation hors ligne Flutter pour réseaux faibles).

Trouvé : PowerSync (SDK Flutter open source, service avec palier gratuit, conçu pour Postgres/Supabase) [N : conditions 2026 non relues] ; petits paquets pub.dev (offline_sync_flutter, offline_sync_data, syncable, offline_sync_helper) = jeunes, peu d'utilisateurs, écartés. Pour un backend Django, un cache local (Drift/Hive) des dernières recherches et fiches commerçants suffit au MVP ; PowerSync n'a d'intérêt que si l'on passe à Supabase.

## Recommandation
Inchangée. Cache local simple côté app ; pas de moteur de synchronisation au MVP.

## Sources
- [PowerSync (GitHub)](https://github.com/powersync-ja)
- [offline_sync_flutter (pub.dev)](https://pub.dev/packages/offline_sync_flutter/versions/1.0.2)
- [syncable (pub.dev)](https://pub.dev/packages/syncable)


---

<!-- source : recherche-apis-github-addendum-191-2026-10-13-netbuis.md -->

# Addendum 191 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13 18:57 UTC)

## Verdict
Aucune nouveauté structurante. Une recherche (reconnaissance vocale open source pour la recherche vocale : français, pidgin, fulfulde).

Pistes : Sunbird « ASR Whisper 51 African Languages » (modèle Whisper affiné, langues africaines ; couverture du pidgin camerounais et du fulfulde non vérifiée) [N] ; UBC-NLP Simba (ASR multilingue africain) [N] ; pidgin-wav2vec2-xlsr53 (pidgin nigérian, proche du pidgin camerounais) ; traducteur Fulfulde (Space HF, démo). Toutes en phase expérimentale ; pour le MVP, la recherche vocale du clavier Android (Gboard, français) suffit et coûte 0.

## Recommandation
Inchangée. Utiliser la dictée native du téléphone ; tester Whisper 51 langues seulement en phase accessibilité (cf. accessibilite-analphabetisme-netbuis.md).

## Sources
- [Sunbird ASR Whisper 51 African Languages](https://salt.sunbird.ai/models/asr-whisper-51-african-languages/)
- [Simba (UBC-NLP)](https://app.alphaneural.io/assets/UBC-NLP/Simba-H)
- [pidgin-wav2vec2-xlsr53](https://huggingface.co/asr-nigerian-pidgin/pidgin-wav2vec2-xlsr53/tree/main)
- [FulfuldeTranslator (HF Space)](https://huggingface.co/spaces/yaya-sy/FulfuldeTranslator/tree/2260d99e85a6b83e19814e7184c20aef51a227e9)


---

<!-- source : recherche-apis-github-addendum-192-2026-10-13-netbuis.md -->

# Addendum 192 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13 19:57 UTC)

## Verdict
Aucune nouveauté structurante. Une recherche (modération de contenu et anti-spam pour le forum).

Pistes : API de modération auto-hébergée open source (article DEV, projet individuel, maturité non vérifiée) [N] ; ALTCHA Sentinel (anti-spam/anti-bot auto-hébergeable, doc en français, cas d'usage chat/forum) [N : licence et palier gratuit à relire] ; Google Perspective API (gratuite, toxicité, support du français) via plugin Discourse = utilisable aussi directement depuis Django [N : conditions 2026]. Comparatif « moderation tools self-hosted 2026 » (dasroot) = lecture utile.

## Recommandation
Inchangée pour le MVP : signalement par les utilisateurs + file de modération dans l'admin Django + limite de débit. Ajouter Perspective API ou ALTCHA seulement si le spam apparaît.

## Sources
- [Self-hosted content moderation API (DEV)](https://dev.to/kokosde/i-built-a-self-hosted-content-moderation-api-open-source-2gba)
- [ALTCHA Sentinel – modération chat/forum](https://altcha.org/fr/docs/v2/sentinel/use-cases/chat-forum-moderation/)
- [Perspective API plugin (Discourse)](https://meta.discourse.org/t/google-perspective-api-plugin/98733?tl=fr)
- [Moderation tools self-hosted 2026](https://dasroot.net/posts/2026/01/moderation-tools-self-hosted-communities/)


---

<!-- source : recherche-apis-github-addendum-193-2026-10-13-netbuis.md -->

# Addendum 193 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13 20:57 UTC)

## Verdict
Aucune nouveauté structurante. Une recherche (recherche de produit par photo / reconnaissance d'image).

Pistes : Google ML Kit (étiquetage d'image et lecture de code-barres sur l'appareil, gratuit, plugin Flutter) = utile plus tard pour « photographier un produit » ou scanner un code-barres ; Google Vision Product Recognizer = payant, écarté ; PackageX Vision SDK = commercial, écarté. Pas de modèle gratuit reconnaissant les produits locaux camerounais sans entraînement propre.

## Recommandation
Inchangée pour le MVP (recherche texte). En phase 2 : scan de code-barres ML Kit sur l'appareil, puis recherche texte sur le nom obtenu.

## Sources
- [Google ML Kit Vision (pub.dev)](https://pub.dev/documentation/google_ml_vision/latest/)
- [Vision AI Product Recognizer](https://docs.cloud.google.com/vision-ai/docs/product-recognizer?hl=ja)
- [PackageX Vision SDK Flutter](https://docs.packagex.io/sdks/vision-SDK/flutter)


---

<!-- source : recherche-apis-github-addendum-194-2026-10-13-netbuis.md -->

# Addendum 194 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13 21:57 UTC)

## Verdict
Aucune nouveauté structurante. Une recherche (connexion par SMS/OTP côté Django).

Pistes : django-phone-verify (paquet Django de vérification par code SMS, fournisseur interchangeable) [N : version récente à relire] ; ob-dj-otp, django-rest-sms-auth, django-phone-login = paquets plus anciens ou peu suivis. Comparatif Prelude « alternatives à Firebase Phone Auth » = article commercial. Rien ne remplace le choix déjà fait (cf. comparatif-fournisseurs-sms-otp-cameroun-netbuis.md) : l'envoi au Cameroun reste payant quel que soit le fournisseur.

## Recommandation
Inchangée. Une petite vue Django maison (code à 6 chiffres, expiration, limite de tentatives) branchée sur le fournisseur SMS retenu ; django-phone-verify comme modèle de code si besoin.

## Sources
- [django-phone-verify (PyPI)](https://pypi.org/project/django-phone-verify/0.2.0/)
- [ob-dj-otp (PyPI)](https://pypi.org/project/ob-dj-otp/0.0.22)
- [Firebase SMS OTP alternatives (Prelude)](https://prelude.so/blog/top-10-firebase-sms-otp-alternatives)


---

<!-- source : recherche-apis-github-addendum-195-2026-10-13-netbuis.md -->

# Addendum 195 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13 22:57 UTC)

## Verdict
Aucune nouveauté structurante. Une recherche (avis et notes sur les commerçants, côté Django).

Pistes : django-rated-reviews (avis notés génériques, doc readthedocs) ; django-reviews, agon-ratings = anciens. Aucun n'est récent (2026) ni indispensable : un modèle Avis (commerçant, auteur, note 1-5, texte, date, statut de modération) tient en quelques lignes.

## Recommandation
Inchangée. Modèle Avis maison + note moyenne calculée ; avis réservé aux utilisateurs ayant appelé ou écrit au commerçant via l'app (limite la fraude).

## Sources
- [django-rated-reviews (PyPI)](https://pypi.org/project/django-rated-reviews)
- [Django Rated Reviews (docs)](https://django-rated-reviews.readthedocs.io/)
- [django-reviews (Django Packages)](https://djangopackages.org/packages/p/django-reviews/)


---

<!-- source : recherche-apis-github-addendum-196-2026-10-13-netbuis.md -->

# Addendum 196 — APIs GitHub gratuites 2026 (run planifié, 2026-10-13 23:57 UTC)

## Verdict
Aucune nouveauté structurante. Une recherche (suivi d'usage et rapports de plantage pour l'app Flutter).

Pistes : GlitchTip (open source, compatible SDK Sentry, auto-hébergeable, offre cloud gratuite limitée) [N : quotas 2026] ; PostHog (analytics produit, palier gratuit cloud, SDK Flutter) [N] ; Firebase Crashlytics reste gratuit et déjà dans l'écosystème FCM. Petits paquets pub.dev (moewe, telling_logger, gatiflow_flutter) = jeunes, écartés.

## Recommandation
MVP : Firebase Crashlytics + Analytics (gratuits, même projet que FCM). GlitchTip si l'on veut sortir de Google plus tard.

## Sources
- [GlitchTip (OpenAlternative)](https://openalternative.co/glitchtip)
- [Crashlytics alternatives (AlternativeTo)](https://alternativeto.net/software/crashlytics)
- [PostHog pour Flutter](https://theflutterk.it.com/alternative/mixpanel-alternative)


---

<!-- source : recherche-apis-github-addendum-197-2026-10-14-netbuis.md -->

# Addendum 197 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 00:57 UTC)

## Verdict
Aucune nouveauté structurante. Une recherche (hébergement et compression des photos produits).

Pistes : imgproxy (open source, redimensionnement à la volée, auto-hébergeable) ; Openinary (alternative open source à Cloudinary, récente) [N : maturité] ; comparatif DEV « alternatives Cloudinary 2026 ». Cloudinary garde un palier gratuit [N : quotas 2026].

## Recommandation
MVP : compression côté téléphone avant envoi (flutter_image_compress, WebP ~100 Ko) + stockage objet (S3 compatible) servi par Django/CDN. imgproxy seulement si plusieurs tailles d'images deviennent nécessaires.

## Sources
- [Cloudinary alternatives 2026 (DEV)](https://dev.to/devtoolpicks/best-cloudinary-alternatives-for-indie-hackers-in-2026-cheaper-image-cdns-58cp)
- [imgproxy alternatives (OpenAlternative)](https://openalternative.co/alternatives/imgproxy)
- [Openinary (OpenAlternative)](https://openalternative.co/alternatives/openinary)


---

<!-- source : recherche-apis-github-addendum-198-2026-10-14-netbuis.md -->

# Addendum 198 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 01:57 UTC)

## Verdict
Aucune nouveauté structurante. Une recherche (modèles de départ Django REST + Flutter avec JWT).

Pistes : p8ul/django-rest-framework-boilerplate, essiee12/django_starter, catalogue starterindex (DRF starter) = squelettes génériques, utiles pour copier la config (JWT, Docker, tests) mais sans brique métier ; client Dart django_rest_framework_client 0.0.5 = trop jeune, écarté (Dio + modèles générés suffit). Kits payants (Selar, Upwork) écartés.

## Recommandation
Inchangée. Partir de `django-admin startproject` + DRF + djangorestframework-simplejwt ; côté Flutter, Dio + Riverpod. Ne pas adopter de boilerplate tiers.

## Sources
- [django-rest-framework-boilerplate](https://github.com/p8ul/django-rest-framework-boilerplate)
- [django_starter](https://github.com/essiee12/django_starter)
- [DRF Starter Template (starterindex)](https://starterindex.com/boilerplate/django-rest-framework-starter-template)


---

<!-- source : recherche-apis-github-addendum-199-2026-10-14-netbuis.md -->

# Addendum 199 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 02:57 UTC)

## Verdict
Aucune nouveauté structurante. Une recherche (hébergement gratuit Django + PostgreSQL/PostGIS).

Sources trouvées : comparatifs 2026 des paliers gratuits (agentdeals, Render, Better Stack, pandastack), guide Django de Fly.io, Railway vs Render 2026. Constat général [N : quotas non relus un par un] : les paliers gratuits mettent le service en veille ou limitent la base (taille, durée) ; ils suffisent pour une démo ou le pilote de 30 commerçants, pas pour la production.

## Recommandation
Pilote : un PaaS gratuit (Render ou Railway, déjà connecté au projet) avec PostgreSQL + extension PostGIS. Production : petit VPS ou palier payant d'entrée. Vérifier la disponibilité de PostGIS sur l'offre choisie avant de déployer.

## Sources
- [Hosting free tier comparison 2026 (agentdeals)](https://agentdeals.dev/hosting-free-tier-comparison-2026)
- [Platforms with a real free tier 2026 (Render)](https://render.com/articles/platforms-with-a-real-free-tier-for-developers-in-2026.md)
- [Django hosting (Fly.io)](https://fly.io/learn/django-hosting.md)
- [Railway vs Render 2026](https://agentdeals.dev/railway-vs-render)
- [Best Django hosting 2026 (pandastack)](https://pandastack.io/blog/best-django-hosting-2026)


---

<!-- source : recherche-apis-github-addendum-200-2026-10-14-netbuis.md -->

# Addendum 200 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 03:58 UTC)

## Verdict
Aucune nouvelle API. Une recherche (taille et performance de l'app Flutter sur téléphones Android d'entrée de gamme / Android Go).

Bonnes pratiques confirmées par plusieurs guides 2026 : App Bundle (AAB) ou `--split-per-abi` (≈70 Mo → ≈30 Mo rapportés), `--obfuscate --split-debug-info`, polices et icônes réduites, images WebP, éviter les gros paquets (cartes, vidéo) au premier écran, chargement différé (deferred components). Android Go : tester sur appareil 1-2 Go de RAM.

## Recommandation
Inchangée côté API. Ajouter au backlog : budget de taille APK < 20 Mo par ABI, test sur un téléphone Android Go réel avant le pilote.

## Sources
- [Flutter sur Android 12 Go (gurubase)](https://gurubase.io/g/flutter/run-flutter-apps-android-12-go-edition)
- [Flutter app size checklist 2026](https://theflutterk.it.com/blog/flutter-app-size-optimization-checklist-2026)
- [Reducing Flutter app size (AppsOnAir)](https://www.appsonair.com/blogs/reducing-flutter-app-size-effectively)


---

<!-- source : recherche-apis-github-addendum-201-2026-10-14-netbuis.md -->

# Addendum 201 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 04:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : limites administratives et quartiers du Cameroun pour rattacher les commerçants à une commune ou un quartier.
- HDX (Centre for Humanitarian Data) et open.africa publient gratuitement les limites régions, départements et districts de santé du Cameroun (GeoJSON/shapefile).
- Les quartiers de Douala et Yaoundé sont disponibles dans OpenStreetMap (place=suburb/neighbourhood), extractibles via Overpass ou Geofabrik.
- geopostcodes et geolocet (niveau commune, admin level 8) sont payants : rejetés.

## Recommandation
Inchangée. Importer dans PostGIS les limites HDX/open.africa et les quartiers OSM, puis rattacher chaque commerçant par ST_Contains pour filtrer « près de moi » et par quartier. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://open.africa/dataset/cameroon-regions
- https://geo.btaa.org/catalog/59c145a6-7ede-4021-96b0-6aff58296d34
- https://geolocet.com/products/cameroon-admin-level-8
- https://www.geopostcodes.com/en-GB/country/cameroon/shapefile/


---

<!-- source : recherche-apis-github-addendum-202-2026-10-14-netbuis.md -->

# Addendum 202 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 05:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : forcer ou proposer la mise à jour de l'app Flutter (utile quand l'API Django change pendant le pilote).
- upgrader (larryaasen/upgrader, MIT) : vérifie la version sur le Play Store et affiche une alerte « Mettre à jour », configurable via un fichier Appcast.
- in_app_update (jonasbark/flutter_in_app_update) : API officielle Android In-App Updates (mode immédiat ou flexible).
- force_update_helper, rast_force_update, force_upgrader : petites variantes, peu maintenues.

## Recommandation
Inchangée. Pour le MVP, exposer un endpoint Django `/api/app-config/` renvoyant `min_version`, et bloquer l'app avec un écran « Mettre à jour » + lien Play Store si la version est inférieure. Ajouter in_app_update plus tard si besoin. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://pub.dev/documentation/upgrader/latest/
- https://docsearch.algolia.com/mcp/docs/repo/jonasbark/flutter_in_app_update
- https://fluttergems.dev/packages/force_update_helper/
- https://appupgrade.dev/blog/how-to-force-upgrade-flutter-app


---

<!-- source : recherche-apis-github-addendum-203-2026-10-14-netbuis.md -->

# Addendum 203 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 06:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : liens partageables (deep links) pour envoyer un produit ou un commerçant via WhatsApp et l'ouvrir directement dans l'app.
- app_links (pub.dev, Apache-2.0) : gère Android App Links et iOS Universal Links sans Firebase Dynamic Links (arrêté en 2025).
- go_router sait router ces liens nativement.
- smart_links, deeplink_sdk, flutter_deep_linker : surcouches récentes, peu adoptées.

## Recommandation
Inchangée. Servir `https://netbuis.cm/m/<id>` depuis Django (page web de secours + fichier `/.well-known/assetlinks.json`), ouvrir dans l'app via app_links + go_router, et partager avec share_plus vers WhatsApp. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://fluttergems.dev/packages/app_links/
- https://theflutterk.it.com/blog/flutter-deep-linking-universal-app-links-2026
- https://dev.to/djsmk123/connecting-the-dots-exploring-flutter-deep-linking-for-seamless-user-experiences-without-firebase-part-1-47ep
- https://pub.dev/documentation/smart_links/latest/


---

<!-- source : recherche-apis-github-addendum-204-2026-10-14-netbuis.md -->

# Addendum 204 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 07:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : pagination et compression de l'API Django pour réseaux mobiles lents.
- DRF fournit déjà CursorPagination (pas de COUNT(*), stable pour un fil infini).
- django-modern-rest (wemake-services) ajoute une pagination par curseur en 2026, mais c'est un framework alternatif à DRF : rejeté pour le MVP.
- Ticket Django #37220 : Paginator sans COUNT en discussion, pas encore livré.

## Recommandation
Inchangée. DRF CursorPagination (page_size 20) pour la liste des commerçants et le forum, GZipMiddleware (ou compression au niveau du reverse proxy), et champs minimaux dans les sérialiseurs de liste. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://pypi.org/project/django-cursor-pagination/
- https://groups.google.com/g/django-updates/c/OYY3risGK7Y
- https://codspeed.io/wemake-services/django-modern-rest/branches/neocim%3Aadd-cursor-pagination
- https://leapcell.io/blog/implementing-diverse-pagination-strategies-in-drf-and-fastapi


---

<!-- source : recherche-apis-github-addendum-205-2026-10-14-netbuis.md -->

# Addendum 205 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 08:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : application bilingue français/anglais (Cameroun).
- flutter_localizations + intl avec fichiers ARB (`gen-l10n`) : solution officielle, gratuite, guides à jour en 2026.
- easy_localization et slang : alternatives open source (JSON/YAML, typage fort pour slang), utiles mais non nécessaires.
- Le dépôt officiel flutter/skills propose désormais une « flutter-localization » skill pour agents de code.

## Recommandation
Inchangée. Utiliser gen-l10n officiel avec `app_fr.arb` (par défaut) et `app_en.arb` dès le premier écran, et `django.utils.translation` côté API pour les messages d'erreur. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://theflutterk.it.com/blog/flutter-localization-i18n-complete-guide-2026
- https://www.freecodecamp.org/news/how-to-add-multi-language-support-in-flutter-manual-and-ai-automated-translations-for-flutter-apps/
- https://skills.sh/flutter/skills/flutter-localization
- https://lingohub.com/blog/flutter-i18n-a-localization-guide


---

<!-- source : recherche-apis-github-addendum-206-2026-10-14-netbuis.md -->

# Addendum 206 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 09:57 UTC)

## Verdict
Pas de nouveauté structurante, mais un point utile : les tâches de fond (envoi FCM, OTP, confirmation de paiement Campay, calcul des tendances).
- Django 6.0 (déc. 2025) intègre un framework de tâches (`django.tasks`, `@task`, `.enqueue()`), mais sans worker en production : il faut un backend.
- django-tasks (backend base de données, par l'auteur du DEP) fournit ce worker sur PostgreSQL, sans Redis.
- VTasks (GlitchTip, avril 2026) se dit 4x plus rapide que Celery ; trop jeune pour le MVP.
- Celery reste l'option lourde (Redis/RabbitMQ), inutile au pilote.

## Recommandation
Inchangée sur le fond. Écrire les tâches avec l'API standard `django.tasks` et le backend base de données de django-tasks (un seul worker, même PostgreSQL) ; passer à Celery seulement si le volume l'exige. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://lincolnloop.com/blog/django-6-tasks-background-processing-without-the-infrastructure/
- https://www.loopwerk.io/articles/2026/django-tasks-review/
- https://glitchtip.com/blog/2026-04-13-django-vtasks
- https://betterstack.com/community/guides/scaling-python/django-background-tasks/


---

<!-- source : recherche-apis-github-addendum-207-2026-10-14-netbuis.md -->

# Addendum 207 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 10:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : regrouper les commerçants sur la carte (clusters) quand ils sont nombreux dans un quartier.
- flutter_map_marker_cluster (BSD-3, port de Leaflet.markercluster) : plugin flutter_map le plus utilisé ; forks récents flutter_map_marker_cluster_plus et _2.
- flutter_map_radius_cluster : clustering côté serveur/isolate pour gros volumes.
- MapLibre GL gère nativement le clustering des sources GeoJSON (option `cluster: true`), sans plugin.

## Recommandation
Inchangée. Au pilote (30 commerçants), pas de clustering nécessaire : liste triée par distance + carte simple. Si la carte MapLibre est retenue, activer `cluster: true` sur la source GeoJSON le moment venu. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://github.com/cromoteca/flutter_map_marker_cluster
- https://pub.dev/packages/flutter_map_marker_cluster_plus
- https://github.com/rorystephenson/flutter_map_radius_cluster
- https://docs.fleaflet.dev/v4/plugins/list


---

<!-- source : recherche-apis-github-addendum-208-2026-10-14-netbuis.md -->

# Addendum 208 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 11:57 UTC)

## Verdict
Pas de nouveauté structurante, mais un gain de temps concret : le back-office pour saisir et modérer les 30 commerçants pilotes.
- django-unfold (MIT, maintenu en 2026) : thème moderne de l'admin Django (Tailwind), filtres, onglets, tableaux de bord, responsive mobile. Gratuit ; « Unfold Studio » est l'offre payante optionnelle.
- django-admin-interface : alternative plus légère, moins de fonctions.

## Recommandation
Inchangée sur le fond. Utiliser l'admin Django + django-unfold comme back-office du pilote (saisie commerçants, file de signalements, avis) au lieu de coder un dashboard. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://pypi.org/project/django-unfold
- https://unfoldadmin.com/blog/django-admin-customization/
- https://unfoldadmin.com/compare/django-unfold-vs-django-admin-interface/
- https://adminlte.io/blog/django-admin-dashboard-templates/


---

<!-- source : recherche-apis-github-addendum-209-2026-10-14-netbuis.md -->

# Addendum 209 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 12:58 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : écrans de chargement « squelette » pendant la recherche de commerçants sur réseau lent.
- skeletonizer (MIT) : transforme automatiquement un widget existant en squelette animé, sans dessiner d'écran à part.
- skeletonizer_plus, hollow, flutter_loading_skeleton : variantes récentes, moins adoptées.

## Recommandation
Inchangée. Envelopper la liste des résultats dans `Skeletonizer(enabled: isLoading, ...)`, avec effet shimmer désactivable sur téléphones bas de gamme. Détail de finition, pas prioritaire. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://medium.com/@flutternewshub/introducing-skeletonizer-effortless-skeleton-loading-for-flutter-08c4ee5632f3
- https://medium.com/@fahadbhatt/smooth-loading-in-flutter-with-skeletonizer-no-extra-code-needed-5baa5cf44521
- https://pub.dev/documentation/skeletonizer_plus/latest/
- https://pub.dev/packages/hollow/license


---

<!-- source : recherche-apis-github-addendum-210-2026-10-14-netbuis.md -->

# Addendum 210 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 13:57 UTC)

## Verdict
Pas de nouveauté structurante, mais un vrai accélérateur : documenter l'API Django et générer le client Dart au lieu de l'écrire à la main.
- drf-spectacular (BSD-3, maintenu) : génère le schéma OpenAPI 3 depuis les vues DRF, avec Swagger UI / ReDoc.
- openapi-generator (Apache-2.0) : génère un client Dart (dart-dio) à partir de ce schéma ; Django Software Foundation a publié un guide « Django → clients via OpenAPI » (août 2025).
- Speakeasy et liblab : générateurs SDK commerciaux, rejetés.

## Recommandation
Inchangée sur le fond. Ajouter drf-spectacular dès le premier endpoint (`/api/schema/` + `/api/docs/`), puis générer le client Dio pour Flutter avec openapi-generator (`-g dart-dio`) à chaque changement d'API. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://drf-spectacular.readthedocs.io/
- https://www.djangoproject.com/weblog/2025/aug/13/building-better-apis-django-to-clients-openapi/
- https://speakeasy.com/openapi/frameworks/django
- https://liblab.com/docs/howto/django


---

<!-- source : recherche-apis-github-addendum-211-2026-10-14-netbuis.md -->

# Addendum 211 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 14:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : protéger la connexion et l'OTP contre la force brute.
- django-axes (MIT, Jazzband) : verrouille un compte/IP après N échecs de connexion, compatible DRF/simplejwt via backend d'authentification.
- DRF throttling intégré (AnonRateThrottle, UserRateThrottle, ScopedRateThrottle) : limite le débit par endpoint, sans paquet supplémentaire.
- Grille « antiflood » de djangopackages : django-ratelimit, alternatives équivalentes.

## Recommandation
Inchangée. ScopedRateThrottle sur `/auth/otp/` (ex. 3/min, 10/heure par numéro) et sur la connexion ; django-axes optionnel si le mot de passe est utilisé. Lancer `manage.py check --deploy` avant la mise en ligne. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://pypi.org/project/django-axes/6.0.3
- https://github.com/GitRon/django-axes
- https://www.djangopackages.org/grids/g/antiflood/
- https://web2.djangopackages.org/grids/g/security


---

<!-- source : recherche-apis-github-addendum-212-2026-10-14-netbuis.md -->

# Addendum 212 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 15:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : automatiser la compilation et la distribution de l'APK aux testeurs pilotes.
- GitHub Actions (gratuit, 2 000 min/mois en dépôt privé) + subosito/flutter-action : `flutter build apk --split-per-abi` à chaque push.
- fastlane (MIT) + `supply` : envoi automatique vers le Play Store (piste « test interne »).
- freeCodeCamp publie en 2026 un guide complet « pipeline Flutter prêt pour la production » (quality gates, environnements, stores).

## Recommandation
Inchangée. Au pilote : un workflow GitHub Actions qui compile l'APK et le publie en artefact/Release, distribué aux 30 commerçants par lien WhatsApp ou via la piste test interne Play. fastlane seulement au moment de la publication publique. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://www.freecodecamp.org/news/how-to-build-a-production-ready-flutter-ci-cd-pipeline-with-github-actions-quality-gates-environments-and-store-deployment/
- https://www.freecodecamp.org/news/how-to-automate-flutter-releases-with-fastlane-and-github-actions/
- https://dev.to/vachhanirishi/streamline-your-flutter-development-complete-cicd-pipeline-with-github-actions-and-google-play-21fc
- https://nferdazel.medium.com/automatically-release-your-flutter-app-to-google-play-store-37089e89421a


---

<!-- source : recherche-apis-github-addendum-213-2026-10-14-netbuis.md -->

# Addendum 213 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 16:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : sauvegarde de la base PostgreSQL (commerçants, avis, forum).
- pgBackRest (MIT) et WAL-G (Apache-2.0) : sauvegardes complètes + WAL avec restauration à un instant donné, vers stockage S3 (Cloudflare R2, Backblaze B2).
- Les classements 2026 (Hackernoon, DEV) les placent en tête des outils open source.
- Au pilote, `pg_dump` quotidien compressé vers un stockage S3-compatible suffit ; les hébergeurs managés incluent souvent déjà des sauvegardes.

## Recommandation
Inchangée. Pilote : sauvegarde automatique de l'hébergeur ou `pg_dump` nocturne (cron / tâche Django) vers R2, avec un test de restauration avant l'ouverture. pgBackRest/WAL-G à l'échelle production. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://hackernoon.com/top-10-open-source-postgresql-backup-tools-in-2026
- https://cdn.jsdelivr.net/gh/pgbackrest/pgbackrest@main/README.md
- https://stackharbor.com/en/knowledge-base/postgres-wal-g-backup-restore/
- https://dev.to/dmetrovich/top-postgresql-backup-tools-in-2026-5h07


---

<!-- source : recherche-apis-github-addendum-214-2026-10-14-netbuis.md -->

# Addendum 214 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 17:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : accessibilité et inclusion (grandes polices, utilisateurs peu à l'aise avec l'écrit, lecteurs d'écran).
- Flutter intègre Semantics, respect du `textScaler` système, contrastes et cibles tactiles 48 dp ; guide officiel docs.flutter.dev.
- Outils gratuits : `meetsGuideline(androidTapTargetGuideline)` dans les tests, Accessibility Scanner Android, règles lint DCM.
- Very Good Ventures publie un retour d'expérience « inclusion numérique » avec Flutter.

## Recommandation
Inchangée. Dès le MVP : icônes + texte sur les boutons Appeler / WhatsApp / Payer, polices qui suivent le réglage du téléphone, boutons ≥ 48 dp, et un test `meetsGuideline` par écran. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://docs.flutter.dev/ui/accessibility/ui-design-and-styling.html
- https://verygood.ventures/blog/exploring-accessibility-and-digital-inclusion-with-flutter.md
- https://dcm.dev/blog/2025/06/30/accessibility-flutter-practical-tips-tools-code-youll-actually-use/
- https://dev.to/adepto/improving-accessibility-in-flutter-apps-a-comprehensive-guide-1jod


---

<!-- source : recherche-apis-github-addendum-215-2026-10-14-netbuis.md -->

# Addendum 215 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 18:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : savoir tout de suite si l'API tombe pendant le pilote.
- django-health-check (MIT) : endpoint `/health/` qui vérifie base, cache, stockage.
- Uptime Kuma (MIT, auto-hébergé) ou Healthchecks.io (offre gratuite) : sondent l'endpoint et alertent par Telegram, e-mail ou WhatsApp via webhook.
- django-watchman : alternative équivalente.

## Recommandation
Inchangée. Ajouter django-health-check + une sonde gratuite (UptimeRobot / Healthchecks.io ou Uptime Kuma) avec alerte Telegram ; Healthchecks.io peut aussi surveiller la sauvegarde nocturne. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://dev.co/observability/open-source/django-health-check
- https://django-watchman.readthedocs.io/en/latest/reference/monitoring-integrations/
- https://instapods.com/apps/uptime-kuma/vs/healthchecks/
- https://djangopackages.org/grids/g/monitoring/packages/


---

<!-- source : recherche-apis-github-addendum-216-2026-10-14-netbuis.md -->

# Addendum 216 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 19:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : recherche plein texte en français dans Django (accents, pluriels).
- `django.contrib.postgres.search` (Django 6.x) : SearchVector + SearchQuery avec `config='french'` pour la racinisation (« tomates » trouve « tomate »).
- Extension `unaccent` (via `UnaccentExtension()` en migration) avec le lookup `__unaccent` : « cafe » trouve « café ».
- Combinaison conseillée pour la barre de recherche : pg_trgm (fautes de frappe, déjà retenu) + unaccent, puis SearchRank uniquement si le catalogue grossit.
- Pour le pilote de 30 commerçants, `icontains` + unaccent + trigram suffit ; aucun moteur externe (Meilisearch, Typesense) n'est nécessaire.

## Recommandation
Inchangée. Ajouter la migration `UnaccentExtension` à côté de `TrigramExtension` lors de la mise en place de la recherche. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://docs.djangoproject.com/es/6.1/ref/contrib/postgres/search/
- https://django.readthedocs.io/en/6.1.x/_sources/ref/contrib/postgres/search.txt
- https://oneuptime.com/blog/post/2026-02-02-django-full-text-search/view
- https://emptyhammock.com/blog/Postgres-full-text-search-with-Django.html


---

<!-- source : recherche-apis-github-addendum-217-2026-10-14-netbuis.md -->

# Addendum 217 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 20:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : compression des photos produits avant envoi (réseau mobile camerounais, forfaits data limités).
- `image_picker` permet déjà de réduire la photo à la capture (`maxWidth`, `maxHeight`, `imageQuality`). Avec `maxWidth: 1280, imageQuality: 75`, une photo de plusieurs Mo passe à quelques centaines de Ko, sans dépendance supplémentaire.
- `flutter_image_compress` (natif, sortie WebP/JPEG) ou `image_compressor` restent possibles si l'on veut ensuite convertir en WebP ; ce n'est pas nécessaire pour le pilote.
- Côté Django, garder une limite de taille (`DATA_UPLOAD_MAX_MEMORY_SIZE`) et générer une vignette avec Pillow, déjà présent dans la pile.

## Recommandation
Inchangée. Paramétrer `image_picker` (1280 px, qualité 75) dès l'écran « ajouter un produit ». Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://pub.dev/packages/image_compressor
- https://pub.dev/documentation/selectcropcompressimage/latest/
- https://rapidevelopers.com/app-features/file-compression-and-optimization
- https://www.rapidevelopers.com/md/app-features/file-compression-and-optimization


---

<!-- source : recherche-apis-github-addendum-218-2026-10-14-netbuis.md -->

# Addendum 218 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 21:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : mode hors ligne léger côté Flutter (coupures réseau fréquentes).
- Les guides 2026 convergent vers drift (SQLite typé) + Riverpod + connectivity_plus, avec une file d'attente de synchronisation pour les écritures.
- Pour NETBUIS, l'essentiel est en lecture : derniers résultats de recherche et fiches commerçants consultées. Un cache HTTP Dio (dio_cache_interceptor, politique « cache puis réseau ») suffit pour le pilote, sans base locale.
- drift ne devient utile que si les commerçants doivent saisir des produits hors ligne ; à réévaluer après le jalon 0.

## Recommandation
Inchangée. Ajouter un intercepteur de cache Dio et un bandeau « hors ligne » via connectivity_plus ; pas de synchronisation complexe avant le pilote. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://geekyants.com/blog/offline-first-flutter-implementation-blueprint-for-real-world-apps
- https://dev.to/mohamed_haizoun_ca3869828/offline-first-sync-in-flutter-with-drift-and-riverpod-5een
- https://gtstu.com/?p=5109
- https://dev.to/anurag_dev/implementing-offline-first-architecture-in-flutter-part-2-building-sync-mechanisms-and-handling-4mb1


---

<!-- source : recherche-apis-github-addendum-219-2026-10-14-netbuis.md -->

# Addendum 219 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 22:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : historique des modifications (prix, numéro de téléphone, statut d'un commerçant).
- django-simple-history (django-commons) : une table d'historique par modèle, avec un onglet « Historique » intégré à django-unfold, déjà retenu pour l'admin.
- django-auditlog : un seul journal JSON des changements, plus léger, mais moins pratique pour restaurer une version.
- Pour NETBUIS, l'historique sert surtout à répondre à « qui a changé le prix ou le numéro de ce commerçant ? ». django-simple-history sur `Merchant` et `Product` suffit.

## Recommandation
Inchangée. Activer django-simple-history sur Merchant et Product lors de la mise en place de l'admin unfold ; pas avant. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://www.mintlify.com/unfoldadmin/django-unfold/integrations/django-simple-history
- https://platform-django-template.readthedocs.io/en/latest/4-guides/model-auditing-history.html
- https://django-auditlog.readthedocs.io/
- https://web2.djangopackages.org/grids/g/model-audit


---

<!-- source : recherche-apis-github-addendum-220-2026-10-14-netbuis.md -->

# Addendum 220 — APIs GitHub gratuites 2026 (run planifié, 2026-10-14 23:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : validation des numéros de téléphone camerounais (cœur du bouton « Appeler » et des liens wa.me).
- django-phonenumber-field (sur la bibliothèque phonenumbers de Google) : `PhoneNumberField(region="CM")` stocke au format E.164 (+2376XXXXXXXX) et rejette les numéros invalides.
- Au Cameroun, les mobiles comptent 9 chiffres commençant par 6 (Orange, MTN, Camtel/Nexttel) ; les fixes commencent par 2. La normalisation E.164 sert directement pour `tel:` et `wa.me/2376…`.
- Côté Flutter, inutile d'ajouter un paquet : un masque simple et la validation serveur suffisent pour le pilote.

## Recommandation
Inchangée. Utiliser `PhoneNumberField(region="CM")` sur Merchant dès le modèle initial pour éviter un nettoyage de données plus tard. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://pypi.org/p/django-phonenumber-field
- https://www.sent.dm/en/resources/phone-number-standards/cm
- https://openapps.pro/packages/django-phonenumber-field
- https://www.piwheels.org/project/django-phonenumber-field/


---

<!-- source : recherche-apis-github-addendum-221-2026-10-15-netbuis.md -->

# Addendum 221 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 00:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : demander une note sur le Play Store depuis l'application.
- `in_app_review` (britannio) reste la référence : il ouvre la fenêtre de notation native de Google Play sans quitter l'app. Google limite lui-même la fréquence d'affichage.
- Bonne pratique (Code With Andrea) : déclencher la demande après une action réussie, par exemple après le 3e appel ou contact WhatsApp vers un commerçant, jamais au premier lancement.
- smart_review_prompter et app_review_promoter ajoutent seulement des compteurs ; quelques lignes de code avec shared_preferences suffisent.

## Recommandation
Inchangée. Utile au moment de la publication sur le Play Store, pas pendant le pilote distribué en APK. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://fluttergems.dev/packages/in_app_review/
- https://codewithandrea.com/articles/flutter-in-app-review-prompt/
- https://gittrend.io/repo/britannio/in_app_review
- https://pub.dev/packages/smart_review_prompter/versions/1.1.0


---

<!-- source : recherche-apis-github-addendum-222-2026-10-15-netbuis.md -->

# Addendum 222 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 01:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : partager une fiche commerçant ou un produit (bouche-à-oreille via WhatsApp).
- `share_plus` (Flutter Community, officiel) ouvre la feuille de partage native du téléphone ; WhatsApp y apparaît d'office. C'est suffisant.
- share_whatsapp_plus, whatsapp_share_plus et open_share_plus ciblent WhatsApp directement, mais ce sont des paquets peu maintenus ; à éviter.
- Le lien partagé doit pointer vers une URL https du domaine NETBUIS ; avec app_links (addendum déjà retenu), il ouvre l'app si elle est installée, sinon une page web minimale de la fiche.

## Recommandation
Inchangée. Ajouter un bouton « Partager » sur la fiche commerçant avec share_plus, une fois les deep links en place. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://fluttergems.dev/sharing-intent/
- https://pub.dev/documentation/whatsapp_share_plus/latest/
- https://fluttergems.dev/packages/open_share_plus/
- https://pub.dev/packages/share_whatsapp_plus/example


---

<!-- source : recherche-apis-github-addendum-223-2026-10-15-netbuis.md -->

# Addendum 223 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 02:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : trier les résultats de recherche par distance (« commerçants près de moi »).
- Côté Flutter, `geolocator` donne la position une fois, à la recherche, avec la permission « pendant l'utilisation ». Inutile de suivre la position en continu.
- Côté Django, GeoDjango sur PostGIS (déjà retenu) : filtre `location__dwithin=(point, D(km=5))` puis `annotate(distance=Distance("location", point)).order_by("distance")`, avec un index GiST sur `location`.
- geo_sort (tri côté client) n'est utile que sans backend ; le tri doit se faire en base.
- Si l'utilisateur refuse la localisation, retomber sur un tri par quartier ou ville saisi à la main.

## Recommandation
Inchangée. Prévoir le champ `location` (PointField) et l'index GiST dès le modèle Merchant ; le tri par distance vient avec la barre de recherche. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://dev.to/adamghill/searching-within-an-area-with-geodjango-and-postgis-24g8
- https://peerj.com/articles/cs-3220
- https://pub.dev/documentation/geo_sort/latest/
- https://rapidevelopers.com/app-features/geolocation


---

<!-- source : recherche-apis-github-addendum-224-2026-10-15-netbuis.md -->

# Addendum 224 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 03:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : QR code de la fiche commerçant (autocollant en boutique ou au marché).
- Le plus simple n'a besoin d'aucun paquet Flutter : générer côté Django un QR (bibliothèque Python `segno` ou `qrcode`) qui encode l'URL https de la fiche. L'appareil photo du téléphone l'ouvre directement, et app_links (déjà retenu) bascule vers l'app si elle est installée.
- `qr_flutter` (affichage) et `mobile_scanner` (lecture) restent les références Flutter si l'on veut un écran « Mon QR » ou un scanner dans l'app ; ce n'est pas nécessaire pour le pilote.
- flutter_qris et les QR de paiement Flutterwave concernent l'Indonésie ou le paiement ; hors sujet pour NETBUIS (Campay reste retenu).

## Recommandation
Inchangée. Une action d'admin « Imprimer le QR » par commerçant suffit pour le terrain ; c'est un bon support pour recruter les 30 commerçants pilotes. Priorité toujours au jalon 0.

## Sources
- https://www.rapidevelopers.com/app-features/qr-scanner
- https://medium.com/pubdev-essentials/scan-smarter-in-flutter-with-mobile-scanner-a-powerful-camera-based-qr-and-barcode-solution-b53b4a4a7edb
- https://pub.dev/documentation/flutter_qris/latest/
- https://dev.to/flutterwaveeng/how-to-set-up-qr-code-payments-in-your-app-5bja


---

<!-- source : recherche-apis-github-addendum-225-2026-10-15-netbuis.md -->

# Addendum 225 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 04:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : horaires d'ouverture et badge « Ouvert maintenant » sur la fiche commerçant.
- django-openinghours (fusionbox) existe mais n'est plus maintenu ; il n'apporte pas grand-chose de plus qu'un petit modèle maison.
- Modèle maison suffisant : `OpeningHours(merchant, weekday, opens, closes)`, plusieurs lignes par jour possibles, fuseau `Africa/Douala` (UTC+1, pas d'heure d'été).
- Le filtre « ouvert maintenant » se fait en une requête : jour courant et heure courante entre `opens` et `closes`.
- Le format OpeningHoursSpecification de schema.org peut servir plus tard pour les pages web publiques des fiches (référencement), pas pour l'app.

## Recommandation
Inchangée. Les horaires restent optionnels pour le pilote ; un champ texte libre « Horaires » sur Merchant suffit au début, le modèle structuré viendra si les utilisateurs filtrent par ouverture. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://github.com/fusionbox/django-openinghours
- https://pypi.org/project/django-openinghours/0.0.32
- https://rdrr.io/github/ropenscilabs/datasauce/man/OpeningHoursSpecification.html
- https://docs.mappedin.com/web/v6/latest/types/OperationHours.html


---

<!-- source : recherche-apis-github-addendum-226-2026-10-15-netbuis.md -->

# Addendum 226 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 05:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : stockage des photos produits et vignettes côté serveur.
- django-storages (backend S3) fonctionne tel quel avec Cloudflare R2, déjà retenu pour les sauvegardes : 10 Go gratuits et pas de frais de sortie (guide TestDriven.io).
- Vignettes : sorl-thumbnail (maintenu, porté sur Django 5.2) ou easy-thumbnails génèrent à la volée des tailles 200 px et 800 px ; la compression côté Flutter (addendum 217) réduit déjà le poids à l'envoi.
- Servir les images par une URL publique R2 ou un sous-domaine Cloudflare suffit ; django-cloudflare-cdn n'est pas nécessaire.

## Recommandation
Inchangée. Configurer `STORAGES["default"]` sur R2 dès le premier déploiement pour éviter de migrer les fichiers plus tard ; une seule taille de vignette suffit pour le pilote. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://testdriven.io/blog/django-cloudflare-r2/
- https://www.djangopackages.org/grids/g/thumbnails/
- https://pypi.python.org/pypi/sorl-thumbnail
- https://pypi.python.org/pypi/easy-thumbnails


---

<!-- source : recherche-apis-github-addendum-227-2026-10-15-netbuis.md -->

# Addendum 227 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 06:58 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : remonter les plantages de l'app Flutter des commerçants pilotes.
- Firebase Crashlytics : gratuit sans limite et s'ajoute au projet Firebase déjà ouvert pour FCM. C'est le choix le plus court.
- Sentry (sentry_flutter) : offre gratuite limitée (environ 5 000 erreurs par mois) mais couvre aussi Django avec le même outil ; utile si l'on veut un seul tableau de bord front et back.
- Les retours de la communauté (r/FlutterDev, StackShare) vont dans le même sens : Crashlytics pour démarrer gratuitement, Sentry quand on veut le suivi des performances et du backend.

## Recommandation
Inchangée. Activer Crashlytics avec FCM dans l'APK du pilote ; garder les logs Django simples pour l'instant. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://sentry.io/from/crashlytics
- https://stackshare.io/stackups/crashlytics-vs-sentry
- https://blog.back4app.com/sentry-vs-firebase/
- https://theflutterk.it.com/alternative/sentry-alternative-flutter


---

<!-- source : recherche-apis-github-addendum-228-2026-10-15-netbuis.md -->

# Addendum 228 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 07:58 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : catégories de produits (alimentation, quincaillerie, téléphonie…) pour filtrer la recherche.
- django-categories (Jazzband, basé sur django-mptt) et django-treebeard gèrent des arbres de catégories illimités, avec une API DRF disponible (django-categories-api).
- django-mptt n'est plus activement maintenu ; treebeard reste l'option sûre si un arbre devient nécessaire.
- Pour le pilote, deux niveaux suffisent : un modèle `Category(name, parent=ForeignKey("self", null=True))` et une liste fixe d'environ 15 catégories chargée par une migration de données. Aucun paquet n'est nécessaire.

## Recommandation
Inchangée. Définir la liste des catégories avec les 30 commerçants pilotes plutôt qu'à l'avance ; le modèle simple à deux niveaux suffit. Priorité toujours au jalon 0.

## Sources
- https://github.com/jazzband/django-categories
- https://pypi.org/project/django-categories/
- https://pypi.python.org/pypi/django-categories-api/
- https://blog.devgenius.io/visualizing-hierarchical-data-categories-tags-and-trees-in-django-apis-4b25f5e95c6c


---

<!-- source : recherche-apis-github-addendum-229-2026-10-15-netbuis.md -->

# Addendum 229 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 08:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : modération du forum natif (signalements, spam, insultes).
- django-moderator (filtrage de commentaires par classifieur bayésien) est ancien et pensé pour l'anglais ; inutile pour un petit forum francophone.
- Le guide 2026 sur les communautés auto-hébergées recommande la même base : bouton « Signaler », masquage automatique après N signalements, file de modération dans l'admin, et limite de fréquence de publication.
- Côté NETBUIS : un modèle `Report(post, reporter, reason)`, un seuil (par exemple 3 signalements = masqué en attente), ScopedRateThrottle déjà retenu sur la création de posts, et une liste de mots interdits en français ou pidgin tenue à la main.

## Recommandation
Inchangée. Le forum n'est pas dans le jalon 0 ; prévoir seulement le bouton « Signaler » et la file d'admin unfold quand il sera ouvert. Priorité toujours aux 30 commerçants pilotes.

## Sources
- https://dasroot.net/posts/2026/01/moderation-tools-self-hosted-communities/
- https://pypi.org/project/django-moderator
- https://pypi.org/project/django-moderator/1.0.2
- https://pypi.python.org/pypi/django-moderator/0.1.3


---

<!-- source : recherche-apis-github-addendum-230-2026-10-15-netbuis.md -->

# Addendum 230 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 09:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : calcul des « produits tendance ».
- Les approches 2026 (RisingWave, ClickHouse) reposent sur un score à décroissance exponentielle : chaque événement (recherche, vue, appel, clic WhatsApp) pèse moins avec le temps. Ces moteurs de streaming sont surdimensionnés pour NETBUIS.
- Version PostgreSQL suffisante : une table `Event(product, kind, created_at)` et une vue matérialisée qui calcule `sum(poids * exp(-age_heures / 48))` par produit, rafraîchie toutes les heures par une tâche `django.tasks` (déjà retenu).
- Une étude 2025 sur les recommandations e-commerce confirme qu'une popularité récente pondérée bat les modèles complexes quand il y a peu de données, ce qui est le cas du pilote.

## Recommandation
Inchangée. Commencer à enregistrer les événements (recherche, appel, WhatsApp) dès le pilote, car ils serviront aussi à mesurer le jalon 0 ; l'écran « Tendances » viendra quand il y aura assez de données. Priorité toujours aux 30 commerçants pilotes.

## Sources
- https://oneuptime.com/blog/post/2026-03-31-clickhouse-exponential-decay-functions/markdown
- https://scitepress.org/publishedPapers/2025/142869/pdf/index.html
- https://www.skills.sh/lvtd-llc/skills/django-materialized-views
- https://risingwave.com/blog/real-time-feature-engineering-recommendations/


---

<!-- source : recherche-apis-github-addendum-231-2026-10-15-netbuis.md -->

# Addendum 231 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 10:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : notes et avis sur les commerçants.
- django-rated-reviews existe (avis notés génériques via contenttypes), mais il ajoute une dépendance pour peu de gain.
- Un modèle simple suffit : `Review(merchant, user, rating 1-5, comment, created_at)` avec contrainte unique (merchant, user) et `Avg("reviews__rating")` en annotation DRF.
- calc-product-rating n'apporte rien de plus qu'une agrégation SQL.
- Pas utile avant le pilote : les 30 premiers commerçants seront évalués par retour terrain, pas par étoiles.

## Recommandation
Inchangée. Ajouter les avis après le pilote, avec le modèle maison ci-dessus. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://pypi.org/project/django-rated-reviews/
- https://django-rated-reviews.readthedocs.io/
- https://pypi.org/project/django-rated-reviews/0.3.0/
- https://mcp.depscope.dev/pkg/pypi/calc-product-rating


---

<!-- source : recherche-apis-github-addendum-232-2026-10-15-netbuis.md -->

# Addendum 232 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 11:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : limitation de débit (anti-abus OTP, recherche, forum).
- DRF intègre déjà `ScopedRateThrottle` : définir des scopes `otp` (ex. 3/min, 10/jour), `search` (60/min), `forum_post` (10/h) dans `DEFAULT_THROTTLE_RATES`.
- Le cache Django par défaut suffit au pilote ; Redis seulement si plusieurs workers Gunicorn doivent partager les compteurs.
- django-smart-ratelimit (v1.0.x) et django-ratelimiter existent, mais n'apportent rien d'indispensable face au throttling DRF natif.
- Point de vigilance : derrière un proxy (Railway, Cloudflare), régler `NUM_PROXIES` pour que l'IP client soit la bonne.

## Recommandation
Inchangée. Activer `ScopedRateThrottle` sur l'endpoint OTP dès le jalon 0 (coût SMS), le reste peut attendre. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://django-smart-ratelimit.readthedocs.io/en/latest/drf/
- https://forum.djangoproject.com/t/django-smart-ratelimit-v1-0-2-released-modern-rate-limiting-for-django/43932
- https://oneuptime.com/blog/post/2026-03-31-redis-redis-for-django-rate-limiting/markdown
- https://pypi.org/project/django-ratelimiter


---

<!-- source : recherche-apis-github-addendum-233-2026-10-15-netbuis.md -->

# Addendum 233 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 12:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : traduction de l'app (français / anglais, Cameroun bilingue).
- La solution officielle `flutter_localizations` + `intl` avec fichiers ARB (`gen-l10n`) reste la référence 2026, sans dépendance tierce.
- slang et easy_localization sont des alternatives valables mais n'apportent rien de décisif pour deux langues.
- Côté Django : `gettext` + `LocaleMiddleware` pour les messages d'API ; le client envoie `Accept-Language` via un intercepteur Dio.
- Recommandation de méthode : écrire l'app en français d'abord (`app_fr.arb`), extraire les chaînes dès le départ, ajouter `app_en.arb` après le pilote.

## Recommandation
Inchangée. Préparer l'extraction des chaînes en ARB dès le jalon 0, traduire en anglais plus tard. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://theflutterk.it.com/blog/flutter-localization-i18n-complete-guide-2026
- https://lingohub.com/blog/flutter-i18n-a-localization-guide
- https://www.f22labs.com/blogs/flutter-internationalization-and-localization-multilingual-support
- https://skills.sh/flutter/skills/flutter-localization


---

<!-- source : recherche-apis-github-addendum-234-2026-10-15-netbuis.md -->

# Addendum 234 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 13:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : mise à jour forcée de l'app (version minimale).
- Plusieurs paquets pub.dev récents (force_app_update, firebase_update, update_checker_plus, force_update_helper) couvrent le cas, souvent adossés à Firebase Remote Config.
- Plus simple pour NETBUIS : un endpoint Django `GET /api/app-config/` renvoyant `min_version` et `latest_version`, comparé au démarrage via `package_info_plus`, puis redirection vers le Play Store.
- Sur Android, le paquet `in_app_update` (API Play Core officielle) permet la mise à jour immédiate ou flexible sans quitter l'app.
- Utile dès le pilote : les 30 commerçants auront des versions de test qui changent souvent ; pouvoir bloquer une version cassée évite du support manuel.

## Recommandation
Inchangée sur le fond. Ajouter l'endpoint `app-config` avec `min_version` au jalon 0 (une heure de travail). Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://pub.dev/documentation/force_update_helper/latest/
- https://pub.dev/documentation/firebase_update/latest/
- https://pub.dev/packages/update_checker_plus/changelog
- https://pub.dev/documentation/force_app_update/latest/


---

<!-- source : recherche-apis-github-addendum-235-2026-10-15-netbuis.md -->

# Addendum 235 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 14:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : générer le client Dart depuis le schéma OpenAPI Django.
- drf-spectacular produit le schéma OpenAPI 3 de l'API DRF (avec Swagger UI pour tester).
- Côté Flutter, florval (0.3.x/0.4, récent, Dio + Riverpod) et openapi_flutter_gen génèrent modèles et appels typés depuis ce schéma ; openapi-generator (dart-dio) reste l'option établie.
- Gain réel : moins d'erreurs de champs entre backend et app. Coût : un générateur de plus à maintenir et du code généré parfois verbeux.
- Pour le pilote, une dizaine d'endpoints écrits à la main avec Dio restent plus rapides ; installer drf-spectacular tout de suite (5 minutes) pour la doc, générer le client plus tard.

## Recommandation
Inchangée. drf-spectacular dès maintenant pour documenter l'API ; génération du client Dart après le pilote si le nombre d'endpoints grandit. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://pub.dev/packages/florval
- https://pub.dev/documentation/florval/latest/
- https://pub.dev/documentation/openapi_flutter_gen/latest/
- https://docs.page/angeloavv/dart_openapi_generator


---

<!-- source : recherche-apis-github-addendum-236-2026-10-15-netbuis.md -->

# Addendum 236 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 15:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : WhatsApp Business Cloud API (messages automatiques).
- Depuis la tarification par message de Meta (2025, toujours en vigueur en 2026), les messages de service (réponse dans la fenêtre de 24 h ouverte par le client) sont gratuits ; les modèles « utility » envoyés dans cette fenêtre aussi ; les modèles marketing et authentification sont payants hors fenêtre.
- Pour NETBUIS, le contact client vers commerçant passe déjà par `wa.me` (gratuit, aucun compte Meta requis). La Cloud API ne servirait qu'aux messages envoyés par NETBUIS lui-même (confirmation de paiement, OTP).
- Coût et démarches (vérification Meta Business, numéro dédié, modèles validés) disproportionnés pour le pilote ; les SMS OTP et les notifications FCM couvrent le besoin.

## Recommandation
Inchangée. Garder `wa.me` ; réévaluer la Cloud API après le pilote si les OTP WhatsApp coûtent moins cher que les SMS au Cameroun. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://developers.facebook.com/documentation/business-messaging/whatsapp/pricing
- https://developers.facebook.com/docs/whatsapp/pricing
- https://www.spurnow.com/blogs/whatsapp-business-api-pricing-explained
- https://chakrahq.com/article/whatsapp-api-pricing-guide/amp/


---

<!-- source : recherche-apis-github-addendum-237-2026-10-15-netbuis.md -->

# Addendum 237 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 16:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : cache des images côté app (réseau lent, forfaits data).
- cached_network_image (Baseflow) reste le standard ; des variantes existent (icached_network_image, slim_cached_network_image, precached_network_image) sans avantage décisif.
- Le vrai gain vient du serveur : servir des miniatures (sorl-thumbnail, addendum 226) en WebP ~400 px pour les listes, l'image pleine taille seulement en fiche produit.
- Côté app : `memCacheWidth` / `cacheWidth` pour décoder à la taille affichée (moins de RAM sur téléphones d'entrée de gamme), placeholder flou ou couleur unie.
- Cache-Control long sur R2 (`max-age=31536000, immutable`) avec noms de fichiers versionnés.

## Recommandation
Inchangée. cached_network_image + miniatures WebP côté serveur dès le jalon 0. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://monterail.com/blog/how-to-cache-network-image-in-flutter
- https://kindacode.com/article/flutter-caching-network-images-for-big-performance-gains
- https://pub.dev/documentation/icached_network_image/latest/
- https://pub.dev/documentation/precached_network_image/latest/


---

<!-- source : recherche-apis-github-addendum-238-2026-10-15-netbuis.md -->

# Addendum 238 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 17:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : analytics produit pour mesurer le pilote.
- PostHog (open source, SDK Flutter `posthog_flutter`) offre en 2026 un palier gratuit d'environ 1 million d'événements par mois, largement suffisant pour 30 commerçants et leurs clients.
- Firebase Analytics (déjà présent via FCM et Crashlytics) est gratuit et sans quota, mais moins pratique pour les entonnoirs et l'analyse par commerçant.
- Le besoin réel du pilote tient en 5 chiffres : recherches, fiches vues, appels/WhatsApp cliqués, paiements, rétention à 7 jours. La table Event du backend (addendum 230, tendances) les fournit déjà avec quelques requêtes SQL.
- Attention à la loi camerounaise de 2024 sur la protection des données personnelles (à vérifier avec un juriste) : pas de numéro de téléphone dans les propriétés d'événements.

## Recommandation
Inchangée. Utiliser la table Event + Firebase Analytics pour le pilote ; ajouter PostHog seulement si des entonnoirs détaillés deviennent nécessaires. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://usercall.co/post/posthog-pricing
- https://ripples.sh/blog/posthog-free-tier-real-cost
- https://theflutterk.it.com/alternative/mixpanel-alternative
- https://dupple.com/learn/best-mobile-app-analytics


---

<!-- source : recherche-apis-github-addendum-239-2026-10-15-netbuis.md -->

# Addendum 239 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 18:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : surveillance de disponibilité (savoir si l'API tombe avant les commerçants).
- django-health-check fournit un endpoint `/health/` qui vérifie base PostgreSQL, cache et stockage R2.
- UptimeRobot reste gratuit en 2026 (environ 50 sondes, intervalle 5 min, alertes e-mail et Telegram) ; Better Stack a aussi un palier gratuit (10 sondes, 3 min).
- Healthchecks.io (open source, palier gratuit) surveille les tâches planifiées : sauvegardes R2 et recalcul des tendances envoient un ping à chaque exécution, une alerte part si le ping manque.
- Coût total : zéro, mise en place en moins d'une heure.

## Recommandation
Mettre en place avant le premier commerçant pilote : `/health/` + une sonde UptimeRobot + un ping Healthchecks.io sur la sauvegarde nocturne. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://agentdeals.dev/vendor/uptimerobot
- https://tools.fun/resources/best-free-uptime-monitors
- https://hyperping.com/blog/healthchecks-io-alternatives
- https://betterstack.com/community/comparisons/uptime-robot-alternatives.md


---

<!-- source : recherche-apis-github-addendum-240-2026-10-15-netbuis.md -->

# Addendum 240 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 19:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : compilation et publication automatiques de l'app Flutter.
- Codemagic garde un palier gratuit (de l'ordre de 500 minutes macOS M2 par mois pour un usage personnel), suffisant pour quelques builds Android par semaine.
- GitHub Actions (2 000 minutes gratuites par mois en dépôt privé, illimité en public) suffit pour l'APK/AAB Android : `subosito/flutter-action` + signature avec keystore en secret + upload sur la piste « test interne » du Play Store.
- Pour le pilote, la piste test interne de Google Play (jusqu'à 100 testeurs, disponible en quelques minutes) est le canal de distribution le plus simple pour les 30 commerçants, combinée à la mise à jour forcée (addendum 234).
- iOS n'est pas prioritaire au Cameroun (parc majoritairement Android).

## Recommandation
Inchangée. Un workflow GitHub Actions Android vers la piste test interne suffit pour le jalon 0 ; Codemagic seulement si iOS devient nécessaire. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://theflutterk.it.com/alternative/codemagic-alternative
- https://toolradar.com/tools/codemagic
- https://www.capterra.com/p/152573/Nevercode/reviews/?page=4
- https://www.getapp.com.au/software/2056900/codemagic


---

<!-- source : recherche-apis-github-addendum-241-2026-10-15-netbuis.md -->

# Addendum 241 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 20:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : recherche vocale (dire « pagne wax Mokolo » au lieu de taper).
- Le paquet établi `speech_to_text` utilise la reconnaissance native Android/iOS, gratuite, avec le français (fr-FR) ; hors ligne seulement si le pack de langue Google est téléchargé sur le téléphone.
- Des options hors ligne embarquées existent (whisper_cpp_flutter_plus, whisper_edge, basées sur whisper.cpp) mais ajoutent 40 à 150 Mo de modèle : trop lourd pour des téléphones d'entrée de gamme.
- Limites : accents camerounais et noms locaux (quartiers, produits) mal reconnus ; la recherche floue côté serveur (pg_trgm + unaccent, addendum 216) compense une partie des erreurs.
- Coût d'intégration faible (un bouton micro qui remplit le champ de recherche).

## Recommandation
Idée intéressante à tester avec les commerçants pilotes, mais après le jalon 0 : `speech_to_text` natif, sans modèle embarqué. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://pub.dev/packages/flutter_speech_to_text
- https://pub.dev/packages/continuous_speech_to_text
- https://pub.dev/packages/whisper_cpp_flutter_plus/changelog
- https://pub.dev/packages/whisper_edge/license


---

<!-- source : recherche-apis-github-addendum-242-2026-10-15-netbuis.md -->

# Addendum 242 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 21:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : aperçu des liens partagés sur WhatsApp (fiche produit ou commerçant).
- Quand un lien NETBUIS est partagé (share_plus, addendum 222), WhatsApp affiche titre, image et description à partir des balises Open Graph de la page web.
- django-meta (maintenu, versions 2.x) génère ces balises depuis le modèle ; trois balises écrites à la main dans un template Django suffisent aussi (`og:title`, `og:description`, `og:image`).
- Contraintes WhatsApp : image en HTTPS, idéalement moins de 300 Ko, ratio proche de 1,91:1 ; la miniature R2 (addendum 226) convient.
- Cette page web minimale sert aussi de repli pour qui n'a pas l'app (bouton « Ouvrir dans l'app » via app_links, sinon lien Play Store).

## Recommandation
Utile dès le pilote car le bouche-à-oreille passe par WhatsApp : une page publique `/m/<slug>/` par commerçant avec balises Open Graph. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://pypi.org/project/django-meta/
- https://django-meta.readthedocs.io/
- https://www.djangotricks.com/blog/2025/01/creating-open-graph-images-in-django-for-improved-social-media-sharing/
- https://dev.to/devmatsu/enhancing-link-previews-a-guide-to-open-graph-meta-tags-261i


---

<!-- source : recherche-apis-github-addendum-243-2026-10-15-netbuis.md -->

# Addendum 243 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 22:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : modération automatique des images (photos produits et forum).
- NudeNet (open source, modèle ONNX léger, exécutable sur CPU) détecte la nudité ; il peut tourner dans une tâche django.tasks après l'upload.
- Les API commerciales et les LLM vision font mieux sur les cas ambigus mais coûtent par image ; inutile au volume du pilote.
- Au jalon 0, les photos viennent de 30 commerçants connus : la modération humaine (liste « à valider » dans l'admin django-unfold) et le signalement communautaire (addendum 229) suffisent.
- À prévoir quand l'inscription des commerçants s'ouvrira au public.

## Recommandation
Inchangée. Validation manuelle dans l'admin pour le pilote ; NudeNet en tâche de fond quand les inscriptions seront ouvertes. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://pypi.org/project/NudeNet/2.0.9
- https://aireiter.com/fr/blog/nsfw-detection-api
- https://repos.ecosyste.ms/topics/nsfw-classifier
- https://pypi.org/project/vnudenet


---

<!-- source : recherche-apis-github-addendum-244-2026-10-15-netbuis.md -->

# Addendum 244 — APIs GitHub gratuites 2026 (run planifié, 2026-10-15 23:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : tests automatisés du backend.
- pytest-django + factory_boy restent le duo standard en 2026 ; `APIClient` de DRF pour tester les endpoints.
- Tests prioritaires pour le pilote, en nombre limité : recherche (accents, distance), création d'un produit par un commerçant, webhook Campay (paiement confirmé, rejeté, rejoué deux fois), OTP (expiration, limitation de débit, addendum 232).
- Le webhook de paiement est le seul point où une erreur coûte de l'argent : il mérite des tests d'idempotence avant le premier paiement réel.
- Exécution dans le workflow GitHub Actions (addendum 240) avec un service PostgreSQL + PostGIS.

## Recommandation
Inchangée. Une dizaine de tests ciblés suffisent pour le jalon 0, en commençant par le webhook Campay. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://tessl.io/registry/jbvc/django-tdd
- https://tessl.io/registry/tdg-personal/django-tdd
- https://skillselion.com/skills/affaan-m/ecc/django-tdd
- https://www.skills.sh/sergio-bershadsky/ai/django-dev-test


---

<!-- source : recherche-apis-github-addendum-245-2026-10-16-netbuis.md -->

# Addendum 245 — APIs GitHub gratuites 2026 (run planifié, 2026-10-16 00:57 UTC)

## Verdict
Pas de nouveauté structurante, mais un gain de temps concret pour l'onboarding. Thème du run : import en masse des catalogues commerçants.
- django-import-export (série 4.x) importe CSV et Excel depuis l'admin, avec aperçu avant validation et rapport d'erreurs ligne par ligne.
- django-unfold, déjà choisi pour l'admin, documente une intégration officielle (formulaires et boutons au style Unfold).
- Usage pilote : un modèle Excel simple (nom, catégorie, prix FCFA, description, nom de fichier photo) rempli sur le terrain avec chaque commerçant, puis importé en une fois ; les photos sont versées dans R2 séparément.
- Évite de saisir à la main des centaines de produits pour 30 commerçants.

## Recommandation
À intégrer au jalon 0 : `ProductResource` django-import-export branché sur l'admin Unfold, plus un modèle Excel partagé avec l'équipe terrain. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://django-import-export.readthedocs.io/
- https://unfoldadmin.com/docs/integrations/django-import-export/
- https://www.mintlify.com/unfoldadmin/django-unfold/integrations/django-import-export
- https://django-import-export.readthedocs.io/en/4.3.1/_sources/release_notes.rst.txt


---

<!-- source : recherche-apis-github-addendum-246-2026-10-16-netbuis.md -->

# Addendum 246 — APIs GitHub gratuites 2026 (run planifié, 2026-10-16 01:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : base de données locale dans l'app (favoris, historique de recherche, brouillons).
- Drift (SQLite typé) reste l'option la plus sûre et la mieux maintenue en 2026 ; ObjectBox est rapide et maintenu par une entreprise.
- Isar et Hive ont connu de longues périodes sans maintenance de leurs auteurs d'origine (forks communautaires depuis) : à éviter pour un nouveau projet.
- Pour le pilote, le besoin local est minime : `shared_preferences` pour les réglages, le cache Dio (addendum 218) pour les réponses API, une petite liste de favoris en JSON. Pas besoin de base locale.
- Si un mode hors ligne réel devient nécessaire (consulter des fiches sans réseau), Drift sera le choix.

## Recommandation
Inchangée. Pas de base locale au jalon 0 ; Drift plus tard si le hors-ligne devient une demande des commerçants. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://powersync.com/blog/flutter-local-database-options.md
- https://objectbox.io/category/mobile-database/objectbox/page/3
- https://greenrobot.org/database/flutter-databases-2023-overview
- https://redlib.hbubli.cc/r/FlutterDev/comments/1bnho2p/isar_vs_sqlite


---

<!-- source : recherche-apis-github-addendum-247-2026-10-16-netbuis.md -->

# Addendum 247 — APIs GitHub gratuites 2026 (run planifié, 2026-10-16 02:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : sécurité minimale avant mise en ligne.
- `python manage.py check --deploy` liste les réglages manquants (DEBUG, HSTS, cookies sécurisés, SECURE_PROXY_SSL_HEADER derrière Railway).
- django-axes bloque les tentatives répétées de connexion à l'admin ; changer aussi l'URL `/admin/` par défaut.
- Secrets (clé Django, Campay, R2, FCM) uniquement en variables d'environnement, jamais dans le dépôt ; activer l'analyse de secrets de GitHub.
- Webhook Campay : vérifier la signature et l'IP source avant de créditer un paiement (lien avec les tests de l'addendum 244).
- django-csp n'est utile que pour les pages web (fiche publique, addendum 242) ; l'API JSON n'en a pas besoin.

## Recommandation
À faire avant le premier commerçant pilote, une demi-journée : `check --deploy` propre, django-axes, URL admin changée, vérification de signature Campay. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://testdriven.io/tips/81b24f1a-75ee-42d4-afe1-611aa75a1b64
- https://dev.to/sizan_mahmud0_e7c3fd0cb68/django-security-10-essential-steps-to-secure-your-project-before-production-4lfn
- https://openapps.pro/packages/django-axes
- https://capitalnumbers.com/blog/?p=10828


---

<!-- source : recherche-apis-github-addendum-248-2026-10-16-netbuis.md -->

# Addendum 248 — APIs GitHub gratuites 2026 (run planifié, 2026-10-16 03:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : pool de connexions PostgreSQL côté Django.
- Depuis Django 5.1, le backend PostgreSQL gère un pool natif via psycopg 3 : `DATABASES["default"]["OPTIONS"] = {"pool": True}` (ou un dict `{"min_size": 2, "max_size": 10, "timeout": 10}`), avec `pip install "psycopg[binary,pool]"`. Gratuit, open source, aucun service externe.
- Le pool natif est incompatible avec `CONN_MAX_AGE` non nul : laisser `CONN_MAX_AGE = 0` quand `pool` est activé.
- Le pool est par processus : dimensionner `max_size × nombre de workers gunicorn` sous la limite `max_connections` de l'offre Postgres hébergée (souvent 20 à 100 sur les petits plans).
- PgBouncer reste l'option si l'hébergeur le fournit déjà ; inutile de l'ajouter pour le pilote.

## Recommandation
Activer `"pool": {"min_size": 1, "max_size": 4}` avec 2 workers gunicorn dès la mise en production, sinon garder `CONN_MAX_AGE = 60` sans pool. Gain : moins de latence par requête sur les recherches produits, zéro coût. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://docs.djangoproject.com/fr/5.1/ref/databases
- https://git.joshthomas.dev/mirrors/django/src/commit/a892459def0d15cd67c81800974b3b037f9531ed/docs/topics/db/connection-pooling.txt
- https://code.djangoproject.com/ticket/35685
- https://levelup.gitconnected.com/how-django-actually-manages-database-connections-ec0d266518cd


---

<!-- source : recherche-apis-github-addendum-249-2026-10-16-netbuis.md -->

# Addendum 249 — APIs GitHub gratuites 2026 (run planifié, 2026-10-16 04:57 UTC)

## Verdict
Pas de nouveauté structurante. Thème du run : notifications ciblées par topics FCM.
- FCM (déjà dans la stack) permet d'abonner un appareil à un topic côté Flutter : `FirebaseMessaging.instance.subscribeToTopic("ville_douala")`. Gratuit, sans quota payant.
- Côté Django, `firebase-admin` envoie à un topic avec `messaging.Message(topic="ville_douala", notification=...)` ; on peut aussi combiner avec une condition (`"'ville_douala' in topics && 'cat_telephones' in topics"`, 5 topics max par condition).
- Usages NETBUIS immédiats : topic par ville (promos locales), par catégorie suivie (tendances), et `marchands` pour les annonces aux commerçants pilotes. Pas besoin de stocker les tokens pour ces diffusions.
- Limites : livraison non garantie en temps réel pour les gros topics, et pas de ciblage individuel (garder l'envoi par token pour les paiements Campay et les messages du forum).

## Recommandation
Pour le pilote, créer un seul topic `marchands_pilote` pour prévenir les 30 commerçants (nouvelle version, maintenance) ; ajouter les topics ville et catégorie après le jalon 0. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://firebase.google.com/docs/cloud-messaging/flutter/topic-messaging
- https://firebase.google.cn/docs/cloud-messaging/flutter/topic-messaging?hl=ja
- https://rapidevelopers.com/firebase-tutorial/how-to-send-notification-to-a-topic-in-firebase
- https://rapidevelopers.com/firebase-tutorial/how-to-subscribe-user-to-fcm-topic


---

<!-- source : recherche-apis-github-addendum-250-2026-10-17-netbuis.md -->

# Addendum 250 — APIs GitHub gratuites 2026 (run planifié, 2026-10-17 11:57 UTC)

Les runs en retard (16/10 05:57 → 17/10 11:57, worker redémarré) sont regroupés dans cet addendum unique.

## Verdict
Pas de nouveauté structurante. Thème du run : sauvegardes PostgreSQL vers Cloudflare R2.
- R2 est compatible S3 et déjà prévu pour le stockage médias : un bucket séparé `netbuis-backups` suffit (10 Go gratuits, sortie gratuite).
- Templates open source « Postgres backups to R2 » (Railway) : conteneur cron qui fait `pg_dump` compressé puis envoi S3 ; aucun code à écrire.
- Alternative sans service en plus : tâche `django.tasks` ou cron système `pg_dump -Fc | gzip` + `boto3` vers l'endpoint R2.
- Règles : dump quotidien, rétention 14 jours via règle de cycle de vie R2, test de restauration (`pg_restore`) une fois par mois.
- PostGIS et pg_trgm sont inclus dans le dump `-Fc` ; restaurer sur une base avec les mêmes extensions.

## Recommandation
Activer un template « Postgres → R2 » dès que la base de prod existe, avec rétention 14 jours. Priorité toujours au jalon 0 (30 commerçants pilotes).

## Sources
- https://railway.com/deploy/postgres-to-r2-backup
- https://railway.com/deploy/backup-postgres-to-r2
- https://station.railway.com/templates/postgres-backups-to-r2-cloudflare-d376f9b9
- https://levelup.gitconnected.com/how-to-stream-your-postgres-backups-straight-to-s3-4d3b91154f74


---

<!-- source : recherche-apis-github-addendum-2026-10-06-netbuis.md -->

# Addendum : APIs et dépôts GitHub récents (2026-10-06) — NetBuis

Complète `recherche-apis-github-gratuites-netbuis.md` (v2) et `apis-github-gratuites-netbuis.md`. Recherche automatique planifiée. [S] = page lue ; [N] = non vérifié. Les décisions de ces deux documents ne changent pas (CamPay, Nexah, FCM, MapLibre/OpenFreeMap, forum Django, wa.me, appel natif).

## Nouveautés trouvées

| Brique | Ce que c'est | État (lu) | Verdict |
|---|---|---|---|
| **TranZak** (siège à Douala) | API REST de collecte mobile money en Afrique subsaharienne, profil API Evangelist mis à jour 23/09/2026 [S] | Fournisseur camerounais, conditions et frais non lus | **Candidat de repli de paiement** à comparer à Notch Pay/pawaPay derrière `PaymentProvider`. À vérifier : frais, payout, webhooks, agrément COBAC. |
| **xeption237** (EagleFox31, TypeScript) | Plateforme e-commerce camerounaise avec CamPay, mise à jour 23/09/2026, 0 étoile [S] | Très jeune | Lecture d'exemple pour l'intégration CamPay (webhook, statuts). Pas une dépendance. |
| **aangaraa_pay_flutter** (pub.dev) | Plugin Flutter MTN/Orange Cameroun, v0.0.1, publié 10/12/2024, 63 téléchargements, licence non vérifiée, éditeur non vérifié [S] | Abandonné de fait | **Écarté** : de plus, il met l'application en contact direct avec la passerelle, contraire à la règle « l'application ne parle qu'à Django ». |
| **AidaGateway** (Laravel, Wave/Orange/MTN) | Paquet PHP, 0 étoile [S] | Mauvaise pile (Django) | Écarté. |
| **cartflox** | Orchestrateur de 23 agrégateurs, 1 étoile, mis à jour 24/09/2026 [S] | Toujours immature | Reste écarté. |
| **OpenWA** (rmyndharis) | Passerelle WhatsApp auto-hébergée, non officielle [N] | API non officielle | **Écarté** : risque de bannissement du numéro. Rester sur `wa.me`. |
| `flutter_open_whatsapp` | Plugin Flutter pour ouvrir WhatsApp vers un numéro [N] | Petit | Inutile : `url_launcher` + `wa.me` suffisent. |
| **Termii / Africa's Talking / Twilio / Vonage / Infobip** | Alternatives SMS/OTP | Comparatif 2026 : aucun ne confirme explicitement la couverture du Cameroun, ni tarifs ni palier gratuit [S] | Garder Nexah en principal ; tester l'envoi réel au Cameroun (MTN + Orange) chez Africa's Talking avant de le retenir en repli. |
| Listes `public-api-lists`, `free-public-apis` | Annuaires d'API publiques | Génériques | Aucun service utile de plus pour le périmètre ; pas d'API « annuaire de commerçants africains » mûre trouvée. |

## Conclusion pour aller vite

1. Aucune nouvelle brique ne remplace une décision existante. Le chemin le plus rapide reste : Django + `pg_trgm`/PostGIS, `tel:` et `wa.me`, MapLibre/OpenFreeMap, CamPay en REST direct, FCM, forum natif.
2. Ajout au registre des replis de paiement : **TranZak** (à évaluer, tâche liée à 10 et 18.8).
3. Écarts confirmés : plugins Flutter de paiement (contournent Django), passerelles WhatsApp non officielles, SDK sous GPL/AGPL embarqués dans l'application.
4. Vérifications restantes : conditions TranZak ; couverture SMS Cameroun d'Africa's Talking et de Termii par essai réel ; licence du SDK CamPay.

## Sources
- [Topic mobile-money (GitHub)](https://github.com/topics/mobile-money?o=desc&s=updated)
- [aangaraa_pay_flutter (pub.dev)](https://pub.dev/packages/aangaraa_pay_flutter)
- [flutter_notchpay](https://github.com/BorisGautier/flutter_notchpay)
- [OpenWA](https://github.com/rmyndharis/OpenWA)
- [Comparatif OTP Afrique 2026 (Arkesel)](https://arkesel.com/otp-api-providers-comparison-2026/)
- [Termii (API Evangelist)](https://github.com/api-evangelist/termii)
- [public-api-lists](https://github.com/public-api-lists/public-api-lists)

