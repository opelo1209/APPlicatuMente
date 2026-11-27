"""Semana 8: pregunta 9 de la Dra. Gonzalez.

«Usar una apertura neutra ("Gracias por escribirme.") salvo que el mensaje
sea claramente negativo.» Claramente negativo = el analizador dice negativo
con al menos 0.6 Y detecta una emocion negativa (tristeza, enojo, miedo o
asco). Con las 120 frases de la bateria, ningun dia neutro recibe asi la
apertura negativa (antes 8 de 20 en s5); ver reporte de la Semana 8.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.serena_pipeline import (  # noqa: E402
    APERTURA_NEGATIVA,
    APERTURA_NEUTRA,
    APERTURA_POSITIVA,
    _apertura_fija,
    claramente_negativo,
)
from tests.test_evaluador_diario import AnalizadorFalso  # noqa: E402


def _analisis(polaridad, emocion, prob=0.9):
    return AnalizadorFalso(polaridad, emocion, prob).analizar("x")


@pytest.mark.parametrize("emocion", ["tristeza", "enojo", "miedo", "asco"])
def test_negativo_con_emocion_negativa_es_claramente_negativo(emocion):
    assert claramente_negativo(_analisis("negativo", emocion))
    assert _apertura_fija(_analisis("negativo", emocion)) == APERTURA_NEGATIVA


def test_negativo_sin_emocion_recibe_la_apertura_neutra():
    # «Me dormí tarde y ando un poco cansado»: negativo 0.95, emocion «otra».
    analisis = _analisis("negativo", "otra", 0.95)
    assert not claramente_negativo(analisis)
    assert _apertura_fija(analisis) == APERTURA_NEUTRA


def test_negativo_con_poca_confianza_recibe_la_apertura_neutra():
    assert _apertura_fija(_analisis("negativo", "tristeza", 0.55)) == APERTURA_NEUTRA


def test_neutro_y_sin_analisis_reciben_la_apertura_neutra():
    assert _apertura_fija(_analisis("neutro", "otra")) == APERTURA_NEUTRA
    assert _apertura_fija(None) == APERTURA_NEUTRA


def test_positivo_no_cambia():
    assert _apertura_fija(_analisis("positivo", "alegria")) == APERTURA_POSITIVA


def test_textos_de_las_aperturas():
    assert APERTURA_NEUTRA == "Gracias por escribirme."
    assert APERTURA_NEGATIVA.startswith("Gracias por contármelo")
