"""Semana 6 (captura del asesor, 30 de octubre).

El asesor platico con Serena sin ninguna senal de riesgo: pidio tecnicas
para sentirse mas feliz y Serena contesto «Entiendo que te sientes triste»,
prometio una lista que se corto en «1.» y termino con «¡Hola! Parece que
estas pasando por un momento dificil». El analizador leyo los mensajes como
neutros: lo invento el modelo. Las respuestas del modelo de estas pruebas
son las que dio Qwen 2.5 1.5B al repetir la conversacion.
"""

import pytest

from app.acompanamiento import APERTURA_INFORMATIVA, FICHAS_INFORMATIVAS
from app.contexto_mensaje import TEMA_BIENESTAR, analizar_contexto
from app.guardia_salida import aplicar_guardia, hechos_de_salida
from app.serena_pipeline import responder
from tests.test_evaluador_diario import AnalizadorFalso
from tests.test_serena_pipeline import GeneradorFalso

NEUTRO = AnalizadorFalso("neutro")

# ------------------------------ contexto -----------------------------------

PIDE_BIENESTAR = [
    "Bien, pero quieor saber que tecnicas emocionales me recomiendas para sentirme mas feliz",
    "¿Cómo puedo ser más feliz?",
    "dame consejos para sentirme mejor",
    "qué puedo hacer para estar de buen ánimo",
    "me siento bien, ¿qué hábitos me ayudan a seguir así de contento?",
    "tips para tener más bienestar",
    "¿Qué cosas me ayudan a estar contento en la escuela?",
    "Dame consejos para tener un buen día",
    "Quiero aprender cosas para estar más contento",
]

CON_MALESTAR = [
    "me siento muy triste, ¿qué técnicas me ayudan a sentirme mejor?",
    "ya no aguanto, dame consejos para estar feliz",
    "estoy deprimido y quiero ser feliz",
    "nadie me ayuda y no estoy contento",
]


@pytest.mark.parametrize("frase", PIDE_BIENESTAR)
def test_pedir_tecnicas_para_estar_bien_es_una_consulta_de_bienestar(frase):
    c = analizar_contexto(frase)
    assert c.informativa and c.tema == TEMA_BIENESTAR, c


@pytest.mark.parametrize("frase", CON_MALESTAR)
def test_si_ademas_cuenta_un_malestar_no_es_consulta(frase):
    assert not analizar_contexto(frase).informativa


def test_pedir_bienestar_no_tapa_una_crisis():
    r = responder("dame consejos para ser feliz, aunque ya no quiero vivir", NEUTRO, GeneradorFalso())
    assert r.tipo == "crisis"


# ------------------------------- guardia -----------------------------------

SUPONE_MALESTAR = [
    "¡Hola! Parece que estás pasando por un momento difícil.",
    "¡Hola! Parece que estás experimentando un poco de tristeza.",
    "Entiendo que te sientes triste.",
    "Veo que la estás pasando mal.",
    "Noto que te sientes preocupado.",
    "Entiendo que te sientes un poco sola/a hoy.",
]


@pytest.mark.parametrize("texto", SUPONE_MALESTAR)
def test_la_guardia_reconoce_cuando_el_modelo_supone_malestar(texto):
    assert "supone_malestar" in hechos_de_salida(texto, False)


@pytest.mark.parametrize(
    "texto",
    ["Me alegra que quieras sentirte más feliz.", "Entiendo que quieres saber más del tema.", "¿Cómo te sientes hoy?"],
)
def test_no_confunde_acompanar_con_suponer(texto):
    assert "supone_malestar" not in hechos_de_salida(texto, False)


def test_suponer_malestar_solo_se_corrige_si_el_estudiante_no_lo_conto():
    texto = "Entiendo que te sientes triste."
    assert not aplicar_guardia(texto, False).mostrable
    assert aplicar_guardia(texto, False, entrada_negativa=True).mostrable


@pytest.mark.parametrize(
    "texto",
    [
        "Puedo recomendarte algunas técnicas emocionales para sentirte más feliz:\n\n1.",
        "Aquí tienes una técnica del módulo que puede ayudarte: 1.",
        "Te comparto algunos consejos:",
    ],
)
def test_una_lista_prometida_y_cortada_no_se_muestra(texto):
    g = aplicar_guardia(texto, False)
    assert "promete_lista" in g.hechos
    assert not g.mostrable


def test_un_numero_suelto_no_cuenta_como_oracion():
    assert "1." not in aplicar_guardia("Qué bueno que preguntes.\n\n1.", False).texto


# ------------------------------ conversacion --------------------------------


def _conversacion(pasos):
    historial, salidas = (), []
    for mensaje, del_modelo in pasos:
        r = responder(mensaje, NEUTRO, GeneradorFalso(del_modelo), historial=historial)
        historial += (r.turno,)
        salidas.append(r)
    return salidas


def test_la_conversacion_de_la_captura_ya_no_supone_tristeza():
    salidas = _conversacion(
        [
            ("Hola podemos platicas de la paleta de colores de sentimientos",
             "¡Hola! Parece que estás experimentando un poco de tristeza."),
            ("Bien, pero quieor saber que tecnicas emocionales me recomiendas para sentirme mas feliz",
             "Entiendo que te sientes triste. Puedo recomendarte algunas técnicas emocionales para sentirte "
             "más feliz:\n\n1."),
            ("Y que conocimiento me puedes dar tu??", "¡Hola! Parece que estás pasando por un momento difícil."),
        ]
    )
    for r in salidas:
        plano = r.texto.lower()
        assert "triste" not in plano and "difícil" not in plano and "1." not in plano, r.texto
    # La pregunta por tecnicas recibe la ficha de bienestar, sin el modelo.
    pide = salidas[1]
    assert pide.texto.startswith(APERTURA_INFORMATIVA)
    assert FICHAS_INFORMATIVAS[TEMA_BIENESTAR] in pide.texto


def test_si_el_estudiante_esta_triste_serena_si_lo_puede_reconocer():
    r = responder(
        "hoy me fue muy mal y me siento triste",
        AnalizadorFalso("negativo", "tristeza"),
        GeneradorFalso("Entiendo que te sientes triste, gracias por contármelo."),
    )
    assert r.texto.startswith("Entiendo que te sientes triste")


def test_a_media_conversacion_no_vuelve_a_saludar():
    primero = responder("hola", NEUTRO, GeneradorFalso("¡Hola! ¿Cómo estás hoy?"))
    assert primero.texto.startswith("¡Hola!")
    segundo = responder(
        "fui al cine con mis primos",
        NEUTRO,
        GeneradorFalso("¡Hola! Qué buen plan ir al cine con tus primos."),
        historial=(primero.turno,),
    )
    assert segundo.texto.startswith("Qué buen plan"), segundo.texto


def test_si_el_modelo_solo_saluda_no_se_bloquea_ni_avisa():
    primero = responder("hola", NEUTRO, GeneradorFalso("¡Hola! ¿Cómo estás hoy?"))
    r = responder("bien, aquí en la casa", NEUTRO, GeneradorFalso("¡Hola!"), historial=(primero.turno,))
    assert r.tipo == "normal" and r.alerta is None
    assert r.texto
