import hashlib
import json
import os
import threading
import re
import secrets
import time
import uuid
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from typing import Any

import psycopg2
from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel, Field

from .prototipo_api import ANALIZADOR, GENERADOR, MEMORIA, crear_router, crear_tablas_prototipo
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

# In-memory password reset tokens: {token: {id_usuario, perfil_tipo, expira}}
RESET_TOKENS: dict[str, dict[str, Any]] = {}

PROFILE_TABLES = {
    "estudiante": "usuarios_estudiantes",
    "padre": "usuarios_padres",
    "administrador": "usuarios_administradores",
}

PROFILE_ALIASES = {
    "estudiante": "estudiante",
    "estudiantes": "estudiante",
    "adolescente": "estudiante",
    "padre": "padre",
    "padres": "padre",
    "madre": "padre",
    "tutor": "padre",
    "admin": "administrador",
    "administrador": "administrador",
}

PROFILE_LABELS = {
    "estudiante": "Estudiante",
    "padre": "Padre/Madre",
    "administrador": "Administrador",
}

ROLE_CAPABILITIES = {
    "estudiante": {
        "can_answer_questionnaires": True,
        "can_play_tcg": True,
        "can_monitor_responses": False,
        "can_edit_questionnaires": False,
        "can_manage_linked_students": False,
        # PROTOTIPO Semana 2
        "can_use_diario": True,
        "can_link_tutor": True,
        "can_review_risk_alerts": False,
    },
    "padre": {
        "can_answer_questionnaires": True,
        "can_play_tcg": False,
        "can_monitor_responses": False,
        "can_edit_questionnaires": False,
        "can_manage_linked_students": True,
        "can_use_diario": False,
        "can_link_tutor": False,
        "can_review_risk_alerts": False,
    },
    "administrador": {
        "can_answer_questionnaires": False,
        "can_play_tcg": False,
        "can_monitor_responses": True,
        "can_edit_questionnaires": True,
        "can_manage_linked_students": False,
        "can_use_diario": False,
        "can_link_tutor": False,
        "can_review_risk_alerts": True,
    },
}

security = HTTPBearer(auto_error=False)
app = FastAPI(title="APTM Front Mock Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class UserRegister(BaseModel):
    perfil_tipo: str
    nombre_usuario: str
    correo: str
    password: str
    nombres: str
    apellido_paterno: str
    apellido_materno: str = ""
    estudiantes_curps: list[str] = Field(default_factory=list)
    curp: str = ""
    parentesco: str = "padre/madre/tutor"
    fecha_nacimiento: str = ""


class UserLogin(BaseModel):
    username: str
    password: str


class GoogleLogin(BaseModel):
    token: str


class DemoLogin(BaseModel):
    perfil: str
    clave: str = ""


class CuestionarioUpdate(BaseModel):
    id_usuario: int | None = None
    tipo_cuestionario: str
    respuestas: dict[str, Any]
    completado: bool = False


class VincularEstudiante(BaseModel):
    curp_estudiante: str
    parentesco: str = "padre/madre/tutor"


class ChatRequest(BaseModel):
    mensaje: str = ""


class PasswordResetRequest(BaseModel):
    email_or_username: str


class PasswordResetConfirm(BaseModel):
    token: str
    new_password: str


class ChangePassword(BaseModel):
    current_password: str
    new_password: str


class QuestionConfigUpdate(BaseModel):
    pregunta: str
    puntaje: int = Field(ge=0)
    activo: bool = True


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


def default_question_configs() -> list[tuple[str, str, str, str, str, int, int]]:
    suicidio = [
        ("suicidio", "Riesgo suicida", "PHQ9", "deprimido_irritable", "likert4", "¿Has estado sintiéndote triste, irritado(a) o sin ganas de nada?", 1, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "poco_interes", "likert4", "¿Has sentido falta de interés en las cosas, o que ya casi nada te da placer o gusto, aunque antes sí te gustaran?", 2, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "sueno", "likert4", "¿Tienes problemas con el sueño? Por ejemplo: ¿te cuesta mucho trabajo dormirte o te despiertas en la madrugada y ya no puedes volver a dormir? O al contrario, ¿duermes tanto que igual sientes que no descansas?", 3, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "apetito", "likert4", "¿Tu apetito ha cambiado mucho? ¿Comes muy poco o demasiado, o has bajado o subido de peso sin querer?", 4, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "cansancio", "likert4", "¿Te sientes cansado(a) o sin energía casi todo el tiempo?", 5, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "mal_consigo", "likert4", "¿Te sientes mal contigo mismo(a), como si fueras un fracaso o como que les has fallado a las personas que quieres?", 6, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "concentracion", "likert4", "¿Te cuesta concentrarte en la escuela, al leer o incluso al ver una película o serie?", 7, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "movimiento", "likert4", "¿Te mueves o hablas más lento de lo normal y los demás lo notan? O al revés, ¿estás tan inquieto(a) que no puedes quedarte quieto(a)?", 8, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "mejor_muerto", "likert4", "¿Has tenido pensamientos de que estarías mejor muerto(a) o de hacerte daño de alguna forma?", 9, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "deprimido_anio", "binario", "¿En el último año te has sentido triste o deprimido(a) la mayor parte del tiempo?", 10, 1),
        ("suicidio", "Riesgo suicida", "PHQ9", "pensar_terminar", "binario", "¿En el último mes hubo algún momento en que pensaste en serio en quitarte la vida?", 11, 1),
        ("suicidio", "Riesgo suicida", "PHQ9", "intento_suicidio", "binario", "¿Alguna vez en tu vida intentaste suicidarte o hacerte daño para morir?", 12, 1),
        ("suicidio", "Riesgo suicida", "CSSRS", "desear_muerto", "binario", "¿Has deseado estar muerto(a), o sentido que quisieras dormirte y simplemente no despertar?", 13, 1),
        ("suicidio", "Riesgo suicida", "CSSRS", "idea_suicidarse", "binario", "¿Has tenido pensamientos de suicidarte, aunque sea por un momento?", 14, 1),
        ("suicidio", "Riesgo suicida", "CSSRS", "como_lo_haria", "binario", "¿Has pensado en cómo lo harías?", 15, 1),
        ("suicidio", "Riesgo suicida", "CSSRS", "intencion_llevarlo", "binario", "¿Has tenido esos pensamientos y sientes que en parte sí querrías llevarlos a cabo?", 16, 1),
        ("suicidio", "Riesgo suicida", "CSSRS", "detalles_plan", "binario", "¿Has empezado a pensar en los detalles de cómo hacerlo? ¿Sientes que de verdad quieres o planeas llevarlo a cabo?", 17, 1),
    ]
    autolesion = [
        ("autolesion", "Autolesiones", "NSSI", "cortado_piel", "binario", "¿Alguna vez te has hecho cortadas en la piel, pero sin querer hacerte daño grave ni quitarte la vida?", 1, 1),
        ("autolesion", "Autolesiones", "NSSI", "primera_vez", "texto", "¿Cuándo fue la primera vez que lo hiciste?", 2, 0),
        ("autolesion", "Autolesiones", "NSSI", "cuantas_veces", "numero", "¿Cuántas veces lo has hecho?", 3, 0),
        ("autolesion", "Autolesiones", "NSSI", "donde_aprendiste", "texto", "¿Dónde o cómo te enteraste de hacerlo?", 4, 0),
    ]
    ansiedad = [
        ("ansiedad", "Ansiedad", "GAD7", "nervioso", "likert4", "¿Te has sentido nervioso(a), ansioso(a) o con los nervios de punta?", 1, 0),
        ("ansiedad", "Ansiedad", "GAD7", "no_controlar_preocupacion", "likert4", "¿No has podido parar o controlar tus preocupaciones?", 2, 0),
        ("ansiedad", "Ansiedad", "GAD7", "preocupacion_excesiva", "likert4", "¿Te has preocupado demasiado por diferentes cosas?", 3, 0),
        ("ansiedad", "Ansiedad", "GAD7", "dificil_relajarse", "likert4", "¿Te ha costado trabajo relajarte?", 4, 0),
        ("ansiedad", "Ansiedad", "GAD7", "inquietud", "likert4", "¿Has estado tan inquieto(a) que te cuesta quedarte quieto(a)?", 5, 0),
        ("ansiedad", "Ansiedad", "GAD7", "irritabilidad", "likert4", "¿Te has molestado o irritado fácilmente?", 6, 0),
        ("ansiedad", "Ansiedad", "GAD7", "miedo", "likert4", "¿Has sentido miedo como si algo terrible pudiera pasar?", 7, 0),
    ]
    return autolesion + suicidio + ansiedad


def seed_question_configs(cur: Any) -> None:
    cur.executemany(
        """
        INSERT INTO cuestionarios_config (
            modulo_key, modulo, bloque, codigo, tipo_respuesta, pregunta, numero, puntaje, activo
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, TRUE)
        ON CONFLICT (modulo_key, codigo) WHERE modulo_key IS NOT NULL AND codigo IS NOT NULL
        DO UPDATE SET
            modulo = EXCLUDED.modulo,
            bloque = EXCLUDED.bloque,
            tipo_respuesta = EXCLUDED.tipo_respuesta,
            numero = EXCLUDED.numero
        """,
        default_question_configs(),
    )


def init_db() -> None:
    wait_for_db()
    with db_conn() as conn:
        with conn.cursor() as cur:
            for table in PROFILE_TABLES.values():
                cur.execute(
                    f"""
                    CREATE TABLE IF NOT EXISTS {table} (
                        id_usuario SERIAL PRIMARY KEY,
                        keycloack_id VARCHAR(120) UNIQUE NOT NULL,
                        nombre_usuario VARCHAR(120) UNIQUE NOT NULL,
                        correo VARCHAR(255) UNIQUE NOT NULL,
                        password_hash TEXT NOT NULL,
                        nombres VARCHAR(160) NOT NULL,
                        apellido_paterno VARCHAR(160) NOT NULL,
                        apellido_materno VARCHAR(160),
                        activo BOOLEAN NOT NULL DEFAULT TRUE,
                        fecha_de_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        ultima_conexion TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )

            cur.execute(
                """
                ALTER TABLE usuarios_estudiantes
                ADD COLUMN IF NOT EXISTS curp VARCHAR(18)
                """
            )
            cur.execute(
                """
                ALTER TABLE usuarios_estudiantes
                ADD COLUMN IF NOT EXISTS fecha_nacimiento DATE
                """
            )
            cur.execute(
                """
                CREATE UNIQUE INDEX IF NOT EXISTS ux_usuarios_estudiantes_curp
                ON usuarios_estudiantes (curp)
                WHERE curp IS NOT NULL
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS padre_estudiante (
                    id_relacion SERIAL PRIMARY KEY,
                    id_padre INTEGER NOT NULL REFERENCES usuarios_padres(id_usuario) ON DELETE CASCADE,
                    id_estudiante INTEGER NOT NULL REFERENCES usuarios_estudiantes(id_usuario) ON DELETE CASCADE,
                    parentesco VARCHAR(80) NOT NULL DEFAULT 'padre/madre/tutor',
                    fecha_vinculacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    UNIQUE (id_padre, id_estudiante)
                )
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS sesiones_locales (
                    token TEXT PRIMARY KEY,
                    perfil_tipo VARCHAR(30) NOT NULL,
                    id_usuario INTEGER NOT NULL,
                    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS cuestionarios_locales (
                    id_sesion SERIAL PRIMARY KEY,
                    perfil_tipo VARCHAR(30) NOT NULL,
                    id_usuario INTEGER NOT NULL,
                    tipo_cuestionario VARCHAR(120) NOT NULL,
                    respuestas JSONB NOT NULL,
                    completado BOOLEAN NOT NULL DEFAULT FALSE,
                    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS alertas_padres (
                    id_alerta SERIAL PRIMARY KEY,
                    id_padre INTEGER NOT NULL REFERENCES usuarios_padres(id_usuario) ON DELETE CASCADE,
                    id_estudiante INTEGER NOT NULL REFERENCES usuarios_estudiantes(id_usuario) ON DELETE CASCADE,
                    id_sesion INTEGER NOT NULL REFERENCES cuestionarios_locales(id_sesion) ON DELETE CASCADE,
                    tipo VARCHAR(80) NOT NULL,
                    titulo VARCHAR(180) NOT NULL,
                    mensaje TEXT NOT NULL,
                    recomendacion TEXT NOT NULL,
                    leida BOOLEAN NOT NULL DEFAULT FALSE,
                    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    fecha_lectura TIMESTAMPTZ,
                    UNIQUE (id_padre, id_sesion)
                )
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS cuestionarios_config (
                    id_pregunta SERIAL PRIMARY KEY,
                    modulo VARCHAR(120) NOT NULL,
                    pregunta TEXT NOT NULL,
                    puntaje INTEGER NOT NULL DEFAULT 0,
                    activo BOOLEAN NOT NULL DEFAULT TRUE,
                    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
            cur.execute("ALTER TABLE cuestionarios_config ADD COLUMN IF NOT EXISTS modulo_key VARCHAR(80)")
            cur.execute("ALTER TABLE cuestionarios_config ADD COLUMN IF NOT EXISTS bloque VARCHAR(120)")
            cur.execute("ALTER TABLE cuestionarios_config ADD COLUMN IF NOT EXISTS codigo VARCHAR(120)")
            cur.execute("ALTER TABLE cuestionarios_config ADD COLUMN IF NOT EXISTS tipo_respuesta VARCHAR(40) DEFAULT 'texto'")
            cur.execute("ALTER TABLE cuestionarios_config ADD COLUMN IF NOT EXISTS numero INTEGER DEFAULT 0")
            cur.execute("DELETE FROM cuestionarios_config WHERE modulo_key IS NULL OR codigo IS NULL")
            cur.execute(
                """
                CREATE UNIQUE INDEX IF NOT EXISTS ux_cuestionarios_config_modulo_codigo
                ON cuestionarios_config (modulo_key, codigo)
                WHERE modulo_key IS NOT NULL AND codigo IS NOT NULL
                """
            )
            seed_question_configs(cur)
            crear_tablas_prototipo(cur)
        conn.commit()


@app.on_event("startup")
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
    iterations = 120_000
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


def serialize(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.isoformat()
    return value


def user_to_dict(row: dict[str, Any], profile: str) -> dict[str, Any]:
    user = {key: serialize(value) for key, value in row.items()}
    user.pop("password_hash", None)
    user["perfil_tipo"] = profile
    user["perfil_label"] = PROFILE_LABELS[profile]
    user["nombre_completo"] = " ".join(
        part
        for part in [
            user.get("nombres"),
            user.get("apellido_paterno"),
            user.get("apellido_materno"),
        ]
        if part
    )
    return user


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


def normalize_curp(curp: str) -> str:
    return curp.strip().upper()


def ensure_curp_is_unique(cur: Any, curp: str) -> None:
    normalized = normalize_curp(curp)
    if not normalized:
        return

    cur.execute(
        """
        SELECT 1
        FROM usuarios_estudiantes
        WHERE curp = %s
        LIMIT 1
        """,
        (normalized,),
    )
    if cur.fetchone():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El CURP ya esta registrado",
        )


def find_student_by_curp(cur: Any, curp: str) -> dict[str, Any]:
    normalized = normalize_curp(curp)
    cur.execute(
        """
        SELECT *
        FROM usuarios_estudiantes
        WHERE curp = %s
        LIMIT 1
        """,
        (normalized,),
    )
    student = cur.fetchone()
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Estudiante con CURP {normalized} no encontrado",
        )
    return student


def ensure_students_curps_exist(cur: Any, curps: list[str]) -> None:
    for curp in curps:
        find_student_by_curp(cur, curp)


def list_parent_students(cur: Any, id_padre: int) -> list[dict[str, Any]]:
    cur.execute(
        """
        SELECT
            pe.id_relacion,
            pe.parentesco,
            pe.fecha_vinculacion,
            e.id_usuario,
            e.keycloack_id,
            e.nombre_usuario,
            e.correo,
            e.curp,
            e.nombres,
            e.apellido_paterno,
            e.apellido_materno,
            e.activo,
            e.fecha_de_creacion,
            e.ultima_conexion
        FROM padre_estudiante pe
        JOIN usuarios_estudiantes e ON e.id_usuario = pe.id_estudiante
        WHERE pe.id_padre = %s
        ORDER BY e.nombres, e.apellido_paterno
        """,
        (id_padre,),
    )
    result = []
    for row in cur.fetchall():
        student = user_to_dict(row, "estudiante")
        student.pop("id_usuario", None)
        student.pop("keycloack_id", None)
        student.pop("id_relacion", None)
        result.append({
            **student,
            "parentesco": row["parentesco"],
            "fecha_vinculacion": serialize(row["fecha_vinculacion"]),
        })
    return result


def list_questionnaires_by_profile(cur: Any, profile: str) -> list[dict[str, Any]]:
    table = PROFILE_TABLES[profile]
    cur.execute(
        f"""
        SELECT
            q.id_sesion,
            q.id_usuario,
            q.perfil_tipo,
            q.tipo_cuestionario,
            q.respuestas,
            q.completado,
            q.fecha_registro,
            u.nombre_usuario,
            u.correo,
            u.nombres,
            u.apellido_paterno,
            u.apellido_materno
        FROM cuestionarios_locales q
        JOIN {table} u ON u.id_usuario = q.id_usuario
        WHERE q.perfil_tipo = %s
        ORDER BY q.fecha_registro DESC
        """,
        (profile,),
    )

    rows = []
    for row in cur.fetchall():
        data = {key: serialize(value) for key, value in row.items()}
        data["fecha_de_registro"] = data.pop("fecha_registro")
        data["nombre_completo"] = " ".join(
            part
            for part in [
                data.get("nombres"),
                data.get("apellido_paterno"),
                data.get("apellido_materno"),
            ]
            if part
        )
        rows.append(data)
    return rows


def list_question_configs(cur: Any) -> list[dict[str, Any]]:
    cur.execute(
        """
        SELECT
            id_pregunta,
            modulo_key,
            modulo,
            bloque,
            codigo,
            tipo_respuesta,
            numero,
            pregunta,
            puntaje,
            activo,
            fecha_actualizacion
        FROM cuestionarios_config
        ORDER BY modulo_key, bloque, numero, id_pregunta
        """
    )
    return [{key: serialize(value) for key, value in row.items()} for row in cur.fetchall()]


def list_question_configs_by_module(cur: Any, module: str) -> list[dict[str, Any]]:
    cur.execute(
        """
        SELECT
            id_pregunta,
            modulo_key,
            modulo,
            bloque,
            codigo,
            tipo_respuesta,
            numero,
            pregunta,
            puntaje,
            activo,
            fecha_actualizacion
        FROM cuestionarios_config
        WHERE modulo_key = %s AND activo = TRUE
        ORDER BY bloque, numero, id_pregunta
        """,
        (module,),
    )
    return [{key: serialize(value) for key, value in row.items()} for row in cur.fetchall()]


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


def _response_int(value: Any) -> int:
    if isinstance(value, bool):
        return 1 if value else 0
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        try:
            return int(value)
        except ValueError:
            return 0
    return 0


def _block_score(respuestas: dict[str, Any], block_key: str) -> int:
    for block in respuestas.get("bloques", []):
        if isinstance(block, dict) and block.get("bloque") == block_key:
            return _response_int(block.get("puntuacion_total"))
    return 0


def build_parent_alert(session: dict[str, Any], student: dict[str, Any]) -> dict[str, str]:
    respuestas = session.get("respuestas")
    if not isinstance(respuestas, dict):
        respuestas = {}

    tipo_cuestionario = str(session.get("tipo_cuestionario", ""))
    nombre = student.get("nombre_completo") or "El estudiante vinculado"

    if tipo_cuestionario == "suicidio":
        phq9_score = _response_int(respuestas.get("phq9_score")) or _block_score(respuestas, "PHQ9")
        cssrs_score = _response_int(respuestas.get("cssrs_score")) or _block_score(respuestas, "CSSRS")
        riesgo_alto = cssrs_score > 0 or phq9_score >= 10
        if riesgo_alto:
            return {
                "tipo": "riesgo_alto",
                "titulo": "Alerta de riesgo emocional",
                "mensaje": (
                    f"{nombre} respondió el cuestionario de depresión/riesgo. "
                    f"PHQ-9: {phq9_score}; C-SSRS: {cssrs_score}. Hay señales que requieren acompañamiento cercano."
                ),
                "recomendacion": (
                    "Como padre/madre/tutor: hable con calma y sin regaños, pregunte directamente cómo se siente, "
                    "no le deje solo/a si percibe riesgo inmediato, retire medios con los que pudiera hacerse daño "
                    "y contacte a un profesional de salud mental. Si hay peligro inmediato, acuda a urgencias o llame a emergencias."
                ),
            }
        return {
            "tipo": "cuestionario_completado",
            "titulo": "Cuestionario de riesgo completado",
            "mensaje": f"{nombre} completó el cuestionario de depresión/riesgo. PHQ-9: {phq9_score}; C-SSRS: {cssrs_score}.",
            "recomendacion": (
                "Como padre/madre/tutor: reconozca el esfuerzo de responder, mantenga una conversación abierta, "
                "observe cambios de ánimo, sueño, apetito o aislamiento, y ofrezca apoyo sin minimizar lo que siente."
            ),
        }

    if tipo_cuestionario == "autolesion":
        nssi_score = _block_score(respuestas, "NSSI")
        riesgo_alto = nssi_score > 0
        if riesgo_alto:
            return {
                "tipo": "riesgo_alto",
                "titulo": "Señal de autolesión reportada",
                "mensaje": f"{nombre} respondió el cuestionario de autolesiones y reportó una señal que necesita atención.",
                "recomendacion": (
                    "Como padre/madre/tutor: conserve la calma, escuche sin juzgar, evite castigos o amenazas, "
                    "pregunte qué emoción intentaba manejar y busque apoyo profesional. Revise heridas si existen y acuda a atención médica si es necesario."
                ),
            }
        return {
            "tipo": "cuestionario_completado",
            "titulo": "Cuestionario de autolesiones completado",
            "mensaje": f"{nombre} completó el cuestionario de autolesiones sin reportar autolesión actual en la pregunta principal.",
            "recomendacion": (
                "Como padre/madre/tutor: mantenga canales de confianza, valide sus emociones y observe si aparecen señales de tristeza intensa, aislamiento o ansiedad."
            ),
        }

    if tipo_cuestionario == "ansiedad":
        gad7_score = _response_int(respuestas.get("gad7_score")) or _block_score(respuestas, "GAD7")
        riesgo_alto = gad7_score >= 10
        if riesgo_alto:
            return {
                "tipo": "riesgo_alto",
                "titulo": "Ansiedad elevada",
                "mensaje": f"{nombre} respondió el cuestionario de ansiedad con un puntaje GAD-7 de {gad7_score}.",
                "recomendacion": (
                    "Como padre/madre/tutor: escuche sin minimizar, ayúdele a identificar detonantes, fomente descanso y rutinas, "
                    "practiquen respiración pausada y considere apoyo profesional si la ansiedad afecta escuela, sueño, convivencia o actividades diarias."
                ),
            }
        return {
            "tipo": "cuestionario_completado",
            "titulo": "Cuestionario de ansiedad completado",
            "mensaje": f"{nombre} completó el cuestionario de ansiedad. Puntaje GAD-7: {gad7_score}.",
            "recomendacion": (
                "Como padre/madre/tutor: acompañe con preguntas abiertas, promueva rutinas saludables y esté atento/a si la preocupación aumenta o evita actividades importantes."
            ),
        }

    return {
        "tipo": "cuestionario_completado",
        "titulo": "Cuestionario completado",
        "mensaje": f"{nombre} completó un cuestionario.",
        "recomendacion": "Como padre/madre/tutor: revise cómo se siente, escuche con calma y ofrezca apoyo disponible.",
    }


def create_parent_alerts_for_session(cur: Any, session: dict[str, Any], student: dict[str, Any] | None = None) -> None:
    if session.get("perfil_tipo") != "estudiante":
        return

    id_estudiante = session["id_usuario"]
    if student is None:
        cur.execute("SELECT * FROM usuarios_estudiantes WHERE id_usuario = %s", (id_estudiante,))
        student = cur.fetchone()
    if not student:
        return

    alert = build_parent_alert(session, user_to_dict(student, "estudiante"))
    cur.execute(
        """
        SELECT id_padre
        FROM padre_estudiante
        WHERE id_estudiante = %s
        """,
        (id_estudiante,),
    )
    parent_rows = cur.fetchall()
    for parent in parent_rows:
        cur.execute(
            """
            INSERT INTO alertas_padres (
                id_padre, id_estudiante, id_sesion, tipo, titulo, mensaje, recomendacion
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (id_padre, id_sesion)
            DO NOTHING
            """,
            (
                parent["id_padre"],
                id_estudiante,
                session["id_sesion"],
                alert["tipo"],
                alert["titulo"],
                alert["mensaje"],
                alert["recomendacion"],
            ),
        )


def backfill_parent_alerts(cur: Any, id_padre: int) -> None:
    cur.execute(
        """
        SELECT q.*, e.*
        FROM padre_estudiante pe
        JOIN usuarios_estudiantes e ON e.id_usuario = pe.id_estudiante
        JOIN cuestionarios_locales q
          ON q.perfil_tipo = 'estudiante'
         AND q.id_usuario = pe.id_estudiante
        WHERE pe.id_padre = %s
        ORDER BY q.fecha_registro DESC
        """,
        (id_padre,),
    )
    for row in cur.fetchall():
        session = {
            "id_sesion": row["id_sesion"],
            "perfil_tipo": row["perfil_tipo"],
            "id_usuario": row["id_usuario"],
            "tipo_cuestionario": row["tipo_cuestionario"],
            "respuestas": row["respuestas"],
            "completado": row["completado"],
            "fecha_registro": row["fecha_registro"],
        }
        student = {
            "id_usuario": row["id_usuario"],
            "keycloack_id": row["keycloack_id"],
            "nombre_usuario": row["nombre_usuario"],
            "correo": row["correo"],
            "curp": row.get("curp"),
            "nombres": row["nombres"],
            "apellido_paterno": row["apellido_paterno"],
            "apellido_materno": row["apellido_materno"],
            "activo": row["activo"],
            "fecha_de_creacion": row["fecha_de_creacion"],
            "ultima_conexion": row["ultima_conexion"],
        }
        create_parent_alerts_for_session(cur, session, student)


def list_parent_alerts(cur: Any, id_padre: int) -> list[dict[str, Any]]:
    backfill_parent_alerts(cur, id_padre)
    cur.execute(
        """
        SELECT
            a.id_alerta,
            a.tipo,
            a.titulo,
            a.mensaje,
            a.recomendacion,
            a.leida,
            a.fecha_creacion,
            a.fecha_lectura,
            a.id_sesion,
            a.id_estudiante,
            e.keycloack_id,
            e.nombre_usuario,
            e.correo,
            e.curp,
            e.nombres,
            e.apellido_paterno,
            e.apellido_materno,
            e.activo,
            e.fecha_de_creacion,
            e.ultima_conexion,
            q.tipo_cuestionario,
            q.respuestas
        FROM alertas_padres a
        JOIN usuarios_estudiantes e ON e.id_usuario = a.id_estudiante
        JOIN cuestionarios_locales q ON q.id_sesion = a.id_sesion
        WHERE a.id_padre = %s
        ORDER BY a.leida ASC, a.fecha_creacion DESC
        """,
        (id_padre,),
    )
    alerts = []
    for row in cur.fetchall():
        student = user_to_dict({
            "id_usuario": row["id_estudiante"],
            "keycloack_id": row["keycloack_id"],
            "nombre_usuario": row["nombre_usuario"],
            "correo": row["correo"],
            "curp": row.get("curp"),
            "nombres": row["nombres"],
            "apellido_paterno": row["apellido_paterno"],
            "apellido_materno": row["apellido_materno"],
            "activo": row["activo"],
            "fecha_de_creacion": row["fecha_de_creacion"],
            "ultima_conexion": row["ultima_conexion"],
        }, "estudiante")
        student.pop("id_usuario", None)
        student.pop("keycloack_id", None)
        alerts.append({
            "id_alerta": row["id_alerta"],
            "tipo": row["tipo"],
            "titulo": row["titulo"],
            "mensaje": row["mensaje"],
            "recomendacion": row["recomendacion"],
            "leida": row["leida"],
            "fecha": serialize(row["fecha_creacion"]),
            "fecha_lectura": serialize(row["fecha_lectura"]),
            "id_sesion": row["id_sesion"],
            "tipo_cuestionario": row["tipo_cuestionario"],
            "respuestas": row["respuestas"],
            "estudiante": student,
        })
    return alerts


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


def link_parent_to_student(cur: Any, id_padre: int, id_estudiante: int, parentesco: str) -> dict[str, Any]:
    cur.execute("SELECT 1 FROM usuarios_padres WHERE id_usuario = %s", (id_padre,))
    if not cur.fetchone():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Padre no encontrado")

    cur.execute(
        """
        INSERT INTO padre_estudiante (id_padre, id_estudiante, parentesco)
        VALUES (%s, %s, %s)
        ON CONFLICT (id_padre, id_estudiante)
        DO UPDATE SET parentesco = EXCLUDED.parentesco
        RETURNING *
        """,
        (id_padre, id_estudiante, parentesco),
    )
    return {key: serialize(value) for key, value in cur.fetchone().items()}


def link_parent_to_student_by_curp(cur: Any, id_padre: int, curp: str, parentesco: str) -> dict[str, Any]:
    student = find_student_by_curp(cur, curp)
    return link_parent_to_student(cur, id_padre, student["id_usuario"], parentesco)


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


@app.post("/auth/login")
def login(credentials: UserLogin) -> dict[str, Any]:
    with db_conn() as conn:
        with conn.cursor() as cur:
            found = find_user(cur, credentials.username)
            if not found:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales incorrectas")

            profile, table, row = found
            if not row["activo"] or not verify_password(credentials.password, row["password_hash"]):
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales incorrectas")

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


@app.post("/auth/demo")
def demo_login(payload: DemoLogin) -> dict[str, Any]:
    if not DEMO_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El acceso rapido no esta activo en este despliegue",
        )

    # Comparacion en tiempo constante para no filtrar la clave midiendo el
    # tiempo de respuesta.
    if not DEMO_SIN_CLAVE and (
        not DEMO_ACCESS_CODE
        or not secrets.compare_digest(payload.clave.strip(), DEMO_ACCESS_CODE)
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Clave incorrecta"
        )

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


@app.post("/auth/password-reset-request")
def password_reset_request(payload: PasswordResetRequest) -> dict[str, Any]:
    with db_conn() as conn:
        with conn.cursor() as cur:
            found = find_user(cur, payload.email_or_username)
            if not found:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="No encontramos una cuenta con ese correo o usuario.",
                )
            profile, table, row = found
    token = str(uuid.uuid4())
    expira = datetime.now(timezone.utc) + timedelta(hours=1)
    RESET_TOKENS[token] = {
        "id_usuario": row["id_usuario"],
        "perfil_tipo": profile,
        "expira": expira,
    }
    debug_msg = (
        f"\n{'='*60}\n"
        f"  📧 CORREO DE RECUPERACION ENVIADO\n"
        f"  Para: {row.get('correo', '?')}\n"
        f"  Usuario: {row.get('nombre_usuario', '?')}\n"
        f"  Token: {token}\n"
        f"  Expira: {expira.isoformat()}\n"
        f"  Enlace: http://localhost:8080/reset-password?token={token}\n"
        f"{'='*60}"
    )
    print(debug_msg)
    return {
        "success": True,
        "message": "Correo de recuperacion enviado. Revisa tu bandeja de entrada.",
    }


@app.post("/auth/password-reset-confirm")
def password_reset_confirm(payload: PasswordResetConfirm) -> dict[str, Any]:
    token_data = RESET_TOKENS.get(payload.token)
    if not token_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token invalido o ya fue usado.",
        )
    if datetime.now(timezone.utc) > token_data["expira"]:
        RESET_TOKENS.pop(payload.token, None)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El token ha expirado. Solicita uno nuevo.",
        )
    profile = token_data["perfil_tipo"]
    table = PROFILE_TABLES[profile]
    user_id = token_data["id_usuario"]
    with db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"UPDATE {table} SET password_hash = %s WHERE id_usuario = %s",
                (hash_password(payload.new_password), user_id),
            )
            # Semana 4 (H2): quien tenia la cuenta abierta queda fuera.
            invalidar_sesiones(cur, profile, user_id)
        conn.commit()
    RESET_TOKENS.pop(payload.token, None)
    return {"success": True, "message": "Contrasena actualizada correctamente."}


@app.post("/auth/change-password")
def change_password(
    payload: ChangePassword,
    user: dict[str, Any] = Depends(current_user),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> dict[str, Any]:
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


@app.get("/users/padres/alertas")
def parent_alerts(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    if user["perfil_tipo"] != "padre":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo padres pueden consultar alertas")

    with db_conn() as conn:
        with conn.cursor() as cur:
            alertas = list_parent_alerts(cur, user["id_usuario"])
        conn.commit()

    return {
        "message": "Alertas consultadas exitosamente",
        "alertas": alertas,
        "total": len(alertas),
        "no_leidas": sum(1 for alerta in alertas if not alerta["leida"]),
    }


@app.put("/users/padres/alertas/{id_alerta}/vista")
def mark_parent_alert_seen(
    id_alerta: int,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    if user["perfil_tipo"] != "padre":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo padres pueden actualizar alertas")

    with db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE alertas_padres
                SET leida = TRUE,
                    fecha_lectura = COALESCE(fecha_lectura, NOW())
                WHERE id_alerta = %s AND id_padre = %s
                RETURNING *
                """,
                (id_alerta, user["id_usuario"]),
            )
            alerta = cur.fetchone()
            if not alerta:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alerta no encontrada")
        conn.commit()

    return {
        "message": "Alerta marcada como vista",
        "alerta": {key: serialize(value) for key, value in alerta.items()},
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
            updated = user_to_dict(cur.fetchone(), user["perfil_tipo"])
        conn.commit()
    return {"message": "Usuario actualizado exitosamente", "user": updated}


@app.post("/users/padres/estudiantes")
def link_student(
    payload: VincularEstudiante,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    if user["perfil_tipo"] != "padre":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo padres pueden vincular estudiantes")

    # PROTOTIPO Semana 2: la vinculacion directa por CURP queda cerrada; se
    # usa la vinculacion en dos sentidos (POST /vinculacion/tutor/solicitudes).
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="La vinculación ahora requiere la confirmación del estudiante. Usa «Vincular a mi hijo».",
    )


@app.get("/users/padres/estudiantes")
def get_linked_students(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    if user["perfil_tipo"] != "padre":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo padres pueden consultar estudiantes")

    with db_conn() as conn:
        with conn.cursor() as cur:
            linked = list_parent_students(cur, user["id_usuario"])
    return {"id_padre": user["id_usuario"], "estudiantes_vinculados": linked}


@app.delete("/users/padres/estudiantes/{curp}")
def unlink_student(
    curp: str,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    if user["perfil_tipo"] != "padre":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo padres pueden desvincular estudiantes")

    with db_conn() as conn:
        with conn.cursor() as cur:
            student = find_student_by_curp(cur, curp)
            id_estudiante = student["id_usuario"]
            cur.execute(
                """
                DELETE FROM alertas_padres
                WHERE id_padre = %s AND id_estudiante = %s
                """,
                (user["id_usuario"], id_estudiante),
            )
            cur.execute(
                """
                DELETE FROM padre_estudiante
                WHERE id_padre = %s AND id_estudiante = %s
                RETURNING id_relacion
                """,
                (user["id_usuario"], id_estudiante),
            )
            deleted = cur.fetchone()
            if not deleted:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="El estudiante no está vinculado a este padre",
                )
            linked = list_parent_students(cur, user["id_usuario"])
        conn.commit()

    return {
        "message": "Estudiante desvinculado exitosamente",
        "estudiantes_vinculados": linked,
    }


@app.get("/admin/monitoreo")
def admin_monitoring(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    if user["perfil_tipo"] != "administrador":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden monitorear respuestas",
        )

    with db_conn() as conn:
        with conn.cursor() as cur:
            estudiantes = list_questionnaires_by_profile(cur, "estudiante")
            padres = list_questionnaires_by_profile(cur, "padre")

    return {
        "estudiantes": estudiantes,
        "padres": padres,
        "total": len(estudiantes) + len(padres),
    }


@app.get("/admin/cuestionarios")
def admin_question_configs(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    if not ROLE_CAPABILITIES[user["perfil_tipo"]]["can_edit_questionnaires"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden editar cuestionarios",
        )

    with db_conn() as conn:
        with conn.cursor() as cur:
            preguntas = list_question_configs(cur)

    return {"preguntas": preguntas, "total": len(preguntas)}


@app.put("/admin/cuestionarios/{id_pregunta}")
def update_admin_question_config(
    id_pregunta: int,
    payload: QuestionConfigUpdate,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    if not ROLE_CAPABILITIES[user["perfil_tipo"]]["can_edit_questionnaires"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden editar cuestionarios",
        )

    with db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE cuestionarios_config
                SET pregunta = %s,
                    puntaje = %s,
                    activo = %s,
                    fecha_actualizacion = NOW()
                WHERE id_pregunta = %s
                RETURNING
                    id_pregunta,
                    modulo_key,
                    modulo,
                    bloque,
                    codigo,
                    tipo_respuesta,
                    numero,
                    pregunta,
                    puntaje,
                    activo,
                    fecha_actualizacion
                """,
                (payload.pregunta, payload.puntaje, payload.activo, id_pregunta),
            )
            updated = cur.fetchone()
            if not updated:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Pregunta no encontrada",
                )
        conn.commit()

    return {
        "message": "Pregunta actualizada en Postgres temporal",
        "pregunta": {key: serialize(value) for key, value in updated.items()},
    }


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


# PROTOTIPO Semana 2: diario, compuerta de Serena, alertas y vinculacion.
app.include_router(
    crear_router(
        db_conn=db_conn,
        current_user=current_user,
        vincular=link_parent_to_student,
        chat_session_id=chat_session_id,
    )
)
