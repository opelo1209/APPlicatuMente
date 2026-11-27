"""Semana 9: respuestas de la Dra. Gonzalez a la revision del 9 de noviembre
(Revision_para_la_Dra_Gonzalez.pdf, devuelto el 17 de noviembre).

Pregunta nueva 5: «A veces el chatbot dice "no te preocupes" a quien conto
algo malo. ¿Lo consideran minimizar?». Respondio: «¿Antes de esta respuesta
se valida la emocion?». Serena solo valida antes cuando el mensaje es
claramente negativo, asi que la frase no se muestra.
"""

import pytest

from app.guardia_salida import aplicar_guardia, hechos_de_salida
from app.serena_pipeline import responder
from tests.test_evaluador_diario import AnalizadorFalso
from tests.test_serena_pipeline import GeneradorFalso


@pytest.mark.parametrize(
    "texto",
    [
        "No te preocupes, todo va a salir bien.",
        "Gracias por contarme. No te preocupes por eso.",
        "no te preocupes",
    ],
)
def test_no_te_preocupes_cuenta_como_minimizar(texto):
    assert "minimiza" in hechos_de_salida(texto, False)
    assert not aplicar_guardia(texto, False).mostrable


@pytest.mark.parametrize(
    "texto",
    ["Me preocupa cómo te sientes.", "Es normal preocuparse antes de un examen.", "¿Qué te preocupa?"],
)
def test_hablar_de_preocupacion_no_es_minimizar(texto):
    assert "minimiza" not in hechos_de_salida(texto, False)


def test_serena_no_muestra_no_te_preocupes_aunque_el_modelo_lo_escriba():
    r = responder(
        "me fue mal en el examen de química",
        AnalizadorFalso("negativo", "tristeza"),
        GeneradorFalso("No te preocupes, a todos nos pasa."),
    )
    assert "preocupes" not in r.texto.lower(), r.texto
    assert r.texto  # Serena no se queda callada
