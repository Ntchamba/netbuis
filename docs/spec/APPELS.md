# Mécanisme d'appel (décision v2.1)

- **Pas de Twilio ni de VoIP.** C'est un appel téléphonique classique, facturé par l'opérateur de l'utilisateur.
- **Android** : « Appeler » → feuille « Avec quelle ligne voulez-vous appeler ? » avec **Orange** et **MTN** (seulement ces deux) + Annuler. Le choix de la ligne **est** la confirmation et lance l'appel directement (`TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE`). Module Kotlin via `MethodChannel` (aucun plugin Flutter éprouvé pour viser une SIM). Permissions : `CALL_PHONE` (une fois) et `READ_PHONE_STATE` (lister les SIM).
- Cas : une seule SIM → feuille sautée ; ligne choisie absente → message simple + autre ligne ; SIM renommée/eSIM → repli qui affiche les noms donnés par le système ; permission refusée → `ACTION_DIAL` (numéro visible).
- **iOS** : `tel://` avec confirmation du système (numéro visible), choix de ligne impossible. Accepté provisoirement.
- **Serveur** : `POST /api/calls/initiate/` vérifie connexion, profil actif non bloqué, quota (si crédits activés), limite par minute/jour ; crée le `CallLog` (plateforme, opérateur) ; renvoie le numéro **pour cet appel seulement**.
- **Ce que « jamais affiché » ne garantit pas** : l'écran d'appel et le journal du téléphone montrent le numéro ; le numéro arrive dans le téléphone pour être composé. À dire honnêtement (D-07).
- **WhatsApp** : lien `https://wa.me/237…` construit par le serveur avec les mêmes contrôles ; signalement « pas de WhatsApp ».
- NetBuis ne sait pas si le commerçant a décroché ni la durée (pas de `READ_CALL_LOG`, permission restreinte par Google Play).
- Mobile Money : le code PIN n'est jamais saisi dans l'application.
