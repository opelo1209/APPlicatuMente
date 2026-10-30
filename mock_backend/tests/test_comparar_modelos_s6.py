"""Semana 6 (asesor): comparar modelos de lenguaje dentro de Serena.

Se corre el pipeline real con cada modelo y se cuenta cuantas veces la
guardia tuvo que descartar lo que escribio (S12-S18) y cuanto tardo. Aqui
con un generador falso: sin GPU ni modelo.
"""
from bateria import comparar_modelos
from tests.test_evaluador_diario import AnalizadorFalso
from tests.test_serena_pipeline import GeneradorFalso

CONVERSACIONES = [
    {"id": "A", "mensajes": ["hola", "fui al cine con mis primos"]},
    {"id": "B", "mensajes": ["¿Cómo puedo ser más feliz?"]},
]


def test_cada_mensaje_queda_con_su_respuesta_y_su_decision():
    filas = comparar_modelos.correr(CONVERSACIONES, AnalizadorFalso("neutro"), GeneradorFalso("Qué bien que me cuentes."))
    assert [(f["conversacion"], f["turno"]) for f in filas] == [("A", 1), ("A", 2), ("B", 1)]
    assert all(f["texto"] and f["segundos"] >= 0 for f in filas)
    assert filas[2]["modelo"].startswith("sin modelo")  # la ficha de bienestar no usa el modelo


def test_el_resumen_cuenta_lo_que_la_guardia_descarto():
    filas = comparar_modelos.correr(
        CONVERSACIONES, AnalizadorFalso("neutro"), GeneradorFalso("Parece que estás pasando por un momento difícil.")
    )
    r = comparar_modelos.resumir(filas)
    assert r["mensajes"] == 3
    assert r["con_modelo"] == 2
    assert r["descartadas"] == 2 and r["por_regla"] == {"S17": 2}
    assert r["mostradas_del_modelo"] == 0


def test_las_conversaciones_de_la_semana_6_no_traen_crisis():
    from app.clasificador_riesgo import NIVEL_NINGUNO, clasificar_mensaje

    datos = comparar_modelos.cargar_conversaciones()
    mensajes = [m for c in datos for m in c["mensajes"]]
    assert len(datos) == 23
    assert all(clasificar_mensaje(m).nivel == NIVEL_NINGUNO for m in mensajes)
