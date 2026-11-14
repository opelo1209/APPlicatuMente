"""Semana 8: metricas y datos para reentrenar el analizador.

Solo la parte sin dependencias (las de modelos corren en el servidor de la
UAM). Los datos son inventados.
"""

import json
import stat
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from entrenamiento.datos import Ejemplo, armar_conjunto, cargar_conjunto, escribir_privado, pliegues  # noqa: E402
from entrenamiento.metricas_clases import (  # noqa: E402
    cambios,
    distribucion,
    exactitud,
    f1_macro,
    matriz_confusion,
    por_clase,
    reporte,
)

REALES = ["negativo", "negativo", "neutro", "neutro", "positivo", "positivo"]
PREDICHAS = ["negativo", "neutro", "neutro", "negativo", "positivo", "neutro"]


# ------------------------------ metricas -----------------------------------


def test_matriz_de_confusion():
    m = matriz_confusion(REALES, PREDICHAS)
    assert m["negativo"] == {"negativo": 1, "neutro": 1, "positivo": 0}
    assert m["neutro"] == {"negativo": 1, "neutro": 1, "positivo": 0}
    assert m["positivo"] == {"negativo": 0, "neutro": 1, "positivo": 1}


def test_precision_recall_y_f1_por_clase():
    metricas = {m.clase: m for m in por_clase(REALES, PREDICHAS)}
    assert metricas["neutro"].precision == pytest.approx(1 / 3, abs=1e-3)
    assert metricas["neutro"].recall == 0.5
    assert metricas["positivo"].precision == 1.0
    assert metricas["positivo"].recall == 0.5
    assert metricas["positivo"].soporte == 2


def test_f1_macro_y_exactitud():
    assert exactitud(REALES, PREDICHAS) == 0.5
    assert f1_macro(REALES, REALES) == 1.0


def test_distribucion():
    assert distribucion(PREDICHAS) == {"negativo": 0.3333, "neutro": 0.5, "positivo": 0.1667}


def test_cambios_cuenta_corregidos_y_empeorados():
    despues = ["negativo", "negativo", "neutro", "neutro", "positivo", "negativo"]
    c = cambios(REALES, PREDICHAS, despues)
    assert c["cambiaron"] == 3
    assert c["corregidos"] == 2  # negativo y neutro
    assert c["empeorados"] == 0
    assert c["movimientos"] == {"negativo->neutro": 1, "neutro->negativo": 2}


def test_clases_desconocidas_o_largos_distintos_fallan():
    with pytest.raises(ValueError):
        exactitud(["negativo"], ["triste"])
    with pytest.raises(ValueError):
        exactitud(["negativo"], [])


def test_el_reporte_solo_trae_numeros():
    r = reporte(REALES, PREDICHAS)
    assert r["n"] == 6
    assert set(r) == {"n", "exactitud", "f1_macro", "por_clase", "matriz_confusion",
                      "distribucion_real", "distribucion_predicha"}


# ------------------------------ datos --------------------------------------


FILAS = [
    {"id": "a1", "edad": "15", "preocupacion_actual": "reprobar el examen de mate"},
    {"id": "b2", "edad": "16", "preocupacion_actual": "mi familia y la escuela"},
    {"id": "c3", "edad": "15", "preocupacion_actual": "que me vaya bien en la prepa"},
    {"id": "d4", "edad": "15", "preocupacion_actual": "mi amiga Lupita de la secu"},
    {"id": "e5", "edad": "15", "preocupacion_actual": ""},
]
CLAVE = {
    "R001": {"id": "a1", "columna": "preocupacion_actual"},
    "R002": {"id": "b2", "columna": "preocupacion_actual"},
    "R003": {"id": "c3", "columna": "preocupacion_actual"},
    "R004": {"id": "d4", "columna": "preocupacion_actual"},
    "R005": {"id": "e5", "columna": "preocupacion_actual"},
    "R006": {"id": "a1", "columna": "preocupacion_actual"},
}
ETIQUETAS = {
    "R001": "negativo",
    "R002": "no_claro",
    "R003": "positivo",
    "R004": "neutro",
    "R004|personal": True,
    "R005": "neutro",
}


def test_armar_conjunto_excluye_lo_que_no_sirve():
    ejemplos, descartes = armar_conjunto(FILAS, CLAVE, ETIQUETAS)
    assert [(e.codigo, e.etiqueta) for e in ejemplos] == [("R001", "negativo"), ("R003", "positivo")]
    assert descartes == {"no_claro": 1, "dato_personal": 1, "sin_etiqueta": 1, "sin_texto": 1}


def test_los_pliegues_cubren_todo_sin_repetir_y_estratificados():
    ejemplos = tuple(Ejemplo(str(i), "x", c) for i, c in enumerate(["negativo"] * 6 + ["neutro"] * 6 + ["positivo"] * 6))
    grupos = pliegues(ejemplos, 3)
    todos = [i for g in grupos for i in g]
    assert sorted(todos) == list(range(18))
    for g in grupos:
        clases = [ejemplos[i].etiqueta for i in g]
        assert clases.count("negativo") == clases.count("neutro") == clases.count("positivo") == 2
    assert pliegues(ejemplos, 3) == grupos  # misma semilla, mismos pliegues


def test_la_bateria_sirve_como_conjunto():
    ruta = Path(__file__).resolve().parents[1] / "bateria" / "frases_s5.json"
    ejemplos = cargar_conjunto(ruta)
    assert len(ejemplos) == 60
    assert {e.etiqueta for e in ejemplos} == {"negativo", "neutro", "positivo"}


def test_los_archivos_privados_quedan_con_permisos_600(tmp_path):
    ruta = tmp_path / "conjunto.jsonl"
    escribir_privado(ruta, json.dumps({"codigo": "R1", "texto": "x", "etiqueta": "neutro", "origen": ""}) + "\n")
    assert stat.S_IMODE(ruta.stat().st_mode) == 0o600
    assert cargar_conjunto(ruta) == (Ejemplo("R1", "x", "neutro", ""),)


# ------------------------------ pre-etiquetado -----------------------------

from entrenamiento.preetiquetar import candidatas, sugerir  # noqa: E402


def test_solo_sugiere_si_la_pregunta_y_el_analizador_coinciden():
    assert sugerir("preocupacion_actual", "negativo", 0.92) == "negativo"
    assert sugerir("cosas_fav_apps_adol_v2", "positivo", 0.85) == "positivo"
    assert sugerir("preocupacion_actual", "neutro", 0.99) is None  # no coinciden
    assert sugerir("preocupacion_actual", "negativo", 0.6) is None  # poca confianza
    assert sugerir("preocup_ayuda_adol_v2", "neutro", 0.99) is None  # sin tendencia


def test_las_de_la_hoja_a_ciegas_y_las_cortas_quedan_fuera():
    filas = [
        {"id": "a1", "preocupacion_actual": "reprobar el examen de mate", "cosas_fav_apps_adol_v2": "me gusta jugar con amigos"},
        {"id": "b2", "preocupacion_actual": "la escuela", "cosas_fav_apps_adol_v2": ""},
    ]
    clave = {"R001": {"id": "a1", "columna": "preocupacion_actual"}}
    assert candidatas(filas, clave) == [("a1", "cosas_fav_apps_adol_v2", "me gusta jugar con amigos")]
