"""Semana 5, H9: el administrador puede marcar una alerta como atendida.

Las alertas de riesgo tenian el campo `atendida`, pero ningun endpoint lo
cambiaba: todas quedaban pendientes para siempre y el resumen del
administrador no distinguia lo que ya se atendio de lo que no.

Necesitan PostgreSQL (igual que test_sesiones_s4.py).
"""
import importlib
import json
import os
import secrets

import pytest
from fastapi.testclient import TestClient

import app.main as main_mod

DB = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@127.0.0.1:55433/aptm_proto")
CLAVE = "clave-admin-s5-123"


@pytest.fixture()
def cliente(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", DB)
    importlib.reload(main_mod)
    # El costo del hash no importa aqui (ver test_cuentas_s5.py).
    monkeypatch.setattr(main_mod, "PBKDF2_ITERACIONES", 1_000)
    main_mod.init_db()
    return TestClient(main_mod.app)


def _crear_usuario(tabla: str, prefijo: str) -> str:
    nombre = f"{prefijo}_{secrets.token_hex(4)}"
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                INSERT INTO {tabla} (keycloack_id, nombre_usuario, correo, password_hash, nombres, apellido_paterno)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (f"local-{nombre}", nombre, f"{nombre}@prueba.local", main_mod.hash_password(CLAVE), "Ana", "Prueba"),
            )
        conn.commit()
    return nombre


def _token(cliente, nombre):
    r = cliente.post("/auth/login", json={"username": nombre, "password": CLAVE})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture()
def admin(cliente):
    return _token(cliente, _crear_usuario("usuarios_administradores", "admin_s5"))


@pytest.fixture()
def alerta():
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO alertas_riesgo (perfil_tipo, id_usuario, origen, nivel, reglas, evidencia, prueba)
                VALUES ('estudiante', 0, 'chat', 'crisis', %s, %s, %s) RETURNING id_alerta
                """,
                (json.dumps(["R1"]), json.dumps([]), json.dumps([])),
            )
            id_alerta = cur.fetchone()["id_alerta"]
        conn.commit()
    yield id_alerta
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM alertas_riesgo WHERE id_alerta = %s", (id_alerta,))
        conn.commit()


def _buscar(cliente, admin, id_alerta, **params):
    r = cliente.get("/admin/alertas-riesgo", headers=admin, params=params)
    assert r.status_code == 200
    return next((a for a in r.json()["alertas"] if a["id_alerta"] == id_alerta), None)


def test_una_alerta_nueva_esta_pendiente(cliente, admin, alerta):
    a = _buscar(cliente, admin, alerta)
    assert a["atendida"] is False
    assert a["atendida_por"] is None and a["fecha_atendida"] is None


def test_marcar_atendida_registra_quien_cuando_y_la_nota(cliente, admin, alerta):
    r = cliente.post(
        f"/admin/alertas-riesgo/{alerta}/atendida",
        headers=admin,
        json={"atendida": True, "nota": "  Se llamó a la mamá.  "},
    )
    assert r.status_code == 200, r.text
    datos = r.json()
    assert datos["atendida"] is True
    assert datos["atendida_por"] == "Ana Prueba"
    assert datos["fecha_atendida"] is not None
    assert datos["nota_atencion"] == "Se llamó a la mamá."

    a = _buscar(cliente, admin, alerta)
    assert a["atendida"] is True and a["nota_atencion"] == "Se llamó a la mamá."


def test_regresar_a_pendiente_borra_los_datos_de_atencion(cliente, admin, alerta):
    cliente.post(f"/admin/alertas-riesgo/{alerta}/atendida", headers=admin, json={"nota": "x"})
    r = cliente.post(f"/admin/alertas-riesgo/{alerta}/atendida", headers=admin, json={"atendida": False})
    datos = r.json()
    assert datos["atendida"] is False
    assert datos["atendida_por"] is None and datos["fecha_atendida"] is None and datos["nota_atencion"] is None


def test_el_filtro_de_pendientes_oculta_las_atendidas(cliente, admin, alerta):
    assert _buscar(cliente, admin, alerta, pendientes="true") is not None
    cliente.post(f"/admin/alertas-riesgo/{alerta}/atendida", headers=admin, json={})
    assert _buscar(cliente, admin, alerta, pendientes="true") is None
    assert _buscar(cliente, admin, alerta) is not None


def test_una_alerta_que_no_existe_da_404(cliente, admin):
    r = cliente.post("/admin/alertas-riesgo/999999999/atendida", headers=admin, json={})
    assert r.status_code == 404


def test_la_nota_tiene_tope(cliente, admin, alerta):
    r = cliente.post(f"/admin/alertas-riesgo/{alerta}/atendida", headers=admin, json={"nota": "a" * 501})
    assert r.status_code == 422


def test_solo_el_administrador_puede_atender(cliente, alerta):
    tutor = _token(cliente, _crear_usuario("usuarios_padres", "tutor_s5"))
    r = cliente.post(f"/admin/alertas-riesgo/{alerta}/atendida", headers=tutor, json={})
    assert r.status_code == 403


def test_sin_sesion_no_se_puede_atender(cliente, alerta):
    r = cliente.post(f"/admin/alertas-riesgo/{alerta}/atendida", json={})
    assert r.status_code == 401
