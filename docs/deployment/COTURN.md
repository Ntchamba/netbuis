# coturn — serveur de relais pour les appels WebRTC (D-31)

coturn est le **serveur TURN/STUN** des appels WebRTC directs (`docs/spec/APPELS_WEBRTC.md`). Dans le cas courant, le son va **directement** de l'appelant à l'agent ; coturn ne sert que quand le réseau d'un des deux (4G d'un opérateur, pare-feu) bloque la connexion directe : il relaie alors le son, **déjà chiffré** de bout en bout (DTLS-SRTP) : coturn ne peut pas l'écouter.

## Sur le VPS (`deploy/vps/`)
- Le service `coturn` est dans `deploy/vps/docker-compose.yml` (image officielle `coturn/coturn`, réseau « host »). `install.sh` ouvre les ports : **3478 UDP et TCP** et la plage UDP **49152-49999** (relais), et tire au hasard `TURN_SECRET` dans `deploy/vps/.env`.
- Ouvrez aussi ces ports dans le panneau de l'hébergeur (Contabo → Firewall) : 3478/udp, 3478/tcp, 49152-49999/udp.
- Le serveur NetBuis reçoit `STUN_URLS`, `TURN_URLS` et `TURN_SECRET` et fabrique, pour **chaque appel**, des identifiants **temporaires** (10 minutes) : `nom = « <expiration>:<session> »`, mot de passe = HMAC-SHA1 du nom avec `TURN_SECRET`. Personne ne peut utiliser le relais sans passer par NetBuis.
- coturn **refuse les adresses privées** comme destinations (10.x, 172.16-31.x, 192.168.x, 127.x…) : il ne peut pas servir de rebond vers le réseau interne du VPS.
- Choisir le moteur : `CALL_ENGINE=webrtc` dans `deploy/vps/.env`, puis `docker compose up -d api`. Par défaut `jitsi`.

## En local (`docker-compose.yml`, Linux)
Le service `coturn` du `docker-compose.yml` local utilise le réseau « host » (Linux seulement) avec un secret de **développement** jetable. `TURN_HOST` (défaut `localhost`) est l'adresse que les clients utilisent pour joindre coturn : pour un téléphone sur le même Wi-Fi, mettez l'adresse de votre ordinateur : `TURN_HOST=192.168.1.23 docker compose up -d api`.

## Vérifier que coturn répond (sans NetBuis)
Avec un secret `S` et un nom `EXPIRATION:test` (EXPIRATION = date Unix dans le futur), le mot de passe est `base64(HMAC-SHA1(S, nom))`, puis :
```
docker run --rm --network host --entrypoint turnutils_uclient coturn/coturn:latest -u "NOM" -w "MOTDEPASSE" -p 3478 -y -n 2 127.0.0.1
```
Un mot de passe faux doit donner « Cannot complete Allocation ». (Vérifié ainsi avec l'image officielle : bons identifiants acceptés, mauvais refusés.)

## À savoir
- Le relais consomme de la bande passante du VPS (audio seul : faible). La plage 49152-49999 limite à environ 400 relais simultanés.
- Pas de TURN chiffré (TLS, port 5349/443) pour l'instant : utile si un réseau bloque tout sauf le port 443. À ajouter si les essais sur réseau mobile le demandent.
- Le fichier `/etc`-équivalent n'est pas utilisé : tous les réglages sont dans la commande du service (donc dans Git, sans secret).
