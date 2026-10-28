# Serveur NetBuis (Django + uvicorn) — pour Railway ou `docker compose`.
# Aucun secret dans l'image : tout vient des variables d'environnement (voir backend/.env.example).
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DJANGO_SETTINGS_MODULE=config.settings.prod

WORKDIR /app/backend

# Dépendances d'abord (couche mise en cache tant que les fichiers requirements ne changent pas).
COPY requirements/ requirements/
RUN pip install -r requirements/prod.txt

COPY . .

# Utilisateur sans droits d'administrateur. Les dossiers d'envoi (photos publiques, pièces privées)
# lui appartiennent (aussi /data, utilisé avec MEDIA_ROOT=/data/media sur un VPS : un volume Docker
# nommé monté sur /data reprend ce propriétaire). Volume Railway : voir docs/deployment/GUIDE_JEFF.md.
RUN useradd --create-home --uid 10001 app \
 && mkdir -p /app/backend/media /app/backend/private_media /app/backend/staticfiles /data/media /data/private_media \
 && chown -R app:app /app/backend/media /app/backend/private_media /app/backend/staticfiles /data
USER app

EXPOSE 8000

# Démarrage : fichiers statiques, migrations, puis le serveur ASGI (flux temps réel des appels).
# $PORT est fourni par Railway ; WEB_CONCURRENCY = nombre de processus (2 par défaut).
CMD ["sh", "-c", "python manage.py collectstatic --noinput && python manage.py migrate --noinput && exec uvicorn config.asgi:application --host 0.0.0.0 --port ${PORT:-8000} --workers ${WEB_CONCURRENCY:-2} --no-access-log"]
