"""Semana 5: lista de cuentas y borrado completo (derecho de cancelacion).

La prueba que importa: despues de borrar a un estudiante no queda NINGUNA
fila suya en ninguna tabla. Antes, borrar la fila del usuario dejaba sus
cuestionarios (Columbia), sus alertas con el fragmento, sus sesiones y sus
enlaces de recuperacion huerfanos.

Necesitan PostgreSQL (igual que test_alertas_atendidas_s5.py).
"""
import json

import pytest

import app.main as main_mod
from app import limite_intentos as limite
from app import recuperacion_contrasena as recuperacion
from tests.test_alertas_atendidas_s5 import CLAVE, _crear_usuario, _token, admin, cliente  # noqa: F401


def _id(tabla, nombre):
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(f"SELECT id_usuario FROM {tabla} WHERE nombre_usuario = %s", (nombre,))
            return cur.fetchone()["id_usuario"]


@pytest.fixture()
def estudiante_con_todo(cliente):  # noqa: F811
    """Un estudiante con datos en todas las tablas que lo pueden guardar."""
    nombre = _crear_usuario("usuarios_estudiantes", "borrar_s5")
    padre = _crear_usuario("usuarios_padres", "tutor_s5")
    _token(cliente, nombre)  # sesion abierta
    cliente.post("/auth/login", json={"username": nombre, "password": "equivocada-123"})  # intento fallido
    id_est, id_padre = _id("usuarios_estudiantes", nombre), _id("usuarios_padres", padre)
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO diario_entradas (id_estudiante, polaridad, emociones, texto, resultado, accion)"
                " VALUES (%s, 'negativo', '[\"tristeza\"]', 'algo muy personal', '{}', 'normal')",
                (id_est,),
            )
            cur.execute(
                "INSERT INTO cuestionarios_locales (perfil_tipo, id_usuario, tipo_cuestionario, respuestas, completado)"
                " VALUES ('estudiante', %s, 'columbia', '{\"ideacion\": true}', TRUE) RETURNING id_sesion",
                (id_est,),
            )
            id_sesion = cur.fetchone()["id_sesion"]
            cur.execute("INSERT INTO padre_estudiante (id_padre, id_estudiante) VALUES (%s, %s)", (id_padre, id_est))
            cur.execute(
                "INSERT INTO alertas_padres (id_padre, id_estudiante, id_sesion, tipo, titulo, mensaje, recomendacion)"
                " VALUES (%s, %s, %s, 'riesgo', 't', 'm', 'r')",
                (id_padre, id_est, id_sesion),
            )
            cur.execute(
                "INSERT INTO alertas_riesgo (perfil_tipo, id_usuario, origen, nivel, reglas, evidencia, prueba, nota_atencion)"
                " VALUES ('estudiante', %s, 'chat', 'riesgo_alto', '[\"R1\"]', %s, '[\"paso\"]', 'hablé con su mamá')",
                (id_est, json.dumps(["ideacion_directa:quiero morirme"])),
            )
            recuperacion.crear(cur, "estudiante", id_est)
        conn.commit()
    yield {"nombre": nombre, "id": id_est, "padre": padre, "id_padre": id_padre}
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM alertas_riesgo WHERE perfil_tipo = 'cuenta_borrada' AND nota_atencion IS NULL"
                        " AND evidencia = '[]' AND reglas = '[\"R1\"]'")
            cur.execute("DELETE FROM usuarios_estudiantes WHERE id_usuario = %s", (id_est,))
            cur.execute("DELETE FROM usuarios_padres WHERE id_usuario = %s", (id_padre,))
        conn.commit()


def _restos(id_est, nombre):
    """Cuantas filas del estudiante quedan en cada tabla."""
    consultas = {
        "usuarios_estudiantes": ("SELECT count(*) FROM usuarios_estudiantes WHERE id_usuario = %s", id_est),
        "diario_entradas": ("SELECT count(*) FROM diario_entradas WHERE id_estudiante = %s", id_est),
        "padre_estudiante": ("SELECT count(*) FROM padre_estudiante WHERE id_estudiante = %s", id_est),
        "alertas_padres": ("SELECT count(*) FROM alertas_padres WHERE id_estudiante = %s", id_est),
        "vinculacion_solicitudes": ("SELECT count(*) FROM vinculacion_solicitudes WHERE id_estudiante = %s", id_est),
        "cuestionarios_locales": ("SELECT count(*) FROM cuestionarios_locales WHERE perfil_tipo = 'estudiante' AND id_usuario = %s", id_est),
        "sesiones_locales": ("SELECT count(*) FROM sesiones_locales WHERE perfil_tipo = 'estudiante' AND id_usuario = %s", id_est),
        "recuperacion_tokens": ("SELECT count(*) FROM recuperacion_tokens WHERE perfil_tipo = 'estudiante' AND id_usuario = %s", id_est),
        "alertas_riesgo": ("SELECT count(*) FROM alertas_riesgo WHERE perfil_tipo = 'estudiante' AND id_usuario = %s", id_est),
        "intentos_acceso": ("SELECT count(*) FROM intentos_acceso WHERE clave = %s", limite.clave(limite.LOGIN_CUENTA, nombre)),
    }
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            resultado = {}
            for tabla, (sql, valor) in consultas.items():
                cur.execute(sql, (valor,))
                resultado[tabla] = cur.fetchone()["count"]
    return resultado


def _borrar(cliente, admin, e, confirmacion=None):  # noqa: F811
    return cliente.post(
        f"/admin/usuarios/estudiante/{e['id']}/borrar",
        headers=admin,
        json={"confirmacion": e["nombre"] if confirmacion is None else confirmacion},
    )


# ------------------------------- borrado -----------------------------------


def test_antes_de_borrar_hay_datos_en_todas_las_tablas(estudiante_con_todo):
    restos = _restos(estudiante_con_todo["id"], estudiante_con_todo["nombre"])
    vacias = [t for t, n in restos.items() if n == 0 and t != "vinculacion_solicitudes"]
    assert vacias == []  # la prueba de abajo si demuestra algo


def test_despues_de_borrar_no_queda_ninguna_fila_del_estudiante(cliente, admin, estudiante_con_todo):  # noqa: F811
    r = _borrar(cliente, admin, estudiante_con_todo)
    assert r.status_code == 200, r.text
    restos = _restos(estudiante_con_todo["id"], estudiante_con_todo["nombre"])
    assert restos == {t: 0 for t in restos}


def test_la_alerta_se_conserva_sin_nada_que_identifique(cliente, admin, estudiante_con_todo):  # noqa: F811
    _borrar(cliente, admin, estudiante_con_todo)
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT * FROM alertas_riesgo WHERE perfil_tipo = 'cuenta_borrada' AND reglas = '[\"R1\"]'"
                " ORDER BY id_alerta DESC LIMIT 1"
            )
            a = cur.fetchone()
    assert a["id_usuario"] == 0
    assert a["evidencia"] == [] and a["prueba"] == [] and a["nota_atencion"] is None
    assert a["nivel"] == "riesgo_alto" and a["origen"] == "chat"  # lo que si se conserva
    assert "quiero morirme" not in json.dumps(a, default=str)


def test_la_alerta_anonimizada_aparece_como_cuenta_borrada(cliente, admin, estudiante_con_todo):  # noqa: F811
    _borrar(cliente, admin, estudiante_con_todo)
    alertas = cliente.get("/admin/alertas-riesgo", headers=admin).json()["alertas"]
    assert any(a["estudiante"] == "Cuenta borrada" for a in alertas)


def test_el_tutor_sigue_existiendo_sin_el_vinculo(cliente, admin, estudiante_con_todo):  # noqa: F811
    _borrar(cliente, admin, estudiante_con_todo)
    assert _id("usuarios_padres", estudiante_con_todo["padre"]) == estudiante_con_todo["id_padre"]


def test_la_sesion_del_estudiante_deja_de_servir(cliente, admin, estudiante_con_todo):  # noqa: F811
    sesion = _token(cliente, estudiante_con_todo["nombre"])
    _borrar(cliente, admin, estudiante_con_todo)
    assert cliente.get("/users/me", headers=sesion).status_code == 401


def test_queda_un_registro_sin_datos_personales(cliente, admin, estudiante_con_todo):  # noqa: F811
    _borrar(cliente, admin, estudiante_con_todo)
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM cuentas_borradas ORDER BY id_borrado DESC LIMIT 1")
            registro = cur.fetchone()
    texto = json.dumps(registro, default=str)
    assert registro["perfil_tipo"] == "estudiante"
    assert estudiante_con_todo["nombre"] not in texto
    assert registro["filas"]["cuestionarios_locales"] == 1


def test_sin_la_confirmacion_exacta_no_se_borra(cliente, admin, estudiante_con_todo):  # noqa: F811
    r = _borrar(cliente, admin, estudiante_con_todo, confirmacion="otro_nombre")
    assert r.status_code == 400
    assert _restos(estudiante_con_todo["id"], estudiante_con_todo["nombre"])["usuarios_estudiantes"] == 1


def test_un_estudiante_no_puede_borrar_cuentas(cliente, estudiante_con_todo):  # noqa: F811
    otro = _token(cliente, _crear_usuario("usuarios_estudiantes", "est_s5"))
    r = cliente.post(f"/admin/usuarios/estudiante/{estudiante_con_todo['id']}/borrar", headers=otro,
                     json={"confirmacion": estudiante_con_todo["nombre"]})
    assert r.status_code == 403


def test_no_se_borran_administradores_ni_cuentas_inexistentes(cliente, admin):  # noqa: F811
    assert cliente.post("/admin/usuarios/administrador/1/borrar", headers=admin, json={"confirmacion": "x"}).status_code == 400
    assert cliente.post("/admin/usuarios/estudiante/999999999/borrar", headers=admin, json={"confirmacion": "x"}).status_code == 404


# -------------------------------- lista ------------------------------------


def test_la_lista_muestra_cuentas_sin_contrasenas_y_marca_google(cliente, admin, estudiante_con_todo):  # noqa: F811
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("UPDATE usuarios_estudiantes SET keycloack_id = %s WHERE id_usuario = %s",
                        (f"google-prueba-{estudiante_con_todo['id']}", estudiante_con_todo["id"]))
        conn.commit()
    r = cliente.get("/admin/usuarios", headers=admin, params={"buscar": estudiante_con_todo["nombre"]})
    assert r.status_code == 200
    [cuenta] = r.json()["cuentas"]
    assert cuenta["nombre_usuario"] == estudiante_con_todo["nombre"]
    assert cuenta["google"] is True and cuenta["activo"] is True
    assert "password_hash" not in cuenta and "keycloack_id" not in cuenta


def test_la_lista_de_tutores(cliente, admin, estudiante_con_todo):  # noqa: F811
    r = cliente.get("/admin/usuarios", headers=admin, params={"perfil": "padre", "buscar": estudiante_con_todo["padre"]})
    assert [c["nombre_usuario"] for c in r.json()["cuentas"]] == [estudiante_con_todo["padre"]]


def test_solo_el_administrador_ve_la_lista(cliente):  # noqa: F811
    estudiante = _token(cliente, _crear_usuario("usuarios_estudiantes", "est_s5"))
    assert cliente.get("/admin/usuarios", headers=estudiante).status_code == 403
    assert cliente.get("/admin/usuarios").status_code == 401
