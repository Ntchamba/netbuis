# Essayer les appels Jitsi en local — ce qu'il faut et où le mettre

But : faire tourner un vrai serveur Jitsi sur votre ordinateur, à côté du `docker compose` local de NetBuis (`TEST_LOCAL.md`), pour vérifier qu'un appel passe : sonnerie sur le tableau de bord → « Répondre » → l'agent et l'appelant se retrouvent dans la même salle. **Non essayé depuis la session de travail** (pas assez de place ni de réseau Docker) : si une étape échoue, copiez-moi le message.

## Ce qu'il faut (la liste)
| Élément | Pourquoi | Comment |
|---|---|---|
| Docker + le `docker compose` local NetBuis lancé | serveur, base, tableau de bord | `TEST_LOCAL.md` |
| **mkcert** | Jitsi exige HTTPS ; mkcert crée un certificat auquel votre navigateur fait confiance | `sudo apt install mkcert libnss3-tools` |
| Le projet officiel **docker-jitsi-meet** | le serveur Jitsi lui-même (4 conteneurs) | téléchargé par le script |
| Le nom **`meet.localtest.me`** | Jitsi refuse les adresses IP et `localhost` ; ce nom public renvoie toujours vers votre propre ordinateur | rien à faire |
| Ports libres **8443** (Jitsi), **8088**, **10000/UDP** (audio) | | changer `HTTPS_PORT` / `HTTP_PORT` dans le `.env` de Jitsi si occupés |
| ~2 Go de disque, ~2 Go de RAM libres | images Jitsi | |

## Où chaque réglage est écrit (le script le fait pour vous)
| Fichier | Contenu |
|---|---|
| `~/jitsi-local/.env` | réglages de Jitsi : adresse publique `https://meet.localtest.me:8443`, domaine XMPP `meet.localtest.me`, **authentification par jeton** (`ENABLE_AUTH=1`, `AUTH_TYPE=jwt`, `JWT_APP_ID`, `JWT_APP_SECRET`, `JWT_ACCEPTED_ISSUERS`, `JWT_ACCEPTED_AUDIENCES=jitsi`), audio sur 127.0.0.1, mots de passe internes (`gen-passwords.sh`) |
| `~/.jitsi-meet-cfg-netbuis/web/keys/cert.crt` et `cert.key` | le certificat HTTPS (mkcert) |
| **`netbuis/.env`** (racine du dépôt, à côté de `docker-compose.yml` ; déjà ignoré par Git) | les 3 variables lues par le serveur NetBuis : `JITSI_DOMAIN=meet.localtest.me:8443`, `JITSI_APP_ID`, `JITSI_JWT_SECRET` (le **même** secret que `JWT_APP_SECRET` de Jitsi) |

Les secrets sont tirés au hasard et ne s'affichent jamais. Ne copiez pas ces fichiers dans un message.

## Étapes
Depuis le dossier `netbuis`, avec le `docker compose` local déjà lancé :
```
sudo apt install mkcert libnss3-tools
bash deploy/local-jitsi/install.sh
```
Puis **fermez et rouvrez le navigateur** (pour qu'il prenne le certificat) et ouvrez https://meet.localtest.me:8443 : la page Jitsi doit s'afficher sans alerte de sécurité.

## Faire un appel d'essai (sans téléphone)
1. Tableau de bord http://localhost:8080 : connectez-vous (compte créé par `createsuperuser`), cliquez sur **Disponible**, autorisez le son.
2. Dans un terminal : `bash deploy/local-jitsi/appel_test.sh` — il joue un appelant (numéro fictif, code lu dans les journaux) et affiche une adresse `https://meet.localtest.me:8443/…?jwt=…`.
3. La sonnerie apparaît sur le tableau de bord. Ouvrez l'adresse affichée dans une **autre fenêtre** (navigation privée) : vous êtes l'appelant. Cliquez sur **Répondre** dans le tableau de bord : les deux fenêtres doivent être dans la même salle (micros et haut-parleurs du même ordinateur : baissez le son pour éviter l'écho).

## Si ça ne marche pas
- La salle refuse d'entrer (« authentification ») : `cd ~/jitsi-local && docker compose logs prosody | tail -50` et envoyez-moi les lignes qui parlent de « token ».
- Pas d'audio : `docker compose logs jvb | tail -30` ; vérifiez que le port UDP 10000 est libre.
- Alerte de certificat : relancez `mkcert -install`, puis le navigateur.
- « jitsi_not_configured » : relancez `bash deploy/local-jitsi/install.sh` (il réécrit `netbuis/.env` et redémarre le serveur).

## Ce que ce test local ne couvre pas
L'appel **depuis l'application Android** : sur un téléphone ou un émulateur, `meet.localtest.me` renvoie vers le téléphone lui-même, pas vers votre ordinateur, et le téléphone ne fait pas confiance au certificat mkcert. Pour ce test-là, utilisez le Jitsi du VPS (`VPS_CONTABO.md` §5), qui a un vrai certificat.
