"""Análisis de cierre de la Semana 10, sin pedir nuevas etiquetas.

Tres preguntas, todas con agregados (nunca se escribe texto):

  acuerdo     ¿Qué tan difícil es la tarea? Acuerdo (kappa de Cohen) entre las
              etiquetas de psicología y el etiquetado alterno del CSV entregado
              por el profesor, sobre las mismas respuestas.
  abstencion  Si el modelo solo opina cuando su confianza supera un umbral,
              ¿cuánto acierta y a cuántos textos renuncia? Y ¿da menos
              confianza a los 125 textos que psicología marcó «no claro»?
  errores     ¿Dónde fallan los modelos? Tasa de error por pregunta de origen,
              longitud, negación y tono mixto («pero»).

Uso:
  python -m entrenamiento.analisis_s10 acuerdo <etiquetas.json> <csv_profesor> --salida a.json
  python -m entrenamiento.analisis_s10 abstencion <probabilidades_robusta.jsonl> \\
      --no-claro <no_claro.jsonl> --checkpoint <ckpt_final> --salida b.json
  python -m entrenamiento.analisis_s10 errores <probabilidades_robusta.jsonl> <conjunto.jsonl> --salida c.json
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import statistics
from collections import Counter
from pathlib import Path
from typing import Mapping, Sequence

from .metricas_clases import CLASES

UMBRALES = tuple(round(0.34 + 0.02 * i, 2) for i in range(33))  # 0.34 ... 0.98
NEGACION = re.compile(r"\b(no|nunca|nada|ni|nadie|jamás|jamas|tampoco|ningun[oa]?)\b", re.IGNORECASE)
CONTRASTE = re.compile(r"\b(pero|aunque|sin embargo|aun así|aun asi)\b", re.IGNORECASE)


# --- acuerdo -------------------------------------------------------------------

def kappa_cohen(a: Sequence[str], b: Sequence[str]) -> float:
    """Acuerdo corregido por azar: (p_o - p_e) / (1 - p_e)."""
    if len(a) != len(b) or not a:
        raise ValueError("se necesitan dos listas del mismo largo, no vacías")
    n = len(a)
    observado = sum(x == y for x, y in zip(a, b)) / n
    ca, cb = Counter(a), Counter(b)
    esperado = sum(ca[c] * cb[c] for c in set(ca) | set(cb)) / (n * n)
    return round((observado - esperado) / (1 - esperado), 4) if esperado < 1 else 1.0


def interpretar_kappa(k: float) -> str:
    """Escala de Landis y Koch (1977)."""
    for limite, texto in ((0.0, "pobre"), (0.20, "leve"), (0.40, "aceptable"), (0.60, "moderado"),
                          (0.80, "sustancial")):
        if k <= limite:
            return texto
    return "casi perfecto"


def matriz(a: Sequence[str], b: Sequence[str], categorias_a: Sequence[str], categorias_b: Sequence[str]):
    conteo = Counter(zip(a, b))
    return {x: {y: conteo[(x, y)] for y in categorias_b} for x in categorias_a}


# --- abstención ----------------------------------------------------------------

def curva_cobertura(reales: Sequence[str], probas: Sequence[Mapping[str, float]],
                    umbrales: Sequence[float] = UMBRALES) -> list[dict[str, float]]:
    """Para cada umbral: qué proporción de textos clasifica el modelo
    (confianza >= umbral) y qué exactitud y recall por clase tiene en ellos."""
    curva = []
    for u in umbrales:
        idx = [i for i, p in enumerate(probas) if max(p.values()) >= u]
        pred = {i: max(CLASES, key=lambda c: probas[i][c]) for i in idx}
        fila = {"umbral": u, "cobertura": round(len(idx) / len(reales), 4),
                "exactitud": round(sum(pred[i] == reales[i] for i in idx) / len(idx), 4) if idx else None}
        for c in CLASES:
            de_c = [i for i in range(len(reales)) if reales[i] == c]
            fila[f"recall_{c}"] = round(sum(pred.get(i) == c for i in de_c) / len(de_c), 4) if de_c else 0.0
        curva.append(fila)
    return curva


def confianza(probas: Sequence[Mapping[str, float]]) -> list[float]:
    return [max(p.values()) for p in probas]


def comparar_confianzas(claros: Sequence[float], dudosos: Sequence[float]) -> dict[str, object]:
    """Media, mediana y AUC (probabilidad de que un texto claro tenga más
    confianza que uno «no claro»; 0.5 = no distingue)."""
    mayores = sum((x > y) + 0.5 * (x == y) for x in claros for y in dudosos)
    return {"claros": {"n": len(claros), "media": round(statistics.mean(claros), 4),
                       "mediana": round(statistics.median(claros), 4)},
            "no_claro": {"n": len(dudosos), "media": round(statistics.mean(dudosos), 4),
                         "mediana": round(statistics.median(dudosos), 4)},
            "auc_claro_mayor": round(mayores / (len(claros) * len(dudosos)), 4)}


# --- errores -------------------------------------------------------------------

def categorias_texto(texto: str, origen: str) -> dict[str, str]:
    palabras = len(texto.split())
    largo = "1-5 palabras" if palabras <= 5 else ("6-15 palabras" if palabras <= 15 else "16+ palabras")
    return {"origen": origen or "sin_origen", "longitud": largo,
            "negacion": "con negación" if NEGACION.search(texto) else "sin negación",
            "contraste": "con «pero/aunque»" if CONTRASTE.search(texto) else "sin contraste"}


def error_por_categoria(reales: Sequence[str], predichas: Sequence[str],
                        categorias: Sequence[Mapping[str, str]]) -> dict[str, dict[str, dict[str, float]]]:
    resultado: dict[str, dict[str, dict[str, float]]] = {}
    for dimension in categorias[0]:
        grupos: dict[str, list[int]] = {}
        for i, cat in enumerate(categorias):
            grupos.setdefault(cat[dimension], []).append(i)
        resultado[dimension] = {
            g: {"n": len(idx), "tasa_error": round(sum(predichas[i] != reales[i] for i in idx) / len(idx), 4)}
            for g, idx in sorted(grupos.items())}
    return resultado


# --- comandos -------------------------------------------------------------------

def _acuerdo(args) -> dict:
    psico = json.loads(args.etiquetas.read_text(encoding="utf-8"))["etiquetas"]
    with open(args.csv_profesor, encoding="utf-8-sig") as f:
        profesor = {fila["codigo"]: fila["sentimiento"].strip() for fila in csv.DictReader(f)}
    codigos = sorted(set(psico) & set(profesor))
    polares = [c for c in codigos if psico[c] in CLASES and profesor[c] in CLASES]
    if not polares:
        raise SystemExit("no hay respuestas con polaridad en ambos etiquetados")
    a, b = [psico[c] for c in polares], [profesor[c] for c in polares]
    kappa = kappa_cohen(a, b)
    return {"n_comun": len(codigos), "n_polares": len(polares),
            "acuerdo_bruto": round(sum(x == y for x, y in zip(a, b)) / len(a), 4),
            "kappa": kappa, "interpretacion": interpretar_kappa(kappa),
            "distribucion_psicologia": dict(Counter(psico[c] for c in codigos)),
            "distribucion_profesor": dict(Counter(profesor[c] for c in codigos)),
            "matriz_psicologia_vs_profesor": matriz(a, b, CLASES, CLASES),
            "no_claro_segun_profesor": dict(Counter(profesor[c] for c in codigos if psico[c] == "no_claro"))}


def _leer_jsonl(ruta: Path) -> list[dict]:
    return [json.loads(x) for x in ruta.read_text(encoding="utf-8").splitlines() if x]


def _abstencion(args) -> dict:
    filas = [f for f in _leer_jsonl(args.probabilidades) if f["repeticion"] == 0]
    reales = [f["real"] for f in filas]
    resultado = {"modelos": {}}
    for m in ("produccion", "secuencial", "sbert"):
        probas = [f[m] for f in filas]
        resultado["modelos"][m] = {"curva": curva_cobertura(reales, probas)}
    if args.no_claro and args.checkpoint:
        from .linea_base import _analizador_produccion
        from .reentrenar import _cargar, _predecir_probas

        textos = [f["texto"] for f in _leer_jsonl(args.no_claro)]
        tokenizador, red = _cargar("cpu", str(args.checkpoint))
        final = _predecir_probas(tokenizador, red, textos, "cpu")
        mapa = {"NEG": "negativo", "NEU": "neutro", "POS": "positivo"}
        analizador = _analizador_produccion()
        prod = [{mapa[k]: float(v) for k, v in analizador.predict(t).probas.items()} for t in textos]
        claros_sec = confianza([f["secuencial"] for f in filas])
        claros_prod = confianza([f["produccion"] for f in filas])
        resultado["no_claro"] = {
            "secuencial": comparar_confianzas(claros_sec, confianza(final)),
            "produccion": comparar_confianzas(claros_prod, confianza(prod)),
            "distribucion_predicha_no_claro_secuencial": dict(Counter(max(CLASES, key=p.get) for p in final)),
            "nota": "claros: predicción fuera de pliegue (repetición 0); no claro: modelo final entrenado con los 274",
        }
    return resultado


def _errores(args) -> dict:
    filas = [f for f in _leer_jsonl(args.probabilidades) if f["repeticion"] == 0]
    textos = {json.loads(x)["codigo"]: json.loads(x) for x in args.conjunto.read_text(encoding="utf-8").splitlines() if x}
    cats = [categorias_texto(textos[f["codigo"]]["texto"], textos[f["codigo"]]["origen"]) for f in filas]
    reales = [f["real"] for f in filas]
    salida = {}
    for m in ("produccion", "secuencial", "sbert", "tfidf"):
        pred = [max(CLASES, key=f[m].get) for f in filas]
        salida[m] = error_por_categoria(reales, pred, cats)
    salida["vader"] = error_por_categoria(reales, [f["vader"] for f in filas], cats)
    return {"n": len(filas), "por_modelo": salida}


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="comando", required=True)
    a = sub.add_parser("acuerdo")
    a.add_argument("etiquetas", type=Path)
    a.add_argument("csv_profesor", type=Path)
    b = sub.add_parser("abstencion")
    b.add_argument("probabilidades", type=Path)
    b.add_argument("--no-claro", type=Path)
    b.add_argument("--checkpoint", type=Path)
    c = sub.add_parser("errores")
    c.add_argument("probabilidades", type=Path)
    c.add_argument("conjunto", type=Path)
    for s in (a, b, c):
        s.add_argument("--salida", type=Path, required=True)
    args = p.parse_args(argv)
    resultado = {"acuerdo": _acuerdo, "abstencion": _abstencion, "errores": _errores}[args.comando](args)
    args.salida.write_text(json.dumps(resultado, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(resultado, ensure_ascii=False)[:1500])


if __name__ == "__main__":
    main()
