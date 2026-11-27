"""Semana 4: Serena dejaba de sonar a conversacion porque cerraba TODAS las
respuestas normales con «platícalo con un adulto de confianza».

La invitacion se agregaba en cada mensaje del modo breve, sin ver si ya se
habia dicho. Ahora se agrega solo si no aparecio en las dos respuestas
anteriores de Serena. Crisis, limites y la sugerencia de apoyo de Wang (R10)
no cambian: ahi la derivacion siempre va.

Semana 5: la bienvenida del chat ya lo dice; una respuesta normal ya no
invita (tests/test_bienvenida_s5.py). Estas pruebas usan una conversacion con
una senal ambigua previa (R15, sugerir apoyo), que es donde la invitacion
sigue y donde importa que no se repita.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.memoria_sesion import SENAL_AMBIGUA, SENAL_NINGUNA, Turno  # noqa: E402
from app.serena_pipeline import INVITACIONES_ADULTO, responder  # noqa: E402
from tests.test_evaluador_diario import AnalizadorFalso  # noqa: E402

AF = AnalizadorFalso("neutro", "otro")


class GeneradorFijo:
    nombre = "fijo"

    def generar(self, mensajes, max_tokens=None):
        return "Te escucho."


def turno(respuesta):
    return Turno("mensaje anterior", respuesta, "normal", SENAL_NINGUNA, "neutro", 0.0)


# Un mensaje ambiguo al inicio de la conversacion activa R15 en los siguientes.
AMBIGUO = Turno("ya no le veo sentido a nada", "¿Desde cuándo te sientes así?", "explorar", SENAL_AMBIGUA, "negativo", 0.0)


def invita(texto):
    return any(inv in texto for inv in INVITACIONES_ADULTO)


def conversar(mensajes):
    historial, respuestas = [AMBIGUO], []
    for m in mensajes:
        r = responder(m, AF, GeneradorFijo(), historial=list(historial), modo="breve")
        respuestas.append(r)
        if r.turno is not None:
            historial.append(r.turno)
    return respuestas


def test_tras_una_senal_ambigua_si_invita_a_un_adulto():
    r = responder("hoy tuve un día raro en la escuela", AF, GeneradorFijo(), historial=[AMBIGUO], modo="breve")
    assert invita(r.texto)


def test_no_se_repite_si_ya_invito_en_la_respuesta_anterior():
    anterior = turno("Te escucho. Recuerda que puedes buscar a un adulto de confianza para hablar de esto.")
    r = responder("y luego me fui a mi casa", AF, GeneradorFijo(), historial=[AMBIGUO, anterior], modo="breve")
    assert not invita(r.texto)


def test_en_una_conversacion_de_seis_mensajes_invita_a_lo_mas_dos_veces():
    respuestas = conversar(
        [
            "hoy tuve un día raro en la escuela",
            "no sé, todo normal pero raro",
            "en el recreo estuve solo",
            "luego tuve examen de mate",
            "creo que me fue más o menos",
            "ya en la tarde jugué videojuegos",
        ]
    )
    veces = sum(invita(r.texto) for r in respuestas)
    assert 1 <= veces <= 2, [r.texto for r in respuestas]


def test_vuelve_a_invitar_despues_de_dos_respuestas_sin_invitacion():
    sin_invitacion = [AMBIGUO, turno("Te escucho."), turno("Qué bien que me lo cuentes.")]
    r = responder("otra vez me siento raro", AF, GeneradorFijo(), historial=sin_invitacion, modo="breve")
    assert invita(r.texto)


def test_una_invitacion_de_otro_texto_tambien_cuenta():
    # La respuesta segura de explorar ya pidio platicarlo con alguien.
    anterior = turno("Si te sirve, platícalo con un adulto de confianza. Línea de la Vida 800 911 2000.")
    r = responder("bueno, cambiando de tema", AF, GeneradorFijo(), historial=[AMBIGUO, anterior], modo="breve")
    assert not invita(r.texto)


def test_la_crisis_siempre_trae_las_lineas_aunque_ya_se_hayan_dado():
    anterior = turno("Si lo necesitas, puedes llamar a la Línea de la Vida (800 911 2000). adulto de confianza")
    r = responder("ya pensé en cómo hacerlo y creo que sí lo voy a hacer", AF, GeneradorFijo(), historial=[anterior])
    assert r.tipo == "crisis"
    assert "800 911 2000" in r.texto


def test_sin_invitacion_no_queda_un_espacio_colgando():
    anterior = turno("Recuerda que puedes buscar a un adulto de confianza para hablar de esto.")
    r = responder("y luego me fui a mi casa", AF, GeneradorFijo(), historial=[anterior], modo="breve")
    assert r.texto == r.texto.strip()
    assert r.texto
