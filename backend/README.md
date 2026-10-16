# NetBuis — backend (Django + DRF + PostgreSQL)

## Installer et lancer (développement)

```
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements/dev.txt
cp .env.example .env        # puis remplir backend/.env (jamais versionné)
python manage.py migrate
python manage.py runserver
```

Vérifications : `ruff check . && python manage.py makemigrations --check --dry-run && pytest -q`.

Les secrets (mot de passe PostgreSQL, `SECRET_KEY`, clés SMS ou de paiement) ne se trouvent
que dans `backend/.env` ou dans les variables d'environnement du serveur. Ils ne sont jamais
écrits dans le dépôt, un test, un journal ou un message de commit.

## Créer le premier administrateur (décision D-14)

Le premier administrateur se crée **en ligne de commande**, sur la machine qui a accès à la base :

```
python manage.py createsuperuser
```

1. La commande demande le **numéro de téléphone** (mobile camerounais, `6XXXXXXXX`, avec ou
   sans `+237`) ; il est enregistré au format `+2376XXXXXXXX`.
2. Elle demande ensuite le **mot de passe**, deux fois, **au clavier** (rien ne s'affiche
   pendant la saisie). Le mot de passe n'est jamais passé en argument ni dans une variable
   d'environnement, et n'est écrit dans aucun fichier du dépôt.
3. Le compte créé a `is_admin=True` (administrateur NetBuis), `is_staff=True` (accès à
   l'admin Django, `/django-admin/`) et `is_superuser=True`.

Ce compte peut ensuite se connecter au dashboard par `POST /api/auth/admin/login/` et à
l'admin Django. Les groupes d'administration (« Validateur », « Administrateur complet »)
arrivent en T070 ; les administrateurs suivants seront créés depuis le dashboard.

Changer le mot de passe d'un administrateur : `python manage.py changepassword +2376XXXXXXXX`
(le mot de passe est, là aussi, saisi au clavier).

Les clients et les commerçants n'ont **pas** de mot de passe : ils se connectent par code SMS.

## Droits sur les routes de l'API

- Par défaut, toute route exige un compte connecté **ni bloqué ni supprimé**
  (`apps.accounts.permissions.IsAuthenticatedNotBlocked`) : un jeton d'accès encore valable
  est refusé dès que le compte est bloqué ou supprimé.
- Routes publiques (déclarées `AllowAny`) : `auth/otp/request/`, `auth/otp/verify/`,
  `auth/refresh/`, `auth/logout/`, `auth/admin/login/`, `health/`.
- `IsActiveBusinessOwner` : compte business au statut « actif ».
- `IsAdminRole` : provisoire (`is_admin`) ; remplacé par les groupes en T070.

## Compte de l'utilisateur : `/api/me/`

- `GET` : identité (numéro **masqué** `+237 6•• •• •• 12`, nom, langue, `has_business`).
  `free_call_available` et `credits_balance` valent `null` tant que les crédits sont
  désactivés (`CREDITS_ENABLED=False`).
- `PATCH` : nom et langue (`fr` ou `en`).
- `DELETE` : suppression **douce** (D-09) — le compte est marqué supprimé, ses jetons sont
  invalidés, ses données restent ; une reconnexion avec ce numéro reçoit « Contactez le support ».
