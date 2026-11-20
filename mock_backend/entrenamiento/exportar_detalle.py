"""Volcado privado por ejemplo para la revisión clínica (Semana 9).

Uso con predicciones fuera de pliegue, recomendado para revisar cambios:
  python -m entrenamiento.exportar_detalle <conjunto.jsonl> --salida detalle.jsonl \
      [--pliegues 5] [--epocas 3] [--tasa 2e-5] [--lote 16] [--semilla 20261112]

Uso con un checkpoint ya guardado, solo para inspección del modelo final:
  python -m entrenamiento.exportar_detalle <conjunto.jsonl> \
      --modelo-despues <checkpoint> --salida detalle.jsonl

Cada línea incluye texto real, predicciones y confianzas. El archivo queda con
permisos 600 y nunca se copia fuera de la UAM.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

from .datos import Ejemplo, cargar_conjunto, escribir_privado
from .linea_base import predecir_original


def filas_detalle(
    ejemplos: Sequence[Ejemplo],
    antes: Sequence[str],
    conf_antes: Sequence[float],
    despues: Sequence[str],
    conf_despues: Sequence[float],
) -> list[dict[str, object]]:
    largos = (len(ejemplos), len(antes), len(conf_antes), len(despues), len(conf_despues))
    if len(set(largos)) != 1:
        raise ValueError("ejemplos y predicciones deben tener el mismo largo")
    return [
        {
            "codigo": e.codigo,
            "texto": e.texto,
            "etiqueta_real": e.etiqueta,
            "prediccion_antes": a,
            "prediccion_despues": d,
            "confianza_antes": round(float(ca), 4),
            "confianza_despues": round(float(cd), 4),
        }
        for e, a, ca, d, cd in zip(ejemplos, antes, conf_antes, despues, conf_despues)
    ]


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("conjunto", type=Path)
    p.add_argument("--salida", type=Path, required=True)
    p.add_argument("--modelo-despues", type=Path)
    p.add_argument("--pliegues", type=int, default=5)
    p.add_argument("--epocas", type=int, default=3)
    p.add_argument("--tasa", type=float, default=2e-5)
    p.add_argument("--lote", type=int, default=16)
    p.add_argument("--semilla", type=int, default=20261112)
    args = p.parse_args(argv)

    ejemplos = cargar_conjunto(args.conjunto)
    textos = [e.texto for e in ejemplos]
    antes, conf_antes = predecir_original(textos)

    if args.modelo_despues:
        from .evaluar_checkpoint import predecir_checkpoint

        despues, conf_despues = predecir_checkpoint(args.modelo_despues, textos, args.lote)
    else:
        from .evaluar_checkpoint import dispositivo_actual
        from .reentrenar import validacion_cruzada

        despues, conf_despues, _ = validacion_cruzada(
            ejemplos,
            args.pliegues,
            args.epocas,
            args.tasa,
            args.lote,
            args.semilla,
            dispositivo_actual(),
        )

    filas = filas_detalle(ejemplos, antes, conf_antes, despues, conf_despues)
    escribir_privado(args.salida, "\n".join(json.dumps(f, ensure_ascii=False) for f in filas) + "\n")
    print(f"{len(filas)} filas privadas -> {args.salida}")


if __name__ == "__main__":
    main()
