import hashlib
import json
import logging
import os
import threading
import re
import secrets
import time
import uuid
from contextlib import asynccontextmanager, contextmanager
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from typing import Any

import psycopg2
from fastapi import Depends, FastAPI, HTTPException, Query, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from psycopg2.extras import RealDictCursor

from . import correo
from . import limite_intentos as limite
from . import recuperacion_contrasena as recuperacion
# Semana 6: main.py se separo por temas (perfiles, modelos, esquema,
# cuestionarios, alertas a padres, vinculos y rutas de padres y admin).
from .alertas_padres import build_parent_alert  # noqa: F401  (test_columbia_s4)
from .alertas_padres import create_parent_alerts_for_session
from .config_cuestionarios import list_question_configs_by_module
from .esquema_bd import crear_esquema
from .modelos_api import (
    ActivoUpdate,
    ChangePassword,
    CuestionarioUpdate,
    DemoLogin,
    GoogleLogin,
    PasswordResetConfirm,
    PasswordResetRequest,
    UserLogin,
    UserRegister,
)
from .rutas_admin import crear_router_admin
from .rutas_padres import crear_router_padres
from .vinculos_padres import (
    ensure_curp_is_unique,
    link_parent_to_student,
    list_parent_students,
    normalize_curp,
)
from .perfiles import (
    PROFILE_ALIASES,
    PROFILE_LABELS,
    PROFILE_TABLES,
    ROLE_CAPABILITIES,
    serialize,
    user_to_dict,
)
from .memoria_sesion import reservar_proceso_unico
from .prototipo_api import ANALIZADOR, GENERADOR, MEMORIA, crear_router
from .cuentas_admin import crear_router_cuentas
from .serena_pipeline import mantener_caliente, precalentar


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:postgres@127.0.0.1:55432/aptm_tmp",
)
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
TOKEN_PREFIX = "local_access_"
# Semana 4 (H2): una sesion vence a las SESION_HORAS de creada.
SESION_HORAS_POR_OMISION = 24

# Acceso rápido de la demo: permite abrir la aplicación con un clic sobre
# cuentas de prueba ya sembradas, sin escribir usuario ni contrasena. Solo se
# activa si el despliegue pone DEMO_ENABLED=true y DEMO_ACCESS_CODE con una
# clave, y queda apagado por omision para que un despliegue normal nunca lo
# exponga por accidente.
def _leer_env_opcional(ruta: str) -> None:
    """Carga un archivo KEY=VALOR en os.environ sin pisar lo que ya existe.

    Existe para el prototipo: el archivo de entorno de systemd
    (/etc/aptm/aptm-prototipo.env) es de root y no se puede editar sin sudo,
    que es justo el punto que hoy bloquea a GOOGLE_CLIENT_ID. Este archivo lo
    escribe el propio usuario, asi que la clave de la demo se puede activar
    sin pedirle la contrasena de root a nadie. Lo que ya venga del entorno
    tiene prioridad, que es lo que dicta systemd.
    """
    try:
        with open(ruta, "r", encoding="utf-8") as fh:
            for linea in fh:
                linea = linea.strip()
                if not linea or linea.startswith("#") or "=" not in linea:
                    continue
                clave, valor = linea.split("=", 1)
                clave = clave.strip()
                if clave and clave not in os.environ:
                    os.environ[clave] = valor.strip()
    except FileNotFoundError:
        pass
    except OSError:
        pass


_leer_env_opcional(
    os.path.join(os.path.dirname(os.path.dirname(__file__)), "demo.env")
)

DEMO_ENABLED = os.getenv("DEMO_ENABLED", "false").strip().lower() in {"1", "true", "si", "yes"}
DEMO_ACCESS_CODE = os.getenv("DEMO_ACCESS_CODE", "")
# Demo de un clic (pedido para la revision del asesor): con DEMO_SIN_CLAVE los
# botones de la demo entran sin teclear clave. Solo tiene efecto si ademas
# DEMO_ENABLED esta activo, y las cuentas solo existen en la base del prototipo.
DEMO_SIN_CLAVE = os.getenv("DEMO_SIN_CLAVE", "false").strip().lower() in {"1", "true", "si", "yes"}
DEMO_USERS = {
    "estudiante": "ana_demo",
    "padre": "luis_demo",
    "madre": "maria_demo",
    "administrador": "admin_demo",
}

log = logging.getLogger("aptm")

# Semana 5 (H11): OWASP recomienda 600 000 iteraciones para PBKDF2-SHA256.
# Los hashes viejos (120 000) se actualizan solos al iniciar sesion.
PBKDF2_ITERACIONES = 600_000
# Semana 5 (H5): longitud de las contrasenas nuevas. El tope evita que una
# contrasena enorme ocupe el CPU calculando PBKDF2.
LONGITUD_MINIMA_PASSWORD = 8
LONGITUD_MAXIMA_PASSWORD = 128

security = HTTPBearer(auto_error=False)

# Semana 5 (H10): antes allow_origins=["*"]. En el servidor la app y la API
# comparten origen (ml.izt.uam.mx), asi que CORS solo hace falta en
# desarrollo, donde Flutter sirve la app en localhost con un puerto que
# cambia. CORS_ORIGENES (separados por comas) reemplaza la lista.
ORIGENES_POR_OMISION = ("https://ml.izt.uam.mx",)
ORIGEN_LOCAL = r"http://(localhost|127\.0\.0\.1)(:\d+)?"


def origenes_cors() -> list[str]:
    configurados = [o.strip().rstrip("/") for o in os.getenv("CORS_ORIGENES", "").split(",") if o.strip()]
    return configurados or list(ORIGENES_POR_OMISION)


@asynccontextmanager
async def ciclo_de_vida(_app: FastAPI):
    """Semana 5 (H10): reemplaza @app.on_event("startup"), obsoleto en
    FastAPI. Lo que se abre aqui vive hasta que el proceso termina."""
    candado = reservar_proceso_unico()
    try:
        startup()
        yield
    finally:
        candado.close()


app = FastAPI(title="APTM Front Mock Backend", lifespan=ciclo_de_vida)

app.add_middleware(
    CORSMiddleware,
    allow_origins=origenes_cors(),
    allow_origin_regex=ORIGEN_LOCAL,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)


@contextmanager
def db_conn():
    conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
    try:
        yield conn
    finally:
        conn.close()


def normalize_profile(profile: str) -> str:
    normalized = profile.strip().lower()
    if normalized not in PROFILE_ALIASES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Perfil no valido. Usa estudiante, padre o administrador.",
        )
    return PROFILE_ALIASES[normalized]


def wait_for_db() -> None:
    last_error = None
    for _ in range(30):
        try:
            with db_conn() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT 1")
            return
        except Exception as exc:
            last_error = exc
            time.sleep(1)
    raise RuntimeError(f"No se pudo conectar a Postgres: {last_error}")


def init_db() -> None:
    wait_for_db()
    with db_conn() as conn:
        with conn.cursor() as cur:
            crear_esquema(cur)
        conn.commit()


def startup() -> None:
    init_db()
    # PROTOTIPO Semana 3: con modelo configurado, se cargan pysentimiento y
    # el LLM de Serena en segundo plano para que el primer mensaje no tarde
    # el doble. Sin SERENA_MODELO (produccion, pruebas) no hace nada.
    # Cierre S3: despues sigue calentandolo si pasa SERENA_CALENTAR_CADA
    # segundos sin usarse (por omision 300; 0 lo apaga).
    if os.getenv("SERENA_MODELO"):
        threading.Thread(target=_calentar_serena, daemon=True).start()


def _calentar_serena() -> None:
    precalentar(ANALIZADOR, GENERADOR)
    mantener_caliente(ANALIZADOR, GENERADOR, float(os.getenv("SERENA_CALENTAR_CADA", "300")), threading.Event())


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    iterations = PBKDF2_ITERACIONES
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        iterations,
    )
    return f"pbkdf2_sha256${iterations}${salt}${digest.hex()}"


def verify_password(password: str, password_hash: str) -> bool:
    try:
        algorithm, iterations, salt, expected = password_hash.split("$", 3)
        if algorithm != "pbkdf2_sha256":
            return False
        digest = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            salt.encode("utf-8"),
            int(iterations),
        )
        return secrets.compare_digest(digest.hex(), expected)
    except ValueError:
        return False


def necesita_rehash(password_hash: str) -> bool:
    """Semana 5 (H11): un hash con otro numero de iteraciones que el actual.
    Semana 6: ``!=`` y no ``<``, para que los de 600 000 tambien bajen."""
    try:
        algorithm, iterations, _, _ = password_hash.split("$", 3)
        return algorithm != "pbkdf2_sha256" or int(iterations) < PBKDF2_ITERACIONES
    except ValueError:
        return True


@lru_cache(maxsize=1)
def _hash_ficticio() -> str:
    return hash_password(secrets.token_hex(16))


def verificar_sin_cuenta(password: str) -> None:
    """Si el usuario no existe se calcula un hash igual de costoso, para que
    el tiempo de respuesta no revele que cuentas existen."""
    verify_password(password, _hash_ficticio())


def validar_password(password: str) -> None:
    """Semana 5 (H5): reglas para cualquier contrasena NUEVA (registro,
    cambio y recuperacion). Las cuentas existentes siguen entrando con la
    que ya tienen."""
    if len(password) < LONGITUD_MINIMA_PASSWORD:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"La contraseña debe tener al menos {LONGITUD_MINIMA_PASSWORD} caracteres.",
        )
    if len(password) > LONGITUD_MAXIMA_PASSWORD:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"La contraseña no puede pasar de {LONGITUD_MAXIMA_PASSWORD} caracteres.",
        )


def ip_de(request: Request) -> str:
    # uvicorn corre con --proxy-headers y solo confia en Apache (127.0.0.1),
    # asi que aqui llega la IP real del cliente y no la del proxy.
    return request.client.host if request.client else "desconocida"


def latest_general_preferences(cur: Any, profile: str, user_id: int) -> dict[str, Any]:
    cur.execute(
        """
        SELECT respuestas
        FROM cuestionarios_locales
        WHERE perfil_tipo = %s
          AND id_usuario = %s
          AND tipo_cuestionario = 'informacion_general'
        ORDER BY fecha_registro DESC
        LIMIT 1
        """,
        (profile, user_id),
    )
    row = cur.fetchone()
    if not row:
        return {}
    respuestas = row.get("respuestas")
    if not isinstance(respuestas, dict):
        return {}
    preferencias = respuestas.get("preferencias")
    return preferencias if isinstance(preferencias, dict) else {}


def find_user(cur: Any, username_or_email: str) -> tuple[str, str, dict[str, Any]] | None:
    for profile, table in PROFILE_TABLES.items():
        cur.execute(
            f"""
            SELECT *
            FROM {table}
            WHERE nombre_usuario = %s OR correo = %s
            LIMIT 1
            """,
            (username_or_email, username_or_email),
        )
        row = cur.fetchone()
        if row:
            return profile, table, row
    return None


def unique_username_from_email(cur: Any, correo: str) -> str:
    base = re.sub(r"[^a-z0-9_]", "", correo.split("@")[0].lower()) or "usuario"
    candidate = base
    suffix = 1
    while True:
        exists = False
        for table in PROFILE_TABLES.values():
            cur.execute(
                f"SELECT 1 FROM {table} WHERE nombre_usuario = %s LIMIT 1",
                (candidate,),
            )
            if cur.fetchone():
                exists = True
                break
        if not exists:
            return candidate
        suffix += 1
        candidate = f"{base}{suffix}"


def ensure_unique(cur: Any, nombre_usuario: str, correo: str) -> None:
    for table in PROFILE_TABLES.values():
        cur.execute(
            f"""
            SELECT 1
            FROM {table}
            WHERE nombre_usuario = %s OR correo = %s
            LIMIT 1
            """,
            (nombre_usuario, correo),
        )
        if cur.fetchone():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="El usuario o correo ya esta registrado",
            )


def questionnaire_completion_status(cur: Any, profile: str, id_usuario: int) -> dict[str, Any]:
    cur.execute(
        """
        SELECT
            tipo_cuestionario,
            BOOL_OR(completado) AS completado,
            MAX(fecha_registro) AS ultima_respuesta
        FROM cuestionarios_locales
        WHERE perfil_tipo = %s AND id_usuario = %s
        GROUP BY tipo_cuestionario
        """,
        (profile, id_usuario),
    )

    completed: dict[str, bool] = {}
    latest: dict[str, Any] = {}
    for row in cur.fetchall():
        questionnaire_type = row["tipo_cuestionario"]
        completed[questionnaire_type] = bool(row["completado"])
        latest[questionnaire_type] = serialize(row["ultima_respuesta"])

    autolesion_done = completed.get("autolesion", False)
    suicidio_done = completed.get("suicidio", False)
    ansiedad_done = completed.get("ansiedad", False)
    general_done = completed.get("informacion_general", False)

    return {
        "cuestionario_completado": general_done,
        "modulo_autolesion_completado": autolesion_done,
        "modulo_suicidio_completado": suicidio_done,
        "modulo_ansiedad_completado": ansiedad_done,
        "ansiedad_desbloqueado": autolesion_done and suicidio_done,
        "sustancias_desbloqueado": ansiedad_done,
        "cuestionarios_completados": completed,
        "ultimas_respuestas": latest,
    }


def module_access_for_role(profile: str, progress: dict[str, Any]) -> list[dict[str, Any]]:
    capabilities = ROLE_CAPABILITIES[profile]
    autolesion_done = progress["modulo_autolesion_completado"]
    suicidio_done = progress["modulo_suicidio_completado"]
    ansiedad_done = progress["modulo_ansiedad_completado"]
    ansiedad_unlocked = progress["ansiedad_desbloqueado"]
    sustancias_unlocked = progress["sustancias_desbloqueado"]

    if capabilities["can_edit_questionnaires"]:
        return [
            {
                "id": "editar_cuestionarios",
                "title": "Editar cuestionarios",
                "enabled": True,
                "locked": False,
                "completed": False,
                "action": "edit_questionnaires",
            },
            {
                "id": "monitoreo",
                "title": "Monitorear respuestas",
                "enabled": True,
                "locked": False,
                "completed": False,
                "action": "monitor_responses",
            },
        ]

    return [
        {
            "id": "autolesion",
            "title": "Autolesiones",
            "enabled": capabilities["can_answer_questionnaires"] and not autolesion_done,
            "locked": autolesion_done,
            "completed": autolesion_done,
            "action": "answer_questionnaire",
        },
        {
            "id": "suicidio",
            "title": "Riesgo de suicidio",
            "enabled": capabilities["can_answer_questionnaires"] and not suicidio_done,
            "locked": suicidio_done,
            "completed": suicidio_done,
            "action": "answer_questionnaire",
        },
        {
            "id": "ansiedad",
            "title": "Ansiedad",
            "enabled": ansiedad_unlocked and not ansiedad_done,
            "locked": not ansiedad_unlocked or ansiedad_done,
            "completed": ansiedad_done,
            "action": "open_module",
        },
        {
            "id": "sustancias",
            "title": "Uso de sustancias",
            "enabled": sustancias_unlocked,
            "locked": not sustancias_unlocked,
            "completed": False,
            "action": "open_module",
        },
    ]


def sesion_horas() -> int:
    """Vigencia de una sesion. Se lee al usarse (demo.env se carga despues
    de importar los modulos) y un valor invalido no deja sesiones eternas."""
    try:
        horas = int(os.getenv("SESION_HORAS", ""))
    except ValueError:
        return SESION_HORAS_POR_OMISION
    return horas if horas > 0 else SESION_HORAS_POR_OMISION


def token_de(credentials: HTTPAuthorizationCredentials | None) -> str | None:
    if not credentials or not credentials.credentials.startswith(TOKEN_PREFIX):
        return None
    return credentials.credentials.replace(TOKEN_PREFIX, "", 1)


def sesion_vencida(creada: datetime, horas: int, ahora: datetime) -> bool:
    # La columna es TIMESTAMPTZ; si un entorno la tuviera sin zona, se toma
    # como UTC en lugar de fallar en cada peticion.
    if creada.tzinfo is None:
        creada = creada.replace(tzinfo=timezone.utc)
    return ahora >= creada + timedelta(hours=horas)


def crear_sesion(cur: Any, perfil_tipo: str, id_usuario: int) -> str:
    """Crea la sesion y, de paso, borra las vencidas de todos los usuarios
    (solo se borraban al usarse y la tabla crecia sin limite)."""
    cur.execute(
        "DELETE FROM sesiones_locales WHERE fecha_creacion < NOW() - make_interval(hours => %s)",
        (sesion_horas(),),
    )
    token = secrets.token_urlsafe(32)
    cur.execute(
        "INSERT INTO sesiones_locales (token, perfil_tipo, id_usuario) VALUES (%s, %s, %s)",
        (token, perfil_tipo, id_usuario),
    )
    return token


def invalidar_sesiones(cur: Any, perfil_tipo: str, id_usuario: int, excepto: str | None = None) -> None:
    """Cierra todas las sesiones de un usuario (menos `excepto`, si se da)."""
    cur.execute(
        "DELETE FROM sesiones_locales WHERE perfil_tipo = %s AND id_usuario = %s AND token IS DISTINCT FROM %s",
        (perfil_tipo, id_usuario, excepto),
    )


def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> dict[str, Any]:
    token = token_de(credentials)
    if token is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token requerido")

    with db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM sesiones_locales WHERE token = %s", (token,))
            session = cur.fetchone()
            if not session:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token invalido")
            if sesion_vencida(session["fecha_creacion"], sesion_horas(), datetime.now(timezone.utc)):
                cur.execute("DELETE FROM sesiones_locales WHERE token = %s", (token,))
                conn.commit()
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Sesion vencida")

            profile = session["perfil_tipo"]
            table = PROFILE_TABLES.get(profile)
            if not table:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Perfil invalido")

            cur.execute(f"SELECT * FROM {table} WHERE id_usuario = %s", (session["id_usuario"],))
            row = cur.fetchone()
            if not row or not row["activo"]:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuario inactivo")
            return user_to_dict(row, profile)


@app.get("/salud")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/")
def api_root() -> dict[str, Any]:
    return {
        "status": "ok",
        "service": "APTM mini backend temporal",
        "front_url": "http://localhost:8080",
        "health_url": "http://localhost:8001/salud",
        "docs_url": "http://localhost:8001/docs",
        "message": "Este puerto es solo API. Abre el front en http://localhost:8080.",
    }


@app.get("/favicon.ico", include_in_schema=False)
def favicon() -> dict[str, str]:
    return {"status": "no favicon for API"}


@app.post("/auth/register", status_code=status.HTTP_201_CREATED)
def register(user: UserRegister) -> dict[str, Any]:
    profile = normalize_profile(user.perfil_tipo)
    validar_password(user.password)

    # El registro publico no puede crear administradores. Una cuenta de
    # administrador puede leer las respuestas de TODOS los estudiantes
    # (/admin/monitoreo) y editar los cuestionarios clinicos, asi que no
    # puede quedar a un clic de distancia de cualquiera que abra la app.
    # Estas cuentas se crean desde el servidor con scripts/crear_admin.py.
    if profile == "administrador":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Las cuentas de administrador no se crean desde el registro publico.",
        )

    table = PROFILE_TABLES[profile]
    keycloack_id = f"local-{profile}-{secrets.token_hex(16)}"

    with db_conn() as conn:
        with conn.cursor() as cur:
            ensure_unique(cur, user.nombre_usuario, user.correo)
            normalized_curp = normalize_curp(user.curp)
            normalized_student_curps = [
                normalize_curp(curp)
                for curp in user.estudiantes_curps
                if normalize_curp(curp)
            ]
            if profile == "estudiante":
                if not normalized_curp:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="El CURP es obligatorio para estudiantes",
                    )
                ensure_curp_is_unique(cur, normalized_curp)
            # PROTOTIPO Semana 2: el registro de un padre ya no lo vincula
            # con un estudiante solo por su CURP (cualquiera que la conozca
            # podia hacerlo). La vinculacion se hace despues, en dos
            # sentidos (prototipo_api.py). Los CURP que lleguen se ignoran.

            if profile == "estudiante":
                cur.execute(
                    f"""
                    INSERT INTO {table} (
                        keycloack_id, nombre_usuario, correo, password_hash,
                        nombres, apellido_paterno, apellido_materno, curp,
                        fecha_nacimiento
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING *
                    """,
                    (
                        keycloack_id,
                        user.nombre_usuario,
                        user.correo,
                        hash_password(user.password),
                        user.nombres,
                        user.apellido_paterno,
                        user.apellido_materno or None,
                        normalized_curp,
                        user.fecha_nacimiento or None,
                    ),
                )
            else:
                cur.execute(
                    f"""
                    INSERT INTO {table} (
                        keycloack_id, nombre_usuario, correo, password_hash,
                        nombres, apellido_paterno, apellido_materno
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING *
                    """,
                    (
                        keycloack_id,
                        user.nombre_usuario,
                        user.correo,
                        hash_password(user.password),
                        user.nombres,
                        user.apellido_paterno,
                        user.apellido_materno or None,
                    ),
                )
            created = user_to_dict(cur.fetchone(), profile)

            linked: list[dict[str, Any]] = []
        conn.commit()

    return {
        "message": "Usuario registrado exitosamente en Postgres temporal",
        "id_usuario": created["id_usuario"],
        "keycloak_id": created["keycloack_id"],
        "perfil_tipo": created["perfil_tipo"],
        "user": created,
        "estudiantes_vinculados": linked,
    }


def _fallo_de_login(cur: Any, conn: Any, cuenta: str, ip: str) -> HTTPException:
    """Semana 5 (H5): cuenta el intento fallido y lo guarda aunque la
    peticion termine en error."""
    limite.registrar(cur, limite.LOGIN_CUENTA, cuenta)
    limite.registrar(cur, limite.LOGIN_IP, ip)
    conn.commit()
    return HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales incorrectas")


@app.post("/auth/login")
def login(credentials: UserLogin, request: Request) -> dict[str, Any]:
    cuenta, ip = credentials.username, ip_de(request)
    with db_conn() as conn:
        with conn.cursor() as cur:
            limite.exigir(cur, (limite.LOGIN_CUENTA, cuenta), (limite.LOGIN_IP, ip))
            found = find_user(cur, credentials.username)
            if not found:
                verificar_sin_cuenta(credentials.password)
                raise _fallo_de_login(cur, conn, cuenta, ip)

            profile, table, row = found
            if not verify_password(credentials.password, row["password_hash"]):
                raise _fallo_de_login(cur, conn, cuenta, ip)
            # Semana 5 (H6): solo quien sabe la contrasena se entera de que la
            # cuenta esta desactivada, y sabe a quien pedir ayuda.
            if not row["activo"]:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Tu cuenta está desactivada. Pide al administrador que la reactive.",
                )
            limite.limpiar(cur, limite.LOGIN_CUENTA, cuenta)
            if necesita_rehash(row["password_hash"]):
                cur.execute(
                    f"UPDATE {table} SET password_hash = %s WHERE id_usuario = %s",
                    (hash_password(credentials.password), row["id_usuario"]),
                )

            token = crear_sesion(cur, profile, row["id_usuario"])
            cur.execute(
                f"UPDATE {table} SET ultima_conexion = NOW() WHERE id_usuario = %s RETURNING *",
                (row["id_usuario"],),
            )
            logged_user = user_to_dict(cur.fetchone(), profile)
        conn.commit()

    return {
        "access_token": f"{TOKEN_PREFIX}{token}",
        "token_type": "bearer",
        "perfil_tipo": profile,
        "user": logged_user,
    }


@app.post("/auth/logout")
def logout(credentials: HTTPAuthorizationCredentials | None = Depends(security)) -> dict[str, Any]:
    """Cierra esta sesion en el servidor. Responde igual si el token ya no
    existia: la app siempre puede salir y no se revela nada del token."""
    token = token_de(credentials)
    if token is not None:
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM sesiones_locales WHERE token = %s", (token,))
            conn.commit()
    return {"success": True}


@app.get("/auth/demo")
def demo_disponible() -> dict[str, Any]:
    """Si el acceso rapido esta activo, para que el boton no aparezca en una
    compilacion normal."""
    return {
        "activo": DEMO_ENABLED,
        "requiere_clave": not DEMO_SIN_CLAVE,
        "personajes": list(DEMO_USERS),
    }


def _exigir_clave_demo(clave: str, ip: str) -> None:
    """Semana 5 (H5): la clave de la demo tambien tiene limite de intentos
    por direccion. Sin clave configurada nunca se entra."""
    if DEMO_SIN_CLAVE:
        return
    with db_conn() as conn:
        with conn.cursor() as cur:
            limite.exigir(cur, (limite.DEMO_IP, ip))
            # Comparacion en tiempo constante para no filtrar la clave
            # midiendo el tiempo de respuesta.
            if DEMO_ACCESS_CODE and secrets.compare_digest(clave.strip(), DEMO_ACCESS_CODE):
                return
            limite.registrar(cur, limite.DEMO_IP, ip)
        conn.commit()
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Clave incorrecta")


@app.post("/auth/demo")
def demo_login(payload: DemoLogin, request: Request) -> dict[str, Any]:
    if not DEMO_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El acceso rapido no esta activo en este despliegue",
        )
    _exigir_clave_demo(payload.clave, ip_de(request))

    # "madre" y "padre" comparten perfil y tabla en este esquema, asi que el
    # personaje se busca con el nombre pedido y no con el perfil normalizado:
    # si no, los dos caerian en el mismo usuario.
    requested = payload.perfil.strip().lower()
    if requested not in DEMO_USERS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Personaje desconocido"
        )
    username = DEMO_USERS[requested]

    with db_conn() as conn:
        with conn.cursor() as cur:
            found = find_user(cur, username)
            if not found:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"El personaje {username} no esta sembrado",
                )
            found_profile, table, row = found
            if not row["activo"]:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"El personaje {username} esta desactivado",
                )
            token = crear_sesion(cur, found_profile, row["id_usuario"])
            logged_user = user_to_dict(row, found_profile)
        conn.commit()

    return {
        "access_token": f"{TOKEN_PREFIX}{token}",
        "token_type": "bearer",
        "perfil_tipo": found_profile,
        "user": logged_user,
    }


@app.post("/auth/google")
def google_login(payload: GoogleLogin) -> dict[str, Any]:
    if not GOOGLE_CLIENT_ID:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="GOOGLE_CLIENT_ID no esta configurado en el backend",
        )

    try:
        idinfo = google_id_token.verify_oauth2_token(
            payload.token, google_requests.Request(), GOOGLE_CLIENT_ID
        )
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de Google invalido",
        )

    correo = idinfo.get("email")
    if not correo or not idinfo.get("email_verified"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo de Google no verificado",
        )

    nombres = idinfo.get("given_name") or idinfo.get("name") or "Usuario"
    apellido_paterno = idinfo.get("family_name") or "Google"
    google_sub = idinfo["sub"]

    with db_conn() as conn:
        with conn.cursor() as cur:
            found = find_user(cur, correo)
            if found:
                profile, table, row = found
                if not row["activo"]:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Usuario inactivo",
                    )
            else:
                profile = "estudiante"
                table = PROFILE_TABLES[profile]
                nombre_usuario = unique_username_from_email(cur, correo)
                keycloack_id = f"google-{google_sub}"
                cur.execute(
                    f"""
                    INSERT INTO {table} (
                        keycloack_id, nombre_usuario, correo, password_hash,
                        nombres, apellido_paterno
                    )
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING *
                    """,
                    (
                        keycloack_id,
                        nombre_usuario,
                        correo,
                        hash_password(secrets.token_urlsafe(24)),
                        nombres,
                        apellido_paterno,
                    ),
                )
                row = cur.fetchone()

            token = crear_sesion(cur, profile, row["id_usuario"])
            cur.execute(
                f"UPDATE {table} SET ultima_conexion = NOW() WHERE id_usuario = %s RETURNING *",
                (row["id_usuario"],),
            )
            logged_user = user_to_dict(cur.fetchone(), profile)
        conn.commit()

    return {
        "access_token": f"{TOKEN_PREFIX}{token}",
        "token_type": "bearer",
        "perfil_tipo": profile,
        "user": logged_user,
    }


MENSAJE_RECUPERACION = (
    "Si existe una cuenta con esos datos, te enviamos un correo con las "
    "instrucciones. Revisa también la carpeta de correo no deseado."
)
MENSAJE_SIN_CORREO = (
    "La recuperación por correo todavía no está disponible. Pide al "
    "administrador de tu escuela que te ayude a restablecer tu contraseña."
)


@app.post("/auth/password-reset-request")
def password_reset_request(payload: PasswordResetRequest, request: Request) -> dict[str, Any]:
    """Semana 5 (H4). Antes respondia 404 si la cuenta no existia (revelaba
    que cuentas existen), imprimia el token en el registro y decia «correo
    enviado» sin enviarlo. Ahora la respuesta es la misma exista o no la
    cuenta, el token solo viaja por correo y, si el servidor no tiene correo
    configurado, lo dice en lugar de fingir el envio."""
    if not correo.configurado():
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=MENSAJE_SIN_CORREO)
    cuenta, ip = payload.email_or_username, ip_de(request)
    destinatario: tuple[str, str] | None = None
    with db_conn() as conn:
        with conn.cursor() as cur:
            limite.exigir(cur, (limite.RECUPERACION_CUENTA, cuenta), (limite.RECUPERACION_IP, ip))
            limite.registrar(cur, limite.RECUPERACION_CUENTA, cuenta)
            limite.registrar(cur, limite.RECUPERACION_IP, ip)
            found = find_user(cur, cuenta)
            if found and found[2]["activo"]:
                profile, _, row = found
                token = recuperacion.crear(cur, profile, row["id_usuario"])
                destinatario = (row["correo"], recuperacion.cuerpo_correo(row["nombres"], token))
        conn.commit()
    if destinatario is not None:
        # En otro hilo: esperar al servidor de correo solo cuando la cuenta
        # existe haria que el tiempo de respuesta la delatara.
        threading.Thread(
            target=correo.enviar,
            args=(destinatario[0], "Restablecer tu contraseña de APPlicatuMente", destinatario[1]),
            daemon=True,
        ).start()
    log.info("recuperacion de contrasena solicitada")
    return {"success": True, "message": MENSAJE_RECUPERACION}


@app.post("/auth/password-reset-confirm")
def password_reset_confirm(payload: PasswordResetConfirm) -> dict[str, Any]:
    validar_password(payload.new_password)
    with db_conn() as conn:
        with conn.cursor() as cur:
            dueno = recuperacion.consumir(cur, payload.token)
            if dueno is None:
                conn.commit()  # un token vencido tambien se borra
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="El enlace no es válido o ya venció. Solicita uno nuevo.",
                )
            table = PROFILE_TABLES[dueno.perfil_tipo]
            cur.execute(
                f"UPDATE {table} SET password_hash = %s WHERE id_usuario = %s RETURNING nombre_usuario, correo",
                (hash_password(payload.new_password), dueno.id_usuario),
            )
            cuenta = cur.fetchone()
            # Semana 4 (H2): quien tenia la cuenta abierta queda fuera.
            invalidar_sesiones(cur, dueno.perfil_tipo, dueno.id_usuario)
            # Con la contrasena nueva ya puede entrar aunque estuviera bloqueada.
            if cuenta:
                limite.limpiar(cur, limite.LOGIN_CUENTA, cuenta["nombre_usuario"])
                limite.limpiar(cur, limite.LOGIN_CUENTA, cuenta["correo"])
        conn.commit()
    return {"success": True, "message": "Contraseña actualizada correctamente."}


@app.post("/auth/change-password")
def change_password(
    payload: ChangePassword,
    user: dict[str, Any] = Depends(current_user),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> dict[str, Any]:
    validar_password(payload.new_password)
    table = PROFILE_TABLES[user["perfil_tipo"]]
    with db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"SELECT password_hash FROM {table} WHERE id_usuario = %s",
                (user["id_usuario"],),
            )
            row = cur.fetchone()
            if not row or not verify_password(payload.current_password, row["password_hash"]):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="La contrasena actual no es correcta.",
                )
            cur.execute(
                f"UPDATE {table} SET password_hash = %s WHERE id_usuario = %s",
                (hash_password(payload.new_password), user["id_usuario"]),
            )
            # Semana 4 (H2): se cierran las demas sesiones; esta sigue abierta.
            invalidar_sesiones(cur, user["perfil_tipo"], user["id_usuario"], excepto=token_de(credentials))
        conn.commit()
    return {"success": True, "message": "Contrasena cambiada exitosamente."}


@app.get("/users/me")
def get_me(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    linked = []
    if user["perfil_tipo"] == "padre":
        with db_conn() as conn:
            with conn.cursor() as cur:
                linked = list_parent_students(cur, user["id_usuario"])

    return {
        "sub": user["keycloack_id"],
        "email": user["correo"],
        "roles": [user["perfil_tipo"]],
        "db_info": user,
        "id_usuario": user["id_usuario"],
        "nombre_completo": user["nombre_completo"],
        "activo": user["activo"],
        "perfil_tipo": user["perfil_tipo"],
        "estudiantes_vinculados": linked,
    }


@app.get("/users/session")
def get_session_context(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    with db_conn() as conn:
        with conn.cursor() as cur:
            progress = questionnaire_completion_status(
                cur,
                user["perfil_tipo"],
                user["id_usuario"],
            )
            preferencias = latest_general_preferences(
                cur,
                user["perfil_tipo"],
                user["id_usuario"],
            )

    user_data = get_me(user)
    profile = user["perfil_tipo"]
    capabilities = ROLE_CAPABILITIES[profile]

    return {
        "user": user_data,
        "perfil_tipo": profile,
        "perfil_label": PROFILE_LABELS[profile],
        "permissions": capabilities,
        "progress": progress,
        "preferences": preferencias,
        "modules": module_access_for_role(profile, progress),
    }


@app.get("/users/perfil")
def get_perfil(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    return get_me(user)


@app.put("/users/cuestionario")
def save_questionnaire(
    payload: CuestionarioUpdate,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    if not ROLE_CAPABILITIES[user["perfil_tipo"]]["can_answer_questionnaires"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Este rol no responde cuestionarios",
        )

    if payload.id_usuario and payload.id_usuario != user["id_usuario"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No tienes permiso")

    with db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO cuestionarios_locales (
                    perfil_tipo, id_usuario, tipo_cuestionario, respuestas, completado
                )
                VALUES (%s, %s, %s, %s::jsonb, %s)
                RETURNING *
                """,
                (
                    user["perfil_tipo"],
                    user["id_usuario"],
                    payload.tipo_cuestionario,
                    json.dumps(payload.respuestas, ensure_ascii=True),
                    payload.completado,
                ),
            )
            row = cur.fetchone()
            create_parent_alerts_for_session(cur, row)
        conn.commit()

    session = {key: serialize(value) for key, value in row.items()}
    session["fecha_de_registro"] = session.pop("fecha_registro")
    return {
        "message": "Sesion de cuestionario guardada exitosamente",
        "cuestionario_completado": session["completado"],
        "user": user,
        "sesion_cuestionario": session,
    }


@app.get("/users/cuestionario/status")
def questionnaire_status(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    with db_conn() as conn:
        with conn.cursor() as cur:
            status_data = questionnaire_completion_status(
                cur,
                user["perfil_tipo"],
                user["id_usuario"],
            )

    return {
        **status_data,
        "message": "Estado consultado en vivo desde Postgres temporal",
        "perfil_tipo": user["perfil_tipo"],
        "id_usuario": user["id_usuario"],
        "usuario_activo": user["activo"],
    }


@app.get("/cuestionarios/config")
def questionnaire_config(
    modulo: str = Query(..., pattern="^(autolesion|suicidio|ansiedad)$"),
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    with db_conn() as conn:
        with conn.cursor() as cur:
            preguntas = list_question_configs_by_module(cur, modulo)

    return {
        "modulo": modulo,
        "perfil_tipo": user["perfil_tipo"],
        "preguntas": preguntas,
        "total": len(preguntas),
    }


@app.put("/users/activar")
def activate_user(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    return set_user_active(user, True)


@app.put("/users/desactivar")
def deactivate_user(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    return set_user_active(user, False)


@app.put("/admin/usuarios/{perfil_tipo}/{id_usuario}/activo")
def admin_set_active(
    perfil_tipo: str, id_usuario: int, payload: ActivoUpdate, user: dict[str, Any] = Depends(current_user)
) -> dict[str, Any]:
    """Semana 5 (H6): una cuenta desactivada ya no puede llamar a
    /users/activar (no puede iniciar sesion), asi que la reactiva el
    administrador."""
    if user["perfil_tipo"] != "administrador":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo para administradores")
    profile = normalize_profile(perfil_tipo)
    if profile == "administrador" and id_usuario == user["id_usuario"] and not payload.activo:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No puedes desactivar tu propia cuenta.")
    try:
        return set_user_active({"perfil_tipo": profile, "id_usuario": id_usuario}, payload.activo)
    except LookupError:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="El usuario no existe.") from None


def set_user_active(user: dict[str, Any], active: bool) -> dict[str, Any]:
    table = PROFILE_TABLES[user["perfil_tipo"]]
    with db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                UPDATE {table}
                SET activo = %s, ultima_conexion = NOW()
                WHERE id_usuario = %s
                RETURNING *
                """,
                (active, user["id_usuario"]),
            )
            fila = cur.fetchone()
            if fila is None:
                raise LookupError(user["id_usuario"])
            updated = user_to_dict(fila, user["perfil_tipo"])
            # Semana 5 (H6): desactivar cierra todas las sesiones abiertas.
            if not active:
                invalidar_sesiones(cur, user["perfil_tipo"], user["id_usuario"])
        conn.commit()
    return {"message": "Usuario actualizado exitosamente", "user": updated}


# Semana 6: alertas y estudiantes del tutor, y monitoreo y editor del
# administrador, separados de main.py.
app.include_router(crear_router_padres(db_conn=db_conn, current_user=current_user))
app.include_router(crear_router_admin(db_conn=db_conn, current_user=current_user))


def chat_session_id(user: dict[str, Any]) -> str:
    return f"{user['perfil_tipo']}_{user['id_usuario']}"


# PROTOTIPO Semana 2: POST /chat vive en prototipo_api.py (compuerta de
# riesgo y polaridad antes del futuro LLM).


# PROTOTIPO Semana 3, fase 2: el historial es la memoria en RAM de Serena
# (memoria_sesion.py). No se guarda en la base de datos.
@app.get("/chat/historial")
def chat_history(user: dict[str, Any] = Depends(current_user)) -> dict[str, list[Any]]:
    turnos = MEMORIA.turnos(chat_session_id(user))
    return {"historial": [{"mensaje": t.texto, "respuesta": t.respuesta, "tipo": t.tipo} for t in turnos]}


@app.delete("/chat/historial")
def chat_history_delete(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    # El frontend la llama al limpiar la conversacion: Serena la olvida.
    MEMORIA.borrar(chat_session_id(user))
    return {"success": True, "sesion_id": chat_session_id(user)}


# Semana 5: lista de cuentas y borrado completo (derecho de cancelacion).
app.include_router(
    crear_router_cuentas(
        db_conn=db_conn,
        current_user=current_user,
        olvidar_conversacion=lambda perfil, id_usuario: MEMORIA.borrar(
            chat_session_id({"perfil_tipo": perfil, "id_usuario": id_usuario})
        ),
    )
)

# PROTOTIPO Semana 2: diario, compuerta de Serena, alertas y vinculacion.
app.include_router(
    crear_router(
        db_conn=db_conn,
        current_user=current_user,
        vincular=link_parent_to_student,
        chat_session_id=chat_session_id,
    )
)
