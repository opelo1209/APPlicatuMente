"""Tokens de recuperacion de contrasena (Semana 5, hallazgos H4 y H7).

Antes vivian en un diccionario en la RAM del proceso (RESET_TOKENS): se
perdian al reiniciar y, con mas de un worker, el token creado en uno no
existia en el otro. Ahora estan en PostgreSQL, y se guarda solo el SHA-256
del token: quien lea la base (o un respaldo) no puede usarlos.
"""

from __future__ import annotations

import hashlib
import os
import secrets
from dataclasses import dataclass
from typing import Any

VIGENCIA_MINUTOS = 60
# Enlace que llega por correo; el token va al final. Se configura por
# despliegue (produccion y prototipo tienen direcciones distintas).
URL_POR_OMISION = "https://ml.izt.uam.mx/aptm/#/restablecer?token="


@dataclass(frozen=True)
class TokenValido:
    perfil_tipo: str
    id_usuario: int


def crear_tabla(cur: Any) -> None:
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS recuperacion_tokens (
            token_sha256 CHAR(64) PRIMARY KEY,
            perfil_tipo VARCHAR(30) NOT NULL,
            id_usuario INTEGER NOT NULL,
            expira TIMESTAMPTZ NOT NULL,
            creado TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
        """
    )


def _huella(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def crear(cur: Any, perfil_tipo: str, id_usuario: int) -> str:
    """Token nuevo de un solo uso. Los anteriores del mismo usuario dejan de
    servir: solo vale el ultimo correo."""
    cur.execute("DELETE FROM recuperacion_tokens WHERE expira < NOW()")
    cur.execute(
        "DELETE FROM recuperacion_tokens WHERE perfil_tipo = %s AND id_usuario = %s",
        (perfil_tipo, id_usuario),
    )
    token = secrets.token_urlsafe(32)
    cur.execute(
        """
        INSERT INTO recuperacion_tokens (token_sha256, perfil_tipo, id_usuario, expira)
        VALUES (%s, %s, %s, NOW() + make_interval(mins => %s))
        """,
        (_huella(token), perfil_tipo, id_usuario, VIGENCIA_MINUTOS),
    )
    return token


def consumir(cur: Any, token: str) -> TokenValido | None:
    """Borra el token y dice de quien era, o None si no existe o vencio.
    DELETE ... RETURNING lo hace atomico: dos peticiones con el mismo token
    no pueden usarlo las dos."""
    cur.execute(
        "DELETE FROM recuperacion_tokens WHERE token_sha256 = %s RETURNING perfil_tipo, id_usuario, expira > NOW() AS vigente",
        (_huella(token),),
    )
    fila = cur.fetchone()
    if fila is None or not fila["vigente"]:
        return None
    return TokenValido(fila["perfil_tipo"], fila["id_usuario"])


def enlace(token: str) -> str:
    return os.getenv("RECUPERACION_URL", URL_POR_OMISION) + token


def cuerpo_correo(nombre: str, token: str) -> str:
    return (
        f"Hola, {nombre}:\n\n"
        "Recibimos una solicitud para restablecer tu contraseña de APPlicatuMente.\n"
        f"Para elegir una nueva, abre este enlace (vale {VIGENCIA_MINUTOS} minutos y un solo uso):\n\n"
        f"{enlace(token)}\n\n"
        "Si no fuiste tú, ignora este correo: tu contraseña no cambia.\n"
    )
