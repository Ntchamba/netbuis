# Tableau de bord NetBuis : construction (Node) puis service statique (nginx), pour Railway.
# VITE_API_BASE_URL est lu à la CONSTRUCTION : le définir dans les variables du service Railway.
FROM node:22-alpine AS build
WORKDIR /app
ARG VITE_API_BASE_URL
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
# Les fichiers de /etc/nginx/templates sont traités au démarrage : ${PORT} vient de Railway.
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
