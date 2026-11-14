"""Arma el conjunto etiquetado en un JSONL privado (Semana 8).

Uso (en el servidor de la UAM o en la carpeta privada):
  python -m entrenamiento.armar <cuestionario1_reducido.csv> <clave_etiquetado.json> \\
      <etiquetas.json> <salida.jsonl>

Solo imprime conteos, nunca respuestas.
"""

from __future__ import annotations

import csv
import json
import sys
from collections import Counter
from dataclasses import asdict
from pathlib import Path

from .datos import armar_conjunto, escribir_privado


def main(argv: list[str]) -> None:
    if len(argv) != 4:
        raise SystemExit(__doc__)
    csv_reducido, ruta_clave, ruta_etiquetas, salida = map(Path, argv)
    with csv_reducido.open(encoding="utf-8", newline="") as f:
        filas = list(csv.DictReader(f))
    clave = json.loads(ruta_clave.read_text(encoding="utf-8"))
    etiquetas = json.loads(ruta_etiquetas.read_text(encoding="utf-8")).get("etiquetas", {})
    ejemplos, descartes = armar_conjunto(filas, clave, etiquetas)
    escribir_privado(salida, "\n".join(json.dumps(asdict(e), ensure_ascii=False) for e in ejemplos) + "\n")
    print(f"{len(ejemplos)} ejemplos -> {salida}")
    print("por etiqueta:", dict(Counter(e.etiqueta for e in ejemplos)))
    print("descartados:", descartes)


if __name__ == "__main__":
    main(sys.argv[1:])
