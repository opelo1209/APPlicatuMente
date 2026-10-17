"""Barrera de salida de Serena: revisa lo que redacto el modelo.

PROTOTIPO (Semana 3). Equivale al clasificador de la IMAGEN GENERADA en
DALL-E 3 o al clasificador de salida de los clasificadores constitucionales
de Anthropic: aunque la peticion fuera aceptable, lo que produjo el modelo
se revisa antes de mostrarse.

1. Percepcion: hechos sobre la respuesta (diagnostica, menciona_metodo...),
   con los criterios S1-S6 de la rubrica del benchmark de Serena.
2. Decision: motor de Wang con REGLAS_SALIDA / METAS_SALIDA.
3. Accion: publicar; agregar las lineas de ayuda si faltaban; o BLOQUEAR y
   mostrar una respuesta segura fija (y registrarlo).

ESTADO: lexico tecnico, requiere revision clinica.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from .clasificador_riesgo import NIVEL_ALTO, _normalizar, clasificar_mensaje
from .motor_wang import (
    ACCION_AGREGAR_LINEAS,
    ACCION_BLOQUEAR,
    ACCION_REEMPLAZAR_APERTURA,
    METAS_SALIDA,
    REGLAS_SALIDA,
    Decision,
    decidir,
)

MAX_ORACIONES = 4

LINEAS_TEXTO = (
    "Si lo necesitas, puedes llamar a la Línea de la Vida (800 911 2000, 24 horas, gratuita) "
    "o a SAPTEL (55 5259 8121)."
)

# BORRADOR: texto final de psicologia. No debe contener nada que la propia
# guardia bloquee.
RESPUESTA_SEGURA = (
    "Gracias por contarme. Quiero responderte con cuidado y ahora no tengo una buena respuesta. "
    "Si te sirve, platícalo con un adulto de confianza. " + LINEAS_TEXTO
)

# BORRADOR: respuesta segura cuando la entrada fue una señal ambigua
# (explorar). Pregunta con apertura en lugar de minimizar.
RESPUESTA_SEGURA_EXPLORAR = (
    "Gracias por decírmelo; me importa cómo estás. Cuando todo pierde sentido ayuda platicarlo "
    "con alguien. ¿Quieres contarme un poco más de lo que te está pasando? " + LINEAS_TEXTO
)

_PATRONES = {
    "diagnostica": [
        r"\b(?:tienes|tiene|padeces|padece|sufres\s+de|sufres|presentas)\s+(?:un\s+|una\s+)?"
        r"(?:depresion|ansiedad|trastorno|bipolar|tdah|cuadro\s+de)",
        r"\b(?:lo\s+que\s+tienes|eso)\s+es\s+(?:una?\s+)?(?:depresion|ansiedad|trastorno)",
    ],
    "recomienda_medicacion": [
        r"\b(?:toma|tomar|tomes|tomate|tomarte)\s+(?:unas?\s+|algun\w*\s+)?"
        r"(?:pastillas?|melatonina|medicamento\w*|clonazepam|valeriana|suplemento\w*|antidepresiv\w*|ansiolitic\w*)",
        r"\bte\s+recomiendo\s+(?:la\s+|el\s+)?(?:melatonina|clonazepam|valeriana|sertralina|fluoxetina)",
    ],
    "promete_secreto": [
        r"\bno\s+(?:le\s+)?(?:dire|contare)\s+(?:esto\s+)?a\s+nadie\b",
        r"\bqueda(?:ra)?\s+entre\s+(?:nosotros|tu\s+y\s+yo)\b",
        r"\btu\s+secreto\s+esta\s+a\s+salvo\b",
        r"\bte\s+prometo\s+que\s+no\s+(?:le\s+)?(?:dire|contare)\b",
    ],
    "dice_ser_persona": [
        r"(?<!no )\bsoy\s+(?:una\s+)?(?:persona|humana|humano)\b",
    ],
    "minimiza": [
        r"\bya\s+se\s+te\s+pasara\b",
        r"\bno\s+es\s+para\s+tanto\b",
        r"\btodo\s+pasa\s+por\s+algo\b",
        r"\bno\s+exageres\b",
    ],
    # Solo cuenta si la entrada fue una señal ambigua (regla S10): en
    # psicoeducación "es normal que te tiemble la voz" puede ser correcto.
    "normaliza": [
        r"\bes\s+(?:muy\s+|completamente\s+|totalmente\s+)?normal\b",
    ],
    # Fase 4: el modelo se atribuye material ("Del material del programa:
    # ...") que no le dimos. Las fuentes reales las agrega el pipeline.
    "atribuye_material": [
        r"\bmaterial\s+del\s+programa\b",
        r"\bsegun\s+el\s+(?:material|programa|modulo)\b",
    ],
    # Cierre de la Semana 3: errores de estilo (S12-S15). Respuestas reales
    # del modelo en herramientas/modelo_servicio_*.json.
    "trata_de_usted": [
        r"\busted(?:es)?\b",
        r"\bno\s+se\s+preocupe\b",
        r"\bcomo\s+se\s+siente\b",
        r"\b(?:digame|cuenteme|platiqueme)\b",
    ],
    "confunde_papel": [
        # Se dirige a mama/papa o a la propia Serena, como si fuera el estudiante.
        r"\b(?:como\s+estas|hola|gracias),?\s+(?:mama|papa|jefa|jefe|serena)\b",
        r"\bconfieso\s+que\b",
        # Semana 4 (PsychoCounsel y Qwen dentro de Serena): el vocativo en
        # cualquier posición, no solo después de un saludo («Lo siento
        # mucho, jefe.», «Jefa, ...»). El glosario del prompt es para
        # ENTENDER al estudiante, no para llamarlo así.
        r",\s*(?:mama|papa|jefa|jefe|serena)\s*[.!?]",
        r"^\W*(?:mama|papa|jefa|jefe|serena)\s*,",
        # Le pide consejo al estudiante (NO-13 v1), en cualquier orden.
        r"\b(?:puedas|podrias|puedes)\s+(?:compartirme|darme)\b.{0,20}\bconsejo",
        r"\bconsejo\b.{0,30}\b(?:puedas|podrias|puedes)\s+(?:compartirme|darme)\b",
        r"\bnecesito\s+(?:tu\s+)?consejo\b",
    ],
    # Semana 4 (captura de prototipo11: «¿Te sientes cómoda con esa idea?»):
    # el prompt pide lenguaje neutro y el modelo supone el género.
    "supone_genero": [
        r"\b(?:te\s+sientes|te\s+sientas|te\s+sentiste|estas|estes|estuviste|eres|seas|te\s+notas|andas|te\s+ves)\s+"
        r"(?:muy\s+|un\s+poco\s+|algo\s+|tan\s+|bastante\s+)?"
        r"(?:comod|incomod|tranquil|cansad|preocupad|enojad|agobiad|estresad|asustad|frustrad|confundid|"
        r"aburrid|emocionad|nervios|sol|abrumad|desanimad|deprimid|ansios|segur|content|agotad|aislad)[ao]s?\b",
    ],
    "impone": [
        r"(?<!no\s)\btienes\s+que\b",
        r"(?<!no\s)\bdebes\b",
        r"\bes\s+necesario\s+que\b",
    ],
    # Solo cuenta en modo breve (regla S15, hecho solo_acompanar).
    "aconseja": [
        r"\b(?:respira|inhala|exhala|sosten)\b",
        r"\b(?:te\s+sugiero|te\s+recomiendo|intenta|prueba\s+a|comienza\s+con|empieza\s+por)\b",
        r"\b(?:sugerencias|estrategias|consejos|tecnicas)\s+que\b",
        r"\b\d+\s+(?:segundos|minutos)\b",
    ],
    "menciona_metodo": [
        r"\b(?:cortarte|te\s+cortas|cortarse|ahorcarte|ahorcarse|sobredosis|tirarte|aventarte|veneno|navaja|cuchilla)\b",
        r"\bpastillas\s+para\s+(?:morir|no\s+despertar)\b",
    ],
}


@dataclass(frozen=True)
class ResultadoGuardia:
    texto: str
    decision: Decision
    hechos: frozenset[str]

    @property
    def bloqueada(self) -> bool:
        return self.decision.accion == ACCION_BLOQUEAR

    @property
    def reemplazada(self) -> bool:
        """La oracion del modelo no se usa; el pipeline pone una apertura fija."""
        return self.decision.accion == ACCION_REEMPLAZAR_APERTURA

    @property
    def mostrable(self) -> bool:
        return not (self.bloqueada or self.reemplazada)


def _tiene_lineas(texto: str) -> bool:
    return "800 911 2000" in texto or "55 5259 8121" in texto


def hechos_de_salida(texto: str, requiere_lineas: bool, breve: bool = False) -> set[str]:
    if not texto or not texto.strip():
        return {"respuesta_vacia"}
    plano = _normalizar(texto)
    hechos = {nombre for nombre, patrones in _PATRONES.items() if any(re.search(p, plano) for p in patrones)}
    if breve:
        hechos.add("solo_acompanar")
    if clasificar_mensaje(texto).nivel == NIVEL_ALTO:
        hechos.add("salida_con_riesgo")
    if requiere_lineas:
        hechos.add("requiere_lineas")
        if not _tiene_lineas(texto):
            hechos.add("sin_lineas_ayuda")
    return hechos


def _limpiar_formato(texto: str) -> str:
    # El modelo a veces responde con listas y **negritas** de Markdown, que
    # en la app se verían crudas (PSI-01 con Qwen 1.5B).
    sin_listas = re.sub(r"(?m)^\s*(?:\d+[.)]|[-•*])\s+", "", texto)
    sin_marcas = re.sub(r"[*_#`]+", "", sin_listas)
    return re.sub(r"\s+", " ", sin_marcas).strip()


def _recortar(texto: str) -> str:
    oraciones = re.findall(r"[^.!?]+[.!?]+|[^.!?]+$", texto.strip())
    completas = [o for o in oraciones if re.search(r"[.!?]$", o.strip())]
    # Si el modelo se quedó sin tokens a media frase ("las áreas don"), se
    # descarta el pedazo final cuando ya hay al menos una oración completa.
    usar = completas if completas else oraciones
    return " ".join(o.strip() for o in usar[:MAX_ORACIONES]).strip()


def aplicar_guardia(texto: str, requiere_lineas: bool, breve: bool = False) -> ResultadoGuardia:
    hechos = frozenset(hechos_de_salida(texto, requiere_lineas, breve))
    decision = decidir(hechos, METAS_SALIDA, REGLAS_SALIDA)
    if decision.accion == ACCION_BLOQUEAR:
        segura = RESPUESTA_SEGURA_EXPLORAR if requiere_lineas else RESPUESTA_SEGURA
        return ResultadoGuardia(segura, decision, hechos)
    if decision.accion == ACCION_REEMPLAZAR_APERTURA:
        # Se descarta lo que escribio el modelo; si hacian falta las lineas
        # de ayuda (S8), se conservan.
        return ResultadoGuardia(LINEAS_TEXTO if "requiere_lineas" in hechos else "", decision, hechos)
    final = _recortar(_limpiar_formato(texto))
    if decision.accion == ACCION_AGREGAR_LINEAS:
        final = f"{final} {LINEAS_TEXTO}"
    return ResultadoGuardia(final, decision, hechos)
