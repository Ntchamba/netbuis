# Guide d'orchestration — comment on construit NetBuis, une tâche à la fois

Ce guide s'adresse à **la session principale de Claude Code, qui joue l'orchestrateur**, et aux sous-agents qu'elle appelle. Il est fait pour que le projet avance **sans halluciner, sans boucler, sans bâcler et sans oublier une fonctionnalité**.

Fichiers à connaître : `docs/BACKLOG.md` (les tâches) · `docs/PROGRESS.md` (où on en est) · `docs/DECISIONS_JEFF.md` (décisions) · `docs/design/README.md` + `docs/design/maquettes/` (écrans) · `docs/spec/` (règles métier) · `docs/TASKS_PAR_AGENT.md` (fichiers à toucher) · `AGENTS.md` (propriétés des dossiers et règles).

---

## 1. Les rôles

| Rôle | Qui | Ce qu'il fait | Ce qu'il ne fait pas |
|---|---|---|---|
| **Orchestrateur** | la session principale | choisit la prochaine tâche, rédige le brief, appelle **un** sous-agent, **vérifie le résultat lui-même**, met à jour `PROGRESS.md`, commit | écrire le gros du code à la place des agents ; valider sans preuve |
| **Sous-agents** `a1 a2 a3 b1 b2 b3 c2 c3` | appelés par l'orchestrateur | exécutent **exactement** la tâche du brief dans leur périmètre, lancent les tests, rendent un rapport | choisir leur propre tâche ; toucher un autre dossier ; ajouter des idées non demandées |
| **`verificateur`** | sous-agent en lecture seule | relit une tâche à neuf, sans avoir vu le travail, et dit ce qui ne correspond pas au cahier | modifier du code |
| **`c1`** | sous-agent des paiements | **reporté** : n'est jamais appelé | — |
| **Jeff** | le propriétaire | relit les zones 🔒, fournit clés et données, fait les tests sur téléphone | — |

Les sous-agents de Claude Code ne peuvent pas en lancer d'autres : **seule la session principale appelle les agents**.

---

## 2. La boucle (à répéter pour chaque tâche)

```
1. CHOISIR    → la première tâche non terminée de PROGRESS.md dont les dépendances sont ✅
2. PRÉPARER   → lire la tâche dans BACKLOG.md + les lignes TASKS_PAR_AGENT.md citées + la maquette + la spec
3. BRIEFER    → un seul sous-agent, avec le brief du §3
4. LAISSER FAIRE → l'agent code, lance les commandes, corrige, rend son rapport
5. VÉRIFIER   → l'orchestrateur refait la vérification lui-même (§4), critère par critère
6. DÉCIDER    → ✅ validée / ↩ à corriger (retour à 3 avec la liste précise des écarts) / ⛔ bloquée (§7)
7. ENREGISTRER → PROGRESS.md mis à jour + un commit « Txxx : titre »
8. SUIVANT    → retour à 1. Jamais deux tâches en même temps.
```

**Cadence** : on enchaîne les tâches sans demander à Jeff, **sauf** aux arrêts obligatoires du §8. À chaque fin de tâche, l'orchestrateur écrit à Jeff **deux lignes** (tâche validée, prochaine tâche), pas un long rapport.

**Une tâche à la fois** : le sous-agent ne lit pas le reste du backlog pour « prendre de l'avance ». Les tâches de plusieurs agents (« a2 puis c2 ») s'exécutent l'une après l'autre, avec une vérification entre les deux.

---

## 3. Le brief donné au sous-agent (modèle à remplir)

```
TÂCHE <Txxx> — <titre>        Agent : <nom>

Tu fais UNIQUEMENT cette tâche. Si tu vois autre chose à faire, note-le dans ton rapport, ne le fais pas.

À LIRE avant d'écrire une ligne :
- docs/BACKLOG.md, section <Txxx> (copiée ci-dessous)
- docs/TASKS_PAR_AGENT.md, lignes <refs> : **seuls les fichiers à toucher et les méthodes font foi** ; en cas de différence sur le comportement, BACKLOG.md l'emporte (voir son tableau « Écarts connus »)
- <maquettes : chemins exacts dans docs/design/maquettes/>          (si écran)
- <docs/spec/…>                                                       (si règle métier)
- docs/DECISIONS_JEFF.md : <D-xx concernées>
- les fichiers déjà présents dans ton périmètre (LIRE avant de modifier)

PÉRIMÈTRE D'ÉCRITURE : <dossiers de ton agent> + les « Autorisations permanentes » de docs/BACKLOG.md.   <Autorisation exceptionnelle éventuelle : « tu peux aussi écrire dans … » — écrite ici par l'orchestrateur, sinon interdit>

TERMINÉ QUAND : <recopie mot pour mot de la tâche>

COMMANDES À LANCER TOI-MÊME et à garder dans logs/ : <commandes du backlog>

INTERDITS : voir CLAUDE.md. En particulier : ne lis jamais backend/.env ; aucun secret ; aucune donnée inventée ; pas de TODO laissé ; pas de test supprimé ou désactivé.

RAPPORT (court, en français) :
1. Fichiers créés / modifiés.
2. Pour CHAQUE critère « Terminé quand » : ✔ ou ✘, avec la PREUVE (commande + résultat, ou test + nom, ou fichier:ligne).
3. Commandes lancées et résultat réel (colle les dernières lignes).
4. Décisions que tu as dû prendre (et pourquoi). Écrans sans maquette. Points flous.
5. Ce qui reste rouge. Rien n'est caché.
```

---

## 4. La vérification par l'orchestrateur (étape 5 — la plus importante)

L'orchestrateur **ne croit pas le rapport**. Il vérifie :

1. **Périmètre** : `git status` et `git diff --stat` — aucun fichier hors périmètre ou hors liste ; pas de gros fichiers inattendus.
2. **Commandes** : il relance **lui-même** les commandes de vérification du dossier (voir BACKLOG). Il lit la sortie ; il l'enregistre dans `logs/<Txxx>-verif.txt`.
3. **Critères** : il reprend « Terminé quand » **un par un** et note, pour chacun, la preuve qu'il a vue. Un critère sans preuve = ✘. Il fait un tableau dans `logs/<Txxx>-verification.md` :

   | Critère | ✔/✘ | Preuve vue par l'orchestrateur |
   |---|---|---|

4. **Cahier de charge** : il relit la ligne de la tâche dans `docs/spec/` et la maquette, et vérifie que le résultat **dit la même chose** (libellés, ordre, champs, règles, plafonds). Pour un écran : il compare les textes de la maquette avec les chaînes du code.
5. **Contrôles automatiques** (`scripts/verifier_tache.sh`, à lancer à chaque tâche) :
   - aucune occurrence de `TODO`, `FIXME`, `NotImplementedError`, `pass  # stub`, `throw UnimplementedError`, `lorem` dans les fichiers de la tâche (sauf `À REMPLACER` listé dans `PROGRESS.md`) ;
   - aucun motif de secret (`password=`, `secret_key =` avec valeur, `sk_`, `AKIA`, jetons) dans les fichiers versionnés ;
   - aucun test marqué `skip`/`xfail`/`@Skip` nouveau ;
   - `git ls-files` ne contient ni `.env`, ni `logs/`, ni clé.
6. **Numéro de téléphone** : pour toute tâche qui touche à la recherche, aux fiches, à la carte, au forum ou aux logs, il vérifie qu'aucun numéro de commerçant n'apparaît (test existant ou recherche dans les réponses de test).
7. **Contrat** : `docs/api/openapi.yaml` décrit les routes de la tâche, et le mobile / le dashboard utilisent bien ce contrat.
8. **Vérificateur indépendant** : **obligatoire** pour les tâches 🔒 et les vérifications de tranche ; facultatif sinon. L'orchestrateur appelle `verificateur` avec **seulement** : la tâche, les critères, la liste des fichiers modifiés — **pas** son avis. Si le vérificateur trouve un écart que l'orchestrateur n'avait pas vu, la tâche retourne en correction.

Si tout est ✔ → ✅. Sinon → ↩ avec la liste exacte des ✘ (l'agent ne corrige que cela).

---

## 5. Définition de « terminé » (identique pour toutes les tâches)

Une tâche est ✅ seulement si **toutes** ces lignes sont vraies :

- [ ] Tous les critères « Terminé quand » ont une preuve.
- [ ] Les commandes de vérification du dossier sont vertes, relancées par l'orchestrateur.
- [ ] Des tests existent pour chaque règle nouvelle (cas qui réussit **et** cas qui doit échouer).
- [ ] Aucun fichier hors périmètre ; aucun `TODO`, stub ou code commenté.
- [ ] `docs/api/openapi.yaml` à jour pour les routes ajoutées ou modifiées.
- [ ] Textes de l'interface en français **et** en anglais (`assets/l10n/fr.json` et `en.json`) pour le mobile ; pour un écran : cibles ≥ 48 dp, clavier numérique pour les chiffres, aucun défilement horizontal, test à 360 px de large.
- [ ] Aucun secret, aucun numéro de commerçant dans le code, les tests, les logs, les messages d'erreur.
- [ ] `PROGRESS.md` mis à jour, un commit « Txxx : titre » fait.
- [ ] Les choix faits sans maquette ou sans spec sont écrits dans `PROGRESS.md` (colonne « Notes »).

---

## 6. Règles contre les hallucinations

1. **Lire avant d'écrire.** Un agent lit les fichiers de son périmètre et le code appelé avant de modifier.
2. **Ne jamais inventer une version, une méthode ou une option.** Après installation, lire la version réelle (`pip show`, `flutter pub deps`, `npm ls`). Pour une API qu'on connaît mal, lire la source du paquet installé (`.venv/lib/.../site-packages`, `~/.pub-cache`, `node_modules`) ou lancer un petit essai. Si le paquet n'est pas téléchargeable : **s'arrêter et le dire** (ne pas le contourner).
3. **Ne jamais inventer une donnée** : villes, quartiers, produits, prix réels, numéros, contacts, textes légaux. Utiliser les données de la spec ; sinon un marqueur `À REMPLACER` + une ligne dans `PROGRESS.md`.
4. **« Ça marche » = une commande qui l'a prouvé.** Le journal est dans `logs/`. Pas de preuve, pas de ✔.
5. **Ne pas changer le cahier en douce.** Si la spec, la maquette et le backlog se contredisent : maquette et `DECISIONS_JEFF.md` d'abord ; l'agent écrit le conflit dans son rapport, il ne tranche pas seul.
6. **Rien de plus que demandé.** Les bonnes idées vont dans `docs/IDEES.md` (une ligne chacune), pas dans le code.
7. **Ne pas truquer les tests** : jamais de test supprimé, désactivé, affaibli, ni de simulation de la chose testée.
8. **Contrat d'abord** : toute route est décrite dans `openapi.yaml` avant que le mobile ou le dashboard ne l'utilise.
9. **Même vocabulaire partout** : les noms de champs viennent de `docs/spec/MODELE_DONNEES.md` ; pas de synonymes inventés.
10. **Un texte de maquette se recopie, il ne se « réinterprète » pas.**

## 7. Règles contre les boucles et le travail bâclé

1. **Trois essais maximum** par vérification qui échoue. Chaque essai doit **changer d'approche** (hypothèse écrite en une ligne). Relancer la même commande sans changer le code est interdit au-delà de deux fois.
2. Après le 3ᵉ échec : l'agent s'arrête et écrit `logs/<Txxx>-blocage.md` (ce qui échoue, les 3 hypothèses, les messages d'erreur exacts). L'orchestrateur marque la tâche ⛔ dans `PROGRESS.md`, puis :
   - si une tâche suivante **ne dépend pas** de la tâche bloquée, il la prend ;
   - sinon il **s'arrête et prévient Jeff** avec le fichier de blocage. Il ne « contourne » pas.
3. **Réseau ou dépôt de paquets inaccessible** : arrêt immédiat et rapport. Jamais de contournement.
4. **Tâche trop grosse** : si elle dépasse ~25 fichiers ou ~1 500 lignes, l'orchestrateur la découpe en `Txxx.a`, `Txxx.b` dans `BACKLOG.md` avant de continuer.
5. **Pas de « presque »** : une tâche à 90 % est ↩, pas ✅.
6. **Pas de réécriture massive** d'un travail déjà validé sans tâche écrite pour cela.
7. **Pas de boucle de correction infinie entre agents** : un même écart renvoyé deux fois à l'agent sans changement → l'orchestrateur lit le code lui-même, trouve la cause, et donne l'instruction précise.

## 8. Arrêts obligatoires (l'orchestrateur attend Jeff)

| Moment | Pourquoi |
|---|---|
| Après une tâche 🔒 validée techniquement | Jeff relit ligne par ligne : OTP/jetons (T006, T007), pièces d'identité (T027, T071), appel (T050, T052), connexion admin et droits (T070, T077, T089) |
| Fin de chaque vérification de tranche (T012, T023, T036, T048, T057, T063, T089, T096, T103, T112) | Jeff peut essayer sur son téléphone / dans son navigateur et corriger la direction |
| Une clé, une donnée ou une décision est vraiment nécessaire (SMS réel, liste de quartiers…) | Seulement si le défaut de `DECISIONS_JEFF.md` ne permet pas d'avancer |
| Tâche ⛔ sans alternative | Voir §7 |
| Tâche `V..` | Jamais sans « go » écrit |
| Toute action destructrice ou publique (`git push`, suppression de dossier, déploiement) | Interdit sans demande explicite |

Entre ces arrêts, **on continue sans demander**.

## 9. Reprise après perte de contexte (très important)

La mémoire de la session peut être comprimée ou perdue. Tout l'état est donc **dans les fichiers**. À chaque début de session, et après toute compression, l'orchestrateur fait, dans cet ordre :

1. Lire `CLAUDE.md`, `docs/ORCHESTRATION.md`, `docs/PROGRESS.md`, `docs/DECISIONS_JEFF.md`.
2. `git status` et `git log --oneline -15`.
3. Lire la ligne « EN COURS » de `PROGRESS.md` ; si une tâche est 🔄, regarder `git diff --stat` et le dernier `logs/<Txxx>-*` pour savoir où elle s'est arrêtée.
4. Reprendre la boucle à l'étape correspondante. **Ne jamais se fier à ses souvenirs** pour dire qu'une tâche est faite : `PROGRESS.md` et les logs font foi.

Pour limiter la perte : après chaque tâche validée, `PROGRESS.md` est à jour et commité ; quand la conversation devient longue, l'orchestrateur lance `/compact` **juste après** un commit.

## 10. Git

- T000 prépare le dépôt (git init si besoin, premier commit, `.gitignore`). Sans dépôt Git, les vérifications du §4 ne sont pas possibles : on s'arrête.
- Une branche par phase : `etape-<N>/<nom>` (par exemple `etape-2/acces`). Un commit par tâche validée : `Txxx : titre`. Commits de correction : `Txxx : correction (…)`.
- Les sous-agents ne commitent pas : l'orchestrateur commite après vérification.
- Jamais de `git push`, `git reset --hard`, `git clean`, `rm -rf` (déjà interdits dans `.claude/settings.json`).
- Étiquette `tranche-Txxx` sur chaque vérification de tranche réussie.

## 11. Mode de travail avec Jeff

- Jeff peut écrire : **« continue »** (enchaîner), **« stop »** (finir la tâche en cours puis s'arrêter), **« où en est-on »** (l'orchestrateur lit `PROGRESS.md` et répond en 5 lignes), **« saute Txxx »**, **« go Vxx »**.
- Les rapports à Jeff sont **courts, en français, sans jargon inutile**.
- Quand Jeff valide une zone 🔒, l'orchestrateur écrit « validé par Jeff le <date> » dans `PROGRESS.md`.
