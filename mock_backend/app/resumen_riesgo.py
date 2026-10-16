"""Resumen de las alertas de un estudiante para el administrador y el tutor.

Semana 4 (reunion con el asesor, 9 de octubre): que Serena no corte la
conversacion y que lo ocurrido quede en un resumen que el administrador o
los padres puedan leer e interpretar ("se le presento una crisis de este
tipo, menciono ideas negativas...").

Como se arma:

  - Solo con lo que ya guarda alertas_riesgo: origen, nivel, reglas y fecha.
    NUNCA con los mensajes del estudiante (la base no los guarda).
  - Cada regla del motor de Wang se traduce a una frase en lenguaje
    cotidiano; la frase sale de la regla, no de un modelo, asi que no
    inventa nada y se puede auditar.
  - Dos versiones: la del administrador (que paso, cuando, que falta
    atender) y la del tutor (general, sin detalles de lo que escribio).

IA generativa: cuando exista el servidor con GPU, un modelo de 3B o mas
podra REDACTAR este resumen con mas fluidez, recibiendo solo el resumen
estructurado (nunca los mensajes) y pasando por la guardia de salida. Con el
modelo de 1,5B del servidor actual no se hace: tarda y no es confiable.

ESTADO: BORRADORES. Que ve el tutor, y cuando, lo deciden el asesor y
psicologia (confidencialidad del adolescente); por eso la version del tutor
no se envia a nadie todavia.
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from datetime import datetime
from typing import Iterable, Mapping, Sequence

# Que significa cada regla, dicho para un adulto que no conoce el sistema.
REGLA_EN_PALABRAS: Mapping[str, str] = {
    "R1": "expresó deseo de morir",
    "R2": "habló de un plan o de la intención de hacerse daño",
    "R3": "contó que se lastimó a propósito",
    "R3b": "contó que se lastimó, junto con otras ideas negativas",
    "R4": "escribió algo parecido a una despedida",
    "R5": "el cuestionario de Columbia marcó riesgo alto",
    "R6": "expresó desesperanza y pidió guardar un secreto",
    "R7": "expresó desesperanza y sentirse una carga",
    "R8": "pidió guardar un secreto y dijo sentirse una carga",
    "R11": "pidió formas de hacerse daño",
    "R13": "dijo que «ya lo decidió» después de hablar de desesperanza",
    "R14": "repitió ideas negativas (desesperanza o sentirse una carga) en la misma conversación",
    "R16": "preguntó por formas de hacerse daño sin decir que fueran para sí",
}
SALIDA_BLOQUEADA = "Serena detuvo una respuesta que no era segura"

ORIGEN_EN_PALABRAS: Mapping[str, str] = {
    "chat": "en el chat con Serena",
    "chat_acumulado": "en el chat con Serena",
    "chat_autolesion": "en el chat con Serena",
    "chat_metodo": "en el chat con Serena",
    "chat_salida": "en el chat con Serena",
    "diario": "en su diario",
}

NIVELES_ALTOS = frozenset({"riesgo_alto"})


@dataclass(frozen=True)
class Alerta:
    origen: str
    nivel: str | None
    reglas: tuple[str, ...]
    fecha: datetime
    atendida: bool = False

    @property
    def es_crisis(self) -> bool:
        return self.nivel in NIVELES_ALTOS


@dataclass(frozen=True)
class Resumen:
    administrador: str
    tutor: str
    crisis: int
    preventivas: int
    pendientes: int


def alerta_de_fila(fila: Mapping[str, object]) -> Alerta:
    return Alerta(
        origen=str(fila["origen"]),
        nivel=fila.get("nivel"),  # type: ignore[arg-type]
        reglas=tuple(str(r) for r in (fila.get("reglas") or ())),  # type: ignore[union-attr]
        fecha=fila["fecha_creacion"],  # type: ignore[arg-type]
        atendida=bool(fila.get("atendida")),
    )


_MESES = ("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
          "septiembre", "octubre", "noviembre", "diciembre")


def _dia(f: datetime) -> str:
    return f"{f.day} de {_MESES[f.month - 1]}"


def _frases(alerta: Alerta) -> tuple[str, ...]:
    if alerta.origen == "chat_salida":
        return (SALIDA_BLOQUEADA,)
    return tuple(REGLA_EN_PALABRAS[r] for r in alerta.reglas if r in REGLA_EN_PALABRAS) or ("mostró señales de riesgo",)


def _lista(frases: Iterable[str]) -> str:
    unicas = list(dict.fromkeys(frases))
    if len(unicas) <= 1:
        return "".join(unicas)
    return ", ".join(unicas[:-1]) + " y " + unicas[-1]


def _renglon(alerta: Alerta) -> str:
    tipo = "Crisis" if alerta.es_crisis else "Aviso preventivo"
    donde = ORIGEN_EN_PALABRAS.get(alerta.origen, "en la app")
    estado = "atendida" if alerta.atendida else "pendiente"
    return f"- {_dia(alerta.fecha)}, {donde}. {tipo}: {_lista(_frases(alerta))} ({estado})."


def resumir(alertas: Sequence[Alerta], nombre: str = "el estudiante") -> Resumen:
    """Las alertas de UN estudiante, de la mas antigua a la mas reciente."""
    ordenadas = sorted(alertas, key=lambda a: a.fecha)
    crisis = sum(a.es_crisis for a in ordenadas)
    preventivas = len(ordenadas) - crisis
    pendientes = sum(not a.atendida for a in ordenadas)
    if not ordenadas:
        sin = f"No hay alertas de {nombre} en este periodo."
        return Resumen(sin, "", 0, 0, 0)

    periodo = f"del {_dia(ordenadas[0].fecha)} al {_dia(ordenadas[-1].fecha)}"
    conteo = Counter(f for a in ordenadas for f in _frases(a))
    lo_mas = _lista(f for f, _ in conteo.most_common(2))
    administrador = "\n".join(
        [
            f"Resumen de {nombre}, {periodo}: {crisis} crisis y {preventivas} avisos preventivos; "
            f"{pendientes} sin atender.",
            f"Lo más frecuente: {lo_mas}.",
            *(_renglon(a) for a in ordenadas),
            "Este resumen se arma con las reglas que se activaron; no incluye lo que escribió el estudiante.",
        ]
    )
    tutor = _resumen_tutor(nombre, crisis > 0)
    return Resumen(administrador, tutor, crisis, preventivas, pendientes)


def _resumen_tutor(nombre: str, hubo_crisis: bool) -> str:
    # Sin detalles de lo que escribio: solo que hubo senales y que hacer.
    gravedad = (
        f"la app detectó señales de que {nombre} está pasando por un momento muy difícil"
        if hubo_crisis
        else f"la app detectó algunas señales de malestar en {nombre}"
    )
    return (
        f"En los últimos días {gravedad}. Le sugerimos buscar un momento tranquilo para platicar, "
        "escuchar sin juzgar y preguntarle directamente cómo está. "
        "Si cree que su seguridad está en peligro, llame al 911. "
        "También pueden llamar juntos a la Línea de la Vida (800 911 2000, 24 horas, gratuita)."
    )
