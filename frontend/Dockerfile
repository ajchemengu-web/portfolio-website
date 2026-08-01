# Multi-stage build: compile the Flutter Web app, then serve the static
# output with nginx. Railway (or any Docker host) only needs this one file.
#
# API_BASE_URL must point at the live backend's /api root, e.g.
# https://portfolio-website-production-86df.up.railway.app/api
# Railway passes service Variables of the same name as build ARGs
# automatically when the ARG is declared below — just set API_BASE_URL as a
# Variable on this service in the Railway dashboard.

# ---- Stage 1: build ---------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

ARG API_BASE_URL
ENV API_BASE_URL=${API_BASE_URL}

# Copy dependency manifest first so `flutter pub get` is cached unless
# pubspec.yaml actually changes.
COPY pubspec.yaml ./
RUN flutter pub get

COPY . .
RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL}

# ---- Stage 2: serve ----------------------------------------------------------
FROM nginx:1.27-alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# Railway injects $PORT at runtime; nginx's official entrypoint runs
# envsubst over every file in /etc/nginx/templates/*.template before start,
# substituting only variables that actually exist in the environment (so
# nginx's own $uri/$host variables are left untouched).
ENV PORT=8080
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
