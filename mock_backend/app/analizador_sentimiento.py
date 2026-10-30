"""Analizador de sentimientos y emociones en espanol (adaptador).

PROTOTIPO (Semana 2). Envuelve pysentimiento (modelos RoBERTuito, Perez et
al.) detras de una interfaz propia, AnalizadorSentimiento, para que:

  - el evaluador del diario y Serena no dependan de una libreria concreta
    (si se cambia de modelo solo cambia este archivo);
  - las pruebas usen un analizador falso, sin descargar modelos.

pysentimiento NO esta en requirements.txt a proposito: trae PyTorch
(~1 GB) y descarga los modelos de Hugging Face la primera vez. Antes de
agregarlo a produccion hay que decidir donde corre (ver reporte, Semana 2).

Limitaciones conocidas (medidas por sus autores sobre tuits, no sobre
diarios): F1 macro 0.705 en polaridad y 0.560 en emociones. Ver la
evaluacion propia con textos de diario en el reporte.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from .emociones_catalogo import (
    CLASE_ALEGRIA,
    CLASE_ASCO,
    CLASE_ENOJO,
    CLASE_MIEDO,
    CLASE_OTRA,
    CLASE_SORPRESA,
    CLASE_TRISTEZA,
    POLARIDAD_NEGATIVA,
    POLARIDAD_NEUTRA,
    POLARIDAD_POSITIVA,
)

# Etiquetas de pysentimiento -> nombres propios del proyecto.
_POLARIDAD = {"POS": POLARIDAD_POSITIVA, "NEU": POLARIDAD_NEUTRA, "NEG": POLARIDAD_NEGATIVA}
_EMOCION = {
    "joy": CLASE_ALEGRIA,
    "sadness": CLASE_TRISTEZA,
    "anger": CLASE_ENOJO,
    "fear": CLASE_MIEDO,
    "surprise": CLASE_SORPRESA,
    "disgust": CLASE_ASCO,
    "others": CLASE_OTRA,
}

MAX_CARACTERES = 2000  # el modelo trunca a 128 tokens; se avisa en el reporte


class AnalizadorNoDisponible(RuntimeError):
    """El modelo no esta instalado o no cargo. El diario debe seguir
    funcionando sin el analisis automatico, nunca romperse por esto."""


@dataclass(frozen=True)
class ResultadoSentimiento:
    polaridad: str
    probabilidades_polaridad: tuple[tuple[str, float], ...]
    emociones: tuple[tuple[str, float], ...]  # ordenadas de mayor a menor
    modelo: str

    def probabilidad(self, polaridad: str) -> float:
        return dict(self.probabilidades_polaridad).get(polaridad, 0.0)

    def emocion_principal(self) -> str:
        return self.emociones[0][0] if self.emociones else CLASE_OTRA

    def puntaje(self) -> float:
        """Semana 6 (asesor): P(positivo) - P(negativo), de -1 a 1."""
        return round(self.probabilidad(POLARIDAD_POSITIVA) - self.probabilidad(POLARIDAD_NEGATIVA), 4)


def polaridad_por_intervalo(resultado: ResultadoSentimiento, izquierda: float = 0.0, derecha: float = 0.0) -> str:
    """Semana 6 (asesor): el neutro como intervalo [-izquierda, derecha]
    alrededor de cero en el puntaje. Si el modelo ya dijo neutro, se queda;
    con el intervalo en cero da la clase mas probable, como hasta ahora.
    La app todavia no lo usa: se mide con bateria/intervalo.py."""
    if not (0.0 <= izquierda <= 1.0 and 0.0 <= derecha <= 1.0):
        raise ValueError("los lados del intervalo van de 0 a 1")
    if resultado.polaridad == POLARIDAD_NEUTRA:
        return POLARIDAD_NEUTRA
    puntaje = resultado.puntaje()
    if -izquierda <= puntaje <= derecha:
        return POLARIDAD_NEUTRA
    return POLARIDAD_POSITIVA if puntaje > 0 else POLARIDAD_NEGATIVA


class AnalizadorSentimiento(Protocol):
    def analizar(self, texto: str) -> ResultadoSentimiento: ...


def _ordenar(probas: dict[str, float], nombres: dict[str, str]) -> tuple[tuple[str, float], ...]:
    pares = ((nombres[etiqueta], round(float(p), 4)) for etiqueta, p in probas.items() if etiqueta in nombres)
    return tuple(sorted(pares, key=lambda par: par[1], reverse=True))


class AnalizadorPysentimiento:
    """Carga los dos modelos la primera vez que se usan (tarda segundos y
    ocupa ~1 GB de RAM entre los dos)."""

    MODELO = "pysentimiento/robertuito-sentiment-analysis + robertuito-emotion-analysis"

    def __init__(self) -> None:
        self._sentimiento = None
        self._emocion = None

    def _cargar(self) -> None:
        if self._sentimiento is not None:
            return
        try:
            from pysentimiento import create_analyzer
        except ImportError as exc:
            raise AnalizadorNoDisponible("pysentimiento no esta instalado") from exc
        try:
            # En el servidor el servicio tiene CPUQuota=200%: PyTorch abre por
            # omision un hilo por nucleo (8) y esos hilos compiten con el
            # modelo de Serena por la misma cuota (la respuesta paso de ~18 s
            # a ~65 s). Se limita a ANALIZADOR_HILOS (2).
            import os

            import torch

            torch.set_num_threads(int(os.getenv("ANALIZADOR_HILOS", "2")))
            self._sentimiento = create_analyzer(task="sentiment", lang="es")
            self._emocion = create_analyzer(task="emotion", lang="es")
        except Exception as exc:  # descarga o carga del modelo
            raise AnalizadorNoDisponible(f"no se pudo cargar el modelo: {exc}") from exc

    def analizar(self, texto: str) -> ResultadoSentimiento:
        texto = (texto or "").strip()
        if not texto:
            raise ValueError("no hay texto que analizar")
        self._cargar()
        texto = texto[:MAX_CARACTERES]
        sentimiento = self._sentimiento.predict(texto)
        emocion = self._emocion.predict(texto)
        return ResultadoSentimiento(
            polaridad=_POLARIDAD[sentimiento.output],
            probabilidades_polaridad=_ordenar(sentimiento.probas, _POLARIDAD),
            emociones=_ordenar(emocion.probas, _EMOCION),
            modelo=self.MODELO,
        )
