# Serveur ASGI et PostgreSQL pour les appels temps réel (T131)

Rien n'est déployé : ce sont les consignes pour le jour venu. L'exploitation de Jitsi lui-même (JaaS ou auto-hébergé) est décrite par la tâche T135.

## Pourquoi ASGI

Les tableaux de bord des agents et les téléphones des appelants reçoivent les événements d'appel par un flux **SSE** (`GET /api/admin/calls/stream/`, `GET /api/calls/sessions/<id>/events/`) : une réponse HTTP qui reste ouverte. Cela demande un serveur **ASGI** ; `gunicorn` en mode WSGI classique garderait un processus occupé par flux.

Les événements viennent de **PostgreSQL `LISTEN/NOTIFY`** : aucune infrastructure en plus (ni Redis, ni file de messages), et cela fonctionne avec plusieurs processus ou plusieurs serveurs, car tous écoutent la même base.

## Dépendance ajoutée

`uvicorn==0.54.0` (`backend/requirements/base.txt`, donc développement et production). Il n'y avait aucun serveur ASGI installé ; Django seul (`config/asgi.py`, déjà présent) ne suffit pas à écouter un port. `PyJWT` (jetons Jitsi HS256) était déjà installé comme dépendance de `djangorestframework-simplejwt`.

## Commande de démarrage

```bash
cd backend
DJANGO_SETTINGS_MODULE=config.settings.prod \
  uvicorn config.asgi:application --host 0.0.0.0 --port "$PORT" --workers 2 \
  --timeout-keep-alive 75 --no-access-log
```

- `--no-access-log` : les journaux d'accès d'un serveur web ne doivent pas lister les adresses de flux ni les jetons (voir `DEPLOYMENT.md`).
- Les flux envoient un battement (`: keepalive`) toutes les 5 secondes : les proxys qui coupent les connexions silencieuses (60 s) ne les ferment pas.
- Derrière nginx : `proxy_buffering off;` (ou l'en-tête `X-Accel-Buffering: no`, déjà posé par l'application), `proxy_read_timeout 1h;`, `proxy_http_version 1.1;`.
- Développement local : `python manage.py runserver` sert aussi l'ASGI (Django ≥ 5), ou la commande `uvicorn` ci-dessus avec `config.settings.dev`.

## PostgreSQL : connexion DIRECTE obligatoire pour `LISTEN`

`LISTEN` exige une connexion qui reste attachée à la même session PostgreSQL. **Un pool en mode « transaction » (pgbouncer, pooler de Neon, etc.) ne convient pas pour `LISTEN`** : les notifications se perdent.

- Si `DATABASE_URL` pointe sur PostgreSQL directement : rien à faire.
- Si `DATABASE_URL` passe par un pool en mode transaction : définir `CALLS_LISTEN_DATABASE_URL` avec l'adresse **directe** de la même base (même format que `DATABASE_URL`). Les requêtes normales (dont `pg_notify`, qui part dans la transaction de l'appel) peuvent rester sur le pool.
- Chaque flux ouvert garde **une** connexion `LISTEN` : prévoir `max_connections` de PostgreSQL ≥ (processus × connexions normales) + (agents connectés + appels en cours) + marge. Mesuré (T122) sur un vrai `uvicorn` : 50 agents connectés = environ 50 connexions de flux, environ 76 au total avec les appels, l'API et les connexions réservées ; le défaut de 100 suffit mais la marge est faible au-delà d'environ 80 flux : prévoir 200 ou plus. Mémoire : environ 0,75 Mo par flux. Voir `docs/verifications/T122-backend.md`.

## Tâche planifiée : fermer les sonneries oubliées

Les sonneries qui dépassent 30 s sont fermées (`missed`) par quatre moyens, du plus fin au plus grossier : le flux de l'appelant, la consultation de l'appelant, le battement de chaque flux agent (toutes les 5 s), et la commande :

```bash
python manage.py expire_calls            # une passe
python manage.py expire_calls --loop 30 # processus dédié, toutes les 30 s
```

À planifier **toutes les minutes** (cron de l'hébergeur) pour le cas où aucun agent n'est connecté. Elle ferme aussi les appels « en cours » vieux de plus de 4 heures (`CALL_MAX_DURATION`). Sûre à lancer en plusieurs exemplaires.

## Variables d'environnement (noms seulement)

| Variable | Rôle |
|---|---|
| `JITSI_DOMAIN` | domaine du serveur Jitsi (sans `https://`) |
| `JITSI_APP_ID` | identifiant d'application (champ `iss` du jeton) |
| `JITSI_JWT_SECRET` | secret du jeton HS256, **32 caractères au moins** ; absent ou trop court = les appels sont refusés (503 `jitsi_not_configured`) |
| `CALLS_LISTEN_DATABASE_URL` | connexion PostgreSQL directe pour `LISTEN` (facultative, voir ci-dessus) |

Durées (dans `config/settings/base.py`, non modifiables par l'environnement) : sonnerie 30 s, jeton Jitsi 120 s, présence d'un agent 25 s.

## Limite connue : JaaS (8x8)

Le jeton émis est signé **HS256** avec un secret partagé (cas du Jitsi auto-hébergé avec le module `token`). D'après la documentation de JaaS, ce service signe ses jetons en RS256 avec une clé privée et un identifiant de clé (`kid`) : ce n'est pas implémenté ici. À trancher avec la question ouverte Q1 / décision D-28 avant tout essai avec JaaS.
