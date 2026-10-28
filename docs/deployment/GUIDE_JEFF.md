# Mettre NetBuis en ligne soi-même — guide pas à pas (Jeff)

Trois éléments : le **serveur** (backend), le **tableau de bord** (dashboard) et l'**application Android** (l'« exécutable » : un fichier `.apk`). Détails techniques : `DEPLOYMENT.md`, `APPELS_ASGI.md`, `JITSI.md`. Rien de ceci n'a été essayé en vrai : c'est la marche à suivre, à vérifier pas à pas.

## Avant de commencer
- Un compte GitHub avec ce dépôt, un compte Railway (⚠ Railway demande une carte de paiement : si ce n'est pas possible, repli prévu : base PostgreSQL chez Neon, serveur chez un autre hébergeur), un compte Vercel (ou Netlify) pour le tableau de bord.
- **Jamais** de mot de passe ni de clé dans un fichier du dépôt : tout se saisit dans les « Variables » de Railway / Vercel.
- Changer d'abord le mot de passe PostgreSQL de l'ancien `.env` (il reste dans l'historique de `main`).

## 1. Serveur (Railway)
1. Railway → New Project → **Deploy from GitHub repo** → ce dépôt, branche `claude/gifted-dijkstra-yjxzvf` (ou `main` après fusion). Service : dossier racine **`backend`**.
2. Base de données : soit **+ New → Database → PostgreSQL** dans Railway, soit **Supabase** (voir `deploy/supabase/README.md` : adresse du *Session pooler*, script de sécurité `02_securite.sql` OBLIGATOIRE).
3. Service serveur → Settings :
   - Le serveur est construit par son **`backend/Dockerfile`** (Railway le détecte tout seul ; `backend/railway.json` le demande explicitement). Au démarrage il lance `collectstatic`, `migrate`, puis `uvicorn`. Rien à saisir pour Build ni Start.
   - Variable `DJANGO_SETTINGS_MODULE` = `config.settings.prod` (déjà la valeur par défaut de l'image).
4. Variables du service (les valeurs sont à vous) :
   - `SECRET_KEY` : au moins 32 caractères au hasard ; `DEBUG` = `False`
   - `DATABASE_URL` : la valeur fournie par le service PostgreSQL (adresse **directe**, pas un pool en mode transaction)
   - `ALLOWED_HOSTS` : le domaine du serveur (ex. `votre-serveur.up.railway.app`)
   - `CORS_ALLOWED_ORIGINS` et `CSRF_TRUSTED_ORIGINS` : l'adresse `https://…` du tableau de bord
   - `NUM_PROXIES` = `1`
   - `SMS_PROVIDER` et `SMS_API_KEY` : le fournisseur de SMS (sans lui, personne ne reçoit de code)
   - Appels : `JITSI_DOMAIN`, `JITSI_APP_ID`, `JITSI_JWT_SECRET` (voir `JITSI.md` ; sans eux les appels sont refusés, le reste fonctionne)
   Le serveur **refuse de démarrer** si un réglage est dangereux (clé trop courte, hôtes non `https`…) : lire le message dans les journaux.
5. **Photos et pièces d'identité (obligatoire avant de vrais utilisateurs).** Les fichiers envoyés sont écrits sur le disque du serveur, qui est effacé à chaque déploiement : il faut un **Volume** Railway (un seul par service). Service → Settings → **Volumes → New Volume**, point de montage **`/data`**. Puis ces variables : `MEDIA_ROOT=/data/media`, `PRIVATE_MEDIA_ROOT=/data/private_media` et `RAILWAY_RUN_UID=0` (sans lui, l'utilisateur du conteneur ne peut pas écrire dans le Volume). Les photos publiques sont servies par le serveur sur `/media/…` ; les pièces d'identité ne sont jamais servies publiquement. Le serveur vérifié en conteneur : photo publique 200, pièce privée 404. (Plus tard : stockage objet compatible S3.)
6. Deuxième service (même dépôt, dossier `backend`) pour les sonneries oubliées : Settings → **Deploy → Custom Start Command** = `python manage.py expire_calls --loop 30` ; mêmes variables (sans Volume, sans `PORT`).
7. Créer le premier administrateur : dans Railway, ouvrir un terminal du service (ou `railway run`) : `python manage.py createsuperuser` (numéro + mot de passe saisis au clavier).
8. Test : ouvrir `https://VOTRE-SERVEUR/api/health/` → doit répondre « ok ».

## 2bis. Tableau de bord sur Railway aussi (fichiers prêts : `dashboard/Dockerfile`, `nginx.conf.template`)
Dans le même projet Railway : **+ New → GitHub Repo** → même dépôt → Settings → **Root Directory : `dashboard`** (Railway détecte le `Dockerfile`). Variable du service : `VITE_API_BASE_URL` = `https://VOTRE-SERVEUR` (sans `/api` ; lue à la construction, donc redéployer si elle change). Settings → Networking → **Generate Domain**, puis mettre cette adresse dans `CORS_ALLOWED_ORIGINS` et `CSRF_TRUSTED_ORIGINS` du serveur. L'en-tête `Permissions-Policy` (micro autorisé pour le domaine Jitsi) et la CSP complète sont à ajouter une fois le domaine Jitsi connu : voir `dashboard/README.md`. Ces fichiers n'ont pas pu être construits ici (pas de Docker) : si la construction échoue, copiez-moi le journal.

## 2ter. Application web installable (PWA) sur Railway (fichiers prêts : `mobile/Dockerfile`, `mobile/nginx.conf.template`)
C'est la même application que sur Android, dans le navigateur, installable sur l'écran d'accueil (Android et iPhone). **L'appel à l'équipe et WhatsApp depuis l'application n'y fonctionnent pas** : un message dit d'utiliser l'application Android.
1. Dans le même projet Railway : **+ New → GitHub Repo** → même dépôt.
2. Service → Settings → **Root Directory : `mobile`** (Railway détecte le `Dockerfile`).
3. Service → Variables : **`API_URL`** = `https://VOTRE-SERVEUR/api` (avec `/api`, en `https`). Elle est lue **à la construction** : si elle change, redéployez. Si elle manque ou n'est pas en https, la construction s'arrête avec un message explicite.
4. Settings → Networking → **Generate Domain** : vous obtenez `https://….up.railway.app`.
5. Dans les variables du **serveur** : ajoutez cette adresse (sans `/` final) à `CORS_ALLOWED_ORIGINS` (et `CSRF_TRUSTED_ORIGINS`), séparée par une virgule des adresses déjà présentes ; redémarrez le serveur. Sans cela, la connexion échoue dans le navigateur (erreur réseau).
6. Ouvrir l'adresse : l'écran de lancement s'affiche. Première visite : environ 3 Mo à télécharger (puis gardés en copie pour le mode hors connexion).
7. **Installer** : Android (Chrome) → menu ⋮ → « Installer l'application » ; iPhone (Safari) → bouton Partager → « Sur l'écran d'accueil ».
À savoir : les jetons de connexion sont gardés dans le stockage du navigateur (moins protégé que sur Android). Le domaine Railway généré convient pour l'essai ; un domaine à vous peut être ajouté ensuite dans Networking. Ces fichiers n'ont pas pu être construits ici de bout en bout dans Docker (disque trop petit) : si la construction échoue, copiez-moi le journal.

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

Un `.apk` est le fichier d'installation d'une application Android. Deux façons de l'obtenir ; la première n'installe rien sur votre ordinateur.

### Méthode A — GitHub construit l'APK pour vous
**A1. Enregistrer l'adresse du serveur (une seule fois, AVANT la construction).**
1. Ouvrez le dépôt sur github.com, onglet **Settings** (en haut à droite des onglets ; il faut être propriétaire du dépôt).
2. Menu de gauche : **Secrets and variables → Actions**.
3. Onglet **Secrets**, bouton vert **New repository secret**.
4. Name : `NETBUIS_API_URL` (exactement, majuscules et tiret bas).
5. Secret : l'adresse de votre serveur Railway **terminée par `/api`**, par exemple `https://votre-serveur.up.railway.app/api`. Pas d'espace, pas de `/` final après `api`.
6. **Add secret.**
⚠ Si vous oubliez ce secret, l'APK se construit quand même, mais avec une fausse adresse : l'application s'ouvrira et ne pourra rien charger.

**A2. Lancer la construction.**
La construction démarre toute seule à chaque envoi de code sur GitHub. Pour la relancer à la main (par exemple après avoir ajouté le secret) :
1. Onglet **Actions** (en haut).
2. À gauche, cliquez sur le workflow **CI**. Vous voyez la liste des exécutions ; la plus récente est en haut.
3. Cliquez sur l'exécution de la branche voulue (`claude/gifted-dijkstra-yjxzvf` ou `main`).
4. En haut à droite : **Re-run all jobs** (ou **Re-run failed jobs** si seule une étape a échoué).
5. Attendez : les tâches s'affichent avec un rond jaune (en cours), une coche verte (réussie) ou une croix rouge (échec). Les tâches sont : Serveur, Tableau de bord, Application mobile, puis **APK Android** (qui n'attend que « Application mobile »). Comptez 10 à 20 minutes au total.
(Le bouton **Run workflow** n'apparaît que si le fichier du workflow se trouve sur la branche principale du dépôt.)

**A3. Télécharger l'APK.**
1. Quand la tâche **APK Android** est verte, cliquez sur le titre de l'exécution (page de résumé).
2. Descendez tout en bas jusqu'à la section **Artifacts**.
3. Cliquez sur **`netbuis-apk-debug-signe`** : un fichier `.zip` se télécharge (connexion à GitHub obligatoire ; l'artefact est conservé 14 jours, puis il faut relancer).
4. Dézippez-le : à l'intérieur, **`app-release.apk`**. La tâche affiche aussi sa taille (étape « Taille de l'APK »).

**A4. Installer sur le téléphone Android.**
1. Envoyez `app-release.apk` au téléphone : câble USB (copier dans « Téléchargements »), Google Drive, WhatsApp ou e-mail.
2. Sur le téléphone, ouvrez le fichier (application « Fichiers » → Téléchargements → `app-release.apk`).
3. Android dit que l'installation depuis cette source est bloquée : appuyez sur **Paramètres** et activez **Autoriser depuis cette source** pour l'application qui a ouvert le fichier (Fichiers, Drive, Chrome…), puis revenez en arrière.
4. Appuyez sur **Installer**. Si « Play Protect » prévient que l'application n'est pas vérifiée (normal : signature de débogage), choisissez **Installer quand même**.
5. Ouvrez NetBuis. Il faut une connexion Internet et le serveur doit être en ligne.

**Si une tâche devient rouge :** cliquez sur la tâche, puis sur l'étape marquée d'une croix rouge : le message d'erreur s'affiche. Copiez ses dernières lignes (sans aucun secret) et envoyez-les-moi. Cette tâche n'a jamais encore tourné.

### Méthode B — sur votre ordinateur
1. Installez **Android Studio** (developer.android.com/studio) ; au premier lancement, laissez-le télécharger le SDK Android. Il fournit aussi Java 17.
2. Installez **Flutter 3.47.7** (docs.flutter.dev/get-started/install, choisissez votre système) et ajoutez son dossier `bin` au PATH.
3. Ouvrez un terminal et lancez `flutter doctor --android-licenses` (répondre `y` partout), puis `flutter doctor` : il doit afficher une coche pour « Android toolchain ».
4. Dans le dossier du projet :
```
cd mobile
flutter pub get
flutter build apk --release --dart-define=API_URL=https://VOTRE-SERVEUR/api
```
(adresse **avec** `/api`). La construction prend plusieurs minutes la première fois.
5. Le fichier est `mobile/build/app/outputs/flutter-apk/app-release.apk` (sous Windows : `mobile\build\app\outputs\flutter-apk\app-release.apk`). Installez-le comme en A4, ou, téléphone branché en USB avec le « débogage USB » activé : `flutter install`.

### Méthode C — l'APK construit dans Docker (ni Flutter ni Android Studio à installer)
Il faut seulement **Docker** (Docker Desktop sous Windows/Mac). Depuis la racine du dépôt :
```
docker build --target apk -f mobile/Dockerfile.apk --build-arg API_URL=https://VOTRE-SERVEUR/api --output type=local,dest=./sortie mobile
```
(adresse **avec** `/api`, en `https`, obligatoire). Facultatif : `--build-arg SUPPORT_WHATSAPP=… --build-arg SUPPORT_PHONE=… --build-arg SUPPORT_EMAIL=…`. Compter 15 à 30 minutes la première fois (téléchargement de Flutter, du SDK Android et de Gradle) et plusieurs Go de disque. Le fichier est `./sortie/app-release.apk` : installez-le comme en A4. Il est signé avec la clé de débogage (voir « À savoir »). **Cette méthode n'a pas pu être essayée ici** (le SDK Android n'est pas téléchargeable depuis la machine de développement) : si elle échoue, copiez-moi les dernières lignes du journal.

### Pour l'envoyer à plusieurs testeurs
Firebase App Distribution : `deploy/firebase/README.md`.

### À savoir
L'APK est signé avec la clé de **débogage** : suffisant pour essayer, pas pour le Play Store (il faudra une vraie clé de signature, créée une fois et gardée **hors du dépôt**, jamais perdue : sans elle, on ne peut plus mettre l'application à jour). Les appels ne fonctionneront qu'une fois le serveur Jitsi en place (`docs/deployment/JITSI.md`).

## 4. Vérifier
Suivre `docs/RECETTE.md`. Premier essai minimal : installer l'APK → Commencer → numéro → code SMS réel → recherche.
