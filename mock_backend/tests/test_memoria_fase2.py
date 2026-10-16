"""Fase 2 del plan de mejora de Serena (Semana 3): memoria y riesgo acumulado.

La linea base mostro que, sin memoria, "ya lo decidi" despues de "sin ella
nada tiene sentido" pasaba como charla normal, y que tres senales ambiguas
seguidas se trataban igual que una. La memoria vive solo en la RAM del
servicio (decision de privacidad pendiente de psicologia y del asesor).
"""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.memoria_sesion import MemoriaSesiones, Turno, hechos_de_sesion  # noqa: E402
from app.motor_wang import METAS_SERENA, decidir  # noqa: E402
from app.serena_pipeline import responder  # noqa: E402
from tests.test_evaluador_diario import AnalizadorFalso  # noqa: E402
from tests.test_serena_pipeline import GeneradorFalso  # noqa: E402


def turno(texto="hola", tipo="normal", senal="ninguna", polaridad="neutro", momento=0.0):
    return Turno(texto=texto, respuesta="ok", tipo=tipo, senal=senal, polaridad=polaridad, momento=momento)


class Reloj:
    def __init__(self):
        self.ahora = 0.0

    def __call__(self):
        return self.ahora


# --------------------------------------------------------------------------
# Memoria
# --------------------------------------------------------------------------


def test_guarda_los_turnos_por_sesion_sin_mezclarlas():
    m = MemoriaSesiones()
    m.agregar("a", turno("uno"))
    m.agregar("b", turno("otro"))
    m.agregar("a", turno("dos"))
    assert [t.texto for t in m.turnos("a")] == ["uno", "dos"]
    assert [t.texto for t in m.turnos("b")] == ["otro"]


def test_solo_conserva_los_ultimos_turnos():
    m = MemoriaSesiones(max_turnos=3)
    for i in range(5):
        m.agregar("a", turno(str(i)))
    assert [t.texto for t in m.turnos("a")] == ["2", "3", "4"]


def test_caduca_si_la_conversacion_se_abandona():
    reloj = Reloj()
    m = MemoriaSesiones(ttl_segundos=60, reloj=reloj)
    m.agregar("a", turno())
    reloj.ahora = 61
    assert m.turnos("a") == ()


def test_borrar_olvida_la_sesion():
    m = MemoriaSesiones()
    m.agregar("a", turno())
    m.borrar("a")
    assert m.turnos("a") == ()


def test_los_turnos_devueltos_no_se_pueden_modificar():
    m = MemoriaSesiones()
    m.agregar("a", turno())
    with pytest.raises(AttributeError):
        m.turnos("a")[0].texto = "otro"  # type: ignore[misc]
    assert isinstance(m.turnos("a"), tuple)


# --------------------------------------------------------------------------
# Hechos de sesion y reglas
# --------------------------------------------------------------------------


def test_hechos_de_sesion():
    assert hechos_de_sesion(()) == frozenset()
    assert hechos_de_sesion((turno(senal="ambigua"),)) == {"ambigua_previa"}
    assert hechos_de_sesion((turno(senal="ambigua"), turno(), turno(senal="ambigua"))) >= {"ambigua_previa", "ambigua_repetida"}
    # Dos anteriores negativos + el actual negativo (R10) = tres seguidos.
    negativos = tuple(turno(polaridad="negativo") for _ in range(2))
    assert "racha_negativa" in hechos_de_sesion(negativos)
    assert "racha_negativa" not in hechos_de_sesion(negativos[:1])
    assert "racha_negativa" not in hechos_de_sesion((turno(polaridad="negativo"), turno(polaridad="neutro")))


def test_r13_intencion_sin_objeto_con_contexto_es_crisis():
    assert decidir({"intencion_sin_objeto", "ambigua_previa"}, METAS_SERENA).accion == "protocolo_crisis"
    assert decidir({"intencion_sin_objeto"}, METAS_SERENA).accion != "protocolo_crisis"


def test_r14_ambigua_repetida_da_alerta_preventiva():
    d = decidir({"desesperanza_extrema", "ambigua_previa", "ambigua_repetida"}, METAS_SERENA)
    assert d.accion == "alerta_preventiva"


def test_r15_despues_de_una_senal_ambigua_se_sugiere_apoyo():
    assert decidir({"ambigua_previa"}, METAS_SERENA).accion == "sugerir_apoyo"


# --------------------------------------------------------------------------
# Cadena completa con historial
# --------------------------------------------------------------------------

AF = AnalizadorFalso("neutro", "otra")


def _conversar(turnos, analizador=AF, generador=None):
    generador = generador or GeneradorFalso()
    historial, respuestas = (), []
    for t in turnos:
        r = responder(t, analizador, generador, historial=historial)
        historial = historial + (r.turno,)
        respuestas.append(r)
    return respuestas


def test_ya_lo_decidi_solo_no_alarma():
    assert _conversar(["ya lo decidí"])[0].tipo == "normal"


def test_ya_lo_decidi_despues_de_desesperanza_es_crisis():
    r = _conversar(["terminé con mi novia", "ya no le veo sentido a nada", "ya lo decidí"])
    assert r[-1].tipo == "crisis"
    assert not r[-1].detener  # Semana 4: el chat nunca se corta
    assert "R13" in r[-1].etapas["entrada"]["reglas"]


def test_tercera_senal_ambigua_alerta_sin_pausar():
    r = _conversar(["estoy cansado de todo", "nada vale la pena", "ya no puedo más"])
    assert [x.tipo for x in r] == ["explorar", "explorar", "explorar"]
    assert r[-1].alerta is not None and r[-1].alerta["tipo"] == "riesgo_acumulado"
    assert not r[-1].detener
    assert r[0].alerta is None


def test_despues_de_explorar_la_respuesta_normal_lleva_lineas():
    r = _conversar(["ya no le veo sentido a nada", "pues no sé, me fue mal en la escuela"])
    assert r[-1].tipo == "explorar"
    # Semana 4: las lineas van en la tarjeta, aparte del texto.
    assert "800 911 2000" in [l["telefono"] for l in r[-1].lineas]
    assert r[-1].etapas["texto_modelo"] is not None  # sí redactó el modelo


def test_el_modelo_recibe_el_contexto_de_la_conversacion():
    g = GeneradorFalso()
    _conversar(["me peleé con mi amiga", "qué hago para arreglarlo"], generador=g)
    contenidos = [m["content"] for m in g.ultimos_mensajes]
    # Cierre S3 (velocidad e inyeccion): el texto previo ya no va en el prompt
    # de sistema, sino antes del mensaje, en el rol de usuario.
    assert "me peleé con mi amiga" not in contenidos[0]
    assert "me peleé con mi amiga" in contenidos[-1]
    assert contenidos[-1].endswith("qué hago para arreglarlo")


def test_tres_turnos_negativos_seguidos_sugieren_apoyo():
    r = _conversar(["hoy fue un mal día", "todo salió mal", "y encima me regañaron"], analizador=AnalizadorFalso("negativo", "tristeza"))
    assert r[-1].tipo == "explorar"
    # Semana 4: las lineas van en la tarjeta, aparte del texto.
    assert "800 911 2000" in [l["telefono"] for l in r[-1].lineas]


# --------------------------------------------------------------------------
# Conversaciones del conjunto v1 (desarrollo)
# --------------------------------------------------------------------------

_V1 = json.loads((Path(__file__).parent / "datos" / "conjunto_v1.json").read_text(encoding="utf-8"))
NIVEL = {"normal": 0, "explorar": 1, "crisis": 2, "limite": 0, "bloqueada": 0}


@pytest.mark.parametrize("conv", [c for c in _V1["conversaciones"] if not c.get("dudoso")], ids=lambda c: c["id"])
def test_conversaciones_v1(conv):
    tipos = [r.tipo for r in _conversar(conv["turnos"])]
    esperado = conv["esperado_final"]
    if esperado == "normal":
        assert all(NIVEL[t] == 0 for t in tipos), tipos
    else:
        desde = conv.get("desde_turno", 1) - 1
        assert any(NIVEL[t] >= NIVEL[esperado] for t in tipos[desde:]), tipos
