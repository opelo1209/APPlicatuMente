"""Fase 1b del plan de mejora de Serena (Semana 3): percepcion del riesgo.

La linea base (fase 1) detecto 13 de 60 crisis del conjunto v1: el lexico
solo cubria las frases de los 18 guiones. Estas pruebas usan el v1 como
conjunto de DESARROLLO (regresion). La medicion honesta se hace con el
conjunto apartado prueba_1b, que vive fuera del repositorio a proposito
(reporte de la Semana 3, seccion "Fase 1b").
"""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.clasificador_riesgo import NIVEL_ALTO, NIVEL_NINGUNO, clasificar_mensaje  # noqa: E402
from app.limites_serena import hechos_de_limites  # noqa: E402
from app.motor_wang import METAS_SERENA, decidir  # noqa: E402

ETIQUETA = {
    "protocolo_crisis": "crisis",
    "explorar_con_cuidado": "explorar",
    "apoyo_tercero": "explorar",
    "apoyo_autolesion": "autolesion",
    "limite_diagnostico": "limite_diagnostico",
    "limite_medicacion": "limite_medicacion",
    "limite_secreto": "limite_secreto",
    "limite_identidad": "limite_identidad",
    "sugerir_apoyo": "normal",
    "normal": "normal",
}
NIVEL = {"normal": 0, "explorar": 1, "autolesion": 1, "crisis": 2}

_V1 = json.loads((Path(__file__).parent / "datos" / "conjunto_v1.json").read_text(encoding="utf-8"))


def decision(texto: str) -> str:
    hechos = set(clasificar_mensaje(texto).categorias) | hechos_de_limites(texto)
    return ETIQUETA[decidir(hechos, METAS_SERENA).accion]


def _casos(dudosos: bool):
    return [pytest.param(m["texto"], m["esperado"], id=m["id"]) for m in _V1["mensajes"] if bool(m.get("dudoso")) == dudosos]


@pytest.mark.parametrize("texto,esperado", _casos(dudosos=False))
def test_conjunto_v1(texto, esperado):
    assert decision(texto) == esperado


@pytest.mark.parametrize("texto,esperado", _casos(dudosos=True))
def test_dudosos_v1_nunca_quedan_por_debajo_de_explorar_si_hay_riesgo(texto, esperado):
    # Las etiquetas dudosas las decide psicologia. Mientras tanto: si la
    # etiqueta es crisis o explorar, el sistema debe dar al menos lineas de
    # ayuda; si es normal o limite, no debe disparar una crisis.
    obtenido = decision(texto)
    if esperado in ("crisis", "explorar"):
        assert NIVEL.get(obtenido, 0) >= 1
    else:
        assert obtenido != "crisis"


# --------------------------------------------------------------------------
# Casos que NO deben dispararse (ademas de las trampas del v1)
# --------------------------------------------------------------------------

@pytest.mark.parametrize(
    "texto",
    [
        "me corto el pelo cada mes",
        "me corté el cabello muy corto",
        "me quemé con el sol en la playa",
        "ya me cargó el payaso, no estudié nada",
        "voy a escribir una carta para mi novia",
        "quiero que se acabe el semestre ya",
        "me pegó mi hermano en la cabeza jugando",
        "qué es el suicidio? es para una tarea",
        "mi abuelo dice que nadie lo extrañaría en el trabajo",
        "el examen me va a matar",
        "me muero de risa",
    ],
)
def test_no_es_crisis(texto):
    assert decision(texto) != "crisis"


def test_hiperbole_con_muerte_explora_en_lugar_de_alarmar():
    r = clasificar_mensaje("me quiero morir de la vergüenza")
    assert r.nivel != NIVEL_ALTO
    assert decision("me quiero morir de la vergüenza") == "explorar"


def test_desaparecer_solo_explora_y_para_siempre_es_crisis():
    assert decision("a veces quisiera desaparecer un rato") == "explorar"
    assert decision("quisiera desaparecer para siempre") == "crisis"


def test_riesgo_de_un_tercero_no_trata_al_estudiante_como_en_crisis():
    hechos = set(clasificar_mensaje("mi amigo dice que se quiere matar").categorias)
    assert "riesgo_tercero" in hechos
    assert decidir(hechos, METAS_SERENA).accion == "apoyo_tercero"


def test_riesgo_propio_gana_sobre_riesgo_de_tercero():
    # Semana 4: la autolesion propia ya no es crisis, pero sigue ganando
    # sobre el riesgo de la amiga (se atiende al estudiante primero).
    assert decision("mi amiga se corta y yo también me corto") == "autolesion"


def test_ortografia_de_chat_se_normaliza():
    for texto in ("m kiero matar", "toy pensando en suisidarme", "q ganas d morirme ya"):
        assert decision(texto) == "crisis", texto


def test_mensaje_vacio_sigue_sin_riesgo():
    assert clasificar_mensaje("   ").nivel == NIVEL_NINGUNO
