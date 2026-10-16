#!/usr/bin/env bash
# Contrôles automatiques de fin de tâche (voir docs/ORCHESTRATION.md §4.5).
# Usage : scripts/verifier_tache.sh [fichier ou dossier ...]
# Sans argument : contrôle les fichiers modifiés ou nouveaux selon git (depuis le dernier commit).
# Code de sortie : 0 = rien à signaler, 1 = au moins un problème.
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/.." && pwd))" || exit 2
problems=0
red() { printf '\033[31m%s\033[0m\n' "$*"; }
ok()  { printf '\033[32m%s\033[0m\n' "$*"; }

if [ "$#" -gt 0 ]; then
  files=$(find "$@" -type f 2>/dev/null)
else
  files=$( { git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | sort -u )
fi
# On ne contrôle que le code et les textes, pas les journaux ni les dépendances.
files=$(printf '%s\n' "$files" | grep -Ev '(^|/)(logs|node_modules|\.venv|build|\.dart_tool|dist|\.git)/|package-lock\.json$|\.(png|jpg|jpeg|webp|ico|zip|ttf|otf)$|^docs/(BACKLOG|PROGRESS|ORCHESTRATION|DECISIONS_JEFF)\.md$|^scripts/verifier_tache\.sh$|^agents/|^CLAUDE\.md$' | while read -r f; do [ -f "$f" ] && echo "$f"; done)

if [ -z "$files" ]; then ok "Aucun fichier à contrôler."; exit 0; fi

check() { # $1 = titre, $2 = regex, $3 = (optionnel) regex de fichiers à exclure
  local hits
  hits=$(printf '%s\n' "$files" | xargs -d '\n' grep -nEI "$2" 2>/dev/null | { if [ -n "${3:-}" ]; then grep -Ev "$3"; else cat; fi; })
  if [ -n "$hits" ]; then red "✘ $1"; printf '%s\n' "$hits" | head -20; problems=1; else ok "✔ $1"; fi
}

check "Pas de TODO / FIXME / stub laissé" 'TODO|FIXME|NotImplementedError|UnimplementedError|lorem ipsum|XXX_' 'À REMPLACER'
check "Pas de test désactivé ou ignoré" '@pytest\.mark\.(skip|xfail)|pytest\.skip\(|\bxit\(|\bxdescribe\(|\bit\.skip\(|\btest\.skip\(|skip: true|@Skip'
check "Pas de secret en clair" '(password|passwd|secret_key|api_key|apikey|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"' ]{8,}["'"'"']|AKIA[0-9A-Z]{12,}|sk_(live|test)_[0-9A-Za-z]{10,}|BEGIN (RSA |EC )?PRIVATE KEY' 'change-me|example|exemple|placeholder|test-secret|\.env\.example'
check "Pas de console.log / print de débogage oublié" '^[[:space:]]*(console\.log\(|print\(|debugPrint\(|breakpoint\(\))' '(^|/)(tests?|test|scripts|management/commands)/|_test\.dart|\.test\.tsx?'

# Aucun fichier sensible suivi par git
bad=$(git ls-files 2>/dev/null | grep -E '(^|/)\.env$|(^|/)logs/|\.pem$|\.keystore$|\.jks$')
if [ -n "$bad" ]; then red "✘ Fichiers sensibles suivis par git :"; echo "$bad"; problems=1; else ok "✔ Aucun .env, log ou clé suivi par git"; fi

# Numéro de téléphone camerounais en dur (hors données de test réservées 600000xxx)
check "Pas de vrai numéro camerounais en dur" '(\+?237[ -]?)?6[5-9][0-9]{7}\b|(\+?237[ -]?)?62[0-9]{7}\b' '600000|6 ?00 ?00 ?00|6••|test|fixture|seed_demo'

[ "$problems" -eq 0 ] && ok "Contrôles automatiques : OK" || red "Contrôles automatiques : à corriger"
exit "$problems"
