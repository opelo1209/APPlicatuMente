"""Tablas de la base: usuarios, vinculos, sesiones, cuestionarios y
alertas a padres, mas las de cada modulo (prototipo, limites,
recuperacion y cuentas borradas). Todo es idempotente (IF NOT EXISTS).

Semana 6: salio de init_db() en main.py sin cambios.
"""

from __future__ import annotations

from typing import Any

from . import limite_intentos as limite
from . import recuperacion_contrasena as recuperacion
from .config_cuestionarios import seed_question_configs
from .cuentas_admin import crear_tabla as crear_tabla_cuentas_borradas
from .perfiles import PROFILE_TABLES
from .prototipo_api import crear_tablas_prototipo


def crear_esquema(cur: Any) -> None:
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
    limite.crear_tabla(cur)
    recuperacion.crear_tabla(cur)
    crear_tabla_cuentas_borradas(cur)
