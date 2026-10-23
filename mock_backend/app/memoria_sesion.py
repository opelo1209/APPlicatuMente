"""Memoria de la conversacion con Serena (Fase 2 del plan de mejora, Semana 3).

PROTOTIPO. Sin memoria, cada mensaje se evaluaba solo: "ya lo decidi"
despues de "sin ella nada tiene sentido" pasaba como charla normal, y la
respuesta que pedia "cuentame mas" no sabia de que se hablaba.

Decision de privacidad (pendiente de psicologia y del asesor): la memoria
vive SOLO en la RAM del servicio. No se escribe en la base de datos, guarda
como maximo MAX_TURNOS por sesion, caduca TTL_SEGUNDOS despues del ultimo
mensaje, se borra al limpiar la conversacion y se pierde al reiniciar el
servicio.
"""

from __future__ import annotations

import fcntl
import os
import tempfile
import threading
import time
from dataclasses import dataclass, replace
from typing import IO, Callable

MAX_TURNOS = 10
TTL_SEGUNDOS = 2 * 60 * 60
TURNOS_RACHA = 3  # turnos negativos seguidos (contando el actual) para R10

SENAL_ALTA = "alta"
SENAL_AMBIGUA = "ambigua"
SENAL_NINGUNA = "ninguna"


@dataclass(frozen=True)
class Turno:
    texto: str
    respuesta: str
    tipo: str
    senal: str
    polaridad: str | None
    momento: float


class MemoriaSesiones:
    def __init__(
        self,
        max_turnos: int = MAX_TURNOS,
        ttl_segundos: float = TTL_SEGUNDOS,
        reloj: Callable[[], float] = time.monotonic,
    ) -> None:
        self._max = max_turnos
        self._ttl = ttl_segundos
        self._reloj = reloj
        self._sesiones: dict[str, tuple[Turno, ...]] = {}
        self._candado = threading.Lock()

    def _vigentes(self, sesion: str) -> tuple[Turno, ...]:
        turnos = self._sesiones.get(sesion, ())
        if turnos and self._reloj() - turnos[-1].momento > self._ttl:
            self._sesiones.pop(sesion, None)
            return ()
        return turnos

    def turnos(self, sesion: str) -> tuple[Turno, ...]:
        with self._candado:
            return self._vigentes(sesion)

    def agregar(self, sesion: str, turno: Turno) -> None:
        with self._candado:
            sellado = replace(turno, momento=self._reloj())
            nuevos = (*self._vigentes(sesion), sellado)[-self._max :]
            self._sesiones = {**self._sesiones, sesion: nuevos}

    def borrar(self, sesion: str) -> None:
        with self._candado:
            self._sesiones = {k: v for k, v in self._sesiones.items() if k != sesion}

    def ahora(self) -> float:
        return self._reloj()


class VariosProcesos(RuntimeError):
    """El servicio arranco con mas de un worker y la memoria no lo soporta."""


def ruta_candado() -> str:
    return os.getenv("SERENA_CANDADO") or os.path.join(tempfile.gettempdir(), f"aptm-serena-{os.getuid()}.lock")


def reservar_proceso_unico(ruta: str | None = None) -> IO[str]:
    """Semana 5 (H7). La memoria vive en la RAM de un proceso: con varios
    workers, cada mensaje caeria en uno distinto y la regla R14 (senales
    repetidas en la conversacion) dejaria de cumplirse sin que nadie lo
    notara. Guardarla en la base cambiaria la decision de privacidad, que
    corresponde a psicologia y al asesor; mientras tanto, el segundo worker
    se niega a arrancar.

    Devuelve el archivo con el candado; hay que mantenerlo abierto mientras
    viva el proceso (el sistema lo suelta solo al terminar)."""
    archivo = open(ruta or ruta_candado(), "w", encoding="utf-8")  # noqa: SIM115
    try:
        fcntl.flock(archivo, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        archivo.close()
        raise VariosProcesos(
            "La memoria de Serena solo funciona con un worker (memoria_sesion.py). "
            "Arranca uvicorn sin --workers o con --workers 1."
        ) from None
    archivo.write(str(os.getpid()))
    archivo.flush()
    return archivo


def hechos_de_sesion(turnos: tuple[Turno, ...]) -> frozenset[str]:
    """Hechos para el motor de Wang a partir de los turnos ANTERIORES.

    Una crisis previa cuenta tambien como senal previa: si la conversacion
    sigue despues de la pausa, el contexto no se olvida.
    """
    con_senal = sum(1 for t in turnos if t.senal in (SENAL_AMBIGUA, SENAL_ALTA))
    hechos = set()
    if con_senal >= 1:
        hechos.add("ambigua_previa")
    if con_senal >= 2:
        hechos.add("ambigua_repetida")
    # Semana 4: el chat ya no se pausa en crisis; lo que sigue es acompanar.
    if any(t.senal == SENAL_ALTA for t in turnos):
        hechos.add("crisis_previa")
    # R10 exige ademas que el mensaje actual sea negativo: aqui se cuentan
    # los TURNOS_RACHA - 1 anteriores.
    previos = turnos[-(TURNOS_RACHA - 1) :]
    if len(previos) == TURNOS_RACHA - 1 and all(t.polaridad == "negativo" for t in previos):
        hechos.add("racha_negativa")
    return frozenset(hechos)
