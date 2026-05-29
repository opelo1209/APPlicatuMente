#!/usr/bin/env sh
set -eu

API_BASE_URL="${API_BASE_URL:-http://localhost:8001}"
COMMAND="${1:-build}"

run_with_local_flutter() {
  flutter pub get

  case "$COMMAND" in
    build)
      flutter build web --release --pwa-strategy=none \
        --dart-define="API_BASE_URL=${API_BASE_URL}"
      ;;
    run)
      flutter run -d chrome --dart-define="API_BASE_URL=${API_BASE_URL}"
      ;;
    pub-get)
      ;;
    *)
      echo "Uso: $0 [build|run|pub-get]" >&2
      exit 2
      ;;
  esac
}

run_with_docker() {
  case "$COMMAND" in
    build)
      docker build \
        --build-arg "API_BASE_URL=${API_BASE_URL}" \
        -t aptm-frontend:local \
        .
      ;;
    pub-get)
      docker run --rm \
        -v "$PWD:/app" \
        -w /app \
        ghcr.io/cirruslabs/flutter:stable \
        flutter pub get
      ;;
    run)
      echo "Flutter no esta instalado localmente. Para servir con Docker usa:" >&2
      echo "  docker compose -f ../aplicate_por_tu_mente/compose.yaml up --build frontend" >&2
      exit 2
      ;;
    *)
      echo "Uso: $0 [build|run|pub-get]" >&2
      exit 2
      ;;
  esac
}

if command -v flutter >/dev/null 2>&1; then
  run_with_local_flutter
else
  run_with_docker
fi
