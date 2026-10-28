# NetBuis sur un VPS Contabo — guide pas à pas

Ce guide installe **tout sur un seul VPS** : serveur, base de données, tableau de bord, application web (PWA), HTTPS automatique et, en option, la visioconférence Jitsi (ce qui règle la décision D-28 : un VPS ouvre le port UDP que Railway n'offre pas). Les scripts sont dans `deploy/vps/` ; tout est dans Docker.

**Honnêteté sur l'état des vérifications :** les scripts n'ont pas pu être exécutés sur un vrai VPS depuis la session de travail. Vérifiés ici : syntaxe des scripts, configuration `docker compose`, fichier Caddy (`caddy validate`), construction et lancement des images du serveur et du tableau de bord. **Non vérifiés** : l'installation complète sur un serveur réel, Let's Encrypt, Jitsi, la construction Flutter dans Docker. Si une étape échoue, copiez-moi le message (sans secret) et je corrige.

## ⚠ Bloquant : l'envoi des SMS
Aucun fournisseur de SMS réel n'est encore codé (décision D-02). En production, le fournisseur « console » est refusé et « real » n'est pas implémenté : **les clients (application mobile) ne pourront pas recevoir de code ni se connecter.** Le **tableau de bord** fonctionne (connexion par mot de passe). Il faut choisir un fournisseur (qui couvre le Cameroun) et me donner sa documentation d'API ; je code l'envoi, la clé va dans `SMS_API_KEY` sur le VPS.

## 0. Ce qu'il vous faut
- Le VPS Contabo : Ubuntu 22.04 ou 24.04, au moins **4 vCPU / 8 Go** de RAM (la construction de l'application web est gourmande ; le script ajoute un fichier d'échange si besoin) et **40 Go** de disque.
- Un **nom de domaine** que vous contrôlez. Chez votre registraire, créez 4 enregistrements DNS de type **A** vers l'adresse IP du VPS :
  `api.VOTRE-DOMAINE`, `admin.VOTRE-DOMAINE`, `app.VOTRE-DOMAINE`, `meet.VOTRE-DOMAINE`.
  Attendez que `ping api.VOTRE-DOMAINE` réponde l'IP du VPS (quelques minutes à quelques heures).
- Dans le **panneau Contabo → Firewall** (s'il est activé) : autoriser TCP 22, 80, 443 et UDP 443 et **UDP 10000**.
- Sur votre ordinateur : un terminal (Windows : PowerShell avec `ssh`).

## 1. Se connecter et sécuriser l'accès
```
ssh root@ADRESSE_IP_DU_VPS
```
Mieux : créer une clé SSH sur votre ordinateur (`ssh-keygen -t ed25519`), l'installer (`ssh-copy-id root@IP`), puis désactiver la connexion par mot de passe (`PasswordAuthentication no` dans `/etc/ssh/sshd_config`, puis `systemctl restart ssh`). Changez le mot de passe root fourni par Contabo.

## 2. Donner au VPS l'accès (lecture seule) au dépôt privé
Sur le VPS :
```
ssh-keygen -t ed25519 -f ~/.ssh/netbuis_deploy -N ""
cat ~/.ssh/netbuis_deploy.pub
```
Copiez la ligne affichée. Sur GitHub : dépôt → Settings → **Deploy keys** → Add deploy key → collez, laissez « Allow write access » **décoché**. Puis sur le VPS :
```
printf 'Host github.com\n  IdentityFile ~/.ssh/netbuis_deploy\n  IdentitiesOnly yes\n' >> ~/.ssh/config
ssh -T git@github.com     # doit répondre « Hi ... You've successfully authenticated »
```

## 3. Installer NetBuis
Récupérez le script puis lancez-le (remplacez le domaine et l'e-mail ; l'e-mail sert à Let's Encrypt) :
```
apt-get update && apt-get install -y git
git clone --branch claude/gifted-dijkstra-yjxzvf git@github.com:Ntchamba/netbuis.git /opt/netbuis
bash /opt/netbuis/deploy/vps/install.sh VOTRE-DOMAINE vous@example.org
```
Le script : installe Docker, règle le pare-feu (SSH, 80, 443, UDP 10000), crée le fichier de configuration `/opt/netbuis/deploy/vps/.env` avec des secrets tirés au hasard (droits 600, jamais affichés), construit et démarre tout, et programme une **sauvegarde quotidienne**. Comptez 10 à 25 minutes.

Vérifier :
```
cd /opt/netbuis/deploy/vps && docker compose ps
curl -I https://api.VOTRE-DOMAINE/api/health/     # 200
```

## 4. Créer le premier administrateur
```
cd /opt/netbuis/deploy/vps
docker compose exec api python manage.py createsuperuser
```
(numéro de téléphone puis mot de passe, saisis au clavier). Connectez-vous sur `https://admin.VOTRE-DOMAINE`. Les administrateurs suivants se créent depuis le tableau de bord.

## 5. La visioconférence (appels) — facultatif mais nécessaire aux appels
```
bash /opt/netbuis/deploy/vps/jitsi.sh
```
Il installe Jitsi (projet officiel `docker-jitsi-meet`) derrière Caddy sur `https://meet.VOTRE-DOMAINE`, avec authentification par jeton (personne ne peut ouvrir une salle sans NetBuis), puis branche le serveur NetBuis dessus. Si l'audio ne passe pas : UDP 10000 doit être ouvert dans le panneau Contabo. Essai : `docs/RECETTE.md` §3.

## 6. Construire l'APK Android (sur le VPS, sans rien installer chez vous)
```
cd /opt/netbuis
docker build --target apk -f mobile/Dockerfile.apk --build-arg API_URL=https://api.VOTRE-DOMAINE/api --output type=local,dest=/root/sortie mobile
```
Récupérez-le sur votre ordinateur : `scp root@IP:/root/sortie/app-release.apk .` puis installation sur le téléphone (`GUIDE_JEFF.md` §3). Ce Dockerfile n'a jamais pu être construit depuis la session de travail (SDK Android inaccessible) : première exécution = premier test. Alternatives : GitHub Actions, ou `deploy/firebase/README.md` pour les testeurs.

## 7. Exploitation
- **Mettre à jour** : `bash /opt/netbuis/deploy/vps/update.sh` (récupère le code, reconstruit, redémarre ; les migrations de base s'appliquent au démarrage). Faites `backup.sh` avant.
- **Sauvegardes** : automatiques à 3 h (`/var/backups/netbuis`, 7 jours). **Copiez-les ailleurs** (autre serveur, stockage chiffré) : elles contiennent des numéros de téléphone et des pièces d'identité, et une sauvegarde sur le même disque ne protège pas d'une panne du VPS. Restauration : `docker compose exec -T db pg_restore --clean --if-exists -U netbuis -d netbuis < base-AAAA-MM-JJ-HHMM.dump`.
- **Journaux** : `docker compose logs -f api` (ne contiennent ni numéro ni jeton par conception).
- **Redémarrage** du VPS : tout redémarre seul (`restart: unless-stopped`).
- **Sécurité** : mises à jour du système (`apt-get upgrade`), connexion SSH par clé, rien d'autre ouvert que 22/80/443/UDP 10000. Docker publie ses ports en contournant `ufw` : n'ajoutez pas de `ports:` aux services sans y penser (la base de données n'en publie aucun).
- **Changer le mot de passe PostgreSQL** de l'ancien `.env` du dépôt (il reste dans l'historique de `main`).

## 8. Adresses et rôles des fichiers
| Adresse | Rôle |
|---|---|
| `https://api.DOMAINE` | serveur (API) |
| `https://admin.DOMAINE` | tableau de bord |
| `https://app.DOMAINE` | application web installable (PWA ; l'appel n'y est pas disponible) |
| `https://meet.DOMAINE` | Jitsi |

`deploy/vps/` : `install.sh` (installation), `jitsi.sh` (visio), `update.sh`, `backup.sh`, `docker-compose.yml`, `Caddyfile`, `env.example`.
