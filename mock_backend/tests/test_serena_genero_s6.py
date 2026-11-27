"""Semana 6 (comparacion en Kaggle): los 8 descartes de Qwen2.5 7B fueron de
genero («Entiendo que te sientes nervioso»). En vez de tirar la oracion,
se reescribe en neutro cuando el adjetivo tiene un sustantivo claro
(«sientes nervios»). Tambien: S17 no veia «no estas tan feliz» y S12 no
veia «¿como estuvo su dia?». Las frases son respuestas reales de Qwen.
"""

import pytest

from app.guardia_salida import aplicar_guardia, hechos_de_salida, neutralizar_genero
from app.serena_pipeline import responder
from tests.test_evaluador_diario import AnalizadorFalso
from tests.test_serena_pipeline import GeneradorFalso

NEUTRO = AnalizadorFalso("neutro")


@pytest.mark.parametrize(
    "original,neutro",
    [
        ("Entiendo que te sientes nervioso al exponer.", "Entiendo que sientes nervios al exponer."),
        ("Entiendo que te sientes muy enojado.", "Entiendo que sientes mucho enojo."),
        ("Entiendo que te sientes estresado por los exámenes.", "Entiendo que sientes estrés por los exámenes."),
        ("Entiendo que te sientes frustrado por no poder salir.", "Entiendo que sientes frustración por no poder salir."),
        ("Entiendo que te sientes abrumado con tanta tarea.", "Entiendo que sientes agobio con tanta tarea."),
        ("Entiendo que te sientes presionado.", "Entiendo que sientes presión."),
        ("entiendo que te sientas solo, ¿qué pasó?", "entiendo que sientas soledad, ¿qué pasó?"),
        ("entiendo que te sientas nervioso/a, cuéntame.", "entiendo que sientas nervios, cuéntame."),
        ("¿Te sientes nerviosa?", "¿Sientes nervios?"),
        ("Es válido sentirte tan preocupado.", "Es válido sentir tanta preocupación."),
        ("Te sentiste un poco triste y cansado.", "Te sentiste un poco triste y cansado."),
    ],
)
def test_reescribe_en_neutro_los_adjetivos_conocidos(original, neutro):
    assert neutralizar_genero(original) == neutro


@pytest.mark.parametrize(
    "texto",
    ["Gracias por contármelo.", "¿Cómo te sientes hoy?", "Te sientes triste.", "Sientes nervios antes del examen."],
)
def test_lo_neutro_no_cambia(texto):
    assert neutralizar_genero(texto) == texto


def test_la_guardia_muestra_la_version_neutra_en_vez_de_descartarla():
    g = aplicar_guardia("Entiendo que te sientes nervioso al exponer.", False, entrada_negativa=True)
    assert g.mostrable
    assert g.texto == "Entiendo que sientes nervios al exponer."
    assert "supone_genero" not in g.hechos


def test_un_adjetivo_sin_sustantivo_claro_se_sigue_descartando():
    g = aplicar_guardia("¿Te sientes cómodo con esa idea?", False)
    assert not g.mostrable
    assert "supone_genero" in g.hechos


def test_en_la_conversacion_se_ve_la_version_neutra():
    vistas = []
    r = responder(
        "me da nervios exponer mañana",
        AnalizadorFalso("negativo", "miedo"),
        GeneradorFalso("Entiendo que te sientes nervioso al exponer."),
        al_avanzar=vistas.append,
    )
    assert "sientes nervios" in r.texto, r.texto
    # Solo la oracion del modelo: el material aprobado se cita tal cual (su
    # «Sentirte nervioso o inquieto» se consulta con la Dra. Gonzalez).
    assert all("te sientes nervioso" not in v for v in vistas), vistas


# ------------------------------ S17 y S12 -----------------------------------


def test_s17_ve_no_estas_tan_feliz():
    assert "supone_malestar" in hechos_de_salida("Entiendo que sientes que no estás tan feliz.", False)
    assert "supone_malestar" in hechos_de_salida("Parece que no te sientes muy bien hoy.", False)
    assert "supone_malestar" not in hechos_de_salida("Me alegra que estés bien.", False)


@pytest.mark.parametrize("texto", ["¡Hola! ¿Cómo estuvo su día?", "¿Cómo le fue en su examen?"])
def test_s12_ve_su_dia(texto):
    assert "trata_de_usted" in hechos_de_salida(texto, False)


def test_s12_no_confunde_el_su_de_otra_persona():
    assert "trata_de_usted" not in hechos_de_salida("¿Y tu mamá cómo pasó su día?", False)


def test_el_prompt_no_trae_un_ejemplo_de_emocion_que_el_modelo_copie():
    # Corrida 2 en Kaggle: con «sientes nervios» en el prompt, el 7B dijo
    # «Sientes nervios» a quien se sentia solo o preguntaba por vapear.
    from app.serena_pipeline import PROMPT_SERENA

    assert "nervios" not in PROMPT_SERENA


def test_s15_ve_podrias_intentar():
    texto = "¿Podrías intentar respirar profundo y contar hasta diez antes de reaccionar?"
    assert "aconseja" in hechos_de_salida(texto, False, breve=True)
