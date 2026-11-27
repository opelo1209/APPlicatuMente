"""Cuerpos de las peticiones de la API principal (Pydantic).

Semana 6: salio de main.py sin cambios.
"""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class UserRegister(BaseModel):
    perfil_tipo: str
    nombre_usuario: str
    correo: str
    password: str
    nombres: str
    apellido_paterno: str
    apellido_materno: str = ""
    estudiantes_curps: list[str] = Field(default_factory=list)
    curp: str = ""
    parentesco: str = "padre/madre/tutor"
    fecha_nacimiento: str = ""


class UserLogin(BaseModel):
    username: str
    password: str


class GoogleLogin(BaseModel):
    token: str


class DemoLogin(BaseModel):
    perfil: str
    clave: str = ""


class CuestionarioUpdate(BaseModel):
    id_usuario: int | None = None
    tipo_cuestionario: str
    respuestas: dict[str, Any]
    completado: bool = False


class VincularEstudiante(BaseModel):
    curp_estudiante: str
    parentesco: str = "padre/madre/tutor"


class ChatRequest(BaseModel):
    mensaje: str = ""


class PasswordResetRequest(BaseModel):
    email_or_username: str


class PasswordResetConfirm(BaseModel):
    token: str
    new_password: str


class ChangePassword(BaseModel):
    current_password: str
    new_password: str


class QuestionConfigUpdate(BaseModel):
    pregunta: str
    puntaje: int = Field(ge=0)
    activo: bool = True


class ActivoUpdate(BaseModel):
    activo: bool
