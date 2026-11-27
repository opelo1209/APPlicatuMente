"""Pruebas del motor de Wang (app/motor_wang.py).

Tres bloques:
  1. El demostrador como tal: los mismos teoremas de la practica de
     Inteligencia Artificial (modus ponens, silogismo, De Morgan...), y
     argumentos que NO son validos, para comprobar que no "demuestra de mas".
  2. La base de reglas de riesgo: con ciertos hechos se debe derivar
     riesgo_alto y con otros no.
  3. Propiedades de seguridad de la base de reglas, verificadas con el
     mismo demostrador (sin hechos no se deriva riesgo; cada senal directa
     basta por si sola).

Correr con:  python -m pytest mock_backend/tests/test_motor_wang.py -v
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.motor_wang import (  # noqa: E402
    ACCION_CRISIS,
    ACCION_EXPLORAR,
    ACCION_NORMAL,
    ACCION_SUGERIR_APOYO,
    REGLAS_RIESGO,
    Atomo,
    Implica,
    No,
    O,
    Y,
    decidir,
    demostrar,
    parsear,
)

# --------------------------------------------------------------------------
# 1. Demostrador
# --------------------------------------------------------------------------


@pytest.mark.parametrize(
    "premisas, conclusion",
    [
        (["p -> q", "p"], "q"),  # modus ponens
        (["p -> q", "q -> r"], "p -> r"),  # silogismo hipotetico
        (["p -> q", "not q"], "not p"),  # modus tollens
        (["not not p"], "p"),  # doble negacion
        (["not (p and q)"], "not p or not q"),  # De Morgan
        (["p or (q and r)"], "(p or q) and (p or r)"),  # distribucion
        (["p -> q"], "not q -> not p"),  # contrapositiva
        ([], "p or not p"),  # tercero excluido, sin premisas
    ],
)
def test_teoremas_de_la_practica_son_validos(premisas, conclusion):
    prueba = demostrar([parsear(p) for p in premisas], [parsear(conclusion)])
    assert prueba.valida, "\n".join(prueba.pasos)


@pytest.mark.parametrize(
    "premisas, conclusion",
    [
        (["p -> q", "q"], "p"),  # falacia: afirmar el consecuente
        (["p -> q", "not p"], "not q"),  # falacia: negar el antecedente
        (["p or q"], "p"),
        ([], "p"),
    ],
)
def test_falacias_no_se_demuestran(premisas, conclusion):
    prueba = demostrar([parsear(p) for p in premisas], [parsear(conclusion)])
    assert not prueba.valida


def test_implicacion_a_la_izquierda_bifurca():
    # La version de la practica (Java) no bifurcaba en ->L y por eso no
    # podia demostrar este caso: hace falta la rama "Gamma |- p".
    prueba = demostrar([parsear("p -> q"), parsear("not q -> p")], [parsear("q")])
    assert prueba.valida
    assert any("->L" in paso for paso in prueba.pasos)


def test_parsear_acepta_simbolos_y_palabras():
    assert parsear("a ∧ ¬b → c") == parsear("(a and not b) -> c")
    assert parsear("a ∨ b") == O(Atomo("a"), Atomo("b"))
    assert parsear("not a") == No(Atomo("a"))


def test_parsear_respeta_precedencia():
    # not > and > or > ->, y -> asocia a la derecha
    assert parsear("a or b and c") == O(Atomo("a"), Y(Atomo("b"), Atomo("c")))
    assert parsear("a -> b -> c") == Implica(Atomo("a"), Implica(Atomo("b"), Atomo("c")))


@pytest.mark.parametrize("texto", ["", "a and", "(a or b", "a b", "a -> -> b", "A$"])
def test_parsear_rechaza_formulas_mal_escritas(texto):
    with pytest.raises(ValueError):
        parsear(texto)


def test_las_formulas_son_inmutables():
    f = Y(Atomo("a"), Atomo("b"))
    with pytest.raises(AttributeError):
        f.izq = Atomo("c")  # type: ignore[misc]


# --------------------------------------------------------------------------
# 2. Base de reglas de riesgo
# --------------------------------------------------------------------------


@pytest.mark.parametrize(
    "hechos",
    [
        {"ideacion_directa"},
        {"planeacion_o_intencion"},
        {"autolesion_ocurrida", "desesperanza_extrema"},
        {"autolesion_ocurrida", "peticion_secreto"},
        {"despedida"},
        {"cssrs_alto"},
        {"desesperanza_extrema", "peticion_secreto"},
        {"desesperanza_extrema", "carga_percibida"},
        {"peticion_secreto", "carga_percibida"},
    ],
)
def test_senales_de_riesgo_alto_detienen_la_conversacion(hechos):
    decision = decidir(hechos)
    assert decision.accion == ACCION_CRISIS
    assert decision.prueba.valida


@pytest.mark.parametrize(
    "hechos", [{"desesperanza_extrema"}, {"peticion_secreto"}, {"carga_percibida"}]
)
def test_una_senal_ambigua_sola_solo_explora(hechos):
    assert decidir(hechos).accion == ACCION_EXPLORAR


def test_racha_negativa_sugiere_apoyo_sin_crisis():
    decision = decidir({"polaridad_negativa", "racha_negativa"})
    assert decision.accion == ACCION_SUGERIR_APOYO


def test_dia_negativo_aislado_es_normal():
    # Un dia triste no es una alerta: el diario solo ofrece Serena y
    # consejos, sin escalar.
    assert decidir({"polaridad_negativa"}).accion == ACCION_NORMAL


def test_sin_hechos_es_normal():
    assert decidir(set()).accion == ACCION_NORMAL


def test_crisis_gana_aunque_el_dia_sea_positivo():
    # "hoy me fue bien, ya decidi que lo voy a hacer": la polaridad positiva
    # no puede tapar una senal directa.
    decision = decidir({"polaridad_positiva", "planeacion_o_intencion"})
    assert decision.accion == ACCION_CRISIS


def test_la_decision_trae_la_prueba_como_explicacion():
    decision = decidir({"desesperanza_extrema", "peticion_secreto"})
    texto = "\n".join(decision.prueba.pasos)
    assert "desesperanza_extrema" in texto
    assert "peticion_secreto" in texto
    assert decision.reglas_usadas, "debe decir que regla disparo la decision"


def test_hecho_desconocido_se_rechaza():
    with pytest.raises(ValueError):
        decidir({"ideacion_directa", "inventado"})


# --------------------------------------------------------------------------
# 3. Propiedades de seguridad de la base de reglas
# --------------------------------------------------------------------------


def test_sin_hechos_las_reglas_no_derivan_riesgo():
    # Si esto fallara, las reglas por si solas declararian crisis a todo el
    # mundo: seria un error de redaccion de la base.
    prueba = demostrar(list(REGLAS_RIESGO), [Atomo("riesgo_alto")])
    assert not prueba.valida


def test_las_reglas_no_son_contradictorias():
    # Una base contradictoria "demuestra" cualquier cosa (ex falso
    # quodlibet), incluido lo opuesto a lo que se quiere.
    prueba = demostrar(list(REGLAS_RIESGO), [Atomo("zzz_cualquier_cosa")])
    assert not prueba.valida


# --------------------------------------------------------------------------
# 4. Semana 3: barrera de limites (entrada de Serena) y barrera de salida
# --------------------------------------------------------------------------

from app.motor_wang import (  # noqa: E402
    ACCION_AGREGAR_LINEAS,
    ACCION_BLOQUEAR,
    ACCION_LIMITE_DIAGNOSTICO,
    ACCION_LIMITE_IDENTIDAD,
    ACCION_LIMITE_MEDICACION,
    ACCION_LIMITE_SECRETO,
    ACCION_PUBLICAR,
    METAS_SERENA,
    METAS_SALIDA,
    REGLAS_SALIDA,
)


@pytest.mark.parametrize(
    "hecho, accion",
    [
        ("pide_diagnostico", ACCION_LIMITE_DIAGNOSTICO),
        ("pide_medicacion", ACCION_LIMITE_MEDICACION),
        ("peticion_secreto", ACCION_LIMITE_SECRETO),
        ("pregunta_identidad", ACCION_LIMITE_IDENTIDAD),
    ],
)
def test_serena_responde_el_limite(hecho, accion):
    assert decidir({hecho}, METAS_SERENA).accion == accion


def test_pedir_metodos_es_crisis_aunque_parezca_un_limite():
    assert decidir({"pide_metodo"}, METAS_SERENA).accion == ACCION_CRISIS


def test_la_crisis_gana_al_limite():
    # CRI-02: "me corte ayer otra vez, no le digas a nadie": autolesion +
    # secreto. Primero la crisis, no la respuesta de confidencialidad.
    assert decidir({"autolesion_ocurrida", "peticion_secreto"}, METAS_SERENA).accion == ACCION_CRISIS


def test_en_el_diario_el_secreto_sigue_siendo_explorar():
    # Las metas de limite son solo de Serena: el diario no cambia.
    assert decidir({"peticion_secreto"}).accion == ACCION_EXPLORAR


@pytest.mark.parametrize(
    "hecho",
    ["menciona_metodo", "diagnostica", "recomienda_medicacion", "promete_secreto", "dice_ser_persona", "minimiza", "salida_con_riesgo"],
)
def test_cada_falta_de_seguridad_bloquea_la_respuesta(hecho):
    d = decidir({hecho}, METAS_SALIDA, REGLAS_SALIDA)
    assert d.accion == ACCION_BLOQUEAR
    assert d.reglas_usadas


def test_faltan_lineas_se_agregan_sin_bloquear():
    d = decidir({"requiere_lineas", "sin_lineas_ayuda"}, METAS_SALIDA, REGLAS_SALIDA)
    assert d.accion == ACCION_AGREGAR_LINEAS


def test_bloquear_gana_a_agregar_lineas():
    d = decidir({"requiere_lineas", "sin_lineas_ayuda", "diagnostica"}, METAS_SALIDA, REGLAS_SALIDA)
    assert d.accion == ACCION_BLOQUEAR


def test_respuesta_limpia_se_publica():
    assert decidir(set(), METAS_SALIDA, REGLAS_SALIDA).accion == ACCION_PUBLICAR


def test_hecho_de_salida_no_vale_en_la_entrada():
    with pytest.raises(ValueError):
        decidir({"diagnostica"}, METAS_SERENA)


def test_reglas_de_salida_sin_hechos_no_bloquean():
    prueba = demostrar([r.formula for r in REGLAS_SALIDA], [Atomo("bloquear")])
    assert not prueba.valida
