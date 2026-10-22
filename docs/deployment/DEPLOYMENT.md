# Déploiement — REPORTÉ

Décision de Jeff : on s'en occupe plus tard. Notes conservées :

- Backend Django prévu sur Railway ; dashboard prévu sur Vercel.
- Railway demande un moyen de paiement post-payé (Jeff n'a pas de carte) → blocage à résoudre ; solution de repli PostgreSQL : Neon.
- Vercel « Hobby » est non commercial.
- Dossier `deploy/` et `backend/Dockerfile` réservés pour ce moment.

## Réglages de sécurité à connaître au déploiement (T121)

Rien n'est déployé : ce sont les consignes pour le jour venu. Réglages de production : `DJANGO_SETTINGS_MODULE=config.settings.prod`. Le démarrage est **refusé** (erreur `ImproperlyConfigured`) si une variable obligatoire manque ou est dangereuse.

| Variable | Obligatoire | Règle |
|---|---|---|
| `SECRET_KEY` | oui | au moins 32 caractères, aléatoire (idéalement 64), jamais la clé de développement |
| `UPLOAD_SIGNING_KEY` | non | si fournie : mêmes règles ; sinon `SECRET_KEY` sert |
| `DATABASE_URL` | oui | fournie par l'hébergeur |
| `ALLOWED_HOSTS` | oui | noms de domaine exacts, séparés par des virgules, sans `*` |
| `CORS_ALLOWED_ORIGINS`, `CSRF_TRUSTED_ORIGINS` | oui | origines `https://…` exactes (adresse du dashboard), sans `*` |
| `NUM_PROXIES` | oui derrière un proxy | `1` derrière Railway (un seul proxy de confiance) ; sinon toutes les limites de débit « par IP » (code SMS, connexion administrateur) comptent l'IP du proxy et bloquent tout le monde ensemble |
| `SECURE_SSL_REDIRECT` | non (vrai) | laisser vrai ; la sonde `/api/health/` est exemptée de la redirection |
| `SECURE_HSTS_INCLUDE_SUBDOMAINS`, `SECURE_HSTS_PRELOAD` | non (faux) | à passer à `True` seulement quand le domaine définitif est connu et que TOUS ses sous-domaines sont en HTTPS (la liste « preload » est quasi irréversible) ; `manage.py check --deploy` signale ces deux points (W005, W021) tant qu'ils sont faux |
| `API_DOCS_ENABLED` | non (faux) | `/api/schema/` et `/api/docs/` sont fermés en production |
| `DJANGO_ADMIN_PATH` | non (vide = admin Django fermé) | si besoin : chemin d'au moins 12 caractères qui finit par `/`, pas `admin/` ni `django-admin/` (ex. `gestion-x7k2p9q4/`). Ce formulaire n'a pas de limite d'essais : préférer le laisser fermé |

Derrière un proxy : `SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")` est actif. Le proxy **doit écraser** `X-Forwarded-Proto` (Railway le fait) ; sinon un client pourrait se faire passer pour une connexion HTTPS.

### Masquer les jetons dans les journaux d'accès du serveur

Deux familles d'adresses portent un jeton signé dans le chemin : `/api/uploads/local/<jeton>/` (envoi, valable 15 min) et `/api/admin/private-files/<jeton>/` (pièce d'identité, valable 5 min, inutilisable sans le jeton de connexion de l'administrateur désigné). Django masque déjà ces chemins dans ses propres journaux (`apps/admin_panel/log_filters.py`). Les journaux des serveurs web, eux, ne sont pas couverts :

- **gunicorn** : ne pas activer son journal d'accès (pas d'option `--access-logfile`) ; laisser seul le proxy journaliser les requêtes.
- **nginx** (si utilisé) : ne jamais journaliser `$request` ni `$request_uri` tels quels ; utiliser :

```nginx
map $request_uri $uri_sans_jeton {
    ~^(?<debut>/api/(?:uploads/local|admin/private-files)/)[^/?]+(?<fin>.*)$  "${debut}[masque]${fin}";
    default $request_uri;
}
log_format netbuis '$remote_addr [$time_local] "$request_method $uri_sans_jeton" $status $body_bytes_sent';
access_log /var/log/nginx/access.log netbuis;
error_log  /var/log/nginx/error.log crit;   # les niveaux plus bas citent la requête complète
```

- **Railway** (journaux HTTP de la plateforme) : le chemin n'est pas configurable. Risque accepté car les jetons sont de courte durée ; ne pas copier ces journaux hors de la plateforme.
