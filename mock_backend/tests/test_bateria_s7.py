"""Semana 7 (T4): la bateria inicia sesion igual que la app.

La app le quita los espacios al usuario y a la contrasena antes de mandarlos
(login.dart y registro.dart usan .trim()); la bateria los mandaba tal cual y
recibia 401 con una cuenta que si entra desde el navegador.
"""
from types import SimpleNamespace

import pytest

from bateria import ejecutar


class ClienteLogin:
    def __init__(self, status_code: int = 200):
        self.status_code = status_code
        self.enviado: dict | None = None
        self.headers: dict[str, str] = {}

    def post(self, ruta: str, json: dict) -> SimpleNamespace:
        assert ruta == "/auth/login"
        self.enviado = json
        return SimpleNamespace(status_code=self.status_code, json=lambda: {"access_token": "aptm_x"})


def test_la_bateria_quita_los_espacios_como_la_app():
    cliente = ClienteLogin()
    ejecutar.iniciar_sesion(cliente, "  bateria_s6b \n", " clave-de-prueba\t")
    assert cliente.enviado == {"username": "bateria_s6b", "password": "clave-de-prueba"}
    assert cliente.headers["Authorization"] == "Bearer aptm_x"


def test_un_401_da_un_mensaje_claro_sin_mostrar_la_contrasena():
    cliente = ClienteLogin(status_code=401)
    with pytest.raises(SystemExit) as error:
        ejecutar.iniciar_sesion(cliente, "bateria_s6b", "clave-secreta")
    mensaje = str(error.value)
    assert "401" in mensaje and "bateria_s6b" in mensaje
    assert "clave-secreta" not in mensaje


def test_un_429_dice_que_espere():
    cliente = ClienteLogin(status_code=429)
    with pytest.raises(SystemExit) as error:
        ejecutar.iniciar_sesion(cliente, "bateria_s6b", "clave-secreta")
    assert "429" in str(error.value)
