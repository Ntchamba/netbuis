> **Note** : le squelette du projet se trouve dans le sous-dossier `netbuis/` (créé à l'extraction du zip).
> Ouvrir `netbuis/netbuis.code-workspace` dans VS Code. Pour tout avoir à la racine, déplacer le contenu de `netbuis/` ici (glisser-déposer dans l'explorateur de VS Code), puis supprimer ce paragraphe.

# NetBuis — Super-App Métier

Trouver un produit auprès des commerçants locaux (Cameroun), voir la liste, appeler directement
(téléphone / WhatsApp), payer par Mobile Money (CamPay), forum, tendances, dashboard d'administration.

## Où est quoi

| Dossier | Contenu | Techno |
|---|---|---|
| `backend/` | API, base de données, règles métier | Django 5.2 LTS + DRF + PostgreSQL |
| `mobile/` | Application Android | Flutter |
| `dashboard/` | Administration web | React (Vite + TypeScript + Tailwind) |
| `docs/` | Architecture, contrat d'API, paiements, sécurité, décisions | Markdown / OpenAPI |
| `agents/` | Consignes de l'orchestrateur et des 3 agents | Markdown |
| `deploy/` | Réservé (déploiement reporté) | — |

**Règle d'or** : un dossier = un propriétaire (voir `AGENTS.md`). Lire `docs/MODULES.md` pour savoir où écrire quoi.

## Démarrage du backend (quand on implémente)

```
docker compose up -d db
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements/dev.txt
cp .env.example .env
python manage.py check
```

⚠️ Avant la première migration : implémenter `User` (tâche A.4) et activer `AUTH_USER_MODEL` dans `config/settings/base.py`.

## État

Squelette uniquement : les fichiers existent, le code reste à écrire. Paiements : vides jusqu'à É6.
Déploiement (Railway / Vercel) et configuration CamPay : reportés.
