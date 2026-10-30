#!/usr/bin/env bash
# Installe NetBuis sur un VPS Ubuntu/Debian (Contabo ou autre), en root.
#
#   bash install.sh DOMAINE EMAIL_LETSENCRYPT [DEPOT_GIT] [BRANCHE]
#   ex. : bash install.sh netbuis.example.org moi@example.org git@github.com:Ntchamba/netbuis.git claude/gifted-dijkstra-yjxzvf
#
# Idempotent : on peut le relancer. N'affiche jamais un secret. Voir docs/deployment/VPS_CONTABO.md.
set -euo pipefail

DOMAINE="${1:?Usage : install.sh DOMAINE EMAIL [DEPOT_GIT] [BRANCHE]}"
ACME_EMAIL="${2:?Usage : install.sh DOMAINE EMAIL [DEPOT_GIT] [BRANCHE]}"
DEPOT="${3:-git@github.com:Ntchamba/netbuis.git}"
BRANCHE="${4:-claude/gifted-dijkstra-yjxzvf}"
DEST=/opt/netbuis

[ "$(id -u)" -eq 0 ] || { echo "À lancer en root (sudo -i)."; exit 1; }
case "$DOMAINE" in *.*) ;; *) echo "DOMAINE doit être un nom de domaine (ex. netbuis.example.org)."; exit 1;; esac

echo "== 1/7 Paquets de base"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl git ufw openssl cron

echo "== 2/7 Docker"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi
docker compose version >/dev/null

echo "== 3/7 Mémoire d'échange (la construction de l'application web demande ~4 Go)"
if [ "$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)" -lt 6000 ] && [ "$(swapon --show | wc -l)" -eq 0 ]; then
  fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "== 4/7 Pare-feu (SSH, web, audio Jitsi)"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw allow 10000/udp
ufw --force enable

echo "== 5/7 Code"
if [ ! -d "$DEST/.git" ]; then
  git clone --branch "$BRANCHE" "$DEPOT" "$DEST"
else
  git -C "$DEST" fetch origin "$BRANCHE"
  git -C "$DEST" checkout "$BRANCHE"
  git -C "$DEST" pull --ff-only origin "$BRANCHE"
fi
cd "$DEST/deploy/vps"

echo "== 6/7 Fichier de configuration .env (secrets tirés au hasard, jamais affichés)"
if [ ! -f .env ]; then
  umask 077
  {
    echo "DOMAINE=$DOMAINE"
    echo "ACME_EMAIL=$ACME_EMAIL"
    echo "POSTGRES_PASSWORD=$(openssl rand -hex 24)"
    echo "SECRET_KEY=$(openssl rand -hex 32)"
    echo "SMS_PROVIDER=real"
    echo "SMS_API_KEY="
    echo "JITSI_DOMAIN="
    echo "JITSI_APP_ID="
    echo "JITSI_JWT_SECRET="
  } > .env
  chmod 600 .env
  echo "   .env créé (droits 600). ⚠ SMS : aucun fournisseur réel n'est encore codé (décision D-02) : les clients ne pourront pas se connecter tant qu'il n'est pas choisi. Le tableau de bord (mot de passe) fonctionne."
else
  echo "   .env existe déjà : conservé."
fi
docker network inspect netbuis_edge >/dev/null 2>&1 || docker network create netbuis_edge >/dev/null

echo "== 7/7 Construction et démarrage (10 à 25 minutes la première fois)"
docker compose --env-file .env up -d --build

echo "== Sauvegarde quotidienne (3 h du matin, 7 jours conservés)"
cat > /etc/cron.d/netbuis-sauvegarde <<CRON
0 3 * * * root $DEST/deploy/vps/backup.sh >> /var/log/netbuis-sauvegarde.log 2>&1
CRON
chmod 644 /etc/cron.d/netbuis-sauvegarde

cat <<FIN

Terminé. Vérifications :
  docker compose -f $DEST/deploy/vps/docker-compose.yml ps
  curl -I https://api.$DOMAINE/api/health/
Premier administrateur (numéro et mot de passe saisis au clavier) :
  cd $DEST/deploy/vps && docker compose exec api python manage.py createsuperuser
Les adresses : https://admin.$DOMAINE (tableau de bord), https://app.$DOMAINE (application web), https://api.$DOMAINE (serveur).
Pour la visioconférence : bash $DEST/deploy/vps/jitsi.sh
FIN
