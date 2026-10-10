"""Barrera de limites de Serena: lo que el estudiante PIDE y Serena no debe hacer.

PROTOTIPO (Semana 3). Es la parte "percepcion" de la barrera: convierte el
mensaje en hechos (pide_diagnostico, pide_medicacion, pide_metodo,
pregunta_identidad, peticion_secreto). La decision la toma el motor de
Wang con METAS_SERENA, igual que el riesgo.

Equivale a lo que hacen los asistentes comerciales cuando responden "no
puedo procesar esta peticion": se reconoce ANTES de llamar al modelo y se
contesta con un texto fijo que explica el limite (guiones LIM-01 a LIM-04
del benchmark de Serena). Pedir metodos no es un limite sino una crisis
(regla R11).

ESTADO: lexico escrito por el equipo tecnico; requiere revision clinica,
igual que el del clasificador de riesgo.
"""

from __future__ import annotations

import re

from .clasificador_riesgo import PETICION_SECRETO, _coincidencias, normalizar_chat

_PADECIMIENTOS = r"(?:depresion|deprimid[oa]|ansiedad|bipolar|tdah|trastorno\w*|autis\w+|esquizofreni\w+)"
_DIAGNOSTICO = [
    # "crees que tengo/soy...", "sera que estoy..."
    r"\b(?:crees|piensas|sera)\s+que\s+(?:tengo|soy|estoy|sufro)\b",
    # "tengo ansiedad?", "soy bipolar o que me pasa", "tengo ansiedad o solo..."
    rf"\b(?:tengo|soy|sufro\s+de|padezco)\s+(?:un\s+|una\s+)?{_PADECIMIENTOS}\s*(?:\?|o\s+(?:que|no|solo|nada))",
    # Fase 1b: "dime si tengo...", "creo que soy bipolar, tu que opinas",
    # "que trastorno tengo".
    r"\b(?:dime|sabes|puedes\s+decirme)\s+si\s+(?:tengo|soy|estoy|sufro)\b",
    rf"\bcreo\s+que\s+(?:tengo|soy|sufro\s+de|estoy)\s+(?:un\s+|una\s+)?{_PADECIMIENTOS}\b.{{0,30}}(?:\?|opinas|crees|verdad)",
    r"\b(?:que|cual)\s+(?:trastorno|enfermedad|diagnostico)\s+tengo\b",
    r"\b(?:me\s+puedes|puedes)\s+diagnosticar\b",
    r"\bdame\s+(?:un\s+)?diagnostico\b",
]

_FARMACOS = (
    r"(?:clonazepam|alprazolam|diazepam|lorazepam|rivotril|tafil|sertralina|fluoxetina|escitalopram|"
    r"paroxetina|melatonina|valeriana|antidepresiv\w*|ansiolitic\w*|somnifer\w*|tranquilizante\w*|"
    r"paracetamol|ibuprofeno|aspirina|naproxeno)"
)
_MEDICACION = [
    r"\b(?:que|cual|cuales|algun|alguna)\s+(?:pastillas?|medicamentos?|medicinas?)\b",
    r"\brecomiendas?\s+(?:algun|alguna|un|una)?\s*(?:medicamento|pastilla|medicina|suplemento)",
    rf"\b(?:tomar|tomo|tomarme|sirve|sirven|recomiendas?)\b.{{0,30}}\b{_FARMACOS}",
    rf"\b{_FARMACOS}\b.{{0,30}}\b(?:tomar|tomo|sirve|funciona|ayuda|ayudan|recomiendas?)",
    # Fase 1b: "puedo tomar las pastillas de mi abuela".
    rf"\bpuedo\s+tomar(?:me)?\b.{{0,30}}\b(?:pastillas?|medicamentos?|medicinas?|gotas|jarabe|{_FARMACOS})",
]

_IDENTIDAD = [
    r"\beres\s+(?:una\s+|un\s+)?(?:persona|humano|humana|real|bot|robot|ia|maquina|inteligencia\s+artificial|"
    r"psicolog[oa]|doctor[a]?|terapeuta)\b",
    r"\bhay\s+(?:alguien|una\s+persona)\s+(?:real\s+|de\s+verdad\s+)?(?:leyendo|contestando|ahi|del\s+otro\s+lado|detras)\b",
    r"\bhay\s+(?:una\s+)?persona\s+(?:detras|del\s+otro\s+lado)\b",
    r"\bcon\s+quien\s+estoy\s+hablando\b",
]

_METODO = [
    r"\bcomo\s+(?:me\s+)?(?:puedo\s+)?(?:cortarme|cortar|matarme|suicidarme|ahorcarme|lastimarme|hacerme\s+dano|"
    r"corto|mato|lastimo|ahorco)\b",
    r"\bcuant[ao]s\s+pastillas\b.{0,40}\b(?:morir|no\s+despertar|matar\w*|sobredosis|mortal\w*)\b",
    # Fase 1b: altura o caida mortal, tomarse todo un frasco, conseguir veneno.
    r"\b(?:altura|alto|caida)\b.{0,40}\b(?:mortal\w*|para\s+morir|matarme)\b",
    r"\b(?:todo\s+el\s+frasco|toda\s+la\s+caja|todas\s+las\s+pastillas)\b",
    r"\b(?:conseguir|comprar|tomar(?:me)?)\s+(?:un\s+|el\s+)?veneno\b",
    r"\b(?:forma|manera)\s+(?:mas\s+)?(?:facil|rapida|menos\s+dolorosa)\s+de\s+(?:morir|matarme|suicidarme)\b",
    r"\bsobredosis\b",
]


def _hay(patrones: list[str], plano: str) -> bool:
    return any(re.search(p, plano) for p in patrones)


def hechos_de_limites(texto: str) -> set[str]:
    """Hechos de la barrera de limites. Los nombres coinciden con los atomos
    de las reglas R11 y L1-L4 de motor_wang."""
    if not texto or not texto.strip():
        return set()
    # Se conservan los signos de interrogacion: "tengo ansiedad?" es una
    # pregunta de diagnostico; "tengo ansiedad cuando expongo" no lo es.
    plano = normalizar_chat(texto)
    hechos = set()
    if _hay(_DIAGNOSTICO, plano):
        hechos.add("pide_diagnostico")
    if _hay(_MEDICACION, plano):
        hechos.add("pide_medicacion")
    if _hay(_IDENTIDAD, plano):
        hechos.add("pregunta_identidad")
    if _hay(_METODO, plano):
        hechos.add("pide_metodo")
    if _coincidencias(PETICION_SECRETO, plano):
        hechos.add("peticion_secreto")
    return hechos
