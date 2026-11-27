"""Barrido del intervalo neutro con la bateria (Semana 6).

Reunion con el asesor: el analizador da un valor de -1 (negativo) a 1
(positivo); ¿que tan abierto esta el intervalo alrededor de cero que se lee
como neutro? Abrirlo de a poco (-0.1, -0.15, -0.2... y +0.1, +0.15...) y ver
si las frases neutras se clasifican mejor sin perder negativas ni positivas.

pysentimiento no da ese valor: da tres probabilidades y la app toma la mas
alta. Aqui el valor es P(positivo) - P(negativo) y el intervalo se aplica con
polaridad_por_intervalo(). Tambien lista las frases que quedan «sin clase»
(la clase elegida no llega a UMBRAL_CONFIANZA) y las que el analizador
clasifica mal, con su valor, para ver hacia donde se fueron.

Ojo: el intervalo se ajusto con las mismas 60 frases con que se mide
(frases_s5). Se confirma con frases nuevas: --frases bateria/frases_s6.json.

Uso (desde mock_backend/):
  ~/.venvs/serena_eval/bin/python -m bateria.intervalo --salida intervalo.json
  python -m bateria.intervalo --desde intervalo.json   # sin volver a correr el modelo
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterable, Sequence

from app.analizador_sentimiento import ResultadoSentimiento, polaridad_por_intervalo
from app.evaluador_diario import UMBRAL_CONFIANZA

from .ejecutar import AQUI, FRASES, cargar_frases
from .metricas import POLARIDADES, evaluar

# Frases nuevas (Semana 6) para confirmar sin volver a ajustar.
FRASES_S6 = AQUI / "frases_s6.json"
LADOS = (0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8)


def _resultado(f: dict) -> ResultadoSentimiento:
    probas = (("positivo", f["pos"]), ("neutro", f["neu"]), ("negativo", f["neg"]))
    ordenadas = tuple(sorted(probas, key=lambda p: p[1], reverse=True))
    return ResultadoSentimiento(ordenadas[0][0], ordenadas, (), "bateria")


def probabilidades(frases: Iterable[dict], analizador=None) -> list[dict]:
    if analizador is None:
        from app.analizador_sentimiento import AnalizadorPysentimiento

        analizador = AnalizadorPysentimiento()
    filas = []
    for f in frases:
        p = dict(analizador.analizar(f["texto"]).probabilidades_polaridad)
        filas.append(
            {"id": f["id"], "texto": f["texto"], "polaridad": f["polaridad"],
             "pos": p["positivo"], "neu": p["neutro"], "neg": p["negativo"]}
        )
    return filas


def cargar_probabilidades(ruta: Path) -> list[dict]:
    return json.loads(ruta.read_text(encoding="utf-8"))["filas"]


def _anotada(f: dict) -> dict:
    r = _resultado(f)
    return {
        **{k: f[k] for k in ("id", "texto", "polaridad")},
        "pred_polaridad": r.polaridad,
        "confianza": round(r.probabilidad(r.polaridad), 3),
        "puntaje": r.puntaje(),
    }


def barrer(
    filas: Sequence[dict], izquierdas: Iterable[float] = LADOS, derechas: Iterable[float] = LADOS
) -> dict[tuple[float, float], dict]:
    """Para cada intervalo: metricas, frases que pasaron a neutro y frases
    que el analizador acertaba y con el intervalo ya no («perdidas»)."""
    resultados = [_resultado(f) for f in filas]
    esperadas = [f["polaridad"] for f in filas]
    base = [r.polaridad for r in resultados]
    derechas = tuple(derechas)
    puntos = {}
    for izq in izquierdas:
        for der in derechas:
            pred = [polaridad_por_intervalo(r, izq, der) for r in resultados]
            puntos[(izq, der)] = {
                "metricas": evaluar(esperadas, pred, POLARIDADES),
                "a_neutro": [f["id"] for f, b, p in zip(filas, base, pred) if p != b],
                "perdidas": [
                    f["id"] for f, e, b, p in zip(filas, esperadas, base, pred) if b == e and p != e
                ],
            }
    return puntos


def sin_clase(filas: Sequence[dict], umbral: float = UMBRAL_CONFIANZA) -> list[dict]:
    """Frases que el diario y Serena no clasifican: la probabilidad de la
    clase elegida no llega al umbral («incierto»)."""
    return [a for a in map(_anotada, filas) if a["confianza"] < umbral]


def errores(filas: Sequence[dict]) -> list[dict]:
    """Frases mal clasificadas por el analizador, de la mas negativa a la mas positiva."""
    return sorted((a for a in map(_anotada, filas) if a["pred_polaridad"] != a["polaridad"]), key=lambda a: a["puntaje"])


def _tabla(puntos: dict) -> str:
    lineas = ["izq   der   neg neu pos  total  F1     a_neutro  perdidas"]
    for (izq, der), p in puntos.items():
        m = p["metricas"]
        aciertos = [m["por_clase"][c]["aciertos"] for c in POLARIDADES]
        lineas.append(
            f"{izq:<5} {der:<5} {aciertos[0]:>3} {aciertos[1]:>3} {aciertos[2]:>3}  {m['aciertos']:>5}  "
            f"{m['f1_macro']:<6} {len(p['a_neutro']):>8}  {','.join(p['perdidas']) or '-'}"
        )
    return "\n".join(lineas)


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--frases", type=Path, default=FRASES)
    p.add_argument("--desde", type=Path, help="JSON de una corrida anterior (no vuelve a correr el modelo)")
    p.add_argument("--salida", type=Path, default=Path("intervalo_resultado.json"))
    args = p.parse_args(argv)

    if args.desde:
        filas = cargar_probabilidades(args.desde)
    else:
        datos, _ = cargar_frases(args.frases)
        filas = probabilidades(datos["frases"])
    puntos = barrer(filas)
    simetricos = {k: v for k, v in puntos.items() if k[0] == k[1]}
    salida = {
        "umbral_confianza": UMBRAL_CONFIANZA,
        "filas": filas,
        "sin_clase": sin_clase(filas),
        "errores": errores(filas),
        "barrido": [{"izquierda": i, "derecha": d, **v} for (i, d), v in puntos.items()],
    }
    args.salida.write_text(json.dumps(salida, ensure_ascii=False, indent=1), encoding="utf-8")
    print(_tabla(simetricos))
    print(f"\n{len(salida['sin_clase'])} sin clase, {len(salida['errores'])} errores -> {args.salida}")


if __name__ == "__main__":
    main()
