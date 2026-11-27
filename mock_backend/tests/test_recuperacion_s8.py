"""Semana 8 (asesor, 12 de noviembre): recuperacion de contrasena.

Dos caminos:
  1. Correo, con una cuenta provisional de Google (SMTP de Gmail con
     contrasena de aplicacion). Ya existia desde la Semana 5; solo faltaba
     configurarlo y la pantalla de la app que abre el enlace.
  2. Sin correo: el administrador genera un codigo de un solo uso y se lo da
     al estudiante (por ejemplo, a traves de la escuela). El estudiante lo
     escribe en «¿Olvidaste tu contraseña?» con su contrasena nueva.

Necesitan PostgreSQL (igual que test_cuentas_s5.py).
"""

import pytest

import app.main as main_mod
from app import recuperacion_contrasena as recuperacion
from tests.test_alertas_atendidas_s5 import CLAVE, _crear_usuario, _token, admin, cliente  # noqa: F401


def _id(tabla, nombre):
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(f"SELECT id_usuario FROM {tabla} WHERE nombre_usuario = %s", (nombre,))
            return cur.fetchone()["id_usuario"]


# ------------------------------ el codigo ---------------------------------


def test_el_codigo_es_facil_de_dictar():
    codigo = recuperacion.nuevo_codigo()
    assert len(codigo) == 9 and codigo[4] == "-"
    assert set(codigo.replace("-", "")) <= set(recuperacion.ALFABETO_CODIGO)
    # Sin letras ni numeros que se confunden al dictarlos.
    assert not set("01OIL") & set(recuperacion.ALFABETO_CODIGO)


@pytest.mark.parametrize("escrito", ["abcd-2345", " ABCD 2345 ", "abcd2345", "ABCD–2345"])
def test_se_acepta_el_codigo_como_lo_escriba(escrito):
    assert recuperacion.normalizar_codigo(escrito) == "ABCD2345"


def test_un_enlace_de_correo_no_se_toma_por_codigo():
    assert recuperacion.normalizar_codigo("Zx_9-largo-token-de-correo-aaaaaaaaaaaa") is None


# ------------------------------ endpoints ---------------------------------


@pytest.fixture()
def estudiante(cliente):  # noqa: F811
    nombre = _crear_usuario("usuarios_estudiantes", "rec_s8")
    yield {"nombre": nombre, "id": _id("usuarios_estudiantes", nombre)}
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM usuarios_estudiantes WHERE nombre_usuario = %s", (nombre,))
        conn.commit()


def _pedir_codigo(cliente, admin, estudiante):  # noqa: F811
    return cliente.post(f"/admin/usuarios/estudiante/{estudiante['id']}/codigo-recuperacion", headers=admin)


def test_el_administrador_genera_un_codigo_y_el_estudiante_lo_usa(cliente, admin, estudiante):  # noqa: F811
    r = _pedir_codigo(cliente, admin, estudiante)
    assert r.status_code == 200, r.text
    cuerpo = r.json()
    assert cuerpo["vigencia_horas"] == recuperacion.VIGENCIA_CODIGO_HORAS
    codigo = cuerpo["codigo"]

    escrito = f" {codigo.lower()} "
    r = cliente.post("/auth/password-reset-confirm", json={"token": escrito, "new_password": "nueva-clave-s8"})
    assert r.status_code == 200, r.text
    assert cliente.post("/auth/login", json={"username": estudiante["nombre"], "password": "nueva-clave-s8"}).status_code == 200
    assert cliente.post("/auth/login", json={"username": estudiante["nombre"], "password": CLAVE}).status_code == 401


def test_el_codigo_sirve_una_sola_vez(cliente, admin, estudiante):  # noqa: F811
    codigo = _pedir_codigo(cliente, admin, estudiante).json()["codigo"]
    assert cliente.post("/auth/password-reset-confirm", json={"token": codigo, "new_password": "nueva-clave-s8"}).status_code == 200
    assert cliente.post("/auth/password-reset-confirm", json={"token": codigo, "new_password": "otra-clave-s8"}).status_code == 400


def test_un_codigo_nuevo_anula_el_anterior(cliente, admin, estudiante):  # noqa: F811
    viejo = _pedir_codigo(cliente, admin, estudiante).json()["codigo"]
    _pedir_codigo(cliente, admin, estudiante)
    assert cliente.post("/auth/password-reset-confirm", json={"token": viejo, "new_password": "nueva-clave-s8"}).status_code == 400


def test_solo_el_administrador_genera_codigos(cliente, estudiante):  # noqa: F811
    propio = _token(cliente, estudiante["nombre"])
    r = cliente.post(f"/admin/usuarios/estudiante/{estudiante['id']}/codigo-recuperacion", headers=propio)
    assert r.status_code == 403


def test_cuenta_inexistente_o_perfil_invalido(cliente, admin):  # noqa: F811
    assert cliente.post("/admin/usuarios/estudiante/999999999/codigo-recuperacion", headers=admin).status_code == 404
    assert cliente.post("/admin/usuarios/administrador/1/codigo-recuperacion", headers=admin).status_code == 400


def test_adivinar_codigos_tiene_limite(cliente):  # noqa: F811
    for _ in range(10):
        r = cliente.post("/auth/password-reset-confirm", json={"token": "AAAA-BBBB", "new_password": "nueva-clave-s8"})
        assert r.status_code == 400
    r = cliente.post("/auth/password-reset-confirm", json={"token": "AAAA-CCCC", "new_password": "nueva-clave-s8"})
    assert r.status_code == 429


def test_sin_correo_configurado_el_mensaje_ofrece_el_codigo(cliente, monkeypatch):  # noqa: F811
    monkeypatch.delenv("SMTP_HOST", raising=False)
    r = cliente.post("/auth/password-reset-request", json={"email_or_username": "alguien"})
    assert r.status_code == 503
    assert "código" in r.json()["detail"]
