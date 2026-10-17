"""Semana 4: niveles de atención del cuestionario de Columbia (asesor, 16 oct).

Plan -> urgente (Hospital Infantil); intención -> comunitario; deseo de
morir, ideación o método -> seguimiento en la app y la escuela, sin alerta de
riesgo a los padres. Antes cualquier «sí» era riesgo alto.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.main import build_parent_alert  # noqa: E402
from app.niveles_columbia import COMUNITARIO, SEGUIMIENTO, SIN_RIESGO, URGENTE, nivel_columbia  # noqa: E402

PREGUNTAS = ("desear_muerto", "idea_suicidarse", "como_lo_haria", "intencion_llevarlo", "detalles_plan")


def respuestas(*si, phq9=0):
    reactivos = [{"id": p, "respuesta_valor": 1 if p in si else 0} for p in PREGUNTAS]
    return {
        "tipo_cuestionario": "suicidio",
        "phq9_score": phq9,
        "cssrs_score": len(si),
        "bloques": [{"bloque": "CSSRS", "puntuacion_total": len(si), "reactivos": reactivos}],
    }


def alerta(r):
    return build_parent_alert({"tipo_cuestionario": "suicidio", "respuestas": r}, {"nombre_completo": "Ana"})


@pytest.mark.parametrize(
    "si, nivel",
    [
        ((), SIN_RIESGO),
        (("desear_muerto",), SEGUIMIENTO),
        (("idea_suicidarse",), SEGUIMIENTO),
        (("como_lo_haria",), SEGUIMIENTO),
        (("desear_muerto", "idea_suicidarse", "como_lo_haria"), SEGUIMIENTO),
        (("intencion_llevarlo",), COMUNITARIO),
        (("desear_muerto", "intencion_llevarlo"), COMUNITARIO),
        (("detalles_plan",), URGENTE),
        (PREGUNTAS, URGENTE),
    ],
)
def test_el_nivel_lo_decide_la_pregunta_mas_grave(si, nivel):
    assert nivel_columbia(respuestas(*si)) == nivel


def test_plan_es_urgente_con_hospital_infantil():
    a = alerta(respuestas("detalles_plan"))
    assert a["tipo"] == "riesgo_alto"
    assert "Hospital Infantil" in a["recomendacion"]
    assert "Se ha detectado alto riesgo" in a["mensaje"]


def test_intencion_va_a_lo_comunitario():
    a = alerta(respuestas("intencion_llevarlo"))
    assert a["tipo"] == "riesgo_comunitario"
    assert "comunitario" in a["recomendacion"]


@pytest.mark.parametrize("si", [("desear_muerto",), ("idea_suicidarse",), ("como_lo_haria",)])
def test_los_demas_ya_no_son_riesgo_alto_para_los_padres(si):
    a = alerta(respuestas(*si))
    assert a["tipo"] == "cuestionario_completado"
    assert "seguimiento" in a["mensaje"]


def test_phq9_alto_sin_columbia_es_seguimiento_no_riesgo_alto():
    a = alerta(respuestas(phq9=15))
    assert a["tipo"] == "cuestionario_completado" and "seguimiento" in a["mensaje"]


def test_sin_reactivos_usa_el_nivel_de_la_app_o_el_total():
    assert nivel_columbia({"cssrs_nivel_dominio": "planConcreto"}) == URGENTE
    assert nivel_columbia({"cssrs_nivel_dominio": "comunitario"}) == COMUNITARIO
    # «planeacion» de la versión anterior mezclaba método e intención: se
    # toma el más grave de los dos.
    assert nivel_columbia({"cssrs_nivel_dominio": "planeacion"}) == COMUNITARIO
    assert nivel_columbia({"cssrs_score": 2}) == SEGUIMIENTO
    assert nivel_columbia({}) == SIN_RIESGO
