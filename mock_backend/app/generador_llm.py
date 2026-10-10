"""Generador de respuestas de Serena con un LLM pequeno local (llama.cpp).

PROTOTIPO (Semana 3). Corre en el propio servidor, en CPU, sin mandar
mensajes de estudiantes a terceros. El modelo es la pieza MENOS confiable de
la cadena: antes lo protegen la barrera de riesgo y la de limites, y despues
la guardia de salida.

Configuracion por variables de entorno:
  SERENA_MODELO   ruta al archivo .gguf (si no existe, Serena responde solo
                  con el contenido recuperado, sin LLM)
  SERENA_HILOS    hilos de CPU (por omision 2, igual que CPUQuota=200%)
"""

from __future__ import annotations

import logging
import os
import threading
import time
from typing import Iterator, Mapping, Protocol

log = logging.getLogger("aptm.serena")


class GeneradorNoDisponible(RuntimeError):
    pass


class GeneradorRespuesta(Protocol):
    nombre: str

    def generar(self, mensajes: tuple[Mapping[str, str], ...], max_tokens: int | None = None) -> str: ...


class GeneradorLlama:
    MAX_TOKENS = 170

    def __init__(self, ruta: str | None = None, hilos: int | None = None) -> None:
        self.ruta = ruta or os.getenv("SERENA_MODELO", "")
        self.hilos = hilos or int(os.getenv("SERENA_HILOS", "2"))
        self.nombre = os.path.basename(self.ruta) or "sin modelo"
        self._llm = None
        # llama.cpp no es seguro para dos generaciones a la vez en el mismo
        # objeto: las peticiones esperan su turno.
        self._candado = threading.Lock()

    def _cargar(self) -> None:
        if self._llm is not None:
            return
        if not self.ruta or not os.path.exists(self.ruta):
            raise GeneradorNoDisponible(f"no existe el modelo: {self.ruta!r}")
        try:
            from llama_cpp import Llama
        except ImportError as exc:
            raise GeneradorNoDisponible("llama-cpp-python no esta instalado") from exc
        try:
            # n_threads_batch (hilos para procesar el prompt) vale por omision
            # el numero de nucleos de la maquina (8 en el servidor): con
            # CPUQuota=200% eso congelaba el servicio el 80 % del tiempo y la
            # respuesta pasaba de ~18 s a ~65 s. Se fija igual que n_threads.
            self._llm = Llama(
                model_path=self.ruta,
                n_ctx=2048,
                n_threads=self.hilos,
                n_threads_batch=self.hilos,
                verbose=False,
            )
        except (ValueError, OSError) as exc:
            # Archivo danado o incompleto (paso con una descarga cortada):
            # Serena sigue respondiendo con el contenido aprobado.
            raise GeneradorNoDisponible(f"no se pudo cargar {self.nombre}: {exc}") from exc
        log.info("modelo de Serena cargado: %s (%s hilos)", self.nombre, self.hilos)

    def generar(self, mensajes: tuple[Mapping[str, str], ...], max_tokens: int | None = None) -> str:
        with self._candado:
            self._cargar()
            salida = self._llm.create_chat_completion(  # type: ignore[union-attr]
                messages=[dict(m) for m in mensajes],
                max_tokens=max_tokens or self.MAX_TOKENS,
                temperature=0.3,
                top_p=0.9,
                repeat_penalty=1.1,
            )
        return (salida["choices"][0]["message"]["content"] or "").strip()

    def generar_partes(self, mensajes: tuple[Mapping[str, str], ...], max_tokens: int | None = None) -> Iterator[str]:
        """Fase 5: la respuesta pedazo a pedazo. Si quien la consume deja de
        pedir, la generacion se detiene (no se gastan los tokens restantes)."""
        with self._candado:
            self._cargar()
            flujo = self._llm.create_chat_completion(  # type: ignore[union-attr]
                messages=[dict(m) for m in mensajes],
                max_tokens=max_tokens or self.MAX_TOKENS,
                temperature=0.3,
                top_p=0.9,
                repeat_penalty=1.1,
                stream=True,
            )
            for pedazo in flujo:
                texto = pedazo["choices"][0]["delta"].get("content") or ""
                if texto:
                    yield texto


# --------------------------------------------------------------------------
# Generador aislado en un proceso hijo
# --------------------------------------------------------------------------
# En el servidor, llama.cpp precompilado murio con "Illegal instruction" (la
# CPU no tiene AVX2): una caida asi dentro del backend tumba todo el
# servicio. Aqui el modelo vive en un proceso aparte; si se cae o tarda mas
# de SERENA_TIEMPO_MAX segundos, el backend sigue y Serena responde con el
# contenido aprobado.


def _enviar_por_partes(conexion, generador, mensajes, max_tokens) -> None:
    """Fase 5: manda ("parte", texto) por cada pedazo y ("fin", "") al final.
    Entre pedazos revisa si el proceso padre pidio "parar"."""
    try:
        for texto in generador.generar_partes(mensajes, max_tokens):
            conexion.send(("parte", texto))
            if conexion.poll(0) and conexion.recv() == "parar":
                break
        conexion.send(("fin", ""))
    except GeneradorNoDisponible as exc:
        conexion.send(("no", str(exc)))


def _bucle_modelo(conexion, ruta: str, hilos: int) -> None:
    generador = GeneradorLlama(ruta, hilos)
    while True:
        # Fase 4: llega una lista de mensajes, o un dict con "max_tokens".
        pedido = conexion.recv()
        if pedido == "parar":  # llego despues de terminar: se ignora
            continue
        mensajes, max_tokens = (pedido["mensajes"], pedido.get("max_tokens")) if isinstance(pedido, dict) else (pedido, None)
        if isinstance(pedido, dict) and pedido.get("partes"):
            _enviar_por_partes(conexion, generador, mensajes, max_tokens)
            continue
        try:
            conexion.send(("ok", generador.generar(mensajes, max_tokens)))
        except GeneradorNoDisponible as exc:
            conexion.send(("no", str(exc)))


class GeneradorAislado:
    def __init__(self, ruta: str | None = None, hilos: int | None = None, objetivo=_bucle_modelo, tiempo_max: float | None = None) -> None:
        # La configuracion se lee al USARSE: el objeto se crea al importar
        # prototipo_api, antes de que main.py cargue demo.env.
        self._ruta, self._hilos, self._tiempo_max = ruta, hilos, tiempo_max
        self._objetivo = objetivo
        self._proceso = None
        self._conexion = None
        self._candado = threading.Lock()
        # Velocidad (cierre S3): cuando termino el ultimo pedido, para que
        # mantener_caliente() sepa si el modelo lleva rato sin usarse.
        self.ultimo_uso = 0.0

    @property
    def ruta(self) -> str:
        return self._ruta or os.getenv("SERENA_MODELO", "")

    @property
    def hilos(self) -> int:
        return self._hilos or int(os.getenv("SERENA_HILOS", "2"))

    @property
    def tiempo_max(self) -> float:
        return self._tiempo_max or float(os.getenv("SERENA_TIEMPO_MAX", "90"))

    @property
    def nombre(self) -> str:
        return os.path.basename(self.ruta) or "sin modelo"

    def _arrancar(self) -> None:
        import multiprocessing

        if self._proceso is not None and self._proceso.is_alive():
            return
        if not self.ruta:
            raise GeneradorNoDisponible("no hay modelo configurado (SERENA_MODELO)")
        contexto = multiprocessing.get_context("spawn")
        padre, hijo = contexto.Pipe()
        self._proceso = contexto.Process(target=self._objetivo, args=(hijo, self.ruta, self.hilos), daemon=True)
        self._proceso.start()
        self._conexion = padre

    def _detener(self) -> None:
        if self._proceso is not None and self._proceso.is_alive():
            self._proceso.kill()
            self._proceso.join(timeout=5)
        self._proceso = None
        self._conexion = None

    def cerrar(self) -> None:
        with self._candado:
            self._detener()

    def _caido(self, exc: BaseException) -> GeneradorNoDisponible:
        codigo = None
        if self._proceso is not None:
            self._proceso.join(timeout=5)
            codigo = self._proceso.exitcode
        self._detener()
        log.error("el proceso del modelo termino (codigo %s)", codigo)
        return GeneradorNoDisponible(f"el proceso del modelo termino (codigo {codigo})")

    def _parar_y_drenar(self) -> None:
        """El consumidor ya no quiere mas: se pide parar y se descartan los
        pedazos en camino hasta el "fin", para que el siguiente pedido no
        reciba restos del anterior. Si no contesta a tiempo, se reinicia."""
        try:
            self._conexion.send("parar")  # type: ignore[union-attr]
            while self._conexion.poll(self.tiempo_max):  # type: ignore[union-attr]
                estado, _ = self._conexion.recv()  # type: ignore[union-attr]
                if estado in ("fin", "no"):
                    return
        except (EOFError, BrokenPipeError, ConnectionResetError, OSError):
            pass
        self._detener()

    def generar_partes(self, mensajes: tuple[Mapping[str, str], ...], max_tokens: int | None = None) -> Iterator[str]:
        with self._candado:
            self._arrancar()
            pedido = {"mensajes": [dict(m) for m in mensajes], "max_tokens": max_tokens, "partes": True}
            terminado = False
            try:
                self._conexion.send(pedido)  # type: ignore[union-attr]
                while True:
                    if not self._conexion.poll(self.tiempo_max):  # type: ignore[union-attr]
                        terminado = True
                        self._detener()
                        raise GeneradorNoDisponible(f"el modelo no respondio a tiempo ({self.tiempo_max:.0f} s)")
                    estado, valor = self._conexion.recv()  # type: ignore[union-attr]
                    if estado == "parte":
                        yield valor
                    elif estado == "fin":
                        terminado = True
                        return
                    else:
                        terminado = True
                        raise GeneradorNoDisponible(valor)
            except (EOFError, BrokenPipeError, ConnectionResetError, OSError) as exc:
                terminado = True
                raise self._caido(exc) from exc
            finally:
                if not terminado and self._conexion is not None:
                    self._parar_y_drenar()
                self.ultimo_uso = time.monotonic()

    def generar(self, mensajes: tuple[Mapping[str, str], ...], max_tokens: int | None = None) -> str:
        with self._candado:
            self._arrancar()
            lista = [dict(m) for m in mensajes]
            pedido = lista if max_tokens is None else {"mensajes": lista, "max_tokens": max_tokens}
            try:
                self._conexion.send(pedido)  # type: ignore[union-attr]
                if not self._conexion.poll(self.tiempo_max):  # type: ignore[union-attr]
                    self._detener()
                    raise GeneradorNoDisponible(f"el modelo no respondio a tiempo ({self.tiempo_max:.0f} s)")
                estado, valor = self._conexion.recv()  # type: ignore[union-attr]
            except (EOFError, BrokenPipeError, ConnectionResetError, OSError) as exc:
                raise self._caido(exc) from exc
            finally:
                self.ultimo_uso = time.monotonic()
        if estado != "ok":
            raise GeneradorNoDisponible(valor)
        return valor
