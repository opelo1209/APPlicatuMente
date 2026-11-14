"""Niveles de atención del cuestionario de Columbia (C-SSRS) (Semana 4).

Decisión del asesor (15 y 16 de octubre de 2026), con los resultados de la
Dra. González (n = 1 389), por la capacidad del sistema de salud:

  - URGENTE      plan suicida (detalles_plan, 4 %): evaluación urgente con un
                 especialista; en el piloto, el Hospital Infantil de México.
  - COMUNITARIO  intención sin plan (intencion_llevarlo, 8,9 %): canalizar a
                 un recurso comunitario. Los porcentajes son independientes
                 (el 8,9 % no incluye al 4 %).
  - SEGUIMIENTO  deseo de morir, ideación o pensar en un método: seguimiento
                 dentro de la app y en la escuela, sin alerta de riesgo a los
                 padres.

Antes, la alerta a padres era «riesgo alto» con cualquier «sí» (cerca del
19 % de los estudiantes con estos datos).

Semana 8 (respuestas de la Dra. González a la consulta de la Semana 5,
pregunta 14):
  - el recurso comunitario son los CECOSAMA (Centros Comunitarios de Salud
    Mental y Adicciones, antes CAPA; 32 en la CDMX), con el directorio de
    CONASAMA;
  - el contacto urgente del piloto es ella, en el Hospital Infantil. Su
    teléfono va solo en la configuración del servidor
    (CONTACTO_URGENTE_PILOTO en /etc/aptm/*.env), nunca en el código;
  - un PHQ-9 de 10 o más sin respuestas de Columbia va al centro comunitario
    (antes quedaba en seguimiento). Con ideación además tampoco baja de
    comunitario: contestar «sí» no puede llevar a una atención menor.
"""

from __future__ import annotations

import os
from typing import Any, Mapping

URGENTE = "urgente"
COMUNITARIO = "comunitario"
SEGUIMIENTO = "seguimiento"
SIN_RIESGO = "sin_riesgo"

_PLAN = "detalles_plan"
_INTENCION = "intencion_llevarlo"
_SEGUIMIENTO = ("desear_muerto", "idea_suicidarse", "como_lo_haria")

# Lo que mandaba la app antes (cssrs_nivel_dominio) y lo que manda ahora.
_NIVEL_DE_APP = {
    "planConcreto": URGENTE,
    "urgente": URGENTE,
    "comunitario": COMUNITARIO,
    "seguimiento": SEGUIMIENTO,
    "ideacion": SEGUIMIENTO,
    "sinRiesgo": SIN_RIESGO,
    "sin_riesgo": SIN_RIESGO,
}

RECURSO_URGENTE = "Hospital Infantil de México Federico Gómez"
RECURSO_COMUNITARIO = (
    "un Centro Comunitario de Salud Mental y Adicciones (CECOSAMA, antes CAPA)"
)
DIRECTORIO_CECOSAMA = "https://www.conasama.salud.gob.mx/directorio/"
UMBRAL_PHQ9_COMUNITARIO = 10
_MAX_CONTACTO = 160
_ORDEN = (SIN_RIESGO, SEGUIMIENTO, COMUNITARIO, URGENTE)


def contacto_urgente() -> str | None:
    """Nombre y teléfono del contacto urgente del piloto, si el servidor lo
    tiene configurado."""
    valor = " ".join(os.getenv("CONTACTO_URGENTE_PILOTO", "").split())
    return valor[:_MAX_CONTACTO] or None


def _valor(v: Any) -> int:
    if isinstance(v, bool):
        return int(v)
    if isinstance(v, (int, float)):
        return int(v)
    if isinstance(v, str):
        try:
            return int(v)
        except ValueError:
            return 0
    return 0


def _reactivos_cssrs(respuestas: Mapping[str, Any]) -> dict[str, int]:
    for bloque in respuestas.get("bloques", []) or []:
        if isinstance(bloque, Mapping) and bloque.get("bloque") == "CSSRS":
            return {
                str(r.get("id")): _valor(r.get("respuesta_valor"))
                for r in bloque.get("reactivos", []) or []
                if isinstance(r, Mapping) and r.get("id")
            }
    return {}


def nivel_columbia(respuestas: Mapping[str, Any]) -> str:
    """El nivel se decide por la pregunta más grave contestada con «sí»,
    no por cuántas se contestaron (C-SSRS es jerárquico)."""
    reactivos = _reactivos_cssrs(respuestas)
    if reactivos:
        if reactivos.get(_PLAN, 0) > 0:
            return URGENTE
        if reactivos.get(_INTENCION, 0) > 0:
            return COMUNITARIO
        if any(reactivos.get(p, 0) > 0 for p in _SEGUIMIENTO):
            return SEGUIMIENTO
        return SIN_RIESGO
    # Sin los reactivos: el nivel que calculó la app; si tampoco viene, el
    # total. Con solo el total no se sabe qué pregunta fue, así que se elige
    # seguimiento (nunca se baja a sin riesgo si hubo algún «sí»).
    nivel_app = _NIVEL_DE_APP.get(str(respuestas.get("cssrs_nivel_dominio", "")))
    if nivel_app is not None:
        return nivel_app
    if str(respuestas.get("cssrs_nivel_dominio", "")) == "planeacion":
        return COMUNITARIO
    return SEGUIMIENTO if _valor(respuestas.get("cssrs_score")) > 0 else SIN_RIESGO


def _phq9(respuestas: Mapping[str, Any]) -> int:
    total = _valor(respuestas.get("phq9_score"))
    if total:
        return total
    for bloque in respuestas.get("bloques", []) or []:
        if isinstance(bloque, Mapping) and bloque.get("bloque") == "PHQ9":
            return _valor(bloque.get("puntuacion_total"))
    return 0


def phq9_alto(respuestas: Mapping[str, Any]) -> bool:
    return _phq9(respuestas) >= UMBRAL_PHQ9_COMUNITARIO


def nivel_atencion(respuestas: Mapping[str, Any]) -> str:
    """Semana 8 (pregunta 14d de la Dra.): el nivel de Columbia, subido al
    menos a comunitario cuando el PHQ-9 es de 10 o más."""
    nivel = nivel_columbia(respuestas)
    if phq9_alto(respuestas) and _ORDEN.index(nivel) < _ORDEN.index(COMUNITARIO):
        return COMUNITARIO
    return nivel
