"""Textos para que Serena no corte la conversacion (Semana 4).

Reunion con el asesor (9 de octubre): "nunca se corta la conversacion si hay
alguien en riesgo". Antes, una crisis pausaba el chat: el estudiante leia el
guion y ya no podia escribir. Ahora:

  - la primera crisis da el guion completo; si la crisis se repite, un texto
    mas corto que no repite el mismo parrafo (las lineas van en la tarjeta);
  - los mensajes que siguen a una crisis reciben acompanamiento: si esta a
    salvo ahora, quien esta cerca, ayudar a dar el paso de llamar o escribir;
  - pedir metodos "en general" (tarea, cuento) recibe un limite: no se dan,
    se ofrece lo que si se puede y se pregunta con cuidado;
  - una consulta ("que es la tristeza") recibe informacion, sin suponer que
    la persona se siente asi.

ESTADO: BORRADORES para psicologia, igual que los demas textos fijos.
"""

from __future__ import annotations

from types import MappingProxyType
from typing import Iterable, Mapping

from .contexto_mensaje import TEMA_AUTOLESION, TEMA_DEPRESION, TEMA_SUICIDIO, TEMA_TRISTEZA

CRISIS_REPETIDA = (
    "Sigo aquí contigo y me importa que estés a salvo. ¿Estás en un lugar seguro ahorita? "
    "Si puedes, busca a alguien que esté cerca o llama a una de las líneas de abajo; es gratis y te escuchan.",
    "No tienes que pasar esto sin compañía. Abajo están los números de personas preparadas para escucharte. "
    "¿Hay algún adulto cerca de ti en este momento?",
)

ACOMPANAR_CRISIS = (
    "Aquí sigo. ¿Cómo estás en este momento? ¿Estás en un lugar seguro?",
    "Gracias por seguir platicando conmigo. ¿Hay alguien cerca de ti ahorita, alguien con quien te sientas seguro?",
    "Si quieres, te ayudo a dar el paso: podemos escribir juntos lo que le dirías a un adulto, "
    "o te cuento qué pasa cuando llamas a la línea. ¿Qué prefieres?",
    "Cuando todo se siente demasiado, puede ayudar respirar despacio: inhala contando cuatro, "
    "sostén cuatro y exhala contando seis. ¿Lo intentamos juntos y me cuentas cómo vas?",
)

LIMITE_METODO = (
    "No puedo dar información sobre formas de hacerse daño, ni para una tarea o una historia: "
    "ese tipo de datos puede poner en peligro a alguien. Lo que sí puedo es contarte las señales de alerta, "
    "cómo ayudar a una persona que la está pasando mal y a dónde llamar. "
    "Y si lo preguntas por algo que te está pasando a ti, me lo puedes contar. ¿Cómo estás tú?"
)

# Para temas que no tienen modulo en la app. Psicoeducacion general, sin
# datos medicos; los revisa psicologia antes de usarse fuera del prototipo.
FICHAS_INFORMATIVAS: Mapping[str, str] = MappingProxyType(
    {
        TEMA_TRISTEZA: (
            "La tristeza es una emoción normal: aparece cuando perdemos algo o algo no sale como esperábamos, "
            "y nos ayuda a detenernos y pedir apoyo. Suele bajar con el tiempo, al platicarlo o al hacer cosas "
            "que nos gustan. Si dura casi todos los días por más de dos semanas o no deja hacer lo de siempre, "
            "vale la pena platicarlo con un profesional."
        ),
        TEMA_DEPRESION: (
            "La depresión es más que estar triste: es un estado que dura semanas, casi todos los días, con "
            "pocas ganas de hacer cosas, cambios en el sueño o el apetito y cansancio. Tiene tratamiento, y "
            "quien puede saber si alguien la tiene es un profesional de la salud mental."
        ),
        TEMA_SUICIDIO: (
            "El suicidio se puede prevenir. Algunas señales de alerta son hablar de querer morir o de ser una "
            "carga, despedirse o regalar sus cosas, y alejarse de todos. Si notas esto en alguien, pregúntale "
            "cómo está, escúchalo sin juzgar y busquen juntos a un adulto o una línea de ayuda."
        ),
        TEMA_AUTOLESION: (
            "La autolesión es hacerse daño a propósito, sin querer morir; muchas veces es una forma de aguantar "
            "un dolor emocional muy fuerte. No es para llamar la atención y sí tiene salida: hablarlo con "
            "alguien de confianza o con un profesional ayuda."
        ),
    }
)

CIERRE_INFORMATIVO = "¿Quieres saber algo más del tema?"
APERTURA_INFORMATIVA = "Claro, te cuento."


def sin_repetir(opciones: tuple[str, ...], respuestas_previas: Iterable[str]) -> str:
    """La primera opcion que Serena no dijo en esta conversacion; si ya dijo
    todas, la que dijo hace mas tiempo."""
    previas = list(respuestas_previas)
    nuevas = [o for o in opciones if o not in previas]
    if nuevas:
        return nuevas[0]
    return min(opciones, key=lambda o: max(i for i, p in enumerate(previas) if p == o))
