"""Endpoints del padre o tutor: sus alertas y sus estudiantes vinculados.

Igual que prototipo_api.py, se arma con crear_router_padres(...)
recibiendo la conexion y el usuario actual de main.py, para no crear una
importacion circular.

Semana 6: salio de main.py sin cambios.
"""

from __future__ import annotations

from typing import Any, Callable

from fastapi import APIRouter, Depends, HTTPException, status

from .alertas_padres import list_parent_alerts
from .modelos_api import VincularEstudiante
from .perfiles import serialize
from .vinculos_padres import find_student_by_curp, list_parent_students


def crear_router_padres(db_conn: Callable[..., Any], current_user: Callable[..., Any]) -> APIRouter:
    router = APIRouter()

    @router.get("/users/padres/alertas")
    def parent_alerts(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
        if user["perfil_tipo"] != "padre":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo padres pueden consultar alertas")

        with db_conn() as conn:
            with conn.cursor() as cur:
                alertas = list_parent_alerts(cur, user["id_usuario"])
            conn.commit()

        return {
            "message": "Alertas consultadas exitosamente",
            "alertas": alertas,
            "total": len(alertas),
            "no_leidas": sum(1 for alerta in alertas if not alerta["leida"]),
        }


    @router.put("/users/padres/alertas/{id_alerta}/vista")
    def mark_parent_alert_seen(
        id_alerta: int,
        user: dict[str, Any] = Depends(current_user),
    ) -> dict[str, Any]:
        if user["perfil_tipo"] != "padre":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo padres pueden actualizar alertas")

        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE alertas_padres
                    SET leida = TRUE,
                        fecha_lectura = COALESCE(fecha_lectura, NOW())
                    WHERE id_alerta = %s AND id_padre = %s
                    RETURNING *
                    """,
                    (id_alerta, user["id_usuario"]),
                )
                alerta = cur.fetchone()
                if not alerta:
                    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alerta no encontrada")
            conn.commit()

        return {
            "message": "Alerta marcada como vista",
            "alerta": {key: serialize(value) for key, value in alerta.items()},
        }

    @router.post("/users/padres/estudiantes")
    def link_student(
        payload: VincularEstudiante,
        user: dict[str, Any] = Depends(current_user),
    ) -> dict[str, Any]:
        if user["perfil_tipo"] != "padre":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo padres pueden vincular estudiantes")

        # PROTOTIPO Semana 2: la vinculacion directa por CURP queda cerrada; se
        # usa la vinculacion en dos sentidos (POST /vinculacion/tutor/solicitudes).
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail="La vinculación ahora requiere la confirmación del estudiante. Usa «Vincular a mi hijo».",
        )


    @router.get("/users/padres/estudiantes")
    def get_linked_students(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
        if user["perfil_tipo"] != "padre":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo padres pueden consultar estudiantes")

        with db_conn() as conn:
            with conn.cursor() as cur:
                linked = list_parent_students(cur, user["id_usuario"])
        return {"id_padre": user["id_usuario"], "estudiantes_vinculados": linked}


    @router.delete("/users/padres/estudiantes/{curp}")
    def unlink_student(
        curp: str,
        user: dict[str, Any] = Depends(current_user),
    ) -> dict[str, Any]:
        if user["perfil_tipo"] != "padre":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo padres pueden desvincular estudiantes")

        with db_conn() as conn:
            with conn.cursor() as cur:
                student = find_student_by_curp(cur, curp)
                id_estudiante = student["id_usuario"]
                cur.execute(
                    """
                    DELETE FROM alertas_padres
                    WHERE id_padre = %s AND id_estudiante = %s
                    """,
                    (user["id_usuario"], id_estudiante),
                )
                cur.execute(
                    """
                    DELETE FROM padre_estudiante
                    WHERE id_padre = %s AND id_estudiante = %s
                    RETURNING id_relacion
                    """,
                    (user["id_usuario"], id_estudiante),
                )
                deleted = cur.fetchone()
                if not deleted:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="El estudiante no está vinculado a este padre",
                    )
                linked = list_parent_students(cur, user["id_usuario"])
            conn.commit()

        return {
            "message": "Estudiante desvinculado exitosamente",
            "estudiantes_vinculados": linked,
        }

    return router
