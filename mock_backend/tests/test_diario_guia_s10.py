"""Semana 10 (asesor, 25 de noviembre): el analizador es una guia.

Lo que pidio el asesor, con sus dos ejemplos:

* «Me siento mal y quiero morirme» marcado como POSITIVO: gana la etiqueta
  negativa, esa es la que se guarda y se envia una alerta (nivel 1).
* «Mi dia fue el mismo de siempre» marcado como NEGATIVO: se hace caso al
  alumno; el analizador no lo corrige.
* El analizador trabaja «por debajo del agua»: el estudiante no ve lo que
  leyo; si lo marco positivo y el texto es claramente negativo, se registra
  una segunda evaluacion en silencio, para sacar mas informacion (nivel 2).

Las pruebas de la logica usan un analizador falso; las de la API necesitan
PostgreSQL (igual que test_alertas_atendidas_s5.py).
"""
import importlib
import os
import secrets
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.analizador_sentimiento import ResultadoSentimiento  # noqa: E402
from app.evaluador_diario import (  # noqa: E402
    AJUSTE_RIESGO,
    MENSAJE_GUARDADO,
    MENSAJE_RIESGO,
    SEGUNDA_NEGATIVO,
    UMBRAL_SEGUNDA_EVALUACION,
    EntradaDiario,
    evaluar_entrada,
    resultado_a_dict,
)

EMOCION = {"positivo": ("alegria",), "neutro": ("tranquilidad",), "negativo": ("tristeza",)}


class AnalizadorFalso:
    """Devuelve la polaridad y la probabilidad que se le pidan."""

    def __init__(self, polaridad="neutro", prob=0.8, emocion="otra"):
        self.polaridad, self.prob, self.emocion = polaridad, prob, emocion

    def analizar(self, texto):
        resto = round((1 - self.prob) / 2, 4)
        probs = {p: resto for p in ("positivo", "neutro", "negativo")}
        probs[self.polaridad] = self.prob
        return ResultadoSentimiento(
            polaridad=self.polaridad,
            probabilidades_polaridad=tuple(sorted(probs.items(), key=lambda x: -x[1])),
            emociones=((self.emocion, self.prob), ("otra", round(1 - self.prob, 4))),
            modelo="falso",
        )


def evaluar(marcado, texto, analizador):
    return evaluar_entrada(EntradaDiario(marcado, EMOCION[marcado], texto), analizador)


# ------------------------- Nivel 1: riesgo alto -----------------------------


def test_quiero_morirme_marcado_positivo_se_guarda_negativo_y_alerta():
    r = evaluar("positivo", "Me siento mal y quiero morirme", AnalizadorFalso("negativo", 0.97, "tristeza"))
    assert r.polaridad_registrada == "positivo"  # lo que marco, para el historial
    assert r.polaridad_guardada == "negativo"  # lo que se guarda
    assert r.ajuste == AJUSTE_RIESGO
    assert r.alerta_admin is not None
    assert r.mostrar_lineas_ayuda


def test_el_nivel_1_no_depende_del_analizador():
    # Aunque el modelo se equivoque y lea «positivo», el riesgo gana.
    r = evaluar("positivo", "Me siento mal y quiero morirme", AnalizadorFalso("positivo", 0.95, "alegria"))
    assert r.polaridad_guardada == "negativo" and r.alerta_admin is not None


@pytest.mark.parametrize("marcado", ["positivo", "neutro"])
def test_autolesion_y_plan_tambien_ganan(marcado):
    for texto in ("Ayer me corté otra vez", "Ya tengo las pastillas guardadas para hacerlo"):
        r = evaluar(marcado, texto, AnalizadorFalso("negativo", 0.9))
        assert r.polaridad_guardada == "negativo", texto
        assert r.alerta_admin is not None, texto


def test_el_estudiante_no_ve_que_se_cambio_su_etiqueta():
    r = evaluar("positivo", "Me siento mal y quiero morirme", AnalizadorFalso("negativo", 0.97))
    d = resultado_a_dict(r)
    assert d["mensaje_concordancia"] == MENSAJE_RIESGO
    assert "negativ" not in d["mensaje_concordancia"].lower()
    assert d["polaridad_registrada"] == "positivo" and d["polaridad_guardada"] == "negativo"


def test_una_consulta_sobre_el_tema_no_cambia_la_etiqueta():
    r = evaluar("neutro", "Hoy vimos en clase qué es el suicidio y cómo prevenirlo", AnalizadorFalso("negativo", 0.95))
    assert r.polaridad_guardada == "neutro" and r.ajuste is None


def test_un_dia_ya_negativo_no_necesita_ajuste():
    r = evaluar("negativo", "Me siento mal y quiero morirme", AnalizadorFalso("negativo", 0.97))
    assert r.polaridad_guardada == "negativo" and r.ajuste is None
    assert r.alerta_admin is not None  # la alerta sale igual


# ----------------- Sin riesgo: se hace caso al alumno -----------------------


@pytest.mark.parametrize(
    "marcado,polaridad_modelo",
    [("negativo", "neutro"), ("negativo", "positivo"), ("neutro", "negativo"), ("positivo", "neutro")],
)
def test_sin_riesgo_se_guarda_lo_que_marco(marcado, polaridad_modelo):
    r = evaluar(marcado, "Mi día fue el mismo de siempre", AnalizadorFalso(polaridad_modelo, 0.99))
    assert r.polaridad_guardada == marcado
    assert r.ajuste is None
    assert r.alerta_admin is None


def test_el_analizador_no_se_le_muestra_al_estudiante():
    # Antes: «Marcaste tu día como positivo. En lo que escribiste también
    # notamos tristeza». Ahora solo se confirma que se guardo.
    r = evaluar("positivo", "todo bien, aunque me siento solo", AnalizadorFalso("negativo", 0.8, "tristeza"))
    assert r.concordancia == "difiere"  # queda en el servidor
    assert r.mensaje_concordancia == MENSAJE_GUARDADO


# ----------------- Nivel 2: segunda evaluacion silenciosa -------------------


def test_positivo_con_texto_muy_negativo_deja_segunda_evaluacion():
    r = evaluar("positivo", "todo me sale mal y nadie me hace caso", AnalizadorFalso("negativo", 0.95))
    assert r.segunda_evaluacion == SEGUNDA_NEGATIVO
    assert r.polaridad_guardada == "positivo"  # no cambia lo que marco
    assert r.alerta_admin is None  # no es urgencia
    assert r.mensaje_concordancia == MENSAJE_GUARDADO


def test_debajo_del_umbral_no_hay_segunda_evaluacion():
    prob = round(UMBRAL_SEGUNDA_EVALUACION - 0.05, 2)
    r = evaluar("positivo", "todo me sale mal", AnalizadorFalso("negativo", prob))
    assert r.segunda_evaluacion is None


@pytest.mark.parametrize("marcado", ["neutro", "negativo"])
def test_la_segunda_evaluacion_solo_aplica_si_marco_positivo(marcado):
    r = evaluar(marcado, "todo me sale mal", AnalizadorFalso("negativo", 0.99))
    assert r.segunda_evaluacion is None


def test_sin_texto_no_hay_ajustes():
    r = evaluar("positivo", "", AnalizadorFalso("negativo", 0.99))
    assert r.polaridad_guardada == "positivo" and r.ajuste is None and r.segunda_evaluacion is None


# ------------------------------ API -----------------------------------------

DB = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@127.0.0.1:55433/aptm_proto")
CLAVE = "clave-diario-s10-123"


def _hay_base():
    try:
        import psycopg2

        psycopg2.connect(DB, connect_timeout=1).close()
        return True
    except Exception:
        return False


@pytest.fixture()
def api(monkeypatch):
    if not _hay_base():
        pytest.skip("requiere PostgreSQL")
    from fastapi.testclient import TestClient

    import app.main as main_mod
    import app.prototipo_api as proto

    monkeypatch.setenv("DATABASE_URL", DB)
    importlib.reload(main_mod)
    monkeypatch.setattr(main_mod, "PBKDF2_ITERACIONES", 1_000)
    main_mod.init_db()
    monkeypatch.setattr(proto, "ANALIZADOR", AnalizadorFalso("negativo", 0.97, "tristeza"))
    nombre = f"est_s10_{secrets.token_hex(4)}"
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO usuarios_estudiantes (keycloack_id, nombre_usuario, correo, password_hash, nombres, apellido_paterno)
                VALUES (%s, %s, %s, %s, 'Ana', 'Prueba') RETURNING id_usuario
                """,
                (f"local-{nombre}", nombre, f"{nombre}@prueba.local", main_mod.hash_password(CLAVE)),
            )
            id_usuario = cur.fetchone()["id_usuario"]
        conn.commit()
    cliente = TestClient(main_mod.app)
    r = cliente.post("/auth/login", json={"username": nombre, "password": CLAVE})
    assert r.status_code == 200, r.text
    yield cliente, {"Authorization": f"Bearer {r.json()['access_token']}"}, id_usuario, main_mod
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM alertas_riesgo WHERE perfil_tipo = 'estudiante' AND id_usuario = %s", (id_usuario,))
            cur.execute("DELETE FROM diario_entradas WHERE id_estudiante = %s", (id_usuario,))
            cur.execute("DELETE FROM usuarios_estudiantes WHERE id_usuario = %s", (id_usuario,))
        conn.commit()


def test_api_guarda_negativo_alerta_y_el_alumno_ve_lo_que_marco(api):
    cliente, cabecera, id_usuario, main_mod = api
    r = cliente.post(
        "/diario/entradas",
        headers=cabecera,
        json={"polaridad": "positivo", "emociones": ["alegria"], "texto": "Me siento mal y quiero morirme"},
    )
    assert r.status_code == 200, r.text
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT polaridad FROM diario_entradas WHERE id_estudiante = %s", (id_usuario,))
            assert cur.fetchone()["polaridad"] == "negativo"
            cur.execute(
                "SELECT COUNT(*) AS n FROM alertas_riesgo WHERE perfil_tipo = 'estudiante' AND id_usuario = %s",
                (id_usuario,),
            )
            assert cur.fetchone()["n"] >= 1
    semana = cliente.get("/diario/entradas", headers=cabecera).json()["entradas"]
    assert semana[-1]["polaridad"] == "positivo"


def test_api_respeta_al_alumno_sin_riesgo(api):
    cliente, cabecera, id_usuario, main_mod = api
    r = cliente.post(
        "/diario/entradas",
        headers=cabecera,
        json={"polaridad": "negativo", "emociones": ["tristeza"], "texto": "Mi día fue el mismo de siempre"},
    )
    assert r.status_code == 200, r.text
    with main_mod.db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT polaridad FROM diario_entradas WHERE id_estudiante = %s", (id_usuario,))
            assert cur.fetchone()["polaridad"] == "negativo"
