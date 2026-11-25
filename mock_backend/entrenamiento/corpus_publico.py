"""Corpus público balanceado para el reentrenamiento (Semana 10).

Pedido del asesor (Semana 10): tomar dos corpus educativos de Hugging Face,
armar un conjunto con 500 positivos, 500 negativos y 500 neutros y medir si
el reentrenamiento mejora el analizador. Fuentes:

  uitnlp/vietnamese_students_feedback  (UIT-VSFC, 16,175 frases, vietnamita,
                                        anotación humana; 0 neg, 1 neu, 2 pos)
  Cocciadipollo/sentiment-analysis-test (349 respuestas, italiano, etiquetas
                                        derivadas de indicadores de gusto)

El vietnamita alcanza para balancear (608 neutros después del filtro); el
italiano queda como conjunto de prueba externo porque sus etiquetas tienen
ruido documentado. Todo se traduce al español con modelos locales
(traducir.py) para que RoBERTuito y TF-IDF lo lean, y al inglés para VADER.

Uso:
  python -m entrenamiento.corpus_publico <carpeta_corpus_hf> <carpeta_salida> \\
      [--por-clase 500] [--prueba 0.2] [--semilla 20261121]

Las funciones de filtrado, balanceo y partición no tienen dependencias y se
prueban en tests/test_entrenamiento_s10.py.
"""

from __future__ import annotations

import argparse
import json
import random
import re
from collections import Counter
from pathlib import Path
from typing import Iterable, Mapping, Sequence

from .datos import Ejemplo
from .metricas_clases import CLASES

SEMILLA = 20261121
MIN_PALABRAS = 3  # mismo filtro que la hoja ciega de la Semana 7
MARCA_ANONIMA = re.compile(r"wzjwz\d*", re.IGNORECASE)  # nombres ocultos en UIT-VSFC
MAPA_VIETNAMITA = {0: "negativo", 1: "neutro", 2: "positivo"}
MAPA_ITALIANO = {"negative": "negativo", "neutral": "neutro", "positive": "positivo"}


def normalizar(texto: str) -> str:
    """Espacios simples; quita el espacio antes de la puntuación (UIT-VSFC
    viene tokenizado: «thầy dạy hay .»)."""
    limpio = re.sub(r"\s+", " ", str(texto)).strip()
    return re.sub(r"\s+([.,!?;:])", r"\1", limpio)


def filtrar(filas: Iterable[Mapping[str, str]]) -> tuple[tuple[dict, ...], dict[str, int]]:
    """Normaliza, quita cortos, anonimizados y duplicados exactos.

    Cada fila trae al menos ``texto`` y ``etiqueta``. Devuelve filas nuevas y
    el conteo de descartes por motivo."""
    vistos: set[str] = set()
    salida, descartes = [], Counter()
    for fila in filas:
        texto = normalizar(fila["texto"])
        if fila["etiqueta"] not in CLASES:
            descartes["sin_etiqueta"] += 1
        elif len(texto.split()) < MIN_PALABRAS:
            descartes["corto"] += 1
        elif MARCA_ANONIMA.search(texto):
            descartes["anonimizado"] += 1
        elif texto.lower() in vistos:
            descartes["duplicado"] += 1
        else:
            vistos.add(texto.lower())
            salida.append({**fila, "texto": texto})
    return tuple(salida), {k: descartes[k] for k in ("sin_etiqueta", "corto", "anonimizado", "duplicado")}


def balancear(filas: Sequence[Mapping[str, str]], por_clase: int, semilla: int = SEMILLA) -> tuple[dict, ...]:
    """Exactamente ``por_clase`` filas de cada clase, elegidas al azar con
    semilla fija. Falla si alguna clase no alcanza: no se rellena repitiendo."""
    azar = random.Random(semilla)
    elegidas = []
    for clase in CLASES:
        disponibles = [dict(f) for f in filas if f["etiqueta"] == clase]
        if len(disponibles) < por_clase:
            raise ValueError(f"la clase {clase} tiene {len(disponibles)} filas; se piden {por_clase}")
        azar.shuffle(disponibles)
        elegidas.extend(disponibles[:por_clase])
    return tuple(elegidas)


def dividir_estratificado(
    filas: Sequence[Mapping[str, str]], proporcion_prueba: float, semilla: int = SEMILLA
) -> tuple[tuple[dict, ...], tuple[dict, ...]]:
    """Entrenamiento y prueba con la misma proporción de cada clase."""
    if not 0 < proporcion_prueba < 1:
        raise ValueError("la proporción de prueba debe estar entre 0 y 1")
    azar = random.Random(semilla)
    entrenamiento, prueba = [], []
    for clase in CLASES:
        grupo = [dict(f) for f in filas if f["etiqueta"] == clase]
        azar.shuffle(grupo)
        corte = round(len(grupo) * proporcion_prueba)
        prueba.extend(grupo[:corte])
        entrenamiento.extend(grupo[corte:])
    return tuple(entrenamiento), tuple(prueba)


def resumen_balance(etiquetas: Sequence[str]) -> dict[str, object]:
    """Conteo, proporción y razón mayoritaria/minoritaria (1.0 = balance perfecto)."""
    conteo = Counter(etiquetas)
    total = len(etiquetas)
    presentes = [conteo[c] for c in CLASES if conteo[c]]
    return {
        "n": total,
        "conteo": {c: conteo[c] for c in CLASES},
        "proporcion": {c: round(conteo[c] / total, 4) if total else 0.0 for c in CLASES},
        "razon_desbalance": round(max(presentes) / min(presentes), 2) if presentes else 0.0,
    }


def a_ejemplos(filas: Sequence[Mapping[str, str]], prefijo: str) -> tuple[Ejemplo, ...]:
    return tuple(
        Ejemplo(f"{prefijo}{i:04d}", f["texto_es"], f["etiqueta"], f["origen"], f.get("texto_en", ""))
        for i, f in enumerate(filas, 1)
    )


def escribir_jsonl(ruta: Path, ejemplos: Sequence[Ejemplo]) -> None:
    lineas = (json.dumps(e.__dict__, ensure_ascii=False) for e in ejemplos)
    Path(ruta).write_text("\n".join(lineas) + "\n", encoding="utf-8")


# --- lectura y traducción (requiere pandas y los modelos Marian locales) ---

def _leer_vietnamita(carpeta: Path) -> list[dict]:
    import pandas as pd

    tablas = [pd.read_parquet(carpeta / f"{s}.parquet").assign(split=s) for s in ("train", "validation", "test")]
    datos = pd.concat(tablas)
    return [
        {"texto": r.sentence, "etiqueta": MAPA_VIETNAMITA[int(r.sentiment)], "origen": f"vsfc_{r.split}"}
        for r in datos.itertuples()
    ]


def _leer_italiano(carpeta: Path) -> list[dict]:
    import pandas as pd

    datos = pd.concat([pd.read_parquet(carpeta / f"{s}.parquet").assign(split=s) for s in ("train", "test")])
    return [
        {"texto": r.text, "etiqueta": MAPA_ITALIANO.get(str(r.sentiment), ""), "origen": f"italiano_{r.split}"}
        for r in datos.itertuples()
    ]


def _traducir_filas(filas: Sequence[dict], ruta_es: Sequence[str], ruta_en: Sequence[str],
                    ruta_cache: Path) -> tuple[dict, ...]:
    """Agrega texto_es y texto_en. Si la ruta al español empieza con el mismo
    par que la del inglés (pivote), reutiliza esa traducción. La caché se
    guarda en disco al terminar cada ruta para no repetir trabajo."""
    from .traducir import traducir_cadena

    caches = json.loads(ruta_cache.read_text(encoding="utf-8")) if ruta_cache.exists() else {}

    def _con_cache(textos, ruta):
        resultado = traducir_cadena(textos, ruta, caches)
        temporal = ruta_cache.with_suffix(".tmp")
        temporal.write_text(json.dumps(caches, ensure_ascii=False), encoding="utf-8")
        temporal.replace(ruta_cache)  # escritura atómica
        return resultado

    textos = [f["texto"] for f in filas]
    en = _con_cache(textos, ruta_en)
    es = _con_cache(en, ruta_es[1:]) if ruta_es[0] == ruta_en[0] else _con_cache(textos, ruta_es)
    return tuple({**f, "texto_es": normalizar(a), "texto_en": normalizar(b)} for f, a, b in zip(filas, es, en))


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("corpus_hf", type=Path, help="carpeta con italiano/ y vietnamita/ en parquet")
    p.add_argument("salida", type=Path)
    p.add_argument("--por-clase", type=int, default=500)
    p.add_argument("--prueba", type=float, default=0.2)
    p.add_argument("--semilla", type=int, default=SEMILLA)
    args = p.parse_args(argv)
    args.salida.mkdir(parents=True, exist_ok=True)

    crudo_vi = _leer_vietnamita(args.corpus_hf / "vietnamita")
    crudo_it = _leer_italiano(args.corpus_hf / "italiano")
    vi, descartes_vi = filtrar(crudo_vi)
    it, descartes_it = filtrar(crudo_it)
    balanceado = balancear(vi, args.por_clase, args.semilla)
    # vietnamita -> inglés -> español (pivote); italiano directo a cada idioma
    cache = args.salida / "cache_traduccion.json"
    balanceado = _traducir_filas(balanceado, ["vi-en", "en-es"], ["vi-en"], cache)
    italiano = _traducir_filas(it, ["it-es"], ["it-en"], cache)
    entrenamiento, prueba = dividir_estratificado(balanceado, args.prueba, args.semilla)

    escribir_jsonl(args.salida / "educativo_entrenamiento.jsonl", a_ejemplos(entrenamiento, "E"))
    escribir_jsonl(args.salida / "educativo_prueba.jsonl", a_ejemplos(prueba, "T"))
    escribir_jsonl(args.salida / "italiano_prueba.jsonl", a_ejemplos(italiano, "I"))
    resumen = {
        "semilla": args.semilla,
        "por_clase": args.por_clase,
        "vietnamita_original": resumen_balance([f["etiqueta"] for f in crudo_vi]),
        "vietnamita_filtrado": resumen_balance([f["etiqueta"] for f in vi]),
        "vietnamita_descartes": descartes_vi,
        "italiano_original": resumen_balance([f["etiqueta"] for f in crudo_it]),
        "italiano_filtrado": resumen_balance([f["etiqueta"] for f in it]),
        "italiano_descartes": descartes_it,
        "balanceado": resumen_balance([f["etiqueta"] for f in balanceado]),
        "entrenamiento": resumen_balance([f["etiqueta"] for f in entrenamiento]),
        "prueba": resumen_balance([f["etiqueta"] for f in prueba]),
        "origen_balanceado": dict(Counter(f["origen"] for f in balanceado)),
    }
    (args.salida / "resumen_corpus.json").write_text(json.dumps(resumen, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(resumen["balanceado"], ensure_ascii=False))


if __name__ == "__main__":
    main()
