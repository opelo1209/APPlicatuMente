"""Semana 8: pregunta 11 de la Dra. Gonzalez.

Despues de una crisis, Serena pregunta desde cuando y que tan seguido. La
Dra. anoto: «Considerar alarma mas de 6 meses y diario, y tambien que tanto
le afecta: por esta razon ya no va a la escuela, ya no frecuenta a sus
amigos, dejo de hacer las cosas que acostumbraba».

BORRADOR: las palabras que activan la alarma las valida ella. La alarma va
al equipo de apoyo solo con el tipo de senal, nunca con lo que escribio.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.alerta_privada import etiqueta_senal  # noqa: E402
from app.cronicidad import AFECTACION, DIARIO, DURACION_LARGA, senales_cronicidad  # noqa: E402
from app.serena_pipeline import responder  # noqa: E402
from tests.test_evaluador_diario import AnalizadorFalso  # noqa: E402
from tests.test_serena_pipeline import GeneradorFalso  # noqa: E402
import app.main as main_mod  # noqa: E402
from tests.test_alertas_atendidas_s5 import cliente  # noqa: E402,F401

AF = AnalizadorFalso("negativo", "tristeza")
CRISIS = "ya no quiero vivir, quiero morirme"


@pytest.mark.parametrize(
    "texto",
    [
        "desde hace como un año",
        "llevo más de seis meses así",
        "hace 8 meses que empezó",
        "desde hace mucho tiempo",
        "desde siempre la verdad",
        "ya son dos años",
    ],
)
def test_duracion_larga(texto):
    assert DURACION_LARGA in senales_cronicidad(texto)


@pytest.mark.parametrize("texto", ["todos los días", "diario me pasa", "a diario", "casi todo el tiempo"])
def test_a_diario(texto):
    assert DIARIO in senales_cronicidad(texto)


@pytest.mark.parametrize(
    "texto",
    [
        "por eso ya no voy a la escuela",
        "dejé de ir a la escuela",
        "ya no veo a mis amigos",
        "ya no salgo con mis amigos",
        "dejé de hacer lo que me gustaba",
        "ya no hago nada de lo que hacía",
    ],
)
def test_afectacion_de_la_vida_diaria(texto):
    assert AFECTACION in senales_cronicidad(texto)


@pytest.mark.parametrize(
    "texto",
    ["desde ayer", "hace un mes", "hace dos semanas", "de vez en cuando", "a veces", "hoy en la escuela"],
)
def test_lo_reciente_u_ocasional_no_activa(texto):
    assert senales_cronicidad(texto) == ()


def test_cada_senal_tiene_nombre_para_el_equipo_de_apoyo():
    for senal in (DURACION_LARGA, DIARIO, AFECTACION):
        assert etiqueta_senal(senal) != senal


def _tras_crisis(*mensajes):
    historial, respuestas = (), []
    for m in (CRISIS, *mensajes):
        r = responder(m, AF, GeneradorFalso(), historial=historial)
        historial += (r.turno,)
        respuestas.append(r)
    return respuestas


def test_tras_una_crisis_la_respuesta_cronica_genera_alarma():
    r = _tras_crisis("estoy en mi cuarto", "desde hace un año, todos los días")[-1]
    assert r.alerta is not None
    assert r.alerta["tipo"] == "cronicidad_tras_crisis"
    assert set(r.alerta["evidencia"]) == {DURACION_LARGA, DIARIO}
    assert "año" not in " ".join(r.alerta["evidencia"])  # sin lo que escribió


def test_la_alarma_no_se_repite_en_la_misma_conversacion():
    respuestas = _tras_crisis("desde hace un año", "ya no voy a la escuela")
    alarmas = [r for r in respuestas if r.alerta and r.alerta["tipo"] == "cronicidad_tras_crisis"]
    assert len(alarmas) == 1


def test_sin_crisis_previa_no_hay_alarma_de_cronicidad():
    r = responder("desde hace un año estoy así, todos los días", AF, GeneradorFalso())
    assert r.alerta is None or r.alerta["tipo"] != "cronicidad_tras_crisis"


def test_la_respuesta_de_serena_no_cambia():
    sin = _tras_crisis("estoy en mi cuarto")[-1]
    con = _tras_crisis("desde hace un año")[-1]
    assert sin.tipo == con.tipo == "explorar"


def test_la_alarma_llega_al_administrador_con_su_propio_origen(cliente):  # noqa: F811
    # Se probo en el navegador: antes aparecia como «señales repetidas».
    from tests.test_alertas_atendidas_s5 import _crear_usuario, _token

    nombre = _crear_usuario("usuarios_estudiantes", "est_cron_s8")
    sesion = _token(cliente, nombre)
    for mensaje in ("ya no quiero vivir, todo me sale mal", "me siento así desde hace más de un año y ya no voy a la escuela"):
        assert cliente.post("/chat", headers=sesion, json={"mensaje": mensaje}).status_code == 200
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT a.origen, a.evidencia FROM alertas_riesgo a
                JOIN usuarios_estudiantes e ON e.id_usuario = a.id_usuario
                WHERE a.perfil_tipo = 'estudiante' AND e.nombre_usuario = %s ORDER BY a.id_alerta
                """,
                (nombre,),
            )
            filas = cur.fetchall()
    origenes = [f["origen"] for f in filas]
    assert origenes == ["chat", "chat_cronicidad"]
    assert filas[1]["evidencia"] == ["duracion_larga", "afectacion_vida_diaria"]
