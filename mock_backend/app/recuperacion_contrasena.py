"""Tokens de recuperacion de contrasena (Semana 5, hallazgos H4 y H7).

Antes vivian en un diccionario en la RAM del proceso (RESET_TOKENS): se
perdian al reiniciar y, con mas de un worker, el token creado en uno no
existia en el otro. Ahora estan en PostgreSQL, y se guarda solo el SHA-256
del token: quien lea la base (o un respaldo) no puede usarlos.

Semana 8 (asesor, 12 de noviembre): ademas del enlace por correo, un codigo
de un solo uso que genera el administrador, para cuando no hay correo. Es
corto para dictarlo (XXXX-XXXX, sin letras que se confundan), vale 24 horas
y se guarda igual: solo su SHA-256. Adivinarlo tiene limite de intentos.
"""

from __future__ import annotations

import hashlib
import os
import secrets
from dataclasses import dataclass
from typing import Any

VIGENCIA_MINUTOS = 60
VIGENCIA_CODIGO_HORAS = 24
# Sin 0/O, 1/I/L: se dictan sin confundirse. 31^8 ~ 8.5e11 combinaciones.
ALFABETO_CODIGO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
_LARGO_CODIGO = 8
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


def nuevo_codigo() -> str:
    letras = "".join(secrets.choice(ALFABETO_CODIGO) for _ in range(_LARGO_CODIGO))
    return f"{letras[:4]}-{letras[4:]}"


def normalizar_codigo(escrito: str) -> str | None:
    """El codigo como se guarda (8 letras en mayusculas), o None si lo
    escrito no tiene forma de codigo (por ejemplo, un token del correo)."""
    plano = "".join(c for c in escrito.upper() if c.isalnum())
    if len(plano) != _LARGO_CODIGO or not set(plano) <= set(ALFABETO_CODIGO):
        return None
    return plano


def crear_codigo(cur: Any, perfil_tipo: str, id_usuario: int) -> str:
    """Codigo para que el administrador se lo de al estudiante. Anula los
    enlaces y codigos anteriores de la misma cuenta."""
    codigo = nuevo_codigo()
    _guardar(cur, perfil_tipo, id_usuario, normalizar_codigo(codigo) or "", VIGENCIA_CODIGO_HORAS * 60)
    return codigo


def _guardar(cur: Any, perfil_tipo: str, id_usuario: int, secreto: str, minutos: int) -> None:
    cur.execute("DELETE FROM recuperacion_tokens WHERE expira < NOW()")
    cur.execute(
        "DELETE FROM recuperacion_tokens WHERE perfil_tipo = %s AND id_usuario = %s",
        (perfil_tipo, id_usuario),
    )
    cur.execute(
        """
        INSERT INTO recuperacion_tokens (token_sha256, perfil_tipo, id_usuario, expira)
        VALUES (%s, %s, %s, NOW() + make_interval(mins => %s))
        """,
        (_huella(secreto), perfil_tipo, id_usuario, minutos),
    )


def crear(cur: Any, perfil_tipo: str, id_usuario: int) -> str:
    """Token nuevo de un solo uso. Los anteriores del mismo usuario dejan de
    servir: solo vale el ultimo correo."""
    token = secrets.token_urlsafe(32)
    _guardar(cur, perfil_tipo, id_usuario, token, VIGENCIA_MINUTOS)
    return token


def consumir_token_o_codigo(cur: Any, escrito: str) -> TokenValido | None:
    """Semana 8: lo que escribio puede ser el token del correo o el codigo
    del administrador (en minusculas, con espacios o sin guion)."""
    dueno = consumir(cur, escrito.strip())
    if dueno is None:
        codigo = normalizar_codigo(escrito)
        if codigo is not None:
            dueno = consumir(cur, codigo)
    return dueno


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
