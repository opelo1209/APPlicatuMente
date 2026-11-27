"""Envio de correo (Semana 5, hallazgo H4).

La recuperacion de contrasena decia «correo enviado» sin enviar nada: solo
imprimia el token en el registro del servicio. Este modulo envia de verdad
cuando el servidor tiene una cuenta SMTP configurada, y dice que no puede
cuando no la tiene; nunca finge un envio.

Variables de entorno (todas en /etc/aptm/*.env, nunca en el codigo):
    SMTP_HOST, SMTP_PUERTO (587), SMTP_USUARIO, SMTP_CLAVE, SMTP_REMITENTE
"""

from __future__ import annotations

import logging
import os
import smtplib
import ssl
from email.message import EmailMessage

log = logging.getLogger("aptm.correo")

ESPERA_SEGUNDOS = 15


def configurado() -> bool:
    return bool(os.getenv("SMTP_HOST", "").strip() and os.getenv("SMTP_REMITENTE", "").strip())


def enviar(destinatario: str, asunto: str, cuerpo: str) -> bool:
    """True si el servidor de correo acepto el mensaje. Nunca lanza: un
    fallo se registra (sin el cuerpo, que puede llevar un enlace secreto)."""
    if not configurado():
        log.warning("correo sin configurar; no se envio «%s»", asunto)
        return False
    mensaje = EmailMessage()
    mensaje["From"] = os.environ["SMTP_REMITENTE"]
    mensaje["To"] = destinatario
    mensaje["Subject"] = asunto
    mensaje.set_content(cuerpo)
    try:
        puerto = int(os.getenv("SMTP_PUERTO", "587"))
        with smtplib.SMTP(os.environ["SMTP_HOST"], puerto, timeout=ESPERA_SEGUNDOS) as smtp:
            smtp.starttls(context=ssl.create_default_context())
            usuario = os.getenv("SMTP_USUARIO", "")
            if usuario:
                smtp.login(usuario, os.getenv("SMTP_CLAVE", ""))
            smtp.send_message(mensaje)
        return True
    except (OSError, ValueError, smtplib.SMTPException) as error:
        log.error("no se pudo enviar «%s»: %s", asunto, type(error).__name__)
        return False
