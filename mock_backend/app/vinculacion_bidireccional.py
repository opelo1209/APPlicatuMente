"""Vinculacion padre/tutor <-> estudiante validada en dos sentidos.

PROTOTIPO (Semana 2): no esta conectado a ningun endpoint ni a produccion.

Hoy (main.py, /users/padres/estudiantes) cualquier adulto con cuenta de
padre se vincula a un estudiante con solo escribir su CURP. Aqui una
vinculacion solo queda activa cuando cada lado aporta algo que el otro no
puede inventar:

Sentido 1, lo inicia el estudiante (desde su perfil):
  1. Registra a su tutor: nombre completo, CURP, correo y parentesco.
  2. La app le muestra un codigo de 6 digitos (se lo dicta a su tutor) y
     notifica al tutor.
  3. El tutor, con SU cuenta, confirma escribiendo la CURP y la fecha de
     nacimiento del estudiante y el codigo. Debe coincidir ademas la CURP
     de la cuenta del tutor con la que registro el estudiante.

Sentido 2, lo inicia el tutor:
  1. Escribe la CURP y la fecha de nacimiento del estudiante.
  2. El estudiante recibe la solicitud en la app, con el nombre del tutor,
     y la acepta o la rechaza.

Protecciones: el codigo no se guarda en claro (solo su hash), maximo de
intentos y bloqueo, caducidad, y un unico mensaje de error que no dice que
dato fallo ni si la CURP existe.

Todas las funciones devuelven una Solicitud NUEVA; nunca modifican la que
reciben.
"""

from __future__ import annotations

import hashlib
import hmac
import re
import secrets
from dataclasses import dataclass, replace
from datetime import date, datetime, timedelta

ESTADO_PENDIENTE_TUTOR = "pendiente_tutor"
ESTADO_PENDIENTE_ESTUDIANTE = "pendiente_estudiante"
ESTADO_VINCULADA = "vinculada"
ESTADO_RECHAZADA = "rechazada"
ESTADO_BLOQUEADA = "bloqueada"
ESTADO_EXPIRADA = "expirada"

MAX_INTENTOS = 5
VIGENCIA = timedelta(hours=72)
_CURP = re.compile(r"^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$")
_CORREO = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class DatosNoCoinciden(Exception):
    MENSAJE = "Los datos no coinciden o la solicitud ya no es válida."

    def __init__(self, solicitud: "Solicitud | None" = None) -> None:
        super().__init__(self.MENSAJE)
        self.solicitud = solicitud  # con el intento ya contado


@dataclass(frozen=True)
class Estudiante:
    id: int
    curp: str
    fecha_nacimiento: date


@dataclass(frozen=True)
class Tutor:
    id: int
    curp: str
    nombre: str
    correo: str


@dataclass(frozen=True)
class DatosTutor:
    """Lo que escribe el estudiante sobre su tutor."""

    nombre: str
    curp: str
    correo: str
    parentesco: str


@dataclass(frozen=True)
class Solicitud:
    id_estudiante: int
    estado: str
    iniciada_por: str  # "estudiante" | "tutor"
    creada: datetime
    parentesco: str
    curp_tutor: str
    nombre_tutor: str
    correo_tutor: str
    id_tutor: int | None = None
    hash_codigo: str = ""
    intentos: int = 0


def normalizar_curp(curp: str) -> str:
    return curp.strip().upper()


def _validar_curp(curp: str) -> str:
    curp = normalizar_curp(curp)
    if not _CURP.match(curp):
        raise ValueError("CURP con formato no valido")
    return curp


def _hash(codigo: str) -> str:
    return hashlib.sha256(codigo.encode()).hexdigest()


def _vigente(solicitud: Solicitud, ahora: datetime) -> bool:
    return ahora - solicitud.creada <= VIGENCIA


def solicitar_desde_estudiante(
    estudiante: Estudiante, datos: DatosTutor, ahora: datetime
) -> tuple[Solicitud, str]:
    """Devuelve la solicitud y el codigo EN CLARO, que solo se muestra una
    vez al estudiante. La base de datos guarda la solicitud (con el hash)."""
    nombre = " ".join(datos.nombre.split())
    if len(nombre) < 3:
        raise ValueError("falta el nombre completo del tutor")
    if not _CORREO.match(datos.correo.strip()):
        raise ValueError("correo del tutor no valido")
    codigo = f"{secrets.randbelow(1_000_000):06d}"
    solicitud = Solicitud(
        id_estudiante=estudiante.id,
        estado=ESTADO_PENDIENTE_TUTOR,
        iniciada_por="estudiante",
        creada=ahora,
        parentesco=datos.parentesco.strip() or "padre/madre/tutor",
        curp_tutor=_validar_curp(datos.curp),
        nombre_tutor=nombre,
        correo_tutor=datos.correo.strip().lower(),
        hash_codigo=_hash(codigo),
    )
    return solicitud, codigo


def confirmar_por_tutor(
    solicitud: Solicitud,
    tutor: Tutor,
    estudiante: Estudiante,
    curp_estudiante: str,
    fecha_nacimiento: date,
    codigo: str,
    ahora: datetime,
) -> Solicitud:
    if solicitud.estado != ESTADO_PENDIENTE_TUTOR:
        raise DatosNoCoinciden(solicitud)
    if not _vigente(solicitud, ahora):
        raise DatosNoCoinciden(replace(solicitud, estado=ESTADO_EXPIRADA))

    # Se revisan TODOS los datos aunque uno ya haya fallado, y se compara el
    # codigo en tiempo constante: el tiempo de respuesta no debe delatar
    # cual dato estaba mal.
    coincide = all(
        (
            solicitud.id_estudiante == estudiante.id,
            normalizar_curp(tutor.curp) == solicitud.curp_tutor,
            normalizar_curp(curp_estudiante) == estudiante.curp,
            fecha_nacimiento == estudiante.fecha_nacimiento,
            hmac.compare_digest(_hash(codigo.strip()), solicitud.hash_codigo),
        )
    )
    if not coincide:
        intentos = solicitud.intentos + 1
        estado = ESTADO_BLOQUEADA if intentos >= MAX_INTENTOS else solicitud.estado
        raise DatosNoCoinciden(replace(solicitud, intentos=intentos, estado=estado))

    return replace(solicitud, estado=ESTADO_VINCULADA, id_tutor=tutor.id, hash_codigo="")


def solicitar_desde_tutor(
    tutor: Tutor,
    estudiante: Estudiante | None,
    curp_estudiante: str,
    fecha_nacimiento: date,
    parentesco: str,
    ahora: datetime,
) -> Solicitud:
    """estudiante es None si la CURP no existe. La API debe responder lo
    mismo en ambos casos ("si los datos son correctos, el estudiante vera la
    solicitud") para no revelar que CURP estan registradas."""
    if (
        estudiante is None
        or normalizar_curp(curp_estudiante) != estudiante.curp
        or fecha_nacimiento != estudiante.fecha_nacimiento
    ):
        raise DatosNoCoinciden()
    return Solicitud(
        id_estudiante=estudiante.id,
        estado=ESTADO_PENDIENTE_ESTUDIANTE,
        iniciada_por="tutor",
        creada=ahora,
        parentesco=parentesco.strip() or "padre/madre/tutor",
        curp_tutor=normalizar_curp(tutor.curp),
        nombre_tutor=tutor.nombre,
        correo_tutor=tutor.correo,
        id_tutor=tutor.id,
    )


def responder_estudiante(solicitud: Solicitud, estudiante: Estudiante, acepta: bool, ahora: datetime) -> Solicitud:
    if solicitud.id_estudiante != estudiante.id:
        raise PermissionError("esta solicitud es para otro estudiante")
    if solicitud.estado != ESTADO_PENDIENTE_ESTUDIANTE:
        raise ValueError(f"la solicitud ya no esta pendiente (estado: {solicitud.estado})")
    if not _vigente(solicitud, ahora):
        return replace(solicitud, estado=ESTADO_EXPIRADA)
    return replace(solicitud, estado=ESTADO_VINCULADA if acepta else ESTADO_RECHAZADA)
