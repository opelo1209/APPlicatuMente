"""Semana 5: H10 (CORS y arranque) y H7 (memoria de Serena con un solo
worker).

H10 El backend aceptaba peticiones de cualquier origen (allow_origins=["*"])
    y arrancaba con @app.on_event("startup"), obsoleto en FastAPI.
H7  La memoria de Serena vive en la RAM de un proceso; con varios workers la
    regla R14 dejaba de cumplirse sin aviso.

No necesitan PostgreSQL: el arranque se sustituye por un registro.
"""
import importlib

import pytest
from fastapi.testclient import TestClient

import app.main as main_mod
from app.memoria_sesion import VariosProcesos, reservar_proceso_unico


@pytest.fixture()
def candado(tmp_path, monkeypatch):
    ruta = tmp_path / "serena.lock"
    monkeypatch.setenv("SERENA_CANDADO", str(ruta))
    return ruta


def preflight(cliente, origen):
    return cliente.options(
        "/salud",
        headers={
            "Origin": origen,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization,content-type",
        },
    )


@pytest.fixture()
def cliente(monkeypatch):
    monkeypatch.delenv("CORS_ORIGENES", raising=False)
    importlib.reload(main_mod)
    return TestClient(main_mod.app)


# --------------------------------------------------------------------- H10


@pytest.mark.parametrize("origen", ["https://ml.izt.uam.mx", "http://localhost:53211", "http://127.0.0.1:8080"])
def test_los_origenes_propios_pueden_llamar(cliente, origen):
    r = preflight(cliente, origen)
    assert r.status_code == 200
    assert r.headers["access-control-allow-origin"] == origen


@pytest.mark.parametrize(
    "origen",
    ["https://sitio-ajeno.example", "http://ml.izt.uam.mx", "https://ml.izt.uam.mx.ajeno.example", "http://localhost.ajeno.example"],
)
def test_un_origen_ajeno_no_recibe_permiso(cliente, origen):
    r = preflight(cliente, origen)
    assert "access-control-allow-origin" not in r.headers
    r = cliente.get("/salud", headers={"Origin": origen})
    assert "access-control-allow-origin" not in r.headers


def test_la_lista_se_configura_por_entorno(monkeypatch):
    monkeypatch.setenv("CORS_ORIGENES", "https://otra.uam.mx/, https://tercera.uam.mx")
    importlib.reload(main_mod)
    c = TestClient(main_mod.app)
    assert preflight(c, "https://otra.uam.mx").headers["access-control-allow-origin"] == "https://otra.uam.mx"
    assert "access-control-allow-origin" not in preflight(c, "https://ml.izt.uam.mx").headers


def test_el_arranque_ya_no_usa_on_event(cliente):
    assert cliente.app.router.on_startup == []


def test_el_arranque_corre_por_lifespan(monkeypatch, candado):
    importlib.reload(main_mod)
    llamadas = []
    monkeypatch.setattr(main_mod, "startup", lambda: llamadas.append(True))
    with TestClient(main_mod.app):
        assert llamadas == [True]


# ---------------------------------------------------------------------- H7


def test_un_segundo_proceso_no_puede_usar_la_memoria(candado):
    primero = reservar_proceso_unico(str(candado))
    try:
        with pytest.raises(VariosProcesos, match="un worker"):
            reservar_proceso_unico(str(candado))
    finally:
        primero.close()


def test_al_terminar_el_primero_el_candado_se_libera(candado):
    reservar_proceso_unico(str(candado)).close()
    reservar_proceso_unico(str(candado)).close()


def test_el_servicio_no_arranca_si_otro_worker_tiene_la_memoria(monkeypatch, candado):
    importlib.reload(main_mod)
    monkeypatch.setattr(main_mod, "startup", lambda: None)
    otro_worker = reservar_proceso_unico(str(candado))
    try:
        with pytest.raises(VariosProcesos):
            with TestClient(main_mod.app):
                pass
    finally:
        otro_worker.close()
