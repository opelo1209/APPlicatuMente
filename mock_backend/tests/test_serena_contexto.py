"""Pruebas de la preparacion de mensajes para Serena (app/serena_contexto.py).

Lo que se prueba es la "compuerta" que va antes del LLM: que un mensaje de
riesgo nunca llegue al modelo, y que los demas lleguen acompanados de su
polaridad, emociones e intencion para que la respuesta se adapte.

Correr con:  python -m pytest mock_backend/tests/test_serena_contexto.py -v
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.analizador_sentimiento import AnalizadorNoDisponible  # noqa: E402
from app.serena_contexto import (  # noqa: E402
    INTENCION_CONSEJO,
    INTENCION_DESAHOGO,
    INTENCION_INFORMATIVA,
    detectar_intencion,
    preparar_turno,
)
from tests.test_evaluador_diario import AnalizadorFalso  # noqa: E402


class AnalizadorRoto:
    def analizar(self, texto):
        raise AnalizadorNoDisponible("sin modelo")


def test_mensaje_de_crisis_no_llega_al_llm():
    turno = preparar_turno("ya pense en como hacerlo y creo que si lo voy a hacer", AnalizadorFalso("negativo"))
    assert turno.detener_conversacion
    assert turno.mensajes_llm == ()
    assert "800 911 2000" in turno.respuesta_fija
    assert turno.alerta_admin is not None


def test_mensaje_normal_lleva_polaridad_al_prompt():
    turno = preparar_turno("me peleé con mi mejor amiga y me siento fatal", AnalizadorFalso("negativo", "tristeza"))
    assert not turno.detener_conversacion
    sistema = turno.mensajes_llm[0]["content"]
    assert "polaridad: negativo" in sistema
    assert "tristeza" in sistema
    assert turno.mensajes_llm[-1] == {"role": "user", "content": "me peleé con mi mejor amiga y me siento fatal"}


def test_estrategia_cambia_con_la_polaridad():
    neg = preparar_turno("hoy todo me salió mal", AnalizadorFalso("negativo", "tristeza"))
    pos = preparar_turno("hoy me fue súper bien en el torneo", AnalizadorFalso("positivo", "alegria"))
    assert neg.mensajes_llm[0]["content"] != pos.mensajes_llm[0]["content"]
    assert "valida" in neg.mensajes_llm[0]["content"].lower()
    assert "refuerza" in pos.mensajes_llm[0]["content"].lower()


def test_senal_ambigua_pide_explorar_con_cuidado():
    turno = preparar_turno("ya no le veo sentido a nada", AnalizadorFalso("negativo", "tristeza"))
    assert not turno.detener_conversacion
    assert "explora con cuidado" in turno.mensajes_llm[0]["content"].lower()
    assert turno.mostrar_lineas_ayuda


def test_si_el_analizador_falla_igual_revisa_riesgo():
    turno = preparar_turno("kiero morirme", AnalizadorRoto())
    assert turno.detener_conversacion


def test_si_el_analizador_falla_el_prompt_lo_dice():
    turno = preparar_turno("que es la ansiedad", AnalizadorRoto())
    assert "polaridad: desconocida" in turno.mensajes_llm[0]["content"]


def test_pregunta_informativa_no_se_trata_como_emocion():
    # Hallazgo con pysentimiento real: "¿qué es la ansiedad?" sale negativo
    # (62 %) porque el TEMA es negativo, no la persona. Serena debe
    # responder la pregunta, no "validar una emocion" que nadie expreso.
    turno = preparar_turno("¿Qué es la ansiedad?", AnalizadorFalso("negativo", "miedo", prob=0.62))
    sistema = turno.mensajes_llm[0]["content"].lower()
    assert "responde la pregunta" in sistema
    assert "valida la emoción" not in sistema


def test_detectar_intencion():
    assert detectar_intencion("¿Qué es la ansiedad?") == INTENCION_INFORMATIVA
    assert detectar_intencion("que hago si no puedo dormir") == INTENCION_CONSEJO
    assert detectar_intencion("hoy me sentí muy solo en la escuela") == INTENCION_DESAHOGO


def test_no_se_mandan_datos_personales_al_modelo():
    turno = preparar_turno("hola", AnalizadorFalso(), nombre_estudiante="Ana", curp="AAAA000000MDFXXX00")
    contenido = " ".join(m["content"] for m in turno.mensajes_llm)
    assert "Ana" not in contenido
    assert "AAAA000000MDFXXX00" not in contenido
