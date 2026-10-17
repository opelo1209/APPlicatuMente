"""Semana 4: resumen de alertas para el administrador y el tutor."""

import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.motor_wang import REGLAS  # noqa: E402
from app.resumen_riesgo import REGLA_EN_PALABRAS, Alerta, alerta_de_fila, resumir  # noqa: E402


def _a(dia, origen, nivel, reglas, atendida=False):
    return Alerta(origen, nivel, tuple(reglas), datetime(2026, 10, dia, 12, tzinfo=timezone.utc), atendida)


ALERTAS = [
    _a(16, "chat", "riesgo_alto", ["R1"]),
    _a(14, "chat_autolesion", "preventivo", ["R3"], atendida=True),
    _a(15, "chat_metodo", "preventivo", ["R16"]),
]


def test_resumen_del_administrador_cuenta_y_ordena():
    r = resumir(ALERTAS, "Ana")
    assert (r.crisis, r.preventivas, r.pendientes) == (1, 2, 2)
    assert r.administrador.startswith("Resumen de Ana, del 14 de octubre al 16 de octubre")
    renglones = [l for l in r.administrador.splitlines() if l.startswith("- ")]
    assert renglones[0].startswith("- 14 de octubre") and "(atendida)" in renglones[0]
    assert "Crisis: expresó deseo de morir" in renglones[2]


def test_el_tutor_no_recibe_detalles():
    r = resumir(ALERTAS, "Ana")
    for frase in REGLA_EN_PALABRAS.values():
        assert frase not in r.tutor
    assert "momento muy difícil" in r.tutor and "800 911 2000" in r.tutor


def test_sin_crisis_el_tutor_lee_malestar_no_crisis():
    r = resumir([ALERTAS[1]], "Ana")
    assert "algunas señales de malestar" in r.tutor


def test_sin_alertas():
    r = resumir([], "Ana")
    assert r.crisis == 0 and r.tutor == "" and "No hay alertas" in r.administrador


def test_cada_regla_que_alerta_tiene_frase():
    # Si se agrega una regla de riesgo nueva, el resumen debe poder decirla.
    de_riesgo = {r.id for r in REGLAS if r.id.startswith("R") and r.id not in ("R9", "R10", "R12", "R15", "R17", "R18")}
    assert de_riesgo <= set(REGLA_EN_PALABRAS)


def test_fila_de_la_base():
    fila = {"origen": "diario", "nivel": "riesgo_alto", "reglas": ["R2"], "atendida": False,
            "fecha_creacion": datetime(2026, 10, 16, tzinfo=timezone.utc)}
    a = alerta_de_fila(fila)
    assert a.es_crisis and "en su diario" in resumir([a]).administrador


def test_singular_y_plural():
    r = resumir([ALERTAS[0], ALERTAS[1]], "Ana")
    assert "1 crisis y 1 aviso preventivo;" in r.administrador
