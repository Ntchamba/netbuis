# Prompt — suite des appels WebRTC directs (D-31)

À coller dans une nouvelle session Claude Code ouverte sur ce dépôt (branche `claude/gifted-dijkstra-yjxzvf`).

```
Tu travailles sur NetBuis (Django + Flutter + React). Lis d'abord, dans cet ordre : CLAUDE.md, docs/ORCHESTRATION.md, docs/PROGRESS.md, docs/BACKLOG.md (PHASE 14), docs/DECISIONS_JEFF.md (D-25, D-30, D-31), docs/spec/APPELS_WEBRTC.md. Réponds en français, court, sans jargon.

CONTEXTE ET DÉCISIONS (ne les remets pas en cause)
- Les appels se font par WebRTC DIRECT entre l'application (appelant) et le tableau de bord (agent de l'équipe), avec coturn comme relais (D-31). PLUS de FreeSWITCH, Asterisk ni Kamailio : abandonnés.
- **NE RETIRE PAS JITSI.** Le WebRTC direct s'AJOUTE à côté de Jitsi, dans l'application ET dans le tableau de bord : les deux moteurs doivent coexister et fonctionner côte à côte (réglage serveur CALL_ENGINE=jitsi|webrtc, le client suit le champ `engine` de la réponse de l'API). Aucun code, SDK, dépendance, route, test, configuration ni document Jitsi n'est supprimé ni désactivé dans cette phase : retirer Jitsi serait long et risqué. Si un changement demande de modifier du code Jitsi, il doit rester rétro-compatible (le moteur `jitsi` garde exactement son comportement et ses tests actuels).
- Jitsi ne sera retiré qu'APRÈS avoir testé les deux moteurs côte à côte dans l'application (sur téléphone, Wi-Fi et réseau mobile) et sur décision écrite de Jeff (nouvelle tâche T156, qui n'existe pas encore : ne la fais pas).
- Appels à deux uniquement ; audio seul (Opus) ; aucun numéro de téléphone dans la signalisation ; la fiche et les numéros pendant l'appel (D-30) ne changent pas.
- Idée centrale : l'appelant prépare son offre et ses adresses ICE PENDANT la sonnerie ; le serveur les garde et les rend à l'agent dans la réponse de `accept`, pour que l'audio démarre dès que l'agent répond.

DÉJÀ FAIT (vérifie, ne refais pas)
- T150 coturn : deploy/vps/docker-compose.yml, docker-compose.yml local, docs/deployment/COTURN.md ; essai de relais entre deux navigateurs : scripts/e2e_webrtc/relais.mjs (relais 10/10, p50 173 ms ; direct p50 43 ms, tout sur la même machine).
- T151 backend (code poussé, vérification incomplète) : backend/apps/calls/ — webrtc.py (identifiants TURN HMAC-SHA1 « <expiration>:<session> »), signal_service.py (signaux conservés, relayés par SSE), routes POST /api/calls/sessions/<id>/signal/ et POST /api/admin/calls/sessions/<id>/signal/, `engine` et `webrtc.ice_servers` dans create/accept, tests test_webrtc*.py. 163 tests des appels verts.

À FAIRE, UNE TÂCHE À LA FOIS, avec les sous-agents de .claude/agents/ selon la boucle de ORCHESTRATION.md (brief → un agent → TU vérifies toi-même en relançant les commandes → PROGRESS.md → un commit « Txxx : titre » → push sur la branche) :
1. T151 : finir la vérification : suite complète (ruff, makemigrations --check, pytest -q, spectacular --validate --fail-on-warn et comparaison avec docs/api/openapi.yaml, scripts/verifier_tache.sh), relecture par le sous-agent `verificateur` (zone 🔒 : signalisation, droits, secrets, fuites de numéros, journaux), docs/verifications/T151.md.
2. T152 (agent c3) : tableau de bord : quand `engine = webrtc`, « Répondre » crée RTCPeerConnection avec les serveurs ICE de l'API, lit les signaux en attente, répond, échange les candidats par l'API et le flux SSE ; audio seul ; raccrocher, fin à distance, échec de connexion, micro refusé ; moteur jitsi inchangé ; tests Vitest avec un faux RTCPeerConnection.
3. T153 (toi) : essai de bout en bout : vrai serveur + deux navigateurs Chromium (--use-fake-device-for-media-stream), appel → réponse → audio reçu → fin ; avec et sans relais forcé ; temps entre « Répondre » et audio reçu (p50/p95), noté dans docs/verifications/T153.md. Modèle : scripts/e2e_appel/bout_en_bout.mjs et scripts/e2e_webrtc/relais.mjs.
4. T154 (agents b2 + b1) : SEULEMENT après accord explicite de Jeff (nouvelle dépendance flutter_webrtc) : écran d'appel mobile en WebRTC (offre créée pendant la sonnerie), faux service pour les tests, procédure d'essai sur téléphone dans docs/TESTS_JEFF.md.
5. T155 (toi) : docs/deployment/ et tableau de comparaison des deux moteurs côte à côte (connexion, qualité, consommation de données, réseaux difficiles). Il servira à Jeff pour décider plus tard du retrait de Jitsi.
6. Côté application, prévois un moyen de choisir le moteur pour les essais (au minimum : le serveur décide via CALL_ENGINE ; idéalement un réglage visible seulement en développement) afin de pouvoir comparer Jitsi et WebRTC sur le même téléphone.

RÈGLES (CLAUDE.md) : **ne retire jamais Jitsi** (voir plus haut) ; un dossier = un propriétaire (autorisation exceptionnelle écrite dans chaque brief) ; ne jamais lire backend/.env ni écrire de secret ; pas de git push --force, rm -rf, reset --hard, clean ; ne rien inventer (versions, API) ; avant de coder une technologie imposée, propose les alternatives à Jeff ; `git add` seulement les fichiers de la tâche validée (jamais `git add -A` pendant qu'un agent travaille) ; arrêts obligatoires : zones 🔒, fins de tranche, blocage.

ENVIRONNEMENT : cloud, éphémère. Backend : créer un venv (python -m venv, pip install -r backend/requirements/dev.txt), PostgreSQL local (service postgresql start ; DATABASE_URL=postgres://netbuis_cloud:cloud-dev-local@localhost:5432/netbuis DEBUG=True SECRET_KEY=<32+ caractères> SMS_PROVIDER=console). Docker : dockerd --iptables=false --ip6tables=false --bridge=none --storage-driver=vfs, toujours --network host, images depuis mirror.gcr.io/library/<image> (Docker Hub limite les téléchargements). Chromium + Playwright : /opt/pw-browsers, /opt/node-tools/node_modules/playwright.
```

## Notes pour Jeff
- Le commit « T150 : essai WebRTC… » contient par erreur le code de T151 qui était en cours (j'avais fait `git add -A` pendant que l'agent travaillait). Je l'ai vérifié après coup : ruff, migrations, contrat d'API et 163 tests des appels sont verts. La suite complète et la relecture indépendante restent à faire.
- FreeSWITCH n'est plus dans le plan.
