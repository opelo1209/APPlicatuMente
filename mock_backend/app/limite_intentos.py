"""Limite de intentos (Semana 5, hallazgo H5).

Antes no habia ningun limite: se podian probar contrasenas sin fin en
/auth/login, claves en /auth/demo, pedir recuperaciones de contrasena en
rafaga y mandar mensajes al chat sin pausa (cada uno ocupa el modelo de
Serena varios segundos).

Los intentos se guardan en PostgreSQL y no en la RAM del proceso, para que
el limite se cumpla aunque el servicio corra con varios workers o se
reinicie (la misma razon por la que H7 saca de la RAM los tokens de
recuperacion). La clave de cada contador es un texto como
"login:ana_demo" o "login-ip:201.1.2.3"; no se guarda la contrasena ni el
mensaje.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any

from fastapi import HTTPException, status

# Los intentos de mas de un dia ya no cuentan para ningun limite.
RETENCION_HORAS = 24


@dataclass(frozen=True)
class Limite:
    """`maximo` eventos dentro de `ventana_min` minutos."""

    nombre: str
    maximo: int
    ventana_min: int


# Por cuenta: cinco contrasenas equivocadas seguidas bloquean 15 minutos.
LOGIN_CUENTA = Limite("login", 5, 15)
# Por direccion: mas alto, porque un salon entero puede salir a internet
# con la misma IP de la escuela.
LOGIN_IP = Limite("login-ip", 30, 15)
DEMO_IP = Limite("demo-ip", 10, 15)
RECUPERACION_CUENTA = Limite("recuperacion", 3, 60)
RECUPERACION_IP = Limite("recuperacion-ip", 10, 60)
# Un mensaje de Serena tarda ~13 s en el prototipo; 15 por minuto solo se
# alcanza con un programa, no escribiendo.
CHAT_USUARIO = Limite("chat", 15, 1)


def crear_tabla(cur: Any) -> None:
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS intentos_acceso (
            id_intento BIGSERIAL PRIMARY KEY,
            clave VARCHAR(300) NOT NULL,
            fecha TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
        """
    )
    cur.execute("CREATE INDEX IF NOT EXISTS intentos_acceso_clave_fecha ON intentos_acceso (clave, fecha)")


def clave(limite: Limite, sujeto: str) -> str:
    return f"{limite.nombre}:{sujeto.strip().lower()[:250]}"


def segundos_de_bloqueo(cur: Any, limite: Limite, sujeto: str) -> int:
    """0 si todavia hay intentos; si no, cuantos segundos faltan para que
    el mas antiguo de la ventana deje de contar."""
    cur.execute(
        """
        SELECT COUNT(*) AS n,
               EXTRACT(EPOCH FROM MIN(fecha) + make_interval(mins => %s) - NOW()) AS restante
        FROM intentos_acceso
        WHERE clave = %s AND fecha > NOW() - make_interval(mins => %s)
        """,
        (limite.ventana_min, clave(limite, sujeto), limite.ventana_min),
    )
    fila = cur.fetchone()
    if fila["n"] < limite.maximo:
        return 0
    return max(1, math.ceil(float(fila["restante"] or 0)))


def registrar(cur: Any, limite: Limite, sujeto: str) -> None:
    cur.execute("INSERT INTO intentos_acceso (clave) VALUES (%s)", (clave(limite, sujeto),))
    # Limpieza de paso, como las sesiones vencidas (Semana 4).
    cur.execute(
        "DELETE FROM intentos_acceso WHERE fecha < NOW() - make_interval(hours => %s)",
        (RETENCION_HORAS,),
    )


def limpiar(cur: Any, limite: Limite, sujeto: str) -> None:
    cur.execute("DELETE FROM intentos_acceso WHERE clave = %s", (clave(limite, sujeto),))


def texto_espera(segundos: int) -> str:
    minutos = math.ceil(segundos / 60)
    if minutos <= 1:
        return "Espera un minuto e inténtalo de nuevo."
    return f"Espera {minutos} minutos e inténtalo de nuevo."


def exigir(cur: Any, *pares: tuple[Limite, str]) -> None:
    """Responde 429 si cualquiera de los limites ya se alcanzo. Retry-After
    lleva el mayor de los tiempos de espera."""
    espera = max((segundos_de_bloqueo(cur, limite, sujeto) for limite, sujeto in pares), default=0)
    if espera:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Demasiados intentos. {texto_espera(espera)}",
            headers={"Retry-After": str(espera)},
        )
