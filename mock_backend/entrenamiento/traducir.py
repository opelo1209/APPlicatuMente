"""Traducción local con modelos Marian (Helsinki-NLP/opus-mt-*) (Semana 10).

VADER solo tiene léxico en inglés y los corpus públicos están en vietnamita e
italiano. Para no mandar textos a ningún servicio externo, todo se traduce en
la máquina con modelos ya descargados (HF_HUB_OFFLINE=1 después de la primera
descarga). Esto es obligatorio para las respuestas de REDCap: su traducción al
inglés se guarda solo en la carpeta privada.

Uso para el conjunto clínico privado (agrega ``texto_en`` a cada línea):
  python -m entrenamiento.traducir <conjunto.jsonl> <salida.jsonl> [--ruta es-en]
"""

from __future__ import annotations

import argparse
import json
from functools import lru_cache
from pathlib import Path
from typing import Sequence

from .datos import cargar_conjunto, escribir_privado

PREFIJO = "Helsinki-NLP/opus-mt-"
LOTE = 16
MAX_TOKENS = 256


@lru_cache(maxsize=4)
def _cargar(par: str):
    from transformers import MarianMTModel, MarianTokenizer

    nombre = PREFIJO + par
    return MarianTokenizer.from_pretrained(nombre), MarianMTModel.from_pretrained(nombre).eval()


def orden_por_longitud(textos: Sequence[str]) -> list[int]:
    """Índices ordenados por largo: los lotes quedan parejos y casi sin relleno."""
    return sorted(range(len(textos)), key=lambda i: len(textos[i]))


def limite_salida(tokens_entrada: int) -> int:
    """Tope de tokens generados: el doble de la entrada más margen, nunca más
    de MAX_TOKENS. Evita que una frase que el modelo repite en bucle consuma
    256 pasos de decodificación."""
    return min(MAX_TOKENS, 2 * tokens_entrada + 16)


def traducir(textos: Sequence[str], par: str, lote: int = LOTE, cache: dict | None = None) -> list[str]:
    """Traduce en lotes conservando el orden; textos vacíos quedan vacíos.

    ``cache`` (texto -> traducción) evita repetir trabajo entre corridas."""
    cache = {} if cache is None else cache
    pendientes = [t for t in dict.fromkeys(textos) if t and t not in cache]
    if pendientes:
        import torch

        tokenizador, modelo = _cargar(par)
        orden = orden_por_longitud(pendientes)
        with torch.no_grad():
            for n, inicio in enumerate(range(0, len(orden), lote), 1):
                grupo = [pendientes[i] for i in orden[inicio:inicio + lote]]
                entrada = tokenizador(grupo, return_tensors="pt", padding=True, truncation=True,
                                      max_length=MAX_TOKENS)
                generado = modelo.generate(**entrada, num_beams=1,
                                           max_new_tokens=limite_salida(entrada["input_ids"].shape[1]))
                for original, traducido in zip(grupo, tokenizador.batch_decode(generado, skip_special_tokens=True)):
                    cache[original] = traducido
                if n % 10 == 0:
                    print(f"[{par}] {min(inicio + lote, len(orden))}/{len(orden)}", flush=True)
    return [cache.get(t, "") if t else "" for t in textos]


def traducir_cadena(textos: Sequence[str], ruta: Sequence[str], caches: dict | None = None) -> list[str]:
    """Aplica varios pares seguidos, por ejemplo ["vi-en", "en-es"] (pivote).

    ``caches`` (par -> {texto: traducción}) se llena en el lugar."""
    caches = {} if caches is None else caches
    actuales = list(textos)
    for par in ruta:
        actuales = traducir(actuales, par, cache=caches.setdefault(par, {}))
    return actuales


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("conjunto", type=Path)
    p.add_argument("salida", type=Path)
    p.add_argument("--ruta", default="es-en", help="pares separados por coma, p. ej. es-en")
    args = p.parse_args(argv)
    ejemplos = cargar_conjunto(args.conjunto)
    en = traducir_cadena([e.texto for e in ejemplos], args.ruta.split(","))
    lineas = (json.dumps({**e.__dict__, "texto_en": t}, ensure_ascii=False) for e, t in zip(ejemplos, en))
    escribir_privado(args.salida, "\n".join(lineas) + "\n")
    print(f"{len(ejemplos)} textos traducidos -> {args.salida} (permisos 600)")


if __name__ == "__main__":
    main()
