#!/usr/bin/env bash
# Ambiente de pruebas de APTM en mathonline.izt.uam.mx con Docker (Semana 5).
#
# El diagnóstico mostró que el servidor no tiene PostgreSQL, Python 3.12 ni
# nginx, pero sí Docker y que la cuenta está en el grupo docker. Este script
# levanta APTM completo en contenedores sin instalar nada en el sistema:
#
#   - Todo vive en ~/aptm-pruebas y en contenedores aptm-pruebas-*.
#   - La API solo escucha en 127.0.0.1:8011 (se usa por túnel SSH); la base
#     de datos no publica ningún puerto. Nada queda expuesto a internet.
#   - El código se descarga del repositorio público (rama del prototipo):
#     el archivo privado de la revisión clínica no viaja.
#   - No usa sudo. «borrar» lo quita todo.
#
# Uso, desde la raíz del repositorio en TU computadora (pide la contraseña):
#   ssh -o PubkeyAuthentication=no USUARIO@mathonline.izt.uam.mx \
#     'mkdir -p ~/aptm-pruebas && cat > ~/aptm-pruebas/pruebas.sh && bash ~/aptm-pruebas/pruebas.sh ORDEN' \
#     < scripts/pruebas_mathonline.sh
#
# ORDEN:
#   instalar    descarga código y modelo, construye la imagen y levanta todo
#               (en segundo plano, 20-40 min la primera vez)
#   estado      qué está corriendo y el final del registro
#   medir       batería del analizador (60 frases) y velocidad de Serena
#               (en segundo plano, unos 10 min)
#   resultados  imprime el resultado de «medir» (JSON)
#   borrar      quita contenedores, volúmenes, imagen y ~/aptm-pruebas

set -euo pipefail

BASE="$HOME/aptm-pruebas"
REPO_URL="https://github.com/opelo1209/APPlicatuMente.git"
RAMA="prototipo/diario-semaforo"
MODELO="qwen2.5-1.5b-instruct-q4_k_m.gguf"
MODELO_URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/$MODELO"
RED="aptm-pruebas"
DB="aptm-pruebas-db"
API="aptm-pruebas-api"
IMAGEN="aptm-pruebas-api:local"
PUERTO=8011
ESTE="$BASE/pruebas.sh"

paso() { printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$1"; }

en_segundo_plano() {  # $1 orden interna, $2 nombre del registro
  nohup bash "$ESTE" "$1" > "$BASE/$2.log" 2>&1 < /dev/null &
  echo "Corriendo en segundo plano (PID $!). Registro: ~/aptm-pruebas/$2.log"
  echo "Para ver el avance usa la orden «estado»."
}

secreto_db() {
  if [ ! -f "$BASE/.env" ]; then
    umask 077
    printf 'PG_CLAVE=%s\n' "$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)" > "$BASE/.env"
  fi
  # shellcheck disable=SC1091
  . "$BASE/.env"
}

_instalar() {
  set -x
  paso "1/5 Código (rama $RAMA)"
  if [ -d "$BASE/APPlicatuMente/.git" ]; then
    docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$BASE:/w:Z" alpine/git -C /w/APPlicatuMente pull --ff-only
  else
    docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$BASE:/w:Z" alpine/git \
      clone --depth 1 --branch "$RAMA" "$REPO_URL" /w/APPlicatuMente
  fi

  paso "2/5 Modelo de Serena ($MODELO, ~1,1 GB)"
  mkdir -p "$BASE/modelos"
  if [ ! -f "$BASE/modelos/$MODELO" ]; then
    curl -fL --retry 3 -C - -o "$BASE/modelos/$MODELO.part" "$MODELO_URL"
    mv "$BASE/modelos/$MODELO.part" "$BASE/modelos/$MODELO"
  fi

  paso "3/5 Imagen del backend (PyTorch CPU, pysentimiento, llama.cpp compilado aquí con AVX-512)"
  cat > "$BASE/Dockerfile.pruebas" <<'DOCKER'
FROM python:3.12
ENV PIP_NO_CACHE_DIR=1 PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN pip install torch==2.14.1 --index-url https://download.pytorch.org/whl/cpu
RUN pip install pysentimiento==0.7.3 transformers==5.19.0 httpx==0.28.1
RUN pip install llama-cpp-python==0.3.36
COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt
WORKDIR /app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
DOCKER
  docker build -t "$IMAGEN" -f "$BASE/Dockerfile.pruebas" "$BASE/APPlicatuMente/mock_backend"

  paso "4/5 PostgreSQL 16"
  secreto_db
  docker network inspect "$RED" > /dev/null 2>&1 || docker network create "$RED"
  docker rm -f "$DB" > /dev/null 2>&1 || true
  docker run -d --name "$DB" --network "$RED" --restart unless-stopped \
    -e POSTGRES_PASSWORD="$PG_CLAVE" -e POSTGRES_DB=aptm \
    -v aptm-pruebas-pg:/var/lib/postgresql/data postgres:16
  for _ in $(seq 1 30); do docker exec "$DB" pg_isready -U postgres > /dev/null 2>&1 && break; sleep 2; done

  paso "5/5 Backend en 127.0.0.1:$PUERTO"
  levantar_api
  set +x
  paso "LISTO. Siguiente: la orden «medir»."
}

levantar_api() {
  secreto_db
  docker rm -f "$API" > /dev/null 2>&1 || true
  docker run -d --name "$API" --network "$RED" --restart unless-stopped --memory 3g \
    -p "127.0.0.1:$PUERTO:8001" \
    -e DATABASE_URL="postgresql://postgres:$PG_CLAVE@$DB:5432/aptm" \
    -e SERENA_MODELO="/modelos/$MODELO" -e SERENA_HILOS=2 \
    -e SERENA_CANDADO=/tmp/serena.lock -e HF_HOME=/cache/hf \
    -v "$BASE/APPlicatuMente/mock_backend:/app:ro,Z" \
    -v "$BASE/modelos:/modelos:ro,Z" \
    -v aptm-pruebas-hf:/cache/hf \
    "$IMAGEN"
  for _ in $(seq 1 60); do
    curl -sf -o /dev/null "http://127.0.0.1:$PUERTO/docs" && { echo "API respondiendo"; return 0; }
    sleep 5
  done
  echo "La API no respondió en 5 minutos:"; docker logs --tail 40 "$API"; return 1
}

_medir() {
  paso "Batería (60 frases, sin modelo) y velocidad de Serena (11 mensajes, con modelo)"
  docker exec -i "$API" python - > "$BASE/resultados.json.part" <<'PY'
import json, os, secrets, statistics, sys, time
import httpx
from bateria.ejecutar import cargar_frases, correr_local, resumir

datos, sha = cargar_frases()
inicio = time.perf_counter()
filas = correr_local(datos["frases"])
bateria = resumir(filas, "local-mathonline", sha)
bateria_s = round(time.perf_counter() - inicio, 1)

import app.main as m
usuario, clave = f"bateria_{secrets.token_hex(3)}", secrets.token_urlsafe(16)
with m.db_conn() as c:
    with c.cursor() as cur:
        cur.execute(
            "INSERT INTO usuarios_estudiantes (keycloack_id, nombre_usuario, correo, password_hash, nombres, apellido_paterno)"
            " VALUES (%s, %s, %s, %s, 'Bateria', 'Prueba')",
            (f"local-{usuario}", usuario, f"{usuario}@prueba.local", m.hash_password(clave)),
        )
    c.commit()
velocidad = {}
try:
    with httpx.Client(base_url="http://127.0.0.1:8001", timeout=300) as cl:
        t = time.perf_counter()
        r = cl.post("/auth/login", json={"username": usuario, "password": clave})
        r.raise_for_status()
        velocidad["login_s"] = round(time.perf_counter() - t, 2)
        cl.headers["Authorization"] = f"Bearer {r.json()['access_token']}"
        frases = [f for f in datos["frases"] if f["id"][0] in "UP"][:11]
        tiempos, tipos = [], []
        for f in frases:
            cl.delete("/chat/historial")
            t = time.perf_counter()
            r = cl.post("/chat", json={"mensaje": f["texto"]})
            r.raise_for_status()
            tiempos.append(round(time.perf_counter() - t, 2))
            tipos.append(r.json().get("tipo"))
        cl.delete("/chat/historial")
    velocidad.update(
        primer_mensaje_s=tiempos[0],
        segundos=tiempos[1:],
        mediana_s=statistics.median(tiempos[1:]),
        maximo_s=max(tiempos[1:]),
        tipos=tipos,
    )
finally:
    with m.db_conn() as c:
        with c.cursor() as cur:
            cur.execute("DELETE FROM usuarios_estudiantes WHERE nombre_usuario = %s", (usuario,))
        c.commit()

json.dump(
    {"servidor": "mathonline.izt.uam.mx", "cpu": os.cpu_count(), "bateria_s": bateria_s,
     "bateria": bateria, "velocidad": velocidad},
    sys.stdout, ensure_ascii=False, indent=1,
)
PY
  mv "$BASE/resultados.json.part" "$BASE/resultados.json"
  paso "LISTO. Usa la orden «resultados»."
}

estado() {
  echo "== Contenedores =="
  docker ps -a --filter name=aptm-pruebas --format '{{.Names}}\t{{.Status}}'
  echo; echo "== API =="
  curl -s -o /dev/null -w 'http %{http_code}\n' "http://127.0.0.1:$PUERTO/docs" || echo "no responde"
  echo; echo "== Memoria =="; free -h
  for r in instalar medir; do
    if [ -f "$BASE/$r.log" ]; then echo; echo "== Final de $r.log =="; tail -n 8 "$BASE/$r.log"; fi
  done
}

borrar() {
  docker rm -f "$API" "$DB" > /dev/null 2>&1 || true
  docker network rm "$RED" > /dev/null 2>&1 || true
  docker volume rm aptm-pruebas-pg aptm-pruebas-hf > /dev/null 2>&1 || true
  docker image rm "$IMAGEN" > /dev/null 2>&1 || true
  rm -rf "$BASE"
  echo "Ambiente de pruebas borrado."
}

mkdir -p "$BASE"
case "${1:-}" in
  instalar)   en_segundo_plano _instalar instalar ;;
  medir)      en_segundo_plano _medir medir ;;
  estado)     estado ;;
  resultados) cat "$BASE/resultados.json" ;;
  borrar)     borrar ;;
  _instalar)  _instalar ;;
  _medir)     _medir ;;
  *) echo "Uso: pruebas.sh instalar|estado|medir|resultados|borrar" >&2; exit 2 ;;
esac
