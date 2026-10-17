# NetBuis : contexte compressé (état au 13/10/2026)

## Projet
Super-App métier Cameroun : recherche produit → commerçants locaux → appel direct (Android, choix ligne Orange/MTN à chaque appel, pas de Twilio) + WhatsApp `wa.me` → forum (publications commerçants + commentaires) → produits tendance → dashboard admin.
Stack : Flutter Android `mobile/`, Django 5.2 + DRF + PostgreSQL `backend/`, React Vite+TS+Tailwind `dashboard/`.
Reportés (V01–V10, accord écrit de Jeff requis) : paiements/CamPay, crédits, abonnements payants, déploiement, Play Store, équipe/parrainage, commandes, push, impression, GPS, iOS.

## Dépôt (PC de Jeff)
`/home/ntchambaalan/NETBUIS/netbuis`, branche `etape-1/socle`, aucun dépôt distant. Commits T000 → T006b. Git = 4,9 Mo (ne pas envoyer `.venv`, `node_modules`, `mobile/build`, `backend/.env`).
Le contexte vit dans les fichiers : `CLAUDE.md`, `docs/ORCHESTRATION.md`, `docs/PROGRESS.md`, `docs/BACKLOG.md` (T000–T125), `docs/DECISIONS_JEFF.md` (D-01…D-24), `logs/`, `.claude/agents/`.
Priorité : DECISIONS_JEFF > ORCHESTRATION > docs/spec > maquettes > BACKLOG.

## Méthode
Orchestrateur (session principale) + sous-agents a1–a3 (Django), b1–b3 (Flutter), c2 (API admin), c3 (dashboard), `verificateur` (relecture indépendante). Une tâche à la fois, vérif critère par critère + `scripts/verifier_tache.sh`, un commit `Txxx : titre`, 3 essais max puis `logs/Txxx-blocage.md`. Arrêts obligatoires : tâches 🔒, fins de tranche, clé/donnée manquante, actions destructives ou publiques.

## Règles fixes de Jeff
- Compte par numéro de téléphone seul, pas de carte bancaire.
- Aucun secret dans le code ou la discussion. Mot de passe PostgreSQL uniquement dans `backend/.env` (ignoré par Git, jamais lu par Claude) ; il est différent de `netbuis`.
- PIN Mobile Money jamais dans l'app.

## Où on en est
- T006 (code SMS) relu : conforme, validé sous réserve. T006b (durcissement : limite verify + blocage 1 h, HMAC-SHA256, limite atomique, retrait `netbuis:netbuis` de `base.py`/`.env.example`, retrait `OTP_TEST_MODE`) est commité mais **pas encore relu**.
- Prochaine tâche : T007 🔒 (JWT / connexion admin).
- Décisions en attente : fournisseur SMS (Orange SMS conseillé), formats de numéro (garder 6XXXXXXXX), durée de blocage, vraie `SECRET_KEY` avant mise en service.
- Dernière question : passer le travail sur Claude Code web. Réponse donnée : créer un dépôt GitHub **privé**, Jeff pousse lui-même (`git remote add origin …` puis `git push -u origin etape-1/socle`), lancer la session web avec `LANCER_AVEC_CLAUDE_CODE.md`, ne coder qu'à un seul endroit. Conseil : backend + dashboard sur le web, mobile sur le PC. **Choix de Jeff attendu.**
