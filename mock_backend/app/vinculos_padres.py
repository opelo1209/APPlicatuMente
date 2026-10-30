"""Busqueda de estudiantes por CURP y vinculo padre-estudiante.

Semana 6: salio de main.py sin cambios.
"""

from __future__ import annotations

from typing import Any

from fastapi import HTTPException, status

from .perfiles import serialize, user_to_dict


def normalize_curp(curp: str) -> str:
    return curp.strip().upper()


def ensure_curp_is_unique(cur: Any, curp: str) -> None:
    normalized = normalize_curp(curp)
    if not normalized:
        return

    cur.execute(
        """
        SELECT 1
        FROM usuarios_estudiantes
        WHERE curp = %s
        LIMIT 1
        """,
        (normalized,),
    )
    if cur.fetchone():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El CURP ya esta registrado",
        )


def find_student_by_curp(cur: Any, curp: str) -> dict[str, Any]:
    normalized = normalize_curp(curp)
    cur.execute(
        """
        SELECT *
        FROM usuarios_estudiantes
        WHERE curp = %s
        LIMIT 1
        """,
        (normalized,),
    )
    student = cur.fetchone()
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Estudiante con CURP {normalized} no encontrado",
        )
    return student


def ensure_students_curps_exist(cur: Any, curps: list[str]) -> None:
    for curp in curps:
        find_student_by_curp(cur, curp)


def list_parent_students(cur: Any, id_padre: int) -> list[dict[str, Any]]:
    cur.execute(
        """
        SELECT
            pe.id_relacion,
            pe.parentesco,
            pe.fecha_vinculacion,
            e.id_usuario,
            e.keycloack_id,
            e.nombre_usuario,
            e.correo,
            e.curp,
            e.nombres,
            e.apellido_paterno,
            e.apellido_materno,
            e.activo,
            e.fecha_de_creacion,
            e.ultima_conexion
        FROM padre_estudiante pe
        JOIN usuarios_estudiantes e ON e.id_usuario = pe.id_estudiante
        WHERE pe.id_padre = %s
        ORDER BY e.nombres, e.apellido_paterno
        """,
        (id_padre,),
    )
    result = []
    for row in cur.fetchall():
        student = user_to_dict(row, "estudiante")
        student.pop("id_usuario", None)
        student.pop("keycloack_id", None)
        student.pop("id_relacion", None)
        result.append({
            **student,
            "parentesco": row["parentesco"],
            "fecha_vinculacion": serialize(row["fecha_vinculacion"]),
        })
    return result


def link_parent_to_student(cur: Any, id_padre: int, id_estudiante: int, parentesco: str) -> dict[str, Any]:
    cur.execute("SELECT 1 FROM usuarios_padres WHERE id_usuario = %s", (id_padre,))
    if not cur.fetchone():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Padre no encontrado")

    cur.execute(
        """
        INSERT INTO padre_estudiante (id_padre, id_estudiante, parentesco)
        VALUES (%s, %s, %s)
        ON CONFLICT (id_padre, id_estudiante)
        DO UPDATE SET parentesco = EXCLUDED.parentesco
        RETURNING *
        """,
        (id_padre, id_estudiante, parentesco),
    )
    return {key: serialize(value) for key, value in cur.fetchone().items()}


def link_parent_to_student_by_curp(cur: Any, id_padre: int, curp: str, parentesco: str) -> dict[str, Any]:
    student = find_student_by_curp(cur, curp)
    return link_parent_to_student(cur, id_padre, student["id_usuario"], parentesco)
