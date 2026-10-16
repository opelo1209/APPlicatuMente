"""Endpoints del prototipo de la Semana 2: diario emocional, compuerta de
Serena, alertas de riesgo y vinculacion en dos sentidos.

PROTOTIPO: solo existe en la rama prototipo/diario-semaforo. No se publica
hasta tener el visto bueno del asesor y de psicologia.

Se arma con crear_router(...) recibiendo las dependencias de main.py (la
conexion y el usuario actual) en lugar de importarlas, para no crear una
importacion circular con main.py.
"""

from __future__ import annotations

import json
import logging
import queue
import threading
from datetime import date, datetime, timezone
from typing import Any, Callable

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from .analizador_sentimiento import AnalizadorPysentimiento
from .emociones_catalogo import buscar
from .evaluador_diario import EntradaDiario, evaluar_entrada, resultado_a_dict
from .generador_llm import GeneradorAislado
from .memoria_sesion import MemoriaSesiones
from .respuesta_chat import respuesta_estudiante, traza_decision
from .resumen_riesgo import alerta_de_fila, resumir
from .serena_pipeline import responder
from .vinculacion_bidireccional import (
    ESTADO_PENDIENTE_ESTUDIANTE,
    ESTADO_PENDIENTE_TUTOR,
    ESTADO_VINCULADA,
    MAX_INTENTOS,
    DatosNoCoinciden,
    DatosTutor,
    Estudiante,
    Solicitud,
    Tutor,
    confirmar_por_tutor,
    normalizar_curp,
    responder_estudiante,
    solicitar_desde_estudiante,
    solicitar_desde_tutor,
)

log = logging.getLogger("aptm.prototipo")

# Un solo analizador por proceso: carga los modelos la primera vez (unos
# segundos y ~1 GB de RAM). Si no esta instalado, el diario sigue
# funcionando sin analisis automatico (ver evaluador_diario).
ANALIZADOR = AnalizadorPysentimiento()
# Semana 3: LLM local de Serena (SERENA_MODELO). Sin modelo, Serena responde
# solo con el contenido aprobado.
GENERADOR = GeneradorAislado()
# Semana 3, fase 2: memoria de la conversacion, solo en RAM (memoria_sesion).
MEMORIA = MemoriaSesiones()

MENSAJE_SOLICITUD_TUTOR = (
    "Si los datos son correctos, el estudiante verá tu solicitud en su app y podrá aceptarla."
)


def crear_tablas_prototipo(cur: Any) -> None:
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS diario_entradas (
            id_entrada SERIAL PRIMARY KEY,
            id_estudiante INTEGER NOT NULL REFERENCES usuarios_estudiantes(id_usuario) ON DELETE CASCADE,
            fecha DATE NOT NULL DEFAULT CURRENT_DATE,
            polaridad VARCHAR(10) NOT NULL,
            emociones JSONB NOT NULL,
            texto TEXT NOT NULL DEFAULT '',
            resultado JSONB NOT NULL,
            accion VARCHAR(40) NOT NULL,
            fecha_registro TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE (id_estudiante, fecha)
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS alertas_riesgo (
            id_alerta SERIAL PRIMARY KEY,
            perfil_tipo VARCHAR(30) NOT NULL,
            id_usuario INTEGER NOT NULL,
            origen VARCHAR(20) NOT NULL,
            nivel VARCHAR(40),
            reglas JSONB NOT NULL,
            evidencia JSONB NOT NULL,
            prueba JSONB NOT NULL,
            atendida BOOLEAN NOT NULL DEFAULT FALSE,
            fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS vinculacion_solicitudes (
            id_solicitud SERIAL PRIMARY KEY,
            id_estudiante INTEGER NOT NULL REFERENCES usuarios_estudiantes(id_usuario) ON DELETE CASCADE,
            estado VARCHAR(30) NOT NULL,
            iniciada_por VARCHAR(20) NOT NULL,
            creada TIMESTAMPTZ NOT NULL,
            parentesco VARCHAR(80) NOT NULL,
            curp_tutor VARCHAR(18) NOT NULL,
            nombre_tutor VARCHAR(240) NOT NULL,
            correo_tutor VARCHAR(255) NOT NULL,
            id_tutor INTEGER REFERENCES usuarios_padres(id_usuario) ON DELETE CASCADE,
            hash_codigo VARCHAR(64) NOT NULL DEFAULT '',
            intentos INTEGER NOT NULL DEFAULT 0
        )
        """
    )


# --------------------------------------------------------------------------
# Esquemas de entrada
# --------------------------------------------------------------------------


class EntradaDiarioIn(BaseModel):
    polaridad: str
    emociones: list[str] = Field(min_length=1, max_length=10)
    texto: str = Field(default="", max_length=5000)


class SolicitudEstudianteIn(BaseModel):
    nombre: str = Field(min_length=3, max_length=240)
    curp: str = Field(min_length=18, max_length=18)
    correo: str = Field(min_length=5, max_length=255)
    parentesco: str = Field(default="padre/madre/tutor", max_length=80)


class RespuestaEstudianteIn(BaseModel):
    acepta: bool


class ConfirmacionTutorIn(BaseModel):
    curp_propia: str = Field(min_length=18, max_length=18)
    curp_estudiante: str = Field(min_length=18, max_length=18)
    fecha_nacimiento: date
    codigo: str = Field(min_length=6, max_length=6)


class SolicitudTutorIn(BaseModel):
    curp_estudiante: str = Field(min_length=18, max_length=18)
    fecha_nacimiento: date
    parentesco: str = Field(default="padre/madre/tutor", max_length=80)


class MensajeChatIn(BaseModel):
    mensaje: str = Field(default="", max_length=2000)


# --------------------------------------------------------------------------
# Conversion fila <-> Solicitud
# --------------------------------------------------------------------------

_CAMPOS_SOLICITUD = (
    "id_estudiante", "estado", "iniciada_por", "creada", "parentesco", "curp_tutor",
    "nombre_tutor", "correo_tutor", "id_tutor", "hash_codigo", "intentos",
)


def _a_solicitud(fila: dict[str, Any]) -> Solicitud:
    return Solicitud(**{c: fila[c] for c in _CAMPOS_SOLICITUD})


def _guardar_solicitud(cur: Any, id_solicitud: int, s: Solicitud) -> None:
    cur.execute(
        """
        UPDATE vinculacion_solicitudes
        SET estado = %s, id_tutor = %s, hash_codigo = %s, intentos = %s
        WHERE id_solicitud = %s
        """,
        (s.estado, s.id_tutor, s.hash_codigo, s.intentos, id_solicitud),
    )


def _estudiante(cur: Any, id_usuario: int | None = None, curp: str | None = None) -> Estudiante | None:
    if id_usuario is not None:
        cur.execute("SELECT id_usuario, curp, fecha_nacimiento FROM usuarios_estudiantes WHERE id_usuario = %s", (id_usuario,))
    else:
        cur.execute("SELECT id_usuario, curp, fecha_nacimiento FROM usuarios_estudiantes WHERE curp = %s", (normalizar_curp(curp or ""),))
    fila = cur.fetchone()
    if not fila or not fila["curp"] or not fila["fecha_nacimiento"]:
        return None
    return Estudiante(id=fila["id_usuario"], curp=fila["curp"], fecha_nacimiento=fila["fecha_nacimiento"])


def _ahora() -> datetime:
    return datetime.now(timezone.utc)


def _solo(user: dict[str, Any], perfil: str) -> None:
    if user["perfil_tipo"] != perfil:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=f"Solo para perfil {perfil}")


def _registrar_alerta(cur: Any, user: dict[str, Any], origen: str, alerta: Any) -> None:
    cur.execute(
        """
        INSERT INTO alertas_riesgo (perfil_tipo, id_usuario, origen, nivel, reglas, evidencia, prueba)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        (
            user["perfil_tipo"],
            user["id_usuario"],
            origen,
            alerta["nivel"],
            json.dumps(list(alerta["reglas"])),
            json.dumps(list(alerta["evidencia"]), ensure_ascii=False),
            json.dumps(list(alerta["prueba"]), ensure_ascii=False),
        ),
    )
    # Sin el texto: solo usuario, origen y reglas (ver reporte, privacidad).
    log.warning("ALERTA DE RIESGO %s usuario=%s reglas=%s", origen, user["id_usuario"], list(alerta["reglas"]))


# --------------------------------------------------------------------------
# Router
# --------------------------------------------------------------------------


def crear_router(
    db_conn: Callable[[], Any],
    current_user: Callable[..., dict[str, Any]],
    vincular: Callable[[Any, int, int, str], dict[str, Any]],
    chat_session_id: Callable[[dict[str, Any]], str],
) -> APIRouter:
    router = APIRouter()

    # ---------------------------- Diario ----------------------------------

    @router.post("/diario/entradas")
    def guardar_entrada(payload: EntradaDiarioIn, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
        _solo(user, "estudiante")
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT polaridad FROM diario_entradas
                    WHERE id_estudiante = %s AND fecha < CURRENT_DATE
                    ORDER BY fecha DESC LIMIT 2
                    """,
                    (user["id_usuario"],),
                )
                previas = tuple(f["polaridad"] for f in cur.fetchall())
                try:
                    entrada = EntradaDiario(payload.polaridad, tuple(payload.emociones), payload.texto, previas)
                except ValueError as exc:
                    raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc

                resultado = evaluar_entrada(entrada, ANALIZADOR)
                cuerpo = resultado_a_dict(resultado, payload.texto)
                cur.execute(
                    """
                    INSERT INTO diario_entradas (id_estudiante, polaridad, emociones, texto, resultado, accion)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT (id_estudiante, fecha) DO UPDATE SET
                        polaridad = EXCLUDED.polaridad, emociones = EXCLUDED.emociones,
                        texto = EXCLUDED.texto, resultado = EXCLUDED.resultado,
                        accion = EXCLUDED.accion, fecha_registro = NOW()
                    RETURNING id_entrada
                    """,
                    (
                        user["id_usuario"],
                        payload.polaridad,
                        json.dumps(list(payload.emociones)),
                        payload.texto,
                        json.dumps(cuerpo, ensure_ascii=False),
                        resultado.accion,
                    ),
                )
                cuerpo["id_entrada"] = cur.fetchone()["id_entrada"]
                if resultado.alerta_admin is not None:
                    _registrar_alerta(cur, user, "diario", resultado.alerta_admin)
            conn.commit()
        return cuerpo

    def _analizador_de(resultado: dict[str, Any] | None) -> dict[str, Any] | None:
        analisis = (resultado or {}).get("analisis")
        if not analisis:
            return None
        emociones = analisis.get("emociones") or []
        return {
            "polaridad": analisis.get("polaridad"),
            "confianza": round(float(analisis.get("confianza") or 0.0), 2),
            "emocion": emociones[0][0] if emociones else None,
        }

    @router.get("/diario/entradas")
    def listar_entradas(
        dias: int = Query(default=7, ge=1, le=90), user: dict[str, Any] = Depends(current_user)
    ) -> dict[str, Any]:
        _solo(user, "estudiante")
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT fecha, polaridad, emociones, accion, resultado FROM diario_entradas
                    WHERE id_estudiante = %s AND fecha > CURRENT_DATE - %s
                    ORDER BY fecha
                    """,
                    (user["id_usuario"], dias),
                )
                filas = cur.fetchall()
        return {
            "entradas": [
                {
                    "fecha": f["fecha"].isoformat(),
                    "polaridad": f["polaridad"],
                    "emociones": [buscar(c).nombre for c in f["emociones"]],
                    "accion": f["accion"],
                    # Semana 4 (asesor): la evolucion de lo que encontro el
                    # analizador, junto a lo que marco el estudiante. Sin el
                    # texto: solo lo ve el propio estudiante en su semana.
                    "analizador": _analizador_de(f["resultado"]),
                    "concordancia": (f["resultado"] or {}).get("concordancia"),
                }
                for f in filas
            ]
        }

    # ------------------------ Serena (compuerta) ---------------------------

    def _procesar_chat(mensaje: str, user: dict[str, Any], al_avanzar=None) -> dict[str, Any]:
        # Semana 3: cadena completa (entrada -> contenido -> modelo -> salida).
        sesion = chat_session_id(user)
        r = responder(mensaje, ANALIZADOR, GENERADOR, historial=MEMORIA.turnos(sesion), al_avanzar=al_avanzar)
        if r.turno is not None:
            MEMORIA.agregar(sesion, r.turno)
        if r.alerta is not None:
            # Crisis, respuesta bloqueada o senales repetidas: el
            # administrador lo ve en «Alertas de riesgo».
            origen = {"crisis": "chat", "bloqueada": "chat_salida"}.get(r.tipo, "chat_acumulado")
            if r.alerta.get("tipo") == "autolesion_en_chat":
                origen = "chat_autolesion"
            elif r.alerta.get("tipo") == "metodo_en_chat":
                origen = "chat_metodo"
            with db_conn() as conn:
                with conn.cursor() as cur:
                    _registrar_alerta(cur, user, origen, r.alerta)
                conn.commit()
        # Semana 4, T3: como se decidio se queda en el registro del servidor;
        # al estudiante solo le llega la respuesta (ver respuesta_chat).
        log.info("chat usuario=%s traza=%s", user["id_usuario"], traza_decision(r))
        return respuesta_estudiante(r, sesion)

    @router.post("/chat")
    def chat(payload: MensajeChatIn, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
        return _procesar_chat(payload.mensaje, user)

    @router.post("/chat/stream")
    def chat_stream(payload: MensajeChatIn, user: dict[str, Any] = Depends(current_user)) -> StreamingResponse:
        """Fase 5: la misma respuesta que /chat, en lineas JSON (NDJSON).
        Primero {"evento": "parcial", "texto": ...} con lo que ya paso la
        guardia (el material aprobado aparece de inmediato) y al final
        {"evento": "final", ...} con lo mismo que devuelve /chat."""
        eventos: queue.Queue = queue.Queue()

        def trabajar() -> None:
            try:
                final = _procesar_chat(payload.mensaje, user, al_avanzar=lambda t: eventos.put({"evento": "parcial", "texto": t}))
                eventos.put({"evento": "final", **final})
            except Exception:  # noqa: BLE001 - se informa al cliente y se registra
                log.exception("fallo /chat/stream")
                eventos.put({"evento": "error", "respuesta": "No pude procesar tu mensaje. Intenta de nuevo."})
            finally:
                eventos.put(None)

        threading.Thread(target=trabajar, daemon=True).start()

        def lineas():
            while (evento := eventos.get()) is not None:
                yield json.dumps(evento, ensure_ascii=False) + "\n"

        # X-Accel-Buffering/Cache-Control: que ningun proxy junte las lineas.
        return StreamingResponse(
            lineas(), media_type="application/x-ndjson", headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"}
        )

    # --------------------------- Administracion -----------------------------

    @router.get("/admin/alertas-riesgo")
    def alertas_riesgo(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
        _solo(user, "administrador")
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT a.*, e.nombres, e.apellido_paterno
                    FROM alertas_riesgo a
                    LEFT JOIN usuarios_estudiantes e
                      ON a.perfil_tipo = 'estudiante' AND e.id_usuario = a.id_usuario
                    ORDER BY a.fecha_creacion DESC LIMIT 100
                    """
                )
                filas = cur.fetchall()
        return {
            "alertas": [
                {
                    "id_alerta": f["id_alerta"],
                    "estudiante": " ".join(p for p in (f["nombres"], f["apellido_paterno"]) if p) or f"usuario {f['id_usuario']}",
                    "origen": f["origen"],
                    "nivel": f["nivel"],
                    "reglas": f["reglas"],
                    "evidencia": f["evidencia"],
                    "prueba": f["prueba"],
                    "atendida": f["atendida"],
                    "fecha": f["fecha_creacion"].isoformat(),
                    "id_usuario": f["id_usuario"],
                    "perfil_tipo": f["perfil_tipo"],
                }
                for f in filas
            ]
        }

    @router.get("/admin/resumen-riesgo/{id_usuario}")
    def resumen_de_riesgo(
        id_usuario: int,
        dias: int = Query(default=30, ge=1, le=180),
        user: dict[str, Any] = Depends(current_user),
    ) -> dict[str, Any]:
        """Semana 4 (asesor): resumen de las alertas de un estudiante. La
        version del tutor es un BORRADOR: no se envia a nadie todavia."""
        _solo(user, "administrador")
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT origen, nivel, reglas, atendida, fecha_creacion FROM alertas_riesgo
                    WHERE perfil_tipo = 'estudiante' AND id_usuario = %s
                      AND fecha_creacion > NOW() - make_interval(days => %s)
                    ORDER BY fecha_creacion
                    """,
                    (id_usuario, dias),
                )
                filas = cur.fetchall()
                cur.execute("SELECT nombres FROM usuarios_estudiantes WHERE id_usuario = %s", (id_usuario,))
                estudiante = cur.fetchone()
        nombre = (estudiante or {}).get("nombres") or "el estudiante"
        r = resumir([alerta_de_fila(f) for f in filas], nombre)
        return {
            "administrador": r.administrador,
            "tutor_borrador": r.tutor,
            "crisis": r.crisis,
            "preventivas": r.preventivas,
            "pendientes": r.pendientes,
            "dias": dias,
        }

    # ----------------------- Vinculacion: estudiante ------------------------

    @router.post("/vinculacion/solicitudes", status_code=status.HTTP_201_CREATED)
    def estudiante_registra_tutor(
        payload: SolicitudEstudianteIn, user: dict[str, Any] = Depends(current_user)
    ) -> dict[str, Any]:
        _solo(user, "estudiante")
        with db_conn() as conn:
            with conn.cursor() as cur:
                estudiante = _estudiante(cur, id_usuario=user["id_usuario"])
                if estudiante is None:
                    raise HTTPException(status_code=400, detail="Tu cuenta no tiene CURP o fecha de nacimiento.")
                try:
                    s, codigo = solicitar_desde_estudiante(
                        estudiante,
                        DatosTutor(payload.nombre, payload.curp, payload.correo, payload.parentesco),
                        _ahora(),
                    )
                except ValueError as exc:
                    raise HTTPException(status_code=422, detail=str(exc)) from exc
                cur.execute(
                    f"""
                    INSERT INTO vinculacion_solicitudes ({", ".join(_CAMPOS_SOLICITUD)})
                    VALUES ({", ".join(["%s"] * len(_CAMPOS_SOLICITUD))})
                    RETURNING id_solicitud
                    """,
                    tuple(getattr(s, c) for c in _CAMPOS_SOLICITUD),
                )
                id_solicitud = cur.fetchone()["id_solicitud"]
            conn.commit()
        # El codigo solo viaja en esta respuesta; en la base queda el hash.
        return {"id_solicitud": id_solicitud, "codigo": codigo, "nombre_tutor": s.nombre_tutor, "vigencia_horas": 72}

    @router.get("/vinculacion/estudiante")
    def estudiante_solicitudes(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
        _solo(user, "estudiante")
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT * FROM vinculacion_solicitudes WHERE id_estudiante = %s ORDER BY creada DESC",
                    (user["id_usuario"],),
                )
                filas = cur.fetchall()
        return {
            "enviadas": [
                {"id_solicitud": f["id_solicitud"], "nombre_tutor": f["nombre_tutor"], "estado": f["estado"], "creada": f["creada"].isoformat()}
                for f in filas if f["iniciada_por"] == "estudiante"
            ],
            "recibidas": [
                {"id_solicitud": f["id_solicitud"], "nombre_tutor": f["nombre_tutor"], "parentesco": f["parentesco"]}
                for f in filas if f["iniciada_por"] == "tutor" and f["estado"] == ESTADO_PENDIENTE_ESTUDIANTE
            ],
        }

    @router.post("/vinculacion/solicitudes/{id_solicitud}/respuesta")
    def estudiante_responde(
        id_solicitud: int, payload: RespuestaEstudianteIn, user: dict[str, Any] = Depends(current_user)
    ) -> dict[str, Any]:
        _solo(user, "estudiante")
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT * FROM vinculacion_solicitudes WHERE id_solicitud = %s FOR UPDATE", (id_solicitud,))
                fila = cur.fetchone()
                estudiante = _estudiante(cur, id_usuario=user["id_usuario"])
                if not fila or estudiante is None:
                    raise HTTPException(status_code=404, detail="Solicitud no encontrada")
                try:
                    nueva = responder_estudiante(_a_solicitud(fila), estudiante, payload.acepta, _ahora())
                except PermissionError as exc:
                    raise HTTPException(status_code=404, detail="Solicitud no encontrada") from exc
                except ValueError as exc:
                    raise HTTPException(status_code=409, detail=str(exc)) from exc
                _guardar_solicitud(cur, id_solicitud, nueva)
                if nueva.estado == ESTADO_VINCULADA and nueva.id_tutor is not None:
                    vincular(cur, nueva.id_tutor, nueva.id_estudiante, nueva.parentesco)
            conn.commit()
        return {"estado": nueva.estado}

    # ------------------------- Vinculacion: tutor ---------------------------

    @router.get("/vinculacion/tutor")
    def tutor_pendientes(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
        _solo(user, "padre")
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT s.id_solicitud, s.parentesco, s.intentos, s.creada, e.nombres, e.apellido_paterno
                    FROM vinculacion_solicitudes s
                    JOIN usuarios_estudiantes e ON e.id_usuario = s.id_estudiante
                    WHERE s.estado = %s AND lower(s.correo_tutor) = lower(%s)
                    ORDER BY s.creada DESC
                    """,
                    (ESTADO_PENDIENTE_TUTOR, user["correo"]),
                )
                filas = cur.fetchall()
        return {
            "pendientes": [
                {
                    "id_solicitud": f["id_solicitud"],
                    "nombre_estudiante": f"{f['nombres']} {f['apellido_paterno']}",
                    "parentesco": f["parentesco"],
                    "intentos_restantes": MAX_INTENTOS - f["intentos"],
                }
                for f in filas
            ]
        }

    @router.post("/vinculacion/solicitudes/{id_solicitud}/confirmar")
    def tutor_confirma(
        id_solicitud: int, payload: ConfirmacionTutorIn, user: dict[str, Any] = Depends(current_user)
    ) -> dict[str, Any]:
        _solo(user, "padre")
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT * FROM vinculacion_solicitudes WHERE id_solicitud = %s FOR UPDATE", (id_solicitud,))
                fila = cur.fetchone()
                if not fila or fila["correo_tutor"].lower() != str(user["correo"]).lower():
                    raise HTTPException(status_code=400, detail={"mensaje": DatosNoCoinciden.MENSAJE, "intentos_restantes": None})
                estudiante = _estudiante(cur, id_usuario=fila["id_estudiante"])
                if estudiante is None:
                    raise HTTPException(status_code=400, detail={"mensaje": DatosNoCoinciden.MENSAJE, "intentos_restantes": None})
                tutor = Tutor(id=user["id_usuario"], curp=payload.curp_propia, nombre=user["nombre_completo"], correo=user["correo"])
                try:
                    nueva = confirmar_por_tutor(
                        _a_solicitud(fila), tutor, estudiante, payload.curp_estudiante,
                        payload.fecha_nacimiento, payload.codigo, _ahora(),
                    )
                except DatosNoCoinciden as exc:
                    if exc.solicitud is not None:
                        _guardar_solicitud(cur, id_solicitud, exc.solicitud)
                        conn.commit()
                    restantes = None if exc.solicitud is None else max(0, MAX_INTENTOS - exc.solicitud.intentos)
                    raise HTTPException(
                        status_code=400, detail={"mensaje": DatosNoCoinciden.MENSAJE, "intentos_restantes": restantes}
                    ) from exc
                _guardar_solicitud(cur, id_solicitud, nueva)
                vincular(cur, user["id_usuario"], nueva.id_estudiante, nueva.parentesco)
            conn.commit()
        return {"estado": nueva.estado}

    @router.post("/vinculacion/tutor/solicitudes", status_code=status.HTTP_202_ACCEPTED)
    def tutor_solicita(payload: SolicitudTutorIn, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
        _solo(user, "padre")
        with db_conn() as conn:
            with conn.cursor() as cur:
                estudiante = _estudiante(cur, curp=payload.curp_estudiante)
                tutor = Tutor(id=user["id_usuario"], curp="", nombre=user["nombre_completo"], correo=user["correo"])
                try:
                    s = solicitar_desde_tutor(
                        tutor, estudiante, payload.curp_estudiante, payload.fecha_nacimiento, payload.parentesco, _ahora()
                    )
                except DatosNoCoinciden:
                    # Misma respuesta que en el caso correcto: no se revela si
                    # la CURP existe ni que dato fallo.
                    return {"mensaje": MENSAJE_SOLICITUD_TUTOR}
                cur.execute(
                    f"""
                    INSERT INTO vinculacion_solicitudes ({", ".join(_CAMPOS_SOLICITUD)})
                    VALUES ({", ".join(["%s"] * len(_CAMPOS_SOLICITUD))})
                    """,
                    tuple(getattr(s, c) for c in _CAMPOS_SOLICITUD),
                )
            conn.commit()
        return {"mensaje": MENSAJE_SOLICITUD_TUTOR}

    return router
