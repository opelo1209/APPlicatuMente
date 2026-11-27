"""VADER como cuarto modelo del analizador (Semana 10).

VADER (Hutto y Gilbert, 2014) es un analizador de léxico y reglas: suma la
valencia de cada palabra de un diccionario en inglés (~7,500 entradas
calificadas por personas) y la ajusta con cinco heurísticas (signos de
exclamación, mayúsculas, intensificadores, «but» y negación). Devuelve
``neg``, ``neu``, ``pos`` y ``compound`` en [-1, 1]. No tiene pesos que
reentrenar, así que «reentrenar VADER» aquí significa tres variantes que
aprenden solo de los datos de entrenamiento:

  vader_clasico   umbrales fijos ±0.05 de la presentación del asesor
                  (compound > 0.05 positivo, < -0.05 negativo, otro neutro)
  vader_umbral    los dos umbrales que dan mejor F1 macro en entrenamiento
  vader_ajustado  regresión logística balanceada sobre las 4 salidas de VADER
                  más las características que la presentación propone en sus
                  conclusiones: palabras positivas, negativas, intensificadores,
                  negaciones, longitud y palabras únicas

Como el léxico es inglés, VADER lee ``Ejemplo.texto_en`` (traducción local,
ver traducir.py), igual que el segundo ejemplo de la presentación, donde las
frases en español se tradujeron al inglés antes de puntuarlas.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from functools import lru_cache
from typing import Mapping, Sequence

from .datos import Ejemplo
from .metricas_clases import f1_macro

UMBRAL_CLASICO = 0.05
PASO_UMBRAL = 0.05
NOMBRES_CARACTERISTICAS = (
    "neg", "neu", "pos", "compound",
    "palabras_positivas", "palabras_negativas", "intensificadores",
    "negaciones", "longitud", "palabras_unicas",
)


def etiqueta_por_compound(compound: float, umbral_neg: float = -UMBRAL_CLASICO,
                          umbral_pos: float = UMBRAL_CLASICO) -> str:
    if compound > umbral_pos:
        return "positivo"
    if compound < umbral_neg:
        return "negativo"
    return "neutro"


def ajustar_umbrales(compounds: Sequence[float], etiquetas: Sequence[str],
                     paso: float = PASO_UMBRAL) -> tuple[float, float, float]:
    """Busca (umbral_neg, umbral_pos) con umbral_neg <= umbral_pos que maximiza
    el F1 macro en los datos dados. Empates: el par más cercano a ±0.05."""
    pasos = round(1 / paso)
    rejilla = [round(i * paso, 4) for i in range(-pasos + 1, pasos)]
    mejor = (-1.0, 0.0, 0.0, 0.0)
    for neg in rejilla:
        for pos in (p for p in rejilla if p >= neg):
            predichas = [etiqueta_por_compound(c, neg, pos) for c in compounds]
            f1 = f1_macro(etiquetas, predichas)
            distancia = abs(neg + UMBRAL_CLASICO) + abs(pos - UMBRAL_CLASICO)
            if f1 > mejor[0] or (f1 == mejor[0] and distancia < mejor[3]):
                mejor = (f1, neg, pos, distancia)
    return mejor[1], mejor[2], mejor[0]


def caracteristicas_lexicas(texto: str, lexico: Mapping[str, float], intensificadores: Mapping[str, float],
                            negaciones: Sequence[str]) -> dict[str, float]:
    """Conteos de la diapositiva de conclusiones de la presentación."""
    palabras = [p.strip(".,!?;:\"'()").lower() for p in texto.split()]
    palabras = [p for p in palabras if p]
    negadoras = {n.lower() for n in negaciones}
    return {
        "palabras_positivas": float(sum(lexico.get(p, 0) > 0 for p in palabras)),
        "palabras_negativas": float(sum(lexico.get(p, 0) < 0 for p in palabras)),
        "intensificadores": float(sum(p in intensificadores for p in palabras)),
        "negaciones": float(sum(p in negadoras or p.endswith("n't") for p in palabras)),
        "longitud": float(len(palabras)),
        "palabras_unicas": float(len(set(palabras))),
    }


@lru_cache(maxsize=1)
def _analizador():
    from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer

    return SentimentIntensityAnalyzer()


def puntuar(textos: Sequence[str]) -> list[dict[str, float]]:
    """Las cuatro salidas de VADER más las características léxicas."""
    from vaderSentiment.vaderSentiment import BOOSTER_DICT, NEGATE

    analizador = _analizador()
    filas = []
    for texto in textos:
        base = analizador.polarity_scores(texto or "")
        filas.append({**base, **caracteristicas_lexicas(texto or "", analizador.lexicon, BOOSTER_DICT, NEGATE)})
    return filas


def _textos(ejemplos: Sequence[Ejemplo]) -> list[str]:
    faltan = sum(not e.texto_en for e in ejemplos)
    if faltan:
        raise ValueError(f"{faltan} ejemplos sin texto_en: traducir primero (entrenamiento.traducir)")
    return [e.texto_en for e in ejemplos]


@dataclass
class VaderClasico:
    nombre: str = "vader_clasico"

    def ajustar(self, ejemplos: Sequence[Ejemplo]) -> "VaderClasico":
        return self

    def predecir(self, ejemplos: Sequence[Ejemplo]) -> list[str]:
        return [etiqueta_por_compound(f["compound"]) for f in puntuar(_textos(ejemplos))]


@dataclass
class VaderUmbral:
    nombre: str = "vader_umbral"
    umbrales: tuple[float, float] = (-UMBRAL_CLASICO, UMBRAL_CLASICO)

    def ajustar(self, ejemplos: Sequence[Ejemplo]) -> "VaderUmbral":
        compounds = [f["compound"] for f in puntuar(_textos(ejemplos))]
        neg, pos, _ = ajustar_umbrales(compounds, [e.etiqueta for e in ejemplos])
        return VaderUmbral(self.nombre, (neg, pos))

    def predecir(self, ejemplos: Sequence[Ejemplo]) -> list[str]:
        neg, pos = self.umbrales
        return [etiqueta_por_compound(f["compound"], neg, pos) for f in puntuar(_textos(ejemplos))]


@dataclass
class VaderAjustado:
    nombre: str = "vader_ajustado"
    modelo: object = field(default=None, repr=False)

    @staticmethod
    def _matriz(ejemplos: Sequence[Ejemplo]) -> list[list[float]]:
        return [[f[n] for n in NOMBRES_CARACTERISTICAS] for f in puntuar(_textos(ejemplos))]

    def ajustar(self, ejemplos: Sequence[Ejemplo]) -> "VaderAjustado":
        from sklearn.linear_model import LogisticRegression
        from sklearn.pipeline import make_pipeline
        from sklearn.preprocessing import StandardScaler

        modelo = make_pipeline(StandardScaler(), LogisticRegression(class_weight="balanced", max_iter=2000))
        modelo.fit(self._matriz(ejemplos), [e.etiqueta for e in ejemplos])
        return VaderAjustado(self.nombre, modelo)

    def predecir(self, ejemplos: Sequence[Ejemplo]) -> list[str]:
        if self.modelo is None:
            raise RuntimeError("primero ajustar() con datos de entrenamiento")
        return [str(c) for c in self.modelo.predict(self._matriz(ejemplos))]

    def pesos(self) -> dict[str, dict[str, float]]:
        """Peso de cada característica por clase (variables estandarizadas)."""
        logistica = self.modelo.steps[-1][1]
        return {
            str(clase): {n: round(float(w), 4) for n, w in zip(NOMBRES_CARACTERISTICAS, fila)}
            for clase, fila in zip(logistica.classes_, logistica.coef_)
        }


VARIANTES = (VaderClasico, VaderUmbral, VaderAjustado)
