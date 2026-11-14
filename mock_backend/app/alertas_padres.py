"""Alertas a padres y tutores a partir de los cuestionarios del
estudiante, con los niveles de Columbia (Semana 4).

Semana 6: salio de main.py sin cambios.
"""

from __future__ import annotations

from typing import Any

from .niveles_columbia import COMUNITARIO as NIVEL_COMUNITARIO
from .niveles_columbia import (
    DIRECTORIO_CECOSAMA,
    RECURSO_COMUNITARIO,
    RECURSO_URGENTE,
    contacto_urgente,
    nivel_atencion,
    nivel_columbia,
)
from .niveles_columbia import SEGUIMIENTO as NIVEL_SEGUIMIENTO
from .niveles_columbia import URGENTE as NIVEL_URGENTE
from .perfiles import serialize, user_to_dict


def _response_int(value: Any) -> int:
    if isinstance(value, bool):
        return 1 if value else 0
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        try:
            return int(value)
        except ValueError:
            return 0
    return 0


def _block_score(respuestas: dict[str, Any], block_key: str) -> int:
    for block in respuestas.get("bloques", []):
        if isinstance(block, dict) and block.get("bloque") == block_key:
            return _response_int(block.get("puntuacion_total"))
    return 0


def _recurso_urgente() -> str:
    """Semana 8 (pregunta 14b de la Dra.): con el contacto del piloto si el
    servidor lo tiene configurado."""
    contacto = contacto_urgente()
    return f"{RECURSO_URGENTE}: {contacto}" if contacto else f"{RECURSO_URGENTE} en el piloto"


def build_parent_alert(session: dict[str, Any], student: dict[str, Any]) -> dict[str, str]:
    respuestas = session.get("respuestas")
    if not isinstance(respuestas, dict):
        respuestas = {}

    tipo_cuestionario = str(session.get("tipo_cuestionario", ""))
    nombre = student.get("nombre_completo") or "El estudiante vinculado"

    if tipo_cuestionario == "suicidio":
        phq9_score = _response_int(respuestas.get("phq9_score")) or _block_score(respuestas, "PHQ9")
        cssrs_score = _response_int(respuestas.get("cssrs_score")) or _block_score(respuestas, "CSSRS")
        # Semana 4 (asesor, 16 oct): niveles de Columbia. Antes era «riesgo
        # alto» con cualquier «sí» o PHQ-9 >= 10 (cerca del 19 % de los
        # estudiantes). Ahora solo el plan es urgente; la intención va a lo
        # comunitario; lo demás se sigue en la app y en la escuela.
        # Semana 8 (pregunta 14d de la Dra.): un PHQ-9 de 10 o más también
        # manda al centro comunitario.
        nivel = nivel_atencion(respuestas)
        if nivel == NIVEL_URGENTE:
            return {
                "tipo": "riesgo_alto",
                "titulo": "Se detectó alto riesgo: busque evaluación hoy",
                "mensaje": (
                    f"{nombre} respondió el cuestionario de riesgo y sus respuestas indican un plan para hacerse daño. "
                    "Se ha detectado alto riesgo: por favor contacte a un especialista para una evaluación más detallada."
                ),
                "recomendacion": (
                    f"Busque hoy la evaluación con un especialista ({_recurso_urgente()}). "
                    "No le deje solo/a, retire medios con los que pudiera hacerse daño y hable con calma y sin regaños. "
                    "Si hay peligro inmediato, llame al 911 o a la Línea de la Vida (800 911 2000, 24 horas)."
                ),
            }
        if nivel == NIVEL_COMUNITARIO:
            por_intencion = nivel_columbia(respuestas) == NIVEL_COMUNITARIO
            return {
                "tipo": "riesgo_comunitario",
                "titulo": "Señales de riesgo: busque apoyo en su comunidad",
                "mensaje": (
                    f"{nombre} respondió el cuestionario de riesgo y sus respuestas indican que ha tenido la intención "
                    "de hacerse daño. Es importante que reciba apoyo profesional pronto."
                    if por_intencion
                    else f"{nombre} respondió el cuestionario de depresión y sus respuestas indican síntomas que "
                    "conviene atender. Es importante que reciba apoyo profesional pronto."
                ),
                "recomendacion": (
                    f"Acérquese con su hijo/a a {RECURSO_COMUNITARIO} cercano (directorio: {DIRECTORIO_CECOSAMA}); "
                    "la escuela puede ayudarle a encontrarlo. "
                    "Pregúntele directamente cómo está, escuche sin juzgar y no minimice lo que siente. "
                    "Si cree que su seguridad está en peligro, llame al 911 o a la Línea de la Vida (800 911 2000)."
                ),
            }
        seguimiento = nivel == NIVEL_SEGUIMIENTO
        return {
            "tipo": "cuestionario_completado",
            "titulo": "Cuestionario de riesgo completado",
            "mensaje": f"{nombre} completó el cuestionario de depresión/riesgo. PHQ-9: {phq9_score}; C-SSRS: {cssrs_score}."
            + (" La app le dará seguimiento y la escuela estará informada de la atención." if seguimiento else ""),
            "recomendacion": (
                "Como padre/madre/tutor: reconozca el esfuerzo de responder, mantenga una conversación abierta, "
                "observe cambios de ánimo, sueño, apetito o aislamiento, y ofrezca apoyo sin minimizar lo que siente."
            ),
        }

    if tipo_cuestionario == "autolesion":
        nssi_score = _block_score(respuestas, "NSSI")
        riesgo_alto = nssi_score > 0
        if riesgo_alto:
            return {
                "tipo": "riesgo_alto",
                "titulo": "Señal de autolesión reportada",
                "mensaje": f"{nombre} respondió el cuestionario de autolesiones y reportó una señal que necesita atención.",
                "recomendacion": (
                    "Como padre/madre/tutor: conserve la calma, escuche sin juzgar, evite castigos o amenazas, "
                    "pregunte qué emoción intentaba manejar y busque apoyo profesional. Revise heridas si existen y acuda a atención médica si es necesario."
                ),
            }
        return {
            "tipo": "cuestionario_completado",
            "titulo": "Cuestionario de autolesiones completado",
            "mensaje": f"{nombre} completó el cuestionario de autolesiones sin reportar autolesión actual en la pregunta principal.",
            "recomendacion": (
                "Como padre/madre/tutor: mantenga canales de confianza, valide sus emociones y observe si aparecen señales de tristeza intensa, aislamiento o ansiedad."
            ),
        }

    if tipo_cuestionario == "ansiedad":
        gad7_score = _response_int(respuestas.get("gad7_score")) or _block_score(respuestas, "GAD7")
        riesgo_alto = gad7_score >= 10
        if riesgo_alto:
            return {
                "tipo": "riesgo_alto",
                "titulo": "Ansiedad elevada",
                "mensaje": f"{nombre} respondió el cuestionario de ansiedad con un puntaje GAD-7 de {gad7_score}.",
                "recomendacion": (
                    "Como padre/madre/tutor: escuche sin minimizar, ayúdele a identificar detonantes, fomente descanso y rutinas, "
                    "practiquen respiración pausada y considere apoyo profesional si la ansiedad afecta escuela, sueño, convivencia o actividades diarias."
                ),
            }
        return {
            "tipo": "cuestionario_completado",
            "titulo": "Cuestionario de ansiedad completado",
            "mensaje": f"{nombre} completó el cuestionario de ansiedad. Puntaje GAD-7: {gad7_score}.",
            "recomendacion": (
                "Como padre/madre/tutor: acompañe con preguntas abiertas, promueva rutinas saludables y esté atento/a si la preocupación aumenta o evita actividades importantes."
            ),
        }

    return {
        "tipo": "cuestionario_completado",
        "titulo": "Cuestionario completado",
        "mensaje": f"{nombre} completó un cuestionario.",
        "recomendacion": "Como padre/madre/tutor: revise cómo se siente, escuche con calma y ofrezca apoyo disponible.",
    }


def create_parent_alerts_for_session(cur: Any, session: dict[str, Any], student: dict[str, Any] | None = None) -> None:
    if session.get("perfil_tipo") != "estudiante":
        return

    id_estudiante = session["id_usuario"]
    if student is None:
        cur.execute("SELECT * FROM usuarios_estudiantes WHERE id_usuario = %s", (id_estudiante,))
        student = cur.fetchone()
    if not student:
        return

    alert = build_parent_alert(session, user_to_dict(student, "estudiante"))
    cur.execute(
        """
        SELECT id_padre
        FROM padre_estudiante
        WHERE id_estudiante = %s
        """,
        (id_estudiante,),
    )
    parent_rows = cur.fetchall()
    for parent in parent_rows:
        cur.execute(
            """
            INSERT INTO alertas_padres (
                id_padre, id_estudiante, id_sesion, tipo, titulo, mensaje, recomendacion
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (id_padre, id_sesion)
            DO NOTHING
            """,
            (
                parent["id_padre"],
                id_estudiante,
                session["id_sesion"],
                alert["tipo"],
                alert["titulo"],
                alert["mensaje"],
                alert["recomendacion"],
            ),
        )


def backfill_parent_alerts(cur: Any, id_padre: int) -> None:
    cur.execute(
        """
        SELECT q.*, e.*
        FROM padre_estudiante pe
        JOIN usuarios_estudiantes e ON e.id_usuario = pe.id_estudiante
        JOIN cuestionarios_locales q
          ON q.perfil_tipo = 'estudiante'
         AND q.id_usuario = pe.id_estudiante
        WHERE pe.id_padre = %s
        ORDER BY q.fecha_registro DESC
        """,
        (id_padre,),
    )
    for row in cur.fetchall():
        session = {
            "id_sesion": row["id_sesion"],
            "perfil_tipo": row["perfil_tipo"],
            "id_usuario": row["id_usuario"],
            "tipo_cuestionario": row["tipo_cuestionario"],
            "respuestas": row["respuestas"],
            "completado": row["completado"],
            "fecha_registro": row["fecha_registro"],
        }
        student = {
            "id_usuario": row["id_usuario"],
            "keycloack_id": row["keycloack_id"],
            "nombre_usuario": row["nombre_usuario"],
            "correo": row["correo"],
            "curp": row.get("curp"),
            "nombres": row["nombres"],
            "apellido_paterno": row["apellido_paterno"],
            "apellido_materno": row["apellido_materno"],
            "activo": row["activo"],
            "fecha_de_creacion": row["fecha_de_creacion"],
            "ultima_conexion": row["ultima_conexion"],
        }
        create_parent_alerts_for_session(cur, session, student)


def list_parent_alerts(cur: Any, id_padre: int) -> list[dict[str, Any]]:
    backfill_parent_alerts(cur, id_padre)
    cur.execute(
        """
        SELECT
            a.id_alerta,
            a.tipo,
            a.titulo,
            a.mensaje,
            a.recomendacion,
            a.leida,
            a.fecha_creacion,
            a.fecha_lectura,
            a.id_sesion,
            a.id_estudiante,
            e.keycloack_id,
            e.nombre_usuario,
            e.correo,
            e.curp,
            e.nombres,
            e.apellido_paterno,
            e.apellido_materno,
            e.activo,
            e.fecha_de_creacion,
            e.ultima_conexion,
            q.tipo_cuestionario,
            q.respuestas
        FROM alertas_padres a
        JOIN usuarios_estudiantes e ON e.id_usuario = a.id_estudiante
        JOIN cuestionarios_locales q ON q.id_sesion = a.id_sesion
        WHERE a.id_padre = %s
        ORDER BY a.leida ASC, a.fecha_creacion DESC
        """,
        (id_padre,),
    )
    alerts = []
    for row in cur.fetchall():
        student = user_to_dict({
            "id_usuario": row["id_estudiante"],
            "keycloack_id": row["keycloack_id"],
            "nombre_usuario": row["nombre_usuario"],
            "correo": row["correo"],
            "curp": row.get("curp"),
            "nombres": row["nombres"],
            "apellido_paterno": row["apellido_paterno"],
            "apellido_materno": row["apellido_materno"],
            "activo": row["activo"],
            "fecha_de_creacion": row["fecha_de_creacion"],
            "ultima_conexion": row["ultima_conexion"],
        }, "estudiante")
        student.pop("id_usuario", None)
        student.pop("keycloack_id", None)
        alerts.append({
            "id_alerta": row["id_alerta"],
            "tipo": row["tipo"],
            "titulo": row["titulo"],
            "mensaje": row["mensaje"],
            "recomendacion": row["recomendacion"],
            "leida": row["leida"],
            "fecha": serialize(row["fecha_creacion"]),
            "fecha_lectura": serialize(row["fecha_lectura"]),
            "id_sesion": row["id_sesion"],
            "tipo_cuestionario": row["tipo_cuestionario"],
            "respuestas": row["respuestas"],
            "estudiante": student,
        })
    return alerts
