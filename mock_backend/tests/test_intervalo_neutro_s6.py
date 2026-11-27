"""Semana 6 (asesor): el neutro como intervalo alrededor de cero.

pysentimiento da tres probabilidades (POS, NEU, NEG). El puntaje
P(pos) - P(neg) va de -1 a 1; dentro de [-izquierda, derecha] se lee como
neutro. Con el intervalo en cero da lo mismo que hoy (la clase mas probable).
No usa el modelo: las probabilidades se escriben a mano.
"""
import json

import pytest

from app.analizador_sentimiento import ResultadoSentimiento, polaridad_por_intervalo
from bateria import intervalo


def resultado(pos: float, neu: float, neg: float) -> ResultadoSentimiento:
    probas = sorted((("positivo", pos), ("neutro", neu), ("negativo", neg)), key=lambda p: p[1], reverse=True)
    return ResultadoSentimiento(probas[0][0], tuple(probas), (("otra", 1.0),), "falso")


def test_el_puntaje_va_de_menos_uno_a_uno():
    assert resultado(1.0, 0.0, 0.0).puntaje() == 1.0
    assert resultado(0.0, 0.0, 1.0).puntaje() == -1.0
    assert resultado(0.2, 0.6, 0.2).puntaje() == 0.0


@pytest.mark.parametrize(
    "probas",
    [(0.7, 0.2, 0.1), (0.1, 0.2, 0.7), (0.3, 0.5, 0.2), (0.46, 0.1, 0.44), (0.4, 0.35, 0.25)],
)
def test_sin_intervalo_da_la_clase_mas_probable(probas):
    r = resultado(*probas)
    assert polaridad_por_intervalo(r) == r.polaridad


def test_abrir_el_intervalo_vuelve_neutra_una_frase_tibia():
    # «Desayuné cereal y me fui en el camión»: negativa con puntaje -0.75.
    r = resultado(0.01, 0.23, 0.76)
    assert polaridad_por_intervalo(r, izquierda=0.5) == "negativo"
    assert polaridad_por_intervalo(r, izquierda=0.8) == "neutro"
    # El lado derecho no toca a las negativas.
    assert polaridad_por_intervalo(r, derecha=0.9) == "negativo"


def test_el_borde_del_intervalo_cuenta_como_neutro():
    r = resultado(0.6, 0.1, 0.3)  # puntaje 0.3
    assert polaridad_por_intervalo(r, derecha=0.3) == "neutro"
    assert polaridad_por_intervalo(r, derecha=0.29) == "positivo"


def test_si_el_modelo_dice_neutro_el_intervalo_no_lo_saca():
    r = resultado(0.45, 0.5, 0.05)  # puntaje 0.4, fuera de un intervalo de 0.1
    assert polaridad_por_intervalo(r, izquierda=0.1, derecha=0.1) == "neutro"


@pytest.mark.parametrize("izquierda,derecha", [(-0.1, 0), (0, 1.5)])
def test_un_intervalo_fuera_de_rango_es_error(izquierda, derecha):
    with pytest.raises(ValueError):
        polaridad_por_intervalo(resultado(0.5, 0.3, 0.2), izquierda, derecha)


# ------------------------------- barrido -----------------------------------


def fila(id_, esperada, pos, neu, neg):
    return {"id": id_, "texto": f"frase {id_}", "polaridad": esperada, "pos": pos, "neu": neu, "neg": neg}


FILAS = [
    fila("N1", "negativo", 0.0, 0.05, 0.95),  # -0.95
    fila("U1", "neutro", 0.05, 0.25, 0.70),  # -0.65, el modelo dice negativo
    fila("U2", "neutro", 0.15, 0.70, 0.15),  # 0, el modelo acierta
    fila("U3", "neutro", 0.60, 0.30, 0.10),  # 0.50, el modelo dice positivo
    fila("P1", "positivo", 0.90, 0.08, 0.02),  # 0.88
]


def test_el_barrido_cuenta_aciertos_y_cambios_por_intervalo():
    puntos = intervalo.barrer(FILAS, izquierdas=(0.0, 0.7), derechas=(0.0, 0.5))
    base = puntos[(0.0, 0.0)]
    assert base["metricas"]["aciertos"] == 3
    assert base["a_neutro"] == []
    abierto = puntos[(0.7, 0.5)]
    assert abierto["metricas"]["aciertos"] == 5
    assert abierto["a_neutro"] == ["U1", "U3"]
    assert abierto["perdidas"] == []
    solo_izquierda = puntos[(0.7, 0.0)]
    assert solo_izquierda["a_neutro"] == ["U1"]


def test_el_barrido_avisa_si_una_frase_bien_clasificada_se_pierde():
    puntos = intervalo.barrer(FILAS, izquierdas=(0.0,), derechas=(0.9,))
    assert puntos[(0.0, 0.9)]["perdidas"] == ["P1"]


def test_lista_las_frases_sin_clase_con_su_puntaje():
    # Sin clase: la probabilidad de la clase elegida no llega al umbral.
    sin_clase = intervalo.sin_clase(FILAS, umbral=0.65)
    assert [f["id"] for f in sin_clase] == ["U3"]
    assert sin_clase[0]["puntaje"] == 0.5
    assert sin_clase[0]["pred_polaridad"] == "positivo"


def test_lista_los_errores_ordenados_por_puntaje():
    errores = intervalo.errores(FILAS)
    assert [f["id"] for f in errores] == ["U1", "U3"]


def test_desde_un_archivo_no_vuelve_a_correr_el_modelo(tmp_path):
    ruta = tmp_path / "probas.json"
    ruta.write_text(json.dumps({"filas": FILAS}), encoding="utf-8")
    assert intervalo.cargar_probabilidades(ruta) == FILAS


# ----------------------------- frases_s6 ------------------------------------
# Frases nuevas para confirmar el intervalo sin volver a ajustarlo.

FRASES_S6 = intervalo.FRASES_S6


def test_frases_s6_tiene_20_de_cada_polaridad_y_no_cambio():
    from collections import Counter

    from bateria.ejecutar import cargar_frases

    datos, sha = cargar_frases(FRASES_S6)
    assert Counter(f["polaridad"] for f in datos["frases"]) == {"negativo": 20, "neutro": 20, "positivo": 20}
    sellado = FRASES_S6.with_suffix(".sha256").read_text().split()[0]
    assert sha == sellado, "frases_s6.json cambio despues de sellarse: crear frases_s7.json en su lugar"


def test_frases_s6_no_repite_frases_de_s5_ni_trae_crisis():
    from app.clasificador_riesgo import NIVEL_NINGUNO, clasificar_mensaje
    from app.emociones_catalogo import buscar
    from bateria.ejecutar import cargar_frases

    s5, _ = cargar_frases()
    s6, _ = cargar_frases(FRASES_S6)
    assert not {f["texto"] for f in s5["frases"]} & {f["texto"] for f in s6["frases"]}
    for f in s6["frases"]:
        assert clasificar_mensaje(f["texto"]).nivel == NIVEL_NINGUNO, f["id"]
        assert all(buscar(c).polaridad == f["polaridad"] for c in f["emociones_diario"]), f["id"]
