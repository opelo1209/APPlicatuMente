"""Semana 5 (reunion con el asesor): resumen del diario para el tutor.

Como en terapia: los papas reciben un resumen de como va el estudiante, no lo
que escribio. Si hubo groserias, el resumen lo dice sin repetirlas.

Las pruebas del endpoint necesitan PostgreSQL (igual que las de alertas).
"""
import json
from datetime import date, timedelta

import pytest

import app.main as main_mod
from app.resumen_tutor import DiaDiario, contar_altisonantes, dia_de_fila, resumir_diario
from tests.test_alertas_atendidas_s5 import _crear_usuario, _token, admin, cliente  # noqa: F401

HOY = date(2026, 10, 23)


def dia(n, polaridad, emociones=(), altisonantes=False):
    return DiaDiario(HOY - timedelta(days=n), polaridad, tuple(emociones), altisonantes)


# ------------------------------ groserias ----------------------------------


@pytest.mark.parametrize(
    "texto",
    ["el pinche profe me regañó", "qué pendejada", "mis compañeros son unos culeros", "ya me tienen hasta la madre, chingao"],
)
def test_detecta_palabras_altisonantes(texto):
    assert contar_altisonantes(texto) >= 1


@pytest.mark.parametrize(
    "texto",
    ["mi mamá me ayudó con la tarea", "estuve en la computadora", "me puse a jugar fut", "hoy fue un buen día"],
)
def test_no_confunde_palabras_comunes(texto):
    assert contar_altisonantes(texto) == 0


def test_de_la_fila_solo_queda_si_hubo_groserias_no_el_texto():
    d = dia_de_fila({"fecha": HOY, "polaridad": "negativo", "emociones": ["enojo"], "texto": "el pinche examen"})
    assert d.altisonantes is True
    assert not hasattr(d, "texto")


# ------------------------------ resumen ------------------------------------


def test_nunca_repite_lo_que_escribio_ni_las_groserias():
    filas = [
        {"fecha": HOY - timedelta(days=1), "polaridad": "negativo", "emociones": ["enojo"],
         "texto": "el pinche profe de mate me humilló frente a todos"},
        {"fecha": HOY, "polaridad": "neutro", "emociones": ["cansancio"], "texto": "dormí poco"},
    ]
    r = resumir_diario([dia_de_fila(f) for f in filas], "Ana")
    for palabra in ("pinche", "profe", "humill", "dormí"):
        assert palabra not in r.texto.lower()
    assert "palabras altisonantes" in r.texto
    assert r.dias_altisonantes == 1


def test_cuenta_los_dias_y_las_emociones_que_marco():
    r = resumir_diario(
        [dia(3, "positivo", ["alegria"]), dia(2, "negativo", ["tristeza"]), dia(1, "negativo", ["tristeza", "enojo"])],
        "Luis",
    )
    assert "Luis escribió en su diario 3 días: 1 bueno, 0 regulares y 2 difíciles." in r.texto
    assert "tristeza" in r.texto
    assert "Hubo más días difíciles que buenos" in r.texto


def test_sin_groserias_no_las_menciona():
    r = resumir_diario([dia(1, "positivo", ["alegria"])], "Ana")
    assert "altisonantes" not in r.texto


def test_sin_entradas_no_alarma():
    r = resumir_diario([], "Ana")
    assert r.dias_con_registro == 0
    assert "no escribió" in r.texto
    assert "No es una mala señal" in r.texto


def test_describe_la_tendencia():
    peor = resumir_diario([dia(6, "positivo"), dia(5, "positivo"), dia(2, "negativo"), dia(1, "negativo")])
    mejor = resumir_diario([dia(6, "negativo"), dia(5, "negativo"), dia(2, "positivo"), dia(1, "positivo")])
    assert "más difíciles que al inicio" in peor.texto
    assert "mejor que al inicio" in mejor.texto


def test_una_clave_de_emocion_desconocida_no_rompe_el_resumen():
    assert resumir_diario([dia(1, "neutro", ["no_existe"])]).dias_con_registro == 1


# ------------------------------ endpoint -----------------------------------


@pytest.fixture()
def estudiante_con_diario(cliente):  # noqa: F811
    nombre = _crear_usuario("usuarios_estudiantes", "est_s5")
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id_usuario FROM usuarios_estudiantes WHERE nombre_usuario = %s", (nombre,))
            id_usuario = cur.fetchone()["id_usuario"]
            for atras, polaridad, texto in ((2, "negativo", "odio al pinche profe"), (1, "neutro", "normal")):
                cur.execute(
                    """
                    INSERT INTO diario_entradas (id_estudiante, fecha, polaridad, emociones, texto, resultado, accion)
                    VALUES (%s, CURRENT_DATE - %s, %s, %s, %s, '{}', 'normal')
                    """,
                    (id_usuario, atras, polaridad, json.dumps(["enojo"]), texto),
                )
        conn.commit()
    yield id_usuario
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM usuarios_estudiantes WHERE id_usuario = %s", (id_usuario,))
        conn.commit()


def test_el_administrador_ve_el_borrador_sin_el_texto(cliente, admin, estudiante_con_diario):  # noqa: F811
    r = cliente.get(f"/admin/resumen-tutor/{estudiante_con_diario}", headers=admin)
    assert r.status_code == 200, r.text
    cuerpo = r.json()
    assert cuerpo["dias_con_registro"] == 2
    assert cuerpo["dias_altisonantes"] == 1
    assert "pinche" not in json.dumps(cuerpo, ensure_ascii=False)
    assert "profe" not in json.dumps(cuerpo, ensure_ascii=False)


def test_un_estudiante_no_puede_pedir_el_resumen(cliente):  # noqa: F811
    estudiante = _token(cliente, _crear_usuario("usuarios_estudiantes", "est_s5"))
    assert cliente.get("/admin/resumen-tutor/1", headers=estudiante).status_code == 403


def test_estudiante_inexistente(cliente, admin):  # noqa: F811
    assert cliente.get("/admin/resumen-tutor/999999999", headers=admin).status_code == 404
