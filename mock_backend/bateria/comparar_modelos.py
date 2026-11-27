"""Comparar modelos de lenguaje dentro de Serena (Semana 6).

Reunion con el asesor (30 de octubre): buscar un lugar con GPU, gratis o
barato, para probar otros modelos. Este script corre el pipeline REAL de
Serena (analizador, motor de Wang, guardia de salida) con cada modelo GGUF
sobre bateria/conversaciones_s6.json y guarda, por mensaje, la respuesta, el
tiempo y la decision de la guardia.

La medida objetiva es cuantas veces la guardia tuvo que DESCARTAR la oracion
del modelo (S12-S18: usted, papel confundido, impone, aconseja, genero,
supone malestar, lista cortada) o bloquearla: menos es mejor. La calidad se
califica despues a ciegas con las respuestas guardadas.

Solo frases inventadas por el equipo: nunca mensajes de estudiantes reales
(son datos de menores) en un servicio externo como Kaggle.

Uso (desde mock_backend/; en Kaggle: bateria/kaggle_modelos_s6.ipynb):
  SERENA_CAPAS_GPU=-1 python -m bateria.comparar_modelos \\
      --modelo qwen1.5b.gguf --modelo qwen3b.gguf --salida comparacion.json
"""

from __future__ import annotations

import argparse
import json
import os
import statistics
import time
from collections import Counter
from pathlib import Path
from typing import Iterable

from .ejecutar import AQUI

CONVERSACIONES = AQUI / "conversaciones_s6.json"
SIN_MODELO = "sin modelo"
DESCARTE = ("reemplazar_apertura", "bloquear")


def cargar_conversaciones(ruta: Path = CONVERSACIONES) -> list[dict]:
    return json.loads(ruta.read_text(encoding="utf-8"))["conversaciones"]


def correr(conversaciones: Iterable[dict], analizador, generador) -> list[dict]:
    from app.serena_pipeline import responder

    filas = []
    for conv in conversaciones:
        historial = ()
        for turno, mensaje in enumerate(conv["mensajes"], 1):
            inicio = time.perf_counter()
            r = responder(mensaje, analizador, generador, historial=historial, modo="breve")
            segundos = round(time.perf_counter() - inicio, 2)
            historial += (r.turno,)
            salida = r.etapas.get("salida") or {}
            filas.append(
                {
                    "conversacion": conv["id"],
                    "turno": turno,
                    "mensaje": mensaje,
                    "texto": r.texto,
                    "texto_modelo": r.etapas.get("texto_modelo"),
                    "modelo": r.etapas.get("modelo") or SIN_MODELO,
                    "tipo": r.tipo,
                    "accion": r.etapas["entrada"]["accion"],
                    "guardia": salida.get("accion"),
                    "reglas_guardia": salida.get("reglas", []),
                    "segundos": segundos,
                }
            )
    return filas


def resumir(filas: list[dict]) -> dict:
    con_modelo = [f for f in filas if not f["modelo"].startswith(SIN_MODELO)]
    descartadas = [f for f in con_modelo if f["guardia"] in DESCARTE]
    tiempos = [f["segundos"] for f in con_modelo] or [0.0]
    return {
        "mensajes": len(filas),
        "con_modelo": len(con_modelo),
        "descartadas": len(descartadas),
        "mostradas_del_modelo": len(con_modelo) - len(descartadas),
        "por_regla": dict(Counter(r for f in descartadas for r in f["reglas_guardia"])),
        "mediana_s": round(statistics.median(tiempos), 2),
        "maximo_s": max(tiempos),
    }


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--modelo", action="append", required=True, help="ruta a un .gguf (se puede repetir)")
    p.add_argument("--conversaciones", type=Path, default=CONVERSACIONES)
    p.add_argument("--salida", type=Path, default=Path("comparacion_modelos.json"))
    args = p.parse_args(argv)

    from app.analizador_sentimiento import AnalizadorPysentimiento
    from app.generador_llm import GeneradorLlama

    conversaciones = cargar_conversaciones(args.conversaciones)
    analizador = AnalizadorPysentimiento()
    analizador.analizar("calentar el modelo")
    resultado = {"capas_gpu": os.getenv("SERENA_CAPAS_GPU", "0"), "modelos": {}}
    for ruta in args.modelo:
        generador = GeneradorLlama(ruta)
        generador.generar(({"role": "user", "content": "hola"},), max_tokens=1)  # la carga no cuenta
        filas = correr(conversaciones, analizador, generador)
        resultado["modelos"][Path(ruta).name] = {"resumen": resumir(filas), "filas": filas}
        r = resultado["modelos"][Path(ruta).name]["resumen"]
        print(f"{Path(ruta).name}: {r['descartadas']}/{r['con_modelo']} descartadas, mediana {r['mediana_s']} s")
    args.salida.write_text(json.dumps(resultado, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
