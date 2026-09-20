#!/usr/bin/env bash
#
# Actualizador de APTM en ml.izt.uam.mx (despliegue "de tirón": es el servidor
# el que consulta, GitHub nunca entra aquí).
#
# Lo ejecuta cron cada pocos minutos con el usuario que despliega. En cada
# ejecución:
#   1. Pregunta a GitHub cuál es el último paquete publicado.
#   2. Si es el mismo que ya está instalado, termina sin hacer nada.
#   3. Descarga el paquete y comprueba su suma sha256 antes de tocar nada.
#   4. Instala el frontend y, si el backend cambió, lo actualiza y lo reinicia.
#
# Se instala en /opt/aptm/actualizar.sh. Ver
# documentacion/despliegue_servidor/despliegue_uam.md
set -euo pipefail

REPO="opelo1209/APPlicatuMente"
ETIQUETA="ultimo-despliegue"
DESTINO_WEB="/var/www/aptm"
DESTINO_BACKEND="/opt/aptm"
MARCA="/opt/aptm/.commit_desplegado"
SERVICIO="aptm-backend"

registrar() { printf '%s %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }

# --------------------------------------------------------------------------
# 1. Consultar la última publicación
# --------------------------------------------------------------------------
API="https://api.github.com/repos/$REPO/releases/tags/$ETIQUETA"
RESPUESTA=$(curl -sS -m 30 -H "Accept: application/vnd.github+json" "$API") || {
  registrar "ERROR: no se pudo consultar GitHub"
  exit 1
}

leer_json() { python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('$1',''))"; }

NOTAS=$(printf '%s' "$RESPUESTA" | leer_json body)
URL=$(printf '%s' "$RESPUESTA" | python3 -c "
import json,sys
datos = json.loads(sys.stdin.read())
for activo in datos.get('assets', []):
    if activo.get('name') == 'aptm-despliegue.tar.gz':
        print(activo.get('browser_download_url', ''))
        break
")
COMMIT=$(printf '%s' "$NOTAS" | sed -n 's/^ *commit: *//p' | head -1)
SHA256_ESPERADO=$(printf '%s' "$NOTAS" | sed -n 's/^ *sha256: *//p' | head -1)

if [ -z "$URL" ] || [ -z "$COMMIT" ] || [ -z "$SHA256_ESPERADO" ]; then
  registrar "ERROR: la publicación no trae paquete, commit o sha256"
  exit 1
fi

INSTALADO=$(cat "$MARCA" 2>/dev/null || echo "ninguno")
if [ "$COMMIT" = "$INSTALADO" ]; then
  exit 0 # Ya está al día: no se registra nada para no llenar la bitácora.
fi

registrar "publicación nueva: $COMMIT (instalado: $INSTALADO)"

# --------------------------------------------------------------------------
# 2. Descargar y verificar
# --------------------------------------------------------------------------
TRABAJO=$(mktemp -d /tmp/aptm-despliegue.XXXXXX)
trap 'rm -rf "$TRABAJO"' EXIT

curl -sSL -m 600 -o "$TRABAJO/paquete.tar.gz" "$URL"

SHA256_REAL=$(sha256sum "$TRABAJO/paquete.tar.gz" | cut -d' ' -f1)
if [ "$SHA256_REAL" != "$SHA256_ESPERADO" ]; then
  registrar "ERROR: la suma de verificación no coincide; no se instala nada"
  registrar "  esperado: $SHA256_ESPERADO"
  registrar "  recibido: $SHA256_REAL"
  exit 1
fi

mkdir -p "$TRABAJO/contenido"
tar -xzf "$TRABAJO/paquete.tar.gz" -C "$TRABAJO/contenido"

if [ ! -f "$TRABAJO/contenido/web/index.html" ] || [ ! -f "$TRABAJO/contenido/backend/app/main.py" ]; then
  registrar "ERROR: el paquete no tiene la estructura esperada; no se instala nada"
  exit 1
fi

# --------------------------------------------------------------------------
# 3. Instalar el frontend
# --------------------------------------------------------------------------
rsync -a --delete --chmod=D755,F644 "$TRABAJO/contenido/web/" "$DESTINO_WEB/"
registrar "frontend actualizado"

# --------------------------------------------------------------------------
# 4. Instalar el backend solo si cambió (reiniciarlo corta las sesiones en
#    curso, así que no se hace sin necesidad)
# --------------------------------------------------------------------------
# Se ignora __pycache__: lo genera Python al ejecutarse, no viene en el
# paquete, y sin excluirlo la comparación siempre ve diferencias y el
# backend se reiniciaría en cada despliegue aunque su código sea idéntico.
if ! diff -rq --exclude='__pycache__' "$TRABAJO/contenido/backend/app" "$DESTINO_BACKEND/app" > /dev/null 2>&1 \
   || ! diff -q "$TRABAJO/contenido/backend/requirements.txt" "$DESTINO_BACKEND/requirements.txt" > /dev/null 2>&1; then

  if ! diff -q "$TRABAJO/contenido/backend/requirements.txt" "$DESTINO_BACKEND/requirements.txt" > /dev/null 2>&1; then
    cp "$TRABAJO/contenido/backend/requirements.txt" "$DESTINO_BACKEND/requirements.txt"
    registrar "dependencias del backend cambiaron: instalando"
    "$DESTINO_BACKEND/.venv/bin/pip" install --quiet -r "$DESTINO_BACKEND/requirements.txt"
  fi

  rsync -a --delete --exclude='__pycache__' "$TRABAJO/contenido/backend/app/" "$DESTINO_BACKEND/app/"
  sudo -n /usr/bin/systemctl restart "$SERVICIO"
  sleep 5

  if ! curl -sf -m 10 http://127.0.0.1:8101/salud > /dev/null; then
    registrar "ERROR: el backend no responde tras reiniciar; revisar 'journalctl -u $SERVICIO'"
    exit 1
  fi
  registrar "backend actualizado y reiniciado"
fi

# --------------------------------------------------------------------------
# 5. Comprobar y dejar constancia
# --------------------------------------------------------------------------
if ! curl -sf -m 10 -o /dev/null https://ml.izt.uam.mx/aptm/; then
  registrar "AVISO: la app no responde por HTTPS tras actualizar"
fi

echo "$COMMIT" > "$MARCA"
registrar "despliegue $COMMIT completado"
