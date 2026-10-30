"""Semana 6: a «Hola Serena» el modelo contestaba «¡Hola! Estoy bien,
gracias por preguntar», como si le hubieran preguntado como esta. Las
respuestas del modelo de estas pruebas son las que dio Qwen 2.5 1.5B.
"""

import pytest

from app.contexto_mensaje import pregunta_por_serena
from app.guardia_salida import aplicar_guardia, hechos_de_salida
from app.serena_pipeline import responder
from tests.test_evaluador_diario import AnalizadorFalso
from tests.test_serena_pipeline import GeneradorFalso

NEUTRO = AnalizadorFalso("neutro")
RESPUESTA_QWEN = "Hola! Estoy bien, gracias por preguntar."


@pytest.mark.parametrize(
    "mensaje",
    ["Hola Serena, ¿cómo estás?", "que tal estas", "¿Cómo te va, Serena?", "y tu como andas?", "como has estado"],
)
def test_reconoce_cuando_le_preguntan_como_esta(mensaje):
    assert pregunta_por_serena(mensaje)


@pytest.mark.parametrize(
    "mensaje",
    ["Hola Serena", "hola", "Hola Serena!! que onda", "buenas tardes", "estoy bien"],
)
def test_un_saludo_no_es_preguntar_como_esta(mensaje):
    assert not pregunta_por_serena(mensaje)


@pytest.mark.parametrize(
    "texto",
    [RESPUESTA_QWEN, "Hola, estoy bien gracias.", "¡Estoy muy bien! ¿Y tú?", "Gracias por preguntar."],
)
def test_la_guardia_reconoce_cuando_el_modelo_habla_de_su_estado(texto):
    assert "habla_de_su_estado" in hechos_de_salida(texto, False)


@pytest.mark.parametrize(
    "texto",
    ["Qué bueno que estés bien.", "Estoy aquí para escucharte.", "Me da gusto que estés bien hoy."],
)
def test_no_confunde_hablar_del_estudiante_con_hablar_de_si(texto):
    assert "habla_de_su_estado" not in hechos_de_salida(texto, False)


def test_contestar_como_esta_solo_se_permite_si_se_lo_preguntaron():
    assert not aplicar_guardia(RESPUESTA_QWEN, False).mostrable
    assert aplicar_guardia(RESPUESTA_QWEN, False, pregunta_por_serena=True).mostrable


@pytest.mark.parametrize("mensaje", ["Hola Serena", "Hola Serena!! que onda"])
def test_a_un_saludo_no_contesta_estoy_bien(mensaje):
    r = responder(mensaje, NEUTRO, GeneradorFalso(RESPUESTA_QWEN))
    assert "estoy bien" not in r.texto.lower() and "gracias por preguntar" not in r.texto.lower(), r.texto
    assert r.texto.startswith("¡Hola!"), r.texto
    assert r.tipo == "normal" and r.alerta is None


def test_si_le_preguntan_como_esta_puede_contestar():
    r = responder("Hola Serena, ¿cómo estás?", NEUTRO, GeneradorFalso("Hola, estoy bien gracias. ¿Cómo estás tú?"))
    assert "estoy bien" in r.texto.lower(), r.texto


def test_un_saludo_con_algo_negativo_conserva_su_apertura():
    r = responder("hola serena, hoy me fue muy mal", AnalizadorFalso("negativo", "tristeza"), GeneradorFalso(RESPUESTA_QWEN))
    assert "estoy bien" not in r.texto.lower()
    assert not r.texto.startswith("¡Hola! Qué gusto"), r.texto


@pytest.mark.parametrize("mensaje", ["Hola Serena", "buenas tardes", "Hola Serena!! que onda", "hola"])
def test_solo_un_saludo_recibe_saludo_fijo(mensaje):
    from app.serena_pipeline import APERTURA_SALUDO, _solo_saluda

    assert _solo_saluda(mensaje, NEUTRO)
    assert APERTURA_SALUDO.startswith("¡Hola!")


@pytest.mark.parametrize("mensaje", ["hola, me siento solo", "hola serena, hoy fui al cine", "que onda"])
def test_si_cuenta_algo_no_es_solo_saludo(mensaje):
    from app.serena_pipeline import _solo_saluda

    assert not _solo_saluda(mensaje, NEUTRO)
