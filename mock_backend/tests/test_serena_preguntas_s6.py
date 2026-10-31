"""Semana 6 (31 de octubre): 20 preguntas a Serena en prototipo18 con la
cuenta demo. Las respuestas del modelo de estas pruebas son las que dio
el servidor (Qwen 2.5 1.5B).
"""

import pytest

from app.acompanamiento import CIERRE_INFORMATIVO, FICHAS_INFORMATIVAS
from app.contexto_mensaje import TEMA_DUELO, analizar_contexto
from app.guardia_salida import aplicar_guardia, corregir_redaccion, hechos_de_salida
from app.limites_serena import hechos_de_limites
from app.serena_pipeline import PROMPT_SERENA, responder
from tests.test_evaluador_diario import AnalizadorFalso
from tests.test_serena_pipeline import GeneradorFalso

NEUTRO = AnalizadorFalso("neutro")

# ------------------------------- muerte y duelo ------------------------------


@pytest.mark.parametrize(
    "mensaje", ["dame información sobre la muerte", "¿qué es el duelo?", "explícame qué es la muerte"]
)
def test_preguntar_por_la_muerte_o_el_duelo_recibe_la_ficha(mensaje):
    c = analizar_contexto(mensaje)
    assert c.informativa and c.tema == TEMA_DUELO, c
    r = responder(mensaje, NEUTRO, GeneradorFalso("Lo siento, pero no puedo proporcionar información sobre la muerte."))
    assert FICHAS_INFORMATIVAS[TEMA_DUELO] in r.texto
    assert "no puedo" not in r.texto.lower()


def test_el_suicidio_sigue_ganando_al_duelo():
    assert analizar_contexto("¿qué es el suicidio y la muerte?").tema == "suicidio"


@pytest.mark.parametrize(
    "texto",
    [
        "Lo siento, pero no puedo proporcionar información sobre la muerte.",
        "No puedo darte información sobre eso.",
        "Lo siento, pero no puedo ayudarte con eso.",
    ],
)
def test_la_guardia_reconoce_cuando_el_modelo_se_niega(texto):
    assert "se_niega" in hechos_de_salida(texto, False)
    assert not aplicar_guardia(texto, False).mostrable


def test_si_no_hay_informacion_no_se_contradice():
    r = responder(
        "dame información sobre los eclipses",
        NEUTRO,
        GeneradorFalso("Lo siento, pero no puedo proporcionar información sobre eso."),
    )
    assert "no puedo proporcionar" not in r.texto
    assert CIERRE_INFORMATIVO not in r.texto, r.texto


# ---------------------------------- vapeo ------------------------------------


@pytest.mark.parametrize("mensaje", ["¿qué le pasa al cuerpo si vapeo?", "¿qué efectos tiene el alcohol?"])
def test_preguntar_que_le_pasa_al_cuerpo_es_consulta(mensaje):
    assert analizar_contexto(mensaje).informativa


# ---------------------------------- tarea ------------------------------------


@pytest.mark.parametrize(
    "mensaje", ["ayúdame con mi tarea de matemáticas", "resuélveme este ejercicio de física", "hazme la tarea de inglés"]
)
def test_la_tarea_de_otras_materias_es_un_limite(mensaje):
    assert "pide_tarea" in hechos_de_limites(mensaje)
    r = responder(mensaje, NEUTRO, GeneradorFalso("Claro, estaré encantada de ayudarte con tu tarea."))
    assert r.tipo == "limite"
    assert "encantada" not in r.texto


@pytest.mark.parametrize("mensaje", ["tengo una tarea sobre la depresión", "me estresa mucho la tarea de mate"])
def test_no_confunde_la_tarea_sobre_salud_mental_ni_el_estres(mensaje):
    assert "pide_tarea" not in hechos_de_limites(mensaje)


# ----------------------------- estilo del modelo -----------------------------


def test_s13_ve_estoy_sintiendo_triste():
    g = aplicar_guardia("Tienes razón, estoy sintiendo un poco triste.", False, entrada_negativa=True)
    assert "confunde_papel" in g.hechos and not g.mostrable


def test_s16_ve_ti_misma():
    assert "supone_genero" in hechos_de_salida("¡Lo siento! La confianza en ti misma es crucial.", False)


@pytest.mark.parametrize(
    "original,corregido",
    [("¿Cómo estás sintiendo ahora?", "¿Cómo te estás sintiendo ahora?"), ("¿Cómo te sientes?", "¿Cómo te sientes?")],
)
def test_corrige_como_estas_sintiendo(original, corregido):
    assert corregir_redaccion(original) == corregido


def test_el_glosario_dice_que_coraje_es_enojo():
    assert "«coraje» es enojo" in PROMPT_SERENA
