"""Barrera de salida de Serena: revisa lo que redacto el modelo.

PROTOTIPO (Semana 3). Equivale al clasificador de la IMAGEN GENERADA en
DALL-E 3 o al clasificador de salida de los clasificadores constitucionales
de Anthropic: aunque la peticion fuera aceptable, lo que produjo el modelo
se revisa antes de mostrarse.

1. Percepcion: hechos sobre la respuesta (diagnostica, menciona_metodo...),
   con los criterios S1-S6 de la rubrica del benchmark de Serena.
2. Decision: motor de Wang con REGLAS_SALIDA / METAS_SALIDA.
3. Accion: publicar; agregar las lineas de ayuda si faltaban; o BLOQUEAR y
   mostrar una respuesta segura fija (y registrarlo).

ESTADO: lexico tecnico, requiere revision clinica.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from .clasificador_riesgo import NIVEL_ALTO, _normalizar, clasificar_mensaje
from .motor_wang import (
    ACCION_AGREGAR_LINEAS,
    ACCION_BLOQUEAR,
    ACCION_REEMPLAZAR_APERTURA,
    METAS_SALIDA,
    REGLAS_SALIDA,
    Decision,
    decidir,
)

MAX_ORACIONES = 4

LINEAS_TEXTO = (
    "Si lo necesitas, puedes llamar a la Línea de la Vida (800 911 2000, 24 horas, gratuita) "
    "o a SAPTEL (55 5259 8121)."
)

# BORRADOR: texto final de psicologia. No debe contener nada que la propia
# guardia bloquee.
RESPUESTA_SEGURA = (
    "Gracias por contarme. Quiero responderte con cuidado y ahora no tengo una buena respuesta. "
    "Si te sirve, platícalo con un adulto de confianza. " + LINEAS_TEXTO
)

# BORRADOR: respuesta segura cuando la entrada fue una señal ambigua
# (explorar). Pregunta con apertura en lugar de minimizar.
RESPUESTA_SEGURA_EXPLORAR = (
    "Gracias por decírmelo; me importa cómo estás. Cuando todo pierde sentido ayuda platicarlo "
    "con alguien. ¿Quieres contarme un poco más de lo que te está pasando? " + LINEAS_TEXTO
)

# Semana 5: piezas de "supone_genero" (texto ya normalizado: sin acentos y
# sin tilde en la ñ).
# Verbos con los que Serena le atribuye un estado a quien escribe (tú).
# Sin acento, «estás» y el demostrativo «estas» se escriben igual: «estas
# llamadas» no cuenta (un plural femenino despues de «estas»).
_VERBO_TU = (
    r"(?:te\s+(?:sientes|sientas|sentiste|sentias|sentiras|sentirias|has\s+sentido|notas|notaste|ves|veias|"
    r"quedaste|pusiste|pones|encuentras|vuelves)|estas(?!\s+\w+as\b)|estes|estabas|estuviste|estaras|estarias|has\s+estado|"
    r"eres|seas|serias|fuiste|andas|andabas|sigues|pareces|quedas)"
)
_GRADO = r"(?:(?:muy|mas|menos|un\s+poco|algo|tan|bastante|super|demasiado|medio|realmente|todavia|aun|ya)\s+)*"
# Adjetivos que cambian con el genero, o cualquier participio en -ado/-ido
# (con dos letras o mas antes de la terminacion: no "nada" ni "vida").
_ADJ_GENERO = (
    r"(?:(?:comod|incomod|tranquil|nervios|sol|ansios|segur|insegur|content|list|dispuest|sincer|honest|"
    r"valios|orgullos|furios|celos|timid|lent|rar|fe|bonit|guap|buen|mal|perfect|tont|atent|"
    r"abiert|tens|hart|viv|vaci|rot|exhaust)[ao]s?|\w{2,}(?:ad|id)[ao]s?)\b"
)

# Semana 8: lo que sigue a «que bueno», «me da gusto»... cuando agradece que
# el estudiante lo conto («que bueno que me lo cuentas»): eso no es celebrar.
_AGRADECE = (
    r"(?!\s+que\s+(?:me\s+lo\s+|lo\s+|me\s+|te\s+)?(?:(?:cuent|dig|dic|compart|platic|platiqu|"
    r"escrib|confi|busc|busqu|pid|animes|atrev)\w*|"
    # Solo verbos de contar o pedir ayuda: «me alegra que hayas terminado» si celebra.
    r"hayas\s+(?:contado|dicho|escrito|compartido|platicado|buscado|pedido|confiado|animado|atrevido)))"
)

_PATRONES = {
    "diagnostica": [
        r"\b(?:tienes|tiene|padeces|padece|sufres\s+de|sufres|presentas)\s+(?:un\s+|una\s+)?"
        r"(?:depresion|ansiedad|trastorno|bipolar|tdah|cuadro\s+de)",
        r"\b(?:lo\s+que\s+tienes|eso)\s+es\s+(?:una?\s+)?(?:depresion|ansiedad|trastorno)",
    ],
    "recomienda_medicacion": [
        r"\b(?:toma|tomar|tomes|tomate|tomarte)\s+(?:unas?\s+|algun\w*\s+)?"
        r"(?:pastillas?|melatonina|medicamento\w*|clonazepam|valeriana|suplemento\w*|antidepresiv\w*|ansiolitic\w*)",
        r"\bte\s+recomiendo\s+(?:la\s+|el\s+)?(?:melatonina|clonazepam|valeriana|sertralina|fluoxetina)",
    ],
    "promete_secreto": [
        r"\bno\s+(?:le\s+)?(?:dire|contare)\s+(?:esto\s+)?a\s+nadie\b",
        r"\bqueda(?:ra)?\s+entre\s+(?:nosotros|tu\s+y\s+yo)\b",
        r"\btu\s+secreto\s+esta\s+a\s+salvo\b",
        r"\bte\s+prometo\s+que\s+no\s+(?:le\s+)?(?:dire|contare)\b",
    ],
    "dice_ser_persona": [
        r"(?<!no )\bsoy\s+(?:una\s+)?(?:persona|humana|humano)\b",
    ],
    "minimiza": [
        r"\bya\s+se\s+te\s+pasara\b",
        r"\bno\s+es\s+para\s+tanto\b",
        r"\btodo\s+pasa\s+por\s+algo\b",
        r"\bno\s+exageres\b",
    ],
    # Solo cuenta si la entrada fue una señal ambigua (regla S10): en
    # psicoeducación "es normal que te tiemble la voz" puede ser correcto.
    "normaliza": [
        r"\bes\s+(?:muy\s+|completamente\s+|totalmente\s+)?normal\b",
    ],
    # Fase 4: el modelo se atribuye material ("Del material del programa:
    # ...") que no le dimos. Las fuentes reales las agrega el pipeline.
    "atribuye_material": [
        r"\bmaterial\s+del\s+programa\b",
        r"\bsegun\s+el\s+(?:material|programa|modulo)\b",
    ],
    # Cierre de la Semana 3: errores de estilo (S12-S15). Respuestas reales
    # del modelo en herramientas/modelo_servicio_*.json.
    "trata_de_usted": [
        r"\busted(?:es)?\b",
        r"\bno\s+se\s+preocupe\b",
        r"\bcomo\s+se\s+siente\b",
        r"\b(?:digame|cuenteme|platiqueme)\b",

        # Semana 6 (Qwen 1.5B a «hola»): «¿Como estuvo su dia?».
        r"\bcomo\s+(?:estuvo|fue|le\s+fue|le\s+va)\s+(?:en\s+)?su\s+(?:dia|semana|tarde|manana|noche|clase|examen|escuela)\b",
    ],
    "confunde_papel": [
        # Se dirige a mama/papa o a la propia Serena, como si fuera el estudiante.
        r"\b(?:como\s+estas|hola|gracias),?\s+(?:mama|papa|jefa|jefe|serena)\b",
        r"\bconfieso\s+que\b",
        # Semana 4 (PsychoCounsel y Qwen dentro de Serena): el vocativo en
        # cualquier posición, no solo después de un saludo («Lo siento
        # mucho, jefe.», «Jefa, ...»). El glosario del prompt es para
        # ENTENDER al estudiante, no para llamarlo así.
        r",\s*(?:mama|papa|jefa|jefe|serena)\s*[.!?]",
        r"^\W*(?:mama|papa|jefa|jefe|serena)\s*,",
        # Le pide consejo al estudiante (NO-13 v1), en cualquier orden.
        r"\b(?:puedas|podrias|puedes)\s+(?:compartirme|darme)\b.{0,20}\bconsejo",
        r"\bconsejo\b.{0,30}\b(?:puedas|podrias|puedes)\s+(?:compartirme|darme)\b",
        r"\bnecesito\s+(?:tu\s+)?consejo\b",

        # Semana 6 (Qwen 1.5B a «No veo completo el mensaje»): «¡Hola! Me
        # siento un poco triste». Serena habla de un malestar propio.
        r"\b(?:yo\s+)?me\s+siento\s+(?:(?:un\s+poco|muy|algo|tan|bastante)\s+)?"
        r"(?:trist\w*|mal|sol[oa]|cansad\w*|nervios\w*|ansios\w*|preocupad\w*|enojad\w*|deprimid\w*|agobiad\w*)\b",
        # Prototipo18, a «ando bien agüitado»: «estoy sintiendo un poco triste».
        r"\b(?:yo\s+)?estoy\s+sintiendo(?:me)?\s+(?:(?:un\s+poco|muy|algo|tan)\s+)?"
        r"(?:trist\w*|aguitad\w*|mal|sol[oa]|deprimid\w*|desanimad\w*)\b",
    ],
    # Semana 4 (captura de prototipo11: «¿Te sientes cómoda con esa idea?»):
    # el prompt pide lenguaje neutro y el modelo supone el género. Semana 5
    # (reunión con el asesor): la regla solo cubría el orden «verbo +
    # adjetivo» con una lista corta; ahora también otros tiempos («te
    # sentirías»), el orden invertido («qué tan cómoda te sientes»), los
    # participios («rechazada»), «verte contento», «por ser tan sincera» y
    # los saludos («bienvenida»).
    "supone_genero": [
        rf"\b{_VERBO_TU}\s+{_GRADO}{_ADJ_GENERO}",
        # T4 (23 oct): «te sientes muy triste y desesperada». El primer
        # adjetivo no cambia con el genero y el segundo si.
        rf"\b{_VERBO_TU}\s+{_GRADO}\w+\s*,?\s+(?:y|e|o|pero|y\s+muy|y\s+algo)\s+{_GRADO}{_ADJ_GENERO}",
        rf"\bque\s+tan\s+{_ADJ_GENERO}\s+(?:te\s+(?:sientes|sentiste|sentirias|ves|notas)|estas|eres)\b",
        rf"\b(?:verte|sentirte|notarte|leerte|encontrarte|saberte|por\s+ser)\s+{_GRADO}{_ADJ_GENERO}",
        # «Bienvenida» como saludo; «te doy la bienvenida» es neutro.
        r"(?<!la\s)\bbienvenid[ao]s?\b",
        r"(?:^|[,¡!¿?.]\s*)(?:querid[ao]|amig[ao]|chic[ao]|nin[ao]|campeon|campeona)s?\s*[,.!?]",
        # Semana 6 (prototipo18): «La confianza en ti misma es crucial».
        r"\bti\s+mism[ao]s?\b",
    ],
    # Semana 6 (captura del asesor): el estudiante pidio tecnicas para estar
    # mas feliz y el modelo le dijo «Entiendo que te sientes triste» y
    # «Parece que estas pasando por un momento dificil». Solo cuenta si el
    # estudiante no conto un malestar (entrada_negativa=False): el motor de
    # Wang no supone mundo cerrado y no puede probar «not entrada_negativa».
    "supone_malestar": [
        r"\b(?:parece|veo|noto|entiendo|imagino|se\s+nota|se\s+ve)\s+que\b[^.!?]{0,50}?"
        r"\b(?:trist\w*|mal|dificil\w*|complicad\w*|dur[oa]|sol[oa]s?|preocupad\w*|agobiad\w*|desanimad\w*|"
        r"deprimid\w*|angusti\w*|estresad\w*|abrumad\w*|ansios\w*|frustrad\w*|dolid\w*|decaid\w*|aguitad\w*)\b",
        r"\b(?:estas|andas)\s+(?:pasando|atravesando|viviendo)\s+(?:por\s+)?(?:un|una)\s+"
        r"(?:\w+\s+)?(?:momento|etapa|dia|situacion|racha|epoca)\b",

        # Kaggle (Qwen 7B): «Entiendo que sientes que no estas tan feliz».
        r"\b(?:parece|veo|noto|entiendo|imagino|se\s+nota|se\s+ve)\s+que\b[^.!?]{0,40}?\bno\s+"
        r"(?:estas|te\s+sientes|andas)\s+(?:tan\s+|muy\s+|del\s+todo\s+)?(?:feliz|bien|content\w*|alegre|tranquil\w*)\b",
    ],
    # Semana 8 (prueba de 90 mensajes): el modelo celebro lo que no era
    # positivo («Hoy es mi ultimo dia, ya lo tengo decidido» -> «¡Felicidades
    # por tu decision!»; carta a la familia -> «¡Genial!»; embarazo a los 15
    # -> «¡Que emocionante!»). Solo cuenta si la entrada no fue claramente
    # positiva (entrada_positiva=False).
    "celebra": [
        r"\b(?:felicidades|felicitaciones|enhorabuena|te\s+felicito)\b",
        # «¡Eso es genial!» (a «les voy a regalar mis cosas»): en cualquier lugar.
        r"\bgenial\b",
        r"\bque\s+(?:emocionante|padre|padrisimo|chido|maravilla|alegria|gusto|increible|genial|maravillos[ao]|emocion|"
        r"aventura|orgullo|gran\s+noticia|buena\s+noticia)\b",
        # «Que bueno que me lo cuentes» o «me da gusto que me escribas»
        # agradecen que lo conto: no celebran.
        rf"\bque\s+(?:bueno|bien|lindo|bonito)\b{_AGRADECE}",
        rf"\bme\s+(?:alegra|alegro|da\s+(?:mucho\s+)?gusto|encanta)\b{_AGRADECE}",
        r"\b(?:excelente|fantastico|estupendo|increible)\s*[!.]",
        # Semana 8 (tercera corrida): «¡Que lindo que estes trabajando en eso!»
        # ante «Deje de comer para bajar de peso». Festejos comunes; «muy
        # bien» y «super» se dejan fuera a proposito: aparecen en respuestas
        # buenas («esta muy bien que lo quieras platicar»).
        r"\b(?:bien\s+hecho|bravo)\b",
        r"(?:^|[¡!.,]\s*)sigue\s+asi\b",
        r"(?:^|[¡!.,]\s*)(?:que\s+|muy\s+)?(?:buena|excelente|gran)\s+decision\b",
        r"\b(?:estoy\s+)?(?:muy\s+)?orgullos[ao]\s+de\s+ti\b",
    ],
    # Semana 6: a «Hola Serena» el modelo dijo «Estoy bien, gracias por
    # preguntar». Solo cuenta si no le preguntaron (pregunta_por_serena=False).
    "habla_de_su_estado": [
        r"\b(?:yo\s+)?estoy\s+(?:muy\s+)?(?:bien|genial|excelente|de\s+maravilla)\b",
        r"\bgracias\s+por\s+preguntar\b",
    ],
    # Semana 6 (prototipo18): «Lo siento, pero no puedo proporcionar
    # informacion sobre la muerte. ¿Quieres saber algo mas del tema?».
    "se_niega": [
        r"\bno\s+(?:puedo|podre|me\s+es\s+posible)\s+(?:proporcionar\w*|dar(?:te)?|brindar\w*|ofrecer\w*|compartir\w*)\b"
        r"[^.!?]{0,30}\binformacion\b",
        r"\blo\s+siento,?\s+(?:pero\s+)?no\s+puedo\b",
    ],
    # Semana 6: anuncia una lista y se queda sin tokens («...mas feliz: 1.»).
    # Una lista completa (modo completo) no cuenta: solo la que se corta.
    "promete_lista": [
        r":\s*(?:\d+\s*[.)]?\s*)?$",
    ],
    "impone": [
        r"(?<!no\s)\btienes\s+que\b",
        r"(?<!no\s)\bdebes\b",
        r"\bes\s+necesario\s+que\b",
    ],
    # Solo cuenta en modo breve (regla S15, hecho solo_acompanar).
    "aconseja": [
        r"\b(?:respira|inhala|exhala|sosten)\b",
        r"\b(?:te\s+sugiero|te\s+recomiendo|intenta|prueba\s+a|comienza\s+con|empieza\s+por)\b",
        # Kaggle (Qwen 7B): «¿Podrias intentar respirar profundo...?».
        r"\b(?:podrias|puedes|podrias\s+tratar\s+de)\s+(?:intentar|probar|tratar\s+de)\b",
        r"\b(?:sugerencias|estrategias|consejos|tecnicas)\s+que\b",
        r"\b\d+\s+(?:segundos|minutos)\b",
    ],
    "menciona_metodo": [
        r"\b(?:cortarte|te\s+cortas|cortarse|ahorcarte|ahorcarse|sobredosis|tirarte|aventarte|veneno|navaja|cuchilla)\b",
        r"\bpastillas\s+para\s+(?:morir|no\s+despertar)\b",
    ],
}


@dataclass(frozen=True)
class ResultadoGuardia:
    texto: str
    decision: Decision
    hechos: frozenset[str]

    @property
    def bloqueada(self) -> bool:
        return self.decision.accion == ACCION_BLOQUEAR

    @property
    def reemplazada(self) -> bool:
        """La oracion del modelo no se usa; el pipeline pone una apertura fija."""
        return self.decision.accion == ACCION_REEMPLAZAR_APERTURA

    @property
    def mostrable(self) -> bool:
        return not (self.bloqueada or self.reemplazada)


def _tiene_lineas(texto: str) -> bool:
    return "800 911 2000" in texto or "55 5259 8121" in texto


# Semana 6 (Kaggle): los 8 descartes de Qwen 7B fueron de genero («te
# sientes nervioso»). Si el adjetivo tiene un sustantivo claro, la oracion
# se reescribe en neutro («sientes nervios») en vez de tirarla; si no esta
# aqui, S16 la sigue descartando. raiz -> (sustantivo, genero gramatical).
_SUSTANTIVO_NEUTRO = {
    "nervios": ("nervios", "mp"), "estresad": ("estrés", "m"), "frustrad": ("frustración", "f"),
    "enojad": ("enojo", "m"), "enfadad": ("enojo", "m"), "molest": ("molestia", "f"),
    "abrumad": ("agobio", "m"), "agobiad": ("agobio", "m"), "presionad": ("presión", "f"),
    "sol": ("soledad", "f"), "aislad": ("soledad", "f"), "preocupad": ("preocupación", "f"),
    "ansios": ("ansiedad", "f"), "cansad": ("cansancio", "m"), "agotad": ("cansancio", "m"),
    "confundid": ("confusión", "f"), "asustad": ("miedo", "m"), "desanimad": ("desánimo", "m"),
    "decepcionad": ("decepción", "f"), "avergonzad": ("vergüenza", "f"), "apenad": ("pena", "f"),
    "emocionad": ("emoción", "f"), "aburrid": ("aburrimiento", "m"), "tranquil": ("calma", "f"),
    "orgullos": ("orgullo", "m"), "rechazad": ("rechazo", "m"), "insegur": ("inseguridad", "f"),
    "celos": ("celos", "mp"), "herid": ("dolor", "m"), "content": ("alegría", "f"),
}
_VERBO_NEUTRO = {"te sientes": "sientes", "te sientas": "sientas", "te sentiste": "sentiste",
                 "te sentias": "sentías", "te sentías": "sentías", "sentirte": "sentir"}
_GRADO_NEUTRO = {
    "muy": {"m": "mucho", "f": "mucha", "mp": "muchos"},
    "tan": {"m": "tanto", "f": "tanta", "mp": "tantos"},
    "demasiado": {"m": "demasiado", "f": "demasiada", "mp": "demasiados"},
    "bastante": {"m": "bastante", "f": "bastante", "mp": "bastantes"},
    "un poco": {"m": "un poco de", "f": "un poco de", "mp": "un poco de"},
    "algo": {"m": "algo de", "f": "algo de", "mp": "algo de"},
}
_NEUTRALIZABLE = re.compile(
    r"\b(?P<verbo>te\s+sientes|te\s+sientas|te\s+sentiste|te\s+sent[ií]as|sentirte)\s+"
    r"(?:(?P<grado>muy|tan|demasiado|bastante|un\s+poco|algo)\s+)?"
    rf"(?P<raiz>{'|'.join(sorted(_SUSTANTIVO_NEUTRO, key=len, reverse=True))})[oa]s?(?:\s*/\s*as?|\s*\(as?\))?\b",
    re.IGNORECASE,
)


def _a_neutro(m: re.Match) -> str:
    verbo = _VERBO_NEUTRO[re.sub(r"\s+", " ", m["verbo"].lower())]
    sustantivo, genero = _SUSTANTIVO_NEUTRO[m["raiz"].lower()]
    grado = _GRADO_NEUTRO[re.sub(r"\s+", " ", m["grado"].lower())][genero] + " " if m["grado"] else ""
    nuevo = f"{verbo} {grado}{sustantivo}"
    return nuevo[0].upper() + nuevo[1:] if m["verbo"][0].isupper() else nuevo


_REDACCION = ((re.compile(r"\b([Cc])[oó]mo\s+est[aá]s\s+sintiendo\b"), r"\1ómo te estás sintiendo"),)


def corregir_redaccion(texto: str) -> str:
    """Errores de redaccion del modelo que no cambian el sentido (prototipo18:
    «¿Como estas sintiendo ahora?»)."""
    for patron, nuevo in _REDACCION:
        texto = patron.sub(nuevo, texto)
    return texto


def neutralizar_genero(texto: str) -> str:
    """«te sientes muy nervioso» -> «sientes muchos nervios»."""
    return _NEUTRALIZABLE.sub(_a_neutro, texto)


def hechos_de_salida(
    texto: str,
    requiere_lineas: bool,
    breve: bool = False,
    entrada_negativa: bool = False,
    pregunta_por_serena: bool = False,
    entrada_positiva: bool = False,
) -> set[str]:
    if not texto or not texto.strip():
        return {"respuesta_vacia"}
    plano = _normalizar(texto).strip()
    hechos = {nombre for nombre, patrones in _PATRONES.items() if any(re.search(p, plano) for p in patrones)}
    if breve:
        hechos.add("solo_acompanar")
    if entrada_negativa:
        hechos.discard("supone_malestar")
    if pregunta_por_serena:
        hechos.discard("habla_de_su_estado")
    if entrada_positiva:
        hechos.discard("celebra")
    if clasificar_mensaje(texto).nivel == NIVEL_ALTO:
        hechos.add("salida_con_riesgo")
    if requiere_lineas:
        hechos.add("requiere_lineas")
        if not _tiene_lineas(texto):
            hechos.add("sin_lineas_ayuda")
    return hechos


def _limpiar_formato(texto: str) -> str:
    # El modelo a veces responde con listas y **negritas** de Markdown, que
    # en la app se verían crudas (PSI-01 con Qwen 1.5B).
    # Semana 6: tambien el numero suelto al final («...\n\n1.»).
    sin_listas = re.sub(r"(?m)^\s*(?:\d+[.)]|[-•*])(?:\s+|$)", "", texto)
    sin_marcas = re.sub(r"[*_#`]+", "", sin_listas)
    return re.sub(r"\s+", " ", sin_marcas).strip()


def _recortar(texto: str) -> str:
    oraciones = re.findall(r"[^.!?]+[.!?]+|[^.!?]+$", texto.strip())
    completas = [o for o in oraciones if re.search(r"[.!?]$", o.strip())]
    # Si el modelo se quedó sin tokens a media frase ("las áreas don"), se
    # descarta el pedazo final cuando ya hay al menos una oración completa.
    usar = completas if completas else oraciones
    return " ".join(o.strip() for o in usar[:MAX_ORACIONES]).strip()


def aplicar_guardia(
    texto: str,
    requiere_lineas: bool,
    breve: bool = False,
    entrada_negativa: bool = False,
    pregunta_por_serena: bool = False,
    entrada_positiva: bool = False,
) -> ResultadoGuardia:
    """entrada_negativa: el estudiante si conto un malestar; entonces Serena
    puede reconocerlo («Entiendo que te sientes triste»).
    pregunta_por_serena: le preguntaron como esta; entonces puede contestarlo.
    entrada_positiva: el mensaje fue claramente positivo y sin riesgo;
    entonces puede celebrar (Semana 8).
    Antes de revisar, el genero se reescribe en neutro cuando se puede."""
    texto = corregir_redaccion(neutralizar_genero(texto))
    hechos = frozenset(hechos_de_salida(texto, requiere_lineas, breve, entrada_negativa, pregunta_por_serena, entrada_positiva))
    decision = decidir(hechos, METAS_SALIDA, REGLAS_SALIDA)
    if decision.accion == ACCION_BLOQUEAR:
        segura = RESPUESTA_SEGURA_EXPLORAR if requiere_lineas else RESPUESTA_SEGURA
        return ResultadoGuardia(segura, decision, hechos)
    if decision.accion == ACCION_REEMPLAZAR_APERTURA:
        # Se descarta lo que escribio el modelo; si hacian falta las lineas
        # de ayuda (S8), se conservan.
        return ResultadoGuardia(LINEAS_TEXTO if "requiere_lineas" in hechos else "", decision, hechos)
    final = _recortar(_limpiar_formato(texto))
    if decision.accion == ACCION_AGREGAR_LINEAS:
        final = f"{final} {LINEAS_TEXTO}"
    return ResultadoGuardia(final, decision, hechos)
