"""Preparacion comun de las pruebas que usan PostgreSQL (Semana 5).

1. Base vacia: antes las pruebas suponian una base ya creada y con los
   personajes de la demo sembrados a mano (ana_demo, luis_demo, ...). En una
   base nueva, como la de la integracion continua, fallaban. Aqui se crean
   las tablas (init_db es idempotente) y los personajes que falten.
2. Contadores de intentos (H5): viven en la base, asi que sin limpiarlos una
   corrida dejaria bloqueada a la siguiente (por ejemplo, las claves
   equivocadas de test_demo_login.py).

Si la base de pruebas no esta disponible no se hace nada: las pruebas que no
la usan siguen corriendo igual.
"""
import importlib
import os
import secrets

import psycopg2
import pytest

DB = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@127.0.0.1:55433/aptm_proto")

# Personajes de la demo (main.DEMO_USERS) y la tabla de cada uno.
PERSONAJES = (
    ("usuarios_estudiantes", "ana_demo", "Ana"),
    ("usuarios_padres", "luis_demo", "Luis"),
    ("usuarios_padres", "maria_demo", "María"),
    ("usuarios_administradores", "admin_demo", "Admin"),
)


def _conectar():
    try:
        return psycopg2.connect(DB, connect_timeout=1)
    except psycopg2.OperationalError:
        return None


@pytest.fixture(scope="session", autouse=True)
def _base_de_pruebas():
    conn = _conectar()
    if conn is None:
        yield
        return
    conn.close()
    os.environ.setdefault("DATABASE_URL", DB)
    import app.main as main_mod

    importlib.reload(main_mod)
    main_mod.init_db()
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            for tabla, usuario, nombre in PERSONAJES:
                cur.execute(
                    f"""
                    INSERT INTO {tabla} (keycloack_id, nombre_usuario, correo, password_hash, nombres, apellido_paterno)
                    VALUES (%s, %s, %s, %s, %s, 'Demo')
                    ON CONFLICT (nombre_usuario) DO NOTHING
                    """,
                    # La contrasena es aleatoria: a la demo se entra por /auth/demo.
                    (f"local-{usuario}", usuario, f"{usuario}@demo.local", f"sin-uso${secrets.token_hex(8)}", nombre),
                )
        conn.commit()
    yield


@pytest.fixture(autouse=True)
def _intentos_limpios():
    conn = _conectar()
    if conn is None:
        yield
        return
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT to_regclass('intentos_acceso')")
            if cur.fetchone()[0] is not None:
                cur.execute("DELETE FROM intentos_acceso")
        conn.commit()
    finally:
        conn.close()
    yield
