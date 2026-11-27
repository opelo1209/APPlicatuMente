"""Pruebas del generador aislado en un proceso hijo (app/generador_llm.py).

Motivo (Semana 3): en el servidor, llama.cpp precompilado murio con
"Illegal instruction" (la CPU no tiene AVX2). Dentro del backend, esa caida
habria tumbado todo el servicio. Aislado en un proceso hijo, el backend
sigue vivo y Serena responde con el contenido aprobado.

Los "modelos" de estas pruebas son funciones de bucle falsas que se caen,
tardan o responden; no se carga ningun modelo real.
"""

import os
import sys
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.generador_llm import GeneradorAislado, GeneradorNoDisponible  # noqa: E402

MENSAJES = ({"role": "user", "content": "hola"},)


def bucle_eco(conexion, ruta, hilos):
    while True:
        mensajes = conexion.recv()
        conexion.send(("ok", f"eco: {mensajes[-1]['content']}"))


def bucle_que_se_cae(conexion, ruta, hilos):
    conexion.recv()
    os._exit(132)  # como "Illegal instruction"


def bucle_lento(conexion, ruta, hilos):
    while True:
        conexion.recv()
        time.sleep(30)


def bucle_sin_modelo(conexion, ruta, hilos):
    while True:
        conexion.recv()
        conexion.send(("no", "no existe el modelo"))


def test_responde_desde_el_proceso_hijo():
    g = GeneradorAislado("x.gguf", objetivo=bucle_eco, tiempo_max=20)
    try:
        assert g.generar(MENSAJES) == "eco: hola"
        assert g.generar(MENSAJES) == "eco: hola"  # el hijo se reutiliza
    finally:
        g.cerrar()


def test_si_el_hijo_se_cae_no_se_cae_el_backend():
    g = GeneradorAislado("x.gguf", objetivo=bucle_que_se_cae, tiempo_max=20)
    try:
        with pytest.raises(GeneradorNoDisponible, match="132"):
            g.generar(MENSAJES)
    finally:
        g.cerrar()


def test_tiempo_agotado():
    g = GeneradorAislado("x.gguf", objetivo=bucle_lento, tiempo_max=1)
    try:
        inicio = time.perf_counter()
        with pytest.raises(GeneradorNoDisponible, match="tiempo"):
            g.generar(MENSAJES)
        assert time.perf_counter() - inicio < 10
    finally:
        g.cerrar()


def test_sin_modelo_se_reporta_como_no_disponible():
    g = GeneradorAislado("x.gguf", objetivo=bucle_sin_modelo, tiempo_max=20)
    try:
        with pytest.raises(GeneradorNoDisponible, match="no existe"):
            g.generar(MENSAJES)
    finally:
        g.cerrar()


def test_despues_de_caerse_se_vuelve_a_levantar():
    g = GeneradorAislado("x.gguf", objetivo=bucle_que_se_cae, tiempo_max=20)
    try:
        for _ in range(2):
            with pytest.raises(GeneradorNoDisponible):
                g.generar(MENSAJES)
    finally:
        g.cerrar()


def test_la_configuracion_se_lee_al_usarse_no_al_crearse(monkeypatch):
    # En el servidor el generador se crea al importar prototipo_api, ANTES
    # de que main.py cargue demo.env: si leyera SERENA_MODELO al crearse, se
    # quedaria "sin modelo" para siempre (paso al publicarlo).
    monkeypatch.delenv("SERENA_MODELO", raising=False)
    g = GeneradorAislado(objetivo=bucle_eco, tiempo_max=20)
    monkeypatch.setenv("SERENA_MODELO", "/ruta/modelo.gguf")
    try:
        assert g.generar(MENSAJES) == "eco: hola"
        assert g.nombre == "modelo.gguf"
    finally:
        g.cerrar()


# --------------------------------------------------------------------------
# Fase 5: generacion por partes, con corte temprano
# --------------------------------------------------------------------------


def bucle_por_partes(conexion, ruta, hilos):
    """Imita al modelo real: manda la respuesta palabra por palabra y se
    detiene si el proceso padre le pide parar."""
    while True:
        pedido = conexion.recv()
        if pedido == "parar":  # llego tarde, despues de terminar: se ignora
            continue
        if not (isinstance(pedido, dict) and pedido.get("partes")):
            conexion.send(("ok", "completo"))
            continue
        for i, palabra in enumerate("Hola. Esta es una respuesta muy larga que sigue y sigue".split()):
            conexion.send(("parte", ("" if i == 0 else " ") + palabra))
            time.sleep(0.05)
            if conexion.poll(0) and conexion.recv() == "parar":
                break
        conexion.send(("fin", ""))


def test_generar_partes_entrega_el_texto_poco_a_poco():
    g = GeneradorAislado("x.gguf", objetivo=bucle_por_partes, tiempo_max=20)
    try:
        partes = list(g.generar_partes(MENSAJES, max_tokens=60))
        assert len(partes) > 3
        assert "".join(partes).startswith("Hola. Esta es")
    finally:
        g.cerrar()


def test_cortar_a_la_mitad_detiene_al_modelo_y_lo_deja_listo():
    g = GeneradorAislado("x.gguf", objetivo=bucle_por_partes, tiempo_max=20)
    try:
        partes = g.generar_partes(MENSAJES, max_tokens=60)
        # Semana 5 (CI): se cronometra desde la primera palabra. Antes
        # contaba tambien el arranque del proceso hijo, que en un entorno
        # nuevo (sin bytecode en cache) pasa de 2 s; lo que importa aqui es
        # que el corte sea inmediato.
        inicio = None
        texto = ""
        for p in partes:
            inicio = inicio or time.perf_counter()
            texto += p
            if "." in texto:
                partes.close()  # el consumidor ya tiene su oracion
                break
        assert texto == "Hola."
        assert time.perf_counter() - inicio < 2
        # El mismo proceso sigue sirviendo despues del corte.
        assert g.generar(MENSAJES) == "completo"
    finally:
        g.cerrar()


def test_si_el_proceso_se_cae_a_media_respuesta_se_reporta():
    g = GeneradorAislado("x.gguf", objetivo=bucle_que_se_cae, tiempo_max=20)
    try:
        with pytest.raises(GeneradorNoDisponible):
            list(g.generar_partes(MENSAJES, max_tokens=60))
    finally:
        g.cerrar()


# Semana 4: servidor con GPU (SERENA_CAPAS_GPU).
def test_capas_gpu_por_omision_es_solo_cpu(monkeypatch):
    from app.generador_llm import capas_gpu_de_entorno

    monkeypatch.delenv("SERENA_CAPAS_GPU", raising=False)
    assert capas_gpu_de_entorno() == 0
    monkeypatch.setenv("SERENA_CAPAS_GPU", "-1")
    assert capas_gpu_de_entorno() == -1
    monkeypatch.setenv("SERENA_CAPAS_GPU", "todas")
    assert capas_gpu_de_entorno() == 0
