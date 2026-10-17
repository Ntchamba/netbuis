# Lancer la construction de NetBuis avec Claude Code (sur ton ordinateur)

## Préparation (une seule fois, ~10 minutes)

1. Clone le dépôt (`git clone https://github.com/Ntchamba/netbuis`) et ouvre-le dans VS Code, puis un terminal.
2. (Ancienne méthode par zip : n'est plus nécessaire.)
3. Git : le dépôt existe sur GitHub. En local, rien n'est poussé sans ta demande ; dans le cloud, voir « Mode cloud » dans `CLAUDE.md`.
4. Base de données : crée la base (`createdb netbuis`, ou `CREATE DATABASE netbuis;` dans psql).
5. Crée le fichier `backend/.env` à partir de `backend/.env.example` et mets-y ton `DATABASE_URL` (ton mot de passe PostgreSQL reste **dans ce fichier seulement**, jamais ailleurs ; ce fichier n'est pas versionné).
6. Les agents et les réglages de sécurité sont déjà dans `.claude/` (versionné : `.claude/agents/` et `.claude/settings.json`). Crée seulement le dossier des journaux : `mkdir -p logs`.
7. Vérifie que ces fichiers existent : `CLAUDE.md`, `docs/ORCHESTRATION.md`, `docs/BACKLOG.md`, `docs/PROGRESS.md`, `docs/DECISIONS_JEFF.md`, `docs/design/maquettes/` (24 écrans), `docs/spec/`, `scripts/verifier_tache.sh`.
8. Lance `claude` dans ce dossier, tape `/agents` pour vérifier que les 9 agents sont listés (a1, a2, a3, b1, b2, b3, c1, c2, c3) plus `verificateur`.

## Le message à coller (le seul dont tu aies besoin)

> Tu es l'orchestrateur de NetBuis. Lis `CLAUDE.md`, puis `docs/ORCHESTRATION.md`, `docs/PROGRESS.md`, `docs/BACKLOG.md` et `docs/DECISIONS_JEFF.md`.
> Construis toute l'application, de la tâche T000 à la tâche T125, **une tâche à la fois**, exactement selon `ORCHESTRATION.md` : brief à un sous-agent, vérification par toi-même critère par critère, mise à jour de `PROGRESS.md`, un commit par tâche, puis tâche suivante.
> Aucun paiement, aucun déploiement, aucune tâche `V..`. Les maquettes sont dans `docs/design/maquettes/` et l'emportent sur tout texte qui les contredit.
> Tu continues sans me demander, sauf aux arrêts prévus au §8 : zones 🔒, fin de chaque tranche, clé ou donnée indispensable, tâche bloquée après trois essais.
> Commence par me confirmer en 5 lignes que tu as lu les fichiers (dernière tâche validée, prochaine tâche), puis lance T000.

## En cours de route

| Tu écris | Effet |
|---|---|
| `continue` | l'orchestrateur reprend la boucle |
| `stop` | il termine la tâche en cours puis s'arrête |
| `où en est-on` | il lit `PROGRESS.md` et répond en 5 lignes |
| `saute T0xx` | il marque la tâche « sautée » (avec ton accord écrit dans le journal) |
| `go V0x` | il autorise une tâche facultative |

- **Si la conversation devient lente ou confuse** : écris `/compact`, ou ferme et relance `claude` avec le même message. Rien n'est perdu : l'état est dans `docs/PROGRESS.md` et dans les commits.
- **Tes arrêts obligatoires** : l'orchestrateur te demande de relire les zones 🔒 (code SMS et jetons, appel, connexion admin) et d'essayer l'application à la fin de chaque « tranche ». Réponds `validé` ou dis ce qui ne va pas.
- **Tests sur téléphone réel** : à T052 et T057 il te donnera une courte liste (appel Orange, appel MTN, une seule SIM…) à faire sur ton téléphone Android.
- **Décisions** : ouvre `docs/DECISIONS_JEFF.md`. Rien ne bloque si tu ne réponds pas : les valeurs par défaut s'appliquent. Tu peux les changer quand tu veux.

## À avoir sous la main plus tard (pas maintenant)

La clé du fournisseur de SMS (T006 réel), la liste de tes quartiers/villes, les sous-catégories des secteurs non détaillés, les coordonnées du support, les textes légaux. Voir la fin de `docs/DECISIONS_JEFF.md`.

## Avec un agent Claude Code dans le cloud

1. Crée une session Claude Code sur claude.ai/code avec le dépôt `Ntchamba/netbuis`.
2. Colle le même message que ci-dessus, en ajoutant : « Tu es en mode cloud : applique la section Mode cloud de `CLAUDE.md`. »
3. Le travail arrive sur GitHub dans la branche de la phase, avec une pull request en brouillon que tu relis et fusionnes.
