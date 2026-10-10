"""Recuperacion de contenido aprobado para Serena (TF-IDF).

PROTOTIPO (Semana 3). Serena no inventa consejo: redacta solo con lo que
devuelve este modulo (Etapa 2 de la arquitectura del informe de Serena).

El corpus son los textos de la propia app (Semana 1,
corpus_81_textos.json). Se excluyen los 21 marcados como bloqueados en la
revision clinica. TF-IDF basta para 60 textos cortos y no agrega
dependencias; si el corpus crece se puede cambiar por embeddings sin tocar
el resto (misma interfaz).
"""

from __future__ import annotations

import json
import math
import re
from collections import Counter
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from .clasificador_riesgo import _normalizar, normalizar_chat
from .revision_clinica import ESTADO_APROBADO, ESTADO_PENDIENTE, revision_de, texto_vigente

RUTA_CORPUS = Path(__file__).parent / "datos" / "corpus_serena.json"
UMBRAL = 0.08  # por debajo, el texto no tiene relacion util con la pregunta
# Modulos que NO se usan como contenido del chat normal: los mensajes de
# riesgo nunca llegan al modelo (los atienden las barreras), y citar "Riesgo
# de suicidio" a quien solo reprobo un examen alarma sin motivo (paso en el
# servidor, Semana 3).
MODULOS_EXCLUIDOS_CHAT = frozenset({"Riesgo de suicidio", "Autolesión no suicida"})

# Fase 3 (Semana 3): FILTRO DE TEMA. Con 20 textos, TF-IDF empataba por
# palabras genericas ("hoy saque 10 en el examen" -> Sustancias) y no
# reconocia sinonimos ("fuma mota"). Ahora un modulo solo es elegible si el
# mensaje toca su tema; si ningun tema aplica, Serena responde sin citar
# fuentes. La lista es corta y auditable (la revisa psicologia, como los
# lexicos de riesgo).
TEMAS: dict[str, tuple[str, ...]] = {
    "Ansiedad": (
        r"\bansie\w*", r"\bnervi\w*", r"\bmiedo\w*", r"\bpanico\b", r"\bpreocup\w*", r"\bangusti\w*",
        r"\bestres\w*", r"\bcalmar\w*", r"\brespir\w*", r"\bterapia\w*", r"\bpsicolog\w*", r"\bsud(?:an|o|or)\b",
        r"\bacelera\w*", r"\btiembl\w*", r"\binquiet\w*", r"\bpreocupad\w*",
    ),
    "Consumo de sustancias": (
        r"\bfum\w*", r"\bcigarr\w*", r"\bvape\w*", r"\bvapea\w*", r"\bnicotina\b", r"\bmota\b",
        r"\bmari[hg]uana\b", r"\balcohol\w*", r"\bcerveza\w*", r"\bborrach\w*", r"\bdrogas?\b", r"\binhal\w*",
        r"\bpegamento\w*", r"\bsolvente\w*", r"\bthc\b", r"\btabaco\b", r"\bpeda\b", r"\bchup\w*\b.{0,15}\bfiesta",
        r"\btom\w*\b.{0,25}\b(?:fiestas?|alcohol|cerveza|pisto)\b",
    ),
}


def temas_de(texto: str) -> frozenset[str]:
    plano = normalizar_chat(texto)
    return frozenset(m for m, patrones in TEMAS.items() if any(re.search(p, plano) for p in patrones))


_VACIAS = set(
    "a al algo algun alguna ante con como cual cuando de del desde donde el ella ellos en entre era es esa ese eso "
    "esta estas este esto estoy fue ha han hay la las le les lo los mas me mi mis muy nada ni no nos o otra otro "
    "para pero por porque que se sea ser si sin sobre solo son su sus te tu tus un una uno unos y ya yo".split()
)


@dataclass(frozen=True)
class Fragmento:
    id: str
    modulo: str
    titulo: str
    texto: str
    puntaje: float
    # Cierre de la Semana 3: estado en la revision clinica (revision_clinica).
    revision: str = ESTADO_PENDIENTE


def _tokens(texto: str) -> list[str]:
    palabras = re.findall(r"[a-zñ]+", _normalizar(texto))
    # Raiz muy simple: quitar terminaciones frecuentes ayuda a juntar
    # "ansiedad/ansioso" o "respirar/respiracion" sin un lematizador.
    return [p[:6] for p in palabras if p not in _VACIAS and len(p) > 2]


@dataclass(frozen=True)
class _Indice:
    documentos: tuple[dict, ...]
    vectores: tuple[dict[str, float], ...]
    idf: dict[str, float]


def _vector(tokens: list[str], idf: dict[str, float]) -> dict[str, float]:
    conteo = Counter(tokens)
    v = {t: (1 + math.log(c)) * idf.get(t, 0.0) for t, c in conteo.items()}
    norma = math.sqrt(sum(x * x for x in v.values())) or 1.0
    return {t: x / norma for t, x in v.items()}


@lru_cache(maxsize=1)
def _indice(ruta: str = str(RUTA_CORPUS)) -> _Indice:
    datos = json.loads(Path(ruta).read_text(encoding="utf-8"))
    # Se indexa el texto vigente: el corregido por psicologia si ya se aplico.
    docs = tuple(
        {**d, "texto": texto_vigente(d["id"], d["texto"])}
        for d in datos
        if not d.get("bloqueada") and d.get("texto")
    )
    tokenizados = [_tokens(f"{d.get('titulo') or ''} {d['texto']}") for d in docs]
    df = Counter(t for toks in tokenizados for t in set(toks))
    n = len(docs)
    idf = {t: math.log((1 + n) / (1 + c)) + 1 for t, c in df.items()}
    return _Indice(docs, tuple(_vector(t, idf) for t in tokenizados), idf)


def recuperar(
    pregunta: str,
    k: int = 3,
    publico: str = "adolescente",
    excluir: frozenset[str] = MODULOS_EXCLUIDOS_CHAT,
) -> tuple[Fragmento, ...]:
    temas = temas_de(pregunta)
    if not temas:
        return ()
    indice = _indice()
    q = _vector(_tokens(pregunta), indice.idf)
    puntajes = []
    for doc, vec in zip(indice.documentos, indice.vectores):
        if publico and doc.get("publico") != publico:
            continue
        if doc.get("modulo") in excluir or doc.get("modulo") not in temas:
            continue
        s = sum(q[t] * vec.get(t, 0.0) for t in q)
        # Dentro de un tema que si aplica, un texto sin palabras en comun
        # (p. ej. "mota" vs "marihuana") aun sirve: queda al final.
        puntajes.append((s, doc))
    # Con la misma relevancia, primero lo aprobado por psicologia. Solo
    # desempata: un texto aprobado nunca gana a uno mas relevante.
    puntajes.sort(key=lambda par: (par[0], revision_de(par[1]["id"]).estado == ESTADO_APROBADO), reverse=True)
    return tuple(
        Fragmento(
            d["id"], d["modulo"], d.get("titulo") or d["modulo"], d["texto"], round(s, 3),
            revision_de(d["id"]).estado,
        )
        for s, d in puntajes[:k]
    )
