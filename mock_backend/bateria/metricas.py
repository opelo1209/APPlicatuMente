"""Metricas de clasificacion para la bateria del analizador (Semana 5).

Sin dependencias: matriz de confusion, exactitud, precision, exhaustividad
(recall) y F1 por clase, y promedio macro. Las usan ejecutar.py y el tablero.
"""

from __future__ import annotations

from collections import Counter
from typing import Iterable, Sequence

POLARIDADES = ("negativo", "neutro", "positivo")
EMOCIONES = ("alegria", "tristeza", "enojo", "miedo", "sorpresa", "asco", "otra")


def _division(a: float, b: float) -> float:
    return a / b if b else 0.0


def evaluar(esperadas: Sequence[str], predichas: Sequence[str | None], clases: Iterable[str]) -> dict:
    """Una prediccion None (el sistema no dio clase: «incierto», consulta,
    sin analisis) cuenta como error y aparece en la columna «sin_clase»."""
    clases = tuple(clases)
    pares = [(e, p if p is not None else "sin_clase") for e, p in zip(esperadas, predichas)]
    confusion = Counter(pares)
    columnas = clases + (("sin_clase",) if any(p == "sin_clase" for _, p in pares) else ())
    por_clase = {}
    for c in clases:
        vp = confusion[(c, c)]
        predichas_c = sum(confusion[(e, c)] for e in clases)
        reales_c = sum(confusion[(c, p)] for p in columnas)
        precision = _division(vp, predichas_c)
        recall = _division(vp, reales_c)
        por_clase[c] = {
            "soporte": reales_c,
            "aciertos": vp,
            "precision": round(precision, 3),
            "recall": round(recall, 3),
            "f1": round(_division(2 * precision * recall, precision + recall), 3),
        }
    con_soporte = [m for m in por_clase.values() if m["soporte"]]
    aciertos = sum(confusion[(c, c)] for c in clases)
    return {
        "total": len(pares),
        "aciertos": aciertos,
        "exactitud": round(_division(aciertos, len(pares)), 3),
        "f1_macro": round(_division(sum(m["f1"] for m in con_soporte), len(con_soporte)), 3),
        "sin_clase": sum(1 for _, p in pares if p == "sin_clase"),
        "por_clase": por_clase,
        "columnas": list(columnas),
        "matriz": [[confusion[(e, p)] for p in columnas] for e in clases],
    }


def acierto_por_grupo(filas: Sequence[dict], grupo: str, esperado: str, predicho: str) -> dict:
    """Ej.: exactitud de la emocion dentro de cada polaridad."""
    salida = {}
    for valor in dict.fromkeys(f[grupo] for f in filas):
        sub = [f for f in filas if f[grupo] == valor]
        ok = sum(f[esperado] == f[predicho] for f in sub)
        salida[valor] = {"aciertos": ok, "total": len(sub), "exactitud": round(_division(ok, len(sub)), 3)}
    return salida


def distribucion(filas: Sequence[dict], grupo: str, campo: str) -> dict:
    """Ej.: que tipo de respuesta dio Serena a las frases de cada polaridad."""
    salida: dict[str, dict[str, int]] = {}
    for f in filas:
        salida.setdefault(f[grupo], Counter())[str(f[campo])] += 1  # type: ignore[index]
    return {k: dict(v) for k, v in salida.items()}
