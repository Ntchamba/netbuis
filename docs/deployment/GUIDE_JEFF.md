# Mettre NetBuis en ligne soi-même — guide pas à pas (Jeff)

Trois éléments : le **serveur** (backend), le **tableau de bord** (dashboard) et l'**application Android** (l'« exécutable » : un fichier `.apk`). Détails techniques : `DEPLOYMENT.md`, `APPELS_ASGI.md`, `JITSI.md`. Rien de ceci n'a été essayé en vrai : c'est la marche à suivre, à vérifier pas à pas.

## Avant de commencer
- Un compte GitHub avec ce dépôt, un compte Railway (⚠ Railway demande une carte de paiement : si ce n'est pas possible, repli prévu : base PostgreSQL chez Neon, serveur chez un autre hébergeur), un compte Vercel (ou Netlify) pour le tableau de bord.
- **Jamais** de mot de passe ni de clé dans un fichier du dépôt : tout se saisit dans les « Variables » de Railway / Vercel.
- Changer d'abord le mot de passe PostgreSQL de l'ancien `.env` (il reste dans l'historique de `main`).

## 1. Serveur (Railway)
1. Railway → New Project → **Deploy from GitHub repo** → ce dépôt, branche `claude/gifted-dijkstra-yjxzvf` (ou `main` après fusion). Service : dossier racine **`backend`**.
2. Dans le même projet : **+ New → Database → PostgreSQL**.
3. Service serveur → Settings :
   - Build et Start sont déjà décrits dans `backend/railway.json` (et `requirements.txt`, `.python-version`) : Railway les lit tout seul. Vérifier qu'ils apparaissent bien dans Settings ; sinon les saisir : Build `python manage.py collectstatic --noinput`, Start `python manage.py migrate && uvicorn config.asgi:application --host 0.0.0.0 --port $PORT --workers 2 --no-access-log`.
   - Variable `DJANGO_SETTINGS_MODULE` = `config.settings.prod`
4. Variables du service (les valeurs sont à vous) :
   - `SECRET_KEY` : au moins 32 caractères au hasard ; `DEBUG` = `False`
   - `DATABASE_URL` : la valeur fournie par le service PostgreSQL (adresse **directe**, pas un pool en mode transaction)
   - `ALLOWED_HOSTS` : le domaine du serveur (ex. `votre-serveur.up.railway.app`)
   - `CORS_ALLOWED_ORIGINS` et `CSRF_TRUSTED_ORIGINS` : l'adresse `https://…` du tableau de bord
   - `NUM_PROXIES` = `1`
   - `SMS_PROVIDER` et `SMS_API_KEY` : le fournisseur de SMS (sans lui, personne ne reçoit de code)
   - Appels : `JITSI_DOMAIN`, `JITSI_APP_ID`, `JITSI_JWT_SECRET` (voir `JITSI.md` ; sans eux les appels sont refusés, le reste fonctionne)
   Le serveur **refuse de démarrer** si un réglage est dangereux (clé trop courte, hôtes non `https`…) : lire le message dans les journaux.
5. ⚠ **Les photos** (commerces, forum) et les **pièces d'identité** sont écrites sur le disque du serveur, dans `media/` et `private_media/` à côté du code. Sur Railway le disque est effacé à chaque déploiement : ajoutez un **Volume** et montez-le sur ces deux dossiers (ou sur un dossier parent commun) avant d'accepter de vrais utilisateurs. (Point à améliorer plus tard : stockage externe.)
6. Deuxième service (même dépôt, dossier `backend`) pour les sonneries oubliées : Start = `python manage.py expire_calls --loop 30`, mêmes variables.
7. Créer le premier administrateur : dans Railway, ouvrir un terminal du service (ou `railway run`) : `python manage.py createsuperuser` (numéro + mot de passe saisis au clavier).
8. Test : ouvrir `https://VOTRE-SERVEUR/api/health/` → doit répondre « ok ».

## 2bis. Tableau de bord sur Railway aussi (fichiers prêts : `dashboard/Dockerfile`, `nginx.conf.template`)
Dans le même projet Railway : **+ New → GitHub Repo** → même dépôt → Settings → **Root Directory : `dashboard`** (Railway détecte le `Dockerfile`). Variable du service : `VITE_API_BASE_URL` = `https://VOTRE-SERVEUR` (sans `/api` ; lue à la construction, donc redéployer si elle change). Settings → Networking → **Generate Domain**, puis mettre cette adresse dans `CORS_ALLOWED_ORIGINS` et `CSRF_TRUSTED_ORIGINS` du serveur. Ces fichiers n'ont pas pu être construits ici (pas de Docker) : si la construction échoue, copiez-moi le journal.

## 2. Tableau de bord (Vercel — alternative)
1. Vercel → Add New Project → ce dépôt → **Root Directory : `dashboard`** (Framework : Vite).
2. Build : `npm run build` ; sortie : `dist`.
3. Variable : `VITE_API_BASE_URL` = `https://VOTRE-SERVEUR` (sans `/api`).
4. Après déploiement, mettre l'adresse Vercel dans `CORS_ALLOWED_ORIGINS` / `CSRF_TRUSTED_ORIGINS` du serveur (point 4 ci-dessus) et redémarrer.
5. Connexion avec le compte créé en 1.7. En-têtes de sécurité recommandés : `dashboard/README.md`.

## Ce qui ne peut PAS tourner sur Railway
- **L'APK Android** : Railway n'en construit pas. Construction par GitHub Actions ou sur votre ordinateur (section 3), puis installation sur le téléphone.
- **Le serveur Jitsi** (audio des appels) : il demande le port UDP 10000, que Railway ne semble pas proposer (à confirmer). Le serveur et le tableau de bord vivent sur Railway, Jitsi sur un petit serveur à part ou sur JaaS (`JITSI.md`, décision D-28).

## 3. Application Android (l'exécutable `.apk`)
**Le plus simple, sans rien installer :** GitHub → onglet Actions → workflow « CI » → tâche **APK Android**. Avant : GitHub → Settings → Secrets and variables → Actions → New repository secret `NETBUIS_API_URL` = `https://VOTRE-SERVEUR/api` (avec `/api`). À la fin de l'exécution, télécharger l'artefact `netbuis-apk-debug-signe` (fichier `app-release.apk`), l'envoyer sur le téléphone et l'installer (autoriser les sources inconnues). Cette tâche n'a jamais encore tourné : si elle échoue, lire le message ou me le coller.
**Sur votre ordinateur :** installer Flutter 3.47 et Android Studio (SDK Android), puis : `cd mobile && flutter pub get && flutter build apk --release --dart-define=API_URL=https://VOTRE-SERVEUR/api` → fichier `mobile/build/app/outputs/flutter-apk/app-release.apk`.
L'APK est signé avec la clé de **débogage** : suffisant pour essayer, pas pour le Play Store (il faudra une vraie clé, gardée hors du dépôt).

## 4. Vérifier
Suivre `docs/RECETTE.md`. Premier essai minimal : installer l'APK → Commencer → numéro → code SMS réel → recherche.
