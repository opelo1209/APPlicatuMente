"""Alarma por duracion y afectacion despues de una crisis (Semana 8).

Pregunta 11 de la Dra. Gonzalez (consulta de la Semana 5). Despues de una
crisis, Serena pregunta «¿Desde cuando tienes estos pensamientos y que tan
seguido te vienen?». Ella anoto: «Considerar alarma mas de 6 meses y diario,
y tambien que tanto le afecta: por esta razon ya no va a la escuela, ya no
frecuenta a sus amigos, dejo de hacer las cosas que acostumbraba».

Aqui solo se detecta en el texto; la alarma la arma serena_pipeline y va al
equipo de apoyo con el tipo de senal, sin lo que escribio el estudiante.

ESTADO: BORRADOR. Las frases que la activan las valida la Dra.
"""

from __future__ import annotations

import re

from .clasificador_riesgo import _normalizar

DURACION_LARGA = "duracion_larga"
DIARIO = "diario"
AFECTACION = "afectacion_vida_diaria"

# Seis meses o mas, un año o mas, «mucho tiempo», «siempre».
_MESES_LARGOS = r"(?:6|7|8|9|10|11|12|seis|siete|ocho|nueve|diez|once|doce|varios|muchos)\s+meses"
_ANIOS = r"(?:un|1|2|3|dos|tres|varios|muchos)\s+anos?"
_DURACION = re.compile(
    rf"\b(?:{_MESES_LARGOS}|{_ANIOS}|medio ano|mucho tiempo|desde siempre|desde la primaria|desde chiquit[oa])\b"
)
_DIARIO = re.compile(r"\b(?:todos los dias|a diario|diario|cada dia|todo el (?:tiempo|dia))\b")
_AFECTACION = re.compile(
    r"\b(?:"
    r"(?:ya no|deje de|no he podido)\s+(?:ir|voy|asisto|asistir)\s+a\s+(?:la\s+)?(?:escuela|clases|secu|prepa)"
    r"|falto (?:mucho )?a (?:la )?(?:escuela|clases)"
    r"|(?:ya no|deje de)\s+(?:veo|ver|salgo|salir|hablo|hablar|frecuento|frecuentar)\b[^.]*\bamig[oa]s"
    r"|(?:ya no|deje de)\s+(?:hago|hacer)\b[^.]*\b(?:gustaba|hacia|acostumbraba)"
    r"|ya no hago nada"
    r"|ya no me levanto"
    r")"
)


def senales_cronicidad(texto: str) -> tuple[str, ...]:
    """Los tipos de senal presentes, en orden fijo; vacio si no hay."""
    plano = _normalizar(texto or "")
    return tuple(
        senal
        for senal, patron in ((DURACION_LARGA, _DURACION), (DIARIO, _DIARIO), (AFECTACION, _AFECTACION))
        if patron.search(plano)
    )
