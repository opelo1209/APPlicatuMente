"""Catalogo de polaridades y emociones del diario (semaforo de estado de animo).

PROTOTIPO (Semana 2). El estudiante elige primero la polaridad de su dia
(positivo, neutro o negativo) y despues las emociones que le correspondan;
las opciones dependen de la polaridad. Este mismo catalogo existe en el
frontend (lib/pantallas/diario/diario_catalogo.dart): si se cambia uno hay
que cambiar el otro.

Cada emocion se asocia a una de las 7 clases que reconoce el analizador de
emociones (pysentimiento: alegria, tristeza, enojo, miedo, sorpresa, asco,
otra). Esa asociacion permite comparar lo que el estudiante marco con lo que
detecta el analizador. Es un borrador tecnico: la lista de emociones y su
agrupacion deben revisarse con psicologia.
"""

from __future__ import annotations

from dataclasses import dataclass

POLARIDAD_POSITIVA = "positivo"
POLARIDAD_NEUTRA = "neutro"
POLARIDAD_NEGATIVA = "negativo"
POLARIDADES = (POLARIDAD_POSITIVA, POLARIDAD_NEUTRA, POLARIDAD_NEGATIVA)

# Clases del analizador de emociones, ya en espanol.
CLASE_ALEGRIA = "alegria"
CLASE_TRISTEZA = "tristeza"
CLASE_ENOJO = "enojo"
CLASE_MIEDO = "miedo"
CLASE_SORPRESA = "sorpresa"
CLASE_ASCO = "asco"
CLASE_OTRA = "otra"


@dataclass(frozen=True)
class Emocion:
    clave: str
    nombre: str
    polaridad: str
    clase_analizador: str


EMOCIONES: tuple[Emocion, ...] = (
    # Positivas
    Emocion("alegria", "Alegría", POLARIDAD_POSITIVA, CLASE_ALEGRIA),
    Emocion("felicidad", "Felicidad", POLARIDAD_POSITIVA, CLASE_ALEGRIA),
    Emocion("calma", "Calma", POLARIDAD_POSITIVA, CLASE_OTRA),
    Emocion("gratitud", "Gratitud", POLARIDAD_POSITIVA, CLASE_ALEGRIA),
    Emocion("orgullo", "Orgullo", POLARIDAD_POSITIVA, CLASE_ALEGRIA),
    Emocion("entusiasmo", "Entusiasmo", POLARIDAD_POSITIVA, CLASE_ALEGRIA),
    Emocion("carino", "Cariño", POLARIDAD_POSITIVA, CLASE_ALEGRIA),
    Emocion("esperanza", "Esperanza", POLARIDAD_POSITIVA, CLASE_ALEGRIA),
    # Neutras
    Emocion("tranquilidad", "Tranquilidad", POLARIDAD_NEUTRA, CLASE_OTRA),
    Emocion("cansancio", "Cansancio", POLARIDAD_NEUTRA, CLASE_OTRA),
    Emocion("aburrimiento", "Aburrimiento", POLARIDAD_NEUTRA, CLASE_OTRA),
    Emocion("confusion", "Confusión", POLARIDAD_NEUTRA, CLASE_OTRA),
    Emocion("sorpresa", "Sorpresa", POLARIDAD_NEUTRA, CLASE_SORPRESA),
    Emocion("indiferencia", "Indiferencia", POLARIDAD_NEUTRA, CLASE_OTRA),
    Emocion("nostalgia", "Nostalgia", POLARIDAD_NEUTRA, CLASE_TRISTEZA),
    # Negativas
    Emocion("tristeza", "Tristeza", POLARIDAD_NEGATIVA, CLASE_TRISTEZA),
    Emocion("angustia", "Angustia", POLARIDAD_NEGATIVA, CLASE_MIEDO),
    Emocion("ansiedad", "Ansiedad", POLARIDAD_NEGATIVA, CLASE_MIEDO),
    Emocion("miedo", "Miedo", POLARIDAD_NEGATIVA, CLASE_MIEDO),
    Emocion("ira", "Ira / enojo", POLARIDAD_NEGATIVA, CLASE_ENOJO),
    Emocion("frustracion", "Frustración", POLARIDAD_NEGATIVA, CLASE_ENOJO),
    Emocion("soledad", "Soledad", POLARIDAD_NEGATIVA, CLASE_TRISTEZA),
    Emocion("culpa", "Culpa", POLARIDAD_NEGATIVA, CLASE_TRISTEZA),
    Emocion("verguenza", "Vergüenza", POLARIDAD_NEGATIVA, CLASE_TRISTEZA),
    Emocion("asco", "Asco", POLARIDAD_NEGATIVA, CLASE_ASCO),
)

_POR_CLAVE = {e.clave: e for e in EMOCIONES}


def emociones_de(polaridad: str) -> tuple[Emocion, ...]:
    if polaridad not in POLARIDADES:
        raise ValueError(f"polaridad desconocida: {polaridad!r}")
    return tuple(e for e in EMOCIONES if e.polaridad == polaridad)


def buscar(clave: str) -> Emocion:
    try:
        return _POR_CLAVE[clave]
    except KeyError:
        raise ValueError(f"emocion desconocida: {clave!r}") from None
