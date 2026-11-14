"""Conjunto etiquetado para medir y reentrenar el analizador (Semana 8).

Junta tres archivos que nunca salen del servidor de la UAM o de la carpeta
privada:
  - el cuestionario 1 de REDCap ya reducido (explorar_redcap.py, Semana 7):
    columnas id, edad y las respuestas abiertas;
  - la clave de la hoja de etiquetado: codigo R001 -> id y columna;
  - etiquetas.json que devuelve psicologia: {"etiquetas": {"R001": "negativo",
    "R001|personal": true, ...}}.

Se excluyen las respuestas marcadas «No es claro» o «Tiene un dato personal».
Tambien sirve con la bateria (frases_s5.json, frases_s6.json) para probar.
"""

from __future__ import annotations

import json
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Mapping, Sequence

from .metricas_clases import CLASES


@dataclass(frozen=True)
class Ejemplo:
    codigo: str
    texto: str
    etiqueta: str
    origen: str = ""


def armar_conjunto(
    filas: Iterable[Mapping[str, str]],
    clave: Mapping[str, Mapping[str, str]],
    etiquetas: Mapping[str, object],
) -> tuple[tuple[Ejemplo, ...], dict[str, int]]:
    """Ejemplos validos y cuantos se descartaron y por que."""
    por_id = {f["id"]: f for f in filas}
    marcados_personales = {k.split("|", 1)[0] for k, v in etiquetas.items() if "|" in k and v is True}
    ejemplos, descartes = [], {"no_claro": 0, "dato_personal": 0, "sin_etiqueta": 0, "sin_texto": 0}
    for codigo in sorted(clave):
        etiqueta = etiquetas.get(codigo)
        if codigo in marcados_personales:
            descartes["dato_personal"] += 1
            continue
        if etiqueta not in CLASES:
            descartes["no_claro" if etiqueta == "no_claro" else "sin_etiqueta"] += 1
            continue
        datos = clave[codigo]
        texto = (por_id.get(datos["id"], {}).get(datos["columna"]) or "").strip()
        if not texto:
            descartes["sin_texto"] += 1
            continue
        ejemplos.append(Ejemplo(codigo, texto, str(etiqueta), datos["columna"]))
    return tuple(ejemplos), descartes


def desde_bateria(ruta: Path) -> tuple[Ejemplo, ...]:
    datos = json.loads(Path(ruta).read_text(encoding="utf-8"))
    return tuple(Ejemplo(f["id"], f["texto"], f["polaridad"], Path(ruta).stem) for f in datos["frases"])


def pliegues(ejemplos: Sequence[Ejemplo], k: int, semilla: int = 20261112) -> tuple[tuple[int, ...], ...]:
    """Indices de prueba de cada pliegue, estratificados por clase: cada
    pliegue tiene mas o menos la misma proporcion de cada etiqueta."""
    if k < 2:
        raise ValueError("se necesitan al menos 2 pliegues")
    azar = random.Random(semilla)
    grupos: list[list[int]] = [[] for _ in range(k)]
    siguiente = 0
    for clase in CLASES:
        indices = [i for i, e in enumerate(ejemplos) if e.etiqueta == clase]
        azar.shuffle(indices)
        for i in indices:
            grupos[siguiente % k].append(i)
            siguiente += 1
    return tuple(tuple(sorted(g)) for g in grupos)


def escribir_privado(ruta: Path, contenido: str) -> None:
    ruta = Path(ruta)
    ruta.write_text(contenido, encoding="utf-8")
    ruta.chmod(0o600)


def cargar_conjunto(ruta: Path) -> tuple[Ejemplo, ...]:
    """Conjunto ya armado (JSONL privado) o una bateria (JSON)."""
    ruta = Path(ruta)
    if ruta.suffix == ".json":
        return desde_bateria(ruta)
    return tuple(Ejemplo(**json.loads(linea)) for linea in ruta.read_text(encoding="utf-8").splitlines() if linea)
