"""Paquete del codigo de Serena para Kaggle (Semana 6).

El repositorio dejo de ser publico y el cuaderno ya no puede clonarlo. En
su lugar se sube este zip a Kaggle como dataset PRIVADO. Lleva solo lo que
necesita bateria.comparar_modelos: el codigo de app/ y bateria/, el corpus
y las frases inventadas por el equipo.

La revision clinica (app/datos/revision_clinica.json) es privada y no va
completa: solo el id y el estado de cada texto, para que Serena no cite lo
que la doctora rechazo. Sin nombre de la revisora, fecha ni comentarios.

Uso (desde mock_backend/):
  python -m bateria.paquete_kaggle --salida ~/aptm_kaggle_s6.zip
"""

from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path

from app.revision_clinica import CORRECCIONES_APLICADAS, RUTA_REVISION

RAIZ = Path(__file__).resolve().parent.parent
PREFIJO = "mock_backend"
CARPETAS = ("app", "bateria")
EXTENSIONES = (".py", ".json", ".sha256")
NO_VAN = {RUTA_REVISION.resolve()}


def revision_minima(datos: dict) -> dict:
    """Solo id y estado; el texto corregido solo de las correcciones ya
    aplicadas (desarrollan la sigla TCC)."""
    contenido = []
    for item in datos.get("contenido", []):
        fila = {"id": item["id"], "estado": item.get("estado")}
        if item["id"] in CORRECCIONES_APLICADAS and item.get("texto_corregido"):
            fila["texto_corregido"] = item["texto_corregido"]
        contenido.append(fila)
    return {"formato": datos.get("formato"), "contenido": contenido}


def archivos(raiz: Path = RAIZ) -> list[Path]:
    encontrados = [
        p
        for carpeta in CARPETAS
        for p in sorted((raiz / carpeta).rglob("*"))
        if p.is_file() and p.suffix in EXTENSIONES and "__pycache__" not in p.parts and p.resolve() not in NO_VAN
    ]
    return [*encontrados, raiz / "requirements.txt"]


def armar(salida: Path, raiz: Path = RAIZ, revision: Path = RUTA_REVISION) -> list[str]:
    nombres = []
    with zipfile.ZipFile(salida, "w", zipfile.ZIP_DEFLATED) as zf:
        for p in archivos(raiz):
            nombre = f"{PREFIJO}/{p.relative_to(raiz).as_posix()}"
            zf.write(p, nombre)
            nombres.append(nombre)
        if revision.exists():
            minima = revision_minima(json.loads(revision.read_text(encoding="utf-8")))
            nombre = f"{PREFIJO}/{RUTA_REVISION.relative_to(RAIZ).as_posix()}"
            zf.writestr(nombre, json.dumps(minima, ensure_ascii=False, indent=1))
            nombres.append(nombre)
    return nombres


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--salida", type=Path, default=Path("aptm_kaggle_s6.zip"))
    args = p.parse_args(argv)
    nombres = armar(args.salida.expanduser())
    con_revision = any(n.endswith("revision_clinica.json") for n in nombres)
    print(f"{len(nombres)} archivos -> {args.salida}")
    print("revision clinica minima incluida" if con_revision else "AVISO: sin revision clinica; lo rechazado no se filtra")


if __name__ == "__main__":
    main()
