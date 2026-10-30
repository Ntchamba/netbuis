#!/usr/bin/env bash
# Met NetBuis à jour : récupère la dernière version du code, reconstruit et redémarre.
# Les migrations de la base s'appliquent au démarrage du serveur. Faire d'abord ./backup.sh.
set -euo pipefail
cd "$(dirname "$0")"
git -C ../.. pull --ff-only
docker compose --env-file .env up -d --build
docker image prune -f >/dev/null
docker compose ps
