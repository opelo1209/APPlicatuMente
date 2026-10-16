"""Semana 4, T2 (hallazgo H2): las sesiones vencen y se pueden cerrar.

Antes un token servia para siempre: la tabla de sesiones no tenia
vencimiento, el servidor no tenia cierre de sesion y cambiar o restablecer
la contrasena no invalidaba los tokens existentes. En un equipo compartido,
o si alguien copiaba el token, la cuenta de un menor quedaba abierta.

Necesitan PostgreSQL (igual que test_demo_login.py).
"""
import importlib
import os
import secrets
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient

import app.main as main_mod

DB = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@127.0.0.1:55433/aptm_proto")
CLAVE = "clave-original-123"


@pytest.fixture()
def cliente(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", DB)
    monkeypatch.delenv("SESION_HORAS", raising=False)
    importlib.reload(main_mod)
    return TestClient(main_mod.app)


@pytest.fixture()
def usuario(cliente):
    nombre = f"tutor_s4_{secrets.token_hex(4)}"
    r = cliente.post(
        "/auth/register",
        json={
            "perfil_tipo": "padre",
            "nombre_usuario": nombre,
            "correo": f"{nombre}@prueba.local",
            "password": CLAVE,
            "nombres": "Tutor",
            "apellido_paterno": "Prueba",
        },
    )
    assert r.status_code == 201, r.text
    return nombre


def entrar(cliente, nombre, clave=CLAVE):
    r = cliente.post("/auth/login", json={"username": nombre, "password": clave})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


def me(cliente, token):
    return cliente.get("/users/me", headers={"Authorization": f"Bearer {token}"})


def envejecer(token, horas):
    crudo = token.replace(main_mod.TOKEN_PREFIX, "", 1)
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE sesiones_locales SET fecha_creacion = %s WHERE token = %s",
                (datetime.now(timezone.utc) - timedelta(hours=horas), crudo),
            )
        conn.commit()


def test_un_token_recien_creado_funciona(cliente, usuario):
    assert me(cliente, entrar(cliente, usuario)).status_code == 200


def test_un_token_vencido_se_rechaza(cliente, usuario):
    token = entrar(cliente, usuario)
    envejecer(token, main_mod.SESION_HORAS_POR_OMISION + 1)
    assert me(cliente, token).status_code == 401


def test_el_plazo_se_configura(cliente, usuario, monkeypatch):
    token = entrar(cliente, usuario)
    envejecer(token, 3)
    assert me(cliente, token).status_code == 200
    monkeypatch.setenv("SESION_HORAS", "2")
    assert me(cliente, token).status_code == 401


def test_un_plazo_invalido_usa_el_de_omision(cliente, usuario, monkeypatch):
    monkeypatch.setenv("SESION_HORAS", "no-es-numero")
    token = entrar(cliente, usuario)
    assert me(cliente, token).status_code == 200


def test_tras_cerrar_sesion_el_token_se_rechaza(cliente, usuario):
    token = entrar(cliente, usuario)
    r = cliente.post("/auth/logout", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    assert me(cliente, token).status_code == 401


def test_cerrar_sesion_no_cierra_las_otras_sesiones(cliente, usuario):
    telefono = entrar(cliente, usuario)
    compu = entrar(cliente, usuario)
    cliente.post("/auth/logout", headers={"Authorization": f"Bearer {telefono}"})
    assert me(cliente, compu).status_code == 200


def test_cerrar_sesion_sin_token_valido_no_falla(cliente):
    r = cliente.post("/auth/logout", headers={"Authorization": "Bearer local_access_inexistente"})
    assert r.status_code == 200


def test_cambiar_la_contrasena_invalida_las_otras_sesiones(cliente, usuario):
    anterior = entrar(cliente, usuario)
    actual = entrar(cliente, usuario)
    r = cliente.post(
        "/auth/change-password",
        json={"current_password": CLAVE, "new_password": "clave-nueva-456"},
        headers={"Authorization": f"Bearer {actual}"},
    )
    assert r.status_code == 200, r.text
    assert me(cliente, anterior).status_code == 401
    assert me(cliente, actual).status_code == 200, "quien cambio la contrasena sigue dentro"


def test_restablecer_la_contrasena_invalida_todas_las_sesiones(cliente, usuario):
    token = entrar(cliente, usuario)
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id_usuario FROM usuarios_padres WHERE nombre_usuario = %s", (usuario,))
            id_usuario = cur.fetchone()["id_usuario"]
    reinicio = secrets.token_urlsafe(16)
    main_mod.RESET_TOKENS[reinicio] = {
        "id_usuario": id_usuario,
        "perfil_tipo": "padre",
        "expira": datetime.now(timezone.utc) + timedelta(minutes=5),
    }
    r = cliente.post("/auth/password-reset-confirm", json={"token": reinicio, "new_password": "otra-clave-789"})
    assert r.status_code == 200, r.text
    assert me(cliente, token).status_code == 401


def test_al_entrar_se_borran_las_sesiones_vencidas(cliente, usuario):
    vieja = entrar(cliente, usuario)
    envejecer(vieja, main_mod.SESION_HORAS_POR_OMISION + 1)
    entrar(cliente, usuario)
    crudo = vieja.replace(main_mod.TOKEN_PREFIX, "", 1)
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM sesiones_locales WHERE token = %s", (crudo,))
            assert cur.fetchone() is None


def test_vencida_acepta_fechas_sin_zona_horaria():
    ahora = datetime.now(timezone.utc)
    assert main_mod.sesion_vencida(ahora.replace(tzinfo=None) - timedelta(hours=48), 24, ahora)
    assert not main_mod.sesion_vencida(ahora.replace(tzinfo=None), 24, ahora)
    assert main_mod.sesion_vencida(ahora - timedelta(hours=25), 24, ahora)
