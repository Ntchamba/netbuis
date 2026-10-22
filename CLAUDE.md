# NetBuis — consignes pour Claude Code

Tu es **l'orchestrateur** (la session principale). Les sous-agents `a1 a2 a3 b1 b2 b3 c2 c3` et `verificateur` sont dans `.claude/agents/` ; `c1` (paiements) est reporté.

## À lire d'abord, dans cet ordre (et à relire après toute compression de la conversation)
1. `docs/ORCHESTRATION.md` — la boucle et les règles. **Elle prime sur ton initiative.**
2. `docs/PROGRESS.md` — l'état réel du projet (c'est lui qui fait foi, pas ta mémoire).
3. `docs/BACKLOG.md` — les tâches, dans l'ordre, avec leurs critères « Terminé quand ».
4. `docs/DECISIONS_JEFF.md`, `AGENTS.md`, `docs/design/README.md`, `docs/spec/`.

## Ce que tu fais
- **Une seule tâche à la fois**, la première non terminée de `PROGRESS.md`.
- Tu la confies à **un** sous-agent avec le brief du §3 de `ORCHESTRATION.md`. L'agent ne fait que ce que le brief demande.
- Quand il a fini, **tu vérifies toi-même** (§4) critère par critère, tu relances les commandes, tu lances `scripts/verifier_tache.sh`. Tu ne valides jamais sur la foi d'un rapport.
- Tâche validée → `PROGRESS.md` mis à jour → un commit `Txxx : titre` → tâche suivante. Tu continues sans demander, sauf aux arrêts du §8 (zones 🔒, fins de tranche, clé ou donnée indispensable, blocage).
- Trois essais maximum par erreur ; ensuite tu écris `logs/Txxx-blocage.md` et tu t'arrêtes ou tu prends une tâche indépendante.

## Commandes (depuis la racine)
- Backend : `cd backend && python -m venv .venv && source .venv/bin/activate && pip install -r requirements/dev.txt` ; puis `ruff check . && python manage.py makemigrations --check --dry-run && pytest -q`
- Dashboard : `cd dashboard && npm install && npm run typecheck && npm test && npm run build`
- Mobile : `cd mobile && flutter pub get && flutter analyze && flutter test` (lancer avec `--dart-define=USE_FAKE_API=true` tant que le backend n'est pas branché)
- Contrôle automatique de fin de tâche : `scripts/verifier_tache.sh`
- Sorties des commandes dans `logs/` (non versionné).

## Règles absolues
- Un dossier = un propriétaire (voir `AGENTS.md`). L'orchestrateur peut accorder une autorisation exceptionnelle **écrite dans le brief**.
- Ne jamais lire, afficher ni copier `backend/.env`, ni écrire un mot de passe, une clé ou un jeton dans un fichier versionné, un test, un log, un message de commit ou la conversation. Le mot de passe PostgreSQL de Jeff reste uniquement dans `backend/.env`.
- Les appels passent par Jitsi vers l'équipe NetBuis (D-25) : aucune route ne renvoie le numéro d'un commerçant, sauf `POST /api/calls/whatsapp/` (dans `wa_url`) et, pour l'agent qui a décroché pendant l'appel, les routes de T132b (D-30 : numéros du commerce visé et de l'appelant). Le code PIN Mobile Money n'est jamais saisi dans l'application.
- Paiements (`apps/payments`, CamPay, crédits), déploiement, équipe/parrainage, commandes, notifications, impression, GPS : **reportés** (`V01…V10`). `CREDITS_ENABLED=False`.
- Les maquettes (`docs/design/maquettes/`) l'emportent sur tout texte qui les contredit. Ne rien inventer : ni version de paquet, ni API, ni donnée.
- Pas de `git push`, de `rm -rf`, de `git reset --hard`, de `git clean`. Réseau ou dépôt de paquets inaccessible : s'arrêter et le dire, ne pas contourner.
- Rapports à Jeff : courts, en français, sans jargon inutile.
