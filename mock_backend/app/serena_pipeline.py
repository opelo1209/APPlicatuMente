"""Cadena completa de Serena: cuatro barreras alrededor del modelo.

PROTOTIPO (Semana 3). Sigue el patron de los asistentes comerciales
(DALL-E 3: clasificador de entrada -> transformacion -> generacion ->
clasificador de salida), con una diferencia: cada decision la toma el motor
de Wang y queda su prueba.

  1. ENTRADA   riesgo + contexto + polaridad + limites -> Wang (METAS_SERENA)
               crisis  -> guion fijo, alerta, lineas a la vista (sin LLM).
                          Semana 4: el chat NO se detiene; lo que sigue es
                          acompanar (R18)
               limite  -> respuesta fija que explica el limite (sin LLM)
  2. CONTENIDO recuperar textos aprobados del corpus de la app
  3. MODELO    LLM local redacta SOLO con ese contenido y la estrategia de
               la polaridad (si no hay modelo: respuesta con el contenido)
  4. SALIDA    guardia de salida -> Wang (METAS_SALIDA)
               bloquear -> respuesta segura + alerta; o agregar lineas
"""

from __future__ import annotations

import logging
import os
import re
import threading
import time
import zlib
from dataclasses import dataclass, field
from types import MappingProxyType
from typing import Callable, Mapping

from .acompanamiento import (
    ACOMPANAR_CRISIS,
    APERTURA_INFORMATIVA,
    CIERRE_INFORMATIVO,
    CRISIS_REPETIDA,
    FICHAS_INFORMATIVAS,
    LIMITE_METODO,
    sin_repetir,
)
from .analizador_sentimiento import AnalizadorNoDisponible, AnalizadorSentimiento, ResultadoSentimiento
from .clasificador_riesgo import clasificar_mensaje, combinar_con_nivel_cssrs
from .evaluador_diario import UMBRAL_CONFIANZA
from .contexto_mensaje import HECHO_CONSULTA, TEMAS_CON_LINEAS, analizar_contexto
from .exploracion import lineas_para, pregunta_seguimiento
from .generador_llm import GeneradorNoDisponible, GeneradorRespuesta
from .guardia_salida import LINEAS_TEXTO, aplicar_guardia
from .limites_serena import hechos_de_limites
from .memoria_sesion import SENAL_ALTA, SENAL_AMBIGUA, SENAL_NINGUNA, Turno, hechos_de_sesion
from .motor_wang import (
    ACCION_ACOMPANAR_CRISIS,
    ACCION_ALERTA_PREVENTIVA,
    ACCION_APOYO_AUTOLESION,
    ACCION_APOYO_TERCERO,
    ACCION_CRISIS,
    ACCION_EXPLORAR,
    ACCION_INFORMAR,
    ACCION_LIMITE_DIAGNOSTICO,
    ACCION_LIMITE_IDENTIDAD,
    ACCION_LIMITE_MEDICACION,
    ACCION_LIMITE_METODO,
    ACCION_LIMITE_SECRETO,
    ACCION_SUGERIR_APOYO,
    METAS_SERENA,
    Decision,
    decidir,
)
from .recuperador_corpus import Fragmento, recuperar
from .recuperador_corpus import _tokens as _tokens_recuperador
from .revision_clinica import revision_de
from .serena_contexto import GUION_CRISIS, INTENCION_INFORMATIVA, PROMPT_BASE, _contexto_interno, detectar_intencion

# BORRADOR: textos de limite. Los redacta en definitiva psicologia. Siguen la
# forma de los avisos comerciales: dicen QUE no se puede, POR QUE, y QUE SI
# se puede hacer.
# BORRADOR (Fase 1b): el riesgo es de otra persona ("mi amiga dice que se
# quiere morir"). No se trata al estudiante como en crisis ni se pausa el
# chat; se le orienta para no guardar el secreto y avisar hoy a un adulto.
RESPUESTA_APOYO_TERCERO = (
    "Qué bueno que quieras ayudar. Si alguien te dice que se quiere morir o que se lastima, tómalo en serio: "
    "no lo guardes como secreto y cuéntaselo hoy a un adulto de confianza (tus papás, un maestro u orientación). "
    "También pueden llamar juntos a la Línea de la Vida (800 911 2000, 24 horas, gratuita) o a SAPTEL (55 5259 8121). "
    "¿Quieres que pensemos cómo decírselo a un adulto?"
)

RESPUESTAS_LIMITE = {
    ACCION_LIMITE_DIAGNOSTICO: (
        "No puedo darte un diagnóstico: eso solo lo puede hacer un profesional de la salud mental "
        "después de platicar contigo con calma. Lo que sí puedo es escucharte y contarte qué "
        "señales vale la pena platicar con un adulto de confianza o con orientación de tu escuela. "
        "¿Qué es lo que te ha hecho preguntártelo?"
    ),
    ACCION_LIMITE_MEDICACION: (
        "No puedo recomendarte ningún medicamento ni pastilla: tomar algo sin que lo indique un "
        "médico puede hacerte daño. Un médico o tu centro de salud pueden revisarlo contigo. "
        "Si quieres, te cuento algunas cosas que a muchas personas les ayudan a dormir o a calmarse."
    ),
    ACCION_LIMITE_SECRETO: (
        "Quiero ser honesta contigo: no puedo prometerte guardar todo en secreto. La mayoría de lo "
        "que platiquemos se queda aquí, pero si me cuentas algo que ponga en riesgo tu seguridad, "
        "lo correcto es avisar a un adulto que pueda ayudarte. Aun así, puedes contarme: ¿de qué se trata?"
    ),
    ACCION_LIMITE_IDENTIDAD: (
        "No soy una persona: soy Serena, un asistente automático de la app. No reemplazo a un "
        "psicólogo ni a alguien de confianza, pero puedo escucharte y orientarte con información "
        "revisada. ¿En qué te puedo ayudar?"
    ),
}

SIN_MODELO = "sin modelo (solo contenido aprobado)"
SIN_MODELO_FICHA = "sin modelo (consulta con ficha)"

log = logging.getLogger("aptm.serena")


@dataclass(frozen=True)
class RespuestaSerena:
    texto: str
    tipo: str  # crisis | limite | explorar | normal | bloqueada
    # Semana 4: siempre False (el chat nunca se corta). Se conserva el campo
    # para no romper versiones anteriores de la app.
    detener: bool
    fuentes: tuple[Mapping[str, str], ...]
    etapas: Mapping[str, object]
    alerta: Mapping[str, object] | None = field(default=None)
    # Fase 2: lo que se guarda en la memoria de la sesion.
    turno: Turno | None = field(default=None)
    # Semana 4: lineas de ayuda para la tarjeta de la app, fuera del texto.
    lineas: tuple[Mapping[str, str], ...] = field(default=())


def _decision_dict(d: Decision) -> dict[str, object]:
    return {"accion": d.accion, "reglas": list(d.reglas_usadas), "hechos": sorted(d.hechos), "prueba": list(d.prueba.pasos)}


def _analizar(mensaje: str, analizador: AnalizadorSentimiento) -> ResultadoSentimiento | None:
    try:
        return analizador.analizar(mensaje)
    except (AnalizadorNoDisponible, ValueError):
        return None


# Parte FIJA del prompt, siempre primero: llama.cpp reutiliza el prefijo que
# no cambia entre mensajes y no lo vuelve a procesar (en el servidor, procesar
# el prompt es lo que más tarda; ver reporte de la Semana 3).
PROMPT_SERENA = (
    PROMPT_BASE
    + "\n- Responde en español de México, tuteando, en 2 o 3 oraciones, sin listas ni formato."
    + "\n- No digas datos médicos que no estén en el contenido aprobado; si no está, no lo digas."
    + "\n- Modismos: «jefa/jefe» es mamá/papá; «agüitado» es triste; «neta» es en serio."
    + "\n- No supongas si es hombre o mujer: usa lenguaje neutro."
)
MAX_FRAGMENTOS = 2
MAX_CARACTERES_FRAGMENTO = 320

# Fase 4 (Semana 3): modo "breve". El modelo solo escribe UNA oracion de
# acompanamiento (tope real de tokens); despues va el texto aprobado tal cual
# y una invitacion fija a un adulto de confianza (C6 de la rubrica, que en la
# linea base fue 0 en 20 de 20). "completo" conserva el modo anterior.
MODO_BREVE = "breve"
MODO_COMPLETO = "completo"
MAX_TOKENS_BREVE = 60
# BORRADORES para psicologia.
INVITACIONES_ADULTO = (
    "Si quieres, también puedes platicarlo con un adulto de confianza o con orientación de tu escuela.",
    "Platicarlo con alguien de confianza, como tu familia o un maestro, también puede ayudarte.",
    "Recuerda que puedes buscar a un adulto de confianza para hablar de esto.",
)
INSTRUCCION_BREVE = (
    "Escribe UNA sola oración breve y cálida que reconozca lo que la persona dice o siente. "
    "No des consejos, técnicas ni datos: el contenido aprobado se agrega después."
)
# Semana 4: la persona pide informacion; no se supone que se siente asi.
INSTRUCCION_BREVE_INFORMAR = (
    "La persona pide información; no habla de cómo se siente: no supongas que le pasa a ella. "
    "Escribe UNA sola oración breve y amable que presente el tema, sin datos médicos."
)
INSTRUCCION_BREVE_INFORMAR_SIN_CONTENIDO = (
    "La persona pide información; no habla de cómo se siente: no supongas que le pasa a ella. "
    "Explica el tema en dos oraciones breves, en términos generales, sin datos médicos, "
    "sin diagnósticos y sin medicamentos."
)
INSTRUCCION_BREVE_SIN_CONTENIDO = (
    "Escribe como máximo dos oraciones breves: una que reconozca lo que la persona dice o siente "
    "y una pregunta abierta. No des consejos, técnicas ni datos."
)


MAX_TURNOS_CONTEXTO = 3
MAX_CARACTERES_TURNO = 300
# Velocidad (cierre S3): en modo breve el modelo escribe una sola oracion;
# basta el ultimo mensaje, recortado. Antes eran hasta 900 caracteres
# (~260 tokens, ~13 s en el servidor) que se releian en cada mensaje.
MAX_TURNOS_CONTEXTO_BREVE = 1
MAX_CARACTERES_TURNO_BREVE = 150


def _mensaje_con_contexto(mensaje: str, historial: tuple[Turno, ...], max_turnos: int, max_caracteres: int) -> str:
    """El mensaje del estudiante, precedido de lo que escribio antes (ultimos
    turnos normales, recortados). Va en el rol de USUARIO, nunca en el de
    sistema: es texto del estudiante y no debe tener autoridad de
    instruccion; ademas, asi el prompt de sistema cambia menos entre
    mensajes. Las respuestas de Serena NO se mandan: en el servidor, el
    modelo copiaba su formato ("Del material del programa: ...") e inventaba
    material que no existe (fase 4)."""
    previos = [t for t in historial if t.tipo in ("normal", "explorar")][-max_turnos:]
    if not previos:
        return mensaje
    citas = "; ".join(f"«{t.texto[:max_caracteres]}»" for t in previos)
    return f"(Antes te escribí: {citas})\n{mensaje}"


def _mensajes(
    mensaje: str,
    analisis,
    intencion: str,
    decision: Decision,
    fragmentos: tuple[Fragmento, ...],
    historial: tuple[Turno, ...] = (),
):
    if fragmentos:
        contenido = "Contenido aprobado (usa solo esto y dilo con tus palabras):\n" + "\n".join(
            f"[{i}] ({f.modulo}) {f.texto[:MAX_CARACTERES_FRAGMENTO]}"
            for i, f in enumerate(fragmentos[:MAX_FRAGMENTOS], 1)
        )
    else:
        contenido = (
            "Contenido aprobado: no hay nada sobre este tema. No des datos ni técnicas; acompaña, "
            "haz una pregunta abierta y sugiere hablar con un adulto de confianza."
        )
    sistema = f"{PROMPT_SERENA}\n\n{_contexto_interno(analisis, intencion, decision)}\n\n{contenido}"
    usuario = _mensaje_con_contexto(mensaje, historial, MAX_TURNOS_CONTEXTO, MAX_CARACTERES_TURNO)
    return (
        MappingProxyType({"role": "system", "content": sistema}),
        MappingProxyType({"role": "user", "content": usuario}),
    )


def _apertura_fija(analisis) -> str:
    return {
        "negativo": "Gracias por contármelo; suena a que no ha sido fácil.",
        "positivo": "¡Qué bueno leerte así!",
    }.get(getattr(analisis, "polaridad", ""), "Gracias por escribirme.")


_ORACION = re.compile(r"[^.!?¿¡]*[¿¡]?[^.!?]+[.!?]+")


def _oraciones(texto: str) -> list[str]:
    return [o.strip() for o in _ORACION.findall(texto) if o.strip()]


_MAYUS = "A-ZÁÉÍÓÚÜÑ"
_GRITO = re.compile(rf"\b[{_MAYUS}]{{2,}}\b(?:[\s,:]+\b[{_MAYUS}]+\b)+")


def _sin_gritos(oracion: str) -> str:
    """El corpus trae encabezados en mayusculas ("RESPIRA LENTO: ..."):
    en el chat se ven como gritos. Se pasan a oracion normal."""
    # Tramos de dos o mas palabras en mayusculas ("OPCIONES DE APOYO"); una
    # sigla suelta ("TDAH") se respeta.
    oracion = _GRITO.sub(lambda m: m.group(0).lower(), oracion)
    return oracion[:1].upper() + oracion[1:]


def extracto(texto: str, pregunta: str, max_oraciones: int = 2, max_caracteres: int = 260) -> str:
    """Las oraciones del texto aprobado que mas se relacionan con la pregunta
    (en su orden original). Se copian tal cual: no las reescribe el modelo."""
    plano = re.sub(r"(?m)^\s*(?:\d+[.)]|[-•*])\s+", "", texto)
    plano = re.sub(r"\s+", " ", plano).strip()
    oraciones = [_sin_gritos(o) for o in _oraciones(plano)] or [plano]
    claves = set(_tokens_recuperador(pregunta))
    puntaje = [(len(claves & set(_tokens_recuperador(o))), -i) for i, o in enumerate(oraciones)]
    elegidas = sorted(sorted(range(len(oraciones)), key=lambda i: puntaje[i], reverse=True)[:max_oraciones])
    texto_final = " ".join(oraciones[i] for i in elegidas)
    if len(texto_final) > max_caracteres:
        texto_final = oraciones[elegidas[0]][:max_caracteres].rstrip()
    return texto_final


def _invitacion(mensaje: str) -> str:
    return INVITACIONES_ADULTO[zlib.crc32(mensaje.encode("utf-8")) % len(INVITACIONES_ADULTO)]


# Semana 4: la invitacion iba en TODAS las respuestas normales y Serena
# sonaba repetitiva. Se omite si ya se dijo en las ultimas respuestas (de
# cualquier texto: invitacion, respuesta segura, limites). Crisis y limites
# no pasan por aqui; la sugerencia de apoyo de Wang (R10) la fuerza.
INVITACION_SIN_REPETIR_TURNOS = 2
_YA_INVITO = re.compile(r"adulto de confianza|alguien de confianza|orientaci[oó]n de tu escuela", re.IGNORECASE)


def _toca_invitar(historial, forzar: bool = False) -> bool:
    if forzar:
        return True
    recientes = list(historial)[-INVITACION_SIN_REPETIR_TURNOS:]
    return not any(_YA_INVITO.search(t.respuesta) for t in recientes)


def _mensajes_breve(mensaje, analisis, intencion, decision, fragmentos, historial, con_contenido=None):
    con_contenido = bool(fragmentos) if con_contenido is None else con_contenido
    if decision.accion == ACCION_INFORMAR:
        instruccion = INSTRUCCION_BREVE_INFORMAR if con_contenido else INSTRUCCION_BREVE_INFORMAR_SIN_CONTENIDO
    else:
        instruccion = INSTRUCCION_BREVE if con_contenido else INSTRUCCION_BREVE_SIN_CONTENIDO
    # Primero lo fijo (PROMPT_SERENA + instruccion): es el prefijo que
    # llama.cpp reutiliza entre mensajes y el que deja listo precalentar().
    sistema = f"{PROMPT_SERENA}\n- {instruccion}\n\n{_contexto_interno(analisis, intencion, decision)}"
    usuario = _mensaje_con_contexto(mensaje, historial, MAX_TURNOS_CONTEXTO_BREVE, MAX_CARACTERES_TURNO_BREVE)
    return (
        MappingProxyType({"role": "system", "content": sistema}),
        MappingProxyType({"role": "user", "content": usuario}),
    )


def _mayuscula(texto: str) -> str:
    return texto[:1].upper() + texto[1:]


def _cuerpo_breve(fragmentos, mensaje: str, invitar: bool = True) -> str:
    """Lo que NO escribe el modelo: material aprobado e invitacion."""
    partes = []
    if fragmentos:
        partes.append(f"Del material del programa: {extracto(fragmentos[0].texto, mensaje)}")
    if invitar:
        partes.append(_invitacion(mensaje))
    return " ".join(partes)


def _componer_breve(texto_guardia: str, necesarias: int, cuerpo: str, apertura_fija: str) -> str:
    oraciones = _oraciones(texto_guardia)
    apertura = _mayuscula(" ".join(oraciones[:necesarias]) or apertura_fija)
    return f"{apertura} {cuerpo}".strip()


def _oraciones_necesarias(fragmentos) -> int:
    return 1 if fragmentos else 2


def _generar_hasta(generador, mensajes, max_tokens: int, necesarias: int, avisar_oracion=None) -> str:
    """Fase 5: pide la respuesta por partes y corta en cuanto hay las
    oraciones necesarias. Cada oracion completa se ofrece a avisar_oracion
    (que decide si la muestra). Un generador sin partes responde de una vez."""
    por_partes = getattr(generador, "generar_partes", None)
    if por_partes is None:
        return generador.generar(mensajes, max_tokens=max_tokens)
    texto, avisadas = "", 0
    flujo = por_partes(mensajes, max_tokens=max_tokens)
    try:
        for pedazo in flujo:
            texto += pedazo
            completas = _oraciones(texto)
            if avisar_oracion is not None and len(completas) > avisadas and len(completas) < necesarias:
                avisar_oracion(completas[avisadas])
                avisadas = len(completas)
            if len(completas) >= necesarias:
                break
    finally:
        flujo.close()
    return texto


def _respuesta_sin_modelo(analisis, fragmentos: tuple[Fragmento, ...]) -> str:
    apertura = _apertura_fija(analisis)
    if fragmentos:
        return f"{apertura} Esto te puede servir: {fragmentos[0].texto}"
    return f"{apertura} ¿Quieres platicarme un poco más de lo que pasó?"


def responder(
    mensaje: str,
    analizador: AnalizadorSentimiento,
    generador: GeneradorRespuesta,
    nivel_cssrs: str | None = None,
    # Se reciben para dejar explicito que NO se mandan al modelo.
    nombre_estudiante: str | None = None,
    curp: str | None = None,
    # Fase 2: turnos anteriores de la misma sesion (memoria_sesion).
    historial: tuple[Turno, ...] = (),
    # Fase 4: "breve" (por omision) o "completo"; tambien SERENA_MODO.
    modo: str | None = None,
    # Fase 5: recibe el texto parcial ya revisado (para /chat/stream).
    al_avanzar: Callable[[str], None] | None = None,
) -> RespuestaSerena:
    inicio = time.perf_counter()
    modo = modo or os.getenv("SERENA_MODO", MODO_BREVE)
    breve = modo == MODO_BREVE

    # 1. ENTRADA ------------------------------------------------------------
    riesgo = combinar_con_nivel_cssrs(clasificar_mensaje(mensaje), nivel_cssrs)
    contexto = analizar_contexto(mensaje)
    analisis = _analizar(mensaje, analizador)
    sesion = hechos_de_sesion(historial)
    hechos = set(riesgo.categorias) | hechos_de_limites(mensaje) | sesion
    if contexto.informativa:
        # Semana 4: en una consulta la polaridad describe el TEMA ("tristeza")
        # y no a quien escribe; no cuenta como dia o mensaje negativo.
        hechos.add(HECHO_CONSULTA)
        analisis = None
    elif analisis is not None and analisis.probabilidad(analisis.polaridad) >= UMBRAL_CONFIANZA:
        hechos.add({"positivo": "polaridad_positiva", "neutro": "polaridad_neutra", "negativo": "polaridad_negativa"}[analisis.polaridad])
    entrada = decidir(hechos, METAS_SERENA)
    crisis_previa = "crisis_previa" in sesion
    etapas: dict[str, object] = {
        "entrada": _decision_dict(entrada),
        "contexto": {"informativa": contexto.informativa, "tema": contexto.tema, "motivo": contexto.motivo},
    }

    def cerrar(texto, tipo, detener=False, fuentes=(), alerta=None):
        # Semana 4: las lineas van en la tarjeta de la app, no en el texto
        # (las respuestas fijas de la guardia todavia las traen pegadas).
        texto = re.sub(r"\s+", " ", texto.replace(LINEAS_TEXTO, "")).strip()
        # Despues de una crisis las lineas quedan a la vista en cada respuesta
        # (como la tarjeta fija de Gemini); en una consulta sobre suicidio o
        # autolesion tambien, sin alerta (guias de la OMS).
        con_crisis = (
            tipo in ("crisis", "explorar", "bloqueada")
            or crisis_previa
            or (entrada.accion == ACCION_INFORMAR and contexto.tema in TEMAS_CON_LINEAS)
        )
        lineas = lineas_para(mensaje, con_lineas_crisis=con_crisis)
        etapas["milisegundos"] = round((time.perf_counter() - inicio) * 1000)
        etapas.setdefault("modelo", None)
        etapas.setdefault("texto_modelo", None)
        etapas.setdefault("salida", None)
        senal = {
            ACCION_CRISIS: SENAL_ALTA,
            ACCION_EXPLORAR: SENAL_AMBIGUA,
            ACCION_ALERTA_PREVENTIVA: SENAL_AMBIGUA,
            ACCION_APOYO_AUTOLESION: SENAL_AMBIGUA,
            ACCION_LIMITE_METODO: SENAL_AMBIGUA,
        }.get(entrada.accion, SENAL_NINGUNA)
        turno = Turno(mensaje, texto, tipo, senal, getattr(analisis, "polaridad", None), 0.0)
        return RespuestaSerena(texto, tipo, detener, tuple(fuentes), MappingProxyType(etapas), alerta, turno, lineas)

    previas = tuple(t.respuesta for t in historial)

    if entrada.accion == ACCION_CRISIS:
        alerta = {"tipo": "riesgo_en_chat", "nivel": entrada.meta, "reglas": list(entrada.reglas_usadas),
                  "evidencia": list(riesgo.evidencia), "prueba": list(entrada.prueba.pasos)}
        # Semana 4: no se pausa el chat. Si la crisis se repite, un texto mas
        # corto: las lineas ya estan en la tarjeta.
        texto = sin_repetir(CRISIS_REPETIDA, previas) if crisis_previa else GUION_CRISIS
        return cerrar(texto, "crisis", alerta=alerta)
    if entrada.accion == ACCION_LIMITE_METODO:
        # R16: pide metodos sin hablar de si. Nunca se dan; se avisa.
        alerta = {"tipo": "metodo_en_chat", "nivel": "preventivo", "reglas": list(entrada.reglas_usadas),
                  "evidencia": [], "prueba": list(entrada.prueba.pasos)}
        return cerrar(LIMITE_METODO, "explorar", alerta=alerta)
    if entrada.accion == ACCION_APOYO_AUTOLESION:
        # Semana 4 (revision clinica): autolesion sin otra senal. No pausa el
        # chat; pregunta, da las lineas y el administrador la ve.
        alerta = {"tipo": "autolesion_en_chat", "nivel": "preventivo", "reglas": list(entrada.reglas_usadas),
                  "evidencia": list(riesgo.evidencia), "prueba": list(entrada.prueba.pasos)}
        return cerrar(pregunta_seguimiento(riesgo.categorias, previas), "explorar", alerta=alerta)
    if entrada.accion == ACCION_APOYO_TERCERO:
        return cerrar(RESPUESTA_APOYO_TERCERO, "explorar")
    if entrada.accion in RESPUESTAS_LIMITE:
        return cerrar(RESPUESTAS_LIMITE[entrada.accion], "limite")
    if entrada.accion == ACCION_ALERTA_PREVENTIVA:
        # Fase 2 (R14): la senal ambigua se repite en la conversacion. Misma
        # respuesta que explorar, sin pausar el chat, y aviso al administrador.
        alerta = {"tipo": "riesgo_acumulado", "nivel": "preventivo", "reglas": list(entrada.reglas_usadas),
                  "evidencia": list(riesgo.evidencia), "prueba": list(entrada.prueba.pasos)}
        return cerrar(pregunta_seguimiento(riesgo.categorias, previas), "explorar", alerta=alerta)
    if entrada.accion == ACCION_ACOMPANAR_CRISIS:
        # R18: despues de una crisis. Texto fijo: con el modelo pequeno no se
        # deja redactar en este momento (ver reporte, Semana 3).
        return cerrar(sin_repetir(ACOMPANAR_CRISIS, previas), "explorar")
    if entrada.accion == ACCION_EXPLORAR:
        # Señal ambigua de riesgo (R9): texto fijo que explora con cuidado.
        # Con el modelo pequeño, en el servidor, la respuesta no exploraba o
        # normalizaba ("es normal sentirse así"); ver reporte, Semana 3.
        # Semana 4: la pregunta depende de la señal y no se repite.
        return cerrar(pregunta_seguimiento(riesgo.categorias, previas), "explorar")

    # 2. CONTENIDO ----------------------------------------------------------
    fragmentos = recuperar(mensaje, k=MAX_FRAGMENTOS)
    # El corpus casi no tiene titulos (el titulo suele ser el modulo): se
    # muestra "Módulo de Ansiedad" en lugar de "Ansiedad - Ansiedad".
    # Cierre de la Semana 3: cada fuente dice si psicologia ya la reviso.
    fuentes = tuple(
        MappingProxyType(
            {
                **(
                    {"titulo": f"Módulo de {f.modulo}", "categoria": "", "id": f.id}
                    if f.titulo == f.modulo
                    else {"titulo": f.titulo, "categoria": f.modulo, "id": f.id}
                ),
                "revision": f.revision,
                "revisor": revision_de(f.id).revisor or "",
            }
        )
        for f in fragmentos
    )
    etapas["fuentes"] = [f.id for f in fragmentos]

    # 3. MODELO -------------------------------------------------------------
    informar = entrada.accion == ACCION_INFORMAR
    intencion = INTENCION_INFORMATIVA if informar else detectar_intencion(mensaje)
    etapas["modo"] = modo
    # R17: en una consulta no se invita a buscar a un adulto ni se supone
    # malestar; se informa y se deja la puerta abierta.
    invitar = not informar and _toca_invitar(historial, forzar=entrada.accion == ACCION_SUGERIR_APOYO)
    ficha = FICHAS_INFORMATIVAS.get(contexto.tema) if informar and not fragmentos else None
    con_contenido = bool(fragmentos or ficha)
    necesarias = 1 if con_contenido else 2
    cuerpo = _cuerpo_breve(fragmentos, mensaje, invitar) if breve else ""
    if breve and informar:
        cuerpo = " ".join(p for p in (cuerpo, ficha, CIERRE_INFORMATIVO) if p)
    apertura_fija = APERTURA_INFORMATIVA if informar else _apertura_fija(analisis)
    if breve and al_avanzar is not None and cuerpo:
        # El material aprobado y la invitacion a un adulto ya se conocen: se
        # muestran mientras el modelo redacta. Velocidad (cierre S3): tambien
        # SIN material (7 de cada 10 mensajes normales), que antes no
        # mostraban nada durante 12-20 s.
        al_avanzar(cuerpo)

    def avisar_oracion(oracion: str) -> None:
        # Solo se muestra lo que pasa la guardia de salida, arriba de lo que
        # ya se veia (la burbuja crece; no cambia lo ya mostrado).
        if al_avanzar is not None and aplicar_guardia(oracion, requiere_lineas=False, breve=breve).mostrable:
            al_avanzar(f"{_mayuscula(oracion)} {cuerpo}".strip())

    # Semana 4 (prototipo11, en el servidor): en una consulta el modelo
    # seguia hablando del tema del mensaje anterior ("La tristeza es..." ante
    # una pregunta sobre suicidio). Con ficha la respuesta ya esta completa y
    # no se llama al modelo; con material del programa, el modelo no recibe
    # los mensajes anteriores.
    historial_modelo = () if informar else historial
    try:
        if breve and ficha:
            raise GeneradorNoDisponible("consulta con ficha: no hace falta el modelo")
        if breve:
            crudo = _generar_hasta(
                generador,
                _mensajes_breve(mensaje, analisis, intencion, entrada, fragmentos, historial_modelo, con_contenido),
                MAX_TOKENS_BREVE,
                necesarias,
                avisar_oracion,
            )
        else:
            crudo = generador.generar(_mensajes(mensaje, analisis, intencion, entrada, fragmentos, historial))
        etapas["modelo"] = generador.nombre
    except GeneradorNoDisponible:
        crudo = apertura_fija if breve else _respuesta_sin_modelo(analisis, fragmentos)
        etapas["modelo"] = SIN_MODELO_FICHA if breve and ficha else SIN_MODELO
    etapas["texto_modelo"] = crudo

    # 4. SALIDA -------------------------------------------------------------
    # Fase 2: "sugerir apoyo" (R10 racha negativa, R15 seguimiento de una
    # senal ambigua) redacta el modelo, pero la respuesta siempre lleva lineas.
    explorar = entrada.accion in (ACCION_EXPLORAR, ACCION_SUGERIR_APOYO)
    # En modo breve la guardia revisa SOLO lo que escribio el modelo; el
    # material aprobado y la invitacion son texto fijo.
    guardia = aplicar_guardia(crudo, requiere_lineas=explorar and not breve, breve=breve)
    if breve and not guardia.bloqueada:
        # Lo peligroso (bloquear) se revisa en TODO lo que escribio el
        # modelo; el estilo (S12-S15), solo en las oraciones que se muestran.
        usadas = " ".join(_oraciones(crudo)[:necesarias])
        guardia = aplicar_guardia(usadas or crudo, requiere_lineas=False, breve=True)
    etapas["salida"] = _decision_dict(guardia.decision)
    if guardia.bloqueada:
        alerta = {"tipo": "respuesta_bloqueada", "nivel": "salida", "reglas": list(guardia.decision.reglas_usadas),
                  "evidencia": sorted(guardia.hechos), "prueba": list(guardia.decision.prueba.pasos)}
        return cerrar(guardia.texto, "bloqueada", fuentes=(), alerta=alerta)
    if breve:
        # Si la guardia reemplazo la oracion (S12-S15), guardia.texto viene
        # vacio y _componer_breve usa la apertura fija.
        texto = _componer_breve(guardia.texto, necesarias, cuerpo, apertura_fija)
    elif guardia.reemplazada:
        texto = f"{_respuesta_sin_modelo(analisis, fragmentos)} {guardia.texto}".strip()
    else:
        texto = guardia.texto
    return cerrar(texto, "explorar" if explorar else "normal", fuentes=fuentes)


def precalentar(analizador: AnalizadorSentimiento, generador: GeneradorRespuesta | None) -> tuple[str, ...]:
    """Carga pysentimiento y el modelo antes del primer mensaje.

    En el servidor, el primer mensaje despues de reiniciar el servicio
    tardaba mas de 90 s porque tambien cargaba ambos modelos. Se llama al
    arrancar, en un hilo aparte; si algo no esta disponible solo se registra.
    """
    listos: list[str] = []
    try:
        analizador.analizar("hola")
        listos.append("analizador")
    except Exception:  # noqa: BLE001 - precalentar nunca debe tumbar el arranque
        log.exception("no se pudo precalentar el analizador")
    if generador is not None:
        try:
            # Velocidad (cierre S3): con el prompt REAL de Serena (modo breve
            # sin material, el caso mas comun) y un solo token. Antes se
            # mandaba "hola" sin prompt de sistema y el primer mensaje real
            # tenia que leer todo el prompt (42-47 s en el servidor).
            generador.generar(_mensajes_calentar(), max_tokens=1)
            listos.append("modelo")
        except GeneradorNoDisponible as exc:
            log.warning("Serena sin modelo al arrancar: %s", exc)
    return tuple(listos)


def _mensajes_calentar():
    mensaje = "hola"
    return _mensajes_breve(mensaje, None, detectar_intencion(mensaje), decidir(set(), METAS_SERENA), (), ())


def debe_calentar(ultimo_uso: float, ahora: float, cada: float) -> bool:
    return cada > 0 and ahora - ultimo_uso >= cada


def mantener_caliente(
    analizador: AnalizadorSentimiento,
    generador: GeneradorRespuesta | None,
    cada: float,
    parar: threading.Event,
) -> None:
    """Velocidad (cierre S3): si el modelo lleva `cada` segundos sin usarse,
    se vuelve a precalentar (un token, menos de un segundo con el prefijo
    listo). Asi sus pesos no se quedan fuera de la RAM (swap) ni se pierde el
    prefijo entre una demo y otra. `cada` <= 0 lo apaga (SERENA_CALENTAR_CADA)."""
    if cada <= 0:
        return
    while not parar.wait(cada):
        if debe_calentar(getattr(generador, "ultimo_uso", 0.0), time.monotonic(), cada):
            precalentar(analizador, generador)
