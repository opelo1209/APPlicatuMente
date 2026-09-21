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
# imprime ni se pasa como argumento: los argumentos de un proceso son
# visibles para cualquier usuario del servidor con `ps`, y el servidor es
# compartido. Se entrega a pg_dump por variables de entorno (PGPASSWORD y
# demás), que en Linux solo puede leer el dueño del proceso
# (/proc/<pid>/environ tiene permisos 400).
#
# La URL se separa con expansiones de bash, que ocurren dentro de este mismo
# proceso: pasarla a sed, cut o python la volvería a exponer en `ps`.
DATABASE_URL=$(sed -n 's/^DATABASE_URL=//p' "$CONFIG")
if [ -z "$DATABASE_URL" ]; then
  registrar "ERROR: no se pudo leer DATABASE_URL de $CONFIG"
  exit 1
fi

# Formato esperado: postgresql://usuario:contraseña@host:puerto/base
# (la contraseña la genera `openssl rand -hex 24`, así que no lleva ni `@`
# ni `:` que rompan la separación).
SIN_ESQUEMA=${DATABASE_URL#postgresql://}
CREDENCIALES=${SIN_ESQUEMA%%@*}
SERVIDOR=${SIN_ESQUEMA#*@}
HOST_PUERTO=${SERVIDOR%%/*}

export PGUSER=${CREDENCIALES%%:*}
export PGPASSWORD=${CREDENCIALES#*:}
export PGHOST=${HOST_PUERTO%%:*}
export PGPORT=${HOST_PUERTO##*:}
export PGDATABASE=${SERVIDOR#*/}
unset DATABASE_URL SIN_ESQUEMA CREDENCIALES SERVIDOR HOST_PUERTO

# Si la URL no tenía la forma esperada, alguna parte queda vacía o igual a
# otra; se detiene en lugar de intentar conectarse con datos incorrectos.
if [ -z "$PGUSER" ] || [ -z "$PGPASSWORD" ] || [ -z "$PGHOST" ] \
   || [ -z "$PGPORT" ] || [ -z "$PGDATABASE" ] || [ "$PGUSER" = "$PGPASSWORD" ]; then
  registrar "ERROR: DATABASE_URL de $CONFIG no tiene la forma esperada"
  exit 1
fi

mkdir -p "$DESTINO"
chmod 700 "$DESTINO"

ARCHIVO="$DESTINO/aptm-$(date +%Y%m%d-%H%M).dump"

# -Fc: formato propio de PostgreSQL, comprimido y restaurable por partes.
# La conexión sale de las variables PG*: el comando no lleva la contraseña.
if ! pg_dump --format=custom --file="$ARCHIVO"; then
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
