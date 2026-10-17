# Briques open source et APIs gratuites pour l'application mobile NetBuis (v2, 2026-10-06)

Correction de cadrage : NetBuis est une application mobile complète (Android d'abord, Play Store, version 1.0 puis 1.1), pas un MVP. La version précédente de ce document parlait de « plan pour aller vite » : retirée. Ici, chaque brique est jugée sur sa fiabilité en production, sa licence et sa compatibilité avec `plan-realisation-netbuis.md` (Django + Flutter, PostgreSQL, Celery, Redis, S3, FCM, CamPay, paiement et PIN jamais dans l'application). Le gain de temps vient de bibliothèques éprouvées, pas de raccourcis de périmètre. [S] = lu ; [N] = non confirmé. Le document `apis-github-gratuites-netbuis.md` couvre le même sujet avec un titre « MVP » : à lire avec la même correction.

## 1. Décision par fonctionnalité du plan

| Bloc du plan | Brique | Licence / coût | Verdict production |
|---|---|---|---|
| 7 Recherche | **PostgreSQL `pg_trgm` + `unaccent` + index GIN** (déjà au plan) | Inclus, gratuit | Retenu. **Meilisearch** (MIT, [S]) en évolution seulement si le test de charge 7.7 (p95 < 300 ms, 10 000 produits) échoue ou si le catalogue dépasse la capacité de la base. Typesense écarté : GPLv3 et index entièrement en RAM. |
| 8 Carte | **MapLibre** (`maplibre_gl` côté Flutter [N]) + fonds **OpenFreeMap** [S par doc voisine] | MIT ; sans clé | À valider : instance publique sans SLA. Prévoir cache de tuiles ou auto-hébergement avant le lancement. L'itinéraire reste `geo:` / `url_launcher` (aucun coût). |
| 8.3 Zones | Extrait **Geofabrik** du Cameroun (OSM) importé par commande, validé à la main (déjà au plan) | ODbL | Retenu. Nominatim public **interdit l'autocomplétion**, limite à 1 requête/s, impose cache et User-Agent, interdit l'extraction massive de points d'intérêt [S] : ne pas s'en servir en production. |
| 3 OTP / SMS | **Nexah** puis Twilio Verify en repli (déjà au plan), derrière `SmsProvider` | Payant à l'unité | Retenu. **httpSMS** (téléphone Android comme passerelle, AGPL-3.0, 3,6 k étoiles [S]) écarté pour la production : dépend d'un téléphone, risque de blocage par l'opérateur. Utile seulement en développement. |
| 15 Push | **Firebase FCM** (`firebase_messaging`, `firebase-admin`) | Gratuit, volume illimité, sans analytique [S] | Retenu. OneSignal, Courier, Pusher Beams : inutiles tant que FCM suffit. |
| 10 Paiement | **CamPay** via la couche `PaymentProvider`. Appel REST direct recommandé ; SDK Python `campay` (GPL-3.0, 1 étoile [S]) à n'utiliser qu'après lecture de la licence | Frais ≈ 2 % collecte / 1 % retrait | Retenu. Repli : Notch Pay ou pawaPay, derrière la même interface. |
| 10 (attention) | `flutter_notchpay` (MIT, MTN/Orange auto-détectés, sandbox [S]) | Gratuit | **À ne pas embarquer dans l'application** : il fait parler le mobile à la passerelle, alors que la règle du projet est « l'application ne parle qu'à Django ». Utile seulement pour s'inspirer de l'écran d'attente. |
| 10 Orchestration | Cartflox (23 agrégateurs, AGPL-3.0, 1 étoile, 1 commit [S]) | Gratuit | Écarté : trop immature, ne gère pas CamPay. |
| 11 Forum | **Forum natif Django** (déjà au plan : Post, Comment, plafonds, masquage, signalement) | Gratuit | Retenu : un seul compte, une seule modération, plafonds liés à l'abonnement. NodeBB (GPL-3, 15,2 k étoiles, API REST [S]) ou Flarum/Discourse imposeraient une 2e pile (Node + MongoDB/Redis) et une synchronisation des comptes. |
| 9 Appel | `MethodChannel` Kotlin + `TelecomManager` (déjà au plan) ; `tel:` en repli | Gratuit | Retenu. |
| WhatsApp (partage, support) | Lien **`wa.me/<numéro>?text=`** via `url_launcher` / `share_plus` | Gratuit [S] | Retenu pour le contact et le partage. L'**API Cloud Meta** n'est à ajouter qu'avec un besoin d'envoi automatique chiffré : facturation par message depuis juillet 2025, gratuit seulement dans la fenêtre de service de 24 h [S]. Éviter les API non officielles (Baileys, Evolution) : bannissement du numéro. |
| 3.1 Saisie du numéro | `libphonenumber`/`phone_numbers_parser` côté Flutter [N] ; validation serveur `+237` | Libre | À choisir à l'implémentation. |
| Backend/Auth | **Django + simplejwt** (déjà au plan) | Gratuit | Retenu. Supabase (palier gratuit : 500 Mo, 50 000 utilisateurs actifs, pause après 7 jours sans requête [S]) écarté : pas de pause tolérable en production et double backend. |
| 1.13 Contrat d'API | `drf-spectacular` → client Dart généré à partir d'`openapi.yaml` | MIT/BSD [N] | Retenu : réduit les erreurs entre Django et Flutter. |

## 2. Ce que ces recherches changent au plan

Aucun bloc ne disparaît ni ne rétrécit. Trois points de vérification s'ajoutent :

1. Bloc 8 : décider avant le développement d'une source de tuiles avec SLA (OpenFreeMap public, ou auto-hébergé, ou fournisseur payant à faible coût) ; prévoir le cache de tuiles hors ligne.
2. Bloc 10 : relire la licence GPL-3.0 du SDK CamPay avec le juriste (tâche 18.8) ou appeler l'API REST directement.
3. Bloc 7 : définir dès 7.7 le seuil qui déclencherait Meilisearch, pour ne pas migrer à la panique.

## 3. Licences à faire valider (tâche 18.8)

GPL-3.0 : SDK CamPay, NodeBB, Typesense. AGPL-3.0 : httpSMS, Cartflox. Les mêmes contraintes ne s'appliquent pas à un service auto-hébergé non modifié et non redistribué, mais tout code embarqué dans l'application distribuée sur Google Play doit être MIT/BSD/Apache. Meilisearch et `flutter_notchpay` sont en MIT.

## 4. Reste à vérifier

Quota gratuit de Firebase Phone Auth (non utilisé si Nexah est retenu), règles Flarum/Discourse (écartés), disponibilité et conditions d'OpenFreeMap en production, paquets Flutter de numéros de téléphone et de carte (versions et maintenance à relire sur pub.dev).

## Sources
- [Meilisearch vs Typesense 2026](https://apiscout.dev/guides/meilisearch-vs-typesense-api-2026)
- [Services push gratuits 2026](https://pushpilot.ai/blog/free-push-notification-services-compared)
- [WhatsApp API : gratuit ou non](https://www.unipile.com/is-the-whatsapp-api-free/)
- [Politique d'usage Nominatim](https://operations.osmfoundation.org/policies/nominatim/)
- [CamPay Python SDK](https://github.com/CamPay/campay-python-sdk)
- [flutter_notchpay](https://github.com/BorisGautier/flutter_notchpay)
- [Cartflox](https://github.com/uvan00/cartflox)
- [httpSMS](https://themenonlab.blog/blog/httpsms-android-sms-gateway)
- [NodeBB](https://github.com/NodeBB/NodeBB)
- [Limites gratuites Supabase 2026](https://www.itpathsolutions.com/supabase-free-tier-limits)
