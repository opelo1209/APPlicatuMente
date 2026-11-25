"""Evaluación robusta de los finalistas (Semana 10, cierre).

Responde a la crítica principal del trabajo: el ganador se eligió mirando las
mismas 274 respuestas y los mismos 5 pliegues muchas veces. Aquí:

  * Los candidatos se fijan ANTES de medir y por una razón de principio:
      produccion      lo que usa la app hoy (no se entrena)
      secuencial      RoBERTuito: checkpoint educativo -> pliegues clínicos
      sbert           embeddings multilingües + regresión logística
      tfidf           referencia de la Semana 9
      vader           solo como insumo de la regla del ensamble E1
  * Ensambles declarados antes de ver resultados:
      E1  regla: RoBERTuito decide; si VADER dice positivo y RoBERTuito
          dice neutro, se marca positivo (VADER detectó 6/9 positivos).
      E2  promedio de probabilidades de RoBERTuito secuencial y SBERT.
  * Validación cruzada REPETIDA (5 repeticiones x 5 pliegues) y AGRUPADA por
    participante: ninguna persona queda a la vez en entrenamiento y prueba
    (elimina la limitación L5).

Salidas: las probabilidades por ejemplo van a un JSONL privado (600); el
reporte compartible solo lleva agregados.

Uso:
  python -m entrenamiento.evaluacion_robusta <conjunto_en.jsonl> <clave.json> \\
      --base-robertuito <checkpoint_educativo> --salida resumen.json \\
      --privado probabilidades.jsonl [--repeticiones 5] [--pliegues 5]
"""

from __future__ import annotations

import argparse
import json
import random
import statistics
import time
from collections import Counter
from pathlib import Path
from typing import Mapping, Sequence

from .datos import Ejemplo, cargar_conjunto, escribir_privado
from .metricas_clases import CLASES, exactitud, f1_macro

SEMILLA = 20261112
CANDIDATOS = ("produccion", "secuencial", "sbert", "tfidf")
ENSAMBLES = ("E1_regla_vader", "E2_promedio_rob_sbert")


# --- pliegues agrupados (sin dependencias) -------------------------------------

def pliegues_por_grupo(etiquetas: Sequence[str], grupos: Sequence[str], k: int,
                       semilla: int = SEMILLA) -> tuple[tuple[int, ...], ...]:
    """Pliegues estratificados por clase y agrupados: todos los ejemplos de un
    grupo (participante) caen en el mismo pliegue. Asignación codiciosa: los
    grupos con la clase más escasa van primero, cada uno al pliegue que menos
    se aleja de la proporción objetivo."""
    if k < 2:
        raise ValueError("se necesitan al menos 2 pliegues")
    if len(etiquetas) != len(grupos):
        raise ValueError("etiquetas y grupos deben tener el mismo largo")
    total = Counter(etiquetas)
    escasez = {c: 1 / total[c] for c in total}
    miembros: dict[str, list[int]] = {}
    for i, g in enumerate(grupos):
        miembros.setdefault(g, []).append(i)
    azar = random.Random(semilla)
    orden = list(miembros)
    azar.shuffle(orden)
    orden.sort(key=lambda g: -max(escasez[etiquetas[i]] for i in miembros[g]))
    conteo = [Counter() for _ in range(k)]
    asignados: list[list[int]] = [[] for _ in range(k)]
    for g in orden:
        clases_g = Counter(etiquetas[i] for i in miembros[g])

        def costo(f: int) -> tuple[float, int]:
            exceso = sum(((conteo[f][c] + n) / (total[c] / k)) for c, n in clases_g.items())
            return exceso, len(asignados[f])

        destino = min(range(k), key=costo)
        conteo[destino].update(clases_g)
        asignados[destino].extend(miembros[g])
    return tuple(tuple(sorted(a)) for a in asignados)


def regla_e1(roberta: Sequence[str], vader: Sequence[str]) -> list[str]:
    """E1: si VADER dice positivo y RoBERTuito neutro, positivo; si no, RoBERTuito."""
    return ["positivo" if r == "neutro" and v == "positivo" else r for r, v in zip(roberta, vader)]


def promedio_probas(a: Sequence[Mapping[str, float]], b: Sequence[Mapping[str, float]]) -> list[dict[str, float]]:
    return [{c: round((x[c] + y[c]) / 2, 4) for c in CLASES} for x, y in zip(a, b)]


def argmax(probas: Sequence[Mapping[str, float]]) -> list[str]:
    return [max(CLASES, key=lambda c: p[c]) for p in probas]


def resumen_metrica(valores: Sequence[float]) -> dict[str, float]:
    return {"media": round(statistics.mean(valores), 4),
            "de": round(statistics.stdev(valores), 4) if len(valores) > 1 else 0.0,
            "min": round(min(valores), 4), "max": round(max(valores), 4)}


def recall_clase(reales: Sequence[str], predichas: Sequence[str], clase: str) -> float:
    idx = [i for i, r in enumerate(reales) if r == clase]
    return round(sum(predichas[i] == clase for i in idx) / len(idx), 4) if idx else 0.0


# --- candidatos (dependencias pesadas solo aquí) --------------------------------

def _probas_produccion(textos: Sequence[str]) -> list[dict[str, float]]:
    from .linea_base import _analizador_produccion

    mapa = {"NEG": "negativo", "NEU": "neutro", "POS": "positivo"}
    analizador = _analizador_produccion()
    return [{mapa[k]: round(float(v), 4) for k, v in analizador.predict(t).probas.items()} for t in textos]


def _probas_secuencial(entrenamiento, prueba, base: str) -> list[dict[str, float]]:
    from .experimentos_s10 import RobertuitoReentrenado
    from .reentrenar import _predecir_probas

    modelo = RobertuitoReentrenado(base=base).ajustar(entrenamiento)
    tokenizador, red = modelo.estado
    return _predecir_probas(tokenizador, red, [e.texto for e in prueba], RobertuitoReentrenado._dispositivo())


def _probas_sklearn(modelo, x_prueba) -> list[dict[str, float]]:
    clases = [str(c) for c in modelo.classes_]
    # una clase ausente del pliegue de entrenamiento queda con probabilidad 0
    return [{**{c: 0.0 for c in CLASES}, **{c: round(float(p), 4) for c, p in zip(clases, fila)}}
            for fila in modelo.predict_proba(x_prueba)]


def _probas_sbert(entrenamiento, prueba) -> list[dict[str, float]]:
    from .experimentos_s10 import SbertLogistica

    modelo = SbertLogistica().ajustar(entrenamiento)
    return _probas_sklearn(modelo.modelo, SbertLogistica._vectores(prueba))


def _probas_tfidf(entrenamiento, prueba) -> list[dict[str, float]]:
    from .experimentos_s10 import Tfidf

    modelo = Tfidf().ajustar(entrenamiento)
    return _probas_sklearn(modelo.modelo, [e.texto for e in prueba])


# --- corrida -------------------------------------------------------------------

def correr(ejemplos: Sequence[Ejemplo], grupos: Sequence[str], base: str, repeticiones: int, k: int):
    from .vader import VaderClasico

    reales = [e.etiqueta for e in ejemplos]
    prod = _probas_produccion([e.texto for e in ejemplos])
    vader = VaderClasico().predecir(ejemplos)
    filas_privadas, por_repeticion = [], []
    for r in range(repeticiones):
        semilla = SEMILLA + r
        probas = {"secuencial": [None] * len(ejemplos), "sbert": [None] * len(ejemplos),
                  "tfidf": [None] * len(ejemplos)}
        f1_pliegue: dict[str, list[float]] = {}
        for n, prueba in enumerate(pliegues_por_grupo(reales, grupos, k, semilla), 1):
            inicio = time.perf_counter()
            fuera = set(prueba)
            ent = [e for i, e in enumerate(ejemplos) if i not in fuera]
            pru = [ejemplos[i] for i in prueba]
            for nombre, funcion in (("secuencial", lambda: _probas_secuencial(ent, pru, base)),
                                    ("sbert", lambda: _probas_sbert(ent, pru)),
                                    ("tfidf", lambda: _probas_tfidf(ent, pru))):
                for i, p in zip(prueba, funcion()):
                    probas[nombre][i] = p
            print(f"repetición {r + 1}/{repeticiones} pliegue {n}/{k} ({time.perf_counter() - inicio:.0f} s)",
                  flush=True)
        predichas = {"produccion": argmax(prod), **{m: argmax(probas[m]) for m in probas}}
        predichas["E1_regla_vader"] = regla_e1(predichas["secuencial"], vader)
        predichas["E2_promedio_rob_sbert"] = argmax(promedio_probas(probas["secuencial"], probas["sbert"]))
        metricas = {m: {"f1_macro": f1_macro(reales, p), "exactitud": exactitud(reales, p),
                        **{f"recall_{c}": recall_clase(reales, p, c) for c in CLASES}}
                    for m, p in predichas.items()}
        por_repeticion.append({"semilla": semilla, "metricas": metricas})
        print(f"repetición {r + 1}: " + " ".join(f"{m}={v['f1_macro']}" for m, v in metricas.items()), flush=True)
        for i, e in enumerate(ejemplos):
            filas_privadas.append({"repeticion": r, "codigo": e.codigo, "real": e.etiqueta, "vader": vader[i],
                                   "produccion": prod[i], **{m: probas[m][i] for m in probas}})
    return por_repeticion, filas_privadas


def agregar(por_repeticion: Sequence[dict]) -> dict:
    modelos = list(por_repeticion[0]["metricas"])
    claves = list(por_repeticion[0]["metricas"][modelos[0]])
    resumen = {m: {c: resumen_metrica([r["metricas"][m][c] for r in por_repeticion]) for c in claves}
               for m in modelos}
    gana = Counter(max(r["metricas"], key=lambda m: r["metricas"][m]["f1_macro"]) for r in por_repeticion)
    sec_vs_prod = sum(r["metricas"]["secuencial"]["f1_macro"] > r["metricas"]["produccion"]["f1_macro"]
                      for r in por_repeticion)
    return {"resumen": resumen, "veces_mejor_f1": dict(gana),
            "secuencial_supera_produccion": f"{sec_vs_prod}/{len(por_repeticion)}"}


def grupos_desde_clave(ejemplos: Sequence[Ejemplo], clave: Mapping[str, Mapping[str, str]]) -> list[str]:
    return [str(clave[e.codigo]["id"]) for e in ejemplos]


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("conjunto", type=Path)
    p.add_argument("clave", type=Path)
    p.add_argument("--base-robertuito", required=True)
    p.add_argument("--salida", type=Path, required=True)
    p.add_argument("--privado", type=Path, required=True)
    p.add_argument("--repeticiones", type=int, default=5)
    p.add_argument("--pliegues", type=int, default=5)
    args = p.parse_args(argv)
    ejemplos = cargar_conjunto(args.conjunto)
    grupos = grupos_desde_clave(ejemplos, json.loads(args.clave.read_text(encoding="utf-8")))
    por_repeticion, filas = correr(ejemplos, grupos, args.base_robertuito, args.repeticiones, args.pliegues)
    escribir_privado(args.privado, "\n".join(json.dumps(f, ensure_ascii=False) for f in filas) + "\n")
    resultado = {"n": len(ejemplos), "participantes": len(set(grupos)), "repeticiones": args.repeticiones,
                 "pliegues": args.pliegues, "candidatos": list(CANDIDATOS), "ensambles": list(ENSAMBLES),
                 "por_repeticion": por_repeticion, **agregar(por_repeticion)}
    args.salida.write_text(json.dumps(resultado, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(resultado["resumen"], ensure_ascii=False)[:2000])


if __name__ == "__main__":
    main()
