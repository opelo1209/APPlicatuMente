"""Pruebas del acceso rapido de la demo (/auth/demo).

El acceso rapido solo existe en el despliegue del prototipo: se activa con
DEMO_ENABLED y exige DEMO_ACCESS_CODE. Estas pruebas fijan las cuatro
condiciones de seguridad, porque un fallo aqui significaria una puerta
abierta en un servidor publico.
"""
import importlib
import os

import pytest
from fastapi.testclient import TestClient

import app.main as main_mod

DB = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@127.0.0.1:55433/aptm_proto")
CODIGO = "clave-de-prueba"


@pytest.fixture()
def cliente(monkeypatch):
    """Cliente con la demo activada y una clave conocida."""
    monkeypatch.setenv("DATABASE_URL", DB)
    monkeypatch.setenv("DEMO_ENABLED", "true")
    monkeypatch.setenv("DEMO_ACCESS_CODE", CODIGO)
    importlib.reload(main_mod)
    return TestClient(main_mod.app)


def test_sin_demo_activada_el_endpoint_no_existe(cliente):
    """Con DEMO_ENABLED apagado el POST debe ser 404, no 403: no debe existir."""
    importlib.reload(main_mod)
    os.environ.pop("DEMO_ENABLED", None)
    importlib.reload(main_mod)
    assert main_mod.DEMO_ENABLED is False
    c = TestClient(main_mod.app)
    r = c.post("/auth/demo", json={"perfil": "estudiante", "clave": CODIGO})
    assert r.status_code == 404


def test_sin_clave_configurada_nunca_entra(monkeypatch):
    """DEMO_ENABLED=true pero sin clave: siempre 403. Nunca una puerta abierta."""
    monkeypatch.setenv("DATABASE_URL", DB)
    monkeypatch.setenv("DEMO_ENABLED", "true")
    monkeypatch.setenv("DEMO_ACCESS_CODE", "")
    importlib.reload(main_mod)
    c = TestClient(main_mod.app)
    r = c.post("/auth/demo", json={"perfil": "estudiante", "clave": ""})
    assert r.status_code == 403
    r = c.post("/auth/demo", json={"perfil": "estudiante", "clave": "cualquiera"})
    assert r.status_code == 403


def test_consulta_de_disponibilidad(cliente):
    data = cliente.get("/auth/demo").json()
    assert data["activo"] is True
    assert "estudiante" in data["personajes"]


@pytest.mark.parametrize(
    "clave,esperado",
    [("", 403), ("mala", 403), ("CLAVE-DE-PRUEBA", 403), ("  " + CODIGO + "  ", 200)],
)
def test_la_clave_se_compara_exacta(cliente, clave, esperado):
    r = cliente.post("/auth/demo", json={"perfil": "estudiante", "clave": clave})
    assert r.status_code == esperado


@pytest.mark.parametrize(
    "perfil,usuario",
    [
        ("estudiante", "ana_demo"),
        ("padre", "luis_demo"),
        ("madre", "maria_demo"),
        ("administrador", "admin_demo"),
    ],
)
def test_cada_personaje_entra_a_su_cuenta(cliente, perfil, usuario):
    """Cada boton abre una cuenta distinta. 'padre' y 'madre' comparten perfil
    en el esquema, asi que si se buscara por perfil normalizado los dos
    caerian en el mismo usuario; por eso se comprueba el nombre."""
    r = cliente.post("/auth/demo", json={"perfil": perfil, "clave": CODIGO})
    assert r.status_code == 200
    assert r.json()["user"]["nombre_usuario"] == usuario


def test_el_token_sirve_para_usar_la_api(cliente):
    r = cliente.post(
        "/auth/demo", json={"perfil": "estudiante", "clave": CODIGO}
    )
    token = r.json()["access_token"]
    assert cliente.get(
        "/users/me", headers={"Authorization": f"Bearer {token}"}
    ).status_code == 200


@pytest.mark.parametrize("perfil", ["rector", "", "  ", "ADMINISTRADOR2"])
def test_personaje_desconocido_rechazado(cliente, perfil):
    r = cliente.post("/auth/demo", json={"perfil": perfil, "clave": CODIGO})
    assert r.status_code in (400, 403)

# --------------------------------------------------------------------------
# Demo sin clave (DEMO_SIN_CLAVE=true): pedido para que el asesor entre con
# un clic. Solo afecta a la clave; todo lo demas se mantiene.
# --------------------------------------------------------------------------


@pytest.fixture()
def cliente_sin_clave(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", DB)
    monkeypatch.setenv("DEMO_ENABLED", "true")
    monkeypatch.setenv("DEMO_ACCESS_CODE", "")
    monkeypatch.setenv("DEMO_SIN_CLAVE", "true")
    importlib.reload(main_mod)
    yield TestClient(main_mod.app)
    monkeypatch.delenv("DEMO_SIN_CLAVE")
    importlib.reload(main_mod)


def test_sin_clave_la_disponibilidad_lo_dice(cliente_sin_clave):
    data = cliente_sin_clave.get("/auth/demo").json()
    assert data["activo"] is True
    assert data["requiere_clave"] is False


@pytest.mark.parametrize("perfil,usuario", [("estudiante", "ana_demo"), ("madre", "maria_demo"), ("administrador", "admin_demo")])
def test_sin_clave_entra_con_un_clic(cliente_sin_clave, perfil, usuario):
    r = cliente_sin_clave.post("/auth/demo", json={"perfil": perfil})
    assert r.status_code == 200
    assert r.json()["user"]["nombre_usuario"] == usuario


def test_sin_clave_sigue_rechazando_personajes_desconocidos(cliente_sin_clave):
    r = cliente_sin_clave.post("/auth/demo", json={"perfil": "rector"})
    assert r.status_code == 400


def test_sin_clave_no_se_activa_si_la_demo_esta_apagada(monkeypatch):
    # DEMO_SIN_CLAVE sola no abre nada: hace falta DEMO_ENABLED.
    monkeypatch.setenv("DATABASE_URL", DB)
    monkeypatch.delenv("DEMO_ENABLED", raising=False)
    monkeypatch.setenv("DEMO_SIN_CLAVE", "true")
    importlib.reload(main_mod)
    r = TestClient(main_mod.app).post("/auth/demo", json={"perfil": "estudiante"})
    assert r.status_code == 404
    monkeypatch.delenv("DEMO_SIN_CLAVE")
    importlib.reload(main_mod)


def test_con_clave_configurada_la_disponibilidad_pide_clave(cliente):
    assert cliente.get("/auth/demo").json()["requiere_clave"] is True
