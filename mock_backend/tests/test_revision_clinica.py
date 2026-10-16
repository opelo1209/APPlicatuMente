"""Cierre de la Semana 3: la revision clinica de la Dra. Gonzalez (9 oct)
conectada a Serena.

Cada texto del corpus lleva su estado de revision; el chat lo muestra junto
a la fuente, prefiere los aprobados cuando la relevancia empata, y solo se
aplican las correcciones que no requieren aclaracion con la doctora.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.recuperador_corpus import recuperar  # noqa: E402
from app.revision_clinica import (  # noqa: E402
    CORRECCIONES_APLICADAS,
    ESTADO_APROBADO,
    ESTADO_CAMBIOS,
    ESTADO_CORREGIDO,
    ESTADO_PENDIENTE,
    ESTADO_RECHAZADO,
    RUTA_REVISION,
    revision_de,
)


def test_estados_tomados_de_la_revision():
    assert revision_de("ansiedad.teenImgQueEs.adolescente").estado == ESTADO_APROBADO
    assert revision_de("ansiedad.teenImgAdvertencia.adolescente").estado == ESTADO_CAMBIOS
    assert revision_de("sustancias.brainContent.adolescente").estado == ESTADO_APROBADO
    assert revision_de("ansiedad.teenImgDiagnostico.adolescente").estado == ESTADO_PENDIENTE
    assert revision_de("suicidio.quimicaDesc.adolescente").estado == ESTADO_RECHAZADO


def test_un_texto_rechazado_no_lleva_texto_corregido():
    assert revision_de("autolesiones.teenImgQueHacer.adolescente").texto_corregido is None


def test_serena_nunca_cita_un_texto_rechazado(monkeypatch):
    # Hoy los modulos de suicidio y autolesion no se usan en el chat; aunque
    # se incluyeran, un texto que psicologia rechazo no se puede citar.
    from app import recuperador_corpus

    recuperador_corpus._indice.cache_clear()
    try:
        ids = {d["id"] for d in recuperador_corpus._indice().documentos}
    finally:
        recuperador_corpus._indice.cache_clear()
    rechazados = {"suicidio.quimicaDesc.adolescente", "autolesiones.actionContent.adolescente"}
    assert not ids & rechazados


def test_un_texto_que_no_esta_en_la_revision_queda_pendiente():
    assert revision_de("no.existe.adolescente").estado == ESTADO_PENDIENTE


def test_aprobado_lleva_revisor_y_fecha():
    r = revision_de("ansiedad.teenImgQueEs.adolescente")
    assert r.revisor == "Nadia Gonzalez"
    assert r.fecha == "2026-10-09"


def test_la_copia_en_el_servidor_no_guarda_la_cedula():
    datos = json.loads(RUTA_REVISION.read_text(encoding="utf-8"))
    assert "cedula" not in json.dumps(datos)


def test_ninguna_referencia_apunta_al_navegador_de_la_revisora():
    datos = json.loads(RUTA_REVISION.read_text(encoding="utf-8"))
    assert all(not (i.get("referencia") or "").startswith("moz-extension") for i in datos["contenido"])


def test_solo_se_aplica_la_correccion_de_la_tcc():
    # Las demas (los "6 meses", la lista de sintomas para padres) se
    # aclaran antes con la doctora.
    assert CORRECCIONES_APLICADAS == frozenset({
        "ansiedad.teenImgTerapia.adolescente",
        "ansiedad.parentTherapyContent.familia",
    })


def test_el_chat_cita_el_texto_corregido():
    frs = recuperar("me da pena ir a terapia con un psicologo", k=3)
    terapia = [f for f in frs if f.id == "ansiedad.teenImgTerapia.adolescente"]
    assert terapia, [f.id for f in frs]
    assert "Terapia Cognitivo Conductual" in terapia[0].texto
    assert terapia[0].revision == ESTADO_CORREGIDO


def test_una_correccion_pendiente_de_aclarar_no_cambia_el_texto():
    frs = recuperar("tengo mucho miedo y nervios todo el tiempo", k=10)
    advertencia = [f for f in frs if f.id == "ansiedad.teenImgAdvertencia.adolescente"]
    assert advertencia
    assert "6 meses" not in advertencia[0].texto
    assert advertencia[0].revision == ESTADO_CAMBIOS


def test_cada_fragmento_trae_su_estado():
    # Segunda entrega (13 oct): Sustancias quedo aprobado completo.
    for f in recuperar("mis amigos vapean en la escuela", k=3):
        assert f.revision == revision_de(f.id).estado == ESTADO_APROBADO


def test_con_la_misma_relevancia_gana_el_aprobado():
    # Sin palabras en comun con ningun texto, todos los de Ansiedad empatan
    # en 0: el primero debe ser uno aprobado.
    frs = recuperar("ansiedad", k=10)
    empatados = [f for f in frs if f.puntaje == frs[0].puntaje]
    if len(empatados) > 1:
        assert frs[0].revision == ESTADO_APROBADO


def test_las_fuentes_del_chat_dicen_si_psicologia_las_reviso():
    from app.serena_pipeline import responder
    from tests.test_evaluador_diario import AnalizadorFalso
    from tests.test_serena_pipeline import GeneradorFalso

    r = responder(
        "me pongo muy nervioso cuando expongo",
        AnalizadorFalso("negativo", "miedo"),
        GeneradorFalso("Entiendo que te pongas nervioso al exponer."),
        modo="breve",
    )
    assert r.fuentes
    for fuente in r.fuentes:
        assert fuente["revision"] in (ESTADO_APROBADO, ESTADO_CORREGIDO, ESTADO_CAMBIOS, ESTADO_PENDIENTE)
        if fuente["revision"] == ESTADO_APROBADO:
            assert fuente["revisor"] == "Nadia Gonzalez"
