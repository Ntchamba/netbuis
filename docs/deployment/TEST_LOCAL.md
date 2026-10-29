# Tester NetBuis en local (sur votre ordinateur) — pas à pas

Objectif : lancer le serveur, la base et le tableau de bord chez vous avec Docker, puis essayer l'application mobile contre ce serveur. Rien n'est envoyé sur Internet. **Réglages de développement seulement** (mots de passe jetables, `DEBUG=True`) : jamais en production.

## 1. Installer Docker (Ubuntu)
```
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
```
Fermez puis rouvrez la session (ou redémarrez), puis vérifiez : `docker compose version`.

## 2. Récupérer le code
```
git clone https://github.com/Ntchamba/netbuis.git
cd netbuis
git checkout claude/gifted-dijkstra-yjxzvf
```
(Le dépôt est privé : Git demande votre identifiant GitHub et un *jeton d'accès personnel* à la place du mot de passe — GitHub → Settings → Developer settings → Personal access tokens, droit « Contents : lecture ». Ne collez jamais ce jeton dans un message.)

## 3. Lancer
```
docker compose up --build
```
Première fois : 5 à 10 minutes. Quand les messages se calment, ouvrez un **deuxième terminal** dans le même dossier :
- Serveur : http://localhost:8000/api/health/ (doit répondre « ok »)
- Documentation de l'API (développement) : http://localhost:8000/api/docs/
- Tableau de bord : http://localhost:8080

## 4. Préparer les données (deuxième terminal)
```
docker compose exec api python manage.py load_zones
docker compose exec api python manage.py seed_referentials
docker compose exec api python manage.py seed_demo --count 50
docker compose exec api python manage.py createsuperuser
```
Les trois premières chargent les villes, les secteurs et 50 commerces **fictifs** ; la dernière crée votre administrateur (numéro puis mot de passe saisis au clavier). Connectez-vous ensuite sur http://localhost:8080.

## 5. Le code de connexion par SMS
En local, aucun vrai SMS n'est envoyé : le « SMS » s'écrit dans les journaux du serveur. Pendant que l'application demande le code :
```
docker compose logs -f api
```
Cherchez la ligne `[SMS console] au numéro finissant par 12 : …` : le code à 6 chiffres est dedans.

## 6. L'application mobile contre ce serveur
Il faut **Flutter 3.47** installé (voir `mobile/README.md`).
- **Dans Chrome (le plus simple, aucun téléphone) :**
  `cd mobile && flutter pub get && flutter run -d chrome --dart-define=API_URL=http://localhost:8000/api`
  (l'appel n'est pas disponible en version web.)
- **Émulateur Android :** `flutter run --dart-define=API_URL=http://10.0.2.2:8000/api` (10.0.2.2 = votre ordinateur vu depuis l'émulateur).
- **Vrai téléphone sur le même Wi-Fi :** `flutter run --dart-define=API_URL=http://ADRESSE_DE_VOTRE_PC:8000/api` (téléphone branché en USB avec le débogage activé). Le pare-feu de l'ordinateur doit laisser passer le port 8000.
- **Sans serveur du tout (fausses données) :** `flutter run -d chrome --dart-define=USE_FAKE_API=true` ; le code de connexion est toujours `123456`.
En mode développement l'application accepte `http` ; en version finale elle exige `https`.

## 7. Les appels (Jitsi)
Les appels demandent un serveur Jitsi : sans lui, le serveur répond « Jitsi non configuré » et l'écran d'appel affiche une erreur. Deux façons de les essayer en local :
- l'essai automatique, qui simule Jitsi : `node scripts/e2e_appel/bout_en_bout.mjs` (voir `docs/verifications/T134.md`) ;
- un vrai Jitsi : `deploy/vps/jitsi.sh` sur un VPS (`docs/deployment/VPS_CONTABO.md`).
Le tableau de bord reçoit les sonneries : connectez-vous, cliquez sur **Disponible**, autorisez le son.

## Si un port est déjà utilisé
Message du genre « address already in use » : un autre programme (souvent un PostgreSQL installé sur l'ordinateur) occupe le port. La base de ce `docker-compose.yml` est publiée sur `127.0.0.1:5433` (et non 5432) pour éviter ce cas ; pour 8000 (serveur) ou 8080 (tableau de bord), changez le premier nombre de la ligne `ports:` du service concerné, ou arrêtez l'autre programme (`sudo ss -ltnp | grep :8000` pour le trouver).

## 8. Arrêter, repartir de zéro
- Arrêter : Ctrl+C dans le premier terminal, ou `docker compose down`.
- Tout effacer (base et fichiers envoyés) : `docker compose down -v`.

## 9. Lancer les tests
Serveur : `cd backend && python -m venv .venv && source .venv/bin/activate && pip install -r requirements/dev.txt && pytest -q` (une base PostgreSQL locale : `docker compose up -d db`, puis `DATABASE_URL=postgres://netbuis:netbuis@localhost:5433/netbuis`).
Tableau de bord : `cd dashboard && npm ci && npm test`. Mobile : `cd mobile && flutter test --dart-define=USE_FAKE_API=true`.
