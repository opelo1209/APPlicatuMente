"""Contexto del mensaje: ¿pide informacion o habla de si mismo? (Semana 4).

Reunion con el asesor (9 de octubre). Serena y el analizador miraban
palabras sueltas: "¿que es la tristeza?" salia negativo (pysentimiento lee
la palabra "tristeza") y Serena contestaba "suena a que no ha sido facil" y
"platicalo con un adulto de confianza", cuando el estudiante solo queria
informacion. El asesor pidio leer la frase completa:

  - "¿hay algun material que me de informacion acerca del suicidio?"
    -> consulta: neutra, Serena informa como un asistente normal.
  - "quiero que me ayudes con las tecnicas para que yo me suicide"
    -> pide un metodo para si: crisis (lo decide limites_serena, R11).

Este modulo NO baja el riesgo: solo agrega el hecho "consulta_informativa"
cuando la frase pide informacion y no habla del estado de quien escribe.
Las senales directas (ideacion, plan, despedida, pedir metodos) se detectan
antes y ganan en el motor de Wang, como en las capas de los asistentes
comerciales, donde un clasificador puede subir el nivel pero no quitarlo.

ESTADO: lexico escrito por el equipo tecnico; requiere revision clinica,
igual que el del clasificador de riesgo.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from .clasificador_riesgo import normalizar_chat

HECHO_CONSULTA = "consulta_informativa"

# Pide informacion: preguntas de definicion, pedir material, tareas
# escolares, como ayudar a otra persona.
_PIDE_INFORMACION = (
    r"^(?:[¿¡]\s*)?(?:(?:oye|hola|serena|una\s+pregunta)\s*,?\s*)*"
    r"(?:que\s+(?:es|son|significa|causa|provoca)|por\s+que\s+(?:la\s+gente|las\s+personas|alguien|se\s+|existe|hay)|"
    r"cuales?\s+(?:son|es)|como\s+(?:funciona|se\s+(?:siente|manifiesta|detecta|previene|trata|identifica))|"
    r"es\s+normal\s+(?:que|sentir)|existe)\b",
    r"\b(?:informacion|material(?:es)?|datos|articulos?|lecturas?|recursos?|guias?|libros?|videos?|explica(?:me|rme|cion)?|hablame)\b"
    r".{0,30}\b(?:de|del|sobre|acerca|respecto|para\s+(?:entender|saber|aprender|conocer))\b",
    r"\b(?:quiero|quisiera|me\s+gustaria|puedes|podrias|me\s+puedes|me\s+podrias)\s+(?:\w+\s+){0,3}?"
    r"(?:saber|aprender|entender|conocer|consultar|investigar|informar\w*)\b",
    r"\b(?:senales|sintomas|mitos|causas|tipos|factores\s+de\s+riesgo|diferencia\s+entre|estadisticas)\b",
    r"\bcomo\s+(?:puedo\s+)?(?:ayudar|apoyar|acompanar)\s+a\s+(?:alguien|un\s+amig\w*|una\s+amig\w*|una\s+persona|mi\s+\w+)",
    # Semana 5 (consultas que fallaban en la Semana 4 y en frases nuevas).
    # Pedir una explicacion: el verbo y luego que/como/cual + lo que se
    # explica ("me puedes explicar que es...", "me explicas como se trata").
    # "dime que no estoy loco" no entra: tras "que" se exige es/son/pasa...
    r"\b(?:explica\w*|dime|decir(?:me)?|cuenta(?:me)?|contar(?:me)?|ensena(?:me|r(?:me)?)?)\b.{0,20}?"
    r"\b(?:que\s+(?:es|son|significa|causa|provoca|pasa)|como\s+(?:se|funciona)|cual(?:es)?\s+(?:es|son)|por\s+que|en\s+que)\b",
    r"\b(?:en\s+que\s+se\s+diferencia\w*|diferencias?\s+(?:hay\s+)?entre|(?:cual|cuales|que)\s+(?:es|son)\s+las?\s+diferencias?)\b",
    r"\bque\s+(?:pasa|sucede|ocurre)\s+(?:en|con)\s+(?:el|la|los|las)\b",
    # Como ayudar a otra persona: "que puedo hacer para apoyar a un amigo",
    # "como le hago para ayudar a mi hermano", "que le digo a mi primo".
    r"\b(?:que|como)\s+(?:\w+\s+){0,3}?(?:ayud\w*|apoy\w*|acompan\w*|decirle|digo|decir)\s+(?:a\s+)?(?:mi|mis|un|una|alguien)\b",
    # "que hago si mi amiga esta pasando por..." (la otra persona es quien
    # esta mal; "que hago si mi papa me pega" no entra: lo frena _HABLA_DE_SI).
    r"\bque\s+(?:hago|puedo\s+hacer|hacer)\s+si\s+(?:mi|un|una)\s+(?:\w+\s+){0,2}?(?:esta|anda|se\s+siente|tiene|pasa|sufre)\b",
    r"\b(?:tarea|trabajo|exposicion|proyecto|investigacion|ensayo)\b.{0,40}\b(?:sobre|de|acerca)\b",
    r"\bsolo\s+(?:quise|quiero|queria)\s+(?:consultar|saber|preguntar|informa\w*|leer)\b",
    r"\b(?:como|maneras?|formas?)\s+(?:de\s+|se\s+puede\s+)?(?:prevenir|evitar|detectar|identificar)\b",
    r"\bprevencion\b",
)

# Habla de si mismo: estado, deseo o conducta en primera persona. Con
# cualquiera de estos la frase ya no es una consulta, aunque pregunte "que es".
_HABLA_DE_SI = (
    r"\bme\s+(?:siento|senti|sientes?)\b",
    r"\bsiento\s+que\b",
    r"\bestoy\s+(?:muy\s+|bien\s+|algo\s+)?(?:triste|deprimid\w*|mal|sol[oa]|cansad\w*|hart\w*|ansios\w*|agobiad\w*|desesperad\w*)",
    r"\bya\s+no\s+(?:aguanto|puedo|quiero|soporto)\b",
    r"\bme\s+quiero\b",
    r"\bquiero\s+(?:morir\w*|matarme|suicidarme|desaparecer|dejar\s+de\s+existir|hacerme)\b",
    r"\bme\s+(?:corto|corte|lastimo|lastime|pego|hago\s+dano|hice\s+dano|muero|mato|suicid\w*)\b",
    r"\b(?:suicidarme|matarme|cortarme|lastimarme|ahorcarme|quitarme\s+la\s+vida|hacerme\s+dano)\b",
    r"\bque\s+(?:yo\s+)?me\s+(?:suicide|mate|muera|corte|lastime)\b",
    r"\byo\s+(?:me|tengo|siento|estoy|quiero|pienso)\b",
    # "para mi" sin acento tambien es "para mi tarea": solo cuenta como
    # "para mi" (yo) al final o antes de es/fue/no/que... (Semana 5).
    r"\bpara\s+mi\b(?=\s*(?:[,.;:!?]|$|(?:es|fue|era|no|que|tambien|mismo|misma|sola|solo)\b))",
    r"\b(?:sentirme|me\s+siento)\b",
    # Lo que otra persona le hace (Semana 5): "que hago, mi papa me pega"
    # habla de quien escribe aunque pregunte "que hago".
    r"\bme\s+(?:pega|pegan|golpea|golpean|grita|gritan|insulta\w*|molesta\w*|hace\w*\s+bullying|toca\w*|amenaza\w*|acosa\w*|lastima\w*)\b",
    r"\bme\s+pasa\b",
    r"\blo\s+que\s+(?:me\s+pasa|siento|vivo)\b",
    r"\b(?:creo\s+que\s+)?tengo\s+(?:depresion|ansiedad|ganas\s+de)\b",
    r"\bpienso\s+en\b",
    # "que es la depresion, creo que la tengo"
    r"\b(?:la|lo|eso)\s+tengo\b",
    r"\bcreo\s+que\s+(?:tengo|soy|estoy|sufro|me)\b",
    r"\bme\s+identifico\b",
    r"\ba\s+mi\s+me\b",
)

TEMA_SUICIDIO = "suicidio"
TEMA_AUTOLESION = "autolesion"
TEMA_TRISTEZA = "tristeza"
TEMA_DEPRESION = "depresion"

_TEMAS = (
    (TEMA_SUICIDIO, r"\b(?:suicid\w*|quitarse\s+la\s+vida)\b"),
    (TEMA_AUTOLESION, r"\b(?:autoles\w*|cortarse|cutting|lastimarse|hacerse\s+dano)\b"),
    (TEMA_DEPRESION, r"\b(?:depresi\w*|deprimid\w*)\b"),
    (TEMA_TRISTEZA, r"\b(?:trist\w*|aguitad\w*)\b"),
)

# Los temas cuya informacion lleva siempre la tarjeta de lineas de ayuda,
# como recomiendan las guias para hablar de suicidio (OMS): sin alerta ni
# "habla con un adulto", solo los numeros a la vista.
TEMAS_CON_LINEAS = frozenset({TEMA_SUICIDIO, TEMA_AUTOLESION})


@dataclass(frozen=True)
class ContextoMensaje:
    informativa: bool
    tema: str | None
    motivo: str  # para la traza del servidor; nunca llega al estudiante


def _alguno(patrones: tuple[str, ...], plano: str) -> str | None:
    return next((p for p in patrones if re.search(p, plano)), None)


def tema_de(texto: str) -> str | None:
    plano = normalizar_chat(texto)
    return next((t for t, p in _TEMAS if re.search(p, plano)), None)


def analizar_contexto(texto: str) -> ContextoMensaje:
    """Lee la frase completa. Es consulta solo si pide informacion Y no
    habla de quien escribe."""
    if not texto or not texto.strip():
        return ContextoMensaje(False, None, "vacio")
    plano = normalizar_chat(texto)
    tema = tema_de(texto)
    personal = _alguno(_HABLA_DE_SI, plano)
    if personal:
        return ContextoMensaje(False, tema, "habla de si")
    if _alguno(_PIDE_INFORMACION, plano):
        return ContextoMensaje(True, tema, "pide informacion")
    return ContextoMensaje(False, tema, "sin pedido de informacion")
