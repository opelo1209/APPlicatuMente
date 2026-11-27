"""Endpoints del administrador: monitoreo de respuestas y editor de
cuestionarios.

Se arma con crear_router_admin(...) recibiendo la conexion y el usuario
actual de main.py.

Semana 6: salio de main.py sin cambios.
"""

from __future__ import annotations

from typing import Any, Callable

from fastapi import APIRouter, Depends, HTTPException, status

from .config_cuestionarios import list_question_configs
from .modelos_api import QuestionConfigUpdate
from .perfiles import PROFILE_TABLES, ROLE_CAPABILITIES, serialize


def list_questionnaires_by_profile(cur: Any, profile: str) -> list[dict[str, Any]]:
    table = PROFILE_TABLES[profile]
    cur.execute(
        f"""
        SELECT
            q.id_sesion,
            q.id_usuario,
            q.perfil_tipo,
            q.tipo_cuestionario,
            q.respuestas,
            q.completado,
            q.fecha_registro,
            u.nombre_usuario,
            u.correo,
            u.nombres,
            u.apellido_paterno,
            u.apellido_materno
        FROM cuestionarios_locales q
        JOIN {table} u ON u.id_usuario = q.id_usuario
        WHERE q.perfil_tipo = %s
        ORDER BY q.fecha_registro DESC
        """,
        (profile,),
    )

    rows = []
    for row in cur.fetchall():
        data = {key: serialize(value) for key, value in row.items()}
        data["fecha_de_registro"] = data.pop("fecha_registro")
        data["nombre_completo"] = " ".join(
            part
            for part in [
                data.get("nombres"),
                data.get("apellido_paterno"),
                data.get("apellido_materno"),
            ]
            if part
        )
        rows.append(data)
    return rows


def crear_router_admin(db_conn: Callable[..., Any], current_user: Callable[..., Any]) -> APIRouter:
    router = APIRouter()

    @router.get("/admin/monitoreo")
    def admin_monitoring(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
        if user["perfil_tipo"] != "administrador":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Solo administradores pueden monitorear respuestas",
            )

        with db_conn() as conn:
            with conn.cursor() as cur:
                estudiantes = list_questionnaires_by_profile(cur, "estudiante")
                padres = list_questionnaires_by_profile(cur, "padre")

        return {
            "estudiantes": estudiantes,
            "padres": padres,
            "total": len(estudiantes) + len(padres),
        }


    @router.get("/admin/cuestionarios")
    def admin_question_configs(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
        if not ROLE_CAPABILITIES[user["perfil_tipo"]]["can_edit_questionnaires"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Solo administradores pueden editar cuestionarios",
            )

        with db_conn() as conn:
            with conn.cursor() as cur:
                preguntas = list_question_configs(cur)

        return {"preguntas": preguntas, "total": len(preguntas)}


    @router.put("/admin/cuestionarios/{id_pregunta}")
    def update_admin_question_config(
        id_pregunta: int,
        payload: QuestionConfigUpdate,
        user: dict[str, Any] = Depends(current_user),
    ) -> dict[str, Any]:
        if not ROLE_CAPABILITIES[user["perfil_tipo"]]["can_edit_questionnaires"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Solo administradores pueden editar cuestionarios",
            )

        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE cuestionarios_config
                    SET pregunta = %s,
                        puntaje = %s,
                        activo = %s,
                        fecha_actualizacion = NOW()
                    WHERE id_pregunta = %s
                    RETURNING
                        id_pregunta,
                        modulo_key,
                        modulo,
                        bloque,
                        codigo,
                        tipo_respuesta,
                        numero,
                        pregunta,
                        puntaje,
                        activo,
                        fecha_actualizacion
                    """,
                    (payload.pregunta, payload.puntaje, payload.activo, id_pregunta),
                )
                updated = cur.fetchone()
                if not updated:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="Pregunta no encontrada",
                    )
            conn.commit()

        return {
            "message": "Pregunta actualizada en Postgres temporal",
            "pregunta": {key: serialize(value) for key, value in updated.items()},
        }

    return router
