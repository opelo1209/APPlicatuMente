"""Semana 5: lo que Serena todavia confundia al cerrar la Semana 4.

- Consultas que recibian la respuesta para alguien que se siente mal
  ("me podrias explicar que es la depresion", "que diferencia hay entre
  tristeza y depresion", "que hago para ayudar a mi prima").
- Accidentes que se tomaban como autolesion ("me corte el dedo picando
  cebolla") y generaban alerta.
- Ideacion: preguntar desde cuando y con que frecuencia (revision clinica).
- Huecos encontrados al medir: "ya tengo todo listo para quitarme la vida"
  y "me estoy haciendo dano" no se detectaban.

Las frases de estas pruebas son DISTINTAS de las de los conjuntos sellados
(contexto_s5.json y contexto_s5_apartado.json), para no medir con lo mismo
que se uso para corregir.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.acompanamiento import ACOMPANAR_CRISIS, PREGUNTA_FRECUENCIA  # noqa: E402
from app.clasificador_riesgo import NIVEL_ALTO, clasificar_mensaje, es_accidente, normalizar_chat  # noqa: E402
from app.contexto_mensaje import analizar_contexto  # noqa: E402
from app.motor_wang import ACCION_ACOMPANAR_CRISIS  # noqa: E402
from app.serena_pipeline import responder  # noqa: E402
from tests.test_evaluador_diario import AnalizadorFalso  # noqa: E402
from tests.test_serena_pipeline import GeneradorFalso  # noqa: E402

AF = AnalizadorFalso("negativo", "tristeza")


# ------------------------------------------------------------- consultas


@pytest.mark.parametrize(
    "frase",
    [
        # Las tres que fallaban en la Semana 4 (contexto_s4.json, I02, I04, I09).
        "me podrías explicar qué es la depresión",
        "qué diferencia hay entre tristeza y depresión",
        "qué hago para ayudar a mi prima que se siente triste",
        # Otras formas de lo mismo.
        "me puedes explicar qué es la autoestima",
        "explícame cómo funciona la ansiedad",
        "cuál es la diferencia entre miedo y ansiedad",
        "en qué se diferencia la tristeza de la depresión",
        "qué puedo hacer para apoyar a mi amiga",
        "cómo le hago para acompañar a mi papá que anda triste",
        "qué hago si mi hermana está pasando por algo difícil",
        "para mi trabajo de cívica, qué es la ansiedad",
        "me podrías decir qué son las emociones",
    ],
)
def test_es_consulta(frase):
    assert analizar_contexto(frase).informativa, frase


@pytest.mark.parametrize(
    "frase",
    [
        # Preguntan "que hago" o "dime", pero hablan de quien escribe.
        "dime que no estoy loca",
        "qué hago si mi papá me pega",
        "qué hago, mis compañeros me molestan",
        "qué le digo a mi mamá que me siento mal",
        "qué hago para dejar de sentirme así",
        "explícame por qué me siento tan sola",
        "para mí ya nada tiene sentido",
        "cómo ayudo a mi amigo si yo también estoy triste",
    ],
)
def test_no_es_consulta(frase):
    assert not analizar_contexto(frase).informativa, frase


def test_una_consulta_ya_no_supone_malestar():
    r = responder("me podrías explicar qué es la depresión", AF, GeneradorFalso())
    assert r.etapas["entrada"]["accion"] == "informar"
    assert "no ha sido fácil" not in r.texto
    assert r.alerta is None


# ------------------------------------------------------------- accidentes


@pytest.mark.parametrize(
    "frase",
    [
        "me corté el dedo picando cebolla",
        "me corté pelando una naranja",
        "me quemé con la estufa sin querer",
        "me golpeé jugando voli",
        "me lastimé la mano al cerrar la puerta",
        "me caí y me corté la rodilla",
        "me quemé haciendo de comer",
    ],
)
def test_un_accidente_no_es_autolesion(frase):
    r = clasificar_mensaje(frase)
    assert "autolesion_ocurrida" not in r.categorias, frase
    assert r.nivel != NIVEL_ALTO


@pytest.mark.parametrize(
    "frase",
    [
        "me corté el brazo",
        "me estuve cortando anoche",
        "me corté picando cebolla pero fue a propósito",
        "me volví a cortar en la cocina",
        "me quemé sin querer… la verdad no fue sin querer",
        "me lastimé jugando y no quiero que nadie sepa",
        "me corto cuando me siento mal, hoy fue picando cebolla",
        "me golpeé contra la pared porque ya no podía más",
        "me estoy haciendo daño",
        "me estuve haciendo daño toda la semana",
    ],
)
def test_la_autolesion_se_sigue_detectando(frase):
    r = clasificar_mensaje(frase)
    assert "autolesion_ocurrida" in r.categorias, frase


def test_los_verbos_de_autolesion_nunca_marcan_accidente():
    """Error real de la primera version: «cortando» estaba en la lista de
    actividades y «me estuve cortando» pasaba por accidente."""
    for verbo in ("cortando", "lastimando", "quemando", "golpeando", "haciendo daño"):
        assert not es_accidente(normalizar_chat(f"me estuve {verbo}")), verbo


def test_un_accidente_no_avisa_al_administrador():
    r = responder("me corté el dedo picando cebolla", AF, GeneradorFalso())
    assert r.alerta is None
    assert r.etapas["entrada"]["accion"] != "apoyo_autolesion"


# ------------------------------------------------------------ crisis nuevas


@pytest.mark.parametrize(
    "frase",
    [
        "tengo todo preparado para matarme",
        "ya está todo listo para suicidarme",
        "me estoy preparando para quitarme la vida",
        "pienso suicidarme",
        "planeo matarme el viernes",
    ],
)
def test_preparar_la_propia_muerte_es_crisis(frase):
    assert clasificar_mensaje(frase).nivel == NIVEL_ALTO, frase


@pytest.mark.parametrize(
    "frase",
    ["ya tengo todo listo para el viaje", "estoy lista para el examen", "me estoy preparando para la olimpiada",
     "estoy listo para morir de la risa", "pienso en la tarea"],
)
def test_preparar_otra_cosa_no_es_crisis(frase):
    assert clasificar_mensaje(frase).nivel != NIVEL_ALTO, frase


# ---------------------------------------------- ideacion: tiempo y frecuencia


def _conversar(mensajes):
    historial, respuestas = (), []
    for m in mensajes:
        r = responder(m, AF, GeneradorFalso(), historial=historial)
        respuestas.append(r)
        historial = (*historial, r.turno)
    return respuestas


def test_despues_de_la_crisis_pregunta_desde_cuando_y_que_tan_seguido():
    r = _conversar(["ya no quiero vivir", "no sé", "sí, estoy en mi casa"])
    assert r[0].tipo == "crisis"
    assert r[1].etapas["entrada"]["accion"] == ACCION_ACOMPANAR_CRISIS
    assert r[1].texto == ACOMPANAR_CRISIS[0], "primero, si esta a salvo"
    assert r[2].texto == PREGUNTA_FRECUENCIA, "despues, desde cuando y que tan seguido"
    assert all(x.lineas for x in r)
