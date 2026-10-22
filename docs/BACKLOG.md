# NetBuis — Backlog complet, dans l'ordre d'exécution

> **À lire avec** : `docs/ORCHESTRATION.md` (la boucle), `docs/PROGRESS.md` (où on en est), `docs/TASKS_PAR_AGENT.md` (les fichiers à toucher et les méthodes, par numéro `A1.7`, `B2.3`…), `docs/design/README.md` (maquettes), `docs/spec/` (règles métier), `docs/DECISIONS_JEFF.md` (décisions et points ouverts).
>
> **Principe** : ce fichier est la **liste unique** des tâches. Elles sont numérotées `T001…` **dans l'ordre où on les exécute**. On ne passe à `T0xx+1` que lorsque `T0xx` est validée par l'orchestrateur (voir `ORCHESTRATION.md`). Le travail est découpé en **tranches verticales** : pour chaque fonctionnalité, le backend d'abord, puis le mobile (ou le dashboard), puis une **tâche de vérification de tranche** où l'on branche le mobile ou le dashboard sur le vrai backend.
>
> **Hors périmètre (reporté)** : tout le paiement (CamPay, achat de crédits, paiement d'abonnement, paiements sortants), le déploiement, la publication sur le Play Store. L'espace est laissé libre (`payments/`, `CREDITS_ENABLED=False`).
>
> **Facultatif v1.1** : voir la dernière section. **Ne jamais commencer une tâche `V..` sans un « go » écrit de Jeff.**

## Légende des champs

| Champ | Sens |
|---|---|
| **Agent** | Sous-agent responsable (a1, a2, a3, b1, b2, b3, c2, c3). Un seul agent par tâche ; si la tâche touche un autre dossier, l'orchestrateur le coordonne. |
| **Réf.** | Lignes de `docs/TASKS_PAR_AGENT.md` qui donnent les **fichiers** et les **méthodes**. Elles restent la référence pour « où ». |
| **Maquette** | Écran(s) de `docs/design/maquettes/` à reproduire. « — » = pas d'écran. |
| **Dépend de** | Tâches qui doivent être validées avant. |
| **Terminé quand** | Critères **vérifiables**. L'orchestrateur les contrôle un par un. Un critère non vérifié = tâche non terminée. |
| 🔒 | Zone sensible : l'orchestrateur s'arrête après validation technique et attend le feu vert écrit de Jeff (relecture ligne par ligne). |

## Autorisations permanentes (valables pour toutes les tâches, sans les répéter dans chaque brief)

| Qui | Peut aussi écrire | Pourquoi |
|---|---|---|
| tous les agents **mobiles** (b1, b2, b3) | `mobile/assets/l10n/{fr,en}.json` (leurs propres clés) ; `mobile/pubspec.yaml` (ajout d'une dépendance **nécessaire à la tâche**, après avoir lu la version réellement installée) ; leurs tests sous `mobile/test/features/<leurs dossiers>` | textes FR/EN, plugins |
| b2 | `mobile/android/**` (manifeste, Kotlin `CallChannel`, permissions, `<queries>` pour WhatsApp) et `mobile/integration_test/` | appel direct, WhatsApp, tests d'intégration |
| b1 | `mobile/android/app/build.gradle`, `mobile/test/features/{onboarding,account}` | construction, tests de ses dossiers |
| b3 | `mobile/lib/features/account/presentation/` **uniquement** pour ajouter ou modifier une entrée de l'écran Profil liée à sa tâche (T038, T102b, T111) | l'écran Profil appartient à b1 mais évolue avec les fonctions |
| tous les agents **backend** | `docs/api/openapi.yaml` (uniquement les routes de leur tâche) ; `backend/tests/` (tests croisés, fabriques) ; ajout d'un **index** sur leurs propres modèles | contrat et tests |
| orchestrateur seul | `docs/PROGRESS.md`, `docs/DECISIONS_JEFF.md`, `docs/RECETTE.md`, `README.md`, `.github/`, `scripts/` | pilotage |

Toute autre sortie du périmètre exige une autorisation **écrite dans le brief**. Un index à ajouter sur le modèle d'un autre agent est demandé à son propriétaire (ou autorisé dans le brief).

## Règles de tâche écran (mobile) — vraies pour toutes les tâches d'écran

Chaque écran mobile livré respecte déjà : cibles tactiles ≥ 48 dp · champs numériques au clavier numérique · aucun défilement horizontal · icône + mot court pour chaque choix · test de widget à **360 px de large** sans débordement · textes présents en `fr.json` **et** `en.json` · numéro de commerçant jamais affiché · chaque `Terminé quand` de la tâche. (T120 audite l'ensemble à la fin ; elle ne remplace pas ces contrôles.)

## Commandes de vérification (valables pour toutes les tâches)

| Dossier | Commande | Doit donner |
|---|---|---|
| `backend/` | `ruff check . && python manage.py makemigrations --check --dry-run && pytest -q` | 0 erreur, aucune migration manquante, tous les tests verts |
| `mobile/` | `flutter analyze && flutter test` | 0 problème, tous les tests verts |
| `dashboard/` | `npm run typecheck && npm test && npm run build` | 0 erreur, tests verts, build OK |
| contrat | `docs/api/openapi.yaml` valide et à jour pour les routes de la tâche | relu par l'orchestrateur |

Chaque exécution écrit sa sortie dans `logs/<tâche>-<commande>.txt` (voir `ORCHESTRATION.md`).

---

# PHASE 0 — Vérifier le socle et caler le projet

### T000 — Préparer le dépôt Git
- **Agent** orchestrateur · **Dépend de** — (toute première tâche)
- **Terminé quand** : `git rev-parse --show-toplevel` désigne le dossier du projet (sinon `git init`) ; `.gitignore` contient `.env`, `.env.*` (sauf `.env.example`), `logs/`, `.venv/`, `node_modules/`, `build/`, `.dart_tool/` ; `git ls-files` ne contient aucun `.env`, aucune clé ; un premier commit « Socle étape 1 + pilotage » existe ; la branche `etape-1/socle` est créée ; `logs/` existe ; `.claude/agents/` contient les 10 fichiers (sinon les copier depuis `agents/claude-code/`) ; `scripts/verifier_tache.sh` est exécutable.

### T001 — Faire tourner le socle backend (étape 1)
- **Agent** a1 · **Réf.** A1.1–A1.6, A1.13 · **Dépend de** — (première tâche)
- **Livrable** : le backend démarre pour de vrai sur la base PostgreSQL locale `netbuis`.
- **Terminé quand** :
  1. `pip install -r requirements/dev.txt` réussit (versions réellement installées notées dans `logs/T001-pip.txt`).
  2. `python manage.py makemigrations --check --dry-run` ne signale rien. Si la migration écrite à la main `accounts/migrations/0001_initial.py` diffère de ce que Django génère, la remplacer par la version générée.
  3. `python manage.py migrate` réussit ; `python manage.py check` ne signale rien.
  4. `ruff check .` et `pytest -q` sont verts (y compris les tests de `apps/core` et `apps/accounts`).
  5. `GET /api/health/` répond 200 sur `runserver`.
  6. `backend/.env` n'est ni lu ni affiché ni versionné ; `git status` ne le montre pas.
- **Ne pas faire** : ajouter des fonctionnalités ; toucher à `payments/`.

### T002 — Faire tourner le socle dashboard (étape 1)
- **Agent** c3 · **Réf.** C3.1–C3.2 · **Dépend de** T001
- **Terminé quand** : `npm install` réussit ; les versions `latest` de `package.json` sont **remplacées par les versions réellement installées** et `package-lock.json` est présent ; `npm run typecheck && npm test && npm run build` verts ; `npm run dev` affiche la page d'accueil du dashboard en mode simulé (`VITE_USE_MOCKS=true`).

### T003 — Faire tourner le socle mobile (étape 1)
- **Agent** b1 · **Réf.** B1.1–B1.8 · **Dépend de** T001
- **Terminé quand** : `flutter pub get` réussit (versions notées) ; `flutter analyze` = 0 problème ; `flutter test` vert ; `flutter run --dart-define=USE_FAKE_API=true` démarre sur l'émulateur Android (ou, à défaut d'émulateur, `flutter build apk --debug` réussit et le rapport le dit).

### T004 — Caler le mobile sur les maquettes (thème, logo, barre du bas)
- **Agent** b1 · **Réf.** B1.3, B1.4, B1.7 · **Maquette** `Main`, `Carte`, `Forum`, `Profil` · **Dépend de** T003
- **Terminé quand** :
  1. Le thème sombre et le thème clair utilisent **exactement** les jetons de `docs/design/README.md` (y compris, en clair, `#A85A00` pour le texte et les icônes d'accent et `#6B6B70` pour le texte secondaire, décision D-20) (fond `#0D0D0F`/`#F7F7F8`, carte `#1B1B1E`, bordure `#2A2A2E`, accent `#F2942E`, texte sur accent `#1A1200`). Aucune couleur turquoise de l'ancien cahier ne subsiste (`grep -ri "teal\|2EC4B6" mobile/lib` ne trouve rien).
  2. La barre du bas a **4 onglets** dans cet ordre : **Accueil, Carte, Forum, Profil** (icône + mot). Pas d'onglet « Tendances ».
  3. Le logo-texte `NET` + `BUIS` (accent) existe comme widget réutilisable.
  4. Boutons, champs et cartes ont les rayons et la graisse de la maquette `Main`.
  5. Tests de widgets : la barre affiche 4 onglets ; changer d'onglet change l'écran ; le thème clair et le thème sombre se construisent sans erreur.
  6. Une capture ou la description de l'écran Accueil (thème sombre) est jointe au rapport pour comparaison avec `Main`.

### T005 — Appliquer les décisions de départ
- **Agent** a1 + c3 + b1 (sous la conduite de l'orchestrateur, un dossier à la fois) · **Dépend de** T001–T003
- **Lire** : `docs/DECISIONS_JEFF.md` (D-01 refresh token, D-02 fournisseur SMS, D-03 quota d'appels).
- **Terminé quand** : chaque décision **ouverte** de ce fichier est soit tranchée par Jeff (note datée), soit déclarée « défaut retenu » avec la valeur écrite dans `DECISIONS_JEFF.md`. Le code ne change que si la décision l'exige. **Si Jeff n'a pas répondu, l'orchestrateur applique le défaut recommandé et continue** (il ne bloque pas).

---

# PHASE 1 — Accès : compte par numéro de téléphone (Étape 2)

### T005b — Backend : champs de compte pour l'administration et le blocage
- **Agent** a1 · **Réf.** A1.6 (complément) · **Dépend de** T005
- **Contexte** : le modèle `User` de l'étape 1 a un champ `role` (client / merchant / admin) mais ni `is_admin`, ni blocage, ni suppression douce. Ces champs sont supposés par T006–T008, T070 et T072.
- **Terminé quand** :
  1. `User` porte `is_admin` (défaut faux), `is_blocked`, `blocked_reason`, `blocked_at`, `is_deleted`, `deleted_at` ; `role` est **supprimé** (le caractère « commerçant » vient de l'existence d'un `BusinessProfile` actif, et « administrateur » de `is_admin`) ; `is_staff` reste réservé à l'admin Django.
  2. Le gestionnaire `UserManager`, `createsuperuser`, l'admin Django, les fabriques de test et `PersonalDataFilter` sont adaptés ; aucun usage de `role` ne subsiste (`grep -rn "\.role\|Role\." backend` est vide).
  3. Migration propre (`makemigrations --check`), tests des champs par défaut et de `createsuperuser` (qui crée un compte `is_admin=True`, `is_staff=True`, mot de passe défini par l'utilisateur au clavier, jamais en argument).
  4. Un utilisateur `is_blocked` ou `is_deleted` est refusé par une méthode unique `user.can_login()` (utilisée ensuite par T006–T007) ; tests.

### T006 — 🔒 Backend : code SMS (OTP)
- **Agent** a1 · **Réf.** A1.7, A1.8, A1.9 · **Dépend de** T005
- **Livrable** : `POST /api/auth/otp/request/` et `POST /api/auth/otp/verify/`.
- **Terminé quand** :
  1. Seuls les numéros camerounais mobiles `6XXXXXXXX` (avec ou sans `+237`) sont acceptés ; le reste donne 400 avec un message clair en français.
  2. Le code a 6 chiffres, est **stocké haché**, expire en 5 min, est à usage unique, et est limité à 5 essais.
  3. Limites : 3 demandes par numéro / 10 min et 10 par IP / heure (réponse 429 avec `Retry-After`).
  4. Le backend SMS est une interface (`sms/base.py`) ; en dev et en test, `console_backend` affiche le code **sur la console du serveur, uniquement quand `DEBUG=True`** (il refuse de fonctionner sinon) ; `real_provider.py` lit sa clé dans l'environnement et échoue proprement si elle manque.
  5. Aucun code OTP, aucun numéro complet dans les logs applicatifs (le filtre `PersonalDataFilter` les masque).
  6. Tests : succès, code faux, code expiré, code réutilisé, trop d'essais, limite par numéro, limite par IP, numéro invalide.
  7. `docs/api/openapi.yaml` décrit les deux routes et leurs erreurs.

### T006b — 🔒 Backend : durcissement du code SMS (demandé par Jeff le 2026-10-11)
- **Agent** a1 · **Dépend de** T006 · Vérification indépendante obligatoire ; ne pas commencer T007 sans la validation de Jeff.
- **Terminé quand** (un test par point) :
  1. `POST /api/auth/otp/verify/` a une limite par IP ; après 5 mauvais codes, le numéro est bloqué 1 heure (429 avec `Retry-After`).
  2. Le code est haché en HMAC-SHA256 (clé : `SECRET_KEY`, avec le numéro) au lieu de PBKDF2 ; comparaison en temps constant.
  3. La limite par numéro est atomique (verrou) : jamais plus de 3 demandes par 10 min, même en simultané.
  4. `DATABASE_URL` n'a plus de valeur par défaut dans `config/settings/base.py` (erreur claire si absente) ; `.env.example` : `DATABASE_URL=postgres://UTILISATEUR:change-me@localhost:5432/netbuis` ; les valeurs `netbuis:netbuis` du code et des exemples sont supprimées (le mot de passe de la base jetable de `.github/workflows/ci.yml` peut rester). `backend/.env` n'est jamais lu ni modifié.
  5. `OTP_TEST_MODE` est supprimé de `base.py`, `prod.py`, `.env.example`, des tests et de la documentation.
  6. `scripts/verifier_tache.sh`, ruff, `makemigrations --check`, pytest verts.

### T007 — 🔒 Backend : jetons et connexion administrateur
- **Agent** a1 · **Réf.** A1.10 · **Dépend de** T006
- **Terminé quand** :
  1. `verify` renvoie `access` (15 min) et `refresh` (30 jours), crée le compte au premier code valide.
  2. `POST /api/auth/refresh/` fonctionne selon la décision D-01 (cookie HttpOnly pour le dashboard, corps JSON pour le mobile) et refuse un jeton expiré ou invalide.
  3. `POST /api/auth/logout/` invalide le jeton de rafraîchissement.
  4. `POST /api/auth/admin/login/` (téléphone + mot de passe) n'accepte que `is_admin=True` ; limité à 5 essais / 15 min / IP ; message d'erreur identique que le compte existe ou non.
  5. Un compte `is_blocked` ou `is_deleted` ne peut ni vérifier un code, ni rafraîchir, ni se connecter.
  6. Tests pour chaque cas ci-dessus. Aucun jeton dans les logs.

### T008 — Backend : compte, droits et admin Django
- **Agent** a1 · **Réf.** A1.11, A1.12 · **Dépend de** T007
- **Terminé quand** :
  1. `GET /api/me/` renvoie l'identité du compte avec le numéro **masqué** (`+237 6•• •• •• 12`), `has_business`, les compteurs utiles à l'écran Profil (`free_call_available`, `credits_balance` à 0 tant que `CREDITS_ENABLED=False`). `PATCH /api/me/` modifie nom et langue.
  2. Les classes de permission `IsAuthenticatedNotBlocked`, `IsActiveBusinessOwner`, `IsAdminRole` existent et sont testées.
  3. Le premier administrateur se crée avec `python manage.py createsuperuser` (documenté dans `backend/README.md`) ; le mot de passe n'est jamais dans le dépôt.
  4. `pytest -q` vert, couverture des tests de `accounts` listée dans le rapport.
  5. `DELETE /api/me/` : **suppression douce** par l'utilisateur lui-même (`is_deleted`, `deleted_at`, jetons invalidés, profil business masqué) — exigence habituelle des boutiques d'applications ; un compte supprimé qui se reconnecte avec le même numéro reçoit un message « compte supprimé, contactez le support » (défaut D-09) ; tests.
  6. `free_call_available` et `credits_balance` valent `null` tant que `CREDITS_ENABLED=False` (le mobile masque alors ces blocs) ; test.
  7. `IsAdminRole` est **provisoire** (`is_admin`) ; sa version définitive avec groupes est faite en T070.

### T008b — Backend : réglages de plateforme (`PlatformSetting`)
- **Agent** a1 · **Réf.** nouveau (modèle placé dans `apps/core`, à la demande de l'orchestrateur) · **Spéc.** `docs/spec/DASHBOARD_ADMIN.md` § PlatformSetting · **Dépend de** T008
- **Terminé quand** : modèle `PlatformSetting` (clé unique, valeur, modifié par, date) ; service `get_setting(key)` qui lit la valeur, avec **défauts déclarés en un seul endroit** : `plafond_sous_categories_non_abonne=3`, `plafond_publications_non_abonne=5`, `limite_appels_par_minute=5`, `limite_appels_par_jour=50`, `seuil_appels_abonnement=10` (valeur d'essai, D-11) ; mise en cache courte invalidée à l'écriture ; une clé inconnue lève une erreur claire ; visible dans l'admin Django ; tests (défaut, valeur modifiée, cache invalidé, clé inconnue).

### T009 — Mobile : données et état de la connexion
- **Agent** b1 · **Réf.** B1.9, B1.10 · **Dépend de** T008
- **Terminé quand** : dépôt « fake » et dépôt « api » pour OTP, vérification, rafraîchissement et déconnexion ; contrôleur d'état (non connecté / code envoyé / connecté / erreur) ; jetons stockés dans le stockage sécurisé uniquement ; tests unitaires des deux dépôts et du contrôleur.

### T010 — Mobile : Lancement et Découverte
- **Agent** b1 · **Réf.** B1.13 · **Maquette** `Splash`, `Onboarding` · **Dépend de** T009
- **Terminé quand** : l'écran de lancement (logo, slogan « Trouvez un produit ou un service. Appelez directement. Près de chez vous. », bouton **Commencer**, « v1.0 — Maroua, Cameroun ») ; la Découverte en **5 diapositives** avec les textes exacts de la maquette, **Passer** et **Suivant** ; elle ne s'affiche qu'à la première ouverture (mémorisé) ; le texte de la 2ᵉ diapositive est celui de la décision D-07 ; tests de widgets (5 pages, Passer saute, 1ʳᵉ ouverture seulement).
  - La 5ᵉ diapositive (« Faites grandir NetBuis », équipe et parrainage) devient « Créez votre compte business » tant que `TEAM_ENABLED=False` ; les autres textes sont ceux de la maquette.

### T011 — Mobile : écran Connexion (numéro puis code)
- **Agent** b1 · **Réf.** B1.11, B1.12 · **Maquette** `Connexion` · **Dépend de** T010
- **Terminé quand** : champ numéro avec préfixe 🇨🇲 +237, clavier **numérique** ; bouton **Recevoir le code** ; saisie du code en 6 cases numériques (collage depuis SMS accepté) ; **Renvoyer le code** avec compte à rebours ; messages d'erreur courts (numéro invalide, code faux, trop d'essais) en français et en anglais ; la mention des conditions d'utilisation ; redirection vers Accueil quand connecté ; l'écran provisoire « fake-login » de l'étape 1 est supprimé ; tests de widgets et du flux complet en mode fake.

### T011b — Mobile : coquille de l'écran Profil et saisie du nom
- **Agent** b1 · **Réf.** B1.14 · **Maquette** `Profil` (partie haute) · **Dépend de** T011
- **Terminé quand** : après la première connexion, un écran court demande le **prénom/nom** (facultatif mais proposé, clavier de texte, bouton « Passer ») et l'envoie par `PATCH /api/me/` ; l'écran Profil existe avec l'identité (initiales ou photo, nom, numéro **masqué** « numéro vérifié ») et le bouton **Se déconnecter** ; quand le nom manque, l'affichage retombe sur « Utilisateur NetBuis » (jamais sur le numéro) ; chaque tâche suivante qui apporte une fonction (Mes produits, Mes publications, Historique, Modifier ma boutique, Aide, Langue) **ajoute sa propre entrée** dans Profil (autorisation permanente de b3 pour T038, T102b, T111) ; la finition de l'écran est faite en T102 ; tests.

### T011c — Mobile : renouvellement automatique du jeton (ajoutée par l'orchestrateur le 2026-10-17)
- **Agent** b1 · **Réf.** B1.5 (partie « sur 401 renouvelle le jeton une seule fois ») · **Dépend de** T011b · Ajoutée parce que T012 l'exige (« le rafraîchissement automatique fonctionne après expiration forcée du jeton d'accès ») et qu'aucune tâche ne la couvrait ; la rotation du jeton de rafraîchissement décidée en T007 la rend indispensable (jeton d'accès valable 15 min).
- **Terminé quand** (un test par point) :
  1. Sur une réponse 401 d'une route protégée, le client renouvelle le jeton **une seule fois**, enregistre le **nouveau** couple (accès et rafraîchissement, car l'ancien rafraîchissement est invalidé), puis rejoue la requête d'origine une seule fois avec le nouvel accès.
  2. Plusieurs requêtes qui échouent en 401 en même temps ne provoquent **qu'un seul** appel de renouvellement (les autres attendent son résultat), puis sont toutes rejouées.
  3. Aucune boucle : une requête déjà rejouée qui reçoit encore 401 n'est pas renouvelée à nouveau ; les routes `/auth/otp/request/`, `/auth/otp/verify/`, `/auth/refresh/`, `/auth/logout/` ne déclenchent jamais de renouvellement.
  4. Renouvellement refusé (`token_invalid`, `account_blocked`, `account_deleted`) : les jetons sont effacés, l'état de connexion devient « non connecté » (ou erreur compte bloqué/supprimé) et la garde renvoie vers `/login`. Réseau coupé pendant le renouvellement : la session est **conservée**, l'erreur réseau remonte, aucune déconnexion.
  5. Aucun jeton dans les journaux ni dans les messages d'erreur ; tests unitaires avec un faux adaptateur Dio (cas qui réussit **et** cas qui échoue pour chaque point).

### T012 — Vérification de tranche : connexion de bout en bout
- **Agent** orchestrateur (aucun nouvel agent) · **Dépend de** T011
- **Terminé quand** : le backend tourne en local, le mobile tourne avec `USE_FAKE_API=false` et `API_URL` pointant sur lui ; un numéro de test reçoit un code (lu dans la console du serveur en dev), la connexion réussit, `/api/me/` répond, la déconnexion fonctionne, le rafraîchissement automatique fonctionne après expiration forcée du jeton d'accès. Le résultat est écrit dans `logs/T012-tranche.md`. **Jeff relit** la zone 🔒 OTP/jetons avant T020.

---

# PHASE 2 — Référentiels : lieux et catalogues (Étape 3)

### T020 — Backend : zones (Pays → Quartier)
- **Agent** a2 · **Réf.** A2.1, A2.2, A2.3 · **Dépend de** T012
- **Spéc.** `docs/spec/MODELE_DONNEES.md` § Zone.
- **Terminé quand** :
  1. Modèle `Zone` : nom, niveau (`pays`, `region`, `departement`, `arrondissement`, `ville_village`, `quartier`, `repere`), parent, code officiel facultatif, `is_active`, ordre, nom normalisé (sans accents, minuscule) ; le parent est toujours d'un niveau **strictement supérieur** (une `ville_village` a pour parent un arrondissement **ou** un département — Maroua s'étend sur 3 arrondissements et est rattachée au département Diamaré ; un `quartier` a pour parent une `ville_village`) ; validation + tests des deux cas valides et d'un cas refusé ; `latitude` et `longitude` **facultatives** (pour les positions indicatives de l'écran Carte).
  2. `load_zones` charge un fichier CSV (`geo/data/zones.csv`) de façon **idempotente** (relancer ne crée pas de doublon).
  3. Routes publiques : `GET /api/zones/?parent=<id>&level=<niveau>` (liste), `GET /api/zones/<id>/` (avec le chemin des parents).
  4. Les zones sont modifiables par l'admin Django (le référentiel n'est **pas** figé dans le code).
  5. Tests : hiérarchie valide/invalide, idempotence du chargement, filtres de l'API.
  6. Le fichier de départ contient au moins : Cameroun → les 10 régions → pour la région de l'Extrême-Nord, le département Diamaré, l'arrondissement Maroua 1/2/3, la ville Maroua et ses quartiers Hardé, Dougoï, Domayo, Djarengol (les noms vus dans les maquettes). **Les autres lignes ne sont pas inventées** : le rapport liste ce qui reste à fournir par Jeff (voir « Données à fournir »).

### T021 — Backend : secteurs, sous-catégories, catégories de service, types de structure, catalogue de produits
- **Agent** a2 · **Réf.** A2.4, A2.5, A2.6 · **Dépend de** T020
- **Spéc.** `docs/spec/MODELE_DONNEES.md` § Secteur, SousCategorie, CategorieService, TypeStructure.
- **Terminé quand** :
  1. Modèles `Secteur` (10 secteurs de la spec, avec icône), `SousCategorie` (rattachée à un secteur), `CategorieService` (7 valeurs), `TypeStructure` (5 valeurs), `CatalogProduct` (produit du catalogue de recherche : nom, nom normalisé, catégorie) et `Synonym`.
  2. `seed_referentials` crée les 10 secteurs, les 7 catégories de service, les 5 types de structure et les sous-catégories **listées dans la spec** (Alimentation, Boutique/Supérette, Transport & Livraison, Artisanat & Services à domicile ; les autres secteurs reçoivent au minimum « Autre » et les sous-catégories sont **marquées « à compléter »** dans le rapport, pas inventées). Idempotent.
  3. Routes publiques : `GET /api/referentials/sectors/` (avec sous-catégories), `/service-categories/`, `/structure-types/`, `/catalog/products/?q=`.
  4. Tous modifiables par l'admin Django.
  5. Tests d'idempotence et de chaque route.

### T022 — Mobile : référentiels et choix de la ville
- **Agent** b1 · **Réf.** B1.13, B1.14 · **Dépend de** T021
- **Autorisation exceptionnelle** : b1 écrit aussi dans `mobile/lib/core/data/` (dépôts de zones et de référentiels partagés par b2 et b3).
- **Terminé quand** : dépôts fake/api pour zones et référentiels ; écran « Choisir ma ville » (grille icône + mot, sans défilement horizontal) ; la ville choisie est mémorisée et modifiable depuis Profil ; tests.

### T023 — Vérification de tranche : référentiels
- **Agent** orchestrateur · **Dépend de** T022
- **Terminé quand** : le mobile affiche les vraies villes et secteurs du backend ; résultat dans `logs/T023-tranche.md`.

---

# PHASE 3 — Compte business : création et fiche (Étape 3)

### T025 — Backend : modèles du compte business
- **Agent** a2 · **Réf.** A2.7, A2.8 · **Dépend de** T023
- **Spéc.** `docs/spec/MODELE_DONNEES.md` § BusinessProfile et les cinq types.
- **Terminé quand** :
  1. `BusinessProfile` avec tous les champs de la spec : `type_compte` (`boutique`, `entreprise`, `particulier_vendeur`, `prestataire_service`, `structure`), nom affiché, zone (niveau `ville_village` ou `quartier` exigé), description, photo, nom et photo du représentant, numéro ancré, `status` (`en_attente_validation`, `actif`, `rejete`), `forme_juridique` + `rccm` (entreprise), `categorie_service` (+ libre) + `cni_photo` + `cni_verifiee` + `diplome_photo` (prestataire), `structure_type` (+ libre) + détails propres à chaque type de structure, `secteur` (+ libre) + sous-catégories + `description_activite`, `motif_rejet`.
  2. Contraintes en base ou en validation : un compte a **au plus un** profil ; les champs d'un type n'existent pas pour les autres (ex. `forme_juridique` interdit hors entreprise) ; secteur interdit pour prestataire et structure.
  3. Le numéro ancré est un champ **jamais exposé** par aucun sérialiseur public (test qui le garantit en parcourant tous les sérialiseurs).
  4. `cni_photo` n'est jamais exposé par un sérialiseur destiné à l'app (test).
  5. Migrations propres (`makemigrations --check`).
  6. Champs en plus, demandés par les maquettes : `repere` (texte court, ex. « À côté du Grand Manguier » — champ de l'écran `Infos`), `whatsapp_available` (booléen, défaut vrai), `calls_count` et `views_count` (entiers, alimentés par T047b et T050).
  7. Détails de structure, **un champ par ligne de la spec** : supermarché → `rayons` (≤ 3 sans abonnement) ; restaurant → `cuisine`, `livraison` (booléen), `horaires` ; hôtel → `standing`, `nombre_chambres`, `equipements` (liste) ; santé → `numero_agrement`, `specialites` (≤ 3 sans abonnement) ; `structure_type_libre` quand le type est « Autre » ; un test par type vérifie que les champs d'un autre type sont refusés.

### T025b — Backend : abonnement (modèle et service `is_subscribed`)
- **Agent** a2 · **Réf.** nouveau · **Spéc.** `docs/spec/DASHBOARD_ADMIN.md` § abonnement · **Dépend de** T025
- **Terminé quand** : modèle `Subscription` (profil, début, fin, statut `actif`/`expiré`, source `manuel`) ; **un seul service** `business.services.subscription.is_subscribed(profile)` (vrai si un abonnement `actif` non échu existe) utilisé partout ensuite (plafonds, tri de la recherche, forum) ; tests (aucun abonnement, actif, échu, expiré) ; aucun mécanisme de paiement.

### T026 — Backend : API de création et de modification du compte business
- **Agent** a2 · **Réf.** A2.9, A2.11 · **Dépend de** T025
- **Terminé quand** :
  1. `POST /api/business/` crée un profil en `en_attente_validation` ; `GET/PATCH /api/business/me/` lit et modifie le sien ; un compte simple n'a accès à rien d'autre.
  2. Validation côté serveur **par type** : champs obligatoires selon la spec (ex. prestataire : catégorie de service + CNI obligatoires ; entreprise : forme juridique obligatoire ; structure : type obligatoire).
  3. Plafond de **3 sous-catégories** sans abonnement actif (`is_subscribed` de T025b ; valeur lue via `get_setting`, défaut 3) ; la 4ᵉ est refusée avec le code d'erreur `SUBSCRIPTION_REQUIRED`. Même plafond de 3 pour les rayons (supermarché) et les spécialités (centre de santé).
  4. Règle D-08 : modifier la description ou les photos d'un profil `actif` ne demande pas de nouvelle validation ; modifier le nom, le type, la zone ou le numéro le remet en `en_attente_validation` (et il disparaît de la recherche et de la carte jusqu'à validation) ; test des deux cas.
  5. Tests : un cas valide par type, un cas invalide par type, plafond de 3, zone trop haute (région seule refusée).
  6. Un profil `rejete` peut être **corrigé et renvoyé** : `PATCH /api/business/me/` sur un profil rejeté le repasse en `en_attente_validation` et efface `motif_rejet` ; test.
  7. Le profil de l'utilisateur qui a supprimé son compte est masqué partout (recherche, carte, fiche).

### T027 — 🔒 Backend : envoi des photos et pièces d'identité
- **Agent** a2 · **Réf.** A2.12 · **Dépend de** T026
- **Terminé quand** : mécanisme d'envoi par URL signée (ou envoi direct vers un stockage local en dev, interface `StorageService` prête pour un stockage compatible S3) ; types et tailles contrôlés (images JPEG/PNG/WebP, 5 Mo max, vidéo 30 Mo max pour les publications) ; les pièces `cni_photo` et `diplome_photo` sont dans un espace **privé** (aucune URL publique) ; tests des refus (mauvais type, trop gros).

### T028 — Backend : données de démonstration
- **Agent** a2 · **Réf.** A2.16, A2.17 · **Dépend de** T027
- **Terminé quand** : `seed_demo` crée ≥ 20 commerces **fictifs** (noms visiblement fictifs, numéros `6 00 00 00 XX` réservés au test) répartis sur ≥ 3 quartiers de Maroua, avec les 5 types de compte et des statuts variés ; relançable sans doublon ; **désactivé si `DEBUG=False`** ; tests.
  5. Option `--count N` (défaut 20, maximum 5 000) pour les mesures de performance (T040, T122). Chaque tâche qui ajoute des données visibles étend `seed_demo` : offres (T037), publications et commentaires (T090), abonnements (T110).

### T030 — Mobile : création du compte business, étapes 1 et forme juridique
- **Agent** b3 · **Réf.** B3.1 · **Maquette** `CreationBusiness-Infos`, `CreationBusiness-Entreprise-Forme` · **Dépend de** T028
- **Terminé quand** : accès depuis Profil (la bannière de l'Accueil s'y ajoute en T044) ; 5 boutons de type (icône + mot, sur deux rangées) ; libellés « nom » et « propriétaire/responsable » qui changent selon le type (voir spec) ; bouton **🔊 Écouter** sur l'encart explicatif (lecture vocale réelle par synthèse du téléphone, repli silencieux si indisponible) ; écran Forme juridique avec la liste de la spec et RCCM facultatif, affiché **seulement** pour Entreprise ; barre « Étape X sur Y » ; état conservé si l'utilisateur revient en arrière ; tests de widgets du branchement par type.
  - Le champ « Ville / Quartier » de l'écran `Infos` est un simple résumé qui ouvre l'écran de choix du lieu fait en T034 ; avant T034, il affiche la ville choisie en T022.

### T031 — Mobile : secteur et détails d'activité
- **Agent** b3 · **Réf.** B3.1 · **Maquette** `CreationBusiness-Secteur`, `CreationBusiness-Details` · **Dépend de** T030
- **Terminé quand** : grille de 10 secteurs (icône + mot) alimentée par l'API ; écran Détails avec sous-catégories du secteur choisi, compteur « X/3 inclus sans abonnement », 4ᵉ sélection bloquée avec l'encart « Limite atteinte » et boutons « Souscrire à un abonnement » (désactivé tant que les paiements ne sont pas faits, il affiche « bientôt ») et « Plus tard » ; cas « Autre » avec nom libre et description ; conseils textuels de la maquette ; tests (plafond, Autre).

### T032 — Mobile : prestataire de service
- **Agent** b3 · **Réf.** B3.1, B3.2 · **Maquette** `CreationBusiness-Prestataire-Categorie` · **Dépend de** T031
- **Terminé quand** : grille de 7 catégories de service ; CNI obligatoire (photo prise ou choisie) avec mention qu'elle ne sera jamais affichée ; diplôme facultatif ; l'écran enchaîne vers le Récapitulatif (pas d'écran Secteur) ; tests.

### T033 — Mobile : structure (supermarché, restaurant, hôtel, centre de santé)
- **Agent** b3 · **Réf.** B3.1 · **Maquette** `CreationBusiness-Structure-Type`, `CreationBusiness-Structure-Details` · **Dépend de** T032
- **Terminé quand** : grille des 5 types avec l'encart commercial/social ; écran de détails dont les champs changent selon le type (rayons ≤ 3 ; cuisine + livraison + horaires ; standing + chambres + équipements ; agrément + spécialités ≤ 3) ; description libre avec exemple propre au type ; tests pour chacun des 4 types.

### T034 — Mobile : choix précis du lieu (ville/village puis quartier) — écran sans maquette
- **Agent** b3 · **Réf.** B3.1 · **Dépend de** T033 (champ « Ville / Quartier » de l'écran `Infos`, utilisé par les cinq parcours)
- **Terminé quand** : le parcours impose de descendre jusqu'à `ville_village` (et `quartier` s'il en existe) ; la région ou le département seuls sont refusés avec un message clair ; réutilise le composant de T022 ; le choix du lieu est repris dans le récapitulatif ; écran décrit dans le rapport (puisqu'il n'a pas de maquette) ; tests.

### T035 — Mobile : récapitulatif et envoi
- **Agent** b3 · **Réf.** B3.1, B3.2 · **Maquette** `CreationBusiness-Recap` · **Dépend de** T034
- **Terminé quand** : récapitulatif commun aux cinq parcours (numéro **masqué** avec ✓) ; envoi des photos puis du profil ; écran « Demande envoyée — sous 24 heures » ; l'état « en attente » s'affiche ensuite dans Profil ; gestion d'erreur réseau (rien n'est perdu, on peut réessayer) ; tests.
  - Texte du récapitulatif : « Vous recevrez une notification » est remplacé par « Vous pourrez suivre l'état de votre demande dans Profil » (les notifications sont reportées, V03).

### T036 — Vérification de tranche : créer un commerce de bout en bout
- **Agent** orchestrateur · **Dépend de** T035
- **Terminé quand** : pour **chacun des 5 types**, un compte de test crée sa demande depuis le mobile contre le vrai backend ; la ligne existe en base avec `en_attente_validation` ; les règles de plafond sont refusées par le serveur même si le mobile est contourné (appel direct à l'API) ; résultat dans `logs/T036-tranche.md`.

---

# PHASE 4 — Espace commerçant : produits et offres

### T037 — Backend : offres du commerçant
- **Agent** a2 · **Réf.** A2.8, A2.11 · **Dépend de** T036
- **Spéc.** `Product` du modèle de données (produit du commerçant : nom, description, photos, prix, compteurs).
- **Terminé quand** : modèle `Offer` (nom, description, prix en FCFA entier ≥ 0 ou « sur demande », photos ≤ 4, lien facultatif vers un `CatalogProduct`, actif/inactif) ; `GET/POST /api/business/me/offers/`, `PATCH/DELETE …/<id>/` réservés au propriétaire d'un profil **actif** ; un commerçant ne voit et ne modifie jamais les offres d'un autre (test) ; aucun compteur sur l'offre (les compteurs de vues et d'appels sont sur le profil, voir T025) ; tests.

### T038 — Mobile : « Mes produits »
- **Agent** b3 · **Réf.** B3.3 · **Maquette** `Profil` (bloc COMPTE BUSINESS) · **Dépend de** T037
- **Terminé quand** : liste de mes produits (compteur affiché dans Profil), ajout et modification avec photo, prix saisi au clavier numérique, suppression avec confirmation ; accessible seulement si le compte business est actif (sinon message « en attente de validation ») ; tests.

---

# PHASE 5 — Recherche et écran d'Accueil (Étape 4, chemin critique)

### T040 — Backend : moteur de recherche
- **Agent** a3 · **Réf.** A3.1, A3.2 · **Dépend de** T038
- **Terminé quand** :
  1. La recherche d'un mot (« riz », « plombier », « pharmacie ») renvoie les comptes business **actifs et non bloqués** dont une offre, une sous-catégorie, un produit du catalogue, un secteur ou une catégorie de service correspond ; recherche **tolérante** : sans accents, majuscules ignorées, fautes légères (trigrammes PostgreSQL `pg_trgm`), synonymes.
  2. **Ordre** : abonnés actifs d'abord, puis pertinence, puis proximité de la ville choisie ; les non-abonnés restent toujours listés.
  3. Filtres : ville/zone, secteur.
  4. Les comptes `rejete`, `en_attente_validation`, bloqués ou supprimés n'apparaissent **jamais** (test).
  5. Chaque recherche est journalisée (`SearchLog` : terme normalisé, zone, nombre de résultats, compte anonymisé ou nul).
  6. Tests de classement avec ≥ 15 cas, dont fautes de frappe, synonymes et abonné vs non-abonné ; une mesure de temps sur 1 000 commerces fictifs est notée (cible < 300 ms, sinon index à ajouter).
  7. `SearchLog` stocke un **hachage** du compte (jamais le compte ni le numéro) pour pouvoir compter des comptes distincts (T104). Un terme vide n'est pas journalisé.
  8. Les index nécessaires sur `catalog` et `business` sont demandés à a2 par l'orchestrateur (autorisation écrite) ; mesure sur `seed_demo --count 1000` notée.

### T041 — Backend : route de recherche, suggestions, recherche vocale
- **Agent** a3 · **Réf.** A3.3, A3.4, A3.5, A3.6 · **Dépend de** T040
- **Terminé quand** :
  1. `GET /api/search/?q=&zone=&sector=&page=` : chaque résultat contient nom, `kind` (« produit » ou « service » selon le type de compte), secteur, zone, `repere`, `description_activite` (sous-titre), photo, prix indicatif, badge ✓ vérifié — **pas de badge « abonné » public** (point ouvert du Projet) — **mais jamais le numéro de téléphone** (test qui parcourt la réponse JSON).
  2. `GET /api/search/suggestions/?q=` : ≤ 8 suggestions (produits du catalogue + termes fréquents).
  3. `POST /api/search/voice/` accepte un texte transcrit et le nettoie (retire « je cherche », « je veux », etc.) avant de lancer la recherche ; les cas courants en français sont testés.
  4. Pagination, 20 par page.
  5. `openapi.yaml` à jour.
  6. `q` vide est autorisé : la route renvoie alors les commerces actifs de la zone choisie (abonnés d'abord) ; c'est ce que montre l'Accueil avant toute recherche.

### T043 — Mobile : données et état de la recherche
- **Agent** b2 · **Réf.** B2.2, B2.3 · **Dépend de** T041
- **Terminé quand** : dépôts fake et api ; contrôleur avec anti-rebond (400 ms), états chargement / vide / erreur / résultats ; pagination infinie ; tests unitaires.

### T044 — Mobile : écran d'Accueil
- **Agent** b2 · **Réf.** B2.1 · **Maquette** `Main` · **Dépend de** T043
- **Terminé quand** : en-tête avec logo ; barre de recherche + bouton micro séparé ; puces de catégories **qui passent à la ligne** (aucun défilement horizontal), chacune avec icône ; zone des résultats ; encart « Aidez NetBuis à grandir » (le bouton « Inviter » ouvre les trois feuilles de la maquette : Devenir parrain — **masqué tant que `TEAM_ENABLED=False`**, Créer mon compte business, Partager NetBuis — qui ouvre le partage Android) ; barre du bas ; thème clair et sombre ; tests de widgets.
  - Décisions écrites (D-19) : avant toute recherche, l'Accueil affiche les commerces de la ville choisie (route de recherche avec `q` vide) ; les puces viennent de `/api/referentials/sectors/` (« Tous » puis les secteurs ; 4 visibles qui passent à la ligne, un bouton **plus** ouvre la grille des 10) ; **aucun écran de promotion plein écran après une recherche** (intrusif pour des utilisateurs peu lecteurs) : seule la bannière « Aidez NetBuis à grandir » est gardée ; le bouton d'appel affiche **« Appeler »** sans prix tant que `CREDITS_ENABLED=False`.

### T045 — Mobile : recherche écrite et résultats
- **Agent** b2 · **Réf.** B2.4, B2.6 · **Maquette** `Main` · **Dépend de** T044
- **Terminé quand** : suggestions pendant la frappe ; liste de résultats avec le format de carte de la maquette (titre, sous-titre, badge, lieu, bouton **Appeler**) ; filtre par zone et par secteur dans une feuille ; message « Aucun résultat » avec proposition utile (essayer un mot plus court, changer de ville) ; abonnés placés en premier, sans aucune étiquette publique ; tests.

### T046 — Mobile : recherche vocale
- **Agent** b2 · **Réf.** B2.5 · **Maquette** `Main` (bandeau « Je vous écoute… ») · **Dépend de** T045
- **Terminé quand** : permission micro demandée avec explication ; reconnaissance vocale en français (service Android) ; bandeau d'écoute de la maquette ; le texte reconnu lance la recherche ; si la reconnaissance échoue ou est refusée, message simple et retour à la recherche écrite ; testé avec un faux service de reconnaissance (tests unitaires) ; un test manuel sur appareil est inscrit dans la liste de Jeff.

### T047b — Backend : fiche publique
- **Agent** a2 · **Réf.** A2.10 · **Dépend de** T041. Elle s'exécute **avant** T047.
- **Terminé quand** : `GET /api/business/<id>/` renvoie la fiche d'un profil `actif` (404 sinon) sans numéro, sans CNI, avec le badge « ✓ Identité vérifiée » si `cni_verifiee` ; le compteur `views_count` du profil est incrémenté sans doublons massifs (limite par compte et par jour) ; tests.
  - La fiche expose les mêmes champs publics que ceux listés pour T047 (par type de compte), et `whatsapp_available`.

### T047 — Mobile : fiche publique du commerçant
- **Agent** b2 · **Réf.** B2.7 · **Maquette** (aucune fiche dédiée : réutiliser les éléments de `Main`/`Quartier`) · **Dépend de** T047b (route `GET /api/business/<id>/`)
- **Terminé quand** : nom, type, photos, description, produits, zone, badges ; **aucun numéro** ; boutons Appeler et WhatsApp **présents mais désactivés avec la mention « bientôt »** (T052 branche Appeler, T054 branche WhatsApp ; leurs critères le vérifient) ; écran non maquetté signalé dans le rapport.
  - La fiche affiche tous les champs publics du type de compte : forme juridique (entreprise), diplôme (prestataire, si fourni), détails de structure (cuisine, horaires, livraison, standing, chambres, équipements, rayons, spécialités, selon le type), description d'activité, repère, produits ; jamais CNI, numéro, `motif_rejet`.
  - Bouton **« Signaler ce commerce »** (voir T093).

### T048 — Vérification de tranche : trouver un commerçant
- **Agent** orchestrateur · **Dépend de** T047
- **Terminé quand** : sur le vrai backend avec `seed_demo`, une recherche écrite et une recherche vocale simulée affichent des résultats ; la fiche s'ouvre ; aucune réponse réseau enregistrée ne contient de numéro (vérification automatique dans `logs/T048-tranche.md`).

---

# PHASE 6 — Appeler et écrire sur WhatsApp (Étape 4, zone la plus sensible)

### T050 — 🔒 Backend : lancer un appel
- **Agent** a3 · **Réf.** A3.7, A3.8 · **Dépend de** T048
- **Spéc.** `docs/spec/APPELS.md`.
- **Terminé quand** :
  1. `POST /api/calls/initiate/` avec `business_id`, `channel` (`call`), `platform` (`android`/`ios`), `operator` (`orange`/`mtn`/absent).
  2. Refus avec un code d'erreur **de cette liste fermée** (décrite dans `openapi.yaml`) : `NOT_AUTHENTICATED`, `ACCOUNT_BLOCKED` (compte de l'appelant ou du commerce bloqué), `BUSINESS_NOT_ACTIVE`, `OWN_BUSINESS`, `RATE_LIMITED`, `CHANNEL_UNAVAILABLE` (WhatsApp désactivé pour ce commerce).
  3. **Un compte simple ne peut appeler qu'un compte business** (jamais un autre compte simple) — test.
  4. Limite anti-aspiration : par compte, N appels / minute et M / jour (valeurs dans `PlatformSetting`, défauts 5 et 50, voir D-05) ; dépassement = 429.
  5. Quota : tant que `CREDITS_ENABLED=False` aucun quota d'appels n'est appliqué (voir D-03) ; le code du quota existe derrière l'interrupteur et est testé avec l'interrupteur à `True`.
  6. Crée un `CallLog` (appelant, profil, date, plateforme, opérateur, type) **avant** de répondre.
  7. Renvoie le numéro **uniquement** dans cette réponse ; ce numéro n'apparaît dans aucun log, aucun message d'erreur, aucune trace de test affichée.
  8. Tests : tous les refus, succès, limite par minute, limite par jour, numéro absent des journaux (capture des logs pendant le test).
  9. `CallLog` distingue `channel` (`call` / `whatsapp`) de `billing_type` (`free` / `credit` / `none`). Règles : les deux canaux comptent pour la limite anti-aspiration (les deux délivrent le numéro) et pour les tendances ; **seuls les appels** comptent pour le quota (si crédits activés) et pour le seuil d'abonnement. Le compteur `calls_count` du profil est incrémenté.

### T051 — Backend : WhatsApp, retour d'appel, historique
- **Agent** a3 · **Réf.** A3.9, A3.10, A3.11 · **Dépend de** T050
- **Terminé quand** : `channel=whatsapp` renvoie un lien `https://wa.me/237…` construit côté serveur avec un message pré-rempli et mêmes contrôles que l'appel (même journal, type `whatsapp`) ; `POST /api/calls/<id>/feedback/` (appel abouti / pas de réponse / mauvais numéro) ; `POST /api/calls/whatsapp-report/` (« ce numéro n'a pas WhatsApp ») ; `GET /api/calls/history/` renvoie **mes** appels (nom du commerce, zone, date, type) sans numéro ; test de bout en bout `tests/e2e/test_flow_search_call.py` (recherche → fiche → appel → historique) ; tests listés.
  - Un commerce signalé « pas de WhatsApp » par ≥ 3 comptes distincts passe `whatsapp_available=false` (revue possible par un admin) ; test.

### T052 — 🔒 Mobile : bouton Appeler, feuille Orange / MTN, appel direct Android
- **Agent** b2 · **Réf.** B2.8, B2.11 (promue obligatoire) · **Maquette** `Main`, `Quartier` (feuille « Avec quelle ligne voulez-vous appeler ? ») · **Dépend de** T051
- **Terminé quand** :
  1. Clic sur **Appeler** → feuille avec deux gros boutons **Orange** et **MTN** (icône + mot) et **Annuler** ; le nom du commerce est visible, **le numéro ne l'est jamais**.
  2. Le choix de la ligne **est** la confirmation : appel immédiat ; `POST /calls/initiate/` est appelé à ce moment ; le numéro reçu est passé au code natif sans être affiché ni journalisé.
  3. Module Kotlin `CallChannel` (MethodChannel) : `TelecomManager.placeCall` avec le compte téléphonique correspondant à la ligne choisie ; permissions `CALL_PHONE` (demandée une fois, avec explication) et `READ_PHONE_STATE`.
  4. Cas : téléphone à une SIM → la feuille est sautée ; ligne choisie absente → message simple qui propose l'autre ligne ; SIM renommée / eSIM / détection impossible → repli qui affiche les noms de SIM donnés par le système ; permission refusée → repli `ACTION_DIAL` (numéro visible, avec un avertissement clair).
  5. Écran « Appel en cours… [nom] · ligne [opérateur] » puis fermeture.
  6. Protection contre le double clic.
  7. Tests Dart avec un faux `CallChannel` pour chaque cas ; le code Kotlin est relu par l'orchestrateur et la liste des tests manuels sur appareil réel est écrite dans `logs/T052-tests-manuels.md` pour Jeff.
  8. **Android seulement en v1** (le projet est généré avec `--platforms=android`). La variante iOS est reportée (V07) ; le texte honnête de D-07 est quand même affiché.
  9. La ligne est **redemandée à chaque appel** (décision D-22, on ne mémorise pas) ; le bouton Appeler de la fiche publique (T047) est activé par cette tâche, avec test.

### T053 — Mobile : historique des appels
- **Agent** b2 · **Réf.** B2.8 · **Maquette** `Historique` · **Dépend de** T052
- **Terminé quand** : liste (nom, zone, date, badge de type : appel / WhatsApp) tirée de `/calls/history/` ; état vide soigné ; bouton pour rappeler (repasse par la feuille) ; tests.

### T054 — Mobile : WhatsApp et retour d'appel
- **Agent** b2 · **Réf.** B2.9 · **Dépend de** T053
- **Terminé quand** : bouton **WhatsApp** sur les cartes et la fiche ; ouvre `wa.me` ; si WhatsApp est absent du téléphone, message simple et possibilité de signaler « pas de WhatsApp » ; après un appel, une petite feuille facultative demande si ça a abouti (3 gros boutons avec icône) ; tests.

### T055 — Mobile : dernier résultat hors connexion
- **Agent** b2 · **Réf.** B2.10 · **Dépend de** T054
- **Terminé quand** : la dernière recherche réussie est mémorisée et affichée avec la mention « hors connexion » quand le réseau manque ; les appels et WhatsApp sont désactivés hors connexion avec un message clair ; tests.

### T056 — Tests du bloc recherche et appel
- **Agent** b2 · **Réf.** B2.13 · **Dépend de** T055
- **Terminé quand** : tests d'intégration `integration_test` du parcours Accueil → recherche → fiche → appel (faux canal) ; `flutter analyze` et `flutter test` verts.

### T057 — Vérification de tranche CRITIQUE : de la recherche à l'appel
- **Agent** orchestrateur · **Dépend de** T056
- **Terminé quand** : sur le vrai backend, parcours complet avec un compte de test ; le journal d'appels côté base a bien les lignes attendues avec plateforme et opérateur ; aucun numéro dans les logs ni dans le trafic enregistré hors de `/calls/initiate/` ; **liste de tests manuels sur téléphone réel prête pour Jeff** (appel Orange, appel MTN, une seule SIM, permission refusée, WhatsApp absent). **Jeff relit 🔒 appel et valide avant T060.**

---

# PHASE 7 — Explorer par quartier (Étape 4)

### T060 — Backend : carte par zones
- **Agent** a2 · **Réf.** A2.3, A2.15 (partie sans GPS) · **Dépend de** T057
- **Terminé quand** : `GET /api/map/cities/` renvoie **seulement** les `ville_village` ayant ≥ 1 profil `actif` (directement ou par un quartier enfant), avec le nombre de commerces, la région, et la hiérarchie supérieure (Région/Département) marquée « explorable » seulement si elle contient une ville active ; `GET /api/map/cities/<id>/areas/` renvoie les quartiers avec nombre de commerces et de produits référencés ; `GET /api/map/areas/<id>/businesses/` renvoie la liste des commerces de ce quartier (même format que la recherche, **sans numéro**) ; un profil rattaché seulement à une région ne figure **jamais** ; la recherche textuelle reste indépendante de cette règle (test des deux) ; tests.
  - Les villes renvoient `latitude` et `longitude` si elles existent ; `GET /api/map/cities/?q=` filtre par nom (utilisé par la recherche du mode Liste).

### T061 — Mobile : écran Carte
- **Agent** b2 · **Réf.** B2.12 (sans GPS) · **Maquette** `Carte` · **Dépend de** T060
- **Terminé quand** : titre « Explorer », libellé de la ville courante, bascule **Carte / Liste** ; mode Carte : positions indicatives des villes/villages actifs (légende « pas encore géolocalisées ») ; mode Liste : villes avec région et nombre de commerces ; sous une ville : quartiers avec compteurs, ou l'encart « Pas encore de détail par quartier » ; champ de recherche ; **aucune ville sans commerce n'apparaît** ; tests.
  - Positions indicatives : coordonnées de la ville si elles existent, sinon placement schématique en grille (même rendu que la maquette) ; aucune carte tierce n'est chargée en v1.

### T062 — Mobile : détail d'un quartier
- **Agent** b2 · **Maquette** `Quartier` · **Dépend de** T061
- **Terminé quand** : liste des commerces du quartier avec Appeler (même feuille Orange/MTN que T052) ; fil d'Ariane « Cameroun · Maroua » ; tests.

### T063 — Vérification de tranche : carte
- **Agent** orchestrateur · **Dépend de** T062
- **Terminé quand** : avec `seed_demo`, une ville sans commerce actif n'apparaît pas et un commerce validé en fait apparaître une ; `logs/T063-tranche.md`.

---

# PHASE 8 — Administration : API puis dashboard (Étape 5)

> Le dashboard est **hors des principes d'accessibilité** (outil interne). Mais il suit les jetons visuels (accent orange, sombre par défaut) et la structure des trois maquettes `Dashboard-*`.

### T070 — 🔒 Backend : droits d'administration et journal d'audit
- **Agent** c2 · **Réf.** C2.1, C2.2 · **Spéc.** `docs/spec/DASHBOARD_ADMIN.md` · **Dépend de** T063
- **Terminé quand** :
  1. Deux groupes : **Validateur** et **Administrateur complet**, créés par migration de données, avec les permissions de la spec (`peut_valider_demande`, `peut_bloquer_compte`, `peut_modifier_reglages`, `peut_gerer_admins`…).
  2. Accès au dashboard = `is_admin=True` **et** appartenance à un groupe ; sans cela 403 partout sous `/api/admin/`.
  3. `AuditLog` (admin, type d'action, cible, motif, date) ; un service unique l'écrit ; **un rejet, un blocage ou une suppression sans motif est refusé** (test).
  4. `GET /api/admin/me/` renvoie l'identité de l'admin et ses permissions (utile au dashboard pour masquer les actions interdites).
  5. Tests : matrice rôle × action (Validateur ne peut ni bloquer, ni supprimer, ni changer les réglages ; Administrateur complet peut tout).
  6. Test de bout en bout : un compte créé par `createsuperuser` puis placé dans le groupe « Administrateur complet » peut se connecter par `/api/auth/admin/login/` et appeler `/api/admin/me/` ; sans groupe il reçoit 403.

### T071 — 🔒 Backend : demandes de compte business (validation)
- **Agent** c2 + a2 · **Réf.** C2.4, A2.13 · **Dépend de** T070
- **Terminé quand** : `GET /api/admin/requests/?type=business` (file d'attente, avec les pièces : photos, et pour un prestataire CNI et diplôme via **URL temporaire signée** réservée à l'admin) ; `POST …/<id>/approve/` passe le profil à `actif` (et `cni_verifiee=True` pour un prestataire, du même geste) ; `POST …/<id>/reject/` exige un motif et enregistre `motif_rejet` ; chaque action écrit l'audit ; l'utilisateur concerné peut lire son nouvel état via `/api/business/me/` ; tests, dont : un Validateur peut valider ; la CNI n'est servie à personne d'autre.

### T072 — Backend : comptes (liste, blocage, suppression douce, restauration)
- **Agent** c2 · **Réf.** C2.6 · **Dépend de** T071
- **Terminé quand** : `GET /api/admin/accounts/` filtrable (tous / simple / business / bloqués), recherche par nom ou numéro, pagination ; `POST …/block/`, `…/unblock/`, `DELETE …/` (suppression **douce** : `is_deleted`, `deleted_at`), `POST …/restore/` — réservés à l'Administrateur complet, motif obligatoire pour bloquer et supprimer ; un compte bloqué ne peut plus se connecter et disparaît de la recherche et de l'appel (tests de bout en bout avec T007 et T040) ; un admin ne peut pas se bloquer ni se supprimer lui-même ; tests.
  - Filtre par zone ; `GET /api/admin/accounts/<id>/` : **vue détaillée** (identité, type, profil business et ses pièces via URL temporaire, historique de statuts, dernières actions d'audit) ; le numéro complet n'apparaît que dans cette vue et seulement pour l'Administrateur complet (la liste montre `+237 6•• •• •• 41`, comme les maquettes).

### T073 — Backend : chiffres du tableau de bord
- **Agent** c2 · **Réf.** C2.3 · **Dépend de** T072
- **Terminé quand** : `GET /api/admin/stats/` : comptes au total et nouveaux de la semaine, comptes business actifs et nombre de quartiers couverts, demandes en attente (business), appels et recherches des 7 derniers jours, comptes à fort trafic non abonnés (seuil lu dans `PlatformSetting`), nombre d'abonnés ; **« revenus du mois » vaut 0 et est marqué `unavailable` tant que les paiements ne sont pas faits** ; requêtes sans N+1 (test du nombre de requêtes) ; tests.

### T074 — Backend : réglages, administrateurs, export
- **Agent** c2 · **Réf.** C2.9 + nouveau · **Dépend de** T073
- **Terminé quand** :
  1. Routes de lecture et d'écriture des `PlatformSetting` (modèle créé en T008b, clés listées là) ; réservées à l'Administrateur complet ; valeurs validées (entiers ≥ 0 dans des bornes raisonnables) ; chaque changement audité.
  2. `POST /api/admin/admins/` crée un compte Validateur ou Administrateur complet (jamais d'auto-inscription) ; attribution et retrait de rôle audités.
  3. `GET /api/admin/export/accounts.csv` (Administrateur complet seulement) sans CNI ni jeton.
  4. Tests de permissions pour chaque route.

### T074b — Backend : référentiels modifiables par l'administration
- **Agent** c2 · **Réf.** nouveau · **Dépend de** T074
- **Terminé quand** : CRUD admin (désactivation à la place de la suppression) des zones, secteurs, sous-catégories, catégories de service, types de structure, produits du catalogue et synonymes — le découpage administratif doit pouvoir changer sans nouvelle version de l'application ; Administrateur complet seulement ; audit des changements ; liste des valeurs libres à examiner (`secteur_libre`, `categorie_service_libre`, `structure_type_libre`) avec leur fréquence ; tests de permissions et de désactivation.

### T074c — Backend : analyses, abonnements, lecture de l'audit
- **Agent** c2 · **Réf.** C2.8 + nouveau · **Dépend de** T074b
- **Terminé quand** : `GET /api/admin/analytics/searches/` (termes fréquents, recherches sans résultat), `…/calls/` (par jour, par opérateur Orange/MTN, par plateforme, par canal), `GET /api/admin/subscriptions/` (liste, filtre abonnés / non abonnés / à fort trafic), `GET /api/admin/audit/` (filtre admin, action, date) ; Validateur et Administrateur complet en lecture, comme dans la spec ; sans N+1 ; tests de permissions.

### T075 — Backend : tests et contrat de l'administration
- **Agent** c2 · **Réf.** C2.10 · **Dépend de** T074c
- **Terminé quand** : `tests/test_{stats,businesses,permissions}.py` couvrent chaque route ; `openapi.yaml` décrit toutes les routes `/api/admin/` ; l'orchestrateur relit le contrat admin des tâches T070–T074c et le note dans `PROGRESS.md` ; les routes ajoutées plus tard (T094, T110) l'étendent sans le casser.

### T076 — Dashboard : kit de composants et thème
- **Agent** c3 · **Réf.** C3.3 · **Maquette** `Dashboard-*` · **Dépend de** T075
- **Terminé quand** : boutons, champs, tableaux, badges, modales, confirmation, pagination, toasts ; thème sombre par défaut avec accent `#F2942E`, bascule clair ; tests des composants clés.

### T077 — 🔒 Dashboard : connexion de l'administrateur
- **Agent** c3 · **Réf.** C3.4 · **Dépend de** T076
- **Terminé quand** : page de connexion (téléphone + mot de passe) ; jeton d'accès **en mémoire** uniquement ; rafraîchissement selon D-01 ; routes protégées ; déconnexion ; rôle lu depuis `/api/admin/me/` (T070) pour masquer les actions interdites ; 401 → retour à la connexion ; tests.

### T078 — Dashboard : mise en page
- **Agent** c3 · **Réf.** C3.5 · **Maquette** barre latérale commune · **Dépend de** T077
- **Terminé quand** : barre latérale NETBUIS Admin avec Vue d'ensemble, Demandes (pastille du nombre), Comptes, Équipe & abonnements (entrée visible mais « bientôt » jusqu'à T113), et — en bas — Déconnexion et le nom de l'admin ; entrées réservées à l'Administrateur complet masquées pour un Validateur ; tests.

### T081 — Dashboard : Vue d'ensemble
- **Agent** c3 · **Réf.** C3.6 · **Maquette** `Dashboard-Vue` · **Dépend de** T078
- **Terminé quand** : quatre cartes de chiffres ; demandes récentes ; bloc abonnements ; liste « comptes à fort trafic non abonnés » ; le bloc « Performance équipe NetBuis » affiche « Fonction à venir » tant que V01 n'est pas fait ; « Revenus du mois » affiche un tiret avec la mention « paiements non activés » ; état de chargement et d'erreur soignés ; tests.

### T082 — Dashboard : Demandes
- **Agent** c3 · **Réf.** C3.7 · **Maquette** `Dashboard-Demandes` · **Dépend de** T081
- **Terminé quand** : onglet Comptes business (l'onglet Équipe NetBuis n'est **pas affiché** tant que V01 n'est pas fait ; la mention « parrainé par » est masquée) ; dossier avec pièces (photo du propriétaire, du commerce ; pour un prestataire CNI et diplôme) ; **Valider**, **Rejeter** avec motif obligatoire (fenêtre de saisie) ; confirmation visuelle comme la maquette ; la CNI n'est ouverte qu'à la demande ; tests (rejet sans motif impossible).

### T083 — Dashboard : Comptes
- **Agent** c3 · **Réf.** C3.8 · **Maquette** `Dashboard-Comptes` · **Dépend de** T082
- **Terminé quand** : tableau NOM · TÉLÉPHONE · TYPE · ZONE · STATUT · ACTIONS ; filtres Tous / Simple / Business / Bloqués (Équipe NetBuis désactivé tant que V01) ; recherche ; Bloquer / Débloquer / Supprimer / Restaurer avec motif ; ces actions n'existent pas pour un Validateur ; le numéro complet s'affiche ici (usage interne admin) ; tests.
  - Le numéro est **masqué** dans le tableau (`+237 6•• •• •• 41`, comme la maquette) ; un clic ouvre la **page de détail du compte** (route de T072), où l'Administrateur complet voit le numéro complet ; filtre par zone ; chaque page du dashboard ajoute **sa propre entrée** dans la barre latérale (règle valable pour T085, T086, T087, T095, T106, T113).

### T085 — Dashboard : référentiels
- **Agent** c3 · **Dépend de** T074b · **Terminé quand** : pages Zones (arbre), Secteurs et sous-catégories, Catégories de service, Types de structure, Produits du catalogue, Synonymes : liste, ajout, modification, désactivation ; les suppressions sont des désactivations ; Administrateur complet seulement ; tests.
  - Une page « À examiner » liste les valeurs libres saisies par les commerçants (secteur, catégorie de service, type de structure « Autre ») avec leur fréquence, pour décider de les ajouter officiellement.

### T086 — Dashboard : réglages et administrateurs
- **Agent** c3 · **Dépend de** T074 · **Terminé quand** : page Réglages (les clés de `PlatformSetting`, avec validation des bornes) et page Administrateurs (créer / retirer / changer le rôle) ; Administrateur complet seulement ; tests.

### T087 — Dashboard : journal d'audit
- **Agent** c3 + c2 · **Réf.** C3.12, C2.8 · **Dépend de** T086 (route de T074c) · **Terminé quand** : liste filtrable (admin, action, date) en lecture seule, motif visible ; tests.

### T088 — Dashboard : export
- **Agent** c3 · **Dépend de** T087 · **Terminé quand** : bouton d'export CSV des comptes (Administrateur complet) ; le fichier ne contient ni CNI ni jeton ; test.

### T089 — Vérification de tranche : administration de bout en bout
- **Agent** orchestrateur · **Dépend de** T088
- **Terminé quand** : scénario réel — un compte de test crée un commerce depuis le mobile (T036), un Validateur le valide dans le dashboard, le commerce apparaît dans la recherche et sur la carte du mobile ; un Administrateur complet bloque le compte, le commerce disparaît de la recherche et son propriétaire est déconnecté au rafraîchissement ; les 4 actions sont dans l'audit ; `logs/T089-tranche.md`. **Jeff relit 🔒 connexion admin et droits.**

---

# PHASE 9 — Forum : publications et commentaires (Étape 7)

> Le forum de la v1 est celui des maquettes : **le fil des publications des commerçants**, avec **commentaires** ouverts à tout compte. (Pas de « fils de discussion » libres.)

### T090 — Backend : publications, commentaires, signalements
- **Agent** a3 · **Réf.** A3.12, A3.13 · **Spéc.** `docs/spec/MODELE_DONNEES.md` § Post, Comment · **Dépend de** T089
- **Terminé quand** :
  1. `Post` (profil, type image/vidéo, média, légende ≤ 500 caractères, produit associé facultatif, date, statut actif/masqué/supprimé), `Comment` (post, auteur, texte ≤ 300, date, statut), `Report` (cible post/commentaire, motif, auteur).
  2. `GET /api/forum/posts/?zone=` (fil, plus récents d'abord, **abonnés mis en avant** seulement via le tri de la spec), `GET /api/forum/posts/<id>/` (avec commentaires paginés), `POST /api/forum/posts/` (réservé à un profil `actif`), `DELETE` de ses propres publications, `GET /api/forum/mine/`, `POST …/<id>/comments/`, `POST …/report/`.
  3. **Plafond de 5 publications actives** sans abonnement actif (valeur `PlatformSetting`) : la 6ᵉ est refusée `SUBSCRIPTION_REQUIRED` ; un abonnement qui expire ne supprime rien.
  4. Un compte bloqué ne peut ni publier, ni commenter ; ses contenus sont masqués.
  5. Limites anti-spam : ≤ 10 commentaires / 10 min / compte ; ≤ 5 publications / jour.
  6. Tests de chaque règle.
  7. `Report` : cible `post`, `comment` ou `business` ; **un seul signalement par compte et par cible** (unicité) ; motif parmi une liste fermée de 4 (`spam`, `arnaque`, `contenu_inapproprie`, `autre`) ; `POST /api/reports/` ; les contenus signalés par l'utilisateur lui-même sont **exclus par le serveur** de ses fils ; tests.
  8. `seed_demo` étendu avec publications et commentaires (voir T028).
  9. Anti-spam : les « 5 publications par jour » ne sont **pas** le plafond de « 5 actives sans abonnement » ; deux règles distinctes, deux tests.

### T091 — Mobile : Publier et Mes publications
- **Agent** b3 · **Réf.** B3.5, B3.6 · **Maquette** `Publier`, `MesPublications` · **Dépend de** T090
- **Terminé quand** : choix d'une photo ou vidéo (caméra ou galerie) ; légende ; association facultative d'un produit parmi mes produits ; bouton **Publier** ; mention « Visible par tous… » ; liste de mes publications avec date et nombre de commentaires, suppression avec confirmation ; accessible seulement avec un compte business actif ; message clair quand le plafond de 5 est atteint ; tests.

### T092 — Mobile : Forum et page d'une publication
- **Agent** b3 · **Réf.** B3.5, B3.6 · **Maquette** `Forum`, `Publication` · **Dépend de** T091
- **Terminé quand** : fil (initiales ou photo du commerce, nom, zone · il y a x h, légende, étiquette produit, « n commentaires ») ; page d'une publication avec commentaires et champ pour écrire ; commentaire envoyé et affiché immédiatement ; chargement de la suite en fin de liste ; vidéo qui ne se lance qu'à la demande ; tests.

### T093 — Mobile : signaler
- **Agent** b3 · **Dépend de** T092 · **Terminé quand** : « Signaler » sur une publication ou un commentaire avec 4 motifs en gros boutons icône + mot ; confirmation « merci » ; un contenu signalé par soi-même n'est plus montré à soi ; tests.
  - Le motif se choisit parmi les 4 de T090 ; le même bouton **« Signaler ce commerce »** existe sur la fiche publique (T047) et sur l'Historique ; il appelle la même route.

### T094 — Backend : modération
- **Agent** a3 + c2 · **Réf.** A3.14, C2.5 · **Dépend de** T093
- **Terminé quand** : filtre anti-spam simple (liens répétés, mots interdits configurables, doublons) ; un contenu signalé par ≥ 3 comptes distincts est **masqué automatiquement** en attente de revue ; `GET /api/admin/reports/`, `POST …/hide/`, `…/restore/`, `…/delete/` (motif, audit) ; tests.

### T095 — Dashboard : modération du forum
- **Agent** c3 · **Réf.** C3.9 · **Dépend de** T094 · **Terminé quand** : file des signalements, aperçu du contenu, actions Masquer / Restaurer / Supprimer avec motif ; tests.

### T096 — Vérification de tranche : forum
- **Agent** orchestrateur · **Dépend de** T095 · **Terminé quand** : scénario réel publier → voir dans le fil → commenter → signaler ×3 → masqué → restauré par un admin ; `logs/T096-tranche.md`.

---

# PHASE 10 — Profil, aide, langue

### T100 — Mobile : réglages (langue et thème)
- **Agent** b3 · **Réf.** B3.12 · **Dépend de** T096
- **Terminé quand** : choix **Français / English** appliqué immédiatement à toute l'application (fichiers `assets/l10n/fr.json` et `en.json` complets pour les écrans déjà faits : une clé manquante fait échouer un test) ; choix du thème **Clair / Sombre / Automatique** ; les deux réglages persistent après redémarrage ; écrans « À propos » et « Mentions légales » avec texte provisoire marqué `À REMPLACER` ; tests.
  - Pages « Conditions d'utilisation » et « Politique de confidentialité » (texte provisoire `À REMPLACER`) liées depuis Connexion, Aide et Profil.
  - Synthèse vocale (D-21) : plugin `flutter_tts` ; si le téléphone n'a pas de voix française, les boutons **🔊 Écouter** sont masqués (jamais un bouton qui ne fait rien).

### T101 — Mobile : Aide et support
- **Agent** b3 · **Réf.** B3.12 · **Maquette** `Aide` · **Dépend de** T100
- **Terminé quand** : FAQ en accordéon (une seule question ouverte) avec trois thèmes et **🔊 Écouter** réel sur chaque réponse ; contact WhatsApp / téléphone / e-mail **lus dans la configuration** (valeurs par défaut marquées `À REMPLACER`, voir D-06) ; bouton « Signaler un problème ou un compte suspect » (ouvre WhatsApp support avec message pré-rempli) ; la réponse sur « pourquoi le numéro n'est pas visible » est celle de D-07 ; **les questions sur les crédits sont masquées** tant que `CREDITS_ENABLED=False` ; tests.
  - La FAQ cite les **5** types de compte business ; la section « Parrainage & sécurité » est réduite à la partie sécurité (comment signaler un compte suspect) tant que `TEAM_ENABLED=False`.

### T102 — Mobile : finition de l'écran Profil
- **Agent** b1 · **Réf.** B1.14 · **Maquette** `Profil` · **Dépend de** T101
- **Terminé quand** : l'écran correspond à la maquette : numéro masqué « vérifié » ; blocs « Appel gratuit du jour » et « Solde de crédits » **affichés seulement si `CREDITS_ENABLED`** (valeurs `null` de `/me/` sinon) ; bloc COMPTE BUSINESS avec compteurs Mes produits et Mes publications, Modifier ma boutique, ou l'invitation à activer le compte business ; état « en attente / rejeté (motif, bouton Corriger) / actif » ; Historique ; Langue ; Thème ; Aide & support ; Se déconnecter (efface les jetons et l'état) ; **Supprimer mon compte** avec double confirmation (appelle `DELETE /api/me/`, T008) ; aucune entrée ne mène à un écran inexistant ; tests.

### T102b — Mobile : modifier ma boutique
- **Agent** b3 · **Réf.** B3.1 · **Dépend de** T102 · **Terminé quand** : modification du profil business selon les règles de T026 et D-08 (champs sensibles → nouvelle validation, avertissement avant) ; un profil **rejeté** affiche le motif et se corrige puis se renvoie (T026.6) ; tests.

### T103 — Vérification de tranche : profil
- **Agent** orchestrateur · **Dépend de** T102b · **Terminé quand** : changement de langue et de thème persistés après redémarrage ; déconnexion ; `logs/T103-tranche.md`.

---

# PHASE 11 — Produits très sollicités et abonnements (sans paiement)

### T104 — Backend : tendances
- **Agent** a3 · **Réf.** A3.15 · **Dépend de** T103
- **Terminé quand** : calcul périodique (commande `compute_trends`, planifiable) des **produits et commerces les plus recherchés (produits) et les plus contactés, appels et WhatsApp (commerces)** sur 7 jours par ville, à partir de `SearchLog` et `CallLog` ; seuil minimum pour éviter les faux classements : **au moins 5 recherches venant d'au moins 3 comptes distincts** (valeurs d'essai dans `PlatformSetting`) ; `GET /api/trends/?zone=` renvoie au plus 10 produits et 10 commerces (commerces **actifs seulement**, sans numéro) ; instantané stocké ; tests avec des données fabriquées.

### T105 — Mobile : produits très sollicités
- **Agents** b3 (dépôt et état des tendances) puis b2 (bande sur l'Accueil), dans cet ordre · **Réf.** B3.7, B2.1 · **Maquette** (bande sur `Main`) · **Dépend de** T104
- **Terminé quand** : bande « Très demandé près de chez vous » sur l'Accueil (grille qui passe à la ligne, 6 produits max, icône + mot) **et** rangée « Commerces très contactés » (3 max, nom + zone, sans numéro) ; toucher un élément lance la recherche correspondante ; masquée s'il n'y a rien ; tests.

### T106 — Dashboard : analyses
- **Agent** c3 · **Réf.** C3.10 (version minimale) · **Dépend de** T105 (routes de T074c) · **Terminé quand** : pages Recherches (termes fréquents, recherches sans résultat), Appels (par jour, par opérateur Orange/MTN, par plateforme) et Tendances ; graphiques simples ; tests.

### T110 — Backend : accorder, faire expirer, proposer un abonnement (sans paiement)
- **Agents** a2 (expiration, proposition) puis c2 (route d'administration), dans cet ordre · **Spéc.** `docs/spec/DASHBOARD_ADMIN.md` § abonnements · **Dépend de** T106
- **Terminé quand** : (le modèle `Subscription` et `is_subscribed` existent depuis T025b) tâche planifiée `expire_subscriptions` qui passe les abonnements échus en `expiré` ; `POST /api/admin/subscriptions/` pour accorder un abonnement (Administrateur complet, motif, audité) ; vérification que tous les plafonds (3 sous-catégories, 5 publications) et le tri de la recherche passent bien par `is_subscribed` (test qui échoue si un autre chemin existe) ; l'expiration ne supprime rien ; seuil d'appels quotidiens : `GET /api/business/me/` renvoie `suggest_subscription=true` quand le nombre d'appels du jour dépasse `seuil_appels_abonnement` (jamais de blocage des appels reçus) ; tests de chaque plafond avec et sans abonnement, et de l'expiration.
  - Route `POST /api/admin/subscriptions/` écrite par **c2** (dossier `admin_panel`) ; `seed_demo` étendu avec des abonnements.

### T111 — Mobile : propositions d'abonnement
- **Agent** b3 · **Dépend de** T110 · **Terminé quand** : l'encart de Profil « Vous recevez beaucoup d'appels… » quand `suggest_subscription` ; le bouton « Souscrire » mène à un écran « Bientôt disponible — contactez le support » (WhatsApp) tant que les paiements ne sont pas faits ; aucun mot de paiement ni de prix inventé ; tests.

### T112 — Vérification de tranche : plafonds et abonnement
- **Agent** orchestrateur · **Dépend de** T111 · **Terminé quand** : compte non abonné refusé à la 4ᵉ sous-catégorie et à la 6ᵉ publication par le **serveur** ; après un abonnement manuel accordé dans le dashboard, accepté ; classé avant les autres dans la recherche ; `logs/T112-tranche.md`.

### T113 — Dashboard : Équipe & abonnements — écran sans maquette
- **Agent** c3 · **Dépend de** T112
- **Terminé quand** : liste des comptes business abonnés / non abonnés, filtre, bouton **Accorder un abonnement** (mois, motif — saisie manuelle en attendant les paiements, audité, Administrateur complet seulement) ; la partie « équipe » est marquée « à venir » ; écran décrit dans le rapport.
  - Utilise les routes de T074c et T110 ; ne masque pas les colonnes liées à l'équipe tant que V01 n'est pas fait (elles ne sont pas affichées).

---

# PHASE 12 — Durcissement et recette (Étape 8)

### T120 — Accessibilité de tous les écrans mobiles
- **Agent** b1 (conduit l'audit) + b2 + b3 pour leurs dossiers · **Réf.** B1.16 · **Spéc.** `docs/spec/ACCESSIBILITE.md` · **Dépend de** T113
- **Terminé quand** : une **grille d'audit** `logs/T120-audit-accessibilite.md` passe les 16 écrans de la liste de la spec **et** les écrans sans maquette (fiche publique, Mes produits, choix de ville et de lieu, filtres, Modifier ma boutique, propositions d'abonnement) sur les 13 principes : pour chacun, conforme / corrigé / dérogation justifiée ; aucun défilement horizontal ; chaque choix = icône + mot ; champs numériques au clavier numérique ; cibles tactiles ≥ 48 dp ; contraste du texte ≥ 4,5:1 en sombre et en clair ; tailles de police qui suivent le réglage du téléphone sans casser la mise en page ; tous les écrans à 360 px de large sans débordement (tests de widgets à cette largeur).
  - Contraste : en thème clair, le texte et les icônes en couleur d'accent utilisent la variante `#A85A00` (4,75:1) et le texte secondaire `#6B6B70` (D-20) ; les boutons gardent le fond `#F2942E` avec le texte `#1A1200`.

### T121 — Revue de sécurité
- **Agent** a1 (backend), c3 (dashboard), b1 (mobile) · **Réf.** A1.x · **Dépend de** T120
- **Terminé quand** : liste de contrôle `logs/T121-securite.md` remplie par vérification, pas par déclaration : aucun secret dans le dépôt (`git grep` sur motifs de clés), `DEBUG=False` en `prod`, en-têtes de sécurité, `ALLOWED_HOSTS` et CORS stricts, limites de débit sur OTP / appel / connexion admin / recherche / commentaires, aucune route admin sans permission (test qui énumère **toutes** les routes et vérifie l'accès refusé sans jeton), numéro de commerçant absent de toutes les réponses sauf `/calls/initiate/` (test qui parcourt toutes les routes publiques), CNI jamais servie hors admin, journaux sans données personnelles, dépendances sans vulnérabilité connue (`pip-audit`, `npm audit` si disponibles, sinon indiqué).

### T122 — Performances
- **Agents** a1, a2, a3 (chacun ses index, un à la fois) puis b1 (mesures mobiles) · **Dépend de** T121
- **Terminé quand** : index vérifiés sur recherche, carte, fil ; pas de N+1 sur les routes de liste (tests sur le nombre de requêtes) ; recherche < 300 ms sur 5 000 commerces fictifs en local (mesure notée) ; mobile : démarrage à froid et défilement des listes sans saccade sur un appareil modeste (mesure ou observation notée).

### T123 — Tests de bout en bout et intégration continue
- **Agent** orchestrateur (fichiers `.github/`, documentation) ; les scénarios sont écrits un domaine après l'autre par l'agent propriétaire du domaine (a1 accès, a2 création de commerce, a3 recherche/appel/forum, b1/b2/b3 mobile, c2/c3 administration) · **Réf.** B1.15, C3.14 · **Dépend de** T122
- **Terminé quand** : le workflow `.github/workflows/` lance les trois jeux de tests ; au moins un scénario complet par domaine (accès, création de commerce, recherche, appel, carte, forum, admin) est automatisé ; couverture notée dans le rapport ; tout est vert.

### T124 — Construction de l'application et documentation d'exploitation
- **Agent** b1 (construction) puis orchestrateur (`README`, `docs/RECETTE.md`) · **Dépend de** T123
- **Terminé quand** : `flutter build apk --release` (signature de débogage) réussit ; `README` racine et `backend/README.md` expliquent installation, variables d'environnement (noms seulement), commandes de démarrage, sauvegarde de la base ; `docs/RECETTE.md` liste la procédure de recette manuelle sur téléphone ; **aucun déploiement n'est fait**.

### T125 — Recette finale contre le cahier de charge
- **Agent** orchestrateur seul · **Dépend de** T124
- **Terminé quand** : le tableau « Cahier de charge → tâches → preuve » de `docs/PROGRESS.md` est rempli : pour chaque fonctionnalité demandée (recherche, liste de commerçants, appel direct, WhatsApp, forum, produits très sollicités, compte business, dashboard) la preuve est un test vert ou un journal ; toute ligne sans preuve est rouverte comme tâche ; le rapport final liste ce qui reste à faire par Jeff (clés, données, publication, paiement).

---

# PHASE 13 — Appels par Jitsi vers l'équipe NetBuis (décisions D-25 à D-28, ajoutée le 2026-10-22)

> Spécification : `docs/spec/APPELS_JITSI.md` (elle remplace `docs/spec/APPELS.md`). À exécuter AVANT la fin de T121 : la revue de sécurité (T121), les performances (T122) et les tests de bout en bout (T123) devront couvrir ces nouvelles routes.

### T041b — Backend : la recherche trouve un commerce par son nom (décision D-27)
- **Agent** a3 · **Dépend de** T040 · **Réf.** `docs/A_RELIRE_PAR_JEFF.md` (« la recherche ne trouve pas un commerce par son nom »)
- **Terminé quand** : taper une partie du **nom d'un commerce actif** (sans tenir compte de la casse ni des accents, y compris une faute de frappe légère comme pour les produits) le fait apparaître dans les résultats ; le nom pèse moins qu'une correspondance exacte de produit mais plus qu'une correspondance de sous-catégorie (ordre documenté et testé) ; un index trigramme sur le nom normalisé existe (migration, `EXPLAIN` ou test de requête) ; seuls les commerces `visible()` sont trouvés (jamais en attente, rejeté, bloqué, supprimé) ; les abonnés restent en premier à pertinence égale ; aucun numéro dans les réponses ; recherche < 300 ms sur 5 000 commerces fictifs (mesure notée) ; tests (nom exact, partiel, accents, faute, commerce masqué, ordre, requêtes en nombre constant).

### T130 — Spécification et décisions des appels Jitsi (orchestrateur)
- **Fait le 2026-10-22** : `docs/spec/APPELS_JITSI.md`, décisions D-25 à D-28, tâches T131 à T135.

### T131 — Backend : sessions d'appel, temps réel et accès Jitsi
- **Agent** a3 (+ a1 pour le droit et la configuration) · **Dépend de** T130, T041b · **Spéc.** `docs/spec/APPELS_JITSI.md`
- **Terminé quand** (un test par point) :
  1. Modèles `CallSession` (états `ringing`, `answered`, `ended`, `missed`, `declined`, `unavailable`, `cancelled`) et `AgentPresence` ; migrations propres.
  2. `POST /api/calls/sessions/` (connecté, non bloqué, `business_id` facultatif) : crée la session, publie l'événement, renvoie `{session_id, jitsi:{domain, room, jwt}, ring_seconds}` ; une seule session active par appelant (409 sinon) ; limites par minute et par jour lues dans `PlatformSetting` (429) ; sans agent disponible : réponse `unavailable` immédiate sans attente.
  3. Accès Jitsi : nom de salle secret (≥ 128 bits), jeton signé HS256 (`JITSI_APP_ID`, `JITSI_JWT_SECRET`, `JITSI_DOMAIN` lus de l'environnement ; secret absent = jeton non émis et configuration signalée) limité à UNE salle, durée courte, rôle modérateur pour l'agent et participant pour l'appelant, enregistrement et transcription désactivés ; test de la structure du jeton (sans secret en clair dans les journaux).
  4. Flux agent `GET /api/admin/calls/stream/` (SSE sur ASGI, PostgreSQL `LISTEN/NOTIFY`), réservé au droit **`peut_repondre_aux_appels`** (ajouté aux groupes « Validateur » et « Administrateur complet », migration de données) ; à la connexion il rejoue les sessions en sonnerie ; battement de cœur de présence ; `POST /api/admin/calls/presence/` (disponible / indisponible).
  5. `POST /api/admin/calls/sessions/<id>/accept/` atomique (un seul gagnant : test avec deux agents simultanés), `…/decline/`, `POST /api/calls/sessions/<id>/end/` (les deux côtés), `…/cancel/` (l'appelant raccroche avant réponse), expiration à 30 s en `missed` (commande ou tâche à planifier documentée), événements `taken` / `ended` aux autres agents ; flux appelant `GET /api/calls/sessions/<id>/events/` (SSE) + consultation courte `GET /api/calls/sessions/<id>/`.
  6. `GET /api/admin/calls/` (liste paginée : appels manqués, répondus, par agent ; sans numéro de l'appelant) et `GET /api/calls/history/` (l'historique de l'appelant, adapté à T053) ; journal d'audit des réponses/refus ; aucun jeton, salle ni numéro dans les journaux.
  7. **`POST /api/calls/initiate/` et la livraison du numéro d'un commerçant sont retirés** (route, service, sérialiseur, tests de livraison remplacés par un test qui prouve qu'AUCUNE route ne renvoie `phone_anchor`) ; WhatsApp inchangé ; `CLAUDE.md` et `AGENTS.md` mis à jour par l'orchestrateur ; `openapi.yaml` à jour.
  8. Serveur ASGI documenté (`uvicorn`/`daphne` ou équivalent déjà installé : n'ajoute une dépendance que si indispensable et dis-le), commande de démarrage et réglage de connexion PostgreSQL directe (pas de pool en mode transaction) dans `docs/deployment/`.
  8b. **Point d'accroche du quota** (V08 reporté) : une fonction unique `caller_may_start_call(user)` appelée par `POST /api/calls/sessions/`, qui reprend la logique de quota de l'ancien `initiate` (limites, `CREDITS_ENABLED`) et ne débite rien tant que les paiements sont reportés ; `free_call_available` et `credits_balance` de `/api/me/` restent `null` ; aucun fichier de `apps/payments/` n'est modifié.
  9. Mesure automatisée : de la réception du POST à la réception de l'événement par un flux agent déjà connecté : **p95 < 250 ms** sur 100 appels en local (test ou script noté dans `docs/verifications/T131.md`) ; avec 3 agents connectés.

### T132 — Dashboard : appels entrants et salle Jitsi
- **Agent** c3 · **Dépend de** T131 · **Maquettes** : aucune (écran sans maquette : à décrire dans le rapport, style des écrans Demandes/Comptes)
- **Terminé quand** : bouton « Disponible / Indisponible » (présence, battement de cœur) visible partout ; fenêtre d'**appel entrant** (sonnerie sonore, nom de l'appelant, commerce concerné, compte à rebours de sonnerie, boutons Répondre / Refuser), qui se ferme si un autre agent répond (`taken`) ; à « Répondre » : salle Jitsi intégrée via `external_api.js` du domaine Jitsi (jeton fourni par l'API, audio, vidéo coupée par défaut, fin d'appel) ; reconnexion automatique du flux (rejoue les sonneries en cours) ; page « Appels » (manqués / répondus, filtres) ; le droit `peut_repondre_aux_appels` pilote l'affichage ; accessibilité (sonnerie annoncée, boutons ≥ 44 px, clavier) ; ErrorBoundary autour de la fenêtre d'appel ; tests (Vitest) et un essai dans un vrai navigateur (Playwright, Jitsi simulé par une page factice) qui mesure le délai entre l'événement serveur et l'affichage de la fenêtre (< 200 ms).

### T133 — Mobile : appel Jitsi à la place de l'appel téléphonique
- **Agent** b2 (+ b1 pour la construction) · **Dépend de** T131
- **Terminé quand** : le bouton Appeler (fiche du commerce, liste, historique) lance `POST /api/calls/sessions/` puis affiche l'écran d'appel (« Appel en cours… », annulation, minuteur) et rejoint la salle Jitsi dès l'envoi (`jitsi_meet_flutter_sdk`, audio seul, vidéo coupée, jeton fourni par l'API) ; états `unavailable` (message « Personne n'est disponible, réessayez plus tard »), `missed`, `declined`, réseau coupé, micro refusé, fin d'appel ; connexion réseau réchauffée à l'ouverture de la fiche ; mention claire à l'utilisateur que l'appel est avec l'équipe NetBuis (texte à valider par Jeff) ; **retrait** de la feuille Orange / MTN, de l'appel direct Android (`CallChannel.kt`, permissions téléphone) et des textes associés ; l'historique des appels lit les sessions ; FR + EN ; tests de widgets avec un faux service Jitsi (la salle réelle n'est pas testable sans téléphone : `docs/TESTS_JEFF.md` reçoit la procédure d'essai) ; taille de l'APK mesurée avant/après (`flutter build apk --release` si possible) et notée.

### T134 — Vérification de tranche : appel de bout en bout et latence
- **Agent** orchestrateur · **Dépend de** T132, T133
- **Terminé quand** : un script exécuté contre le vrai serveur et un vrai navigateur (Playwright, Jitsi simulé) joue : agent connecté et disponible → appelant lance l'appel → fenêtre d'appel entrant → réponse → fin ; deux agents (un seul gagne) ; aucun agent (réponse immédiate) ; délai mesuré (p95 noté dans `docs/verifications/T134.md`) ; aucun numéro de commerçant dans aucune réponse ; le résultat est écrit ; ce qui n'est pas vérifiable ici (audio réel, SDK Android) est listé pour Jeff.

### T135 — Exploitation de Jitsi et de l'ASGI (documentation, orchestrateur)
- **Terminé quand** : `docs/deployment/JITSI.md` décrit les deux options (JaaS et auto-hébergé : ports, variables, jetons, coûts à revérifier, sauvegarde), les réglages du serveur ASGI et de PostgreSQL, la tâche planifiée d'expiration des sonneries, et la procédure d'essai réel pour Jeff ; **aucun déploiement n'est fait**.

---

# Écarts connus entre `docs/TASKS_PAR_AGENT.md` et ce backlog (le backlog l'emporte)

Les colonnes « Ce qu'il faut implémenter » de `TASKS_PAR_AGENT.md` datent d'avant les maquettes. Quand une `Réf.` est citée, **seuls les fichiers à toucher** comptent, et les écarts suivants sont réglés ainsi :

| Ligne | Ancienne valeur | Valeur retenue |
|---|---|---|
| A1.2 / A1.10 | jeton d'accès 30 min ; `/admin-login/` | 15 min (T007) ; `/api/auth/admin/login/` |
| A1.6 / A1.11 | rôles client/merchant/admin ; `DELETE /me/` avec anonymisation | `is_admin` + `BusinessProfile` (T005b) ; suppression douce (T008) |
| A2.1 | modèles `Ville`, `Quartier` | un seul modèle `Zone` hiérarchique (T020) |
| A2.7 | champs `phone_orange`, `phone_mtn` | un numéro ancré, jamais exposé (T025) |
| A2.12 | photos 2 Mo | 5 Mo (T027) |
| A2.16 | 200 fiches « [DÉMO] » | `seed_demo --count` (T028) |
| A3.8 | 30 appels / h, `wa_url` | 5 / min et 50 / jour (D-05), lien WhatsApp (T051) |
| A3.12 / A3.13 / B3.5 / B3.6 | fils de discussion de 2 000 caractères | publications de commerçants (500) + commentaires (300) (T090–T092) |
| A3.15 | 3 recherches / 2 utilisateurs | 5 recherches / 3 comptes (T104) |
| B1.3 / B1.7 / C3.5 | thème turquoise, onglets Tendances / Compte | orange, Accueil · Carte · Forum · Profil (T004) |
| B1.13 | 3 diapositives | 5 diapositives (T010) |
| C2.4 | `PATCH approve` | `POST …/approve/` et `…/reject/` (T071) |
| C3.4 | cookie `SameSite=Strict` | `SameSite=Lax` (D-01) |
| B3.8 et suivantes | paiement | reporté (V08) |

# FACULTATIF v1.1 — ne pas commencer sans « go » écrit de Jeff

| Id | Sujet | Réf. | Remarque |
|---|---|---|---|
| V01 | Équipe NetBuis et parrainage (candidature avec vidéo CNI, code de parrainage, prime) | A2/A3 nouveau, C3 onglet Équipe | Les bannières et onglets existent déjà, désactivés derrière `TEAM_ENABLED=False` |
| V02 | Commandes (`Order`) entre un compte simple et un compte business | modèle de données | Pas dans les maquettes |
| V03 | Notifications (push et dans l'application) | A3.16, B3.11 | Nécessite Firebase |
| V04 | Impression de fiches et d'affiches QR | A3.17, B3.10 | |
| V05 | « Autour de moi » avec la position GPS | A2.15, B2.12 | |
| V06 | Statistiques du commerçant (vues, appels) | A2.14, B3.4 | Les compteurs existent déjà dès T037 |
| V07 | Variante iOS de l'appel et de WhatsApp | décision D-07 | |
| V08 | **Paiements** : CamPay, achat de crédits, quota d'appels, paiement des abonnements, paiements sortants | C1.*, B3.8, B3.9, C2.7, C3.11 | Reporté. Passer `CREDITS_ENABLED=True` seulement après validation de Jeff |
| V09 | Déploiement (Railway, Vercel, stockage S3) et publication Play Store | `docs/deployment/` | Reporté |
| V10 | Camtel et Nexttel dans le choix de la ligne | décision appel | |
