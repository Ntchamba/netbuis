#!/usr/bin/env bash
# Sauvegarde : base PostgreSQL + fichiers envoyés (photos, pièces d'identité). Garde 7 jours.
# Les sauvegardes contiennent des données personnelles : droits 700, à copier AILLEURS (autre serveur,
# stockage chiffré) — une sauvegarde qui reste sur le même disque ne protège pas d'une panne du VPS.
set -euo pipefail
cd "$(dirname "$0")"
DEST="${BACKUP_DIR:-/var/backups/netbuis}"
umask 077
mkdir -p "$DEST"
STAMP="$(date +%F-%H%M)"
docker compose exec -T db pg_dump -U netbuis --format=custom netbuis > "$DEST/base-$STAMP.dump"
docker compose run --rm --no-deps -T -u 0 -v "$DEST:/sortie" --entrypoint tar api czf "/sortie/fichiers-$STAMP.tgz" -C /data . 
find "$DEST" -type f \( -name 'base-*.dump' -o -name 'fichiers-*.tgz' \) -mtime +7 -delete
echo "Sauvegarde $STAMP écrite dans $DEST"
