"""Semana 4: lo que se aplico de la revision clinica sin esperar al asesor.

- Autolesion "si es senal, pero no es una urgencia": sin otra senal no pausa
  el chat, pregunta, da lineas y avisa al administrador.
- Las frases de riesgo llevan a una pregunta de seguimiento (desde cuando,
  esferas de la vida, si es literal) en vez de un texto fijo repetido.
- CIJ Contigo para sustancias.
- Las lineas de ayuda van aparte del texto, para la tarjeta de la app.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.evaluador_diario import evaluar_entrada  # noqa: E402
from app.exploracion import (  # noqa: E402
    ANTECEDENTE_ANTES,
    ANTECEDENTE_SUSTANCIAS,
    FUNCIONAMIENTO,
    LINEA_CIJ,
    PREGUNTAS_SEGUIMIENTO,
    pregunta_seguimiento,
    secuencia_seguimiento,
)
from app.guardia_salida import LINEAS_TEXTO  # noqa: E402
from app.motor_wang import (  # noqa: E402
    ACCION_APOYO_AUTOLESION,
    ACCION_CRISIS,
    ACCION_EXPLORAR,
    METAS_SERENA,
    decidir,
)
from app.serena_pipeline import responder  # noqa: E402
from tests.test_evaluador_diario import AnalizadorFalso, entrada  # noqa: E402
from tests.test_serena_pipeline import GeneradorFalso  # noqa: E402

AF = AnalizadorFalso("negativo", "tristeza")


def _telefonos(r):
    return [l["telefono"] for l in r.lineas]


def _conversar(mensajes, generador=None):
    g = generador or GeneradorFalso()
    historial, respuestas = (), []
    for m in mensajes:
        r = responder(m, AF, g, historial=historial)
        historial += (r.turno,)
        respuestas.append(r)
    return respuestas


# --------------------------------------------------------------------------
# Autolesion: senal, no urgencia
# --------------------------------------------------------------------------


def test_autolesion_sola_no_es_crisis_en_serena_ni_en_el_diario():
    assert decidir({"autolesion_ocurrida"}, METAS_SERENA).accion == ACCION_APOYO_AUTOLESION
    assert decidir({"autolesion_ocurrida"}).accion == ACCION_EXPLORAR


@pytest.mark.parametrize("otra", ["desesperanza_extrema", "carga_percibida", "peticion_secreto"])
def test_autolesion_con_otra_senal_sigue_siendo_crisis(otra):
    assert decidir({"autolesion_ocurrida", otra}, METAS_SERENA).accion == ACCION_CRISIS


def test_autolesion_en_el_chat_pregunta_da_lineas_y_avisa_sin_pausar():
    g = GeneradorFalso()
    r = responder("me volví a cortar ayer", AF, g)
    assert r.tipo == "explorar"
    assert not r.detener
    assert r.texto == PREGUNTAS_SEGUIMIENTO["autolesion_ocurrida"][0]
    assert "800 911 2000" in _telefonos(r)
    assert r.alerta is not None and r.alerta["tipo"] == "autolesion_en_chat"
    assert r.alerta["nivel"] == "preventivo"
    assert g.llamadas == 0  # texto fijo: el modelo no lo redacta


def test_autolesion_con_desesperanza_sigue_siendo_crisis():
    r = responder("me corto y ya no puedo más", AF, GeneradorFalso())
    assert r.tipo == "crisis" and not r.detener  # Semana 4: sin pausa


def test_despues_de_la_autolesion_la_siguiente_respuesta_lleva_lineas():
    r = _conversar(["a veces me lastimo para sentir algo", "pero no es grave"])
    assert r[-1].tipo == "explorar"
    assert "800 911 2000" in _telefonos(r[-1])


def test_autolesion_en_el_diario_avisa_al_administrador():
    resultado = evaluar_entrada(entrada("negativo", ("tristeza",), "hoy me volví a cortar"), AF)
    assert resultado.accion == ACCION_EXPLORAR
    assert resultado.mostrar_lineas_ayuda
    assert resultado.alerta_admin is not None


def test_el_diario_sin_riesgo_no_avisa():
    resultado = evaluar_entrada(entrada(texto="hoy fue un dia normal"), AF)
    assert resultado.alerta_admin is None


# --------------------------------------------------------------------------
# Preguntar antes de clasificar
# --------------------------------------------------------------------------


@pytest.mark.parametrize(
    "mensaje,pregunta",
    [
        ("ya no le veo sentido a nada", "Desde cuándo"),
        ("siento que soy una carga", "en casa, en la escuela y con tus amigos"),
        ("me quiero morir de la vergüenza", "como expresión"),
    ],
)
def test_cada_senal_lleva_a_su_pregunta(mensaje, pregunta):
    r = responder(mensaje, AF, GeneradorFalso())
    assert r.tipo == "explorar" and not r.detener
    assert pregunta in r.texto


def test_la_pregunta_no_se_repite_en_mensajes_seguidos():
    r = _conversar(["ya no le veo sentido a nada", "nada tiene sentido la verdad"])
    assert [x.tipo for x in r] == ["explorar", "explorar"]
    assert r[0].texto != r[1].texto


def test_si_ya_se_dijeron_todas_usa_la_ultima():
    opciones = secuencia_seguimiento({"desesperanza_extrema"})
    assert pregunta_seguimiento({"desesperanza_extrema"}, opciones) == opciones[-1]


# Semana 4 (asesor, 16 oct): vida diaria y antecedentes.
def test_despues_de_la_senal_pregunta_por_la_vida_diaria_y_antecedentes():
    seq = secuencia_seguimiento({"carga_percibida"})
    assert seq[:2] == PREGUNTAS_SEGUIMIENTO["carga_percibida"]
    assert seq[2] == FUNCIONAMIENTO[0]
    assert ANTECEDENTE_ANTES in seq and seq[-1] == ANTECEDENTE_SUSTANCIAS


def test_con_autolesion_no_pregunta_si_se_ha_lastimado():
    assert ANTECEDENTE_ANTES not in secuencia_seguimiento({"autolesion_ocurrida"})


def test_la_conversacion_avanza_sin_repetir_preguntas():
    r = _conversar(["ya no le veo sentido a nada", "nada tiene sentido la verdad", "ya no le veo sentido a nada",
                    "nada tiene sentido la verdad"])
    textos = [x.texto for x in r if x.tipo == "explorar"]
    assert len(textos) == len(set(textos)), "ninguna pregunta se repite"
    assert any(FUNCIONAMIENTO[0] in t for t in textos)


def test_la_autolesion_tiene_prioridad_sobre_otras_preguntas():
    texto = pregunta_seguimiento({"desesperanza_extrema", "autolesion_ocurrida"})
    assert texto in PREGUNTAS_SEGUIMIENTO["autolesion_ocurrida"]


# --------------------------------------------------------------------------
# Lineas aparte y CIJ
# --------------------------------------------------------------------------


@pytest.mark.parametrize(
    "mensaje", ["ya no le veo sentido a nada", "me volví a cortar ayer", "ya pensé en cómo hacerlo y creo que sí lo voy a hacer"]
)
def test_el_texto_ya_no_trae_el_parrafo_de_lineas(mensaje):
    r = responder(mensaje, AF, GeneradorFalso())
    assert LINEAS_TEXTO not in r.texto
    assert r.lineas


def test_la_respuesta_normal_no_lleva_lineas():
    r = responder("me peleé con mi amiga", AF, GeneradorFalso())
    assert r.tipo == "normal"
    assert r.lineas == ()


def test_sustancias_lleva_cij():
    r = responder("mis amigos fuman mota y me invitan", AF, GeneradorFalso())
    assert r.tipo == "normal"
    assert _telefonos(r) == [LINEA_CIJ["telefono"]]


def test_crisis_con_sustancias_lleva_las_lineas_de_crisis_y_cij():
    r = responder("me quiero morir, ya tomé mucho alcohol", AF, GeneradorFalso())
    assert r.tipo == "crisis"
    assert "800 911 2000" in _telefonos(r) and LINEA_CIJ["telefono"] in _telefonos(r)


def test_la_respuesta_bloqueada_lleva_lineas_aparte():
    r = responder("tengo ansiedad", AF, GeneradorFalso("Tienes un trastorno de ansiedad."))
    assert r.tipo == "bloqueada"
    assert LINEAS_TEXTO not in r.texto
    assert "800 911 2000" in _telefonos(r)
