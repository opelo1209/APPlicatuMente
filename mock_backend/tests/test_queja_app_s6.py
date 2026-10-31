"""Semana 6 (Kaggle, corrida 3): a «No veo completo el mensaje» el 7B dijo
«Entiendo que sientes que no estas tan feliz». S17 lo detectaba, pero el
analizador leyo la queja como negativa (0.73) y Serena tenia permiso de
reconocer un malestar. Una queja sobre la app describe a la app, no a
quien escribe: como en una consulta, no cuenta su polaridad.
"""

import pytest

from app.contexto_mensaje import queja_de_la_app
from app.serena_pipeline import responder
from tests.test_evaluador_diario import AnalizadorFalso
from tests.test_serena_pipeline import GeneradorFalso

NEGATIVO = AnalizadorFalso("negativo", "tristeza", 0.9)
RESPUESTA_7B = "Entiendo que sientes que no estás tan feliz. ¿Podrías contarme más sobre cómo te sientes?"

QUEJAS = [
    "No veo completo el mensaje",
    "no carga la app",
    "la pantalla se congeló",
    "se cortó tu respuesta",
    "el juego no funciona",
    "no entiendo tu respuesta",
    "el botón no sirve",
    "la respuesta salió incompleta",
    "no me abre el diario",
]

NO_SON_QUEJAS = [
    "no puedo ver a mi papá",
    "mi mamá no me deja usar el celular",
    "mis amigos no me dejan jugar",
    "estoy triste porque la app no carga",
    "me siento mal, el juego no funciona y nada me sale",
    "hoy me fue mal en el examen",
    "no veo sentido a nada",
]


@pytest.mark.parametrize("mensaje", QUEJAS)
def test_reconoce_una_queja_sobre_la_app(mensaje):
    assert queja_de_la_app(mensaje)


@pytest.mark.parametrize("mensaje", NO_SON_QUEJAS)
def test_no_confunde_con_lo_que_le_pasa_a_quien_escribe(mensaje):
    assert not queja_de_la_app(mensaje)


def test_en_una_queja_serena_no_supone_tristeza():
    r = responder("No veo completo el mensaje", NEGATIVO, GeneradorFalso(RESPUESTA_7B))
    assert "feliz" not in r.texto.lower(), r.texto
    assert r.turno.polaridad is None  # no suma a la racha negativa
    assert "S17" in r.etapas["salida"]["reglas"]


def test_si_ademas_cuenta_como_se_siente_se_respeta():
    r = responder(
        "estoy triste porque la app no carga",
        NEGATIVO,
        GeneradorFalso("Entiendo que te sientes triste, gracias por contármelo."),
    )
    assert r.texto.startswith("Entiendo que te sientes triste"), r.texto
    assert r.turno.polaridad == "negativo"


def test_una_queja_con_riesgo_sigue_siendo_crisis():
    r = responder("la app no sirve y ya no quiero vivir", NEGATIVO, GeneradorFalso(RESPUESTA_7B))
    assert r.tipo == "crisis"


@pytest.mark.parametrize("texto", ["¡Hola! Me siento un poco triste.", "Yo me siento mal también."])
def test_s13_serena_no_dice_que_se_siente_mal(texto):
    from app.guardia_salida import aplicar_guardia

    g = aplicar_guardia(texto, False, breve=True)
    assert "confunde_papel" in g.hechos and not g.mostrable


def test_s13_no_confunde_cuando_repite_lo_que_dijo_el_estudiante():
    from app.guardia_salida import hechos_de_salida

    assert "confunde_papel" not in hechos_de_salida("Gracias por contarme cómo te sientes.", False)
