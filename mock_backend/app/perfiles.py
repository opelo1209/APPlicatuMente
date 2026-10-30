"""Perfiles de usuario, sus tablas y permisos, y la forma de
convertir una fila de usuario en la respuesta de la API.

Semana 6: salio de main.py sin cambios.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any


PROFILE_TABLES = {
    "estudiante": "usuarios_estudiantes",
    "padre": "usuarios_padres",
    "administrador": "usuarios_administradores",
}

PROFILE_ALIASES = {
    "estudiante": "estudiante",
    "estudiantes": "estudiante",
    "adolescente": "estudiante",
    "padre": "padre",
    "padres": "padre",
    "madre": "padre",
    "tutor": "padre",
    "admin": "administrador",
    "administrador": "administrador",
}

PROFILE_LABELS = {
    "estudiante": "Estudiante",
    "padre": "Padre/Madre",
    "administrador": "Administrador",
}

ROLE_CAPABILITIES = {
    "estudiante": {
        "can_answer_questionnaires": True,
        "can_play_tcg": True,
        "can_monitor_responses": False,
        "can_edit_questionnaires": False,
        "can_manage_linked_students": False,
        # PROTOTIPO Semana 2
        "can_use_diario": True,
        "can_link_tutor": True,
        "can_review_risk_alerts": False,
    },
    "padre": {
        "can_answer_questionnaires": True,
        "can_play_tcg": False,
        "can_monitor_responses": False,
        "can_edit_questionnaires": False,
        "can_manage_linked_students": True,
        "can_use_diario": False,
        "can_link_tutor": False,
        "can_review_risk_alerts": False,
    },
    "administrador": {
        "can_answer_questionnaires": False,
        "can_play_tcg": False,
        "can_monitor_responses": True,
        "can_edit_questionnaires": True,
        "can_manage_linked_students": False,
        "can_use_diario": False,
        "can_link_tutor": False,
        "can_review_risk_alerts": True,
    },
}


def serialize(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.isoformat()
    return value


def user_to_dict(row: dict[str, Any], profile: str) -> dict[str, Any]:
    user = {key: serialize(value) for key, value in row.items()}
    user.pop("password_hash", None)
    user["perfil_tipo"] = profile
    user["perfil_label"] = PROFILE_LABELS[profile]
    user["nombre_completo"] = " ".join(
        part
        for part in [
            user.get("nombres"),
            user.get("apellido_paterno"),
            user.get("apellido_materno"),
        ]
        if part
    )
    return user
