"""Evaluacion de una entrada del diario emocional (semaforo de animo).

PROTOTIPO (Semana 2): no esta conectado a ningun endpoint ni a produccion.

Recorrido de una entrada (ver diagrama en el reporte de la Semana 2):

  1. El estudiante se autoevalua: polaridad del dia + emociones + texto
     opcional. Su autoevaluacion es lo que se REGISTRA; el analizador nunca
     la reemplaza.
  2. Si escribio algo, el texto pasa por:
       a. el clasificador de riesgo por reglas (el mismo de Serena), SIEMPRE,
          aunque el analizador de sentimientos falle;
       b. el analizador de sentimientos (pysentimiento), que estima la
          polaridad y las emociones del texto.
  3. Todo se convierte en hechos y el motor de Wang decide la accion:
     crisis, explorar con cuidado, sugerir apoyo o normal.
  4. Se arma la respuesta: comparacion con la autoevaluacion, consejos,
     invitacion a Serena, lineas de ayuda y, en crisis, alerta al
     administrador.

Los consejos y mensajes son BORRADORES tecnicos: requieren revision
clinica antes de mostrarse a estudiantes.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from types import MappingProxyType
from typing import Mapping

from .analizador_sentimiento import (
    AnalizadorNoDisponible,
    AnalizadorSentimiento,
    ResultadoSentimiento,
)
from .clasificador_riesgo import ResultadoClasificacion, clasificar_mensaje, combinar_con_nivel_cssrs
from .contexto_mensaje import analizar_contexto
from .limites_serena import hechos_de_limites
from .emociones_catalogo import (
    CLASE_ALEGRIA,
    CLASE_ASCO,
    CLASE_ENOJO,
    CLASE_MIEDO,
    CLASE_OTRA,
    CLASE_SORPRESA,
    CLASE_TRISTEZA,
    POLARIDAD_NEGATIVA,
    POLARIDAD_NEUTRA,
    POLARIDAD_POSITIVA,
    POLARIDADES,
    buscar,
)
from .motor_wang import (
    ACCION_CRISIS,
    ACCION_EXPLORAR,
    ACCION_NORMAL,
    ACCION_SUGERIR_APOYO,
    Decision,
    decidir,
)

MAX_CARACTERES_TEXTO = 5000
# Por debajo de esta probabilidad el analizador "no esta seguro" y la app no
# le dice al estudiante que su autoevaluacion difiere. Valor provisional:
# se debe calibrar con la evaluacion del reporte.
UMBRAL_CONFIANZA = 0.6
# Tres dias negativos seguidos (hoy + 2 anteriores) cuentan como racha.
DIAS_PREVIOS_PARA_RACHA = 2

LINEAS_AYUDA = (
    # Pendiente de confirmar con la doctora (revision clinica, apartado A).
    {"nombre": "Línea de la Vida", "telefono": "800 911 2000", "horario": "24 horas, gratuita"},
    {"nombre": "SAPTEL", "telefono": "55 5259 8121", "horario": "24 horas"},
)

_SUFIJO = {POLARIDAD_POSITIVA: "positiva", POLARIDAD_NEUTRA: "neutra", POLARIDAD_NEGATIVA: "negativa"}

_NOMBRE_CLASE = {
    CLASE_ALEGRIA: "alegría",
    CLASE_TRISTEZA: "tristeza",
    CLASE_ENOJO: "enojo",
    CLASE_MIEDO: "miedo o angustia",
    CLASE_SORPRESA: "sorpresa",
    CLASE_ASCO: "asco o rechazo",
    CLASE_OTRA: "otras emociones",
}

# BORRADOR: consejos por emocion predominante. Revisar con psicologia.
_CONSEJOS = {
    CLASE_ALEGRIA: (
        "¿Qué hiciste hoy que te gustaría repetir? Anotarlo ayuda a recordarlo en días difíciles.",
        "Comparte algo de lo bueno de hoy con alguien que te importe.",
    ),
    CLASE_TRISTEZA: (
        "Está bien sentirse triste. Prueba hablar con alguien de confianza o escribir un poco más aquí.",
        "Un paseo corto, música que te guste o descansar bien pueden ayudar a que el día pese menos.",
    ),
    CLASE_ENOJO: (
        # Misma técnica que el módulo de Ansiedad (teenImgActividades); antes
        # decía «4-7-8», que no es la del material aprobado.
        "Antes de reaccionar, respira lento: inhala 4 segundos, sostén 4 y exhala 6. Repítelo varias veces.",
        "Escribe qué te hizo enojar y qué necesitabas en ese momento; ayuda a ordenar la idea.",
    ),
    CLASE_MIEDO: (
        # Atención plena del módulo de Ansiedad; antes proponía «5 cosas que
        # ves…», técnica que no está en ningún texto aprobado.
        "Cuando la angustia sube, dedica 3 minutos al presente: mira, escucha y siente lo que te rodea.",
        "Si lo que te preocupa se repite varios días, platícalo con un adulto de confianza.",
    ),
    CLASE_SORPRESA: ("Tómate un momento para pensar qué cambió hoy y cómo te hace sentir.",),
    CLASE_ASCO: (
        "Si algo o alguien te hizo sentir rechazo o incomodidad, está bien poner límites.",
    ),
    CLASE_OTRA: (
        "Los días tranquilos también cuentan. ¿Hubo algún momento que disfrutaras?",
        "Si te sientes con poca energía, revisa cómo has dormido y comido estos días.",
    ),
}


@dataclass(frozen=True)
class EntradaDiario:
    polaridad: str
    emociones: tuple[str, ...]
    texto: str = ""
    # Polaridades autoevaluadas de los dias anteriores, de la mas reciente a
    # la mas antigua. Las aporta el backend desde el historial guardado.
    polaridades_previas: tuple[str, ...] = ()
    nivel_cssrs: str | None = None

    def __post_init__(self) -> None:
        if self.polaridad not in POLARIDADES:
            raise ValueError(f"polaridad desconocida: {self.polaridad!r}")
        if not self.emociones:
            raise ValueError("hay que elegir al menos una emocion")
        for clave in self.emociones:
            if buscar(clave).polaridad != self.polaridad:
                raise ValueError(f"la emocion {clave!r} no corresponde a un dia {self.polaridad}")
        if len(self.texto) > MAX_CARACTERES_TEXTO:
            raise ValueError(f"el texto no puede pasar de {MAX_CARACTERES_TEXTO} caracteres")
        for p in self.polaridades_previas:
            if p not in POLARIDADES:
                raise ValueError(f"polaridad previa desconocida: {p!r}")


@dataclass(frozen=True)
class ResultadoDiario:
    polaridad_registrada: str
    emociones_registradas: tuple[str, ...]
    analisis: ResultadoSentimiento | None
    aviso_analizador: str | None
    concordancia: str  # coincide | difiere | incierto | sin_analisis
    mensaje_concordancia: str
    riesgo: ResultadoClasificacion
    decision: Decision
    consejos: tuple[str, ...]
    ofrecer_serena: bool
    mensaje_serena: str
    mostrar_lineas_ayuda: bool
    lineas_ayuda: tuple[Mapping[str, str], ...]
    alerta_admin: Mapping[str, object] | None = field(default=None)

    @property
    def accion(self) -> str:
        return self.decision.accion


def _analizar(texto: str, analizador: AnalizadorSentimiento) -> tuple[ResultadoSentimiento | None, str | None]:
    if not texto.strip():
        return None, None
    try:
        return analizador.analizar(texto), None
    except AnalizadorNoDisponible as exc:
        # El diario no se cae: se guarda la autoevaluacion y el riesgo ya se
        # reviso por reglas. Se avisa para que quede registro.
        return None, f"El análisis automático no está disponible ({exc})."


def _es_confiable(analisis: ResultadoSentimiento | None) -> bool:
    return analisis is not None and analisis.probabilidad(analisis.polaridad) >= UMBRAL_CONFIANZA


MENSAJE_CONSULTA = (
    "Lo que escribiste habla de un tema y no de cómo te sentiste, así que tu día queda como lo marcaste."
)


def _concordancia(entrada: EntradaDiario, analisis: ResultadoSentimiento | None, consulta: bool = False) -> tuple[str, str]:
    if analisis is None:
        return "sin_analisis", ""
    if consulta:
        # Semana 4: "vimos en clase las senales del suicidio" sale negativo
        # por la palabra, no por el dia del estudiante.
        return "incierto", MENSAJE_CONSULTA
    if not _es_confiable(analisis):
        return "incierto", "Gracias por escribir. Tu registro de hoy quedó guardado."
    if analisis.polaridad == entrada.polaridad:
        return "coincide", "Lo que escribiste va de acuerdo con cómo calificaste tu día."
    emocion = _NOMBRE_CLASE[analisis.emocion_principal()]
    return (
        "difiere",
        f"Marcaste tu día como {entrada.polaridad}. En lo que escribiste también notamos {emocion}. "
        "Está bien sentir varias cosas a la vez; si quieres, puedes platicarlo con Serena.",
    )


# Semana 4: el diario tampoco detectaba "busque como me puedo suicidar".
# De la barrera de limites de Serena solo se toman los metodos; diagnostico,
# medicacion o identidad no aplican a un diario.
_HECHOS_METODO = frozenset({"pide_metodo", "pide_metodo_general"})


def _hechos(
    entrada: EntradaDiario,
    analisis: ResultadoSentimiento | None,
    riesgo: ResultadoClasificacion,
    consulta: bool = False,
) -> set[str]:
    hechos = {f"autoevaluacion_{_SUFIJO[entrada.polaridad]}"}
    hechos.update(hechos_de_limites(entrada.texto) & _HECHOS_METODO)
    if _es_confiable(analisis) and not consulta:
        hechos.add(f"polaridad_{_SUFIJO[analisis.polaridad]}")  # type: ignore[union-attr]
    hoy_negativo = entrada.polaridad == POLARIDAD_NEGATIVA or "polaridad_negativa" in hechos
    previas = entrada.polaridades_previas[:DIAS_PREVIOS_PARA_RACHA]
    if hoy_negativo and len(previas) == DIAS_PREVIOS_PARA_RACHA and all(p == POLARIDAD_NEGATIVA for p in previas):
        hechos.add("racha_negativa")
    hechos.update(c for c in riesgo.categorias if c != "cssrs_alto")
    if "cssrs_alto" in riesgo.categorias:
        hechos.add("cssrs_alto")
    return hechos


def _consejos(entrada: EntradaDiario, accion: str) -> tuple[str, ...]:
    if accion == ACCION_CRISIS:
        return ()  # la pantalla de crisis tiene su propio mensaje fijo
    # Los consejos siguen la emocion que MARCO el estudiante, no la que
    # estima el analizador: con texto real el analizador llego a leer
    # "enojo" donde el estudiante marco tristeza (ver reporte).
    clase = buscar(entrada.emociones[0]).clase_analizador
    return _CONSEJOS.get(clase, _CONSEJOS[CLASE_OTRA])[:2]


def _alerta_admin(riesgo: ResultadoClasificacion, decision: Decision) -> Mapping[str, object]:
    # Minimo necesario para actuar: que reglas dispararon y la frase exacta
    # que coincidio, NO el texto completo del diario. Ver reporte: que mas
    # se comparte (y con quien) es decision clinica pendiente.
    return MappingProxyType(
        {
            "tipo": "riesgo_en_diario",
            "nivel": decision.meta,
            "reglas": decision.reglas_usadas,
            "evidencia": riesgo.evidencia,
            "prueba": decision.prueba.pasos,
        }
    )


META_AUTOLESION = "apoyo_autolesion"
META_METODO = "limite_metodo"
_METAS_CON_AVISO = frozenset({META_AUTOLESION, META_METODO})


def evaluar_entrada(entrada: EntradaDiario, analizador: AnalizadorSentimiento) -> ResultadoDiario:
    riesgo = combinar_con_nivel_cssrs(clasificar_mensaje(entrada.texto), entrada.nivel_cssrs)
    analisis, aviso = _analizar(entrada.texto, analizador)
    # Semana 4: se lee la frase completa. En una consulta la polaridad del
    # analizador describe el tema, no el dia.
    consulta = analizar_contexto(entrada.texto).informativa
    decision = decidir(_hechos(entrada, analisis, riesgo, consulta))
    accion = decision.accion

    concordancia, mensaje = _concordancia(entrada, analisis, consulta)
    dia_negativo = entrada.polaridad == POLARIDAD_NEGATIVA or (
        not consulta and _es_confiable(analisis) and analisis.polaridad == POLARIDAD_NEGATIVA  # type: ignore[union-attr]
    )
    ofrecer_serena = accion != ACCION_CRISIS and (
        dia_negativo or accion in (ACCION_EXPLORAR, ACCION_SUGERIR_APOYO)
    )
    mensaje_serena = (
        "Por lo que escribiste, hay algunos temas que podrías platicar en privado con Serena, "
        "el chat de ayuda de la app."
        if ofrecer_serena
        else ""
    )

    return ResultadoDiario(
        polaridad_registrada=entrada.polaridad,
        emociones_registradas=entrada.emociones,
        analisis=analisis,
        aviso_analizador=aviso,
        concordancia=concordancia,
        mensaje_concordancia=mensaje,
        riesgo=riesgo,
        decision=decision,
        consejos=_consejos(entrada, accion),
        ofrecer_serena=ofrecer_serena,
        mensaje_serena=mensaje_serena,
        mostrar_lineas_ayuda=accion in (ACCION_CRISIS, ACCION_EXPLORAR, ACCION_SUGERIR_APOYO),
        lineas_ayuda=tuple(MappingProxyType(l) for l in LINEAS_AYUDA),
        # Semana 4: la autolesion ya no es crisis, pero el administrador la ve.
        alerta_admin=_alerta_admin(riesgo, decision) if accion == ACCION_CRISIS or decision.meta in _METAS_CON_AVISO else None,
    )


def resultado_a_dict(r: ResultadoDiario, texto: str = "") -> dict[str, object]:
    """Forma JSON del resultado, la misma que espera la pantalla del diario
    (lib/pantallas/diario/diario_modelos.dart)."""
    analisis = None
    if r.analisis is not None:
        analisis = {
            "polaridad": r.analisis.polaridad,
            "confianza": r.analisis.probabilidad(r.analisis.polaridad),
            "probabilidades": dict(r.analisis.probabilidades_polaridad),
            "emociones": [[e, p] for e, p in r.analisis.emociones[:3]],
            "modelo": r.analisis.modelo,
        }
    return {
        "texto": texto,
        "polaridad_registrada": r.polaridad_registrada,
        "emociones_registradas": [{"clave": c, "nombre": buscar(c).nombre} for c in r.emociones_registradas],
        "analisis": analisis,
        "aviso_analizador": r.aviso_analizador,
        "concordancia": r.concordancia,
        "mensaje_concordancia": r.mensaje_concordancia,
        "accion": r.accion,
        "reglas_usadas": list(r.decision.reglas_usadas),
        "consejos": list(r.consejos),
        "ofrecer_serena": r.ofrecer_serena,
        "mensaje_serena": r.mensaje_serena,
        "mostrar_lineas_ayuda": r.mostrar_lineas_ayuda,
        "lineas_ayuda": [dict(l) for l in r.lineas_ayuda],
    }
