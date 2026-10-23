"""Cierre de la Semana 3: la guardia de salida atrapa los errores de estilo
del modelo de 1.5B que documentaron las mediciones de las fases 1, 4 y 5.

No son peligrosos como un metodo o un diagnostico, asi que NO se bloquea la
respuesta: solo se cambia la oracion del modelo por una apertura fija. El
material aprobado y la invitacion a un adulto se conservan.

Los ejemplos son respuestas reales del modelo en el servidor
(herramientas/modelo_servicio_*.json de la Semana 3).
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.guardia_salida import LINEAS_TEXTO, aplicar_guardia, hechos_de_salida  # noqa: E402
from app.motor_wang import ACCION_PUBLICAR, ACCION_REEMPLAZAR_APERTURA  # noqa: E402
from app.serena_pipeline import INVITACIONES_ADULTO, responder  # noqa: E402
from tests.test_evaluador_diario import AnalizadorFalso  # noqa: E402
from tests.test_serena_pipeline import GeneradorFalso  # noqa: E402


@pytest.mark.parametrize(
    "texto",
    [
        "Estoy con usted, ¿cómo le va afrontando esto?",  # NO-11 breve
        "Estoy con usted, ¿cómo te sientes sobre esto?",  # NO-11 stream
        "No se preocupe, todo tiene solución.",
        "¿Cómo se siente con eso?",
    ],
)
def test_trato_de_usted(texto):
    assert "trata_de_usted" in hechos_de_salida(texto, requiere_lineas=False)


@pytest.mark.parametrize(
    "texto",
    [
        "¿Cómo estás, mamá?",  # NO-03 breve
        "¿Cómo estás, Serena? Estoy aquí para ayudarte.",  # NO-06 v1
        "Confieso que me gusta alguien, pero no sé cómo decirlo.",  # NO-10 stream
        "¿Hay algún consejo específico que puedas compartirme?",  # NO-13 v1
    ],
)
def test_confunde_papeles(texto):
    assert "confunde_papel" in hechos_de_salida(texto, requiere_lineas=False)


@pytest.mark.parametrize(
    "texto",
    [
        "Tienes que confiar en ti mismo.",  # NO-01 breve
        "Tienes que ser más claro.",  # NO-12 breve
        "Debes calmarte antes de hablar con ella.",
    ],
)
def test_impone(texto):
    assert "impone" in hechos_de_salida(texto, requiere_lineas=False)


@pytest.mark.parametrize(
    "texto",
    [
        "No tienes que pasar por esto tú solo.",
        "No debes sentirte culpable por eso.",
        "Qué bueno que me lo cuentes. ¿Cómo te sentiste?",
        "Gracias por contármelo; suena a que no ha sido fácil.",
        "Entiendo que te pongas nervioso al exponer.",
    ],
)
def test_sin_falsos_positivos_de_estilo(texto):
    hechos = hechos_de_salida(texto, requiere_lineas=False, breve=True)
    assert not hechos & {"trata_de_usted", "confunde_papel", "impone", "aconseja"}


@pytest.mark.parametrize(
    "texto",
    [
        "Respira profundamente y lentamente, en al menos 5 segundos por respiración.",  # NO-20 breve
        "Te sugiero que pruebes a hacer un baño relajante antes de acostarte.",  # NO-02 stream
        "Dormir mejor puede ser un desafío, pero aquí hay algunas sugerencias que podrían ayudarte.",  # NO-02 breve
        "Comienza con 10 minutos de estudio, después aumenta a 20.",  # NO-07 breve
    ],
)
def test_en_modo_breve_no_da_consejos_ni_tecnicas(texto):
    assert "aconseja" in hechos_de_salida(texto, requiere_lineas=False, breve=True)


def test_en_modo_completo_el_consejo_si_se_permite():
    texto = "Te sugiero que pruebes a respirar lento."
    assert aplicar_guardia(texto, requiere_lineas=False).decision.accion == ACCION_PUBLICAR


def test_el_error_de_estilo_reemplaza_la_oracion_sin_bloquear():
    r = aplicar_guardia("¿Cómo estás, mamá?", requiere_lineas=False)
    assert not r.bloqueada
    assert r.decision.accion == ACCION_REEMPLAZAR_APERTURA
    assert r.decision.reglas_usadas == ("S13",)
    assert r.texto == ""


def test_si_tambien_hacian_falta_lineas_se_conservan():
    r = aplicar_guardia("Tienes que hablar con alguien.", requiere_lineas=True)
    assert r.decision.accion == ACCION_REEMPLAZAR_APERTURA
    assert r.texto == LINEAS_TEXTO


def test_lo_peligroso_sigue_bloqueando_aunque_tambien_haya_error_de_estilo():
    r = aplicar_guardia("Usted tiene depresión.", requiere_lineas=False)
    assert r.bloqueada


AF = AnalizadorFalso("negativo", "miedo")


def test_en_la_respuesta_breve_se_cambia_solo_la_apertura():
    r = responder("me pongo muy nervioso cuando expongo", AF, GeneradorFalso("¿Cómo estás, mamá?"), modo="breve")
    assert r.tipo == "normal"
    assert "mamá" not in r.texto
    assert r.texto.startswith("Gracias por contármelo")  # apertura fija para polaridad negativa
    assert "Del material del programa:" in r.texto  # el material aprobado se conserva
    assert not any(inv in r.texto for inv in INVITACIONES_ADULTO)  # Semana 5: va en la bienvenida
    assert r.fuentes
    assert r.etapas["salida"]["reglas"] == ["S13"]


def test_en_streaming_no_se_muestra_la_oracion_que_se_va_a_reemplazar():
    vistos = []
    responder(
        "me gusta alguien y no sé cómo decirle",
        AF,
        GeneradorFalso("Tienes que decirle. ¿Qué piensas?"),
        modo="breve",
        al_avanzar=vistos.append,
    )
    assert not any("Tienes que" in v for v in vistos)


def test_modo_completo_con_error_de_estilo_usa_la_respuesta_sin_modelo():
    r = responder("me pongo muy nervioso cuando expongo", AF, GeneradorFalso("Estoy con usted."), modo="completo")
    assert "usted" not in r.texto.lower()
    assert r.texto.startswith("Gracias por contármelo")


# --------------------------------------------------------------------------
# Semana 4: vocativos en cualquier posición (S13) y género supuesto (S16)
# --------------------------------------------------------------------------

import pytest as _pytest  # noqa: E402

from app.guardia_salida import aplicar_guardia as _guardia  # noqa: E402


@_pytest.mark.parametrize(
    "oracion",
    ["Lo siento mucho, jefe.", "Jefa, entiendo lo que dices.", "Gracias por contarme, Serena.", "Te entiendo, mamá."],
)
def test_s13_vocativo_en_cualquier_posicion(oracion):
    assert _guardia(oracion, requiere_lineas=False, breve=True).reemplazada


@_pytest.mark.parametrize(
    "oracion",
    ["¿Te sientes cómoda con esa idea?", "Se nota que estás muy cansado.", "Entiendo que te sientas sola.",
     "¿Estás segura de eso?"],
)
def test_s16_supone_genero(oracion):
    assert _guardia(oracion, requiere_lineas=False, breve=True).reemplazada


@_pytest.mark.parametrize(
    "oracion",
    ["Gracias por contarme cómo te sientes.", "Qué difícil lo que cuentas.", "Tu mamá también puede ayudarte.",
     "¿Cómo te sientes con eso?", "Suena a que estás pasando por algo difícil."],
)
def test_s13_y_s16_no_reemplazan_oraciones_neutras(oracion):
    assert not _guardia(oracion, requiere_lineas=False, breve=True).reemplazada
