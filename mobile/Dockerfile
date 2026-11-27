# NetBuis PWA (version web de l'application Flutter) pour Railway : construction puis nginx.
#   Railway : service avec « Root Directory » = mobile ; variable API_URL (lue à la CONSTRUCTION) =
#   https://VOTRE-SERVEUR/api . Voir docs/deployment/GUIDE_JEFF.md.
FROM debian:bookworm-slim AS build
ARG FLUTTER_VERSION=3.47.7
ARG API_URL
ENV PATH=/opt/flutter/bin:$PATH

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git curl unzip xz-utils zip \
 && rm -rf /var/lib/apt/lists/*

# Flutter : le tag exact, sans l'historique.
RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git /opt/flutter \
 && git config --global --add safe.directory /opt/flutter \
 && flutter config --no-analytics \
 && flutter precache --web

WORKDIR /app
# Les dépendances d'abord : cette couche reste en cache tant que pubspec.* ne change pas.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .

# Version de production : l'adresse de l'API doit être en https (l'application la refuse sinon).
# --no-web-resources-cdn : le moteur CanvasKit est copié dans le site (pas téléchargé chez Google),
# ce qui permet le démarrage hors connexion une fois l'application installée.
RUN case "$API_URL" in \
      https://?*) ;; \
      *) echo "ERREUR : la variable API_URL doit etre definie et commencer par https:// (ex. https://serveur.up.railway.app/api)" >&2; exit 1 ;; \
    esac \
 && flutter build web --release --no-web-resources-cdn --dart-define=API_URL="${API_URL}"

FROM nginx:1.27-alpine
# Les fichiers de /etc/nginx/templates sont traités au démarrage : ${PORT} vient de Railway.
ENV PORT=8080
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html
