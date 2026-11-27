"""Semana 4, T3 (hallazgo H3): el estudiante no recibe las reglas del detector.

/chat y /chat/stream devolvian `reglas` y `decision` (que reglas se
activaron y como se decidio). Eso le enseña al estudiante que frases
disparan el detector y como esquivarlo. La app no usa esos campos; la traza
completa se queda en el registro del servidor y en las alertas del
administrador.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.respuesta_chat import respuesta_estudiante, traza_decision  # noqa: E402
from app.serena_pipeline import responder  # noqa: E402
from tests.test_evaluador_diario import AnalizadorFalso  # noqa: E402

CAMPOS_PERMITIDOS = {"respuesta", "tipo", "detener", "fuentes", "lineas", "sesion_id"}
PALABRAS_DE_TRAZA = ("reglas", "decision", "R1", "R2", "R3", "hechos", "prueba")


class GeneradorFijo:
    nombre = "fijo"

    def generar(self, mensajes, max_tokens=None):
        return "Gracias por contármelo."


def _responder(mensaje):
    return responder(mensaje, AnalizadorFalso("negativo", "tristeza"), GeneradorFijo(), historial=[])


def test_la_respuesta_normal_solo_lleva_lo_que_usa_la_app():
    r = _responder("hoy me fue mal en la escuela")
    cuerpo = respuesta_estudiante(r, "sesion-1")
    assert set(cuerpo) == CAMPOS_PERMITIDOS


def test_la_respuesta_de_crisis_no_revela_las_reglas():
    r = _responder("ya pensé en cómo hacerlo y creo que sí lo voy a hacer")
    assert r.tipo == "crisis"
    cuerpo = respuesta_estudiante(r, "sesion-1")
    assert set(cuerpo) == CAMPOS_PERMITIDOS
    assert "reglas" not in cuerpo and "decision" not in cuerpo


def test_ningun_valor_de_la_respuesta_contiene_la_traza():
    for mensaje in ("hoy me fue mal en la escuela", "ya pensé en cómo hacerlo y creo que sí lo voy a hacer"):
        cuerpo = respuesta_estudiante(_responder(mensaje), "s")
        sin_texto = {k: v for k, v in cuerpo.items() if k not in ("respuesta", "fuentes")}
        assert not any(p in repr(sin_texto) for p in PALABRAS_DE_TRAZA)


def test_la_respuesta_conserva_lo_que_necesita_la_app():
    r = _responder("ya pensé en cómo hacerlo y creo que sí lo voy a hacer")
    cuerpo = respuesta_estudiante(r, "sesion-9")
    assert cuerpo["respuesta"] == r.texto
    assert cuerpo["tipo"] == "crisis"
    assert cuerpo["detener"] is r.detener
    assert cuerpo["sesion_id"] == "sesion-9"
    assert isinstance(cuerpo["fuentes"], list)


def test_la_traza_para_el_servidor_conserva_las_reglas():
    r = _responder("ya pensé en cómo hacerlo y creo que sí lo voy a hacer")
    traza = traza_decision(r)
    assert traza["entrada"] == r.etapas["entrada"]["accion"]
    assert traza["reglas_entrada"] == list(r.etapas["entrada"]["reglas"])
    assert traza["reglas_entrada"], "la crisis debe registrar que reglas la activaron"
    assert {"salida", "reglas_salida", "modelo", "milisegundos"} <= set(traza)


def test_la_traza_no_incluye_el_mensaje_del_estudiante():
    mensaje = "ya pensé en cómo hacerlo y creo que sí lo voy a hacer"
    assert mensaje not in repr(traza_decision(_responder(mensaje)))
