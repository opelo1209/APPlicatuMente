"""Tablero HTML de la bateria del analizador (Semana 5).

Uso: python -m bateria.tablero resultado.json tablero.html

Un solo archivo, sin internet ni bibliotecas: se abre en cualquier
navegador y se puede adjuntar al reporte o mandar por correo.
"""

from __future__ import annotations

import json
import sys
from html import escape
from pathlib import Path

NOMBRES = {
    "negativo": "Negativo", "neutro": "Neutro", "positivo": "Positivo", "sin_clase": "Sin clase",
    "alegria": "Alegría", "tristeza": "Tristeza", "enojo": "Enojo", "miedo": "Miedo",
    "sorpresa": "Sorpresa", "asco": "Asco", "otra": "Otra",
}

CSS = """
:root{--fondo:#f6f4ef;--tarjeta:#fffdf8;--texto:#1f2a24;--suave:#5d6b63;--linea:#dcd6c8;
--acento:#2e7d5b;--neg:#c2410c;--neu:#64748b;--pos:#2e7d5b;--malo:#b91c1c;--celda:46,125,91}
@media (prefers-color-scheme:dark){:root{--fondo:#141a17;--tarjeta:#1c2420;--texto:#e7ece9;--suave:#9fb0a7;
--linea:#2f3a34;--acento:#5fcf9c;--neg:#fb923c;--neu:#94a3b8;--pos:#5fcf9c;--malo:#f87171;--celda:95,207,156}}
*{box-sizing:border-box}body{margin:0;background:var(--fondo);color:var(--texto);
font:15px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif}
main{max-width:1100px;margin:0 auto;padding:28px 16px 64px}
h1{font-size:clamp(1.5rem,1.1rem + 1.6vw,2.2rem);margin:0 0 4px;letter-spacing:-.01em}
h2{font-size:1.15rem;margin:40px 0 12px;padding-bottom:6px;border-bottom:2px solid var(--linea)}
.sub{color:var(--suave);margin:0}.mono{font-family:ui-monospace,monospace;font-size:.8em;overflow-wrap:anywhere}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-top:24px}
.kpi{background:var(--tarjeta);border:1px solid var(--linea);border-radius:10px;padding:14px 16px}
.kpi b{display:block;font-size:2rem;line-height:1.1}.kpi span{color:var(--suave);font-size:.85rem}
.kpi.principal{border-left:5px solid var(--acento)}
.fila{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px}
.caja{background:var(--tarjeta);border:1px solid var(--linea);border-radius:10px;padding:14px 16px;overflow-x:auto}
.caja h3{margin:0 0 8px;font-size:1rem}
table{border-collapse:collapse;width:100%;font-size:.88rem}
th,td{padding:5px 6px;text-align:center;border-bottom:1px solid var(--linea)}
th{color:var(--suave);font-weight:600;font-size:.8rem}td.izq,th.izq{text-align:left}
td.diag{font-weight:700;outline:2px solid var(--acento);outline-offset:-2px}
.barra{height:10px;border-radius:5px;background:var(--acento);min-width:2px}
.pista{background:var(--linea);border-radius:5px;width:100%}
.error td{text-align:left}.error .malo{color:var(--malo);font-weight:600}
.etq{display:inline-block;padding:1px 8px;border-radius:99px;font-size:.78rem;color:#fff}
.negativo{background:var(--neg)}.neutro{background:var(--neu)}.positivo{background:var(--pos)}
.nota{color:var(--suave);font-size:.85rem;margin-top:8px}
"""


def _n(clave) -> str:
    return NOMBRES.get(str(clave), str(clave))


def _pct(x: float) -> str:
    return f"{round(x * 100)} %"


def _matriz(titulo: str, m: dict, nota: str = "") -> str:
    filas_n = [sum(f) for f in m["matriz"]]
    cab = "".join(f"<th>{_n(c)}</th>" for c in m["columnas"])
    cuerpo = ""
    for i, (clase, fila) in enumerate(zip(m["por_clase"], m["matriz"])):
        celdas = ""
        for j, v in enumerate(fila):
            alfa = v / filas_n[i] if filas_n[i] else 0
            diag = " class='diag'" if j == i else ""
            celdas += f"<td{diag} style='background:rgba(var(--celda),{alfa * 0.55:.2f})'>{v}</td>"
        cuerpo += f"<tr><th class='izq'>{_n(clase)}</th>{celdas}</tr>"
    return (
        f"<div class='caja'><h3>{escape(titulo)}</h3><p class='sub'>Exactitud {_pct(m['exactitud'])} · "
        f"F1 macro {m['f1_macro']:.2f}</p><table><tr><th class='izq'>Real \\ predicha</th>{cab}</tr>"
        f"{cuerpo}</table>{f'<p class=nota>{escape(nota)}</p>' if nota else ''}</div>"
    )


def _por_clase(titulo: str, m: dict) -> str:
    filas = ""
    for clase, v in m["por_clase"].items():
        if not v["soporte"]:
            continue
        barras = "".join(
            f"<td><div class='pista'><div class='barra' style='width:{v[k] * 100:.0f}%'></div></div>"
            f"<span class='mono'>{v[k]:.2f}</span></td>"
            for k in ("precision", "recall", "f1")
        )
        filas += f"<tr><th class='izq'>{_n(clase)} <span class='mono'>({v['soporte']})</span></th>{barras}</tr>"
    return (
        f"<div class='caja'><h3>{escape(titulo)}</h3><table><tr><th class='izq'>Clase (n)</th>"
        f"<th>Precisión</th><th>Recall</th><th>F1</th></tr>{filas}</table></div>"
    )


def _distribucion(titulo: str, d: dict, nota: str = "") -> str:
    valores = sorted({k for v in d.values() for k in v})
    cab = "".join(f"<th>{escape(str(v))}</th>" for v in valores)
    filas = "".join(
        f"<tr><th class='izq'><span class='etq {p}'>{_n(p)}</span></th>"
        + "".join(f"<td>{d.get(p, {}).get(v, 0)}</td>" for v in valores)
        + "</tr>"
        for p in ("negativo", "neutro", "positivo")
        if p in d
    )
    return (
        f"<div class='caja'><h3>{escape(titulo)}</h3><table><tr><th class='izq'>Frases</th>{cab}</tr>"
        f"{filas}</table>{f'<p class=nota>{escape(nota)}</p>' if nota else ''}</div>"
    )


def _errores(titulo: str, errores: list, esperado: str, predicho: str, extra: str) -> str:
    if not errores:
        return f"<div class='caja'><h3>{escape(titulo)}</h3><p>Sin errores.</p></div>"
    filas = "".join(
        f"<tr><td class='mono'>{escape(e['id'])}</td><td>{escape(e['texto'])}</td>"
        f"<td>{_n(e[esperado])}</td><td class='malo'>{_n(e[predicho])}</td>"
        f"<td class='mono'>{escape(str(e[extra]))}</td></tr>"
        for e in errores
    )
    return (
        f"<div class='caja error'><h3>{escape(titulo)} ({len(errores)})</h3><table><tr><th>Id</th>"
        f"<th class='izq'>Frase</th><th>Esperada</th><th>Predicha</th><th>{escape(extra)}</th></tr>"
        f"{filas}</table></div>"
    )


def generar(resultado: dict) -> str:
    r = resultado["resumen"]
    pol, emo, dia = r["analizador_polaridad"], r["analizador_emocion"], r["diario_polaridad"]
    total = r["total"]
    kpis = [
        ("principal", _pct(pol["exactitud"]), f"Polaridad del analizador ({pol['aciertos']}/{total})"),
        ("", f"{pol['f1_macro']:.2f}", "F1 macro de polaridad"),
        ("", _pct(emo["exactitud"]), f"Emoción principal ({emo['aciertos']}/{total})"),
        ("", _pct(r["emocion_en_top3"] / total), "Emoción entre las 3 más probables"),
        ("", _pct(dia["exactitud"]), f"Polaridad que usa el diario ({dia['aciertos']}/{total})"),
    ]
    if "serena_polaridad" in r:
        s = r["serena_polaridad"]
        kpis.append(("", _pct(s["exactitud"]), f"Polaridad que usa Serena ({s['aciertos']}/{total})"))
    kpis.append(("", f"{r['tiempo_ms']['mediana']} ms", "Tiempo por frase (mediana)"))
    tiles = "".join(f"<div class='kpi {c}'><b>{v}</b><span>{escape(t)}</span></div>" for c, v, t in kpis)

    matrices = _matriz("Analizador", pol)
    matrices += _matriz("Diario", dia, "Sin clase: el diario no mostró polaridad (baja confianza o consulta).")
    if "serena_polaridad" in r:
        matrices += _matriz("Serena", r["serena_polaridad"], "Sin clase: Serena no usó la polaridad (baja confianza o consulta).")
    emo_pol = "".join(
        f"<tr><th class='izq'><span class='etq {p}'>{_n(p)}</span></th><td>{v['aciertos']}/{v['total']}</td>"
        f"<td>{_pct(v['exactitud'])}</td></tr>"
        for p, v in r["emocion_por_polaridad"].items()
    )
    serena = _distribucion("Tipo de respuesta de Serena", r["serena_tipo"])
    if "serena_accion" in r:
        serena += _distribucion("Decisión del motor de Wang", r["serena_accion"])
    consulta = ""
    if r.get("leidas_como_consulta"):
        consulta = (
            "<p class='nota'>Frases que el detector de contexto leyó como consulta (no como algo que le pasa a quien "
            f"escribe): {escape(', '.join(r['leidas_como_consulta']))}.</p>"
        )
    return f"""<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Batería del analizador</title>
<style>{CSS}</style></head><body><main>
<h1>Batería del analizador de sentimientos</h1>
<p class="sub">APPlicatuMente · {total} frases · modo {escape(r['modo'])} · {escape(r['fecha'])}</p>
<p class="sub mono">frases sha256 {escape(r['frases_sha256'])}</p>
<section class="kpis">{tiles}</section>
<h2>1. Polaridad: analizador, diario y Serena</h2><div class="fila">{matrices}</div>
<div class="fila" style="margin-top:16px">{_por_clase('Polaridad por clase (analizador)', pol)}</div>
<h2>2. Emociones</h2>{_matriz('Emoción principal (7 clases del analizador)', emo)}
<div class="fila" style="margin-top:16px">{_por_clase('Emoción por clase', emo)}
<div class='caja'><h3>Emoción correcta según la polaridad</h3><table><tr><th class='izq'>Frases</th><th>Aciertos</th>
<th>Exactitud</th></tr>{emo_pol}</table></div></div>
<h2>3. Qué hicieron el diario y Serena</h2><div class="fila">
{_distribucion('Concordancia del diario', r['diario_concordancia'], 'coincide: lo escrito va con lo que marcó; difiere: el diario le dice que notó otra cosa; incierto: no se pronuncia.')}
{serena}</div>{consulta}
<h2>4. Lo que no acertó</h2><div class="fila">
{_errores('Polaridad', r['errores_polaridad'], 'polaridad', 'pred_polaridad', 'confianza')}</div>
<div class="fila" style="margin-top:16px">{_errores('Emoción', r['errores_emocion'], 'emocion', 'pred_emocion', 'emociones_top3')}</div>
</main></body></html>"""


def main(argv: list[str] | None = None) -> None:
    argv = argv if argv is not None else sys.argv[1:]
    if len(argv) != 2:
        sys.exit("uso: python -m bateria.tablero resultado.json tablero.html")
    resultado = json.loads(Path(argv[0]).read_text(encoding="utf-8"))
    Path(argv[1]).write_text(generar(resultado), encoding="utf-8")
    print(f"Tablero en {argv[1]}")


if __name__ == "__main__":
    main()
