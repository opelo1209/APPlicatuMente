"""Semana 8: pregunta 14 de la Dra. Gonzalez (niveles de Columbia).

  a) Nivel comunitario: los CECOSAMA (Centros Comunitarios de Salud Mental y
     Adicciones, antes CAPA), con el directorio de CONASAMA.
  b) Nivel urgente: su contacto en el Hospital Infantil. El telefono solo va
     en la configuracion del servidor (CONTACTO_URGENTE_PILOTO), no en git.
  c) Seguimiento: la escuela esta informada de la atencion.
  d) PHQ-9 de 10 o mas sin respuestas de Columbia: ir al centro comunitario.
     Con ideacion ademas, tampoco baja de comunitario (no puede ser que
     contestar «si» a Columbia lleve a una atencion menor).
  f) Antecedentes familiares: «¿Tus papás están enfermos de algo?».
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.exploracion import (  # noqa: E402
    ANTECEDENTE_ANTES,
    ANTECEDENTE_FAMILIAR,
    ANTECEDENTE_SUSTANCIAS,
    secuencia_seguimiento,
)
from app.main import build_parent_alert  # noqa: E402
from app.niveles_columbia import (  # noqa: E402
    COMUNITARIO,
    DIRECTORIO_CECOSAMA,
    SEGUIMIENTO,
    SIN_RIESGO,
    UMBRAL_PHQ9_COMUNITARIO,
    URGENTE,
    contacto_urgente,
    nivel_atencion,
)
from tests.test_columbia_s4 import alerta, respuestas  # noqa: E402


# --------------------------------------------------------------- d) PHQ-9
@pytest.mark.parametrize(
    "si, phq9, nivel",
    [
        ((), 9, SIN_RIESGO),
        ((), UMBRAL_PHQ9_COMUNITARIO, COMUNITARIO),
        ((), 22, COMUNITARIO),
        (("desear_muerto",), 5, SEGUIMIENTO),
        (("desear_muerto",), 12, COMUNITARIO),
        (("intencion_llevarlo",), 12, COMUNITARIO),
        (("detalles_plan",), 3, URGENTE),
        (("detalles_plan",), 25, URGENTE),
    ],
)
def test_nivel_de_atencion_con_phq9(si, phq9, nivel):
    assert nivel_atencion(respuestas(*si, phq9=phq9)) == nivel


def test_phq9_desde_el_bloque_si_no_viene_el_total():
    r = respuestas()
    r.pop("phq9_score")
    r["bloques"].append({"bloque": "PHQ9", "puntuacion_total": 14})
    assert nivel_atencion(r) == COMUNITARIO


def test_phq9_alto_sin_columbia_manda_al_centro_comunitario():
    a = alerta(respuestas(phq9=15))
    assert a["tipo"] == "riesgo_comunitario"
    assert "CECOSAMA" in a["recomendacion"]
    assert "depresión" in a["mensaje"]
    assert "intención" not in a["mensaje"]


# ---------------------------------------------------------- a) CECOSAMA
def test_el_nivel_comunitario_nombra_los_cecosama_y_su_directorio():
    a = alerta(respuestas("intencion_llevarlo"))
    assert "Centro Comunitario de Salud Mental y Adicciones" in a["recomendacion"]
    assert "CECOSAMA" in a["recomendacion"]
    assert DIRECTORIO_CECOSAMA in a["recomendacion"]
    assert DIRECTORIO_CECOSAMA.startswith("https://www.conasama.salud.gob.mx/")


# ------------------------------------------------------ b) contacto urgente
def test_sin_configuracion_el_urgente_no_trae_telefono(monkeypatch):
    monkeypatch.delenv("CONTACTO_URGENTE_PILOTO", raising=False)
    assert contacto_urgente() is None
    a = alerta(respuestas("detalles_plan"))
    assert "Hospital Infantil de México Federico Gómez" in a["recomendacion"]


def test_con_configuracion_el_urgente_trae_el_contacto(monkeypatch):
    monkeypatch.setenv("CONTACTO_URGENTE_PILOTO", "Contacto de prueba, 55 0000 0000")
    a = alerta(respuestas("detalles_plan"))
    assert "Contacto de prueba, 55 0000 0000" in a["recomendacion"]


def test_el_contacto_se_limpia_y_se_acota(monkeypatch):
    monkeypatch.setenv("CONTACTO_URGENTE_PILOTO", "   ")
    assert contacto_urgente() is None
    monkeypatch.setenv("CONTACTO_URGENTE_PILOTO", "x" * 500)
    assert len(contacto_urgente()) <= 160


# ---------------------------------------------------- c) escuela informada
def test_en_seguimiento_la_escuela_esta_informada():
    a = alerta(respuestas("desear_muerto"))
    assert a["tipo"] == "cuestionario_completado"
    assert "la escuela estará informada" in a["mensaje"]


# --------------------------------------------- f) antecedentes familiares
def test_pregunta_por_antecedentes_familiares_antes_de_sustancias():
    seq = secuencia_seguimiento({"carga_percibida"})
    assert ANTECEDENTE_FAMILIAR == "¿Tus papás están enfermos de algo?"
    assert seq.index(ANTECEDENTE_ANTES) < seq.index(ANTECEDENTE_FAMILIAR) < seq.index(ANTECEDENTE_SUSTANCIAS)


def test_con_autolesion_tambien_pregunta_por_la_familia():
    assert ANTECEDENTE_FAMILIAR in secuencia_seguimiento({"autolesion_ocurrida"})
