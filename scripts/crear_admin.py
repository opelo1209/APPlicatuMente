#!/usr/bin/env python3
"""Crea una cuenta de administrador de APTM desde el servidor.

El registro publico ya no permite crear administradores: esa cuenta puede
leer las respuestas de TODOS los estudiantes y editar los cuestionarios
clinicos, asi que solo debe crearla alguien con acceso al servidor.

Uso (en el servidor, con el entorno virtual del backend):

    cd /opt/aptm
    set -a; . /etc/aptm/aptm.env; set +a
    .venv/bin/python scripts/crear_admin.py

Pide los datos de forma interactiva. La contrasena no se escribe en
pantalla ni queda en el historial del shell, y se guarda con el mismo
algoritmo (PBKDF2-SHA256) que usa el backend.
"""

from __future__ import annotations

import getpass
import os
import re
import secrets
import sys

import psycopg2
from psycopg2.extras import RealDictCursor

# Permite importar hash_password del backend sin duplicar el algoritmo: si
# algun dia cambia ahi, este script lo sigue automaticamente.
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from app.main import hash_password  # noqa: E402

LONGITUD_MINIMA_PASSWORD = 12


def pedir(texto: str, obligatorio: bool = True) -> str:
    while True:
        valor = input(texto).strip()
        if valor or not obligatorio:
            return valor
        print("   Este dato es obligatorio.")


def pedir_password() -> str:
    while True:
        password = getpass.getpass("Contrasena (no se muestra): ")
        if len(password) < LONGITUD_MINIMA_PASSWORD:
            print(f"   Debe tener al menos {LONGITUD_MINIMA_PASSWORD} caracteres.")
            continue
        if password != getpass.getpass("Repite la contrasena: "):
            print("   No coinciden, intenta de nuevo.")
            continue
        return password


def main() -> int:
    url = os.getenv("DATABASE_URL")
    if not url:
        print("ERROR: falta DATABASE_URL. Carga /etc/aptm/aptm.env antes de correr esto.")
        return 1

    print("Crear cuenta de administrador de APTM")
    print("-" * 38)
    nombre_usuario = pedir("Nombre de usuario: ")
    correo = pedir("Correo: ")
    if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", correo):
        print("ERROR: el correo no tiene un formato valido.")
        return 1
    nombres = pedir("Nombre(s): ")
    apellido_paterno = pedir("Apellido paterno: ")
    apellido_materno = pedir("Apellido materno (opcional): ", obligatorio=False)
    password = pedir_password()

    with psycopg2.connect(url, cursor_factory=RealDictCursor) as conexion:
        with conexion.cursor() as cursor:
            # El nombre de usuario y el correo deben ser unicos en los tres
            # perfiles, igual que en el registro normal.
            for tabla in ("usuarios_estudiantes", "usuarios_padres", "usuarios_administradores"):
                cursor.execute(
                    f"SELECT 1 FROM {tabla} WHERE nombre_usuario = %s OR correo = %s LIMIT 1",
                    (nombre_usuario, correo),
                )
                if cursor.fetchone():
                    print(f"ERROR: ese usuario o correo ya existe (en {tabla}).")
                    return 1

            cursor.execute(
                """
                INSERT INTO usuarios_administradores (
                    keycloack_id, nombre_usuario, correo, password_hash,
                    nombres, apellido_paterno, apellido_materno
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                RETURNING id_usuario
                """,
                (
                    f"local-administrador-{secrets.token_hex(16)}",
                    nombre_usuario,
                    correo,
                    hash_password(password),
                    nombres,
                    apellido_paterno,
                    apellido_materno or None,
                ),
            )
            id_usuario = cursor.fetchone()["id_usuario"]
        conexion.commit()

    print()
    print(f"Listo: administrador '{nombre_usuario}' creado (id {id_usuario}).")
    print("Puede iniciar sesion en https://ml.izt.uam.mx/aptm/ con esa contrasena.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
