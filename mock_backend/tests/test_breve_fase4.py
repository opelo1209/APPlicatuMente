"""Fase 4 del plan de mejora de Serena (Semana 3): un papel mas pequeno para el modelo.

En la linea base el modelo de 1.5B tardaba 37 s (p50), inventaba datos y
nunca orientaba hacia un adulto (C6 = 0 en 20 de 20). En modo "breve" solo
escribe UNA oracion de acompanamiento; despues va el texto aprobado tal cual
y una invitacion fija a hablar con un adulto de confianza.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.serena_pipeline import INVITACIONES_ADULTO, MAX_TOKENS_BREVE, extracto, responder  # noqa: E402
from tests.test_evaluador_diario import AnalizadorFalso  # noqa: E402
from tests.test_serena_pipeline import GeneradorFalso  # noqa: E402

AF = AnalizadorFalso("negativo", "miedo")
LARGA = "Entiendo que te pongas nervioso al exponer. Es algo que le pasa a mucha gente. Además te digo que tienes que relajarte siempre."


def test_breve_usa_una_oracion_del_modelo_el_texto_aprobado_y_la_invitacion():
    g = GeneradorFalso(LARGA)
    r = responder("me pongo muy nervioso cuando expongo", AF, g, modo="breve")
    assert r.tipo == "normal"
    assert r.texto.startswith("Entiendo que te pongas nervioso al exponer.")
    assert "Es algo que le pasa" not in r.texto  # solo la primera oracion
    assert "Del material del programa:" in r.texto
    assert any(inv in r.texto for inv in INVITACIONES_ADULTO)
    assert r.fuentes
    assert g.ultimo_max_tokens == MAX_TOKENS_BREVE


def test_breve_sin_tema_no_cita_material_pero_invita_a_un_adulto():
    g = GeneradorFalso("Qué bueno que me lo cuentes. ¿Cómo te sentiste?")
    r = responder("me gusta alguien y no sé cómo decirle", AF, g, modo="breve")
    assert "Del material del programa" not in r.texto
    assert "¿Cómo te sentiste?" in r.texto  # sin material, el modelo puede preguntar
    assert any(inv in r.texto for inv in INVITACIONES_ADULTO)
    assert not r.fuentes


def test_breve_la_guardia_sigue_revisando_lo_que_escribe_el_modelo():
    r = responder("me pongo muy nervioso cuando expongo", AF, GeneradorFalso("Por lo que me cuentas, tienes ansiedad."), modo="breve")
    assert r.tipo == "bloqueada"


def test_breve_si_el_modelo_no_termina_la_oracion_usa_una_apertura_fija():
    r = responder("me pongo muy nervioso cuando expongo", AF, GeneradorFalso("Entiendo que cuando pasas al frente te"), modo="breve")
    assert "pasas al frente te" not in r.texto
    assert "Del material del programa:" in r.texto


def test_breve_despues_de_una_senal_ambigua_agrega_lineas():
    g = GeneradorFalso("Gracias por seguir contándome.")
    primera = responder("ya no le veo sentido a nada", AF, g, modo="breve")
    r = responder("me pongo nervioso en la escuela", AF, g, modo="breve", historial=(primera.turno,))
    assert "800 911 2000" in r.texto


def test_el_modo_completo_conserva_el_comportamiento_anterior():
    g = GeneradorFalso("Respirar lento ayuda. Prueba inhalar cuatro segundos.")
    r = responder("cómo respiro para calmarme", AF, g, modo="completo")
    assert "Del material del programa" not in r.texto
    assert g.ultimo_max_tokens is None


def test_extracto_corrige_mayusculas_y_quita_viñetas():
    texto = "LA ANSIEDAD ES UNA EMOCIÓN NORMAL QUE TODAS LAS PERSONAS SIENTEN.\n• Puede aparecer antes de un examen."
    e = extracto(texto, "qué es la ansiedad")
    assert e.startswith("La ansiedad es una emoción normal")
    assert "•" not in e


def test_extracto_prefiere_las_oraciones_relacionadas_con_la_pregunta():
    texto = "Estas actividades ayudan. 1. RESPIRA LENTO: inhala 4 segundos. 2. Haz ejercicio. 3. Duerme bien por las noches."
    e = extracto(texto, "cómo respiro para calmarme", max_oraciones=1)
    assert "inhala" in e.lower()


def test_extracto_baja_los_encabezados_en_mayusculas_dentro_de_la_oracion():
    # Oracion real del corpus (58 % de mayusculas: la primera version, que solo
    # bajaba oraciones con mas de 60 %, la dejaba igual).
    e = extracto("OPCIONES DE APOYO: RESPIRACIÓN Y RELAJACIÓN: ayudan a calmar tu cuerpo y mente.", "respirar")
    assert e == "Opciones de apoyo: respiración y relajación: ayudan a calmar tu cuerpo y mente."
    assert extracto("La TDAH no es tu culpa.", "x") == "La TDAH no es tu culpa."  # siglas sueltas se quedan


# --------------------------------------------------------------------------
# Hallazgo en el servidor: el modelo copiaba "Del material del programa:" de
# sus respuestas anteriores (que recibia como contexto) e INVENTABA material
# ("Del material del programa: La empatia es...", texto que no existe).
# --------------------------------------------------------------------------


def test_el_contexto_solo_lleva_lo_que_escribio_el_estudiante():
    g = GeneradorFalso("Qué bueno que lo cuentes.")
    primera = responder("me pongo muy nervioso cuando expongo", AF, g, modo="breve")
    assert "Del material del programa" in primera.texto
    responder("y también cuando hablo con gente nueva", AF, g, modo="breve", historial=(primera.turno,))
    contenidos = " ".join(m["content"] for m in g.ultimos_mensajes)
    assert "me pongo muy nervioso cuando expongo" in contenidos
    assert "Del material del programa" not in contenidos
    assert all(m["role"] != "assistant" for m in g.ultimos_mensajes)


def test_la_guardia_bloquea_material_inventado_por_el_modelo():
    falso = GeneradorFalso("Entiendo. Del material del programa: La empatía es una habilidad.")
    r = responder("cómo ayudo a un amigo que está triste", AF, falso, modo="breve")
    assert r.tipo == "bloqueada"
    assert "La empatía es una habilidad" not in r.texto


def test_la_apertura_del_modelo_empieza_con_mayuscula():
    # NO-20 en el servidor: "respira profundamente y lentamente..."
    # (Cierre de la Semana 3: el ejemplo era "respira conmigo un momento.",
    # que ahora la regla S15 trata como una tecnica y reemplaza.)
    r = responder("cómo respiro para calmarme", AF, GeneradorFalso("entiendo que quieras calmarte."), modo="breve")
    assert r.texto.startswith("Entiendo que quieras calmarte.")
