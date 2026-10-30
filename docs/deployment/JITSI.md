# Exploitation de Jitsi et des appels temps réel (T135)

**Rien n'est déployé.** Ce document dit quoi faire le jour du déploiement. Il complète `APPELS_ASGI.md` (serveur ASGI, PostgreSQL) et `docs/spec/APPELS_JITSI.md` (fonctionnement). Les tarifs cités sont ceux vus le 2026-10-22 : **à revérifier avant de décider**. Décision attendue de Jeff : D-28.

## 1. Choisir où héberger Jitsi (D-28)

| | JaaS (8x8, hébergé) | Jitsi auto-hébergé |
|---|---|---|
| Installation | aucune | un serveur (VPS) à installer et à tenir à jour |
| Coût | gratuit jusqu'à 25 utilisateurs actifs par mois, puis ~99 $/mois pour 300 (appelants compris) | prix du serveur, sans limite d'utilisateurs |
| Réseau | géré par 8x8 | TCP 443 **et UDP 10000** ouverts (indispensable pour l'audio) |
| Jeton | **RS256 avec clé privée et identifiant de clé (`kid`)** — pas encore codé | HS256 avec secret partagé — **codé** |
| Données | chez 8x8 | chez nous |

Railway ne semble pas exposer de port UDP : **Jitsi ne peut pas tourner sur Railway** (à confirmer). Il faut alors un VPS à part. Le backend et la base restent sur Railway.

Recommandation de départ : auto-hébergé sur un petit VPS dès que l'on dépasse l'essai (le code actuel le gère sans changement). Si Jeff préfère JaaS, il faut d'abord une petite tâche : signature RS256 + `kid` dans `apps/calls/services/jitsi.py` (HS256 ne fonctionne pas avec JaaS).

## 2. Variables d'environnement du backend (Railway)

| Variable | Rôle |
|---|---|
| `JITSI_DOMAIN` | nom de domaine du serveur Jitsi (sans `https://`) ; le tableau de bord et le mobile le reçoivent de l'API |
| `JITSI_APP_ID` | identifiant d'application (auto-hébergé : la valeur `app_id` de Prosody) |
| `JITSI_JWT_SECRET` | secret HS256, **au moins 32 caractères**, tiré au hasard (`openssl rand -hex 32`) ; jamais dans Git |

Secret absent ou trop court = le serveur refuse les appels (503 `jitsi_not_configured`) : c'est voulu.

## 3. Jitsi auto-hébergé : points à régler
1. Installation « Docker » officielle de Jitsi Meet sur le VPS, nom de domaine + certificat HTTPS.
2. Activer l'authentification par jeton (`ENABLE_AUTH=1`, `AUTH_TYPE=jwt`, `JWT_APP_ID` = `JITSI_APP_ID`, `JWT_APP_SECRET` = `JITSI_JWT_SECRET`) ; **désactiver les salles anonymes** (personne n'entre sans jeton).
3. Pare-feu : 443/TCP, 10000/UDP (et 4443/TCP en secours si UDP bloqué).
4. Pas d'enregistrement ni de diffusion (Jibri non installé) ; transcription absente.
5. Champs du jeton produits par le backend (`context.user.moderator`, `features`, `room`) : à confirmer sur le vrai serveur au premier essai (le format suit le module `token` de Prosody).
6. Pas de données à sauvegarder côté Jitsi (aucune salle durable) ; sauvegarder seulement la configuration (`.env`, `docker-compose`) hors du dépôt public.
7. Mises à jour de sécurité régulières ; surveiller l'espace disque et la charge CPU (l'audio seul est léger : un petit serveur suffit pour quelques dizaines d'appels simultanés).

## 4. Serveur ASGI, PostgreSQL, expiration
- Commande, délais proxy et connexion PostgreSQL **directe** (pas de pool en mode transaction) : voir `APPELS_ASGI.md`.
- Variable utile derrière Railway : `NUM_PROXIES=1`.
- **Expiration des sonneries** : `python manage.py expire_calls --loop 30` dans un **second service** Railway (même image, commande différente), ou un déclencheur planifié toutes les 30 s. Sans lui, une sonnerie oubliée se ferme quand même à la prochaine requête qui la touche, mais l'historique « manqué » peut tarder.
- Le flux SSE tient une connexion ouverte par agent connecté : surveiller le nombre de connexions PostgreSQL autorisé par l'offre.

## 5. Essai réel pour Jeff (quand Jitsi est installé)
1. Renseigner les trois variables, redémarrer le serveur.
2. Donner à deux comptes de l'équipe le rôle Validateur (ou Administrateur complet), se connecter au tableau de bord, cliquer **Disponible** (autoriser le son).
3. Sur le téléphone, ouvrir la fiche d'un commerce, appuyer sur **Appeler**, autoriser le micro.
4. Vérifier : la fenêtre sonne sur le tableau de bord en moins d'une seconde ; **Répondre** ; on s'entend dans les deux sens ; **Voir la fiche** montre les deux numéros ; **Raccrocher** ferme tout des deux côtés.
5. Refaire avec les deux membres connectés : un seul peut répondre. Refaire avec tous indisponibles : « Personne n'est disponible ».
6. Noter le délai entre l'appui sur Appeler et la sonnerie ; si > 1 s, vérifier d'abord le réseau du téléphone et le tampon du proxy (SSE).
7. Rapport : `docs/TESTS_JEFF.md` (section T133) et `docs/verifications/T134.md`.

## 6. Ce qui n'est pas vérifié
Audio réel, SDK Android sur téléphone, réseau mobile du Cameroun, comportement de Railway avec les flux SSE, taille de l'APK avec le SDK Jitsi.
