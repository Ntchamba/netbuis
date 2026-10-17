# APIs et briques GitHub gratuites pour aller vite — NetBuis (2026-10-06)

Recherche web automatique. [S] = page lue ; [N] = non vérifié. Complète `decision-campay-netbuis.md` et `decision-finale-appels.md` (appel = dialer natif, paiement = CamPay ; Twilio abandonné).

## Tableau de synthèse (par fonctionnalité)

| Besoin | Brique recommandée | Licence / coût | Vitesse de mise en route | Réserves |
|---|---|---|---|---|
| Paiement MTN + Orange (collecte et payout) | **CamPay + SDK Python `campay`** (`pip install campay`) | SDK GPL-3.0 ; frais CamPay ≈2 % collecte / 1 % retrait | Très rapide (démo `demo.campay.net`) | SDK mis à jour en avril 2024 (v1.0.7), 1 étoile : le wrapper est mince, on peut appeler l'API REST directement. GPL-3.0 : lire avant de l'embarquer. [S] |
| Alternative paiement (repli) | **zignpay** (Python, MIT) : API unifiée MTN MoMo + Orange Money, collections | MIT, gratuit | Rapide | 0 étoile, 8 commits, doc incomplète, pas de payout/webhook décrits : à utiliser comme exemple de code, pas comme dépendance critique. [S] |
| Recherche produit (barre de recherche, tolérance aux fautes, géo-tri) | **Meilisearch** (auto-hébergé) | MIT, gratuit (cloud payant dès 30 $/mois) | Rapide (config minimale) | Typesense (GPLv3) garde tout l'index en RAM ; Meilisearch moins gourmand. Au démarrage, PostgreSQL `pg_trgm` + PostGIS peut suffire sans service en plus. [S] |
| Carte | **OpenFreeMap + MapLibre** | MIT ; sans clé API, sans limite de vues | Très rapide | Dépend d'une instance publique sans SLA ; auto-hébergement possible. [S] |
| Géocodage / recherche d'adresse | **Photon (komoot)** ou Nominatim | Apache 2.0 | Rapide via l'instance publique | Instance publique : usage « raisonnable » seulement, blocage possible en cas d'abus ; auto-héberger demande ≈95 Go disque et 64 Go RAM (monde entier) — importer seulement le Cameroun. [S] |
| Notifications push | **Firebase Cloud Messaging** (gratuit) ; Novu (open source) si orchestration multi-canal | FCM gratuit [N : relire les conditions] | Très rapide | Novu est surtout utile plus tard. |
| Forum | **Flarum** (PHP, léger) ou **Discourse** (plus lourd) en service séparé, OU forum natif Django (modèles Post/Comment) | Open source, auto-hébergé | Flarum : rapide ; natif : le plus simple pour l'app mobile | Pour une app mobile, un forum natif minimal (fil, réponses, signalement) évite de gérer deux comptes. Les moteurs externes sont à préférer seulement si on veut la modération toute faite. |
| WhatsApp | **Lien `wa.me/<numéro>?text=…`** (gratuit, sans API) ; API Cloud officielle Meta si besoin de messages automatiques | wa.me : 0 ; Cloud API : paiement par message, réponses dans la fenêtre de 24 h gratuites | wa.me : immédiat | Évite les API non officielles (Baileys, Evolution API, OpenWA) : risque de bannissement du numéro, pas de support. [S] |
| Appel | **Dialer natif** (`tel:`) — décision finale | 0 | Immédiat | Pas de suivi d'appel ni de masquage. Rien à ajouter. |
| Base de données / auth rapide (option) | **Supabase** (free tier) ou Django + PostgreSQL | Free tier limité [N : chiffres 2026 à relire sur supabase.com] | Rapide | Le projet a déjà un backend Django : ne changer que si le temps manque. |

## Ordre recommandé pour aller vite (MVP)

1. Django + PostgreSQL (PostGIS) + recherche `pg_trgm` : liste de commerçants par produit et distance.
2. Appel par `tel:` et WhatsApp par `wa.me` : deux liens, aucune intégration.
3. Carte OpenFreeMap/MapLibre + géocodage Photon public (limiter les requêtes, mettre en cache).
4. Paiement CamPay : sandbox, puis un pilote réel MTN + Orange ; couche `PaymentProvider` abstraite pour pouvoir basculer vers pawaPay/Notch Pay.
5. Push FCM, forum natif minimal.
6. Meilisearch seulement quand le volume ou la tolérance aux fautes l'exigent.

## Points de vigilance
- Licences : GPL-3.0 (SDK CamPay, Typesense) peut contraindre la distribution ; préférer l'appel REST direct ou une lib MIT/Apache.
- Services publics gratuits (Photon, OpenFreeMap) : pas de garantie de disponibilité ; prévoir cache et plan d'auto-hébergement.
- Tarifs WhatsApp : des rumeurs de changement en octobre 2026 (service messages possiblement facturés) non confirmées par Meta. [N]
- Aucun dépôt GitHub camerounais mature trouvé pour le mobile money en dehors de CamPay lui-même ; zignpay et camwallet sont des projets très jeunes. [S]

## Sources
- [zignpay (GitHub)](https://github.com/kevelino/zignpay)
- [CamPay Python SDK (GitHub)](https://github.com/CamPay/campay-python-sdk)
- [camwallet (GitHub)](https://github.com/ndjoumessi/camwallet)
- [komoot/photon (GitHub)](https://github.com/komoot/photon)
- [Nominatim (GitHub)](https://github.com/osm-search/Nominatim)
- [OpenFreeMap (GitHub)](https://github.com/hyperknot/openfreemap)
- [Meilisearch vs Typesense 2026](https://apiscout.dev/guides/meilisearch-vs-typesense-api-2026)
- [Typesense (GitHub)](https://github.com/typesense/typesense)
- [Is the WhatsApp API free? 2026 (Unipile)](https://www.unipile.com/is-the-whatsapp-api-free/)
- [Evolution API (GitHub)](https://github.com/evolution-foundation/evolution-api)
- [Discourse vs Flarum](https://dev.to/selfhostingsh/discourse-vs-flarum-which-forum-to-self-host-470g)
- [Novu](https://github.com/javascript-space/novu)
