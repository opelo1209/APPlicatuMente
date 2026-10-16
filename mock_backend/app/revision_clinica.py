"""Revision clinica del corpus de Serena (cierre de la Semana 3).

La Dra. Nadia Gonzalez reviso el corpus el 9 de octubre de 2026 con la
herramienta de revision (formato revision-clinica-serena/v2). Este modulo
lee la copia del servidor (datos/revision_clinica.json, sin cedula) y le da
a cada texto su estado:

  aprobado   la revisora lo aprobo tal cual
  corregido  pidio cambios y su texto corregido ya se aplico
  cambios    pidio cambios que todavia se aclaran con ella (el texto sigue
             igual)
  pendiente  no se ha revisado
  rechazado  la revisora lo rechazo (segunda entrega, 13 oct): Serena no
             lo cita nunca

Solo se aplican las correcciones de CORRECCIONES_APLICADAS. Las demas (el
criterio de "6 meses", la lista de sintomas para padres escrita en segunda
persona) cambian el sentido clinico y se consultan antes con la doctora.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from types import MappingProxyType
from typing import Mapping

RUTA_REVISION = Path(__file__).parent / "datos" / "revision_clinica.json"

ESTADO_APROBADO = "aprobado"
ESTADO_CORREGIDO = "corregido"
ESTADO_CAMBIOS = "cambios"
ESTADO_PENDIENTE = "pendiente"
ESTADO_RECHAZADO = "rechazado"

# Correcciones claras: solo desarrollan la sigla TCC.
CORRECCIONES_APLICADAS = frozenset({
    "ansiedad.teenImgTerapia.adolescente",
    "ansiedad.parentTherapyContent.familia",
})


@dataclass(frozen=True)
class Revision:
    estado: str
    revisor: str | None = None
    fecha: str | None = None
    referencia: str | None = None
    texto_corregido: str | None = None


SIN_REVISION = Revision(ESTADO_PENDIENTE)


@lru_cache(maxsize=1)
def _revisiones(ruta: str = str(RUTA_REVISION)) -> Mapping[str, Revision]:
    try:
        datos = json.loads(Path(ruta).read_text(encoding="utf-8"))
    except FileNotFoundError:
        return MappingProxyType({})
    revisor, fecha = datos.get("revisor"), datos.get("fecha")
    resultado: dict[str, Revision] = {}
    for item in datos.get("contenido", []):
        estado = item.get("estado") or ESTADO_PENDIENTE
        corregido = item.get("texto_corregido") if item["id"] in CORRECCIONES_APLICADAS else None
        if estado == ESTADO_CAMBIOS and corregido:
            estado = ESTADO_CORREGIDO
        con_revisor = estado != ESTADO_PENDIENTE
        resultado[item["id"]] = Revision(
            estado=estado,
            revisor=revisor if con_revisor else None,
            fecha=fecha if con_revisor else None,
            referencia=item.get("referencia"),
            texto_corregido=corregido,
        )
    return MappingProxyType(resultado)


def revision_de(id_texto: str) -> Revision:
    return _revisiones().get(id_texto, SIN_REVISION)


def texto_vigente(id_texto: str, original: str) -> str:
    """El texto que Serena debe usar: el corregido si ya se aplico."""
    return revision_de(id_texto).texto_corregido or original
