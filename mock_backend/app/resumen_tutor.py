"""Resumen del diario para el tutor (padre, madre o quien cuida).

Semana 5 (reunion con el asesor): como en una terapia, el terapeuta no le
cuenta a los padres lo que dijo el adolescente, sino un resumen de como va.
Aqui igual:

  - Se arma con lo que el estudiante MARCO (polaridad y emociones de cada
    dia) y con una sola senal del texto: si hubo palabras altisonantes. El
    texto se lee en el servidor para buscarlas y se descarta: ni las
    palabras ni una cita salen de esta funcion.
  - Cada frase sale de una plantilla, no de un modelo, asi que no inventa
    nada y se puede revisar con psicologia.
  - Se agrega lo que ya decia resumen_riesgo para el tutor cuando hubo
    alertas.

A los estudiantes se les avisa al empezar que sus papas reciben un resumen
de este estilo (texto del aviso en la app, BORRADOR para psicologia).

ESTADO: BORRADOR. Que recibe el tutor, cada cuando y por que medio lo
deciden psicologia y el asesor; por ahora solo lo ve el administrador.
"""

from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass
from datetime import date
from typing import Mapping, Sequence

from .clasificador_riesgo import _normalizar
from .emociones_catalogo import POLARIDAD_NEGATIVA, POLARIDAD_NEUTRA, POLARIDAD_POSITIVA, buscar

# BORRADOR para psicologia: groserias comunes en Mexico (texto ya sin
# acentos). Solo se cuenta si aparecen; nunca se dice cuales.
_ALTISONANTES = re.compile(
    r"\b(?:pendej\w*|pinche\w*|put[ao]s?|putiza\w*|ching\w*|verga\w*|cabron\w*|culer[ao]s?|"
    r"mierda\w*|jod[eiao]\w*|ojete\w*|mamon\w*|mamad[ao]s?|huevon\w*)\b"
)


def contar_altisonantes(texto: str) -> int:
    return len(_ALTISONANTES.findall(_normalizar(texto or "")))


@dataclass(frozen=True)
class DiaDiario:
    fecha: date
    polaridad: str
    emociones: tuple[str, ...]
    altisonantes: bool = False


def dia_de_fila(fila: Mapping[str, object]) -> DiaDiario:
    """Una entrada del diario sin su texto: solo si tenia groserias."""
    return DiaDiario(
        fecha=fila["fecha"],  # type: ignore[arg-type]
        polaridad=str(fila["polaridad"]),
        emociones=tuple(str(e) for e in (fila.get("emociones") or ())),  # type: ignore[union-attr]
        altisonantes=contar_altisonantes(str(fila.get("texto") or "")) > 0,
    )


@dataclass(frozen=True)
class ResumenTutor:
    texto: str
    dias_con_registro: int
    positivos: int
    neutros: int
    dificiles: int
    dias_altisonantes: int


def _nombre(clave: str) -> str | None:
    try:
        return buscar(clave).nombre.lower()
    except ValueError:
        return None


def _veces(n: int) -> str:
    return "1 día" if n == 1 else f"{n} días"


def _lista(nombres: Sequence[str]) -> str:
    if len(nombres) <= 1:
        return "".join(nombres)
    return ", ".join(nombres[:-1]) + " y " + nombres[-1]


def _tendencia(dias: Sequence[DiaDiario]) -> str | None:
    """Compara la primera y la segunda mitad del periodo (dias dificiles)."""
    if len(dias) < 4:
        return None
    mitad = len(dias) // 2
    antes = sum(d.polaridad == POLARIDAD_NEGATIVA for d in dias[:mitad]) / mitad
    despues = sum(d.polaridad == POLARIDAD_NEGATIVA for d in dias[mitad:]) / (len(dias) - mitad)
    if despues - antes >= 0.34:
        return "Los últimos días se vieron más difíciles que al inicio del periodo."
    if antes - despues >= 0.34:
        return "Los últimos días se vieron mejor que al inicio del periodo."
    return None


def resumir_diario(dias: Sequence[DiaDiario], nombre: str = "su hijo o hija", periodo_dias: int = 7) -> ResumenTutor:
    ordenados = sorted(dias, key=lambda d: d.fecha)
    conteo = Counter(d.polaridad for d in ordenados)
    pos, neu, neg = conteo[POLARIDAD_POSITIVA], conteo[POLARIDAD_NEUTRA], conteo[POLARIDAD_NEGATIVA]
    groserias = sum(d.altisonantes for d in ordenados)
    if not ordenados:
        texto = (
            f"En los últimos {periodo_dias} días {nombre} no escribió en su diario. No es una mala señal por sí "
            "misma; si quiere, pregúntele cómo le ha ido, sin presionar."
        )
        return ResumenTutor(texto, 0, 0, 0, 0, 0)

    emociones = Counter(e for d in ordenados for e in d.emociones)
    principales = [n for n in (_nombre(c) for c, _ in emociones.most_common(3)) if n]
    frases = [
        f"En los últimos {periodo_dias} días {nombre} escribió en su diario {_veces(len(ordenados))}: "
        f"{pos} {'bueno' if pos == 1 else 'buenos'}, {neu} {'regular' if neu == 1 else 'regulares'} y "
        f"{neg} {'difícil' if neg == 1 else 'difíciles'}.",
    ]
    if principales:
        frases.append(f"Lo que más marcó fue {_lista(principales)}.")
    tendencia = _tendencia(ordenados)
    if tendencia:
        frases.append(tendencia)
    if groserias:
        frases.append(
            f"En {_veces(groserias)} usó palabras altisonantes. Suele ser una forma de desahogar enojo o "
            "frustración; vale la pena platicarlo con calma y sin regañar, preguntando qué le hizo sentir así."
        )
    if neg > len(ordenados) / 2:
        frases.append(
            "Hubo más días difíciles que buenos. Le sugerimos buscar un momento tranquilo para platicar y "
            "escuchar sin juzgar."
        )
    frases.append("Este resumen no incluye lo que escribió: solo cómo dijo sentirse.")
    return ResumenTutor(" ".join(frases), len(ordenados), pos, neu, neg, groserias)
