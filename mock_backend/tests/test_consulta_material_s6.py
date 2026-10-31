"""Semana 6 (prototipo19, captura del usuario): a «¿qué le pasa al cuerpo
si vapeo?» el modelo dijo «puede que experimentes sensación de calor en el
cuerpo» y la fuente «Módulo de Consumo de sustancias» salía dos veces. La
guardia revisa el estilo, no los hechos: en una consulta con material
aprobado el modelo ya no redacta, y cada fuente se muestra una vez.
"""

from app.acompanamiento import APERTURA_INFORMATIVA
from app.serena_pipeline import SIN_MODELO_MATERIAL, responder
from tests.test_evaluador_diario import AnalizadorFalso
from tests.test_serena_pipeline import GeneradorFalso

NEUTRO = AnalizadorFalso("neutro")
INVENTADO = "Si vapeas, puede que experimentes sensación de calor en el cuerpo."
VAPEO = "¿qué le pasa al cuerpo si vapeo?"


def test_en_una_consulta_con_material_el_modelo_no_inventa():
    r = responder(VAPEO, NEUTRO, GeneradorFalso(INVENTADO))
    assert r.fuentes, "la consulta debe recuperar material de sustancias"
    assert "calor" not in r.texto, r.texto
    assert r.texto.startswith(APERTURA_INFORMATIVA), r.texto
    assert "Del material del programa:" in r.texto
    assert r.etapas["modelo"] == SIN_MODELO_MATERIAL


def test_mientras_se_arma_tampoco_se_ve_lo_inventado():
    vistas = []
    responder(VAPEO, NEUTRO, GeneradorFalso(INVENTADO), al_avanzar=vistas.append)
    assert all("calor" not in v for v in vistas), vistas


def test_cada_fuente_se_muestra_una_vez():
    r = responder(VAPEO, NEUTRO, GeneradorFalso(INVENTADO))
    titulos = [f["titulo"] for f in r.fuentes]
    assert len(titulos) == len(set(titulos)), titulos


def test_fuera_de_una_consulta_el_modelo_sigue_redactando():
    r = responder("hoy me fue bien en el examen", AnalizadorFalso("positivo", "alegria"),
                  GeneradorFalso("¡Qué gusto que te haya ido bien!"))
    assert r.texto.startswith("¡Qué gusto"), r.texto
