"""Pre-etiquetado de las respuestas de REDCap que NO estan en la hoja a ciegas.

Pregunta del asesor (12 de noviembre): ¿se pueden ir categorizando o filtrar
como negativas, neutras y positivas mientras llegan las etiquetas?

Si, pero solo como ayuda para el conjunto de ENTRENAMIENTO, nunca para medir:
  - las 400 de la hoja a ciegas quedan fuera (son la prueba de psicologia);
  - usar solo lo que dice el analizador seria circular: el modelo aprenderia
    su propio sesgo (en la Semana 7 dejaba en neutro 2 de cada 3
    preocupaciones). Por eso se combinan dos pistas independientes: la
    PREGUNTA que contestaron (lo que te preocupa / lo que te molesta de las
    apps tiende a negativo; lo que te gusta de las apps, a positivo) y el
    ANALIZADOR. Solo cuando las dos coinciden, con confianza alta, la
    respuesta sale «sugerida»; las demas quedan para revisar a mano.
  - las sugeridas las confirma el equipo de la Dra. (confirmar es mas rapido
    que etiquetar desde cero).

Uso (en el servidor de la UAM o en la carpeta privada):
  python -m entrenamiento.preetiquetar <cuestionario1_reducido.csv> <clave_etiquetado.json> <salida.jsonl>

Escribe un JSONL privado (permisos 600) y solo imprime conteos.
"""

from __future__ import annotations

import csv
import json
import sys
from collections import Counter
from pathlib import Path

from .datos import escribir_privado

# Hacia donde tiende cada pregunta. La de «que hubiera ayudado» no tiene
# tendencia clara (pide sugerencias), asi que no se sugiere nada ahi.
TENDENCIA_PREGUNTA = {
    "preocupacion_actual": "negativo",
    "no_gustar_apps_adol_v2": "negativo",
    "cosas_fav_apps_adol_v2": "positivo",
}
CONFIANZA_MINIMA = 0.8
MIN_PALABRAS = 3


def sugerir(columna: str, predicha: str, confianza: float) -> str | None:
    """La etiqueta sugerida si la pregunta y el analizador coinciden con
    confianza alta; si no, None (revisar a mano)."""
    tendencia = TENDENCIA_PREGUNTA.get(columna)
    if tendencia is None or predicha != tendencia or confianza < CONFIANZA_MINIMA:
        return None
    return tendencia


def candidatas(filas, clave) -> list[tuple[str, str, str]]:
    """(id, columna, texto) de las respuestas que no estan en la hoja a ciegas."""
    en_hoja = {(d["id"], d["columna"]) for d in clave.values()}
    salida = []
    for fila in filas:
        for columna in TENDENCIA_PREGUNTA:
            texto = (fila.get(columna) or "").strip()
            if len(texto.split()) >= MIN_PALABRAS and (fila["id"], columna) not in en_hoja:
                salida.append((fila["id"], columna, texto))
    return salida


def main(argv: list[str]) -> None:
    if len(argv) != 3:
        raise SystemExit(__doc__)
    from .linea_base import predecir_original

    ruta_csv, ruta_clave, salida = map(Path, argv)
    with ruta_csv.open(encoding="utf-8", newline="") as f:
        filas = list(csv.DictReader(f))
    clave = json.loads(ruta_clave.read_text(encoding="utf-8"))
    lista = candidatas(filas, clave)
    predichas, confianzas = predecir_original([t for _, _, t in lista])
    registros = [
        {"id": i, "columna": c, "texto": t, "analizador": p, "confianza": conf, "sugerida": sugerir(c, p, conf)}
        for (i, c, t), p, conf in zip(lista, predichas, confianzas)
    ]
    escribir_privado(salida, "\n".join(json.dumps(r, ensure_ascii=False) for r in registros) + "\n")
    conteo = Counter((r["columna"], r["sugerida"] or "revisar") for r in registros)
    print(f"{len(registros)} respuestas fuera de la hoja a ciegas -> {salida}")
    for (columna, destino), n in sorted(conteo.items()):
        print(f"  {columna:28} {destino:9} {n}")


if __name__ == "__main__":
    main(sys.argv[1:])
