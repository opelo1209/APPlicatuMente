"""Reentrenar RoBERTuito con las etiquetas de psicologia (Semana 8).

Ajuste fino del mismo modelo que usa la app
(pysentimiento/robertuito-sentiment-analysis) con validacion cruzada: en cada
pliegue se parte del modelo original, se entrena con los demas pliegues y se
mide en el que quedo fuera. Asi cada ejemplo se mide con un modelo que no lo
vio, y se puede comparar ejemplo por ejemplo con el modelo original.

El reporte responde lo que pidio el asesor: que hace la red antes y despues
(F1 por clase, matriz de confusion, que proporcion manda a cada clase, que
tan segura esta) y que cambio (cuantos ejemplos se corrigieron, cuantos se
echaron a perder y hacia donde se movieron).

Uso (en el servidor de la UAM; con GPU tarda minutos, en CPU mas):
  python -m entrenamiento.reentrenar <conjunto.jsonl> --salida reporte.json \\
      [--pliegues 5] [--epocas 3] [--tasa 2e-5] [--guardar-modelo carpeta]

Con --guardar-modelo, al final entrena con TODO el conjunto y guarda el
modelo para la app (no se publica sin la aprobacion del asesor).
"""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path
from typing import Sequence

from .datos import Ejemplo, cargar_conjunto, pliegues
from .linea_base import confianza_media, predecir_original
from .metricas_clases import cambios, f1_macro, reporte

MODELO = "pysentimiento/robertuito-sentiment-analysis"
_A_ETIQUETA = {"negativo": "NEG", "neutro": "NEU", "positivo": "POS"}
_DE_ETIQUETA = {v: k for k, v in _A_ETIQUETA.items()}
MAX_TOKENS = 128


def _preparar(textos: Sequence[str]) -> list[str]:
    from pysentimiento.preprocessing import preprocess_tweet

    return [preprocess_tweet(t, lang="es") for t in textos]


def _cargar(dispositivo):
    from transformers import AutoModelForSequenceClassification, AutoTokenizer

    tokenizador = AutoTokenizer.from_pretrained(MODELO)
    modelo = AutoModelForSequenceClassification.from_pretrained(MODELO).to(dispositivo)
    return tokenizador, modelo


def _entrenar(ejemplos: Sequence[Ejemplo], epocas: int, tasa: float, lote: int, semilla: int, dispositivo):
    import torch

    torch.manual_seed(semilla)
    tokenizador, modelo = _cargar(dispositivo)
    etiqueta_id = {modelo.config.id2label[i]: i for i in modelo.config.id2label}
    textos = _preparar([e.texto for e in ejemplos])
    objetivos = [etiqueta_id[_A_ETIQUETA[e.etiqueta]] for e in ejemplos]
    optimizador = torch.optim.AdamW(modelo.parameters(), lr=tasa, weight_decay=0.01)
    azar = random.Random(semilla)
    modelo.train()
    for _ in range(epocas):
        orden = list(range(len(textos)))
        azar.shuffle(orden)
        for inicio in range(0, len(orden), lote):
            idx = orden[inicio:inicio + lote]
            entrada = tokenizador([textos[i] for i in idx], padding=True, truncation=True,
                                  max_length=MAX_TOKENS, return_tensors="pt").to(dispositivo)
            salida = modelo(**entrada, labels=torch.tensor([objetivos[i] for i in idx], device=dispositivo))
            salida.loss.backward()
            optimizador.step()
            optimizador.zero_grad()
    return tokenizador, modelo


def _predecir(tokenizador, modelo, textos: Sequence[str], dispositivo, lote: int = 32):
    import torch

    modelo.eval()
    clases, confianzas = [], []
    preparados = _preparar(textos)
    with torch.no_grad():
        for inicio in range(0, len(preparados), lote):
            entrada = tokenizador(preparados[inicio:inicio + lote], padding=True, truncation=True,
                                  max_length=MAX_TOKENS, return_tensors="pt").to(dispositivo)
            probas = torch.softmax(modelo(**entrada).logits, dim=-1)
            for fila in probas:
                i = int(fila.argmax())
                clases.append(_DE_ETIQUETA[modelo.config.id2label[i]])
                confianzas.append(round(float(fila[i]), 4))
    return clases, confianzas


def validacion_cruzada(ejemplos, k, epocas, tasa, lote, semilla, dispositivo):
    """Prediccion de cada ejemplo con un modelo que no lo vio."""
    predichas = [""] * len(ejemplos)
    confianzas = [0.0] * len(ejemplos)
    f1_pliegues = []
    for n, prueba in enumerate(pliegues(ejemplos, k, semilla), 1):
        fuera = set(prueba)
        entrenamiento = [e for i, e in enumerate(ejemplos) if i not in fuera]
        tokenizador, modelo = _entrenar(entrenamiento, epocas, tasa, lote, semilla, dispositivo)
        clases, conf = _predecir(tokenizador, modelo, [ejemplos[i].texto for i in prueba], dispositivo)
        for i, c, p in zip(prueba, clases, conf):
            predichas[i], confianzas[i] = c, p
        f1_pliegues.append(f1_macro([ejemplos[i].etiqueta for i in prueba], clases))
        print(f"pliegue {n}/{k}: F1 macro {f1_pliegues[-1]}")
    return predichas, confianzas, f1_pliegues


def main(argv: list[str] | None = None) -> None:
    import torch

    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("conjunto", type=Path)
    p.add_argument("--salida", type=Path, required=True)
    p.add_argument("--pliegues", type=int, default=5)
    p.add_argument("--epocas", type=int, default=3)
    p.add_argument("--tasa", type=float, default=2e-5)
    p.add_argument("--lote", type=int, default=16)
    p.add_argument("--semilla", type=int, default=20261112)
    p.add_argument("--guardar-modelo", type=Path)
    args = p.parse_args(argv)

    dispositivo = "cuda" if torch.cuda.is_available() else "cpu"
    ejemplos = cargar_conjunto(args.conjunto)
    reales = [e.etiqueta for e in ejemplos]
    antes, conf_antes = predecir_original([e.texto for e in ejemplos])
    despues, conf_despues, f1_pliegues = validacion_cruzada(
        ejemplos, args.pliegues, args.epocas, args.tasa, args.lote, args.semilla, dispositivo
    )
    resultado = {
        "modelo": MODELO,
        "dispositivo": dispositivo,
        "parametros": {"pliegues": args.pliegues, "epocas": args.epocas, "tasa": args.tasa, "lote": args.lote},
        "antes": {**reporte(reales, antes), "confianza_media": confianza_media(antes, conf_antes)},
        "despues": {**reporte(reales, despues), "confianza_media": confianza_media(despues, conf_despues),
                    "f1_por_pliegue": f1_pliegues},
        "cambios": cambios(reales, antes, despues),
    }
    args.salida.write_text(json.dumps(resultado, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"F1 macro antes {resultado['antes']['f1_macro']} -> despues {resultado['despues']['f1_macro']}")
    print("cambios:", resultado["cambios"])

    if args.guardar_modelo:
        tokenizador, modelo = _entrenar(list(ejemplos), args.epocas, args.tasa, args.lote, args.semilla, dispositivo)
        args.guardar_modelo.mkdir(parents=True, exist_ok=True)
        modelo.save_pretrained(args.guardar_modelo)
        tokenizador.save_pretrained(args.guardar_modelo)
        print(f"modelo entrenado con {len(ejemplos)} ejemplos -> {args.guardar_modelo}")


if __name__ == "__main__":
    main()
