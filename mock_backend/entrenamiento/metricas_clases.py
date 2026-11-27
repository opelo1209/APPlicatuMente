"""Metricas por clase para comparar el analizador antes y despues (Semana 8).

Sin dependencias: se prueba en el backend y corre igual en el servidor.
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from typing import Sequence

CLASES = ("negativo", "neutro", "positivo")


@dataclass(frozen=True)
class MetricaClase:
    clase: str
    precision: float
    recall: float
    f1: float
    soporte: int


def _validar(reales: Sequence[str], predichas: Sequence[str]) -> None:
    if len(reales) != len(predichas):
        raise ValueError("reales y predichas deben tener el mismo largo")
    desconocidas = (set(reales) | set(predichas)) - set(CLASES)
    if desconocidas:
        raise ValueError(f"clases desconocidas: {sorted(desconocidas)}")


def matriz_confusion(reales: Sequence[str], predichas: Sequence[str]) -> dict[str, dict[str, int]]:
    """matriz[real][predicha] = cuantos ejemplos."""
    _validar(reales, predichas)
    conteo = Counter(zip(reales, predichas))
    return {r: {p: conteo[(r, p)] for p in CLASES} for r in CLASES}


def _division(a: float, b: float) -> float:
    return round(a / b, 4) if b else 0.0


def por_clase(reales: Sequence[str], predichas: Sequence[str]) -> tuple[MetricaClase, ...]:
    matriz = matriz_confusion(reales, predichas)
    metricas = []
    for c in CLASES:
        acierto = matriz[c][c]
        predichas_c = sum(matriz[r][c] for r in CLASES)
        reales_c = sum(matriz[c].values())
        precision, recall = _division(acierto, predichas_c), _division(acierto, reales_c)
        f1 = _division(2 * precision * recall, precision + recall)
        metricas.append(MetricaClase(c, precision, recall, f1, reales_c))
    return tuple(metricas)


def f1_macro(reales: Sequence[str], predichas: Sequence[str]) -> float:
    return round(sum(m.f1 for m in por_clase(reales, predichas)) / len(CLASES), 4)


def exactitud(reales: Sequence[str], predichas: Sequence[str]) -> float:
    _validar(reales, predichas)
    return _division(sum(r == p for r, p in zip(reales, predichas)), len(reales))


def distribucion(etiquetas: Sequence[str]) -> dict[str, float]:
    """Que proporcion de los ejemplos cae en cada clase."""
    conteo = Counter(etiquetas)
    return {c: _division(conteo[c], len(etiquetas)) for c in CLASES}


def cambios(reales: Sequence[str], antes: Sequence[str], despues: Sequence[str]) -> dict[str, object]:
    """Que hizo el reentrenamiento: cuantos ejemplos cambiaron de clase,
    cuantos se corrigieron y cuantos se echaron a perder, y hacia donde se
    movieron (por ejemplo, de neutro a negativo)."""
    _validar(reales, antes)
    _validar(reales, despues)
    movidos = Counter(f"{a}->{d}" for a, d in zip(antes, despues) if a != d)
    return {
        "cambiaron": sum(movidos.values()),
        "corregidos": sum(a != r and d == r for r, a, d in zip(reales, antes, despues)),
        "empeorados": sum(a == r and d != r for r, a, d in zip(reales, antes, despues)),
        "movimientos": dict(sorted(movidos.items())),
    }


def reporte(reales: Sequence[str], predichas: Sequence[str]) -> dict[str, object]:
    """Todo junto, listo para guardarse en JSON (solo numeros)."""
    return {
        "n": len(reales),
        "exactitud": exactitud(reales, predichas),
        "f1_macro": f1_macro(reales, predichas),
        "por_clase": {m.clase: {"precision": m.precision, "recall": m.recall, "f1": m.f1, "soporte": m.soporte}
                      for m in por_clase(reales, predichas)},
        "matriz_confusion": matriz_confusion(reales, predichas),
        "distribucion_real": distribucion(reales),
        "distribucion_predicha": distribucion(predichas),
    }
