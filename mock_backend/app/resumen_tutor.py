"""Resumen del diario para el tutor (padre, madre o quien cuida).

Semana 5 (reunion con el asesor): como en una terapia, el terapeuta no le
cuenta a los padres lo que dijo el adolescente, sino un resumen de como va.

Semana 8 (respuestas de la Dra. Gonzalez a la consulta de la Semana 5,
preguntas 6 y 7):
  - el resumen es MENSUAL y lo recibe el tutor en su cuenta de la app;
  - dice solo cuantos dias fueron buenos, regulares y dificiles: ya no
    nombra emociones ni la tendencia;
  - no menciona palabras altisonantes. Por eso el texto del diario ya ni se
    lee para armarlo: solo la fecha y la polaridad que marco el estudiante;
  - sugiere platicar desde el 60 % de dias dificiles. Ella anoto «mas de 60
    dias», que no cabe en un mes; se toma como 60 % mientras lo confirma.

Cada frase sale de una plantilla, no de un modelo, asi que no inventa nada.
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from datetime import date
from typing import Mapping, Sequence

from .emociones_catalogo import POLARIDAD_NEGATIVA, POLARIDAD_NEUTRA, POLARIDAD_POSITIVA

UMBRAL_PLATICAR = 0.6

_MESES = (
    "enero", "febrero", "marzo", "abril", "mayo", "junio",
    "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
)


@dataclass(frozen=True)
class DiaDiario:
    fecha: date
    polaridad: str
    emociones: tuple[str, ...] = ()


def dia_de_fila(fila: Mapping[str, object]) -> DiaDiario:
    """Una entrada del diario sin su texto."""
    return DiaDiario(
        fecha=fila["fecha"],  # type: ignore[arg-type]
        polaridad=str(fila["polaridad"]),
        emociones=tuple(str(e) for e in (fila.get("emociones") or ())),  # type: ignore[union-attr]
    )


@dataclass(frozen=True)
class ResumenTutor:
    texto: str
    dias_con_registro: int
    positivos: int
    neutros: int
    dificiles: int


def mes_anterior(hoy: date) -> tuple[int, int]:
    """El ultimo mes completo: el que se entrega al tutor."""
    return (hoy.year - 1, 12) if hoy.month == 1 else (hoy.year, hoy.month - 1)


def nombre_mes(anio: int, mes: int) -> str:
    return f"{_MESES[mes - 1]} de {anio}"


def _plural(n: int, singular: str, plural: str) -> str:
    return f"{n} {singular if n == 1 else plural}"


def resumir_diario(dias: Sequence[DiaDiario], nombre: str = "su hijo o hija", periodo: str = "este mes") -> ResumenTutor:
    """`periodo` completa la frase «En {periodo} ...», por ejemplo
    «octubre de 2026»."""
    conteo = Counter(d.polaridad for d in dias)
    pos, neu, neg = conteo[POLARIDAD_POSITIVA], conteo[POLARIDAD_NEUTRA], conteo[POLARIDAD_NEGATIVA]
    total = len(dias)
    if total == 0:
        texto = (
            f"En {periodo} {nombre} no escribió en su diario. No es una mala señal por sí misma; "
            "si quiere, pregúntele cómo le ha ido, sin presionar."
        )
        return ResumenTutor(texto, 0, 0, 0, 0)

    frases = [
        f"En {periodo} {nombre} escribió en su diario {_plural(total, 'día', 'días')}: "
        f"{_plural(pos, 'bueno', 'buenos')}, {_plural(neu, 'regular', 'regulares')} y "
        f"{_plural(neg, 'difícil', 'difíciles')}.",
    ]
    if neg / total >= UMBRAL_PLATICAR:
        frases.append(
            "Hubo varios días difíciles. Le sugerimos buscar un momento tranquilo para platicar y "
            "escuchar sin juzgar."
        )
    frases.append("Este resumen no incluye lo que escribió: solo cómo dijo sentirse.")
    return ResumenTutor(" ".join(frases), total, pos, neu, neg)
