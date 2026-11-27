"""Preguntas por omision de los cuestionarios (PHQ-9, C-SSRS, NSSI,
GAD-7), su siembra en la base y las consultas que usa el editor del
administrador.

Semana 6: salio de main.py sin cambios.
"""

from __future__ import annotations

from typing import Any

from .perfiles import serialize


def default_question_configs() -> list[tuple[str, str, str, str, str, int, int]]:
    suicidio = [
        ("suicidio", "Riesgo suicida", "PHQ9", "deprimido_irritable", "likert4", "¿Has estado sintiéndote triste, irritado(a) o sin ganas de nada?", 1, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "poco_interes", "likert4", "¿Has sentido falta de interés en las cosas, o que ya casi nada te da placer o gusto, aunque antes sí te gustaran?", 2, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "sueno", "likert4", "¿Tienes problemas con el sueño? Por ejemplo: ¿te cuesta mucho trabajo dormirte o te despiertas en la madrugada y ya no puedes volver a dormir? O al contrario, ¿duermes tanto que igual sientes que no descansas?", 3, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "apetito", "likert4", "¿Tu apetito ha cambiado mucho? ¿Comes muy poco o demasiado, o has bajado o subido de peso sin querer?", 4, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "cansancio", "likert4", "¿Te sientes cansado(a) o sin energía casi todo el tiempo?", 5, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "mal_consigo", "likert4", "¿Te sientes mal contigo mismo(a), como si fueras un fracaso o como que les has fallado a las personas que quieres?", 6, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "concentracion", "likert4", "¿Te cuesta concentrarte en la escuela, al leer o incluso al ver una película o serie?", 7, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "movimiento", "likert4", "¿Te mueves o hablas más lento de lo normal y los demás lo notan? O al revés, ¿estás tan inquieto(a) que no puedes quedarte quieto(a)?", 8, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "mejor_muerto", "likert4", "¿Has tenido pensamientos de que estarías mejor muerto(a) o de hacerte daño de alguna forma?", 9, 0),
        ("suicidio", "Riesgo suicida", "PHQ9", "deprimido_anio", "binario", "¿En el último año te has sentido triste o deprimido(a) la mayor parte del tiempo?", 10, 1),
        ("suicidio", "Riesgo suicida", "PHQ9", "pensar_terminar", "binario", "¿En el último mes hubo algún momento en que pensaste en serio en quitarte la vida?", 11, 1),
        ("suicidio", "Riesgo suicida", "PHQ9", "intento_suicidio", "binario", "¿Alguna vez en tu vida intentaste suicidarte o hacerte daño para morir?", 12, 1),
        ("suicidio", "Riesgo suicida", "CSSRS", "desear_muerto", "binario", "¿Has deseado estar muerto(a), o sentido que quisieras dormirte y simplemente no despertar?", 13, 1),
        ("suicidio", "Riesgo suicida", "CSSRS", "idea_suicidarse", "binario", "¿Has tenido pensamientos de suicidarte, aunque sea por un momento?", 14, 1),
        ("suicidio", "Riesgo suicida", "CSSRS", "como_lo_haria", "binario", "¿Has pensado en cómo lo harías?", 15, 1),
        ("suicidio", "Riesgo suicida", "CSSRS", "intencion_llevarlo", "binario", "¿Has tenido esos pensamientos y sientes que en parte sí querrías llevarlos a cabo?", 16, 1),
        ("suicidio", "Riesgo suicida", "CSSRS", "detalles_plan", "binario", "¿Has empezado a pensar en los detalles de cómo hacerlo? ¿Sientes que de verdad quieres o planeas llevarlo a cabo?", 17, 1),
    ]
    autolesion = [
        ("autolesion", "Autolesiones", "NSSI", "cortado_piel", "binario", "¿Alguna vez te has hecho cortadas en la piel, pero sin querer hacerte daño grave ni quitarte la vida?", 1, 1),
        ("autolesion", "Autolesiones", "NSSI", "primera_vez", "texto", "¿Cuándo fue la primera vez que lo hiciste?", 2, 0),
        ("autolesion", "Autolesiones", "NSSI", "cuantas_veces", "numero", "¿Cuántas veces lo has hecho?", 3, 0),
        ("autolesion", "Autolesiones", "NSSI", "donde_aprendiste", "texto", "¿Dónde o cómo te enteraste de hacerlo?", 4, 0),
    ]
    ansiedad = [
        ("ansiedad", "Ansiedad", "GAD7", "nervioso", "likert4", "¿Te has sentido nervioso(a), ansioso(a) o con los nervios de punta?", 1, 0),
        ("ansiedad", "Ansiedad", "GAD7", "no_controlar_preocupacion", "likert4", "¿No has podido parar o controlar tus preocupaciones?", 2, 0),
        ("ansiedad", "Ansiedad", "GAD7", "preocupacion_excesiva", "likert4", "¿Te has preocupado demasiado por diferentes cosas?", 3, 0),
        ("ansiedad", "Ansiedad", "GAD7", "dificil_relajarse", "likert4", "¿Te ha costado trabajo relajarte?", 4, 0),
        ("ansiedad", "Ansiedad", "GAD7", "inquietud", "likert4", "¿Has estado tan inquieto(a) que te cuesta quedarte quieto(a)?", 5, 0),
        ("ansiedad", "Ansiedad", "GAD7", "irritabilidad", "likert4", "¿Te has molestado o irritado fácilmente?", 6, 0),
        ("ansiedad", "Ansiedad", "GAD7", "miedo", "likert4", "¿Has sentido miedo como si algo terrible pudiera pasar?", 7, 0),
    ]
    return autolesion + suicidio + ansiedad


def seed_question_configs(cur: Any) -> None:
    cur.executemany(
        """
        INSERT INTO cuestionarios_config (
            modulo_key, modulo, bloque, codigo, tipo_respuesta, pregunta, numero, puntaje, activo
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, TRUE)
        ON CONFLICT (modulo_key, codigo) WHERE modulo_key IS NOT NULL AND codigo IS NOT NULL
        DO UPDATE SET
            modulo = EXCLUDED.modulo,
            bloque = EXCLUDED.bloque,
            tipo_respuesta = EXCLUDED.tipo_respuesta,
            numero = EXCLUDED.numero
        """,
        default_question_configs(),
    )


def list_question_configs(cur: Any) -> list[dict[str, Any]]:
    cur.execute(
        """
        SELECT
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
        FROM cuestionarios_config
        ORDER BY modulo_key, bloque, numero, id_pregunta
        """
    )
    return [{key: serialize(value) for key, value in row.items()} for row in cur.fetchall()]


def list_question_configs_by_module(cur: Any, module: str) -> list[dict[str, Any]]:
    cur.execute(
        """
        SELECT
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
        FROM cuestionarios_config
        WHERE modulo_key = %s AND activo = TRUE
        ORDER BY bloque, numero, id_pregunta
        """,
        (module,),
    )
    return [{key: serialize(value) for key, value in row.items()} for row in cur.fetchall()]
