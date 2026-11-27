"""Compuerta y contexto de cada turno de Serena (antes del LLM).

PROTOTIPO (Semana 2). Serena sigue en desarrollo y /chat sigue siendo una
respuesta fija; este modulo prepara lo que se le mandaria al modelo cuando
exista, y muestra la propuesta del asesor: analizar la pregunta, obtener su
polaridad e incluirla en el prompt para que la respuesta vaya guiada por
ella.

Por cada mensaje del estudiante:

  1. Clasificador de riesgo por reglas + analizador de sentimientos ->
     hechos -> motor de Wang (igual que el diario).
  2. Si la decision es CRISIS: el mensaje NO llega al LLM. Se devuelve un
     guion fijo con lineas de ayuda, se detiene la conversacion y se arma
     la alerta para el administrador. Es lo mismo que hacen los asistentes
     comerciales con un clasificador de entrada, pero aqui la decision es
     auditable (la prueba de Wang dice que regla se cumplio).
  3. Si no: se arma el prompt de sistema con un bloque de "contexto
     interno" (polaridad, emociones, intencion y estrategia de respuesta).

Nunca se manda al modelo el nombre, la CURP ni otro dato que identifique al
estudiante.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from types import MappingProxyType
from typing import Mapping

from .analizador_sentimiento import AnalizadorNoDisponible, AnalizadorSentimiento, ResultadoSentimiento
from .clasificador_riesgo import clasificar_mensaje, combinar_con_nivel_cssrs
from .contexto_mensaje import analizar_contexto
from .evaluador_diario import LINEAS_AYUDA, UMBRAL_CONFIANZA
from .motor_wang import ACCION_CRISIS, ACCION_EXPLORAR, Decision, decidir

INTENCION_INFORMATIVA = "pregunta_informativa"
INTENCION_CONSEJO = "pide_consejo"
INTENCION_DESAHOGO = "desahogo"

_CONSEJO = re.compile(
    r"\b(que\s+hago|como\s+(?:puedo|le\s+hago|hago)|ayudame|necesito\s+ayuda|que\s+me\s+recomiendas|"
    r"algun\s+consejo|que\s+deberia)\b"
)
_INFORMATIVA = re.compile(
    r"^(?:que\s+(?:es|son|significa)|por\s+que|como\s+(?:funciona|se\s+)|cual(?:es)?\s|cuando\s|"
    r"es\s+normal|existe)"
)

PROMPT_BASE = """Eres Serena, el asistente de apoyo emocional de APPlicatuMente para estudiantes \
de secundaria y bachillerato en México. Reglas que nunca rompes:
- No diagnosticas ni das tratamiento; no eres psicóloga ni una persona.
- Respondes solo con el contenido psicoeducativo aprobado que se te entrega; no digas de dónde sale \
(las fuentes las muestra la app).
- Nunca mencionas métodos de autolesión o suicidio.
- No prometes confidencialidad absoluta.
- Lenguaje sencillo, cálido y breve (máximo 4 oraciones)."""

_ESTRATEGIA = {
    "negativo": "Valida la emoción antes de cualquier sugerencia, sin minimizarla. Haz una sola "
    "pregunta abierta y ofrece una técnica concreta del módulo que corresponda.",
    "neutro": "Explora con una pregunta abierta cómo fue su día; no asumas que hay un problema.",
    "positivo": "Refuerza lo que salió bien y pregunta qué lo hizo posible; no cambies el tema a problemas.",
    "desconocida": "No se pudo estimar el tono: responde neutral y pregunta cómo se siente.",
}

_ESTRATEGIA_INFORMATIVA = (
    "Responde la pregunta de forma clara con el contenido aprobado. Al final, pregunta con suavidad "
    "si lo pregunta por algo que le está pasando."
)

_ESTRATEGIA_EXPLORAR = (
    "Hay una señal ambigua de riesgo: explora con cuidado, con lenguaje directo y sin alarmar, si "
    "está pensando en hacerse daño, y menciona las líneas de ayuda."
)

# BORRADOR: el texto final lo redacta la psicóloga (revisión clínica, apartado B).
GUION_CRISIS = (
    "Gracias por contármelo. Lo que sientes es importante y no tienes que pasarlo sin compañía. "
    "Ahora mismo te pueden escuchar personas preparadas para esto: "
    + "; ".join(f"{l['nombre']}: {l['telefono']} ({l['horario']})" for l in LINEAS_AYUDA)
    + ". Vamos a avisar a un adulto responsable para que te acompañe."
)


@dataclass(frozen=True)
class TurnoSerena:
    detener_conversacion: bool
    respuesta_fija: str
    mensajes_llm: tuple[Mapping[str, str], ...]
    decision: Decision
    analisis: ResultadoSentimiento | None
    intencion: str
    mostrar_lineas_ayuda: bool
    alerta_admin: Mapping[str, object] | None


def _plano(texto: str) -> str:
    t = unicodedata.normalize("NFD", texto.lower())
    t = "".join(c for c in t if unicodedata.category(c) != "Mn")
    return re.sub(r"[¿?¡!.,;]", " ", t).strip()


def detectar_intencion(mensaje: str) -> str:
    """Primer borrador por reglas. Una version siguiente lo haria el propio
    LLM o un clasificador; aqui basta para mostrar el flujo."""
    plano = _plano(mensaje)
    if _CONSEJO.search(plano):
        return INTENCION_CONSEJO
    # Semana 4: tambien "quiero informacion sobre...", "material de...".
    if _INFORMATIVA.search(plano) or analizar_contexto(mensaje).informativa:
        return INTENCION_INFORMATIVA
    return INTENCION_DESAHOGO


def _contexto_interno(analisis: ResultadoSentimiento | None, intencion: str, decision: Decision) -> str:
    if analisis is not None and analisis.probabilidad(analisis.polaridad) >= UMBRAL_CONFIANZA:
        polaridad = analisis.polaridad
        confianza = f"{analisis.probabilidad(polaridad):.0%}"
        emociones = ", ".join(e for e, p in analisis.emociones[:2] if p >= 0.2) or "sin emoción clara"
    else:
        polaridad, confianza, emociones = "desconocida", "-", "-"
    if intencion == INTENCION_INFORMATIVA:
        # En una pregunta informativa la polaridad mide el tono del TEMA
        # ("ansiedad" suena negativo), no como se siente quien pregunta.
        estrategia = _ESTRATEGIA_INFORMATIVA
    else:
        estrategia = _ESTRATEGIA[polaridad]
    if decision.accion == ACCION_EXPLORAR:
        estrategia += " " + _ESTRATEGIA_EXPLORAR
    return (
        "Contexto interno de este mensaje (no lo menciones ni lo cites):\n"
        f"- polaridad: {polaridad} (confianza {confianza})\n"
        f"- emociones: {emociones}\n"
        f"- intención: {intencion}\n"
        f"- estrategia: {estrategia}"
    )


def preparar_turno(
    mensaje: str,
    analizador: AnalizadorSentimiento,
    historial: tuple[Mapping[str, str], ...] = (),
    nivel_cssrs: str | None = None,
    # Se reciben para dejar explicito que existen y que NO se mandan al modelo.
    nombre_estudiante: str | None = None,
    curp: str | None = None,
) -> TurnoSerena:
    riesgo = combinar_con_nivel_cssrs(clasificar_mensaje(mensaje), nivel_cssrs)
    try:
        analisis: ResultadoSentimiento | None = analizador.analizar(mensaje)
    except AnalizadorNoDisponible:
        analisis = None

    hechos = set(riesgo.categorias)
    if analisis is not None and analisis.probabilidad(analisis.polaridad) >= UMBRAL_CONFIANZA:
        hechos.add({"positivo": "polaridad_positiva", "neutro": "polaridad_neutra", "negativo": "polaridad_negativa"}[analisis.polaridad])
    decision = decidir(hechos)
    intencion = detectar_intencion(mensaje)

    if decision.accion == ACCION_CRISIS:
        alerta = MappingProxyType(
            {
                "tipo": "riesgo_en_chat",
                "nivel": decision.meta,
                "reglas": decision.reglas_usadas,
                "evidencia": riesgo.evidencia,
                "prueba": decision.prueba.pasos,
            }
        )
        return TurnoSerena(True, GUION_CRISIS, (), decision, analisis, intencion, True, alerta)

    sistema = PROMPT_BASE + "\n\n" + _contexto_interno(analisis, intencion, decision)
    mensajes = (
        (MappingProxyType({"role": "system", "content": sistema}),)
        + tuple(historial)
        + (MappingProxyType({"role": "user", "content": mensaje}),)
    )
    return TurnoSerena(
        detener_conversacion=False,
        respuesta_fija="",
        mensajes_llm=mensajes,
        decision=decision,
        analisis=analisis,
        intencion=intencion,
        mostrar_lineas_ayuda=decision.accion == ACCION_EXPLORAR,
        alerta_admin=None,
    )
