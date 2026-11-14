"""Semana 8: pregunta 5 de la Dra. Gonzalez.

«Solo mostrar el tipo de señal como ideación suicida o plan suicida», sin el
fragmento que escribio el estudiante. Asi «no leen tus palabras» es cierto
tambien para el equipo de apoyo. El servidor ya no guarda el fragmento, y
las alertas viejas se limpian al arrancar.

Las pruebas con base necesitan PostgreSQL (igual que test_alertas_atendidas_s5.py).
"""

import json

import app.main as main_mod
from app.alerta_privada import ETIQUETAS_SENAL, etiqueta_senal, tipos_de_senal
from app.prototipo_api import _registrar_alerta, crear_tablas_prototipo
from tests.test_alertas_atendidas_s5 import _crear_usuario, admin, cliente  # noqa: F401


def test_solo_quedan_los_tipos_sin_repetir_y_en_orden():
    evidencia = ["ideacion_directa:quiero morirme", "despedida:adios a todos", "ideacion_directa:ya no quiero vivir"]
    assert tipos_de_senal(evidencia) == ["ideacion_directa", "despedida"]


def test_los_hechos_sin_texto_se_conservan():
    # La guardia de salida guarda hechos de la respuesta de Serena, no del estudiante.
    assert tipos_de_senal(["ofrece_metodo"]) == ["ofrece_metodo"]


def test_vacio():
    assert tipos_de_senal([]) == []


def test_cada_categoria_del_clasificador_tiene_etiqueta():
    from app.clasificador_riesgo import _CATEGORIAS

    assert set(_CATEGORIAS) <= set(ETIQUETAS_SENAL)
    assert etiqueta_senal("planeacion_o_intencion") == "Plan o intención suicida"
    assert etiqueta_senal("desconocida") == "desconocida"


class _CursorFalso:
    def __init__(self):
        self.parametros = None

    def execute(self, sql, parametros=None):
        self.parametros = parametros


def test_registrar_alerta_no_guarda_lo_que_escribio():
    cur = _CursorFalso()
    alerta = {
        "nivel": "riesgo_alto",
        "reglas": ["R1"],
        "evidencia": ["ideacion_directa:quiero morirme"],
        "prueba": ["paso"],
    }
    _registrar_alerta(cur, {"perfil_tipo": "estudiante", "id_usuario": 7}, "chat", alerta)
    guardado = json.loads(cur.parametros[5])
    assert guardado == ["ideacion_directa"]
    assert "morirme" not in " ".join(str(p) for p in cur.parametros)


def test_las_alertas_viejas_se_limpian_y_el_admin_no_ve_el_fragmento(cliente, admin):  # noqa: F811
    nombre = _crear_usuario("usuarios_estudiantes", "fragmento_s8")
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id_usuario FROM usuarios_estudiantes WHERE nombre_usuario = %s", (nombre,))
            id_est = cur.fetchone()["id_usuario"]
            cur.execute(
                "INSERT INTO alertas_riesgo (perfil_tipo, id_usuario, origen, nivel, reglas, evidencia, prueba)"
                " VALUES ('estudiante', %s, 'chat', 'riesgo_alto', '[\"R1\"]', %s, '[]') RETURNING id_alerta",
                (id_est, json.dumps(["ideacion_directa:quiero morirme", "despedida:adios"])),
            )
            id_alerta = cur.fetchone()["id_alerta"]
            crear_tablas_prototipo(cur)  # lo que corre al arrancar el servidor
        conn.commit()
    try:
        r = cliente.get("/admin/alertas-riesgo", headers=admin)
        assert r.status_code == 200, r.text
        alerta = next(a for a in r.json()["alertas"] if a["id_alerta"] == id_alerta)
        assert alerta["evidencia"] == ["ideacion_directa", "despedida"]
        assert alerta["senales"] == ["Ideación suicida", "Mensaje de despedida"]
        assert "morirme" not in r.text
    finally:
        with main_mod.db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM alertas_riesgo WHERE id_alerta = %s", (id_alerta,))
                cur.execute("DELETE FROM usuarios_estudiantes WHERE id_usuario = %s", (id_est,))
            conn.commit()
