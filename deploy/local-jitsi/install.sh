#!/usr/bin/env bash
# Jitsi EN LOCAL pour essayer les appels NetBuis sur votre ordinateur (Ubuntu), à côté du docker compose local.
#   À lancer depuis la racine du dépôt, en utilisateur normal :  bash deploy/local-jitsi/install.sh
# Adresse de Jitsi : https://meet.localtest.me:8443 (localtest.me renvoie toujours vers votre propre ordinateur).
# Certificat HTTPS de confiance créé par mkcert. Secrets tirés au hasard, jamais affichés.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
JDIR="${JITSI_DIR:-$HOME/jitsi-local}"
CFG="${JITSI_CFG:-$HOME/.jitsi-meet-cfg-netbuis}"
DOMAIN=meet.localtest.me
PORT=8443

command -v docker >/dev/null || { echo "Docker manquant (voir docs/deployment/TEST_LOCAL.md)."; exit 1; }
command -v mkcert >/dev/null || { echo "Installez d'abord mkcert :  sudo apt install mkcert libnss3-tools"; exit 1; }

echo "== 1/5 Autorité de certification locale (le navigateur fera confiance au certificat)"
mkcert -install

echo "== 2/5 Code Jitsi (projet officiel docker-jitsi-meet)"
if [ ! -d "$JDIR/.git" ]; then
  TAG="$(git ls-remote --tags --refs https://github.com/jitsi/docker-jitsi-meet.git 'stable-*' | sed 's#.*/##' | sort -V | tail -1)"
  echo "   version : $TAG"
  git clone --depth 1 --branch "$TAG" https://github.com/jitsi/docker-jitsi-meet.git "$JDIR"
fi
cd "$JDIR"

echo "== 3/5 Configuration de Jitsi ($JDIR/.env)"
if [ ! -f .env ]; then
  umask 077
  cp env.example .env
  bash ./gen-passwords.sh
  APP_ID="netbuis-local"
  APP_SECRET="$(openssl rand -hex 32)"
  cat >> .env <<CONF

# --- Réglages NetBuis (essai local) ---
CONFIG=$CFG
TZ=UTC
HTTP_PORT=8088
HTTPS_PORT=$PORT
PUBLIC_URL=https://$DOMAIN:$PORT
XMPP_DOMAIN=$DOMAIN
ENABLE_LETSENCRYPT=0
JVB_ADVERTISE_IPS=127.0.0.1
ENABLE_AUTH=1
ENABLE_GUESTS=0
AUTH_TYPE=jwt
JWT_APP_ID=$APP_ID
JWT_APP_SECRET=$APP_SECRET
JWT_ACCEPTED_ISSUERS=$APP_ID
JWT_ACCEPTED_AUDIENCES=jitsi
JITSI_IMAGE_VERSION=stable
CONF
  chmod 600 .env
fi
mkdir -p "$CFG"/{web/keys,web/custom-ca,storage/web,storage/transcripts,tmp/web-load-test,prosody/config,prosody/prosody-plugins-custom,jicofo,jicofo/custom-ca,jvb}
[ -f "$CFG/web/keys/cert.crt" ] || mkcert -cert-file "$CFG/web/keys/cert.crt" -key-file "$CFG/web/keys/cert.key" "$DOMAIN"

echo "== 4/5 Démarrage de Jitsi"
docker compose up -d

echo "== 5/5 NetBuis utilise ce Jitsi ($ROOT/.env, lu par docker compose)"
APP_ID="$(grep '^JWT_APP_ID=' .env | cut -d= -f2-)"
APP_SECRET="$(grep '^JWT_APP_SECRET=' .env | cut -d= -f2-)"
cd "$ROOT"
umask 077
touch .env && chmod 600 .env
set_var() { if grep -q "^$1=" .env; then sed -i "s#^$1=.*#$1=$2#" .env; else echo "$1=$2" >> .env; fi; }
set_var JITSI_DOMAIN "$DOMAIN:$PORT"
set_var JITSI_APP_ID "$APP_ID"
set_var JITSI_JWT_SECRET "$APP_SECRET"
docker compose up -d api expire_calls

cat <<FIN

Jitsi local prêt : https://$DOMAIN:$PORT  (le navigateur doit l'ouvrir sans alerte de sécurité ;
sinon relancez le navigateur après « mkcert -install »).
Essai d'un appel : bash deploy/local-jitsi/appel_test.sh   (voir docs/deployment/JITSI_LOCAL.md)
Arrêter Jitsi : cd $JDIR && docker compose down
FIN
