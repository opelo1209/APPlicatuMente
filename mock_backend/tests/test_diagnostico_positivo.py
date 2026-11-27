"""Pruebas del diagnóstico de positivo con estratificación real yCV repetida."""

import json
import stat
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from entrenamiento import diagnostico_positivo, reentrenar  # noqa: E402
from entrenamiento.datos import Ejemplo, pliegues_estratificados  # noqa: E402


def _escribir_jsonl(ruta: Path, filas: list[dict]) -> None:
    ruta.write_text(
        "".join(json.dumps(fila, ensure_ascii=False) + "\n" for fila in filas),
        encoding="utf-8",
    )


def _ejemplos(n_por_clase: int = 3) -> tuple[Ejemplo, ...]:
    filas = []
    for clase in ("negativo", "neutro", "positivo"):
        for n in range(n_por_clase):
            filas.append(Ejemplo(f"{clase[:3]}{n}", "texto", clase, "origen"))
    return tuple(filas)


def test_pliegues_estratificados_reparte_cada_clase_sin_contador_global():
    ejemplos = _ejemplos(4)
    grupos = pliegues_estratificados(ejemplos, 3, semilla=7)
    assert len(grupos) == 3
    todos = [i for grupo in grupos for i in grupo]
    assert sorted(todos) == list(range(len(ejemplos)))
    for clase in ("negativo", "neutro", "positivo"):
        conteos = [sum(ejemplos[i].etiqueta == clase for i in grupo) for grupo in grupos]
        assert max(conteos) - min(conteos) <= 1


def test_pliegues_estratificados_cambian_entre_repeticiones():
    ejemplos = _ejemplos(5)
    repeticiones = tuple(pliegues_estratificados(ejemplos, 5, semilla=11, repeticiones=3))
    assert len(repeticiones) == 3
    assert repeticiones[0] != repeticiones[1]
    assert repeticiones[1] != repeticiones[2]


def test_vistas_respetan_compuerta_y_claramente_positivo():
    probas = (
        {"negativo": 0.05, "neutro": 0.05, "positivo": 0.90},
        {"negativo": 0.10, "neutro": 0.40, "positivo": 0.50},
        {"negativo": 0.20, "neutro": 0.70, "positivo": 0.10},
        {"negativo": 0.30, "neutro": 0.50, "positivo": 0.20},
    )
    vistas = diagnostico_positivo.vistas_desde_probas(probas)
    assert vistas["argmax"] == ["positivo", "positivo", "neutro", "neutro"]
    assert vistas["compuerta_060"] == ["positivo", "sin_clase", "neutro", "sin_clase"]
    assert vistas["claro_positivo_085"] == ["positivo", "sin_clase", "neutro", "sin_clase"]


def test_reporte_vista_cuenta_sin_clase_como_error():
    reporte = diagnostico_positivo.reporte_vista(
        ["positivo", "positivo", "neutro"],
        ["positivo", "sin_clase", "neutro"],
    )
    assert reporte["exactitud"] == 0.6667
    assert reporte["por_clase"]["positivo"]["recall"] == 0.5
    assert reporte["matriz_confusion"]["positivo"]["sin_clase"] == 1
    assert "sin_clase" in reporte["distribucion_predicha"]


def test_guardar_probabilidades_no_escribe_texto_y_usa_permisos_600(tmp_path):
    ruta = tmp_path / "probas.jsonl"
    filas = [{"codigo": "R001", "etiqueta_real": "positivo", "negativo": 0.1,
              "neutro": 0.2, "positivo": 0.7, "repeticion": 1, "pliegue": 1}]
    diagnostico_positivo.guardar_probabilidades(ruta, filas)
    contenido = ruta.read_text(encoding="utf-8")
    assert "texto" not in contenido
    assert json.loads(contenido.splitlines()[0])["positivo"] == 0.7
    assert stat.S_IMODE(ruta.stat().st_mode) == 0o600


def test_diagnosticar_agrega_repeticiones_sin_modelo_real(tmp_path, monkeypatch):
    monkeypatch.setattr(reentrenar, "_entrenar", lambda *args, **kwargs: (None, None))
    monkeypatch.setattr(
        reentrenar,
        "_predecir_probas",
        lambda tokenizador, modelo, textos, dispositivo, lote=32: [
            {"negativo": 0.1, "neutro": 0.2, "positivo": 0.7} for _ in textos
        ],
    )
    salida = tmp_path / "probas.jsonl"
    resultado = diagnostico_positivo.diagnosticar(
        _ejemplos(2),
        salida,
        k=2,
        repeticiones=2,
        semilla=5,
        dispositivo="cpu",
    )
    assert len(resultado["por_repeticion"]) == 2
    assert resultado["agregado"]["vistas"]["argmax"]["recall_positivo_media"] == 1.0
    filas = [json.loads(linea) for linea in salida.read_text(encoding="utf-8").splitlines()]
    assert len(filas) == 12
    assert all("texto" not in fila for fila in filas)


def test_vistas_desde_detalle_es_conservadora_con_positivo_dudoso():
    filas = [
        {
            "etiqueta_real": "positivo",
            "prediccion_despues": "positivo",
            "confianza_despues": 0.55,
        },
        {
            "etiqueta_real": "negativo",
            "prediccion_despues": "negativo",
            "confianza_despues": 0.92,
        },
    ]
    vistas = diagnostico_positivo.vistas_desde_detalle(filas)
    assert vistas["argmax"] == [("positivo", "positivo"), ("negativo", "negativo")]
    assert vistas["compuerta_060"] == [
        ("positivo", "sin_clase"),
        ("negativo", "negativo"),
    ]
    assert vistas["claro_positivo_085"] == [
        ("positivo", "sin_clase"),
        ("negativo", "negativo"),
    ]


def test_diagnosticar_desde_detalle_agrega_las_tres_vistas():
    filas = [
        {
            "etiqueta_real": "positivo",
            "prediccion_despues": "positivo",
            "confianza_despues": 0.9,
        },
        {
            "etiqueta_real": "negativo",
            "prediccion_despues": "neutro",
            "confianza_despues": 0.5,
        },
    ]
    resultado = diagnostico_positivo.diagnosticar_desde_detalle(filas)
    assert resultado["modo"] == "aproximado_desde_detalle"
    assert resultado["ejemplos"] == 2
    assert set(resultado["vistas"]) == set(diagnostico_positivo.VISTAS)
    assert resultado["vistas"]["claro_positivo_085"]["por_clase"]["positivo"]["recall"] == 1.0


def test_main_desde_detalle_no_entrena(tmp_path: Path, monkeypatch, capsys):
    detalle = tmp_path / "detalle.jsonl"
    _escribir_jsonl(
        detalle,
        [
            {
                "etiqueta_real": "positivo",
                "prediccion_despues": "positivo",
                "confianza_despues": 0.9,
            }
        ],
    )
    salida = tmp_path / "reporte.json"

    def fallo(*args, **kwargs):
        pytest.fail("diagnosticar desde detalle no debe cargar modelos")

    monkeypatch.setattr(diagnostico_positivo, "diagnosticar", fallo)
    diagnostico_positivo.main([str(detalle), "--desde-detalle", "--salida", str(salida)])

    reporte = json.loads(salida.read_text())
    assert reporte["modo"] == "aproximado_desde_detalle"
    assert "repeticion 1/1" in capsys.readouterr().out
