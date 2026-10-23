"""Semana 5: la bateria del analizador (bateria/) mide bien y no se rompe.

No usa pysentimiento: un analizador falso que responde lo que se le diga.
"""
import hashlib
import json
from collections import Counter
from types import SimpleNamespace

import pytest

from bateria import ejecutar, tablero
from bateria.metricas import POLARIDADES, evaluar
from tests.test_evaluador_diario import AnalizadorFalso


# ------------------------------ conjunto -----------------------------------


def test_el_conjunto_tiene_20_frases_de_cada_polaridad_y_no_cambio():
    datos, sha = ejecutar.cargar_frases()
    assert Counter(f["polaridad"] for f in datos["frases"]) == {"negativo": 20, "neutro": 20, "positivo": 20}
    sellado = (ejecutar.AQUI / "frases_s5.sha256").read_text().split()[0]
    assert sha == sellado, "frases_s5.json cambio despues de sellarse: crear frases_s6.json en su lugar"


def test_cada_frase_trae_emociones_validas_del_diario():
    from app.emociones_catalogo import buscar

    datos, _ = ejecutar.cargar_frases()
    for f in datos["frases"]:
        assert f["emocion"] in datos["clases_emocion"]
        assert all(buscar(c).polaridad == f["polaridad"] for c in f["emociones_diario"]), f["id"]


def test_ninguna_frase_es_de_crisis():
    # La bateria corre en el servidor: no debe crear alertas reales.
    from app.clasificador_riesgo import NIVEL_NINGUNO, clasificar_mensaje

    datos, _ = ejecutar.cargar_frases()
    assert all(clasificar_mensaje(f["texto"]).nivel == NIVEL_NINGUNO for f in datos["frases"])


# ------------------------------ metricas -----------------------------------


def test_metricas_de_un_caso_calculado_a_mano():
    m = evaluar(["negativo", "negativo", "neutro", "positivo"], ["negativo", "neutro", "neutro", None], POLARIDADES)
    assert m["aciertos"] == 2 and m["exactitud"] == 0.5
    assert m["por_clase"]["negativo"] == {"soporte": 2, "aciertos": 1, "precision": 1.0, "recall": 0.5, "f1": 0.667}
    assert m["por_clase"]["neutro"]["precision"] == 0.5
    assert m["por_clase"]["positivo"]["recall"] == 0.0
    assert m["sin_clase"] == 1 and m["columnas"][-1] == "sin_clase"
    assert m["matriz"][2] == [0, 0, 0, 1]


# ------------------------------ modo local ---------------------------------


def test_modo_local_con_un_analizador_que_todo_lo_ve_negativo():
    datos, sha = ejecutar.cargar_frases()
    filas = ejecutar.correr_local(datos["frases"][:6], AnalizadorFalso("negativo", "tristeza", 0.9))
    r = ejecutar.resumir(filas, "local", sha)
    assert r["analizador_polaridad"]["por_clase"]["negativo"]["recall"] == 1.0
    assert all(f["serena_polaridad"] in ("negativo", None) for f in filas)
    assert {"diario_concordancia", "serena_accion", "serena_tipo"} <= set(filas[0])
    assert r["errores_polaridad"] == []  # las 6 primeras son negativas


# ------------------------------- modo api ----------------------------------


class Respuesta(SimpleNamespace):
    def json(self):
        return self.cuerpo

    def raise_for_status(self):
        if self.status_code >= 400:
            raise RuntimeError(self.status_code)


class ClienteFalso:
    """Simula la API: el primer /chat responde 429 (limite por minuto)."""

    def __init__(self):
        self.llamadas, self.chats = [], 0

    def post(self, ruta, json):
        self.llamadas.append(ruta)
        if ruta == "/diario/entradas":
            return Respuesta(status_code=200, headers={}, cuerpo={
                "analisis": {"polaridad": "negativo", "confianza": 0.9, "emociones": [["tristeza", 0.8], ["otra", 0.1]]},
                "concordancia": "coincide", "accion": "normal"})
        self.chats += 1
        if self.chats == 1:
            return Respuesta(status_code=429, headers={"Retry-After": "2"}, cuerpo={})
        return Respuesta(status_code=200, headers={}, cuerpo={"tipo": "normal", "respuesta": "..."})

    def delete(self, ruta):
        self.llamadas.append(f"DELETE {ruta}")


def test_modo_api_respeta_el_limite_y_empieza_cada_frase_sin_historial():
    cliente, esperas = ClienteFalso(), []
    frase = ejecutar.cargar_frases()[0]["frases"][0]
    fila = ejecutar.fila_api(frase, cliente, dormir=esperas.append)
    assert esperas == [2.5]
    assert cliente.llamadas == ["/diario/entradas", "DELETE /chat/historial", "/chat", "/chat"]
    assert fila["pred_polaridad"] == "negativo" and fila["pred_emocion"] == "tristeza"
    assert fila["serena_tipo"] == "normal"


def test_modo_api_falla_si_el_limite_no_cede():
    cliente = SimpleNamespace(post=lambda ruta, json: Respuesta(status_code=429, headers={}, cuerpo={}))
    with pytest.raises(RuntimeError):
        ejecutar._con_reintento(lambda: cliente.post("/chat", {}), dormir=lambda s: None, intentos=2)


def test_el_modo_api_exige_credenciales(monkeypatch, capsys):
    monkeypatch.delenv("BATERIA_USUARIO", raising=False)
    with pytest.raises(SystemExit):
        ejecutar.main(["api", "--url", "http://x"])


# ------------------------------- tablero -----------------------------------


def test_el_tablero_es_un_html_completo_y_escapa_las_frases(tmp_path):
    datos, sha = ejecutar.cargar_frases()
    frases = [dict(datos["frases"][0], texto="<script>alert(1)</script>")] + datos["frases"][20:23]
    # Positivo ante una frase negativa: la frase sale en la tabla de errores.
    filas = ejecutar.correr_local(frases, AnalizadorFalso("positivo", "alegria", 0.9))
    resultado = {"resumen": ejecutar.resumir(filas, "local", sha), "filas": filas}
    entrada, salida = tmp_path / "r.json", tmp_path / "t.html"
    entrada.write_text(json.dumps(resultado), encoding="utf-8")
    tablero.main([str(entrada), str(salida)])
    html = salida.read_text(encoding="utf-8")
    assert html.startswith("<!doctype html>")
    assert "<script>" not in html and "&lt;script&gt;" in html
    assert "Batería del analizador" in html and sha in html
    assert hashlib.sha256(html.encode()).hexdigest()  # se genero completo
