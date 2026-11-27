# Appels WebRTC directs avec coturn (D-31)

Complète `APPELS_JITSI.md` (qui reste valable pour le moteur `jitsi`). Seule la **partie audio** change : les sessions d'appel, les droits, la sonnerie, l'historique, la fiche et les numéros (D-30) restent identiques.

## Principe
Appel à deux : l'**appelant** (application) et l'**agent** (tableau de bord). Le son passe directement de l'un à l'autre (WebRTC, chiffré DTLS-SRTP, codec Opus) ; si le réseau l'empêche, il passe par **coturn** (relais TURN).

## Déroulement (objectif : l'audio part dès que l'agent répond)
1. L'appelant demande l'appel (`POST /api/calls/sessions/`). La réponse contient `engine: "webrtc"` et `webrtc.ice_servers` (adresses STUN/TURN + identifiants TURN **temporaires**), au lieu de `jitsi`.
2. Pendant que ça sonne, l'appelant ouvre le micro, crée son **offre** et collecte ses adresses (ICE « trickle »). Il les envoie au serveur par `POST /api/calls/sessions/<id>/signal/` (`offer`, `candidate`). Le serveur les **garde** (sonnerie : l'agent n'est pas encore là).
3. L'agent répond (`accept`). La réponse contient les mêmes `ice_servers` et les signaux déjà reçus (`signals`). L'agent crée sa **réponse** (`answer`) et ses `candidate` ; il les envoie par `POST /api/admin/calls/sessions/<id>/signal/`.
4. Les signaux suivants arrivent à l'autre côté par les flux SSE existants (nouvel événement `signal`). La connexion s'établit ; fin par `end`/`cancel` existants ou signal `bye`.

## Signalisation
- Corps : `{ "type": "offer"|"answer"|"candidate"|"bye", "data": {…} }` ; `data` ≤ 16 Ko ; au plus 200 signaux par session.
- Seuls l'appelant de la session et l'agent qui a répondu peuvent signaler ; un signal n'est relayé qu'à l'AUTRE partie ; l'agent ne peut envoyer qu'après `accept`, et seulement tant que la session est `ringing` (appelant) ou `answered`.
- Rien du contenu n'est journalisé ; les signaux sont supprimés à la fin de la session (ou après 1 h).
- Latence : relais de bout en bout < 250 ms p95 (même objectif que D-26).

## Identifiants TURN temporaires (mode `use-auth-secret` de coturn)
`username = "<expiration_unix>:<session_id>"` ; `credential = base64(HMAC-SHA1(TURN_SECRET, username))` ; durée `TURN_TTL` (défaut 600 s). Réglages : `TURN_URLS` (liste), `TURN_SECRET` (≥ 32 car., secret absent = pas de TURN, STUN seul + avertissement), `STUN_URLS`. Le secret n'est jamais renvoyé ni journalisé.

## Jitsi n'est pas retiré (décision de Jeff, 2026-11-22)
Le WebRTC s'ajoute à côté de Jitsi, dans l'application et dans le tableau de bord ; les deux moteurs coexistent tant que les essais côte à côte (téléphone, Wi-Fi et réseau mobile) ne sont pas faits. Le retrait de Jitsi est une tâche séparée (T156), longue, à spécifier et à décider ensuite.

## Choix du moteur
`CALL_ENGINE` = `webrtc` (défaut après mesures) ou `jitsi`. Les clients lisent `engine` dans la réponse : un client qui ne connaît pas `webrtc` peut tomber en `jitsi` si le serveur l'accepte (période de transition).

## Sécurité
- Média chiffré de bout en bout entre les deux pairs (sauf relais TURN, qui ne voit que du chiffré).
- Identifiants TURN liés à une session et expirants ; coturn refuse les adresses privées (`no-multicast-peers`, `denied-peer-ip` sur les plages privées) pour éviter l'usage comme rebond réseau.
- Les numéros de téléphone ne passent jamais dans la signalisation ; la fiche de contexte (D-30) est inchangée.

## Hors périmètre (étapes ultérieures)
Conférence à plus de deux, enregistrement, transfert d'appel, appel vers un téléphone ordinaire (SIP trunk : FreeSWITCH/Asterisk/fournisseur, décision à part).

## Tâches
T150 coturn (déploiement) · T151 backend · T152 tableau de bord · T153 essai de bout en bout dans un navigateur réel (médias simulés) + mesures · T154 mobile (`flutter_webrtc`) · T155 documentation et comparaison avec Jitsi.
