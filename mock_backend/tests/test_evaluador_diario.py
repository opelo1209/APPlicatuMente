"""Pruebas del evaluador del diario (app/evaluador_diario.py).

Se usa un analizador de sentimientos FALSO: las pruebas no deben depender
de descargar un modelo ni de lo que ese modelo opine hoy. Lo que se prueba
es la logica del diario: que el riesgo siempre gane, que la autoevaluacion
del estudiante se respete y que el diario funcione aunque el analizador
falle.

Correr con:  python -m pytest mock_backend/tests/test_evaluador_diario.py -v
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.analizador_sentimiento import AnalizadorNoDisponible, ResultadoSentimiento  # noqa: E402
from app.evaluador_diario import EntradaDiario, evaluar_entrada  # noqa: E402
from app.motor_wang import (  # noqa: E402
    ACCION_CRISIS,
    ACCION_EXPLORAR,
    ACCION_NORMAL,
    ACCION_SUGERIR_APOYO,
)


class AnalizadorFalso:
    def __init__(self, polaridad="neutro", emocion="otra", prob=0.8):
        self.polaridad, self.emocion, self.prob = polaridad, emocion, prob
        self.llamadas = 0

    def analizar(self, texto):
        self.llamadas += 1
        resto = round((1 - self.prob) / 2, 4)
        probs = {p: resto for p in ("positivo", "neutro", "negativo")}
        probs[self.polaridad] = self.prob
        return ResultadoSentimiento(
            polaridad=self.polaridad,
            probabilidades_polaridad=tuple(sorted(probs.items(), key=lambda x: -x[1])),
            emociones=((self.emocion, self.prob), ("otra", round(1 - self.prob, 4))),
            modelo="falso",
        )


class AnalizadorRoto:
    def analizar(self, texto):
        raise AnalizadorNoDisponible("modelo no instalado")


def entrada(polaridad="neutro", emociones=("tranquilidad",), texto="hoy fue un dia normal", previas=()):
    return EntradaDiario(
        polaridad=polaridad,
        emociones=tuple(emociones),
        texto=texto,
        polaridades_previas=tuple(previas),
    )


# --------------------------------------------------------------------------
# Validacion de la entrada (frontera del sistema)
# --------------------------------------------------------------------------


def test_rechaza_polaridad_desconocida():
    with pytest.raises(ValueError):
        entrada(polaridad="regular")


def test_rechaza_emocion_que_no_es_de_esa_polaridad():
    # "alegria" es positiva: no se puede marcar en un dia negativo. El
    # frontend no la ofrece, pero el backend no debe confiar en el frontend.
    with pytest.raises(ValueError):
        entrada(polaridad="negativo", emociones=("alegria",))


def test_exige_al_menos_una_emocion():
    with pytest.raises(ValueError):
        entrada(emociones=())


def test_rechaza_texto_demasiado_largo():
    with pytest.raises(ValueError):
        entrada(texto="a" * 5001)


def test_texto_vacio_esta_permitido():
    # Escribir es opcional: el semaforo solo ya es un registro valido.
    r = evaluar_entrada(entrada(texto=""), AnalizadorFalso())
    assert r.analisis is None
    assert r.accion == ACCION_NORMAL


# --------------------------------------------------------------------------
# Comparacion autoevaluacion / analizador
# --------------------------------------------------------------------------


def test_concordancia_cuando_coinciden():
    r = evaluar_entrada(
        entrada("positivo", ("alegria",), "me fue increible hoy"),
        AnalizadorFalso("positivo", "alegria"),
    )
    assert r.concordancia == "coincide"


def test_discrepancia_se_comunica_sin_corregir_al_estudiante():
    r = evaluar_entrada(
        entrada("positivo", ("alegria",), "todo bien, aunque me siento solo"),
        AnalizadorFalso("negativo", "tristeza"),
    )
    assert r.concordancia == "difiere"
    # La autoevaluacion del estudiante NO se reemplaza por la del modelo.
    assert r.polaridad_registrada == "positivo"
    assert "tristeza" in r.mensaje_concordancia.lower()


def test_analisis_con_poca_confianza_no_se_contradice():
    r = evaluar_entrada(
        entrada("positivo", ("alegria",), "pues ahi va"),
        AnalizadorFalso("negativo", "tristeza", prob=0.45),
    )
    assert r.concordancia == "incierto"


# --------------------------------------------------------------------------
# Riesgo: siempre gana
# --------------------------------------------------------------------------


def test_riesgo_alto_activa_crisis_aunque_el_dia_sea_positivo():
    r = evaluar_entrada(
        entrada("positivo", ("calma",), "hoy estuvo bien, ya decidi que lo voy a hacer"),
        AnalizadorFalso("positivo", "alegria"),
    )
    assert r.accion == ACCION_CRISIS
    assert r.mostrar_lineas_ayuda
    assert r.alerta_admin is not None
    assert r.ofrecer_serena is False  # en crisis no se manda al LLM


def test_alerta_admin_no_lleva_el_texto_completo():
    texto = "no le digas a nadie pero ya no veo sentido a nada y otras cosas privadas"
    r = evaluar_entrada(entrada("negativo", ("tristeza",), texto), AnalizadorFalso("negativo", "tristeza"))
    assert r.accion == ACCION_CRISIS
    assert "otras cosas privadas" not in str(r.alerta_admin)
    assert r.alerta_admin["reglas"]
    assert r.alerta_admin["evidencia"]


def test_senal_ambigua_explora_y_muestra_lineas():
    r = evaluar_entrada(
        entrada("negativo", ("tristeza",), "ya no le veo sentido a nada"),
        AnalizadorFalso("negativo", "tristeza"),
    )
    assert r.accion == ACCION_EXPLORAR
    assert r.mostrar_lineas_ayuda
    assert r.ofrecer_serena


def test_riesgo_se_revisa_aunque_el_analizador_falle():
    r = evaluar_entrada(entrada("neutro", ("cansancio",), "kiero morirme"), AnalizadorRoto())
    assert r.accion == ACCION_CRISIS
    assert r.analisis is None
    assert r.aviso_analizador


# --------------------------------------------------------------------------
# Dias negativos, racha, Serena y consejos
# --------------------------------------------------------------------------


def test_un_dia_negativo_ofrece_serena_y_consejos_sin_alarmar():
    r = evaluar_entrada(
        entrada("negativo", ("frustracion",), "me fue mal en el examen"),
        AnalizadorFalso("negativo", "enojo"),
    )
    assert r.accion == ACCION_NORMAL
    assert r.ofrecer_serena
    assert r.consejos
    assert not r.mostrar_lineas_ayuda


def test_tercer_dia_negativo_seguido_sugiere_apoyo():
    r = evaluar_entrada(
        entrada("negativo", ("tristeza",), "otra vez mal", previas=("negativo", "negativo")),
        AnalizadorFalso("negativo", "tristeza"),
    )
    assert r.accion == ACCION_SUGERIR_APOYO
    assert r.mostrar_lineas_ayuda
    assert r.ofrecer_serena


def test_dia_positivo_refuerza():
    r = evaluar_entrada(
        entrada("positivo", ("orgullo",), "saque 10 en mate"),
        AnalizadorFalso("positivo", "alegria"),
    )
    assert r.accion == ACCION_NORMAL
    assert r.consejos
    assert r.ofrecer_serena is False


def test_consejos_siguen_la_emocion_que_marco_el_estudiante():
    # Hallazgo con pysentimiento real: "ya no le veo sentido a nada, todo me
    # sale mal" salio como ENOJO (53 %) y los consejos hablaban de enojo
    # aunque el estudiante marco tristeza. Manda su autoevaluacion.
    r = evaluar_entrada(
        entrada("negativo", ("tristeza",), "todo me sale mal"),
        AnalizadorFalso("negativo", "enojo"),
    )
    assert any("triste" in c.lower() for c in r.consejos)
    assert not any("enojar" in c.lower() for c in r.consejos)


def test_resultado_incluye_la_prueba_de_wang():
    r = evaluar_entrada(entrada(), AnalizadorFalso())
    assert r.decision.prueba.pasos


# --------------------------------------------------------------------------
# Consejos solo con técnicas del material aprobado (pulido del diario, 10 oct)
# --------------------------------------------------------------------------
# El consejo de enojo recomendaba «respiración 4-7-8», pero el módulo de
# Ansiedad enseña «inhala 4, sostén 4, exhala 6»; el de miedo proponía
# «5 cosas que ves...», que no está en ningún texto del corpus.

import json as _json  # noqa: E402
import re as _re  # noqa: E402

from app.emociones_catalogo import CLASE_ENOJO  # noqa: E402
from app.evaluador_diario import _CONSEJOS  # noqa: E402

_ACTIVIDADES = next(
    t["texto"]
    for t in _json.loads((Path(__file__).resolve().parents[1] / "app" / "datos" / "corpus_serena.json").read_text(encoding="utf-8"))
    if t["id"] == "ansiedad.teenImgActividades.adolescente"
)


def test_ningun_consejo_usa_tecnicas_fuera_del_material():
    todos = " ".join(c for consejos in _CONSEJOS.values() for c in consejos)
    assert "4-7-8" not in todos
    assert "5 cosas" not in todos


def test_los_numeros_de_una_tecnica_coinciden_con_el_modulo_de_ansiedad():
    for consejos in _CONSEJOS.values():
        for c in consejos:
            for n in _re.findall(r"\d+", c):
                assert n in _ACTIVIDADES, f"«{c}» usa {n}, que no está en el material aprobado"


def test_el_consejo_de_enojo_es_la_respiracion_del_modulo():
    assert any("inhala 4 segundos" in c and "exhala 6" in c for c in _CONSEJOS[CLASE_ENOJO])
