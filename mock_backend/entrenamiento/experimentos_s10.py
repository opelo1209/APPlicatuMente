"""Comparación de cuatro modelos con varios conjuntos de datos (Semana 10).

Pedido del asesor: reentrenar RoBERTuito, TF-IDF y el analizador de
producción con un corpus balanceado (500/500/500), incorporar VADER como
cuarto modelo y reportar métricas por modelo y por clase en entrenamiento y
en prueba, con distintos conjuntos de datos.

Modelos (``MODELOS``):
  robertuito_produccion  pysentimiento tal como lo usa la app (no se entrena)
  robertuito_reentrenado ajuste fino de RoBERTuito (mismo código que la S9)
  tfidf                  TF-IDF de palabras y letras + regresión logística
  vader_clasico          VADER con umbrales ±0.05 (no se entrena)
  vader_umbral           VADER con umbrales aprendidos en entrenamiento
  vader_ajustado         regresión logística sobre salidas y conteos de VADER

Escenarios:
  holdout   se entrena con educativo_entrenamiento (1200) y se mide en el
            mismo entrenamiento, en educativo_prueba (300) y en cualquier
            otro conjunto pasado con --prueba nombre=ruta (clínico,
            italiano, batería sintética).
  mixto     validación cruzada de 5 pliegues sobre el conjunto clínico
            (mismos pliegues y semilla que la S9). En cada pliegue se entrena
            con los pliegues clínicos restantes, con o sin el corpus educativo
            completo, y se mide en el pliegue que quedó fuera.

  final     parte del checkpoint educativo (--base-robertuito) y afina con
            TODO el conjunto clínico; guarda el checkpoint con permisos 700
            en --guardar (debe ser una carpeta privada).
  base      entrena RoBERTuito con el corpus educativo completo y guarda el
            checkpoint (--guardar). Con mixto --base-robertuito <checkpoint>
            se hace el ajuste secuencial: en cada pliegue se parte de ese
            checkpoint y se afina solo con los pliegues clínicos (variante
            ``secuencial``). Aproxima M+E a una fracción del costo en CPU.

Salida: un JSON solo con números (métricas, matrices, intervalos bootstrap) y,
aparte, las predicciones por ejemplo. Si un conjunto se marca como privado
(--privado nombre), sus predicciones se escriben con permisos 600 y nunca
en el JSON compartible.

Uso:
  python -m entrenamiento.experimentos_s10 holdout --entrenamiento edu_ent.jsonl \\
      --prueba educativo=edu_prueba.jsonl --prueba clinico=conjunto_en.jsonl \\
      --privado clinico --salida resultados.json --predicciones pred.json
  python -m entrenamiento.experimentos_s10 mixto --clinico conjunto_en.jsonl \\
      --educativo edu_ent.jsonl --educativo edu_prueba.jsonl --salida mixto.json
"""

from __future__ import annotations

import argparse
from functools import lru_cache
import json
import random
import time
from dataclasses import dataclass, field, replace
from pathlib import Path
from typing import Callable, Sequence

from .datos import Ejemplo, cargar_conjunto, escribir_privado, pliegues
from .metricas_clases import CLASES, exactitud, f1_macro, reporte
from .vader import VaderAjustado, VaderClasico, VaderUmbral

SEMILLA_S9 = 20261112
REMUESTREOS = 1000
# Solo estos conjuntos pueden tener predicciones por ejemplo en un archivo
# compartible; cualquier otro nombre se trata como privado.
CONJUNTOS_PUBLICOS = frozenset({"entrenamiento", "educativo", "italiano", "bateria"})


# --- modelos con la misma interfaz: ajustar(ejemplos) -> modelo; predecir -----

@dataclass
class RobertuitoProduccion:
    nombre: str = "robertuito_produccion"

    def ajustar(self, ejemplos: Sequence[Ejemplo]) -> "RobertuitoProduccion":
        return self

    def predecir(self, ejemplos: Sequence[Ejemplo]) -> list[str]:
        from .linea_base import predecir_original

        return predecir_original([e.texto for e in ejemplos])[0]


@dataclass
class RobertuitoReentrenado:
    nombre: str = "robertuito_reentrenado"
    epocas: int = 3
    tasa: float = 2e-5
    lote: int = 16
    semilla: int = SEMILLA_S9
    base: str = "pysentimiento/robertuito-sentiment-analysis"
    pesos_clase: bool = False
    congelar: int = 0
    estado: tuple = field(default=(), repr=False)

    @staticmethod
    def _dispositivo() -> str:
        import torch

        return "cuda" if torch.cuda.is_available() else "cpu"

    def ajustar(self, ejemplos: Sequence[Ejemplo]) -> "RobertuitoReentrenado":
        from .reentrenar import _entrenar

        tokenizador, modelo = _entrenar(list(ejemplos), self.epocas, self.tasa, self.lote, self.semilla,
                                        self._dispositivo(), self.base, self.pesos_clase, self.congelar)
        return replace(self, estado=(tokenizador, modelo))

    def predecir(self, ejemplos: Sequence[Ejemplo]) -> list[str]:
        from .reentrenar import _predecir

        if not self.estado:
            raise RuntimeError("primero ajustar()")
        return _predecir(*self.estado, [e.texto for e in ejemplos], self._dispositivo())[0]


@dataclass
class Tfidf:
    nombre: str = "tfidf"
    modelo: object = field(default=None, repr=False)

    def ajustar(self, ejemplos: Sequence[Ejemplo]) -> "Tfidf":
        from .alterno import _tfidf

        modelo = _tfidf()
        modelo.fit([e.texto for e in ejemplos], [e.etiqueta for e in ejemplos])
        return Tfidf(self.nombre, modelo)

    def predecir(self, ejemplos: Sequence[Ejemplo]) -> list[str]:
        if self.modelo is None:
            raise RuntimeError("primero ajustar()")
        return [str(c) for c in self.modelo.predict([e.texto for e in ejemplos])]


def _union_tfidf():
    """Las mismas dos bolsas TF-IDF que alterno._tfidf (palabras 1-2 y letras 3-5)."""
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.pipeline import make_union

    return make_union(
        TfidfVectorizer(analyzer="word", ngram_range=(1, 2), strip_accents="unicode", lowercase=True, min_df=1),
        TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5), strip_accents="unicode", lowercase=True, min_df=1),
    )


@dataclass
class _ClasificadorTexto:
    """Base para los modelos de scikit-learn que leen ``Ejemplo.texto``."""

    nombre: str = ""
    modelo: object = field(default=None, repr=False)

    def _fabrica(self):
        raise NotImplementedError

    def ajustar(self, ejemplos: Sequence[Ejemplo]):
        modelo = self._fabrica()
        modelo.fit([e.texto for e in ejemplos], [e.etiqueta for e in ejemplos])
        return replace(self, modelo=modelo)

    def predecir(self, ejemplos: Sequence[Ejemplo]) -> list[str]:
        if self.modelo is None:
            raise RuntimeError("primero ajustar()")
        return [str(c) for c in self.modelo.predict([e.texto for e in ejemplos])]


@dataclass
class SvmTfidf(_ClasificadorTexto):
    """SVM lineal (presentación, diap. 122-136) sobre el mismo TF-IDF."""

    nombre: str = "svm_tfidf"

    def _fabrica(self):
        from sklearn.pipeline import make_pipeline
        from sklearn.svm import LinearSVC

        return make_pipeline(_union_tfidf(), LinearSVC(class_weight="balanced", C=0.5, max_iter=5000))


@dataclass
class BayesIngenuo(_ClasificadorTexto):
    """Bayes ingenuo (presentación, diap. 93-96). ComplementNB es la variante
    recomendada para texto con clases desbalanceadas."""

    nombre: str = "bayes_ingenuo"

    def _fabrica(self):
        from sklearn.naive_bayes import ComplementNB
        from sklearn.pipeline import make_pipeline

        return make_pipeline(_union_tfidf(), ComplementNB(alpha=0.5))


MODELO_EMBEDDINGS = "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"
# Variante ligera (revisión S10): 12 capas de 384 dimensiones en lugar de 768;
# se evalúa para bajar la memoria del ensamble E2 en el servidor.
MODELO_EMBEDDINGS_LIGERO = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"


@lru_cache(maxsize=2)
def _codificador(nombre: str = MODELO_EMBEDDINGS):
    from sentence_transformers import SentenceTransformer

    return SentenceTransformer(nombre, device="cpu")


_CACHE_VECTORES: dict[tuple[str, str], object] = {}


def _vectores_cache(textos: tuple[str, ...], nombre: str = MODELO_EMBEDDINGS):
    """Codifica solo los textos que no se han visto con ese codificador; la
    caché vive en memoria durante la corrida (no se escribe a disco: puede
    contener texto clínico). La clave incluye el modelo para no mezclar
    vectores de dimensiones distintas."""
    import numpy as np

    nuevos = [t for t in dict.fromkeys(textos) if (nombre, t) not in _CACHE_VECTORES]
    if nuevos:
        vectores = _codificador(nombre).encode(nuevos, batch_size=32, normalize_embeddings=True,
                                               show_progress_bar=False)
        _CACHE_VECTORES.update({(nombre, t): v for t, v in zip(nuevos, vectores)})
    return np.stack([_CACHE_VECTORES[(nombre, t)] for t in textos])


@dataclass
class SbertLogistica:
    """Embeddings semánticos multilingües (SBERT; trabajo futuro de la
    presentación, diap. 156) + regresión logística balanceada. No memoriza
    palabras: frases de sentido parecido quedan cerca."""

    nombre: str = "sbert_logistica"
    modelo: object = field(default=None, repr=False)
    codificador: str = MODELO_EMBEDDINGS

    @staticmethod
    def _vectores(ejemplos: Sequence[Ejemplo], codificador: str = MODELO_EMBEDDINGS):
        return _vectores_cache(tuple(e.texto for e in ejemplos), codificador)

    def vectores(self, ejemplos: Sequence[Ejemplo]):
        """Vectores con el codificador de esta instancia."""
        return self._vectores(ejemplos, self.codificador)

    def ajustar(self, ejemplos: Sequence[Ejemplo]) -> "SbertLogistica":
        from sklearn.linear_model import LogisticRegression

        modelo = LogisticRegression(class_weight="balanced", max_iter=3000, C=1.0)
        modelo.fit(self.vectores(ejemplos), [e.etiqueta for e in ejemplos])
        return replace(self, modelo=modelo)

    def predecir(self, ejemplos: Sequence[Ejemplo]) -> list[str]:
        if self.modelo is None:
            raise RuntimeError("primero ajustar()")
        return [str(c) for c in self.modelo.predict(self.vectores(ejemplos))]


def sbert_ligero() -> SbertLogistica:
    """SBERT con el codificador MiniLM (variante ligera)."""
    return SbertLogistica(nombre="sbert_minilm", codificador=MODELO_EMBEDDINGS_LIGERO)


MODELOS: dict[str, Callable[[], object]] = {
    "robertuito_produccion": RobertuitoProduccion,
    "robertuito_reentrenado": RobertuitoReentrenado,
    "tfidf": Tfidf,
    "vader_clasico": VaderClasico,
    "vader_umbral": VaderUmbral,
    "vader_ajustado": VaderAjustado,
    "svm_tfidf": SvmTfidf,
    "bayes_ingenuo": BayesIngenuo,
    "sbert_logistica": SbertLogistica,
    "sbert_minilm": sbert_ligero,
}


# --- métricas (sin dependencias) --------------------------------------------

def exactitud_por_clase(reales: Sequence[str], predichas: Sequence[str]) -> dict[str, float]:
    """Proporción de cada clase real que el modelo clasificó bien (recall)."""
    resultado = {}
    for clase in CLASES:
        indices = [i for i, r in enumerate(reales) if r == clase]
        aciertos = sum(predichas[i] == clase for i in indices)
        resultado[clase] = round(aciertos / len(indices), 4) if indices else 0.0
    return resultado


def intervalo_bootstrap(reales: Sequence[str], predichas: Sequence[str], metrica: Callable,
                        remuestreos: int = REMUESTREOS, semilla: int = SEMILLA_S9) -> tuple[float, float]:
    """Intervalo percentil del 95% con bootstrap estratificado: se remuestrea
    con reemplazo dentro de cada clase real, así ninguna réplica pierde una
    clase completa (con 9 positivos eso hundiría el F1 macro sin razón)."""
    azar = random.Random(semilla)
    grupos = [[i for i, r in enumerate(reales) if r == c] for c in CLASES]
    grupos = [g for g in grupos if g]
    valores = []
    for _ in range(remuestreos):
        idx = [g[azar.randrange(len(g))] for g in grupos for _ in g]
        valores.append(metrica([reales[i] for i in idx], [predichas[i] for i in idx]))
    valores.sort()
    return round(valores[int(0.025 * remuestreos)], 4), round(valores[int(0.975 * remuestreos) - 1], 4)


def evaluar(reales: Sequence[str], predichas: Sequence[str], remuestreos: int = REMUESTREOS) -> dict[str, object]:
    return {
        **reporte(reales, predichas),
        "exactitud_por_clase": exactitud_por_clase(reales, predichas),
        "ic95_exactitud": intervalo_bootstrap(reales, predichas, exactitud, remuestreos),
        "ic95_f1_macro": intervalo_bootstrap(reales, predichas, f1_macro, remuestreos),
    }


# --- escenarios ---------------------------------------------------------------

def muestra_repaso(educativo: Sequence[Ejemplo], por_clase: int, semilla: int = SEMILLA_S9) -> list[Ejemplo]:
    """Muestra balanceada del corpus educativo para mezclar con lo clínico en la
    última etapa del ajuste secuencial (repaso o *rehearsal*): evita que el
    modelo olvide la clase positiva al afinarse con un conjunto que casi no la
    tiene. Determinista con la semilla."""
    if por_clase <= 0:
        return []
    azar = random.Random(semilla)
    muestra = []
    for clase in CLASES:
        grupo = [e for e in educativo if e.etiqueta == clase]
        if len(grupo) < por_clase:
            raise ValueError(f"el corpus educativo tiene {len(grupo)} de {clase}; se piden {por_clase}")
        muestra.extend(azar.sample(grupo, por_clase))
    return muestra



def _ajustar(nombre: str, entrenamiento: Sequence[Ejemplo], base: str | None = None, pesos_clase: bool = False,
             congelar: int = 0):
    inicio = time.perf_counter()
    vacio = MODELOS[nombre]()
    opciones = {k: v for k, v in (("base", base), ("pesos_clase", pesos_clase), ("congelar", congelar)) if v}
    if opciones:
        if not isinstance(vacio, RobertuitoReentrenado):
            raise ValueError("la variante secuencial, los pesos de clase y el congelado solo aplican a robertuito_reentrenado")
        vacio = replace(vacio, **opciones)
    modelo = vacio.ajustar(entrenamiento)
    return modelo, round(time.perf_counter() - inicio, 1)


def holdout(entrenamiento: Sequence[Ejemplo], pruebas: dict[str, Sequence[Ejemplo]], modelos: Sequence[str]):
    conjuntos = {"entrenamiento": entrenamiento, **pruebas}
    metricas: dict[str, dict] = {c: {} for c in conjuntos}
    predicciones: dict[str, dict] = {c: {} for c in conjuntos}
    ajuste = {}
    for nombre in modelos:
        modelo, segundos = _ajustar(nombre, entrenamiento)
        ajuste[f"{nombre}_segundos"] = segundos
        for conjunto, ejemplos in conjuntos.items():
            pred = modelo.predecir(ejemplos)
            predicciones[conjunto][nombre] = pred
            metricas[conjunto][nombre] = evaluar([e.etiqueta for e in ejemplos], pred)
            print(f"{nombre:24} {conjunto:14} exact={metricas[conjunto][nombre]['exactitud']:.4f} "
                  f"F1m={metricas[conjunto][nombre]['f1_macro']:.4f}", flush=True)
        if isinstance(modelo, VaderUmbral):
            ajuste[f"{nombre}_umbrales"] = modelo.umbrales
        if isinstance(modelo, VaderAjustado):
            ajuste[f"{nombre}_pesos"] = modelo.pesos()
    return metricas, predicciones, ajuste


def mixto(clinico: Sequence[Ejemplo], educativo: Sequence[Ejemplo], modelos: Sequence[str], k: int = 5,
          semilla: int = SEMILLA_S9, variantes: Sequence[str] = ("solo_clinico", "clinico_mas_educativo"),
          base_robertuito: str | None = None, pesos_clase: bool = False, repaso_por_clase: int = 0,
          congelar: int = 0):
    if "secuencial" in variantes:
        if base_robertuito is None:
            raise ValueError("la variante secuencial necesita --base-robertuito")
        if set(modelos) != {"robertuito_reentrenado"}:
            raise ValueError("la variante secuencial solo aplica a robertuito_reentrenado")
    reales = [e.etiqueta for e in clinico]
    metricas, predicciones = {}, {}
    for variante in variantes:
        if variante == "clinico_mas_educativo":
            extra = list(educativo)
        elif variante == "secuencial":
            extra = muestra_repaso(educativo, repaso_por_clase)
        else:
            extra = []
        for nombre in modelos:
            pred, f1_pliegues = [""] * len(clinico), []
            for prueba in pliegues(clinico, k, semilla):
                fuera = set(prueba)
                entrenamiento = [e for i, e in enumerate(clinico) if i not in fuera] + extra
                modelo, _ = _ajustar(nombre, entrenamiento, base_robertuito if variante == "secuencial" else None,
                                     pesos_clase, congelar)
                etiquetas = modelo.predecir([clinico[i] for i in prueba])
                for i, c in zip(prueba, etiquetas):
                    pred[i] = c
                f1_pliegues.append(f1_macro([clinico[i].etiqueta for i in prueba], etiquetas))
            clave = f"{variante}/{nombre}"
            metricas[clave] = {**evaluar(reales, pred), "f1_por_pliegue": f1_pliegues}
            predicciones[clave] = pred
            print(f"{clave:46} exact={metricas[clave]['exactitud']:.4f} F1m={metricas[clave]['f1_macro']:.4f} "
                  f"pliegues={f1_pliegues}", flush=True)
    return metricas, predicciones


# --- línea de comandos --------------------------------------------------------

def _pares(valores: Sequence[str]) -> dict[str, Path]:
    malos = [v for v in valores if "=" not in v]
    if malos:
        raise SystemExit(f"--prueba espera nombre=ruta: {malos}")
    return {v.split("=", 1)[0]: Path(v.split("=", 1)[1]) for v in valores}


def privados(nombres: Sequence[str], marcados: Sequence[str]) -> set[str]:
    """Conjuntos cuyas predicciones no pueden ir a un archivo compartible:
    los marcados con --privado y cualquiera fuera de CONJUNTOS_PUBLICOS."""
    desconocidos = set(marcados) - set(nombres)
    if desconocidos:
        raise SystemExit(f"--privado nombra conjuntos que no existen: {sorted(desconocidos)}")
    return set(marcados) | {n for n in nombres if n not in CONJUNTOS_PUBLICOS}


def _guardar(ruta: Path, datos: object, privado: bool) -> None:
    contenido = json.dumps(datos, ensure_ascii=False, indent=1)
    if privado:
        escribir_privado(ruta, contenido)
    else:
        ruta.write_text(contenido, encoding="utf-8")


def guardar_checkpoint_privado(modelo, carpeta: Path) -> None:
    """Un modelo afinado con respuestas clínicas es dato derivado privado:
    la carpeta queda con permisos 700 y sus archivos con 600."""
    import os

    carpeta = Path(carpeta)
    carpeta.mkdir(parents=True, exist_ok=True)
    os.chmod(carpeta, 0o700)
    modelo.estado[1].save_pretrained(carpeta)
    modelo.estado[0].save_pretrained(carpeta)
    for archivo in carpeta.iterdir():
        os.chmod(archivo, 0o600)


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("escenario", choices=("holdout", "mixto", "base", "final"))
    p.add_argument("--guardar", type=Path, help="carpeta del checkpoint (escenario base)")
    p.add_argument("--base-robertuito", help="checkpoint de partida para la variante secuencial")
    p.add_argument("--congelar", type=int, default=0,
                   help="congela embeddings y las N capas inferiores del encoder (RoBERTuito tiene 12)")
    p.add_argument("--repaso", type=int, default=0,
                   help="ejemplos educativos por clase que se mezclan con lo clínico en la última etapa (secuencial/final)")
    p.add_argument("--pesos-clase", action="store_true",
                   help="pérdida ponderada por clase en la etapa clínica (solo variante secuencial)")
    p.add_argument("--entrenamiento", type=Path)
    p.add_argument("--prueba", action="append", default=[], help="nombre=ruta (repetible)")
    p.add_argument("--privado", action="append", default=[], help="conjuntos cuyas predicciones no se comparten")
    p.add_argument("--clinico", type=Path)
    p.add_argument("--educativo", type=Path, action="append", default=[])
    p.add_argument("--variante", action="append", default=[], help="solo_clinico y/o clinico_mas_educativo")
    p.add_argument("--modelos", default=",".join(MODELOS))
    p.add_argument("--salida", type=Path, required=True)
    p.add_argument("--predicciones", type=Path)
    p.add_argument("--predicciones-privadas", type=Path)
    args = p.parse_args(argv)
    modelos = [m for m in args.modelos.split(",") if m]
    desconocidos = set(modelos) - set(MODELOS)
    if desconocidos:
        raise SystemExit(f"modelos desconocidos: {sorted(desconocidos)}")

    requeridos = {"base": ("educativo", "guardar"), "holdout": ("entrenamiento",), "mixto": ("clinico",),
                  "final": ("clinico", "base_robertuito", "guardar")}
    faltan = [f"--{r.replace('_', '-')}" for r in requeridos[args.escenario] if not getattr(args, r)]
    if faltan:
        p.error(f"{args.escenario} necesita {' '.join(faltan)}")
    if args.escenario == "base":
        educativo = [e for r in args.educativo for e in cargar_conjunto(r)]
        modelo, segundos = _ajustar("robertuito_reentrenado", educativo, congelar=args.congelar)
        args.guardar.mkdir(parents=True, exist_ok=True)
        modelo.estado[1].save_pretrained(args.guardar)
        modelo.estado[0].save_pretrained(args.guardar)
        _guardar(args.salida, {"escenario": "base", "n": len(educativo), "congelar": args.congelar,
                               "segundos": segundos}, privado=False)
        print(f"checkpoint educativo ({len(educativo)} ejemplos, {segundos} s) -> {args.guardar}")
        return
    if args.escenario == "final":
        clinico = cargar_conjunto(args.clinico)
        repaso = muestra_repaso([e for r in args.educativo for e in cargar_conjunto(r)], args.repaso)
        modelo, segundos = _ajustar("robertuito_reentrenado", list(clinico) + repaso, args.base_robertuito,
                                    args.pesos_clase, args.congelar)
        guardar_checkpoint_privado(modelo, args.guardar)
        _guardar(args.salida, {"escenario": "final", "n_clinico": len(clinico), "n_repaso": len(repaso),
                               "base": "checkpoint educativo",
                               "pesos_clase": args.pesos_clase, "congelar": args.congelar,
                               "segundos": segundos}, privado=False)
        print(f"checkpoint final ({len(clinico)} clínicos, {segundos} s) -> {args.guardar} (permisos 700)")
        return
    if args.escenario == "holdout":
        entrenamiento = cargar_conjunto(args.entrenamiento)
        pruebas = {n: cargar_conjunto(r) for n, r in _pares(args.prueba).items()}
        metricas, predicciones, extra = holdout(entrenamiento, pruebas, modelos)
        resultado = {"escenario": "holdout", "n_entrenamiento": len(entrenamiento), "modelos": modelos,
                     "metricas": metricas, "ajuste": extra}
        ocultos = privados(list(predicciones), args.privado)
        publicas = {c: v for c, v in predicciones.items() if c not in ocultos}
        privadas = {c: v for c, v in predicciones.items() if c in ocultos}
    else:
        clinico = cargar_conjunto(args.clinico)
        educativo = [e for r in args.educativo for e in cargar_conjunto(r)]
        variantes = args.variante or ["solo_clinico", "clinico_mas_educativo"]
        if args.repaso and not educativo:
            p.error("--repaso necesita --educativo")
        metricas, predicciones = mixto(clinico, educativo, modelos, variantes=variantes,
                                       base_robertuito=args.base_robertuito, pesos_clase=args.pesos_clase,
                                       repaso_por_clase=args.repaso, congelar=args.congelar)
        resultado = {"escenario": "mixto", "n_clinico": len(clinico), "n_educativo": len(educativo),
                     "repaso_por_clase": args.repaso,
                     "semilla": SEMILLA_S9, "modelos": modelos, "metricas": metricas}
        publicas, privadas = {}, predicciones

    _guardar(args.salida, resultado, privado=False)
    if args.predicciones and publicas:
        _guardar(args.predicciones, publicas, privado=False)
    if privadas and not args.predicciones_privadas:
        print("aviso: hay predicciones privadas y no se pidió --predicciones-privadas; no se guardaron")
    if args.predicciones_privadas and privadas:
        _guardar(args.predicciones_privadas, privadas, privado=True)


if __name__ == "__main__":
    main()
