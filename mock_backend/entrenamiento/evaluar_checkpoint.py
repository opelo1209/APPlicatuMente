"""Evaluar un checkpoint reentrenado con baterías sintéticas (Semana 9).

Uso:
  python -m entrenamiento.evaluar_checkpoint <checkpoint> <bateria.json> \
      --salida reporte.json [--sin-original] [--lote 32]

Carga el checkpoint guardado por ``reentrenar.py --guardar-modelo`` y compara
sus números contra el analizador de producción sobre los mismos ejemplos.
La regresión sintética se mide con las baterías de la Semana 5 y 6.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

from .datos import cargar_conjunto
from .linea_base import confianza_media, predecir_original
from .metricas_clases import cambios, reporte

MAX_TOKENS = 128
_NORMALIZADAS = {
    "NEG": "negativo",
    "NEGATIVO": "negativo",
    "NEU": "neutro",
    "NEUTRO": "neutro",
    "POS": "positivo",
    "POSITIVO": "positivo",
}


def normalizar_etiqueta(valor: object) -> str:
    texto = str(valor).strip().upper()
    if texto not in _NORMALIZADAS:
        raise ValueError(f"etiqueta de checkpoint desconocida: {valor}")
    return _NORMALIZADAS[texto]


def dispositivo_actual() -> str:
    import torch

    return "cuda" if torch.cuda.is_available() else "cpu"


def evaluar_predicciones(
    reales: Sequence[str],
    predichas: Sequence[str],
    dispositivo: str,
    parametros: dict[str, object],
) -> dict[str, object]:
    return {
        "dispositivo": dispositivo,
        "parametros": parametros,
        **reporte(reales, predichas),
    }


def predecir_checkpoint(ruta: Path, textos: Sequence[str], lote: int = 32) -> tuple[list[str], list[float]]:
    import torch
    from transformers import AutoModelForSequenceClassification, AutoTokenizer
    from pysentimiento.preprocessing import preprocess_tweet

    dispositivo = dispositivo_actual()
    tokenizador = AutoTokenizer.from_pretrained(str(ruta))
    modelo = AutoModelForSequenceClassification.from_pretrained(str(ruta)).to(dispositivo)
    modelo.eval()
    id2label = {int(k): v for k, v in modelo.config.id2label.items()}
    preparados = [preprocess_tweet(t, lang="es") for t in textos]
    clases, confianzas = [], []
    with torch.no_grad():
        for inicio in range(0, len(preparados), lote):
            entrada = tokenizador(
                preparados[inicio:inicio + lote],
                padding=True,
                truncation=True,
                max_length=MAX_TOKENS,
                return_tensors="pt",
            ).to(dispositivo)
            probas = torch.softmax(modelo(**entrada).logits, dim=-1)
            for fila in probas:
                i = int(fila.argmax())
                clases.append(normalizar_etiqueta(id2label[i]))
                confianzas.append(round(float(fila[i]), 4))
    return clases, confianzas


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("checkpoint", type=Path)
    p.add_argument("conjuntos", nargs="+", type=Path)
    p.add_argument("--salida", type=Path, required=True)
    p.add_argument("--sin-original", action="store_true")
    p.add_argument("--lote", type=int, default=32)
    args = p.parse_args(argv)

    ejemplos = [e for ruta in args.conjuntos for e in cargar_conjunto(ruta)]
    reales = [e.etiqueta for e in ejemplos]
    textos = [e.texto for e in ejemplos]
    predichas, confianzas = predecir_checkpoint(args.checkpoint, textos, args.lote)
    parametros = {"checkpoint": args.checkpoint.name, "lote": args.lote, "max_tokens": MAX_TOKENS}
    resultado: dict[str, object] = {
        "modelo": str(args.checkpoint),
        "conjuntos": [ruta.name for ruta in args.conjuntos],
        "checkpoint": evaluar_predicciones(reales, predichas, dispositivo_actual(), parametros),
        "checkpoint_confianza_media": confianza_media(predichas, confianzas),
    }

    if not args.sin_original:
        original, conf_original = predecir_original(textos)
        resultado["original"] = evaluar_predicciones(reales, original, dispositivo_actual(), {"modelo": "produccion"})
        resultado["original_confianza_media"] = confianza_media(original, conf_original)
        resultado["cambios"] = cambios(reales, original, predichas)

    args.salida.write_text(json.dumps(resultado, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"checkpoint F1 macro {resultado['checkpoint']['f1_macro']}")
    if not args.sin_original:
        print(f"produccion F1 macro {resultado['original']['f1_macro']}")
    print(f"reporte -> {args.salida}")


if __name__ == "__main__":
    main()
