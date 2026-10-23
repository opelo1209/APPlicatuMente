"""Semana 5: hallazgos de cuentas H4, H5, H6, H7 (tokens) y H11.

H4  La recuperacion de contrasena decia «correo enviado» sin enviarlo,
    imprimia el token en el registro y su 404 revelaba que cuentas existen.
H5  No habia limite de intentos ni longitud minima de contrasena.
H6  Desactivar la cuenta la dejaba inutilizable para siempre.
H7  Los tokens de recuperacion vivian en la RAM del proceso.
H11 PBKDF2 con 120 000 iteraciones; OWASP recomienda 600 000.

Necesitan PostgreSQL (igual que test_sesiones_s4.py).
"""
import hashlib
import importlib
import os
import secrets
import threading

import pytest
from fastapi.testclient import TestClient

import app.main as main_mod
from app import correo
from app import limite_intentos as limite
from app import recuperacion_contrasena as recuperacion

DB = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@127.0.0.1:55433/aptm_proto")
CLAVE = "clave-cuentas-s5"


def _cliente(monkeypatch, iteraciones=None):
    monkeypatch.setenv("DATABASE_URL", DB)
    importlib.reload(main_mod)
    if iteraciones is not None:
        monkeypatch.setattr(main_mod, "PBKDF2_ITERACIONES", iteraciones)
    main_mod.init_db()
    return TestClient(main_mod.app)


@pytest.fixture()
def cliente(monkeypatch):
    # 600 000 iteraciones tardan ~1,8 s por hash; fuera de las pruebas de
    # H11 no importa el costo y la bateria tardaria minutos.
    return _cliente(monkeypatch, iteraciones=1_000)


@pytest.fixture()
def cliente_real(monkeypatch):
    """Con las iteraciones de produccion (pruebas de H11)."""
    return _cliente(monkeypatch)


def registrar(cliente, clave=CLAVE, perfil="padre"):
    nombre = f"cta_s5_{secrets.token_hex(4)}"
    r = cliente.post(
        "/auth/register",
        json={
            "perfil_tipo": perfil,
            "nombre_usuario": nombre,
            "correo": f"{nombre}@prueba.local",
            "password": clave,
            "nombres": "Tutor",
            "apellido_paterno": "Prueba",
        },
    )
    return nombre, r


@pytest.fixture()
def usuario(cliente):
    nombre, r = registrar(cliente)
    assert r.status_code == 201, r.text
    return nombre


def entrar(cliente, nombre, clave=CLAVE):
    return cliente.post("/auth/login", json={"username": nombre, "password": clave})


def cabecera(cliente, nombre, clave=CLAVE):
    r = entrar(cliente, nombre, clave)
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def fila(nombre, tabla="usuarios_padres"):
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(f"SELECT * FROM {tabla} WHERE nombre_usuario = %s", (nombre,))
            return cur.fetchone()


def admin(cliente):
    nombre = f"adm_s5_{secrets.token_hex(4)}"
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO usuarios_administradores (keycloack_id, nombre_usuario, correo, password_hash, nombres, apellido_paterno)
                VALUES (%s, %s, %s, %s, 'Admin', 'Prueba') RETURNING id_usuario
                """,
                (f"local-{nombre}", nombre, f"{nombre}@prueba.local", main_mod.hash_password(CLAVE)),
            )
            id_admin = cur.fetchone()["id_usuario"]
        conn.commit()
    return cabecera(cliente, nombre), id_admin


# ---------------------------------------------------------------- H4 / H7


@pytest.fixture()
def buzon(monkeypatch):
    """Simula un servidor de correo configurado y guarda lo que se envia."""
    buzon = Buzon()
    monkeypatch.setattr(correo, "configurado", lambda: True)
    monkeypatch.setattr(correo, "enviar", buzon.enviar)
    return buzon


class Buzon(list):
    """Correos enviados. El envio corre en otro hilo: esperar() lo aguarda."""

    def __init__(self):
        super().__init__()
        self._listo = threading.Event()

    def enviar(self, destinatario, asunto, cuerpo):
        self.append((destinatario, asunto, cuerpo))
        self._listo.set()
        return True

    def esperar(self, segundos=3):
        return self._listo.wait(segundos)


def token_del_correo(cuerpo):
    return cuerpo.split("token=")[1].split()[0]


def test_sin_correo_configurado_lo_dice_en_vez_de_fingir(cliente, usuario, monkeypatch):
    monkeypatch.setattr(correo, "configurado", lambda: False)
    existe = cliente.post("/auth/password-reset-request", json={"email_or_username": usuario})
    no_existe = cliente.post("/auth/password-reset-request", json={"email_or_username": "nadie_" + usuario})
    assert existe.status_code == no_existe.status_code == 503
    assert existe.json() == no_existe.json()
    assert "enviamos" not in existe.json()["detail"]


def test_la_respuesta_no_revela_si_la_cuenta_existe(cliente, usuario, buzon):
    existe = cliente.post("/auth/password-reset-request", json={"email_or_username": usuario})
    no_existe = cliente.post("/auth/password-reset-request", json={"email_or_username": "nadie_" + usuario})
    assert existe.status_code == no_existe.status_code == 200
    assert existe.json() == no_existe.json()
    assert buzon.esperar()
    assert len(buzon) == 1 and buzon[0][0] == f"{usuario}@prueba.local"


def test_el_token_no_aparece_en_el_registro(cliente, usuario, buzon, capsys, caplog):
    cliente.post("/auth/password-reset-request", json={"email_or_username": usuario})
    assert buzon.esperar()
    token = token_del_correo(buzon[0][2])
    salida = capsys.readouterr()
    assert token not in salida.out + salida.err + caplog.text


def test_en_la_base_solo_queda_la_huella_del_token(cliente, usuario, buzon):
    cliente.post("/auth/password-reset-request", json={"email_or_username": usuario})
    assert buzon.esperar()
    token = token_del_correo(buzon[0][2])
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT token_sha256 FROM recuperacion_tokens WHERE id_usuario = %s", (fila(usuario)["id_usuario"],))
            guardado = cur.fetchone()["token_sha256"]
    assert guardado == hashlib.sha256(token.encode()).hexdigest() != token


def test_el_token_del_correo_cambia_la_contrasena_una_sola_vez(cliente, usuario, buzon):
    sesion = cabecera(cliente, usuario)
    cliente.post("/auth/password-reset-request", json={"email_or_username": usuario})
    assert buzon.esperar()
    token = token_del_correo(buzon[0][2])
    r = cliente.post("/auth/password-reset-confirm", json={"token": token, "new_password": "nueva-clave-s5"})
    assert r.status_code == 200, r.text
    assert entrar(cliente, usuario, "nueva-clave-s5").status_code == 200
    assert cliente.get("/users/me", headers=sesion).status_code == 401
    otra = cliente.post("/auth/password-reset-confirm", json={"token": token, "new_password": "otra-clave-s5"})
    assert otra.status_code == 400


def test_un_token_vencido_no_sirve(cliente, usuario):
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            token = recuperacion.crear(cur, "padre", fila(usuario)["id_usuario"])
            cur.execute("UPDATE recuperacion_tokens SET expira = NOW() - INTERVAL '1 minute'")
        conn.commit()
    r = cliente.post("/auth/password-reset-confirm", json={"token": token, "new_password": "nueva-clave-s5"})
    assert r.status_code == 400


def test_pedir_otro_correo_anula_el_anterior(cliente, usuario):
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            primero = recuperacion.crear(cur, "padre", fila(usuario)["id_usuario"])
            recuperacion.crear(cur, "padre", fila(usuario)["id_usuario"])
        conn.commit()
    r = cliente.post("/auth/password-reset-confirm", json={"token": primero, "new_password": "nueva-clave-s5"})
    assert r.status_code == 400


def test_una_contrasena_corta_no_gasta_el_token(cliente, usuario):
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            token = recuperacion.crear(cur, "padre", fila(usuario)["id_usuario"])
        conn.commit()
    assert cliente.post("/auth/password-reset-confirm", json={"token": token, "new_password": "corta"}).status_code == 400
    assert cliente.post("/auth/password-reset-confirm", json={"token": token, "new_password": "larga-ya-s5"}).status_code == 200


def test_una_cuenta_desactivada_no_recibe_correo(cliente, usuario, buzon):
    cliente.put("/users/desactivar", headers=cabecera(cliente, usuario))
    r = cliente.post("/auth/password-reset-request", json={"email_or_username": usuario})
    assert r.status_code == 200
    assert not buzon.esperar(1)


# --------------------------------------------------------------------- H5


def test_cinco_fallos_bloquean_la_cuenta_aunque_luego_acierte(cliente, usuario):
    for _ in range(limite.LOGIN_CUENTA.maximo):
        assert entrar(cliente, usuario, "equivocada").status_code == 401
    r = entrar(cliente, usuario)
    assert r.status_code == 429
    assert int(r.headers["Retry-After"]) > 0
    assert "Demasiados intentos" in r.json()["detail"]


def test_el_bloqueo_de_una_cuenta_no_afecta_a_otra(cliente, usuario):
    otro, _ = registrar(cliente)
    for _ in range(limite.LOGIN_CUENTA.maximo):
        entrar(cliente, usuario, "equivocada")
    assert entrar(cliente, otro).status_code == 200


def test_entrar_bien_reinicia_el_conteo(cliente, usuario):
    for _ in range(limite.LOGIN_CUENTA.maximo - 1):
        entrar(cliente, usuario, "equivocada")
    assert entrar(cliente, usuario).status_code == 200
    for _ in range(limite.LOGIN_CUENTA.maximo - 1):
        assert entrar(cliente, usuario, "equivocada").status_code == 401


def test_una_cuenta_inexistente_tambien_se_bloquea(cliente):
    """Si solo se bloquearan las cuentas que existen, el 429 las delataria."""
    for _ in range(limite.LOGIN_CUENTA.maximo):
        assert entrar(cliente, "nadie_s5", "x").status_code == 401
    assert entrar(cliente, "nadie_s5", "x").status_code == 429


def test_muchos_fallos_desde_la_misma_direccion_se_bloquean(cliente, usuario, monkeypatch):
    # Mismo mecanismo con un tope chico: con 30 la prueba tardaria un minuto.
    monkeypatch.setattr(limite, "LOGIN_IP", limite.Limite("login-ip", 3, 15))
    for i in range(limite.LOGIN_IP.maximo):
        entrar(cliente, f"cuenta_{i}_s5", "x")
    assert entrar(cliente, usuario).status_code == 429


def test_tres_recuperaciones_por_hora(cliente, usuario, buzon):
    for _ in range(limite.RECUPERACION_CUENTA.maximo):
        assert cliente.post("/auth/password-reset-request", json={"email_or_username": usuario}).status_code == 200
    r = cliente.post("/auth/password-reset-request", json={"email_or_username": usuario})
    assert r.status_code == 429


def test_la_clave_de_la_demo_tiene_limite(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", DB)
    monkeypatch.setenv("DEMO_ENABLED", "true")
    monkeypatch.setenv("DEMO_ACCESS_CODE", "clave-demo-s5")
    importlib.reload(main_mod)
    c = TestClient(main_mod.app)
    for _ in range(limite.DEMO_IP.maximo):
        assert c.post("/auth/demo", json={"perfil": "estudiante", "clave": "mala"}).status_code == 403
    r = c.post("/auth/demo", json={"perfil": "estudiante", "clave": "clave-demo-s5"})
    assert r.status_code == 429


def test_el_chat_pide_una_pausa_con_la_linea_de_ayuda(cliente, usuario):
    sesion = cabecera(cliente, usuario)
    sujeto = f"padre:{fila(usuario)['id_usuario']}"
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            for _ in range(limite.CHAT_USUARIO.maximo):
                limite.registrar(cur, limite.CHAT_USUARIO, sujeto)
        conn.commit()
    for ruta in ("/chat", "/chat/stream"):
        r = cliente.post(ruta, headers=sesion, json={"mensaje": "hola"})
        assert r.status_code == 429
        assert "Línea de la Vida" in r.json()["detail"]


@pytest.mark.parametrize("clave", ["", "1234567", "a" * 129])
def test_registro_rechaza_contrasenas_fuera_de_rango(cliente, clave):
    _, r = registrar(cliente, clave=clave)
    assert r.status_code == 400
    assert "contraseña" in r.json()["detail"]


def test_cambiar_a_una_contrasena_corta_se_rechaza(cliente, usuario):
    r = cliente.post(
        "/auth/change-password",
        json={"current_password": CLAVE, "new_password": "corta"},
        headers=cabecera(cliente, usuario),
    )
    assert r.status_code == 400
    assert entrar(cliente, usuario).status_code == 200


def test_una_cuenta_vieja_con_contrasena_corta_sigue_entrando(cliente, usuario):
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE usuarios_padres SET password_hash = %s WHERE nombre_usuario = %s",
                (main_mod.hash_password("corta"), usuario),
            )
        conn.commit()
    assert entrar(cliente, usuario, "corta").status_code == 200


# --------------------------------------------------------------------- H6


def test_desactivar_cierra_las_sesiones(cliente, usuario):
    telefono = cabecera(cliente, usuario)
    compu = cabecera(cliente, usuario)
    assert cliente.put("/users/desactivar", headers=telefono).status_code == 200
    assert cliente.get("/users/me", headers=compu).status_code == 401


def test_una_cuenta_desactivada_sabe_a_quien_pedir_ayuda(cliente, usuario):
    cliente.put("/users/desactivar", headers=cabecera(cliente, usuario))
    r = entrar(cliente, usuario)
    assert r.status_code == 403
    assert "administrador" in r.json()["detail"]
    # Sin la contrasena correcta no se entera de nada.
    assert entrar(cliente, usuario, "equivocada").status_code == 401


def test_el_administrador_la_reactiva(cliente, usuario):
    cliente.put("/users/desactivar", headers=cabecera(cliente, usuario))
    jefe, _ = admin(cliente)
    id_usuario = fila(usuario)["id_usuario"]
    r = cliente.put(f"/admin/usuarios/padre/{id_usuario}/activo", headers=jefe, json={"activo": True})
    assert r.status_code == 200, r.text
    assert r.json()["user"]["activo"] is True
    assert entrar(cliente, usuario).status_code == 200


def test_el_administrador_tambien_puede_desactivar(cliente, usuario):
    sesion = cabecera(cliente, usuario)
    jefe, _ = admin(cliente)
    id_usuario = fila(usuario)["id_usuario"]
    cliente.put(f"/admin/usuarios/padre/{id_usuario}/activo", headers=jefe, json={"activo": False})
    assert cliente.get("/users/me", headers=sesion).status_code == 401


def test_solo_el_administrador_reactiva(cliente, usuario):
    otro, _ = registrar(cliente)
    r = cliente.put(
        f"/admin/usuarios/padre/{fila(usuario)['id_usuario']}/activo",
        headers=cabecera(cliente, otro),
        json={"activo": True},
    )
    assert r.status_code == 403


def test_reactivar_a_alguien_que_no_existe_da_404(cliente):
    jefe, _ = admin(cliente)
    r = cliente.put("/admin/usuarios/padre/999999999/activo", headers=jefe, json={"activo": True})
    assert r.status_code == 404


def test_el_administrador_no_se_desactiva_a_si_mismo(cliente):
    jefe, id_admin = admin(cliente)
    r = cliente.put(f"/admin/usuarios/administrador/{id_admin}/activo", headers=jefe, json={"activo": False})
    assert r.status_code == 400


# -------------------------------------------------------------------- H11


def test_las_contrasenas_nuevas_usan_600_mil_iteraciones(cliente_real):
    usuario, r = registrar(cliente_real)
    assert r.status_code == 201
    assert fila(usuario)["password_hash"].startswith("pbkdf2_sha256$600000$")


def test_un_hash_viejo_se_actualiza_al_entrar(cliente_real):
    cliente = cliente_real
    usuario, _ = registrar(cliente)
    sal = secrets.token_hex(16)
    viejo = hashlib.pbkdf2_hmac("sha256", CLAVE.encode(), sal.encode(), 120_000).hex()
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE usuarios_padres SET password_hash = %s WHERE nombre_usuario = %s",
                (f"pbkdf2_sha256$120000${sal}${viejo}", usuario),
            )
        conn.commit()
    assert entrar(cliente, usuario).status_code == 200
    assert fila(usuario)["password_hash"].startswith("pbkdf2_sha256$600000$")
    assert entrar(cliente, usuario).status_code == 200


@pytest.mark.parametrize(
    "guardado,esperado",
    [
        ("pbkdf2_sha256$120000$sal$abc", True),
        ("pbkdf2_sha256$600000$sal$abc", False),
        ("md5$1$sal$abc", True),
        ("basura", True),
    ],
)
def test_necesita_rehash(guardado, esperado):
    importlib.reload(main_mod)
    assert main_mod.necesita_rehash(guardado) is esperado
