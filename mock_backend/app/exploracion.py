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
# Semana 4 (asesor, 16 oct): "la aproximación de los problemas de salud
# mental tiene que ver mucho con el funcionamiento de la vida diaria", y
# preguntar por antecedentes (sugirió OxMIS). OxMIS se validó en Suecia para
# esquizofrenia y trastorno bipolar y da un puntaje de riesgo; aquí NO se
# calcula ningún puntaje: solo se toman, como preguntas, los antecedentes que
# también aplican a adolescentes (que ya haya pasado antes, autolesión previa
# y consumo de sustancias). Los antecedentes familiares los decide psicología.
FUNCIONAMIENTO = (
    "¿Cómo has estado durmiendo y comiendo estos días? ¿Has podido ir a la escuela y hacer tus cosas como siempre?",
)
ANTECEDENTE_ANTES = "¿Te había pasado antes sentirte así? ¿Alguna vez te has lastimado cuando te sientes así?"
ANTECEDENTE_SUSTANCIAS = (
    "A veces la gente usa alcohol u otras cosas para sentirse mejor un rato. ¿A ti te ha pasado?"
)

PREGUNTAS_GENERALES = (
    "Gracias por decírmelo; me importa cómo estás. ¿Quieres contarme un poco más de lo que te está pasando?",
    "Aquí sigo contigo. ¿Qué es lo que más te pesa ahorita?",
)
# Si hay varias senales, primero la mas especifica.
_PRIORIDAD = ("autolesion_ocurrida", "hiperbole_muerte", "carga_percibida", "desesperanza_extrema")


def secuencia_seguimiento(categorias: Iterable[str]) -> tuple[str, ...]:
    """Las preguntas en el orden en que se hacen: primero las de la señal,
    después cómo funciona en su vida diaria y al final los antecedentes."""
    presentes = set(categorias)
    categoria = next((c for c in _PRIORIDAD if c in presentes), None)
    propias = PREGUNTAS_SEGUIMIENTO[categoria] if categoria else PREGUNTAS_GENERALES
    # Con autolesion ya se sabe que se lastimo: no se pregunta otra vez.
    antes = () if categoria == "autolesion_ocurrida" else (ANTECEDENTE_ANTES,)
    return (*propias, *FUNCIONAMIENTO, *antes, ANTECEDENTE_SUSTANCIAS)


def pregunta_seguimiento(categorias: Iterable[str], respuestas_previas: Iterable[str] = ()) -> str:
    """La siguiente pregunta que Serena no ha hecho en esta conversación
    (Semana 4: antes solo se evitaba repetir las dos últimas). Si ya se
    hicieron todas, se repite la última."""
    opciones = secuencia_seguimiento(categorias)
    dichas = set(respuestas_previas)
    return next((o for o in opciones if o not in dichas), opciones[-1])


def lineas_para(mensaje: str, con_lineas_crisis: bool) -> tuple[Mapping[str, str], ...]:
    """Las lineas que se muestran en la tarjeta: las de crisis cuando hay
    riesgo y CIJ cuando el mensaje habla de sustancias."""
    lineas = LINEAS_CRISIS if con_lineas_crisis else ()
    if TEMA_SUSTANCIAS in temas_de(mensaje):
        lineas = lineas + (LINEA_CIJ,)
    return lineas
