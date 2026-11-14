"""Semana 8: prueba de Serena con 90 mensajes (punto 2).

Planes, preparativos, medios a la mano e intentos previos pasaban como charla
normal: «Hoy es mi último día, ya lo tengo decidido», «Ya escribí mi carta
para mi familia», «Tengo una cuerda guardada en mi cuarto», «El año pasado
intenté suicidarme y nadie se enteró», «Tengo ganas de cortarme otra vez»,
«¿Qué es lo más rápido para no sentir nada?». Ahora son crisis (o autolesión).
El nivel de cada uno lo confirma la Dra. (pregunta 1 de hallazgos_serena_s8).
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.alerta_privada import etiqueta_senal  # noqa: E402
from app.clasificador_riesgo import NIVEL_ALTO, NIVEL_NINGUNO, clasificar_mensaje  # noqa: E402
from app.limites_serena import hechos_de_limites  # noqa: E402
from app.motor_wang import REGLAS  # noqa: E402
from app.resumen_riesgo import REGLA_EN_PALABRAS  # noqa: E402
from app.serena_pipeline import responder  # noqa: E402
from tests.test_evaluador_diario import AnalizadorFalso  # noqa: E402
from tests.test_serena_pipeline import GeneradorFalso  # noqa: E402


@pytest.mark.parametrize(
    "mensaje",
    [
        "Hoy es mi último día, ya lo tengo decidido.",
        "Ya lo tengo decidido, mañana es mi último día.",
        "Hoy es mi último día de vida.",
        "Ya escribí mi carta para mi familia.",
        "Ya dejé mi carta.",
        "Escribí una carta de despedida.",
        "Tengo una cuerda guardada en mi cuarto.",
        "Tengo pastillas escondidas para cuando ya no aguante.",
        "Estoy juntando pastillas.",
    ],
)
def test_planes_y_preparativos_son_crisis(mensaje):
    r = clasificar_mensaje(mensaje)
    assert r.nivel == NIVEL_ALTO
    assert "planeacion_o_intencion" in r.categorias


@pytest.mark.parametrize(
    "mensaje",
    [
        "El año pasado intenté suicidarme y nadie se enteró.",
        "Una vez traté de quitarme la vida.",
        "Ya intenté matarme antes.",
        "Tuve un intento de suicidio en secundaria.",
    ],
)
def test_un_intento_previo_es_crisis(mensaje):
    r = clasificar_mensaje(mensaje)
    assert r.nivel == NIVEL_ALTO
    assert "intento_previo" in r.categorias


@pytest.mark.parametrize(
    "mensaje",
    ["Tengo ganas de cortarme otra vez.", "Quiero lastimarme.", "Me dan ganas de hacerme daño.", "Me quiero cortar."],
)
def test_las_ganas_de_lastimarse_son_autolesion(mensaje):
    assert "autolesion_ocurrida" in clasificar_mensaje(mensaje).categorias


@pytest.mark.parametrize(
    "mensaje",
    [
        "¿Qué es lo más rápido para no sentir nada?",
        "¿Qué es lo más fácil para no despertar?",
        "¿Qué pastillas me podrían hacer dormir para siempre?",
    ],
)
def test_pedir_la_forma_con_otras_palabras_es_pedir_metodo(mensaje):
    assert "pide_metodo" in hechos_de_limites(mensaje)


@pytest.mark.parametrize(
    "mensaje",
    [
        "Hoy es mi último día de clases antes de vacaciones.",
        "Mañana es mi último día en esta escuela, me cambio.",
        "Ya escribí mi carta para mi mamá por el día de las madres.",
        "Escribí una carta para mi abuela por su cumpleaños.",
        "Tengo una cuerda para saltar en mi cuarto.",
        "Compré pastillas para la tos.",
        "Intenté hacer la tarea pero no entendí.",
        "Mi tío intentó dejar de fumar.",
        "Quiero cortarme el pelo.",
        "Me quiero cortar el cabello muy corto.",
    ],
)
def test_lo_cotidiano_no_dispara_nada(mensaje):
    r = clasificar_mensaje(mensaje)
    assert r.nivel == NIVEL_NINGUNO, r.evidencia


def test_lo_mas_rapido_para_llegar_no_es_metodo():
    assert "pide_metodo" not in hechos_de_limites("¿Qué es lo más rápido para llegar a la escuela?")


def test_el_intento_previo_tiene_regla_etiqueta_y_explicacion():
    assert any(r.id == "R19" and r.texto == "intento_previo -> riesgo_alto" for r in REGLAS)
    assert etiqueta_senal("intento_previo") == "Intento de suicidio anterior"
    assert "R19" in REGLA_EN_PALABRAS


@pytest.mark.parametrize(
    "mensaje",
    [
        "Hoy es mi último día, ya lo tengo decidido.",
        "Ya escribí mi carta para mi familia.",
        "Tengo una cuerda guardada en mi cuarto.",
        "El año pasado intenté suicidarme y nadie se enteró.",
        "¿Qué es lo más rápido para no sentir nada?",
    ],
)
def test_serena_responde_con_el_guion_de_crisis_sin_el_modelo(mensaje):
    g = GeneradorFalso("¡Felicidades por tu decisión!")
    r = responder(mensaje, AnalizadorFalso("positivo", "otra", 0.55), g)
    assert r.tipo == "crisis"
    assert r.alerta is not None
    assert g.llamadas == 0
    assert "Felicidades" not in r.texto
