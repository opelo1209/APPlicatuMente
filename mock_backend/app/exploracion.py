"""Preguntar antes de clasificar y lineas de ayuda aparte (Semana 4).

Revision clinica de la Dra. Gonzalez y nota del asesor: una frase de riesgo
no debe clasificar al estudiante por si sola, "mas que corregirlas se
deberian ligar a otras preguntas". Antes, toda senal ambigua recibia el
mismo texto fijo (RESPUESTA_SEGURA_EXPLORAR), que ademas se repetia igual en
cada mensaje. Ahora cada senal lleva a la pregunta que pidio psicologia:

- desesperanza: desde cuando y con que frecuencia;
- ser una carga: como le va en las esferas de su vida (casa, escuela, amigos);
- autolesion: es senal, pero no urgencia; se pregunta y se busca un adulto;
- hiperbole ("me quiero morir de la verguenza"): se pregunta si es literal.

Las lineas de ayuda ya no van pegadas al texto: se devuelven aparte para que
la app las muestre en una tarjeta (como Gemini y ChatGPT), y el texto de la
conversacion no repite el mismo parrafo en cada mensaje.

ESTADO: BORRADORES para psicologia, igual que los demas textos fijos.
"""

from __future__ import annotations

from types import MappingProxyType
from typing import Iterable, Mapping

from .evaluador_diario import LINEAS_AYUDA
from .recuperador_corpus import temas_de

TEMA_SUSTANCIAS = "Consumo de sustancias"

LINEAS_CRISIS: tuple[Mapping[str, str], ...] = tuple(MappingProxyType(dict(l)) for l in LINEAS_AYUDA)
# Revision clinica (Semana 4): la doctora la agrego para el uso de sustancias.
# Falta confirmar el horario; mientras, se dice para que es.
LINEA_CIJ: Mapping[str, str] = MappingProxyType(
    {"nombre": "CIJ Contigo", "telefono": "55 5212 1212", "horario": "orientación sobre consumo de sustancias"}
)

# Cuantas respuestas anteriores se revisan para no repetir la misma pregunta.
SIN_REPETIR_TURNOS = 2

PREGUNTAS_SEGUIMIENTO: Mapping[str, tuple[str, ...]] = MappingProxyType(
    {
        "autolesion_ocurrida": (
            "Gracias por confiarme algo así; no estás en problemas por contármelo. A veces lastimarse es "
            "una forma de aguantar algo que duele mucho por dentro. ¿Hace cuánto te pasa y cómo estás ahorita?",
            "Me importa cómo estás. ¿Hay algún adulto con quien te sientas seguro para contarle lo que te pasa? "
            "Si quieres, pensamos juntos cómo decírselo.",
        ),
        "hiperbole_muerte": (
            "Te leo. A veces decimos «me quiero morir» como expresión y a veces se siente de verdad. "
            "¿Cómo lo dices tú ahorita?",
            "Si alguna vez lo has sentido de verdad, me lo puedes decir sin problema. ¿Qué pasó?",
        ),
        "carga_percibida": (
            "Gracias por contármelo. A veces uno siente que estorba cuando algo no va bien. "
            "¿Cómo te va últimamente en casa, en la escuela y con tus amigos?",
            "Lo que sientes importa, y tú también. ¿En qué momentos sientes más que eres una carga?",
        ),
        "desesperanza_extrema": (
            "Gracias por decírmelo; me importa cómo estás. ¿Desde cuándo te sientes así? "
            "¿Te pasa seguido o fue por algo de hoy?",
            "Suena a que llevas un rato cargando con esto. ¿Qué es lo que más te pesa ahorita?",
        ),
    }
)
PREGUNTAS_GENERALES = (
    "Gracias por decírmelo; me importa cómo estás. ¿Quieres contarme un poco más de lo que te está pasando?",
    "Aquí sigo contigo. ¿Qué es lo que más te pesa ahorita?",
)
# Si hay varias senales, primero la mas especifica.
_PRIORIDAD = ("autolesion_ocurrida", "hiperbole_muerte", "carga_percibida", "desesperanza_extrema")


def pregunta_seguimiento(categorias: Iterable[str], respuestas_previas: Iterable[str] = ()) -> str:
    """La pregunta que corresponde a la senal, sin repetir la que Serena
    acaba de decir. Si ya se dijeron todas, se usa la ultima."""
    presentes = set(categorias)
    opciones = next((PREGUNTAS_SEGUIMIENTO[c] for c in _PRIORIDAD if c in presentes), PREGUNTAS_GENERALES)
    recientes = set(list(respuestas_previas)[-SIN_REPETIR_TURNOS:])
    return next((o for o in opciones if o not in recientes), opciones[-1])


def lineas_para(mensaje: str, con_lineas_crisis: bool) -> tuple[Mapping[str, str], ...]:
    """Las lineas que se muestran en la tarjeta: las de crisis cuando hay
    riesgo y CIJ cuando el mensaje habla de sustancias."""
    lineas = LINEAS_CRISIS if con_lineas_crisis else ()
    if TEMA_SUSTANCIAS in temas_de(mensaje):
        lineas = lineas + (LINEA_CIJ,)
    return lineas
