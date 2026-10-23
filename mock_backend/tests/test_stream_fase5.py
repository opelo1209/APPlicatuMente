"""Fase 5 del plan de mejora de Serena (Semana 3): respuesta por partes.

1. Corte temprano: en cuanto el modelo completa la oracion que se necesita,
   se le pide parar (no se esperan los 60 tokens).
2. Avance seguro: el material aprobado se muestra de inmediato (ya se
   conoce antes de llamar al modelo) y la oracion del modelo solo se manda
   DESPUES de pasar por la guardia de salida.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.serena_pipeline import responder  # noqa: E402
from tests.test_evaluador_diario import AnalizadorFalso  # noqa: E402

AF = AnalizadorFalso("negativo", "miedo")


class GeneradorPorPartes:
    nombre = "por partes"

    def __init__(self, texto):
        self.palabras = texto.split(" ")
        self.entregadas = 0
        self.empezo = False

    def generar(self, mensajes, max_tokens=None):
        return " ".join(self.palabras)

    def generar_partes(self, mensajes, max_tokens=None):
        self.empezo = True
        for i, p in enumerate(self.palabras):
            self.entregadas += 1
            yield ("" if i == 0 else " ") + p


LARGO = "Qué bueno que me lo cuentas. Y aquí sigue mucho texto que ya no se necesita para nada en esta respuesta."


def test_corta_al_completar_la_oracion_necesaria():
    g = GeneradorPorPartes(LARGO)
    r = responder("me pongo muy nervioso cuando expongo", AF, g, modo="breve")
    assert r.texto.startswith("Qué bueno que me lo cuentas.")
    assert g.entregadas < len(g.palabras)
    assert "ya no se necesita" not in r.texto


def test_el_material_se_avisa_antes_de_que_empiece_el_modelo():
    g = GeneradorPorPartes(LARGO)
    avisos = []
    r = responder("me pongo muy nervioso cuando expongo", AF, g, modo="breve",
                  al_avanzar=lambda texto: avisos.append((g.empezo, texto)))
    assert avisos[0][0] is False  # el modelo aun no empezaba
    assert "Del material del programa" in avisos[0][1]
    # Con material, la oracion del modelo es lo ultimo que falta: llega en la
    # respuesta final, arriba del material.
    assert len(avisos) == 1
    assert r.texto.startswith("Qué bueno que me lo cuentas.")


def test_sin_material_avisa_la_primera_oracion_ya_revisada():
    g = GeneradorPorPartes("Qué bueno que me escribes. ¿Qué pasó con tu amiga? Y más texto sobrante aquí.")
    avisos = []
    r = responder("me peleé con mi mejor amiga", AF, g, modo="breve", al_avanzar=avisos.append)
    # Cierre S3: primero la invitacion (ya se conoce) y luego la oracion
    # revisada, arriba de ella. Semana 5: sin invitacion, la oracion revisada
    # es lo primero que se ve.
    assert avisos[0] == "Qué bueno que me escribes."
    assert "¿Qué pasó con tu amiga?" in r.texto
    assert "sobrante" not in r.texto


def test_una_oracion_bloqueada_nunca_se_avisa():
    g = GeneradorPorPartes("Por lo que me cuentas, tienes depresión. Busca ayuda.")
    avisos = []
    r = responder("me peleé con mi mejor amiga", AF, g, modo="breve", al_avanzar=avisos.append)
    assert r.tipo == "bloqueada"
    assert not any("depresión" in a for a in avisos)


def test_crisis_y_limites_no_avisan_nada_parcial():
    avisos = []
    r = responder("quiero matarme", AF, GeneradorPorPartes(LARGO), modo="breve", al_avanzar=avisos.append)
    assert r.tipo == "crisis" and avisos == []
