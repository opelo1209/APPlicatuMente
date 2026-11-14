"""Clasificador de otro tipo para separar las tres clases (Semana 8).

Si reentrenar la red no mejora, el asesor pidio probar otro tipo de
clasificador. Aqui hay dos, medidos con los MISMOS pliegues que reentrenar.py
para que la comparacion sea justa:

  tfidf       palabras (1 y 2) y fragmentos de letras (3 a 5) con TF-IDF, y
              una regresion logistica con clases balanceadas. Rapido, corre
              en CPU y se puede explicar: cada palabra tiene un peso por
              clase (se guardan las de mas peso).
  embeddings  (opcional, --embeddings <modelo>) vectores de un modelo de
              oraciones multilingue y una regresion logistica encima.

Uso:
  python -m entrenamiento.alterno <conjunto.jsonl> --salida reporte.json \\
      [--pliegues 5] [--embeddings sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2]
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

from .datos import Ejemplo, cargar_conjunto, pliegues
from .linea_base import predecir_original
from .metricas_clases import CLASES, cambios, f1_macro, reporte

PALABRAS_POR_CLASE = 10


def _tfidf():
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    from sklearn.pipeline import make_pipeline, make_union

    return make_pipeline(
        make_union(
            TfidfVectorizer(analyzer="word", ngram_range=(1, 2), strip_accents="unicode", lowercase=True, min_df=1),
            TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5), strip_accents="unicode", lowercase=True, min_df=1),
        ),
        LogisticRegression(class_weight="balanced", max_iter=2000, C=4.0),
    )


def _embeddings(nombre: str):
    from sentence_transformers import SentenceTransformer
    from sklearn.linear_model import LogisticRegression
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import FunctionTransformer

    codificador = SentenceTransformer(nombre)
    vectorizar = FunctionTransformer(lambda textos: codificador.encode(list(textos), normalize_embeddings=True))
    return make_pipeline(vectorizar, LogisticRegression(class_weight="balanced", max_iter=2000))


def validacion_cruzada(fabrica, ejemplos: Sequence[Ejemplo], k: int, semilla: int):
    predichas = [""] * len(ejemplos)
    f1_pliegues = []
    for prueba in pliegues(ejemplos, k, semilla):
        fuera = set(prueba)
        modelo = fabrica()
        modelo.fit([e.texto for i, e in enumerate(ejemplos) if i not in fuera],
                   [e.etiqueta for i, e in enumerate(ejemplos) if i not in fuera])
        clases = list(modelo.predict([ejemplos[i].texto for i in prueba]))
        for i, c in zip(prueba, clases):
            predichas[i] = str(c)
        f1_pliegues.append(f1_macro([ejemplos[i].etiqueta for i in prueba], clases))
    return predichas, f1_pliegues


def palabras_de_peso(ejemplos: Sequence[Ejemplo]) -> dict[str, list[str]]:
    """Las palabras que mas empujan hacia cada clase (modelo con todo el
    conjunto). Solo palabras sueltas o pares, no respuestas completas."""
    modelo = _tfidf()
    modelo.fit([e.texto for e in ejemplos], [e.etiqueta for e in ejemplos])
    union, logistica = modelo.steps[0][1], modelo.steps[1][1]
    nombres = union.transformer_list[0][1].get_feature_names_out()
    n = len(nombres)
    resultado = {}
    for fila, clase in zip(logistica.coef_, logistica.classes_):
        pesos = fila[:n]
        resultado[str(clase)] = [str(nombres[i]) for i in pesos.argsort()[::-1][:PALABRAS_POR_CLASE]]
    return {c: resultado.get(c, []) for c in CLASES}


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("conjunto", type=Path)
    p.add_argument("--salida", type=Path, required=True)
    p.add_argument("--pliegues", type=int, default=5)
    p.add_argument("--semilla", type=int, default=20261112)
    p.add_argument("--embeddings")
    p.add_argument("--sin-original", action="store_true", help="no correr el analizador actual para comparar")
    p.add_argument("--con-palabras", action="store_true",
                   help="guardar las palabras de mas peso (no usar si el conjunto puede tener nombres)")
    args = p.parse_args(argv)

    ejemplos = cargar_conjunto(args.conjunto)
    reales = [e.etiqueta for e in ejemplos]
    resultado: dict[str, object] = {"parametros": {"pliegues": args.pliegues, "semilla": args.semilla}}
    original = None if args.sin_original else predecir_original([e.texto for e in ejemplos])[0]
    if original is not None:
        resultado["original"] = reporte(reales, original)

    candidatos = {"tfidf": _tfidf}
    if args.embeddings:
        candidatos["embeddings"] = lambda: _embeddings(args.embeddings)
    for nombre, fabrica in candidatos.items():
        predichas, f1_pliegues = validacion_cruzada(fabrica, ejemplos, args.pliegues, args.semilla)
        resultado[nombre] = {**reporte(reales, predichas), "f1_por_pliegue": f1_pliegues}
        if original is not None:
            resultado[nombre]["cambios_vs_original"] = cambios(reales, original, predichas)
        print(f"{nombre}: F1 macro {resultado[nombre]['f1_macro']} (pliegues {f1_pliegues})")
    if args.con_palabras:
        resultado["tfidf_palabras_de_peso"] = palabras_de_peso(ejemplos)
    if original is not None:
        print(f"original: F1 macro {resultado['original']['f1_macro']}")
    args.salida.write_text(json.dumps(resultado, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
