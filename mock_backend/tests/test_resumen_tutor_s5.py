"""Resumen del diario para el tutor.

Semana 5 (asesor): como en terapia, los papas reciben un resumen de como va
el estudiante, no lo que escribio.

Semana 8 (pregunta 6 de la Dra. Gonzalez): el resumen es MENSUAL, dice solo
cuantos dias fueron buenos, regulares y dificiles (sin emociones), no
menciona palabras altisonantes, y lo recibe el tutor en su cuenta de la app.
El texto del diario ya ni se lee para armarlo.

Las pruebas del endpoint necesitan PostgreSQL (igual que las de alertas).
"""
import json
from datetime import date

import pytest

import app.main as main_mod
from app import resumen_tutor as rt
from app.resumen_tutor import (
    UMBRAL_PLATICAR,
    DiaDiario,
    dia_de_fila,
    mes_anterior,
    nombre_mes,
    resumir_diario,
)
from tests.test_alertas_atendidas_s5 import _crear_usuario, _token, admin, cliente  # noqa: F401


def dia(n, polaridad, emociones=()):
    return DiaDiario(date(2026, 10, n), polaridad, tuple(emociones))


# ------------------------------ resumen ------------------------------------


def test_cuenta_los_dias_del_mes():
    r = resumir_diario([dia(3, "positivo"), dia(12, "neutro"), dia(20, "negativo")], "Luis", "octubre de 2026")
    assert r.texto.startswith("En octubre de 2026 Luis escribió en su diario 3 días: 1 bueno, 1 regular y 1 difícil.")
    assert (r.dias_con_registro, r.positivos, r.neutros, r.dificiles) == (3, 1, 1, 1)


def test_no_nombra_emociones_ni_palabras_altisonantes():
    r = resumir_diario([dia(1, "negativo", ["tristeza", "enojo"]), dia(2, "negativo", ["miedo"])], "Ana", "octubre")
    for palabra in ("tristeza", "enojo", "miedo", "altisonantes"):
        assert palabra not in r.texto.lower()
    assert not hasattr(rt, "contar_altisonantes")


def test_de_la_fila_no_queda_el_texto():
    d = dia_de_fila({"fecha": date(2026, 10, 1), "polaridad": "negativo", "emociones": ["enojo"],
                     "texto": "el pinche examen"})
    assert not hasattr(d, "texto") and not hasattr(d, "altisonantes")


def test_sugiere_platicar_desde_el_60_por_ciento_de_dias_dificiles():
    # Pregunta 6d: anotó «más de 60 días»; con un resumen mensual se toma
    # como el 60 % de los días con registro mientras ella lo confirma.
    assert UMBRAL_PLATICAR == 0.6
    tres_de_cinco = [dia(1, "negativo"), dia(2, "negativo"), dia(3, "negativo"), dia(4, "positivo"), dia(5, "neutro")]
    dos_de_cinco = [dia(1, "negativo"), dia(2, "negativo"), dia(3, "positivo"), dia(4, "positivo"), dia(5, "neutro")]
    assert "platicar" in resumir_diario(tres_de_cinco, "Ana", "octubre").texto
    assert "platicar" not in resumir_diario(dos_de_cinco, "Ana", "octubre").texto


def test_sin_entradas_no_alarma():
    r = resumir_diario([], "Ana", "octubre de 2026")
    assert r.dias_con_registro == 0
    assert "no escribió" in r.texto
    assert "No es una mala señal" in r.texto


def test_aclara_que_no_incluye_lo_que_escribio():
    assert "no incluye lo que escribió" in resumir_diario([dia(1, "neutro")], "Ana", "octubre").texto


# ------------------------------ meses --------------------------------------


@pytest.mark.parametrize(
    "hoy, esperado",
    [(date(2026, 11, 12), (2026, 10)), (date(2026, 1, 3), (2025, 12)), (date(2026, 3, 31), (2026, 2))],
)
def test_mes_anterior(hoy, esperado):
    assert mes_anterior(hoy) == esperado


def test_nombre_del_mes():
    assert nombre_mes(2026, 10) == "octubre de 2026"


# ------------------------------ endpoints ----------------------------------


@pytest.fixture()
def estudiante_con_diario(cliente):  # noqa: F811
    """Un estudiante con tres dias del mes pasado y uno de este mes."""
    nombre = _crear_usuario("usuarios_estudiantes", "est_s8")
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id_usuario FROM usuarios_estudiantes WHERE nombre_usuario = %s", (nombre,))
            id_usuario = cur.fetchone()["id_usuario"]
            for fecha_sql, polaridad, texto in (
                ("date_trunc('month', CURRENT_DATE) - INTERVAL '3 days'", "negativo", "odio al pinche profe"),
                ("date_trunc('month', CURRENT_DATE) - INTERVAL '2 days'", "negativo", "otra vez mal"),
                ("date_trunc('month', CURRENT_DATE) - INTERVAL '1 day'", "neutro", "normal"),
                ("CURRENT_DATE", "positivo", "de este mes"),
            ):
                cur.execute(
                    f"""
                    INSERT INTO diario_entradas (id_estudiante, fecha, polaridad, emociones, texto, resultado, accion)
                    VALUES (%s, ({fecha_sql})::date, %s, %s, %s, '{{}}', 'normal')
                    """,
                    (id_usuario, polaridad, json.dumps(["enojo"]), texto),
                )
        conn.commit()
    yield {"id": id_usuario, "nombre": nombre}
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM usuarios_estudiantes WHERE id_usuario = %s", (id_usuario,))
        conn.commit()


def _vincular(id_padre, id_estudiante):
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO padre_estudiante (id_padre, id_estudiante) VALUES (%s, %s)", (id_padre, id_estudiante))
        conn.commit()


def _id_padre(nombre):
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id_usuario FROM usuarios_padres WHERE nombre_usuario = %s", (nombre,))
            return cur.fetchone()["id_usuario"]


def test_el_administrador_ve_el_mes_pasado_sin_el_texto(cliente, admin, estudiante_con_diario):  # noqa: F811
    r = cliente.get(f"/admin/resumen-tutor/{estudiante_con_diario['id']}", headers=admin)
    assert r.status_code == 200, r.text
    cuerpo = r.json()
    assert (cuerpo["dias_con_registro"], cuerpo["dificiles"]) == (3, 2)
    texto = json.dumps(cuerpo, ensure_ascii=False)
    for palabra in ("pinche", "profe", "enojo", "altisonantes"):
        assert palabra not in texto


def test_el_tutor_vinculado_recibe_el_resumen_mensual(cliente, estudiante_con_diario):  # noqa: F811
    padre = _crear_usuario("usuarios_padres", "tutor_s8")
    _vincular(_id_padre(padre), estudiante_con_diario["id"])
    try:
        r = cliente.get("/users/padres/resumen-mensual", headers=_token(cliente, padre))
        assert r.status_code == 200, r.text
        cuerpo = r.json()
        assert len(cuerpo["resumenes"]) == 1
        resumen = cuerpo["resumenes"][0]
        assert resumen["dias_con_registro"] == 3  # el día de este mes no cuenta
        assert "2 difíciles" in resumen["texto"]
        assert "platicar" in resumen["texto"]  # 2 de 3 = 67 %
        assert "pinche" not in json.dumps(cuerpo, ensure_ascii=False)
    finally:
        with main_mod.db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM usuarios_padres WHERE nombre_usuario = %s", (padre,))
            conn.commit()


def test_el_tutor_no_ve_estudiantes_que_no_son_suyos(cliente, estudiante_con_diario):  # noqa: F811
    padre = _crear_usuario("usuarios_padres", "tutor_s8")
    try:
        r = cliente.get("/users/padres/resumen-mensual", headers=_token(cliente, padre))
        assert r.status_code == 200
        assert r.json()["resumenes"] == []
    finally:
        with main_mod.db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM usuarios_padres WHERE nombre_usuario = %s", (padre,))
            conn.commit()


@pytest.mark.parametrize("mes", ["2026-13", "abc", "1999-01", "2999-01"])
def test_un_mes_invalido_o_fuera_de_rango_se_rechaza(cliente, mes):  # noqa: F811
    padre = _crear_usuario("usuarios_padres", "tutor_s8")
    try:
        r = cliente.get(f"/users/padres/resumen-mensual?mes={mes}", headers=_token(cliente, padre))
        assert r.status_code == 422
    finally:
        with main_mod.db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM usuarios_padres WHERE nombre_usuario = %s", (padre,))
            conn.commit()


def test_solo_los_tutores_piden_el_resumen_mensual(cliente):  # noqa: F811
    estudiante = _token(cliente, _crear_usuario("usuarios_estudiantes", "est_s8"))
    assert cliente.get("/users/padres/resumen-mensual", headers=estudiante).status_code == 403


def test_un_estudiante_no_puede_pedir_el_resumen_del_admin(cliente):  # noqa: F811
    estudiante = _token(cliente, _crear_usuario("usuarios_estudiantes", "est_s5"))
    assert cliente.get("/admin/resumen-tutor/1", headers=estudiante).status_code == 403


def test_estudiante_inexistente(cliente, admin):  # noqa: F811
    assert cliente.get("/admin/resumen-tutor/999999999", headers=admin).status_code == 404
