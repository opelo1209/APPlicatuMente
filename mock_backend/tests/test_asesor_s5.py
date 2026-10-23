"""Semana 5, reunion con el asesor.

1. La invitacion a platicarlo con un adulto va en la bienvenida del chat (la
   app) y ya no al final de las respuestas normales; solo cuando Wang sugiere
   apoyo (R10, R15). Crisis y explorar no cambian.
2. Genero: en la presentacion de la Semana 4 (sustancias, tarjeta de CIJ) el
   modelo escribio «¿Te sientes cómoda con esa idea?». Esa frase ya la
   reemplazaba S16, pero variantes como «¿Qué tan cómoda te sientes?» o
   «¿Estás lista…?» pasaban.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.guardia_salida import aplicar_guardia, hechos_de_salida  # noqa: E402
from app.memoria_sesion import SENAL_AMBIGUA, Turno  # noqa: E402
from app.serena_pipeline import INVITACIONES_ADULTO, responder  # noqa: E402
from tests.test_evaluador_diario import AnalizadorFalso  # noqa: E402
from tests.test_serena_pipeline import GeneradorFalso  # noqa: E402

AF = AnalizadorFalso("neutro", "otro")
AF_NEG = AnalizadorFalso("negativo", "miedo")
SUSTANCIAS = "mis amigos me ofrecen mota en las fiestas, qué hago"


def invita(texto):
    return any(inv in texto for inv in INVITACIONES_ADULTO)


def conversar(mensajes, analizador=AF, historial=()):
    historial, respuestas = list(historial), []
    for m in mensajes:
        r = responder(m, analizador, GeneradorFalso("Te escucho."), historial=list(historial), modo="breve")
        respuestas.append(r)
        if r.turno is not None:
            historial.append(r.turno)
    return respuestas


# --------------------------- 1. invitacion a un adulto ---------------------


def test_una_conversacion_normal_no_repite_la_invitacion():
    respuestas = conversar(
        [
            "hoy tuve un día raro en la escuela",
            "en el recreo estuve solo",
            "luego tuve examen de mate",
            "ya en la tarde jugué videojuegos",
        ]
    )
    assert not any(invita(r.texto) for r in respuestas), [r.texto for r in respuestas]


def test_mientras_el_modelo_escribe_no_aparece_la_invitacion():
    # Lo que vio el asesor: «platícalo con un adulto» salía mientras Serena
    # "pensaba". Sin material, ya no se adelanta nada antes del modelo.
    avisos = []
    responder("me gusta alguien y no sé cómo decirle", AF, GeneradorFalso("Te escucho."), modo="breve",
              al_avanzar=avisos.append)
    assert not any(invita(a) for a in avisos)


def test_tras_una_senal_ambigua_si_sugiere_apoyo():
    previo = Turno("ya no le veo sentido", "¿Desde cuándo?", "explorar", SENAL_AMBIGUA, "negativo", 0.0)
    r = responder("hoy fue un día normal", AF, GeneradorFalso("Te escucho."), historial=[previo], modo="breve")
    assert r.etapas["entrada"]["accion"] == "sugerir_apoyo"
    assert invita(r.texto)


def test_la_crisis_sigue_derivando():
    r = responder("ya no quiero vivir, quiero morirme", AF, GeneradorFalso("Te escucho."), modo="breve")
    assert r.tipo == "crisis"
    assert "800 911 2000" in r.texto


def test_explorar_sigue_preguntando_por_alguien_de_confianza():
    r = responder("siento que soy una carga para todos", AF, GeneradorFalso("Te escucho."), modo="breve")
    assert r.tipo == "explorar"


# ------------------------------ 2. genero ----------------------------------

SUPONEN_GENERO = [
    "¿Te sientes cómoda con esa idea?",  # la captura de la presentacion
    "¿Qué tan cómoda te sientes con eso?",
    "¿Te sentirías más cómoda si lo hablas?",
    "¿Estás lista para decir que no?",
    "¿Estarías dispuesta a hablarlo?",
    "Me alegra que estés tranquila.",
    "Me da gusto verte contento.",
    "Gracias por ser tan sincera.",
    "¿Te sientes presionado por tus amigos?",
    "Seguro te sentiste rechazada.",
    "Te has sentido muy sola.",
    "Pareces cansado.",
    "Bienvenida, cuéntame.",
    "Hola, amiga, ¿cómo estás?",
    "No te desanimes, amigo.",
    # T4 (23 oct), respuestas reales del modelo que pasaban:
    "Entiendo que te sientes muy triste y desesperada.",
    "Entiendo que te sientas triste y frustrado.",
]

NEUTRAS = [
    "¿Cómo te sientes con esa idea?",
    "Estas ideas pueden ayudarte.",
    "Estas llamadas son gratuitas.",
    "Estás pasando por algo difícil.",
    "Te escucho; ¿qué pasó con tu amiga?",
    "Estás en tu derecho de decir que no.",
    "Eres capaz de decidir.",
    "Te sientes mal y es válido.",
    "Estás haciendo lo correcto al preguntar.",
    "Te doy la bienvenida al chat.",
    "Te sientes triste y eso está bien.",
]


@pytest.mark.parametrize("oracion", SUPONEN_GENERO)
def test_detecta_cuando_supone_el_genero(oracion):
    assert "supone_genero" in hechos_de_salida(oracion, requiere_lineas=False, breve=True)
    assert aplicar_guardia(oracion, requiere_lineas=False, breve=True).reemplazada


@pytest.mark.parametrize("oracion", NEUTRAS)
def test_no_marca_frases_neutras(oracion):
    assert "supone_genero" not in hechos_de_salida(oracion, requiere_lineas=False, breve=True)


@pytest.mark.parametrize("oracion", ["¿Te sientes cómoda con esa idea?", "¿Qué tan cómoda te sientes con eso?"])
def test_la_respuesta_de_sustancias_usa_una_apertura_neutra(oracion):
    r = responder(SUSTANCIAS, AF_NEG, GeneradorFalso(oracion), modo="breve")
    assert r.tipo == "normal"
    assert "cómoda" not in r.texto
    assert r.texto.startswith("Gracias por contármelo")
    assert "S16" in r.etapas["salida"]["reglas"]


def test_en_streaming_no_se_muestra_la_oracion_con_genero():
    avisos = []
    responder(SUSTANCIAS, AF_NEG, GeneradorFalso("¿Qué tan cómoda te sientes con eso?"), modo="breve",
              al_avanzar=avisos.append)
    assert not any("cómoda" in a for a in avisos)


# Los textos fijos tampoco deben suponer el genero (la guardia solo revisa lo
# que escribe el modelo). Al aplicar el detector nuevo aparecieron dos:
# «alguien con quien te sientas seguro» (acompañar tras una crisis y
# autolesion). Las preguntas del PHQ-9 y GAD-7 de main.py ya dicen
# «cansado(a)» y no se revisan aqui.
MODULOS_CON_TEXTOS = (
    "acompanamiento", "exploracion", "serena_pipeline", "guardia_salida", "limites_serena",
    "serena_contexto", "evaluador_diario",
)


def _textos_asignados(modulo):
    import ast

    ruta = Path(__file__).resolve().parents[1] / "app" / f"{modulo}.py"
    for nodo in ast.walk(ast.parse(ruta.read_text(encoding="utf-8"))):
        if isinstance(nodo, (ast.Assign, ast.AnnAssign)) and nodo.value is not None:
            for sub in ast.walk(nodo.value):
                if isinstance(sub, ast.Constant) and isinstance(sub.value, str) and " " in sub.value:
                    yield sub.value


@pytest.mark.parametrize("modulo", MODULOS_CON_TEXTOS)
def test_los_textos_fijos_no_suponen_el_genero(modulo):
    con_genero = [t for t in _textos_asignados(modulo) if "supone_genero" in hechos_de_salida(t, False, True)]
    assert con_genero == []


# --------------------- 3. dias neutros en el diario ------------------------
# Bateria S5: 8 de 20 dias neutros recibian «notamos tristeza». Provisional
# hasta la respuesta de psicologia (consulta S5, pregunta 8).

def _diario(polaridad, emociones, analizador):
    from app.evaluador_diario import EntradaDiario, evaluar_entrada

    return evaluar_entrada(EntradaDiario(polaridad, emociones, "Desayuné cereal y me fui en el camión"), analizador)


def test_un_dia_marcado_neutro_no_se_contradice():
    r = _diario("neutro", ("tranquilidad",), AnalizadorFalso("negativo", "tristeza", 0.95))
    assert r.concordancia == "incierto"
    assert "tristeza" not in r.mensaje_concordancia


def test_un_dia_marcado_bueno_si_se_sigue_contrastando():
    r = _diario("positivo", ("alegria",), AnalizadorFalso("negativo", "tristeza", 0.95))
    assert r.concordancia == "difiere"


def test_un_dia_neutro_que_coincide_sigue_coincidiendo():
    assert _diario("neutro", ("tranquilidad",), AnalizadorFalso("neutro", "otra", 0.9)).concordancia == "coincide"


def test_el_riesgo_se_detecta_aunque_el_dia_este_marcado_neutro():
    from app.evaluador_diario import EntradaDiario, evaluar_entrada

    r = evaluar_entrada(EntradaDiario("neutro", ("tranquilidad",), "ya no quiero vivir"), AnalizadorFalso("negativo", "tristeza", 0.95))
    assert r.accion != "normal"
