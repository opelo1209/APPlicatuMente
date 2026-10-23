"""Cuentas para el administrador: lista y borrado completo (Semana 5).

Lista. La app del administrador no tenia ninguna forma de ver las cuentas:
solo existia PUT /admin/usuarios/.../activo, sin manera de encontrar a quien
reactivar. GET /admin/usuarios las lista (sin contrasenas) y dice si la
cuenta se creo con Google.

Borrado (derecho de cancelacion, ARCO). El aviso de privacidad lo promete y
hoy solo existia desactivar. Borrar la fila del usuario no bastaba: varias
tablas guardan al usuario como (perfil_tipo, id_usuario) sin llave foranea,
asi que sus cuestionarios (incluido Columbia), sus alertas con el fragmento
que escribio, sus sesiones y sus enlaces de recuperacion se quedaban
huerfanos. borrar_cuenta() lo quita todo en UNA transaccion.

Alertas de riesgo, opcion intermedia PROVISIONAL (consulta S5, pregunta 15):
no se borran; se anonimizan. Se quita todo lo que identifica (a quien
pertenecen, el fragmento, la traza y la nota de atencion) y se conserva
«hubo una alerta de este tipo, en esta fecha, y se atendio o no». Asi la
escuela no pierde el registro de que hubo una crisis y como se atendio, y
ya no se puede ligar a nadie.

Solo el administrador borra, escribiendo el nombre de usuario para
confirmar. No es autoservicio: es un menor de edad, podria hacerlo en un
momento de crisis, y la ley permite que lo pida su tutor. Queda un registro
SIN datos personales (que perfil, cuando y quien lo borro).

Los respaldos diarios (scripts/respaldo_bd.sh) conservan 14 dias: lo
borrado desaparece de ellos a mas tardar en ese plazo (aviso de privacidad).
"""

from __future__ import annotations

import json
import logging
from typing import Any, Callable

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field

from . import limite_intentos as limite

log = logging.getLogger(__name__)

TABLAS = {"estudiante": "usuarios_estudiantes", "padre": "usuarios_padres"}
PERFIL_ANONIMO = "cuenta_borrada"
MAX_LISTA = 200


def crear_tabla(cur: Any) -> None:
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS cuentas_borradas (
            id_borrado SERIAL PRIMARY KEY,
            perfil_tipo VARCHAR(30) NOT NULL,
            borrada_por VARCHAR(120) NOT NULL,
            filas JSONB NOT NULL,
            fecha TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
        """
    )


def _contar(cur: Any) -> int:
    return cur.rowcount if cur.rowcount and cur.rowcount > 0 else 0


def borrar_cuenta(cur: Any, perfil: str, id_usuario: int) -> dict[str, int]:
    """Borra la cuenta y todos sus datos; anonimiza sus alertas. Devuelve
    cuantas filas se tocaron por tabla (sin datos personales). Lanza
    LookupError si la cuenta no existe. No hace commit."""
    tabla = TABLAS[perfil]
    cur.execute(f"SELECT nombre_usuario, correo FROM {tabla} WHERE id_usuario = %s FOR UPDATE", (id_usuario,))
    fila = cur.fetchone()
    if fila is None:
        raise LookupError(id_usuario)
    filas: dict[str, int] = {}

    # Sin llave foranea: se borran a mano.
    for nombre in ("cuestionarios_locales", "sesiones_locales", "recuperacion_tokens"):
        cur.execute(f"DELETE FROM {nombre} WHERE perfil_tipo = %s AND id_usuario = %s", (perfil, id_usuario))
        filas[nombre] = _contar(cur)
    claves = [
        limite.clave(lim, sujeto)
        for lim in (limite.LOGIN_CUENTA, limite.RECUPERACION_CUENTA)
        for sujeto in (fila["nombre_usuario"], fila["correo"])
    ]
    cur.execute("DELETE FROM intentos_acceso WHERE clave = ANY(%s)", (claves,))
    filas["intentos_acceso"] = _contar(cur)

    # Opcion intermedia: la alerta se conserva sin nada que identifique.
    cur.execute(
        """
        UPDATE alertas_riesgo
        SET perfil_tipo = %s, id_usuario = 0, evidencia = '[]', prueba = '[]', nota_atencion = NULL
        WHERE perfil_tipo = %s AND id_usuario = %s
        """,
        (PERFIL_ANONIMO, perfil, id_usuario),
    )
    filas["alertas_riesgo_anonimizadas"] = _contar(cur)

    # Con ON DELETE CASCADE: diario, vinculos con el tutor, solicitudes de
    # vinculacion y alertas a padres se van con la cuenta.
    cur.execute(f"DELETE FROM {tabla} WHERE id_usuario = %s", (id_usuario,))
    filas[tabla] = _contar(cur)
    return filas


class BorradoIn(BaseModel):
    # El administrador escribe el nombre de usuario para confirmar.
    confirmacion: str = Field(min_length=1, max_length=120)


def _cuenta(fila: dict[str, Any], perfil: str) -> dict[str, Any]:
    return {
        "perfil_tipo": perfil,
        "id_usuario": fila["id_usuario"],
        "nombre_usuario": fila["nombre_usuario"],
        "nombre_completo": " ".join(p for p in (fila["nombres"], fila["apellido_paterno"], fila["apellido_materno"]) if p),
        "correo": fila["correo"],
        "activo": fila["activo"],
        "google": str(fila["keycloack_id"]).startswith("google-"),
        "fecha_de_creacion": fila["fecha_de_creacion"].isoformat(),
        "ultima_conexion": fila["ultima_conexion"].isoformat(),
    }


def crear_router_cuentas(
    db_conn: Callable, current_user: Callable, olvidar_conversacion: Callable[[str, int], None]
) -> APIRouter:
    router = APIRouter()

    def _solo_admin(user: dict[str, Any]) -> None:
        if user["perfil_tipo"] != "administrador":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo para administradores")

    @router.get("/admin/usuarios")
    def listar_cuentas(
        perfil: str = Query(default="estudiante", pattern="^(estudiante|padre)$"),
        buscar: str = Query(default="", max_length=120),
        user: dict[str, Any] = Depends(current_user),
    ) -> dict[str, Any]:
        _solo_admin(user)
        patron = f"%{buscar.strip().lower()}%"
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    SELECT id_usuario, nombre_usuario, nombres, apellido_paterno, apellido_materno, correo,
                           activo, keycloack_id, fecha_de_creacion, ultima_conexion
                    FROM {TABLAS[perfil]}
                    WHERE lower(nombre_usuario) LIKE %s OR lower(correo) LIKE %s
                       OR lower(nombres || ' ' || apellido_paterno) LIKE %s
                    ORDER BY ultima_conexion DESC
                    LIMIT %s
                    """,
                    (patron, patron, patron, MAX_LISTA),
                )
                filas = cur.fetchall()
        return {"cuentas": [_cuenta(f, perfil) for f in filas], "limite": MAX_LISTA}

    @router.post("/admin/usuarios/{perfil}/{id_usuario}/borrar")
    def borrar(
        perfil: str, id_usuario: int, payload: BorradoIn, user: dict[str, Any] = Depends(current_user)
    ) -> dict[str, Any]:
        _solo_admin(user)
        if perfil not in TABLAS:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Solo se borran cuentas de estudiante o de tutor.")
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(f"SELECT nombre_usuario FROM {TABLAS[perfil]} WHERE id_usuario = %s", (id_usuario,))
                fila = cur.fetchone()
                if fila is None:
                    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="La cuenta no existe.")
                if payload.confirmacion.strip() != fila["nombre_usuario"]:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Para confirmar, escribe exactamente el nombre de usuario de la cuenta.",
                    )
                filas = borrar_cuenta(cur, perfil, id_usuario)
                cur.execute(
                    "INSERT INTO cuentas_borradas (perfil_tipo, borrada_por, filas) VALUES (%s, %s, %s)",
                    (perfil, user["nombre_usuario"], json.dumps(filas)),
                )
            conn.commit()
        olvidar_conversacion(perfil, id_usuario)
        # Sin datos de la cuenta borrada: solo el perfil y quien la borro.
        log.warning("cuenta de %s borrada por el administrador %s", perfil, user["id_usuario"])
        return {"borrada": True, "filas": filas}

    return router
