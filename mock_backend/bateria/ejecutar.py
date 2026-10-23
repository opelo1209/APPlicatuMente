"""Bateria del analizador de sentimientos: diario y Serena (Semana 5).

Reunion con el asesor: medir con un conjunto chico (20 negativas, 20 neutras
y 20 positivas, cada una con su emocion) como clasifica el analizador y que
hacen con eso el diario y Serena, y poder repetirlo cuando la app este en
marcha, con un solo usuario que escribe varias entradas.

Dos modos:

  local  Corre en este proceso, con el mismo codigo que la app. Necesita un
         entorno con pysentimiento (~/.venvs/serena_eval). Ve todo: la
         polaridad que uso Serena, la accion del motor de Wang, etc. No
         llama al modelo de lenguaje: se mide la clasificacion, no el texto.
  api    Habla con el servidor por HTTP como un estudiante (BATERIA_USUARIO
         y BATERIA_CLAVE en el entorno; una cuenta de prueba, nunca la de un
         estudiante real). Guarda cada frase en el diario y la manda al chat,
         respetando el limite de mensajes por minuto. Solo ve lo que ve la app.

Uso (desde mock_backend/):
  ~/.venvs/serena_eval/bin/python -m bateria.ejecutar local --salida r.json
  BATERIA_USUARIO=... BATERIA_CLAVE=... python -m bateria.ejecutar api \\
      --url https://ml.izt.uam.mx/aptm-prototipo-api --salida r.json
  python -m bateria.tablero r.json tablero.html
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Iterable

from .metricas import EMOCIONES, POLARIDADES, acierto_por_grupo, distribucion, evaluar

AQUI = Path(__file__).resolve().parent
FRASES = AQUI / "frases_s5.json"
CONCORDANCIA_CON_CLASE = ("coincide", "difiere")
_HECHO_POLARIDAD = {"polaridad_positiva": "positivo", "polaridad_neutra": "neutro", "polaridad_negativa": "negativo"}


def cargar_frases(ruta: Path = FRASES) -> tuple[dict, str]:
    crudo = ruta.read_bytes()
    return json.loads(crudo), hashlib.sha256(crudo).hexdigest()


# ------------------------------- local -------------------------------------


class _SinModelo:
    """Serena sin modelo de lenguaje: responde con su apertura fija."""

    nombre = "sin_modelo"

    def generar(self, mensajes, max_tokens=None):
        from app.generador_llm import GeneradorNoDisponible

        raise GeneradorNoDisponible("bateria: solo se mide la clasificacion")


def fila_local(frase: dict, analizador) -> dict[str, Any]:
    from app.contexto_mensaje import analizar_contexto
    from app.evaluador_diario import EntradaDiario, evaluar_entrada
    from app.serena_pipeline import responder

    inicio = time.perf_counter()
    a = analizador.analizar(frase["texto"])
    ms = round((time.perf_counter() - inicio) * 1000)
    diario = evaluar_entrada(
        EntradaDiario(frase["polaridad"], tuple(frase["emociones_diario"]), frase["texto"]), analizador
    )
    serena = responder(frase["texto"], analizador, _SinModelo(), modo="breve")
    hechos = serena.etapas["entrada"]["hechos"]
    return {
        **frase,
        "pred_polaridad": a.polaridad,
        "confianza": round(a.probabilidad(a.polaridad), 3),
        "pred_emocion": a.emocion_principal(),
        "emociones_top3": [e for e, _ in a.emociones[:3]],
        "consulta": analizar_contexto(frase["texto"]).informativa,
        "diario_concordancia": diario.concordancia,
        "diario_polaridad": a.polaridad if diario.concordancia in CONCORDANCIA_CON_CLASE else None,
        "diario_accion": diario.accion,
        "serena_polaridad": next((_HECHO_POLARIDAD[h] for h in hechos if h in _HECHO_POLARIDAD), None),
        "serena_accion": serena.etapas["entrada"]["accion"],
        "serena_tipo": serena.tipo,
        "ms_analizador": ms,
    }


def correr_local(frases: Iterable[dict], analizador=None) -> list[dict]:
    if analizador is None:
        from app.analizador_sentimiento import AnalizadorPysentimiento

        analizador = AnalizadorPysentimiento()
        analizador.analizar("calentar el modelo")  # la carga no cuenta en el tiempo
    return [fila_local(f, analizador) for f in frases]


# -------------------------------- api --------------------------------------


def _con_reintento(enviar: Callable[[], Any], dormir: Callable[[float], None] = time.sleep, intentos: int = 5):
    """Respeta el limite de la API (429 + Retry-After) en lugar de fallar."""
    for _ in range(intentos):
        r = enviar()
        if r.status_code != 429:
            r.raise_for_status()
            return r.json()
        dormir(float(r.headers.get("Retry-After", "5")) + 0.5)
    raise RuntimeError("la API siguio respondiendo 429")


def fila_api(frase: dict, cliente, dormir=time.sleep) -> dict[str, Any]:
    inicio = time.perf_counter()
    d = _con_reintento(
        lambda: cliente.post(
            "/diario/entradas",
            json={"polaridad": frase["polaridad"], "emociones": frase["emociones_diario"], "texto": frase["texto"]},
        ),
        dormir,
    )
    ms = round((time.perf_counter() - inicio) * 1000)
    # Cada frase en una conversacion nueva: se mide la frase, no la racha.
    cliente.delete("/chat/historial")
    chat = _con_reintento(lambda: cliente.post("/chat", json={"mensaje": frase["texto"]}), dormir)
    analisis = d.get("analisis") or {}
    emociones = [e for e, _ in (analisis.get("emociones") or [])]
    return {
        **frase,
        "pred_polaridad": analisis.get("polaridad"),
        "confianza": round(float(analisis.get("confianza") or 0.0), 3),
        "pred_emocion": emociones[0] if emociones else None,
        "emociones_top3": emociones[:3],
        "consulta": None,
        "diario_concordancia": d.get("concordancia"),
        "diario_polaridad": analisis.get("polaridad") if d.get("concordancia") in CONCORDANCIA_CON_CLASE else None,
        "diario_accion": d.get("accion"),
        "serena_polaridad": None,  # la API no lo expone (Semana 4, T3)
        "serena_accion": None,
        "serena_tipo": chat.get("tipo"),
        "ms_analizador": ms,  # en api: ida y vuelta del diario completo
    }


def correr_api(frases: Iterable[dict], url: str, usuario: str, clave: str) -> list[dict]:
    import httpx

    with httpx.Client(base_url=url.rstrip("/"), timeout=120) as cliente:
        r = cliente.post("/auth/login", json={"username": usuario, "password": clave})
        r.raise_for_status()
        cliente.headers["Authorization"] = f"Bearer {r.json()['access_token']}"
        filas = []
        for i, frase in enumerate(frases, 1):
            filas.append(fila_api(frase, cliente))
            print(f"  {i:2d} {frase['id']} {filas[-1]['pred_polaridad']}", file=sys.stderr)
        cliente.delete("/chat/historial")
        return filas


# ------------------------------ resumen ------------------------------------


def resumir(filas: list[dict], modo: str, sha256: str) -> dict[str, Any]:
    esperadas = [f["polaridad"] for f in filas]
    tiempos = sorted(f["ms_analizador"] for f in filas)
    resumen: dict[str, Any] = {
        "modo": modo,
        "fecha": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "frases_sha256": sha256,
        "total": len(filas),
        "analizador_polaridad": evaluar(esperadas, [f["pred_polaridad"] for f in filas], POLARIDADES),
        "analizador_emocion": evaluar([f["emocion"] for f in filas], [f["pred_emocion"] for f in filas], EMOCIONES),
        "emocion_en_top3": sum(f["emocion"] in f["emociones_top3"] for f in filas),
        "emocion_por_polaridad": acierto_por_grupo(filas, "polaridad", "emocion", "pred_emocion"),
        "diario_polaridad": evaluar(esperadas, [f["diario_polaridad"] for f in filas], POLARIDADES),
        "diario_concordancia": distribucion(filas, "polaridad", "diario_concordancia"),
        "serena_tipo": distribucion(filas, "polaridad", "serena_tipo"),
        "tiempo_ms": {"mediana": tiempos[len(tiempos) // 2], "maximo": tiempos[-1]},
    }
    if any(f["serena_polaridad"] for f in filas):
        resumen["serena_polaridad"] = evaluar(esperadas, [f["serena_polaridad"] for f in filas], POLARIDADES)
        resumen["serena_accion"] = distribucion(filas, "polaridad", "serena_accion")
    if any(f["consulta"] for f in filas):
        resumen["leidas_como_consulta"] = [f["id"] for f in filas if f["consulta"]]
    resumen["errores_polaridad"] = [
        {k: f[k] for k in ("id", "texto", "polaridad", "pred_polaridad", "confianza")}
        for f in filas
        if f["pred_polaridad"] != f["polaridad"]
    ]
    resumen["errores_emocion"] = [
        {k: f[k] for k in ("id", "texto", "emocion", "pred_emocion", "emociones_top3")}
        for f in filas
        if f["pred_emocion"] != f["emocion"]
    ]
    return resumen


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("modo", choices=("local", "api"))
    p.add_argument("--frases", type=Path, default=FRASES)
    p.add_argument("--salida", type=Path, default=Path("bateria_resultado.json"))
    p.add_argument("--url", default=os.getenv("BATERIA_URL", ""))
    args = p.parse_args(argv)

    datos, sha = cargar_frases(args.frases)
    if args.modo == "local":
        filas = correr_local(datos["frases"])
    else:
        usuario, clave = os.getenv("BATERIA_USUARIO"), os.getenv("BATERIA_CLAVE")
        if not (args.url and usuario and clave):
            p.error("el modo api necesita --url (o BATERIA_URL), BATERIA_USUARIO y BATERIA_CLAVE")
        filas = correr_api(datos["frases"], args.url, usuario, clave)
    resultado = {"resumen": resumir(filas, args.modo, sha), "filas": filas}
    args.salida.write_text(json.dumps(resultado, ensure_ascii=False, indent=1), encoding="utf-8")
    r = resultado["resumen"]
    print(
        f"Polaridad {r['analizador_polaridad']['aciertos']}/{r['total']} "
        f"(F1 macro {r['analizador_polaridad']['f1_macro']}), "
        f"emocion {r['analizador_emocion']['aciertos']}/{r['total']}, "
        f"diario {r['diario_polaridad']['aciertos']}/{r['total']} -> {args.salida}"
    )


if __name__ == "__main__":
    main()
