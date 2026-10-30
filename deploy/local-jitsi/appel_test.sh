#!/usr/bin/env bash
# Joue un APPELANT sans téléphone : se connecte par code SMS (lu dans les journaux du serveur local),
# crée un appel vers l'équipe et affiche l'adresse de la salle Jitsi à ouvrir dans un 2e navigateur.
# Prérequis : docker compose local lancé, Jitsi local (install.sh), un agent connecté au tableau de bord
# (http://localhost:8080) et « Disponible ». Usage : bash deploy/local-jitsi/appel_test.sh [NUMERO]
set -euo pipefail
cd "$(dirname "$0")/../.."
API=http://localhost:8000/api
PHONE="${1:-600000099}"   # numéro FICTIF d'essai

py() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

echo "== Demande du code pour $PHONE"
curl -fsS -X POST "$API/auth/otp/request/" -H 'Content-Type: application/json' -d "{\"phone\":\"$PHONE\"}" >/dev/null
sleep 2
CODE="$(docker compose logs --no-log-prefix --since 2m api | grep '\[SMS console\]' | tail -1 | grep -oE '[0-9]{6}' | tail -1)"
[ -n "$CODE" ] || { echo "Code introuvable dans les journaux (docker compose logs api)."; exit 1; }

echo "== Connexion"
ACCESS="$(curl -fsS -X POST "$API/auth/otp/verify/" -H 'Content-Type: application/json' -d "{\"phone\":\"$PHONE\",\"code\":\"$CODE\"}" | py 'd["access"]')"

echo "== Appel vers l'équipe"
REP="$(curl -sS -X POST "$API/calls/sessions/" -H "Authorization: Bearer $ACCESS" -H 'Content-Type: application/json' -d '{}')"
STATE="$(printf '%s' "$REP" | py 'd.get("state") or d.get("code")')"
echo "   état : $STATE"
if [ "$STATE" != "ringing" ]; then
  echo "   Réponse du serveur : $(printf '%s' "$REP" | py '{k: v for k, v in d.items() if k != "jitsi"}')"
  echo "   (« unavailable » = aucun agent Disponible ; « jitsi_not_configured » = relancer install.sh)"
  exit 1
fi
URL="$(printf '%s' "$REP" | py '"https://%s/%s?jwt=%s" % (d["jitsi"]["domain"], d["jitsi"]["room"], d["jitsi"]["jwt"])')"
cat <<FIN

Ça sonne sur le tableau de bord. Ouvrez CETTE adresse dans une AUTRE fenêtre de navigateur (navigation
privée par exemple) pour être l'appelant, puis cliquez sur « Répondre » dans le tableau de bord :

$URL

(Adresse valable 2 minutes, propre à cet appel d'essai. Raccrochez depuis le tableau de bord.)
FIN
