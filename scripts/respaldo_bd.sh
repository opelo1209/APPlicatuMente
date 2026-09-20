#!/usr/bin/env bash
#
# Respaldo diario de la base de datos de APTM en ml.izt.uam.mx.
#
# Guarda un volcado comprimido de la base `aptm` en /opt/aptm/respaldos,
# comprueba que el archivo sea legible y conserva los ultimos 14 dias.
# Lo ejecuta cron con el usuario que despliega; no necesita sudo.
#
# Contiene datos personales de menores de edad: los archivos se crean con
# permisos 600 (solo el usuario duenno puede leerlos).
#
# Restaurar:
#   pg_restore -h 127.0.0.1 -U aptm -d aptm --clean --if-exists <archivo>
set -euo pipefail

CONFIG="/etc/aptm/aptm.env"
DESTINO="/opt/aptm/respaldos"
DIAS_A_CONSERVAR=14

registrar() { printf '%s %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }

# La contraseña se lee del mismo archivo que usa el backend y nunca se
# imprime ni se pasa como argumento (los argumentos son visibles para
# cualquier usuario del servidor con `ps`).
DATABASE_URL=$(sed -n 's/^DATABASE_URL=//p' "$CONFIG")
if [ -z "$DATABASE_URL" ]; then
  registrar "ERROR: no se pudo leer DATABASE_URL de $CONFIG"
  exit 1
fi

mkdir -p "$DESTINO"
chmod 700 "$DESTINO"

ARCHIVO="$DESTINO/aptm-$(date +%Y%m%d-%H%M).dump"

# -Fc: formato propio de PostgreSQL, comprimido y restaurable por partes.
if ! pg_dump --dbname="$DATABASE_URL" --format=custom --file="$ARCHIVO"; then
  registrar "ERROR: fallo pg_dump; no se genero respaldo"
  rm -f "$ARCHIVO"
  exit 1
fi

chmod 600 "$ARCHIVO"

# Un archivo puede escribirse y aun asi estar corrupto: se comprueba que
# PostgreSQL pueda leer su indice antes de darlo por bueno.
if ! pg_restore --list "$ARCHIVO" > /dev/null 2>&1; then
  registrar "ERROR: el respaldo $ARCHIVO no es legible; se elimina"
  rm -f "$ARCHIVO"
  exit 1
fi

TAMANO=$(du -h "$ARCHIVO" | cut -f1)
TABLAS=$(pg_restore --list "$ARCHIVO" | grep -c "TABLE DATA" || true)
registrar "respaldo correcto: $(basename "$ARCHIVO") ($TAMANO, $TABLAS tablas con datos)"

# Limpieza: se borran los mas viejos, pero solo si quedo al menos uno nuevo.
BORRADOS=$(find "$DESTINO" -name 'aptm-*.dump' -type f -mtime +$DIAS_A_CONSERVAR -print -delete | wc -l)
if [ "$BORRADOS" -gt 0 ]; then
  registrar "eliminados $BORRADOS respaldos de mas de $DIAS_A_CONSERVAR dias"
fi

TOTAL=$(find "$DESTINO" -name 'aptm-*.dump' -type f | wc -l)
registrar "respaldos guardados: $TOTAL"
