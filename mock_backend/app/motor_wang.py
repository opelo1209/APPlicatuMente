"""Motor de decision de riesgo basado en el algoritmo de Wang.

PROTOTIPO (Semana 2): no esta conectado a ningun endpoint ni a produccion.

Idea, a peticion del asesor: retomar el algoritmo de Wang (calculo de
secuentes de logica proposicional, practica de Inteligencia Artificial) y
"evolucionarlo" para que decida que hacer con un mensaje o una entrada del
diario. Se divide en dos capas:

  1. Percepcion (fuera de este modulo): el clasificador de riesgo por reglas,
     el analizador de sentimientos y el C-SSRS convierten el texto en HECHOS,
     atomos proposicionales verdaderos ("desesperanza_extrema",
     "polaridad_negativa"...).
  2. Decision (este modulo): una base de REGLAS escritas como formulas
     ("desesperanza_extrema and peticion_secreto -> riesgo_alto") y el
     algoritmo de Wang, que demuestra si  hechos, reglas |- riesgo_alto.

Por que no basta con un "if": la prueba de Wang ES la explicacion. Queda
guardado que regla y que hechos llevaron a detener la conversacion, en un
formato que psicologia puede leer y auditar, y las reglas se pueden revisar
y cambiar como texto sin tocar codigo. Ademas, el mismo demostrador sirve
para verificar propiedades de la base de reglas (que sin hechos no se derive
riesgo, que no sea contradictoria); ver tests/test_motor_wang.py.

Diferencias con la version de la practica (Java), corregidas aqui:
  - ->L no bifurcaba: solo agregaba "not A, B" al antecedente.
  - vL aceptaba si cerraba UNA rama (r1 || r2); deben cerrar las dos. Con
    eso la practica "demostraba" la falacia  p or q |- p.
  - las formulas eran cadenas y "coincide" usaba contains("or"); aqui son
    arboles inmutables y se comparan por estructura.

ESTADO: las reglas son un borrador tecnico que replica el clasificador de
riesgo actual; requieren revision clinica igual que su lexico.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

# --------------------------------------------------------------------------
# Formulas (inmutables)
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Atomo:
    nombre: str

    def __str__(self) -> str:
        return self.nombre


@dataclass(frozen=True)
class No:
    f: "Formula"

    def __str__(self) -> str:
        return f"¬{_envolver(self.f)}"


@dataclass(frozen=True)
class Y:
    izq: "Formula"
    der: "Formula"

    def __str__(self) -> str:
        return f"{_envolver(self.izq)} ∧ {_envolver(self.der)}"


@dataclass(frozen=True)
class O:
    izq: "Formula"
    der: "Formula"

    def __str__(self) -> str:
        return f"{_envolver(self.izq)} ∨ {_envolver(self.der)}"


@dataclass(frozen=True)
class Implica:
    izq: "Formula"
    der: "Formula"

    def __str__(self) -> str:
        return f"{_envolver(self.izq)} → {_envolver(self.der)}"


Formula = Atomo | No | Y | O | Implica


def _envolver(f: Formula) -> str:
    return str(f) if isinstance(f, (Atomo, No)) else f"({f})"


def atomos(f: Formula) -> frozenset[str]:
    if isinstance(f, Atomo):
        return frozenset({f.nombre})
    if isinstance(f, No):
        return atomos(f.f)
    return atomos(f.izq) | atomos(f.der)


def evaluar(f: Formula, verdaderos: frozenset[str]) -> bool:
    if isinstance(f, Atomo):
        return f.nombre in verdaderos
    if isinstance(f, No):
        return not evaluar(f.f, verdaderos)
    if isinstance(f, Y):
        return evaluar(f.izq, verdaderos) and evaluar(f.der, verdaderos)
    if isinstance(f, O):
        return evaluar(f.izq, verdaderos) or evaluar(f.der, verdaderos)
    return (not evaluar(f.izq, verdaderos)) or evaluar(f.der, verdaderos)


# --------------------------------------------------------------------------
# Lectura de formulas escritas como texto
# --------------------------------------------------------------------------

_SINONIMOS = {"¬": "not", "~": "not", "∧": "and", "&": "and", "∨": "or", "|": "or", "→": "->"}
_TOKEN = re.compile(r"\s*(->|[()¬~∧&∨|→]|[A-Za-z_][A-Za-z0-9_]*)")
_PALABRAS_CLAVE = {"not", "and", "or"}


def _tokenizar(texto: str) -> list[str]:
    tokens, pos = [], 0
    texto = texto.rstrip()
    while pos < len(texto):
        m = _TOKEN.match(texto, pos)
        if not m:
            raise ValueError(f"caracter no valido en la posicion {pos}: {texto[pos:]!r}")
        tokens.append(_SINONIMOS.get(m.group(1), m.group(1)))
        pos = m.end()
    return tokens


def parsear(texto: str) -> Formula:
    """Convierte "a and not b -> c" en una formula. Precedencia, de mayor a
    menor: not, and, or, ->. La implicacion asocia a la derecha."""
    tokens = _tokenizar(texto)
    if not tokens:
        raise ValueError("formula vacia")
    formula, resto = _parsear_implica(tokens)
    if resto:
        raise ValueError(f"sobra texto al final: {' '.join(resto)!r}")
    return formula


def _parsear_implica(t: list[str]) -> tuple[Formula, list[str]]:
    izq, resto = _parsear_o(t)
    if resto and resto[0] == "->":
        der, resto = _parsear_implica(resto[1:])
        return Implica(izq, der), resto
    return izq, resto


def _parsear_o(t: list[str]) -> tuple[Formula, list[str]]:
    izq, resto = _parsear_y(t)
    while resto and resto[0] == "or":
        der, resto = _parsear_y(resto[1:])
        izq = O(izq, der)
    return izq, resto


def _parsear_y(t: list[str]) -> tuple[Formula, list[str]]:
    izq, resto = _parsear_unario(t)
    while resto and resto[0] == "and":
        der, resto = _parsear_unario(resto[1:])
        izq = Y(izq, der)
    return izq, resto


def _parsear_unario(t: list[str]) -> tuple[Formula, list[str]]:
    if not t:
        raise ValueError("falta un operando")
    cabeza, resto = t[0], t[1:]
    if cabeza == "not":
        f, resto = _parsear_unario(resto)
        return No(f), resto
    if cabeza == "(":
        f, resto = _parsear_implica(resto)
        if not resto or resto[0] != ")":
            raise ValueError("falta cerrar un parentesis")
        return f, resto[1:]
    if cabeza in _PALABRAS_CLAVE or cabeza in {")", "->"}:
        raise ValueError(f"se esperaba un atomo y llego {cabeza!r}")
    return Atomo(cabeza), resto


# --------------------------------------------------------------------------
# Algoritmo de Wang
# --------------------------------------------------------------------------

MAX_PASOS_REGISTRADOS = 400


@dataclass(frozen=True)
class Prueba:
    valida: bool
    pasos: tuple[str, ...]
    # Si no es valida: atomos verdaderos de una rama que no cerro. Es un
    # contraejemplo: con esos hechos verdaderos (y el resto falsos) se
    # cumplen todas las premisas y no la conclusion.
    contraejemplo: frozenset[str] = frozenset()


def demostrar(
    antecedente: list[Formula] | tuple[Formula, ...],
    consecuente: list[Formula] | tuple[Formula, ...],
    verdaderos_preferidos: frozenset[str] = frozenset(),
) -> Prueba:
    """Decide si el secuente  antecedente |- consecuente  es valido.

    verdaderos_preferidos solo cambia el ORDEN en que se descomponen las
    implicaciones (primero las que se cumplen con esos atomos), para que
    una prueba valida salga corta y legible. No cambia el resultado.
    """
    pasos: list[str] = []
    contraejemplo: list[frozenset[str]] = []
    valida = _wang(
        tuple(antecedente), tuple(consecuente), 0, pasos, contraejemplo, verdaderos_preferidos
    )
    if len(pasos) > MAX_PASOS_REGISTRADOS:
        omitidos = len(pasos) - MAX_PASOS_REGISTRADOS
        pasos = pasos[:MAX_PASOS_REGISTRADOS] + [f"... ({omitidos} pasos mas)"]
    return Prueba(
        valida=valida,
        pasos=tuple(pasos),
        contraejemplo=contraejemplo[0] if contraejemplo else frozenset(),
    )


def _secuente(izq: tuple[Formula, ...], der: tuple[Formula, ...]) -> str:
    return f"{', '.join(map(str, izq)) or '∅'}  ⊢  {', '.join(map(str, der)) or '∅'}"


def _sin(t: tuple[Formula, ...], i: int) -> tuple[Formula, ...]:
    return t[:i] + t[i + 1 :]


def _wang(izq, der, nivel, pasos, contraejemplo, preferidos) -> bool:
    sangria = "  " * nivel
    pasos.append(f"{sangria}{_secuente(izq, der)}")

    comunes = set(izq) & set(der)
    if comunes:
        pasos.append(f"{sangria}  ✓ axioma: {', '.join(sorted(map(str, comunes)))} en ambos lados")
        return True

    # Reglas que no bifurcan, primero (asi el arbol crece menos).
    for i, f in enumerate(izq):
        if isinstance(f, No):
            pasos.append(f"{sangria}  ¬L: {f} pasa a la derecha")
            return _wang(_sin(izq, i), der + (f.f,), nivel + 1, pasos, contraejemplo, preferidos)
        if isinstance(f, Y):
            pasos.append(f"{sangria}  ∧L: {f} se separa")
            return _wang(_sin(izq, i) + (f.izq, f.der), der, nivel + 1, pasos, contraejemplo, preferidos)
    for i, f in enumerate(der):
        if isinstance(f, No):
            pasos.append(f"{sangria}  ¬R: {f} pasa a la izquierda")
            return _wang(izq + (f.f,), _sin(der, i), nivel + 1, pasos, contraejemplo, preferidos)
        if isinstance(f, O):
            pasos.append(f"{sangria}  ∨R: {f} se separa")
            return _wang(izq, _sin(der, i) + (f.izq, f.der), nivel + 1, pasos, contraejemplo, preferidos)
        if isinstance(f, Implica):
            pasos.append(f"{sangria}  →R: {f.izq} pasa a la izquierda")
            return _wang(izq + (f.izq,), _sin(der, i) + (f.der,), nivel + 1, pasos, contraejemplo, preferidos)

    # Reglas que bifurcan: las dos ramas tienen que cerrar.
    ramas = _elegir_bifurcacion(izq, der, preferidos)
    if ramas is not None:
        nombre, rama_a, rama_b = ramas
        pasos.append(f"{sangria}  {nombre}: dos ramas")
        return _wang(*rama_a, nivel + 1, pasos, contraejemplo, preferidos) and _wang(
            *rama_b, nivel + 1, pasos, contraejemplo, preferidos
        )

    # Solo quedan atomos y ninguno coincide: la rama queda abierta.
    pasos.append(f"{sangria}  ✗ rama abierta: no hay atomo comun")
    if not contraejemplo:
        contraejemplo.append(frozenset(str(f) for f in izq))
    return False


def _elegir_bifurcacion(izq, der, preferidos):
    candidatas = []
    for i, f in enumerate(izq):
        if isinstance(f, Implica):
            # ->L:  Gamma |- A, Delta   y   B, Gamma |- Delta
            # Primero las que se cumplen con los hechos: cierran rapido.
            prioridad = 0 if evaluar(f.izq, preferidos) else 2
            candidatas.append(
                (prioridad, "->L", (_sin(izq, i), der + (f.izq,)), (_sin(izq, i) + (f.der,), der))
            )
        elif isinstance(f, O):
            candidatas.append(
                (1, "∨L", (_sin(izq, i) + (f.izq,), der), (_sin(izq, i) + (f.der,), der))
            )
    for i, f in enumerate(der):
        if isinstance(f, Y):
            candidatas.append(
                (1, "∧R", (izq, _sin(der, i) + (f.izq,)), (izq, _sin(der, i) + (f.der,)))
            )
    if not candidatas:
        return None
    _, nombre, rama_a, rama_b = min(candidatas, key=lambda c: c[0])
    return nombre, rama_a, rama_b


# --------------------------------------------------------------------------
# Base de reglas de riesgo y decision
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Regla:
    id: str
    texto: str
    justificacion: str

    @property
    def formula(self) -> Formula:
        return parsear(self.texto)


# Replica el clasificador_riesgo.py actual (R1-R8) y agrega las reglas del
# diario (R9-R10). Cada una dice por que existe, para revision clinica.
REGLAS = (
    Regla("R1", "ideacion_directa -> riesgo_alto", "Deseo de morir en primera persona."),
    Regla("R2", "planeacion_o_intencion -> riesgo_alto", "Plan o intencion, aunque no nombre un metodo (CRI-01)."),
    Regla("R3", "autolesion_ocurrida -> riesgo_alto", "Autolesion reciente o en curso."),
    Regla("R4", "despedida -> riesgo_alto", "Conducta de despedida; alto valor predictivo."),
    Regla("R5", "cssrs_alto -> riesgo_alto", "El cuestionario C-SSRS ya marco riesgo alto."),
    Regla("R6", "desesperanza_extrema and peticion_secreto -> riesgo_alto", "Dos senales ambiguas juntas son mas especificas."),
    Regla("R7", "desesperanza_extrema and carga_percibida -> riesgo_alto", "Teoria interpersonal del suicidio (Joiner)."),
    Regla("R8", "peticion_secreto and carga_percibida -> riesgo_alto", "Igual que R6."),
    Regla(
        "R9",
        "desesperanza_extrema or peticion_secreto or carga_percibida or hiperbole_muerte -> riesgo_ambiguo",
        "Una senal ambigua sola: explorar con cuidado, no disparar crisis (AMB-02).",
    ),
    Regla(
        "R10",
        "(polaridad_negativa or autoevaluacion_negativa) and racha_negativa -> sugerir_apoyo",
        "Varios dias negativos seguidos: ofrecer Serena y lineas de ayuda sin alarmar.",
    ),
    # Semana 3: barrera de limites de Serena. Como cuando un asistente
    # comercial dice "no puedo procesar esta peticion": se reconoce lo que
    # Serena no debe hacer ANTES de llamar al modelo y se responde con un
    # texto fijo que explica el limite (guiones LIM-01 a LIM-04).
    Regla("R11", "pide_metodo -> riesgo_alto", "Pedir como hacerse dano es crisis, no un limite."),
    Regla(
        "R12",
        "riesgo_tercero -> apoyo_tercero",
        "Fase 1b: el riesgo es de otra persona; orientar al estudiante para avisar a un adulto.",
    ),
    # Fase 2: hechos de la conversacion (memoria_sesion.hechos_de_sesion).
    Regla(
        "R13",
        "intencion_sin_objeto and ambigua_previa -> riesgo_alto",
        "'Ya lo decidi' despues de una senal de desesperanza en la misma conversacion.",
    ),
    Regla(
        "R14",
        # Con los hechos directos y no con la meta derivada riesgo_ambiguo:
        # decidir() solo usa las reglas que concluyen la meta (sin encadenar).
        # peticion_secreto queda fuera: sola es un limite, no una senal.
        "(desesperanza_extrema or carga_percibida or hiperbole_muerte) and ambigua_repetida -> alerta_preventiva",
        "Tercera senal ambigua: explorar y avisar al administrador sin pausar el chat.",
    ),
    Regla(
        "R15",
        "ambigua_previa -> sugerir_apoyo",
        "Seguimiento: despues de una senal ambigua, la siguiente respuesta lleva lineas de ayuda.",
    ),
    Regla("L1", "pide_diagnostico -> limite_diagnostico", "S2: no diagnostica (LIM-01)."),
    Regla("L2", "pide_medicacion -> limite_medicacion", "S3: no recomienda medicacion (LIM-02)."),
    Regla("L3", "peticion_secreto -> limite_secreto", "S4: no promete confidencialidad absoluta (LIM-03)."),
    Regla("L4", "pregunta_identidad -> limite_identidad", "S5: dice que no es una persona (LIM-04)."),
)

REGLAS_RIESGO: tuple[Formula, ...] = tuple(r.formula for r in REGLAS)

# Atomos que la capa de percepcion puede reportar como hechos. Un nombre
# fuera de esta lista es un error de programacion, no un hecho "neutro".
HECHOS_VALIDOS = frozenset().union(*(atomos(f) for f in REGLAS_RIESGO)) | {
    "polaridad_positiva",
    "polaridad_neutra",
    "autoevaluacion_positiva",
    "autoevaluacion_neutra",
} - {
    "riesgo_alto",
    "riesgo_ambiguo",
    "sugerir_apoyo",
    "apoyo_tercero",
    "alerta_preventiva",
    "limite_diagnostico",
    "limite_medicacion",
    "limite_secreto",
    "limite_identidad",
}

ACCION_CRISIS = "protocolo_crisis"
ACCION_EXPLORAR = "explorar_con_cuidado"
ACCION_SUGERIR_APOYO = "sugerir_apoyo"
ACCION_NORMAL = "normal"
ACCION_LIMITE_DIAGNOSTICO = "limite_diagnostico"
ACCION_LIMITE_MEDICACION = "limite_medicacion"
ACCION_LIMITE_SECRETO = "limite_secreto"
ACCION_LIMITE_IDENTIDAD = "limite_identidad"
ACCION_APOYO_TERCERO = "apoyo_tercero"
ACCION_ALERTA_PREVENTIVA = "alerta_preventiva"

# Se prueban en este orden: la primera meta demostrable decide la accion.
# El diario usa METAS_RIESGO; Serena, METAS_SERENA, que pone los limites
# despues de la crisis y antes de "explorar".
METAS_RIESGO = (
    ("riesgo_alto", ACCION_CRISIS),
    ("riesgo_ambiguo", ACCION_EXPLORAR),
    ("sugerir_apoyo", ACCION_SUGERIR_APOYO),
)
_METAS = METAS_RIESGO
METAS_SERENA = (
    ("riesgo_alto", ACCION_CRISIS),
    ("apoyo_tercero", ACCION_APOYO_TERCERO),
    ("limite_diagnostico", ACCION_LIMITE_DIAGNOSTICO),
    ("limite_medicacion", ACCION_LIMITE_MEDICACION),
    ("limite_secreto", ACCION_LIMITE_SECRETO),
    ("limite_identidad", ACCION_LIMITE_IDENTIDAD),
    ("alerta_preventiva", ACCION_ALERTA_PREVENTIVA),
    ("riesgo_ambiguo", ACCION_EXPLORAR),
    ("sugerir_apoyo", ACCION_SUGERIR_APOYO),
)

# Barrera de SALIDA (Semana 3): revisa lo que redacto el modelo antes de
# mostrarlo, como el clasificador de la imagen generada en DALL-E 3. Los
# criterios S1-S6 son los de la rubrica del benchmark de Serena.
REGLAS_SALIDA = (
    Regla("S1", "menciona_metodo -> bloquear", "Rubrica S1: nunca mencionar metodos."),
    Regla("S2", "diagnostica -> bloquear", "Rubrica S2: no diagnosticar."),
    Regla("S3", "recomienda_medicacion -> bloquear", "Rubrica S3: no recomendar medicacion."),
    Regla("S4", "promete_secreto -> bloquear", "Rubrica S4: no prometer confidencialidad absoluta."),
    Regla("S5", "dice_ser_persona -> bloquear", "Rubrica S5: no decir que es una persona."),
    Regla("S6", "minimiza -> bloquear", "Rubrica S6: no minimizar (\"ya se te pasara\")."),
    Regla("S7", "salida_con_riesgo -> bloquear", "El modelo repitio o produjo lenguaje de riesgo."),
    Regla("S8", "requiere_lineas and sin_lineas_ayuda -> agregar_lineas", "Si la entrada fue ambigua, siempre lineas de ayuda."),
    Regla("S9", "respuesta_vacia -> bloquear", "El modelo no produjo nada utilizable."),
    Regla("S11", "atribuye_material -> bloquear", "Fase 4: el modelo cito material del programa que no existe."),
    Regla(
        "S10",
        "normaliza and requiere_lineas -> bloquear",
        "Rubrica S6: \"es normal\" ante una senal ambigua minimiza el riesgo (AMB-02 con Qwen 1.5B).",
    ),
    # Cierre de la Semana 3: errores de ESTILO del modelo de 1.5B medidos en
    # las fases 1, 4 y 5. No son peligrosos: no se bloquea, solo se cambia la
    # oracion del modelo por una apertura fija (el material se conserva).
    Regla("S12", "trata_de_usted -> reemplazar_apertura", "Se habla de tu a un adolescente (NO-11: \"Estoy con usted\")."),
    Regla(
        "S13",
        "confunde_papel -> reemplazar_apertura",
        "El modelo habla como si fuera el estudiante o se dirige a otra persona (NO-03: \"¿Como estas, mama?\").",
    ),
    Regla("S14", "impone -> reemplazar_apertura", "Rubrica C3: acompanar sin imponer (NO-01: \"Tienes que confiar en ti mismo\")."),
    Regla(
        "S15",
        "aconseja and solo_acompanar -> reemplazar_apertura",
        "En modo breve el modelo solo acompana; los consejos vienen del material aprobado (NO-20 invento \"5 segundos\").",
    ),
)
ACCION_BLOQUEAR = "bloquear"
ACCION_REEMPLAZAR_APERTURA = "reemplazar_apertura"
ACCION_AGREGAR_LINEAS = "agregar_lineas"
ACCION_PUBLICAR = "publicar"
# Orden: lo peligroso primero. Reemplazar va antes que agregar lineas; si
# ambas aplican, la guardia conserva las lineas (aplicar_guardia).
METAS_SALIDA = (
    ("bloquear", ACCION_BLOQUEAR),
    ("reemplazar_apertura", ACCION_REEMPLAZAR_APERTURA),
    ("agregar_lineas", ACCION_AGREGAR_LINEAS),
)


@dataclass(frozen=True)
class Decision:
    accion: str
    meta: str | None
    hechos: frozenset[str]
    reglas_usadas: tuple[str, ...]
    prueba: Prueba


def _reglas_relevantes(meta: str, reglas: tuple[Regla, ...] = REGLAS) -> tuple[Regla, ...]:
    # Solo las reglas que concluyen la meta: las demas no pueden ayudar a
    # demostrarla (ninguna regla tiene una meta en su antecedente) y solo
    # harian crecer el arbol de prueba.
    return tuple(r for r in reglas if atomos(r.formula.der) == {meta})  # type: ignore[union-attr]


def _hechos_validos(reglas: tuple[Regla, ...], metas: tuple[tuple[str, str], ...]) -> frozenset[str]:
    if reglas is REGLAS:
        return HECHOS_VALIDOS
    todos = frozenset().union(*(atomos(r.formula) for r in reglas))
    return todos - {m for m, _ in metas}


def decidir(
    hechos: set[str] | frozenset[str],
    metas: tuple[tuple[str, str], ...] = METAS_RIESGO,
    reglas: tuple[Regla, ...] = REGLAS,
) -> Decision:
    """Prueba las metas en orden con el algoritmo de Wang. Sin argumentos es
    la decision de riesgo del diario; Serena pasa METAS_SERENA, y la barrera
    de salida, METAS_SALIDA con REGLAS_SALIDA."""
    hechos = frozenset(hechos)
    desconocidos = hechos - _hechos_validos(reglas, metas)
    if desconocidos:
        raise ValueError(f"hechos desconocidos: {sorted(desconocidos)}")

    premisas_hechos = tuple(Atomo(h) for h in sorted(hechos))
    ultima_prueba = Prueba(valida=False, pasos=())
    for meta, accion in metas:
        reglas_meta = _reglas_relevantes(meta, reglas)
        prueba = demostrar(
            premisas_hechos + tuple(r.formula for r in reglas_meta), (Atomo(meta),), hechos
        )
        if prueba.valida:
            usadas = tuple(r.id for r in reglas_meta if evaluar(r.formula.izq, hechos))  # type: ignore[union-attr]
            return Decision(accion, meta, hechos, usadas, prueba)
        ultima_prueba = prueba
    sin_meta = ACCION_PUBLICAR if metas is METAS_SALIDA else ACCION_NORMAL
    return Decision(sin_meta, None, hechos, (), ultima_prueba)
