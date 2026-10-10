"""Pruebas de la vinculacion padre/tutor <-> estudiante en dos sentidos
(app/vinculacion_bidireccional.py).

Problema que corrige (reporte Semana 2, revision inicial): hoy cualquier
adulto se vincula como padre de un estudiante con solo su CURP. Aqui una
vinculacion solo queda activa cuando AMBOS lados aportan algo que el otro
no puede inventar.

Correr con:  python -m pytest mock_backend/tests/test_vinculacion_bidireccional.py -v
"""

import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.vinculacion_bidireccional import (  # noqa: E402
    ESTADO_BLOQUEADA,
    ESTADO_EXPIRADA,
    ESTADO_PENDIENTE_ESTUDIANTE,
    ESTADO_PENDIENTE_TUTOR,
    ESTADO_RECHAZADA,
    ESTADO_VINCULADA,
    MAX_INTENTOS,
    DatosNoCoinciden,
    DatosTutor,
    Estudiante,
    Tutor,
    confirmar_por_tutor,
    responder_estudiante,
    solicitar_desde_estudiante,
    solicitar_desde_tutor,
)

AHORA = datetime(2026, 10, 2, 12, 0, tzinfo=timezone.utc)
ANA = Estudiante(id=7, curp="ROAA100512MDFXXX01", fecha_nacimiento=date(2010, 5, 12))
LUIS = Tutor(id=3, curp="ROPL800101HDFXXX02", nombre="Luis Rodríguez Pérez", correo="luis@example.com")
OTRO = Tutor(id=9, curp="XXXX800101HDFXXX09", nombre="Alguien Más", correo="otro@example.com")
DATOS_LUIS = DatosTutor(nombre="Luis Rodríguez Pérez", curp="ropl800101hdfxxx02 ", correo="luis@example.com", parentesco="padre")


# --------------------------------------------------------------------------
# Sentido 1: lo inicia el estudiante, lo confirma el tutor
# --------------------------------------------------------------------------


def nueva_desde_estudiante():
    return solicitar_desde_estudiante(ANA, DATOS_LUIS, AHORA)


def test_estudiante_registra_a_su_tutor_y_queda_pendiente():
    solicitud, codigo = nueva_desde_estudiante()
    assert solicitud.estado == ESTADO_PENDIENTE_TUTOR
    assert len(codigo) == 6 and codigo.isdigit()
    assert codigo not in repr(solicitud), "el codigo no se guarda en claro"


def test_tutor_confirma_con_datos_del_hijo_y_codigo():
    solicitud, codigo = nueva_desde_estudiante()
    final = confirmar_por_tutor(solicitud, LUIS, ANA, ANA.curp, ANA.fecha_nacimiento, codigo, AHORA)
    assert final.estado == ESTADO_VINCULADA
    assert final.id_tutor == LUIS.id


def test_otro_adulto_no_puede_confirmar_aunque_sepa_todo():
    # Aunque conozca CURP, fecha y codigo: su propia CURP no es la que el
    # estudiante registro.
    solicitud, codigo = nueva_desde_estudiante()
    with pytest.raises(DatosNoCoinciden):
        confirmar_por_tutor(solicitud, OTRO, ANA, ANA.curp, ANA.fecha_nacimiento, codigo, AHORA)


@pytest.mark.parametrize(
    "curp, fecha, codigo_ok",
    [
        ("ROAA100512MDFXXX99", date(2010, 5, 12), True),
        ("ROAA100512MDFXXX01", date(2010, 5, 13), True),
        ("ROAA100512MDFXXX01", date(2010, 5, 12), False),
    ],
)
def test_cualquier_dato_mal_falla_con_el_mismo_error(curp, fecha, codigo_ok):
    solicitud, codigo = nueva_desde_estudiante()
    usado = codigo if codigo_ok else str((int(codigo) + 1) % 1_000_000).zfill(6)
    with pytest.raises(DatosNoCoinciden) as error:
        confirmar_por_tutor(solicitud, LUIS, ANA, curp, fecha, usado, AHORA)
    # El mensaje no dice QUE dato fallo (no ayuda a adivinar).
    assert str(error.value) == DatosNoCoinciden.MENSAJE
    assert error.value.solicitud.intentos == 1


def test_se_bloquea_tras_demasiados_intentos():
    solicitud, codigo = nueva_desde_estudiante()
    for _ in range(MAX_INTENTOS):
        with pytest.raises(DatosNoCoinciden) as error:
            confirmar_por_tutor(solicitud, LUIS, ANA, ANA.curp, ANA.fecha_nacimiento, "000000" if codigo != "000000" else "111111", AHORA)
        solicitud = error.value.solicitud
    assert solicitud.estado == ESTADO_BLOQUEADA
    # Ya bloqueada, ni el codigo correcto sirve.
    with pytest.raises(DatosNoCoinciden):
        confirmar_por_tutor(solicitud, LUIS, ANA, ANA.curp, ANA.fecha_nacimiento, codigo, AHORA)


def test_la_solicitud_expira():
    solicitud, codigo = nueva_desde_estudiante()
    tarde = AHORA + timedelta(hours=73)
    with pytest.raises(DatosNoCoinciden) as error:
        confirmar_por_tutor(solicitud, LUIS, ANA, ANA.curp, ANA.fecha_nacimiento, codigo, tarde)
    assert error.value.solicitud.estado == ESTADO_EXPIRADA


def test_las_solicitudes_son_inmutables():
    solicitud, _ = nueva_desde_estudiante()
    with pytest.raises(AttributeError):
        solicitud.estado = ESTADO_VINCULADA  # type: ignore[misc]


@pytest.mark.parametrize(
    "datos",
    [
        DatosTutor(nombre="", curp=LUIS.curp, correo=LUIS.correo, parentesco="padre"),
        DatosTutor(nombre="Luis", curp="CURP-MALA", correo=LUIS.correo, parentesco="padre"),
        DatosTutor(nombre="Luis", curp=LUIS.curp, correo="no-es-correo", parentesco="padre"),
    ],
)
def test_datos_del_tutor_se_validan(datos):
    with pytest.raises(ValueError):
        solicitar_desde_estudiante(ANA, datos, AHORA)


# --------------------------------------------------------------------------
# Sentido 2: lo inicia el tutor, lo acepta el estudiante
# --------------------------------------------------------------------------


def test_tutor_solicita_y_estudiante_acepta():
    solicitud = solicitar_desde_tutor(LUIS, ANA, ANA.curp, ANA.fecha_nacimiento, "madre", AHORA)
    assert solicitud.estado == ESTADO_PENDIENTE_ESTUDIANTE
    final = responder_estudiante(solicitud, ANA, acepta=True, ahora=AHORA)
    assert final.estado == ESTADO_VINCULADA


def test_estudiante_puede_rechazar():
    solicitud = solicitar_desde_tutor(LUIS, ANA, ANA.curp, ANA.fecha_nacimiento, "padre", AHORA)
    final = responder_estudiante(solicitud, ANA, acepta=False, ahora=AHORA)
    assert final.estado == ESTADO_RECHAZADA


def test_tutor_con_fecha_equivocada_no_genera_solicitud():
    with pytest.raises(DatosNoCoinciden):
        solicitar_desde_tutor(LUIS, ANA, ANA.curp, date(2011, 1, 1), "padre", AHORA)


def test_solo_el_estudiante_correcto_responde():
    solicitud = solicitar_desde_tutor(LUIS, ANA, ANA.curp, ANA.fecha_nacimiento, "padre", AHORA)
    otro_estudiante = Estudiante(id=8, curp="XXXX100512MDFXXX08", fecha_nacimiento=date(2010, 5, 12))
    with pytest.raises(PermissionError):
        responder_estudiante(solicitud, otro_estudiante, acepta=True, ahora=AHORA)


def test_no_se_responde_dos_veces():
    solicitud = solicitar_desde_tutor(LUIS, ANA, ANA.curp, ANA.fecha_nacimiento, "padre", AHORA)
    final = responder_estudiante(solicitud, ANA, acepta=True, ahora=AHORA)
    with pytest.raises(ValueError):
        responder_estudiante(final, ANA, acepta=False, ahora=AHORA)
