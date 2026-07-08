FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG API_BASE_URL=https://aptm-backend.onrender.com
RUN flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=${API_BASE_URL} \
    && sed -i 's/main.dart.js/main.dart.js?v=aptm_personalizacion_20260708/g' build/web/flutter_bootstrap.js

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080
