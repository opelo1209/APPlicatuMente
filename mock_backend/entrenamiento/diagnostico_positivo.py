"""Diagnóstico de la clase positiva con estratificación real y CV repetida."""

from __future__ import annotations

import argparse
import json
import statistics
from collections import Counter
from pathlib import Path
from typing import Mapping, Sequence

from . import reentrenar
from .datos import Ejemplo, cargar_conjunto, escribir_privado, pliegues_estratificados
from .metricas_clases import CLASES, f1_macro

CLASES_VISTA = CLASES + ("sin_clase",)
UMBRAL_CONFIANZA = 0.6
UMBRAL_CLARO_POSITIVO = 0.85
VISTAS = ("argmax", "compuerta_060", "claro_positivo_085")


def _division(a: float, b: float) -> float:
    return round(a / b, 4) if b else 0.0


def vistas_desde_probas(probas: Sequence[Mapping[str, float]]) -> dict[str, list[str]]:
    vistas = {nombre: [] for nombre in VISTAS}
    for fila in probas:
        mejor = max(CLASES, key=lambda c: fila.get(c, 0.0))
        confianza = fila.get(mejor, 0.0)
        vistas["argmax"].append(mejor)
        vistas["compuerta_060"].append(mejor if confianza >= UMBRAL_CONFIANZA else "sin_clase")
        if fila.get("positivo", 0.0) >= UMBRAL_CLARO_POSITIVO:
            vistas["claro_positivo_085"].append("positivo")
        else:
            otra = max(("negativo", "neutro"), key=lambda c: fila.get(c, 0.0))
            vistas["claro_positivo_085"].append(otra if fila.get(otra, 0.0) >= UMBRAL_CONFIANZA else "sin_clase")
    return vistas


def reporte_vista(reales: Sequence[str], predichas: Sequence[str]) -> dict[str, object]:
    if len(reales) != len(predichas):
        raise ValueError("reales y predichas deben tener el mismo largo")
    if set(reales) - set(CLASES) or set(predichas) - set(CLASES_VISTA):
        raise ValueError("clases desconocidas en la vista")
    conteo = Counter(zip(reales, predichas))
    matriz = {r: {p: conteo[(r, p)] for p in CLASES_VISTA} for r in CLASES}
    por_clase = {}
    for clase in CLASES:
        aciertos = matriz[clase][clase]
        falsos_positivos = sum(matriz[r][clase] for r in CLASES if r != clase)
        falsos_negativos = sum(matriz[clase][p] for p in CLASES_VISTA if p != clase)
        precision = _division(aciertos, aciertos + falsos_positivos)
        recall = _division(aciertos, aciertos + falsos_negativos)
        f1 = _division(2 * precision * recall, precision + recall)
        por_clase[clase] = {"precision": precision, "recall": recall, "f1": f1, "soporte": sum(matriz[clase].values())}
    return {
        "n": len(reales),
        "exactitud": _division(sum(r == p for r, p in zip(reales, predichas)), len(reales)),
        "f1_macro": round(sum(m["f1"] for m in por_clase.values()) / len(CLASES), 4),
        "por_clase": por_clase,
        "matriz_confusion": matriz,
        "distribucion_predicha": {c: _division(sum(p == c for p in predichas), len(predichas)) for c in CLASES_VISTA},
    }


def guardar_probabilidades(ruta: Path, filas: Sequence[Mapping[str, object]]) -> None:
    contenido = "".join(json.dumps(fila, ensure_ascii=False) + "\n" for fila in filas)
    escribir_privado(Path(ruta), contenido)


def _resumen(por_repeticion: Sequence[Mapping[str, object]]) -> dict[str, dict[str, float]]:
    resumen = {}
    for vista in VISTAS:
        corridas = [r["vistas"][vista] for r in por_repeticion]
        f1 = [r["f1_macro"] for r in corridas]
        recall = [r["por_clase"]["positivo"]["recall"] for r in corridas]
        exactitud = [r["exactitud"] for r in corridas]
        resumen[vista] = {
            "f1_macro_media": round(statistics.mean(f1), 4),
            "f1_macro_min": min(f1),
            "f1_macro_max": max(f1),
            "exactitud_media": round(statistics.mean(exactitud), 4),
            "recall_positivo_media": round(statistics.mean(recall), 4),
            "recall_positivo_min": min(recall),
            "recall_positivo_max": max(recall),
            "recall_positivo_desviacion": round(statistics.pstdev(recall), 4) if len(recall) > 1 else 0.0,
        }
    return resumen


def vistas_desde_detalle(
    filas: Sequence[dict],
) -> dict[str, list[tuple[str, str]]]:
    """Reconstruye las vistas desde el volcado por ejemplo ya existente.

    Es una aproximación: el detalle guarda la etiqueta ganadora y su
    confianza, no las tres probabilidades. Cuando el modelo dijo positivo con
    confianza menor a 0.85 no se intenta adivinar entre negativo y neutro; se
    marca ``sin_clase`` para no sobreestimar la celebración.
    """
    vistas: dict[str, list[tuple[str, str]]] = {vista: [] for vista in VISTAS}
    for fila in filas:
        real = fila["etiqueta_real"]
        prediccion = fila["prediccion_despues"]
        confianza = float(fila["confianza_despues"])
        compuerta = prediccion if confianza >= UMBRAL_CONFIANZA else "sin_clase"
        if prediccion == "positivo":
            claro = (
                "positivo"
                if confianza >= UMBRAL_CLARO_POSITIVO
                else "sin_clase"
            )
        else:
            claro = compuerta
        vistas["argmax"].append((real, prediccion))
        vistas["compuerta_060"].append((real, compuerta))
        vistas["claro_positivo_085"].append((real, claro))
    return vistas


def diagnosticar_desde_detalle(filas: Sequence[dict]) -> dict:
    vistas = vistas_desde_detalle(filas)
    return {
        "modo": "aproximado_desde_detalle",
        "ejemplos": len(filas),
        "nota": "Aproximación desde predicción y confianza; no incluye probabilidades completas.",
        "vistas": {
            vista: reporte_vista([real for real, _ in pares], [pred for _, pred in pares])
            for vista, pares in vistas.items()
        },
    }


def diagnosticar(
    ejemplos: Sequence[Ejemplo],
    salida_probabilidades: Path,
    k: int = 5,
    repeticiones: int = 3,
    semilla: int = 20261112,
    epocas: int = 3,
    tasa: float = 2e-5,
    lote: int = 16,
    dispositivo: str = "cpu",
) -> dict[str, object]:
    reales = [e.etiqueta for e in ejemplos]
    corridas = pliegues_estratificados(ejemplos, k, semilla, repeticiones)
    if repeticiones == 1:
        corridas = (corridas,)
    filas_probabilidad: list[dict[str, object]] = []
    por_repeticion: list[dict[str, object]] = []

    for repeticion, grupos in enumerate(corridas, 1):
        semilla_actual = semilla + repeticion - 1
        probas: list[Mapping[str, float] | None] = [None] * len(ejemplos)
        pliegue_de: list[int] = [0] * len(ejemplos)
        f1_pliegues = []
        for numero, prueba in enumerate(grupos, 1):
            print(f"repeticion {repeticion}/{repeticiones}, pliegue {numero}/{k}", flush=True)
            fuera = set(prueba)
            entrenamiento = [e for i, e in enumerate(ejemplos) if i not in fuera]
            tokenizador, modelo = reentrenar._entrenar(
                entrenamiento, epocas, tasa, lote, semilla_actual, dispositivo
            )
            calculadas = reentrenar._predecir_probas(
                tokenizador, modelo, [ejemplos[i].texto for i in prueba], dispositivo, lote
            )
            for i, fila in zip(prueba, calculadas):
                probas[i] = fila
                pliegue_de[i] = numero
            f1_pliegues.append(f1_macro(
                [reales[i] for i in prueba],
                [max(probas[i], key=probas[i].get) for i in prueba],
            ))
        vistas = vistas_desde_probas([fila for fila in probas if fila is not None])
        por_repeticion.append({
            "repeticion": repeticion,
            "semilla": semilla_actual,
            "f1_por_pliegue": f1_pliegues,
            "vistas": {vista: reporte_vista(reales, vistas[vista]) for vista in VISTAS},
        })
        for i, fila in enumerate(probas):
            if fila is None:
                continue
            filas_probabilidad.append({
                "codigo": ejemplos[i].codigo,
                "etiqueta_real": reales[i],
                "negativo": fila.get("negativo", 0.0),
                "neutro": fila.get("neutro", 0.0),
                "positivo": fila.get("positivo", 0.0),
                "repeticion": repeticion,
                "pliegue": pliegue_de[i],
            })
        guardar_probabilidades(salida_probabilidades, filas_probabilidad)

    guardar_probabilidades(salida_probabilidades, filas_probabilidad)
    n_positivos = sum(clase == "positivo" for clase in reales)
    recall_argmax = round(
        statistics.mean(r["vistas"]["argmax"]["por_clase"]["positivo"]["recall"] for r in por_repeticion), 4
    )
    return {
        "modelo": reentrenar.MODELO,
        "dispositivo": dispositivo,
        "parametros": {
            "pliegues": k,
            "repeticiones": repeticiones,
            "semilla": semilla,
            "epocas": epocas,
            "tasa": tasa,
            "lote": lote,
            "umbral_confianza": UMBRAL_CONFIANZA,
            "umbral_claro_positivo": UMBRAL_CLARO_POSITIVO,
        },
        "por_repeticion": por_repeticion,
        "agregado": {
            "vistas": _resumen(por_repeticion),
            "estabilidad": {
                "n_positivos_reales": n_positivos,
                "recall_positivo_argmax_promedio": recall_argmax,
            },
        },
    }


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("conjunto", type=Path)
    p.add_argument("--salida", type=Path, required=True)
    p.add_argument("--probabilidades", type=Path)
    p.add_argument("--desde-detalle", action="store_true")
    p.add_argument("--pliegues", type=int, default=5)
    p.add_argument("--repeticiones", type=int, default=3)
    p.add_argument("--epocas", type=int, default=3)
    p.add_argument("--tasa", type=float, default=2e-5)
    p.add_argument("--lote", type=int, default=16)
    p.add_argument("--semilla", type=int, default=20261112)
    args = p.parse_args(argv)

    if args.desde_detalle:
        filas = [
            json.loads(linea)
            for linea in args.conjunto.read_text(encoding="utf-8").splitlines()
            if linea.strip()
        ]
        resultado = diagnosticar_desde_detalle(filas)
        print("repeticion 1/1 desde detalle (sin entrenamiento)")
    else:
        if args.probabilidades is None:
            p.error("--probabilidades es obligatorio si no se usa --desde-detalle")
        import torch

        print("repeticion 1/...; se guarda progreso por repeticion")
        resultado = diagnosticar(
            cargar_conjunto(args.conjunto),
            args.probabilidades,
            k=args.pliegues,
            repeticiones=args.repeticiones,
            semilla=args.semilla,
            epocas=args.epocas,
            tasa=args.tasa,
            lote=args.lote,
            dispositivo="cuda" if torch.cuda.is_available() else "cpu",
        )

    escribir_privado(args.salida, json.dumps(resultado, ensure_ascii=False, indent=1))
    if args.desde_detalle:
        for vista, datos in resultado["vistas"].items():
            print(f"  {vista}: recall positivo {datos['por_clase']['positivo']['recall']}")
    else:
        print("recall positivo promedio por vista:")
        for vista, datos in resultado["agregado"]["vistas"].items():
            print(f"  {vista}: {datos['recall_positivo_media']}")


if __name__ == "__main__":
    main()
