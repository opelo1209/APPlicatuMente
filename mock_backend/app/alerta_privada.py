"""Alertas sin lo que escribio el estudiante (Semana 8, pregunta 5 de la Dra.).

Antes cada alerta guardaba en `evidencia` el tipo de senal y el fragmento
que la activo («ideacion_directa:quiero morirme»), y el administrador lo
veia. La Dra. Gonzalez pidio mostrar solo el tipo de senal. Aqui se quita el
fragmento ANTES de guardar, y una consulta limpia las alertas viejas al
arrancar el servidor: el fragmento deja de existir, no solo de mostrarse.
"""

from __future__ import annotations

from types import MappingProxyType
from typing import Iterable

# Nombre que ve el equipo de apoyo para cada tipo de senal del clasificador.
ETIQUETAS_SENAL = MappingProxyType({
    "ideacion_directa": "Ideación suicida",
    "planeacion_o_intencion": "Plan o intención suicida",
    "intento_previo": "Intento de suicidio anterior",
    "autolesion_ocurrida": "Autolesión",
    "desesperanza_extrema": "Desesperanza",
    "despedida": "Mensaje de despedida",
    "peticion_secreto": "Pide guardar un secreto",
    "carga_percibida": "Se siente una carga",
    "hiperbole_muerte": "Habla de la muerte (posible exageración)",
    "riesgo_tercero": "Riesgo para otra persona",
    "intencion_sin_objeto": "Intención sin objeto claro",
    "cssrs_alto": "Cuestionario de Columbia en riesgo alto",
    # Semana 8 (pregunta 11 de la Dra.): despues de una crisis.
    "duracion_larga": "Lo siente desde hace más de 6 meses",
    "diario": "Lo siente a diario",
    "afectacion_vida_diaria": "Le afecta la vida diaria (escuela, amigos, actividades)",
})

# Idempotente: solo toca las filas que todavia traen «tipo:fragmento».
SQL_LIMPIAR_FRAGMENTOS = """
    UPDATE alertas_riesgo a
    SET evidencia = COALESCE((
        SELECT jsonb_agg(tipo ORDER BY primera)
        FROM (
            SELECT split_part(e.valor, ':', 1) AS tipo, MIN(e.orden) AS primera
            FROM jsonb_array_elements_text(a.evidencia) WITH ORDINALITY AS e(valor, orden)
            GROUP BY 1
        ) tipos
    ), '[]'::jsonb)
    WHERE jsonb_typeof(a.evidencia) = 'array'
      AND EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(a.evidencia) AS v(valor)
        WHERE position(':' IN v.valor) > 0
      )
"""


def tipos_de_senal(evidencia: Iterable[object]) -> list[str]:
    """Solo el tipo de cada senal, sin repetir y en el orden en que aparecio."""
    vistos: dict[str, None] = {}
    for elemento in evidencia:
        vistos.setdefault(str(elemento).split(":", 1)[0].strip(), None)
    return [t for t in vistos if t]


def etiqueta_senal(tipo: str) -> str:
    return ETIQUETAS_SENAL.get(tipo, tipo)
