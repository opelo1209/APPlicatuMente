"""Que se le manda al estudiante y que se queda en el servidor (Semana 4, T3).

Antes /chat y /chat/stream devolvian `reglas` y `decision`: que reglas del
detector se activaron y como se decidio. Con eso un estudiante puede probar
frases hasta aprender a esquivar el detector de crisis (hallazgo H3). La app
no usa esos campos, asi que se separan:

- respuesta_estudiante(): solo lo que la app necesita para mostrar la
  respuesta.
- traza_decision(): como se decidio, para el registro del servidor. No
  incluye el mensaje del estudiante.
"""

from __future__ import annotations

from typing import Any

from .serena_pipeline import RespuestaSerena


def respuesta_estudiante(r: RespuestaSerena, sesion_id: str) -> dict[str, Any]:
    return {
        "respuesta": r.texto,
        "tipo": r.tipo,
        "detener": r.detener,
        "fuentes": [dict(f) for f in r.fuentes],
        # Semana 4: la app las muestra en una tarjeta aparte del texto.
        "lineas": [dict(l) for l in r.lineas],
        "sesion_id": sesion_id,
    }


def traza_decision(r: RespuestaSerena) -> dict[str, Any]:
    entrada = r.etapas["entrada"]
    salida = r.etapas.get("salida") or {}
    return {
        "tipo": r.tipo,
        "entrada": entrada["accion"],
        "reglas_entrada": list(entrada["reglas"]),
        "salida": salida.get("accion"),
        "reglas_salida": list(salida.get("reglas", [])),
        "modelo": r.etapas.get("modelo"),
        "milisegundos": r.etapas.get("milisegundos"),
    }
