"""Linea base: donde esta hoy el analizador, por clase (Semana 8).

Corre el mismo analizador que usa la app (pysentimiento, RoBERTuito) sobre un
conjunto etiquetado y guarda un reporte con solo numeros: exactitud, F1 por
clase, matriz de confusion y que proporcion predice de cada clase.

Uso:
  python -m entrenamiento.linea_base <conjunto.jsonl|bateria.json> [...] --salida reporte.json

Necesita pysentimiento (requirements-entrenamiento.txt). Sin red: el modelo
ya descargado basta (HF_HUB_OFFLINE=1).
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

from .datos import cargar_conjunto
from .metricas_clases import reporte

_POLARIDAD = {"POS": "positivo", "NEU": "neutro", "NEG": "negativo"}


def predecir_original(textos: Sequence[str]) -> tuple[list[str], list[float]]:
    """Clase y confianza del analizador tal como lo usa la app."""
    from pysentimiento import create_analyzer  # dependencia pesada: solo aqui

    analizador = create_analyzer(task="sentiment", lang="es")
    clases, confianzas = [], []
    for texto in textos:
        r = analizador.predict(texto)
        clases.append(_POLARIDAD[r.output])
        confianzas.append(round(max(r.probas.values()), 4))
    return clases, confianzas


def confianza_media(predichas: Sequence[str], confianzas: Sequence[float]) -> dict[str, float]:
    """Que tan seguro esta el modelo, en promedio, de lo que dice de cada clase."""
    medias = {}
    for clase in ("negativo", "neutro", "positivo"):
        valores = [c for p, c in zip(predichas, confianzas) if p == clase]
        medias[clase] = round(sum(valores) / len(valores), 4) if valores else 0.0
    return medias


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("conjuntos", nargs="+", type=Path)
    p.add_argument("--salida", type=Path, required=True)
    args = p.parse_args(argv)
    ejemplos = [e for ruta in args.conjuntos for e in cargar_conjunto(ruta)]
    reales = [e.etiqueta for e in ejemplos]
    predichas, confianzas = predecir_original([e.texto for e in ejemplos])
    resultado = {
        "modelo": "pysentimiento/robertuito-sentiment-analysis",
        "conjuntos": [r.name for r in args.conjuntos],
        **reporte(reales, predichas),
        "confianza_media": confianza_media(predichas, confianzas),
    }
    args.salida.write_text(json.dumps(resultado, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"n={resultado['n']} exactitud={resultado['exactitud']} F1 macro={resultado['f1_macro']}")
    for clase, m in resultado["por_clase"].items():
        print(f"  {clase:9} precision={m['precision']:.2f} recall={m['recall']:.2f} f1={m['f1']:.2f} n={m['soporte']}")


if __name__ == "__main__":
    main()
