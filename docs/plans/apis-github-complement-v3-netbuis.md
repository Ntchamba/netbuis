# APIs et dépôts GitHub gratuits — complément v3 (2026-10-06)

Complète `recherche-apis-github-gratuites-netbuis.md` (v2, bien plus complet) et `apis-github-gratuites-netbuis.md`. Ici : seulement ce qui était manquant ou à confirmer. [S] = page lue le 2026-10-06 ; [N] = non confirmé. Cadrage v2 conservé : application complète, l'appli ne parle qu'à Django, paiement/PIN jamais dans l'appli.

## 1. Briques confirmées ou ajoutées

| Besoin | Brique | Licence / coût | Fait vérifié | Décision |
|---|---|---|---|---|
| Carte (bloc 8) | **maplibre/flutter-maplibre-gl** | Libre (voir LICENSE du dépôt) ; sans clé ni compte | 367 étoiles, 566 commits, **régions hors-ligne Android/iOS**, PMTiles sur toutes plateformes, Android 5.0+, Flutter 3.29+ [S] | Retenu. Lève le point « cache de tuiles hors ligne » de la v2 : régions hors-ligne natives + PMTiles auto-hébergé (un seul fichier Cameroun, sans SLA tiers). |
| Numéros +237 serveur (3.1) | **django-phonenumber-field 8.5.0** (+ `phonenumbers`) | MIT | Publié 23 juillet 2026 ; Django 4.2/5.2/6.0 ; Python ≥ 3.10 ; 5 mainteneurs [S] | Retenu : normalisation E.164 + validation Cameroun. |
| Recherche vocale (accessibilité, analphabétisme) | **speech_to_text 7.5.0** | BSD-3 | Publié 14 sept. 2026 ; Android/iOS ; choix de langue (`localeId`) ; orienté commandes et phrases courtes ; **peut utiliser un service distant** [S] | Retenu pour la barre de recherche vocale. À tester sur téléphones bas de gamme et en français camerounais ; pas de garantie hors-ligne. |
| Lecture vocale des résultats | **flutter_tts 4.2.5** | MIT | 1,6 k likes, 443 k téléchargements, Android SDK 21+ [S] | Retenu pour lire prix/nom du commerçant. Qualité des voix dépend du moteur installé sur le téléphone. |
| Stockage images (photos produits) | **Cloudflare R2** via `django-storages` (API S3) | Gratuit : 10 Go, 1 M opérations d'écriture, 10 M de lecture par mois, **sortie de données gratuite**, sans expiration [S] | Compatible S3 déjà prévu au plan | Retenu comme option S3 : au-delà du palier, facturation au Go. Prévoir compression côté Flutter avant envoi. |
| Plantages / erreurs | **Firebase Crashlytics** (`firebase_crashlytics`) | Gratuit [N : relire conditions] | Même SDK que FCM déjà retenu | Retenu en premier choix. Auto-hébergé en repli : **GlitchTip** (MIT, 512 Mo de RAM, événements illimités en auto-hébergé) [S]. Côté Django : SDK Sentry compatible GlitchTip [N]. |
| Modération du forum (bloc 11) | **localmod** (self-hosted, MIT, 138 étoiles) | Gratuit | Toxicité, spam, PII, NSFW image+texte ; ~3,5 Go de modèles ; **documentation en anglais, français non confirmé** [S] | **Non retenu en première version** : modèles lourds et français non garanti. Garder signalement + masquage manuels du plan ; réévaluer après test sur un corpus français/camfranglais. |

## 2. Dépôts examinés et écartés

- **janekamso/mobile-money** (MIT) : pont MTN/Orange/Airtel ↔ blockchain Stellar, Node/GraphQL/Kubernetes, 0 étoile (fork), plus de 2 000 commits [S]. Hors sujet pour NetBuis (remises transfrontalières) et trop lourd. À ne pas utiliser.
- **zignpay** (MIT) : déjà jugé immature en v1 ; inchangé.
- Aucun nouveau SDK GitHub mûr pour Orange Money / MTN MoMo Cameroun n'est apparu dans les recherches du jour : la décision **CamPay via REST direct** (`decision-campay-netbuis.md`) reste la plus sûre.

## 3. Ordre d'intégration pour avancer vite

1. `django-phonenumber-field` + OTP (bloc 3) : une journée, aucune dépendance externe.
2. `maplibre_gl` + fichier PMTiles du Cameroun : valider la taille du fichier et l'espace disque téléphone avant de promettre le hors-ligne.
3. R2 + `django-storages` pour les photos ; Crashlytics dès la première version interne.
4. `speech_to_text` + `flutter_tts` en bloc accessibilité : test terrain avec de vrais utilisateurs avant d'annoncer la fonction.
5. Modération automatique : après lancement, selon le volume de signalements.

## 4. Reste à vérifier
Licence exacte du fichier LICENSE de flutter-maplibre-gl (page non détaillée) ; reconnaissance vocale en français camerounais et en mode hors-ligne ; taille d'un PMTiles Cameroun ; conditions gratuites actuelles de Crashlytics ; qualité du français de localmod.

## Sources
- [maplibre/flutter-maplibre-gl](https://github.com/maplibre/flutter-maplibre-gl)
- [speech_to_text (pub.dev)](https://pub.dev/packages/speech_to_text)
- [flutter_tts (pub.dev)](https://pub.dev/packages/flutter_tts)
- [django-phonenumber-field (PyPI)](https://pypi.org/project/django-phonenumber-field/)
- [localmod](https://github.com/KOKOSde/localmod)
- [janekamso/mobile-money](https://github.com/janekamso/mobile-money)
- [Alternatives à Sentry 2026 (GlitchTip)](https://temps.sh/blog/8-best-sentry-alternatives-error-tracking-2026)
- [Cloudflare R2 free tier 2026](https://nubbo.app/blog/cloudflare-r2-free-tier/)
- [Stocker les médias Django sur R2](https://testdriven.io/blog/django-cloudflare-r2/)
- [firebase_crashlytics](https://pub.dev/packages/firebase_crashlytics)
