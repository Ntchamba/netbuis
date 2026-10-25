# Base de données NetBuis sur Supabase

Supabase fournit un **PostgreSQL géré**. NetBuis ne s'en sert que comme base : le serveur Django s'y connecte directement. On n'utilise ni « Supabase Auth », ni son API REST, ni son stockage. **Rien n'a été déployé ni testé sur un vrai projet Supabase** : les scripts SQL ont seulement été vérifiés sur un PostgreSQL local.

## 1. Créer le projet
1. supabase.com → New project → région la plus proche de votre serveur Railway (latence) → **mot de passe de base fort, noté dans un gestionnaire de mots de passe** (jamais dans le dépôt).
2. Plan : le plan gratuit met le projet en pause après une semaine d'inactivité et limite le nombre de connexions ; pour la production, prendre un plan payant (voir « Connexions »).

## 2. Choisir la bonne adresse de connexion (point critique)
Le suivi des appels en temps réel utilise `LISTEN/NOTIFY` : il faut une connexion qui garde la même session PostgreSQL.

| Adresse (Supabase → bouton **Connect**) | Convient ? |
|---|---|
| **Direct connection** `db.<projet>.supabase.co:5432` | Oui, mais en **IPv6 seulement** (IPv4 = option payante). Railway ne sait peut-être pas joindre l'IPv6 : à tester. |
| **Session pooler** (port **5432**, hôte `…pooler.supabase.com`, utilisateur `postgres.<projet>`) | **Oui — le choix recommandé** (IPv4, garde la session). |
| **Transaction pooler** (port **6543**) | **NON** : `LISTEN` ne fonctionne pas, les appels ne sonneraient jamais. |

Copiez l'adresse exacte depuis le bouton Connect (ne la reconstituez pas à la main) et ajoutez `?sslmode=require` à la fin. Mettez-la dans les variables du serveur Railway :
- `DATABASE_URL` = adresse du Session pooler (ou directe) + `?sslmode=require`
- `CALLS_LISTEN_DATABASE_URL` = la même adresse (obligatoire si `DATABASE_URL` passait par un pool en mode transaction ; ici identique).

## 3. Connexions (dimensionnement)
Chaque agent connecté au tableau de bord garde **1 connexion** (T122), plus celles des processus du serveur (2 workers) et du service `expire_calls`. Le Session pooler n'a qu'un nombre limité de connexions simultanées selon le plan (vérifier dans Supabase → Settings → Database). Pour 50 agents, compter ≈ 80 connexions : au-delà de la limite du plan, prendre un plan supérieur ou la connexion directe.

## 4. Mettre en place (dans cet ordre)
1. (Facultatif) SQL Editor → coller `01_extensions.sql` → Run. Sinon la migration Django les crée toute seule.
2. Lancer les migrations depuis le serveur (Railway : la commande de démarrage fait `python manage.py migrate`) ou depuis votre ordinateur avec `DATABASE_URL` exportée dans le terminal.
3. SQL Editor → coller **`02_securite.sql`** → Run. **Ne pas sauter cette étape** : sans elle, les tables (donc les numéros de téléphone) sont lisibles depuis Internet avec la clé publique de Supabase. Rejouer ce script après toute migration qui ajoute une table.
4. En plus : Supabase → Settings → **API** (Data API) → désactiver l'exposition du schéma `public` si l'option existe : NetBuis n'en a pas besoin.
5. SQL Editor → `03_verifier.sql` : aucune ligne dans les deux contrôles de sécurité, deux extensions présentes.
6. Créer le premier administrateur : `python manage.py createsuperuser`.

## 5. Sauvegardes
Les sauvegardes quotidiennes automatiques dépendent du plan (vérifier dans Supabase → Database → Backups). En plus : `pg_dump` régulier (voir `backend/README.md`) vers un stockage chiffré hors du dépôt, et un essai de restauration avant la mise en service.

## 6. Ce que Supabase ne règle pas
- **Les photos et pièces d'identité** restent écrites sur le disque du serveur (`media/`, `private_media/`) : Volume Railway, ou plus tard un stockage objet (Supabase Storage est compatible S3, mais NetBuis ne sait pas encore l'utiliser : tâche à créer).
- **Changer le mot de passe PostgreSQL** de l'ancien `.env` qui reste dans l'historique de `main`.
