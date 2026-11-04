# NetBuis sur un VPS Contabo — guide pas à pas

Ce guide installe **tout sur un seul VPS** : serveur, base de données, tableau de bord, application web (PWA), HTTPS automatique et, en option, la visioconférence Jitsi (ce qui règle la décision D-28 : un VPS ouvre le port UDP que Railway n'offre pas). Les scripts sont dans `deploy/vps/` ; tout est dans Docker.

**Honnêteté sur l'état des vérifications :** les scripts n'ont pas pu être exécutés sur un vrai VPS depuis la session de travail. Vérifiés ici : syntaxe des scripts, configuration `docker compose`, fichier Caddy (`caddy validate`), construction et lancement des images du serveur et du tableau de bord. **Non vérifiés** : l'installation complète sur un serveur réel, Let's Encrypt, Jitsi, la construction Flutter dans Docker. Si une étape échoue, copiez-moi le message (sans secret) et je corrige.

## ⚠ Bloquant : l'envoi des SMS
Aucun fournisseur de SMS réel n'est encore codé (décision D-02). En production, le fournisseur « console » est refusé et « real » n'est pas implémenté : **les clients (application mobile) ne pourront pas recevoir de code ni se connecter.** Le **tableau de bord** fonctionne (connexion par mot de passe). Il faut choisir un fournisseur (qui couvre le Cameroun) et me donner sa documentation d'API ; je code l'envoi, la clé va dans `SMS_API_KEY` sur le VPS.

## 0. Ce qu'il vous faut
- Le VPS Contabo : Ubuntu 22.04 ou 24.04, au moins **4 vCPU / 8 Go** de RAM (la construction de l'application web est gourmande ; le script ajoute un fichier d'échange si besoin) et **40 Go** de disque.
- **Pas besoin de nom de domaine.** Le script utilise alors le service gratuit **sslip.io** : un nom comme `api.203-0-113-5.sslip.io` pointe tout seul vers l'IP `203.0.113.5`, et Caddy obtient un vrai certificat HTTPS pour ce nom. Les 4 adresses (`api.`, `admin.`, `app.`, `meet.`) fonctionnent sans rien configurer. Inconvénient : l'adresse n'est pas jolie et dépend de sslip.io ; un vrai domaine pourra remplacer ce nom plus tard (relancer l'installation avec le nouveau domaine).
- *(Si vous achetez un domaine plus tard : créez 4 enregistrements DNS de type **A** — `api`, `admin`, `app`, `meet` — vers l'IP du VPS.)*
- Dans le **panneau Contabo → Firewall** (s'il est activé) : autoriser TCP 22, 80, 443 et UDP 443 et **UDP 10000**.
- Sur votre ordinateur : un terminal (Windows : PowerShell avec `ssh`).

## 1. Se connecter et sécuriser l'accès
```
ssh root@ADRESSE_IP_DU_VPS
```
Mieux : créer une clé SSH sur votre ordinateur (`ssh-keygen -t ed25519`), l'installer (`ssh-copy-id root@IP`), puis désactiver la connexion par mot de passe (`PasswordAuthentication no` dans `/etc/ssh/sshd_config`, puis `systemctl restart ssh`). Changez le mot de passe root fourni par Contabo.

## 2. Récupérer le code directement sur le VPS
Le dépôt est privé : le VPS doit prouver qu'il a le droit de le lire. Le plus simple est un **jeton GitHub en lecture seule**.
1. Sur github.com (depuis votre ordinateur) : photo de profil → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
   - Repository access : **Only select repositories** → `Ntchamba/netbuis`.
   - Permissions → Repository permissions → **Contents : Read-only**.
   - Durée : 30 jours par exemple. **Generate token**, puis copiez-le (il ne s'affiche qu'une fois). Ne le collez jamais dans un message.
2. Sur le VPS :
```
apt-get update && apt-get install -y git
git clone --branch claude/gifted-dijkstra-yjxzvf https://github.com/Ntchamba/netbuis.git /opt/netbuis
```
Git demande : **Username** = votre identifiant GitHub ; **Password** = le jeton (rien ne s'affiche pendant le collage, c'est normal).

*(Alternative sans jeton : une « clé de déploiement » SSH — `ssh-keygen -t ed25519 -f ~/.ssh/netbuis_deploy -N ""`, puis collez TOUTE la ligne de `cat ~/.ssh/netbuis_deploy.pub` (elle commence par `ssh-ed25519 AAAA…`) dans GitHub → dépôt → Settings → Deploy keys, et clonez avec `git@github.com:Ntchamba/netbuis.git`. Le message « Key is invalid » veut dire qu'autre chose que cette ligne a été collé.)*

## 3. Installer NetBuis
**Sans nom de domaine** (remplacez l'e-mail ; il sert à Let's Encrypt pour les certificats) :
```
bash /opt/netbuis/deploy/vps/install.sh auto vous@example.org
```
Le script trouve l'IP publique du VPS et affiche les adresses, par exemple `203-0-113-5.sslip.io`. **Avec un domaine** : remplacez `auto` par le domaine.

Le script : installe Docker, règle le pare-feu (SSH, 80, 443, UDP 10000), crée le fichier de configuration `/opt/netbuis/deploy/vps/.env` avec des secrets tirés au hasard (droits 600, jamais affichés), construit et démarre tout, et programme une **sauvegarde quotidienne**. Comptez 10 à 25 minutes.

Vérifier (remplacez par vos adresses ; la ligne `DOMAINE=` de `/opt/netbuis/deploy/vps/.env` les rappelle) :
```
cd /opt/netbuis/deploy/vps && docker compose ps
grep '^DOMAINE=' .env
curl -I https://api.203-0-113-5.sslip.io/api/health/     # 200
```

## 4. Créer le premier administrateur
```
cd /opt/netbuis/deploy/vps
docker compose exec api python manage.py createsuperuser
```
(numéro de téléphone puis mot de passe, saisis au clavier). Connectez-vous sur `https://admin.VOTRE-DOMAINE` (sans domaine : `https://admin.203-0-113-5.sslip.io`, avec votre IP). Les administrateurs suivants se créent depuis le tableau de bord.

## 5. La visioconférence (appels) — facultatif mais nécessaire aux appels
```
bash /opt/netbuis/deploy/vps/jitsi.sh
```
Il installe Jitsi (projet officiel `docker-jitsi-meet`) derrière Caddy sur `https://meet.VOTRE-DOMAINE` (ou `https://meet.<IP-avec-tirets>.sslip.io`), avec authentification par jeton (personne ne peut ouvrir une salle sans NetBuis), puis branche le serveur NetBuis dessus. Si l'audio ne passe pas : UDP 10000 doit être ouvert dans le panneau Contabo. Essai : `docs/RECETTE.md` §3.

## 6. Construire l'APK Android (sur le VPS, sans rien installer chez vous)
```
cd /opt/netbuis
docker build --target apk -f mobile/Dockerfile.apk --build-arg API_URL=https://api.VOTRE-DOMAINE/api --output type=local,dest=/root/sortie mobile
```
Récupérez-le sur votre ordinateur : `scp root@IP:/root/sortie/app-release.apk .` puis installation sur le téléphone (`GUIDE_JEFF.md` §3). Ce Dockerfile n'a jamais pu être construit depuis la session de travail (SDK Android inaccessible) : première exécution = premier test. Alternatives : GitHub Actions, ou `deploy/firebase/README.md` pour les testeurs.

## 7. Exploitation
- **Mettre à jour** : `bash /opt/netbuis/deploy/vps/update.sh` (avec un jeton GitHub, Git le redemande ; s'il a expiré, créez-en un nouveau) (récupère le code, reconstruit, redémarre ; les migrations de base s'appliquent au démarrage). Faites `backup.sh` avant.
- **Sauvegardes** : automatiques à 3 h (`/var/backups/netbuis`, 7 jours). **Copiez-les ailleurs** (autre serveur, stockage chiffré) : elles contiennent des numéros de téléphone et des pièces d'identité, et une sauvegarde sur le même disque ne protège pas d'une panne du VPS. Restauration : `docker compose exec -T db pg_restore --clean --if-exists -U netbuis -d netbuis < base-AAAA-MM-JJ-HHMM.dump`.
- **Journaux** : `docker compose logs -f api` (ne contiennent ni numéro ni jeton par conception).
- **Redémarrage** du VPS : tout redémarre seul (`restart: unless-stopped`).
- **Sécurité** : mises à jour du système (`apt-get upgrade`), connexion SSH par clé, rien d'autre ouvert que 22/80/443/UDP 10000. Docker publie ses ports en contournant `ufw` : n'ajoutez pas de `ports:` aux services sans y penser (la base de données n'en publie aucun).
- **Changer le mot de passe PostgreSQL** de l'ancien `.env` du dépôt (il reste dans l'historique de `main`).

## 8. Adresses et rôles des fichiers
DOMAINE = votre domaine, ou `<IP-avec-tirets>.sslip.io` sans domaine.

| Adresse | Rôle |
|---|---|
| `https://api.DOMAINE` | serveur (API) |
| `https://admin.DOMAINE` | tableau de bord |
| `https://app.DOMAINE` | application web installable (PWA ; l'appel n'y est pas disponible) |
| `https://meet.DOMAINE` | Jitsi |

`deploy/vps/` : `install.sh` (installation), `jitsi.sh` (visio), `update.sh`, `backup.sh`, `docker-compose.yml`, `Caddyfile`, `env.example`.
