#!/usr/bin/env bash
# Installe un serveur Jitsi (visioconférence) sur le même VPS, derrière Caddy, avec authentification
# par jeton (seul NetBuis peut ouvrir une salle), puis branche NetBuis dessus (décision D-28 : auto-hébergé).
#
#   bash jitsi.sh [ADRESSE_IP_PUBLIQUE]      (à lancer APRÈS install.sh, en root)
#
# Ouvre l'audio : UDP 10000 doit être joignable depuis Internet (pare-feu du VPS ET panneau Contabo).
# Utilise le projet officiel https://github.com/jitsi/docker-jitsi-meet (images ghcr.io/jitsi, étiquette « stable »).
set -euo pipefail

NB=/opt/netbuis/deploy/vps
JITSI=/opt/jitsi
CFG=/opt/jitsi-cfg
[ "$(id -u)" -eq 0 ] || { echo "À lancer en root."; exit 1; }
[ -f "$NB/.env" ] || { echo "Lancez d'abord install.sh."; exit 1; }
# shellcheck disable=SC1091
DOMAINE="$(grep '^DOMAINE=' "$NB/.env" | cut -d= -f2-)"
[ -n "$DOMAINE" ] || { echo "DOMAINE absent de $NB/.env"; exit 1; }
IP="${1:-$(curl -4 -fsS --max-time 10 https://api.ipify.org || true)}"
[ -n "$IP" ] || { echo "Adresse IP publique introuvable : relancez avec  bash jitsi.sh ADRESSE_IP"; exit 1; }

echo "== 1/4 Code Jitsi (dernière version stable publiée)"
TAG="$(git ls-remote --tags --refs https://github.com/jitsi/docker-jitsi-meet.git 'stable-*' | sed 's#.*/##' | sort -V | tail -1)"
echo "   version : $TAG"
if [ ! -d "$JITSI/.git" ]; then
  git clone --depth 1 --branch "$TAG" https://github.com/jitsi/docker-jitsi-meet.git "$JITSI"
fi
cd "$JITSI"

echo "== 2/4 Configuration (.env Jitsi, secrets tirés au hasard, jamais affichés)"
if [ ! -f .env ]; then
  umask 077
  cp env.example .env
  bash ./gen-passwords.sh
  APP_ID="netbuis-$(openssl rand -hex 4)"
  APP_SECRET="$(openssl rand -hex 32)"
  {
    echo ""
    echo "# --- Réglages NetBuis ---"
    echo "CONFIG=$CFG"
    echo "TZ=UTC"
    echo "HTTP_PORT=127.0.0.1:8000"
    echo "HTTPS_PORT=127.0.0.1:8443"
    echo "PUBLIC_URL=https://meet.$DOMAINE"
    echo "XMPP_DOMAIN=meet.$DOMAINE"
    echo "DISABLE_HTTPS=1"
    echo "ENABLE_HTTP_REDIRECT=0"
    echo "ENABLE_LETSENCRYPT=0"
    echo "JVB_ADVERTISE_IPS=$IP"
    echo "ENABLE_AUTH=1"
    echo "ENABLE_GUESTS=0"
    echo "AUTH_TYPE=jwt"
    echo "JWT_APP_ID=$APP_ID"
    echo "JWT_APP_SECRET=$APP_SECRET"
    echo "JWT_ACCEPTED_ISSUERS=$APP_ID"
    echo "JWT_ACCEPTED_AUDIENCES=jitsi"
    echo "JITSI_IMAGE_VERSION=stable"
    echo "RESTART_POLICY=unless-stopped"
  } >> .env
  chmod 600 .env
fi
mkdir -p "$CFG"/{web,web/custom-ca,storage/web,storage/transcripts,tmp/web-load-test,prosody/config,prosody/prosody-plugins-custom,jicofo,jicofo/custom-ca,jvb}

# Le conteneur « web » rejoint le réseau partagé avec Caddy sous le nom « jitsi-web ».
cat > docker-compose.override.yml <<'OVR'
services:
  web:
    networks:
      meet.jitsi: {}
      netbuis_edge:
        aliases:
          - jitsi-web
networks:
  netbuis_edge:
    external: true
OVR
docker network inspect netbuis_edge >/dev/null 2>&1 || docker network create netbuis_edge >/dev/null

echo "== 3/4 Démarrage de Jitsi"
docker compose up -d

echo "== 4/4 NetBuis utilise ce Jitsi"
APP_ID="$(grep '^JWT_APP_ID=' .env | cut -d= -f2-)"
APP_SECRET="$(grep '^JWT_APP_SECRET=' .env | cut -d= -f2-)"
cd "$NB"
set_var() { grep -q "^$1=" .env && sed -i "s#^$1=.*#$1=$2#" .env || echo "$1=$2" >> .env; }
set_var JITSI_DOMAIN "meet.$DOMAINE"
set_var JITSI_APP_ID "$APP_ID"
set_var JITSI_JWT_SECRET "$APP_SECRET"
docker compose --env-file .env up -d api expire_calls caddy

cat <<FIN

Jitsi installé. Contrôles :
  curl -I https://meet.$DOMAINE/        (doit répondre 200 ; le premier certificat peut prendre une minute)
  docker compose -f $JITSI/docker-compose.yml ps
Ouvrez UDP 10000 dans le panneau Contabo (Firewall) si l'audio ne passe pas.
Essai : voir docs/RECETTE.md §3. Si une salle refuse le jeton : docker compose -f $JITSI/docker-compose.yml logs prosody
FIN
