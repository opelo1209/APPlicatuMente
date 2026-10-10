"""Fase 3 del plan de mejora de Serena (Semana 3): busqueda de contenido.

Con TF-IDF solo, "hoy saque 10 en el examen" traia el modulo de sustancias
y "mi primo fuma mota" no traia nada. Meta del plan: la primera fuente es del
modulo correcto (o no hay fuente) en al menos 85 % de las preguntas, y
ninguna fuente sin relacion.
"""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.recuperador_corpus import recuperar, temas_de  # noqa: E402

_P = json.loads((Path(__file__).parent / "datos" / "preguntas_recuperacion.json").read_text(encoding="utf-8"))["preguntas"]


def _primero(texto):
    frs = recuperar(texto, k=2)
    return frs[0].modulo if frs else "ninguno"


@pytest.mark.parametrize("texto,esperado", _P)
def test_nunca_cita_una_fuente_sin_relacion(texto, esperado):
    assert _primero(texto) in (esperado, "ninguno")


def test_acierta_en_al_menos_85_por_ciento():
    correctas = sum(_primero(t) == e for t, e in _P)
    assert correctas >= 0.85 * len(_P), correctas


def test_sin_tema_no_hay_fuentes():
    assert recuperar("quiero aprender a tocar la guitarra") == ()


def test_temas():
    assert temas_de("me pongo nervioso") == {"Ansiedad"}
    assert temas_de("mis amigos vapean") == {"Consumo de sustancias"}
    assert temas_de("me tomo mi agua") == frozenset()
