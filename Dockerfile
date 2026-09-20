FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Backend de produccion en el servidor de la universidad. Los despliegues
# anteriores (Render y despues GCP) estan fuera de servicio: dejar uno de
# ellos como valor por defecto producia builds que apuntaban a un servidor
# muerto si se omitia --build-arg.
ARG API_BASE_URL=https://ml.izt.uam.mx/aptm-api
ARG GOOGLE_CLIENT_ID=""

# Marca de version. Antes era una cadena escrita a mano que llevaba semanas
# sin cambiar, asi que no servia para saber que habia publicado. Ahora la
# inyecta CI con el hash del commit; el valor por defecto identifica los
# builds hechos a mano.
ARG BUILD_SHA=local

# La app no vive en la raiz de un dominio, sino en https://ml.izt.uam.mx/aptm/.
# Sin esto el navegador buscaria main.dart.js en la raiz del servidor.
ARG BASE_HREF=/aptm/

# Los ARG se citan aqui: un valor con un espacio de mas (facil de pegar mal
# en un secret de CI) sin comillas se parte en varias palabras y Flutter
# interpreta el fragmento sobrante como si fuera el archivo de entrada
# ("Target file ... not found"), en vez de como el valor de un solo --dart-define.
RUN flutter build web --release --pwa-strategy=none \
    --base-href "${BASE_HREF}" \
    --dart-define=API_BASE_URL="${API_BASE_URL}" \
    --dart-define=GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID}" \
    --dart-define=BUILD_SHA="${BUILD_SHA}" \
    && sed -i "s/main.dart.js/main.dart.js?v=${BUILD_SHA}/g" build/web/flutter_bootstrap.js \
    && sed -i "s/}$/,\"build_sha\":\"${BUILD_SHA}\"}/" build/web/version.json

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080
