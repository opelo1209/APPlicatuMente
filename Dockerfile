FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Backend de produccion en GCP. El despliegue anterior en Render esta
# fuera de servicio: dejarlo como valor por defecto producia builds que
# apuntaban a un servidor muerto si se omitia --build-arg.
ARG API_BASE_URL=https://aptm-api-uami.duckdns.org
ARG GOOGLE_CLIENT_ID=""
RUN flutter build web --release --pwa-strategy=none \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID} \
    && sed -i 's/main.dart.js/main.dart.js?v=aptm_personalizacion_20260708/g' build/web/flutter_bootstrap.js

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080
