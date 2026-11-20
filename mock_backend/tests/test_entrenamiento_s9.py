"""Semana 9: exportador privado y evaluador de checkpoint sin dependencias.

Las predicciones se simulan; las corridas con modelos reales se hacen en la UAM.
"""

import json
import stat
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from entrenamiento import evaluar_checkpoint, exportar_detalle, reentrenar  # noqa: E402
from entrenamiento.datos import Ejemplo, escribir_privado  # noqa: E402


def test_normalizar_etiqueta_acepta_ids_del_modelo():
    assert evaluar_checkpoint.normalizar_etiqueta("NEG") == "negativo"
    assert evaluar_checkpoint.normalizar_etiqueta("neutro") == "neutro"
    assert evaluar_checkpoint.normalizar_etiqueta(" POS ") == "positivo"
    with pytest.raises(ValueError):
        evaluar_checkpoint.normalizar_etiqueta("no_claro")


def test_evaluar_predicciones_trae_dispositivo_y_parametros():
    resultado = evaluar_checkpoint.evaluar_predicciones(
        ["negativo", "positivo"],
        ["negativo", "negativo"],
        "cpu",
        {"lote": 32},
    )
    assert resultado["n"] == 2
    assert resultado["dispositivo"] == "cpu"
    assert resultado["parametros"] == {"lote": 32}
    assert resultado["f1_macro"] == 0.2222


def test_filas_detalle_copian_texto_predicciones_y_confianzas():
    ejemplos = (
        Ejemplo("R001", "texto uno", "negativo", "preocupacion_actual"),
        Ejemplo("R002", "texto dos", "positivo", "cosas_fav_apps_adol_v2"),
    )
    filas = exportar_detalle.filas_detalle(
        ejemplos,
        ["negativo", "neutro"],
        [0.91234, 0.7],
        ["positivo", "positivo"],
        [0.6, 0.87654],
    )
    assert filas[0]["codigo"] == "R001"
    assert filas[0]["texto"] == "texto uno"
    assert filas[0]["confianza_antes"] == 0.9123
    assert filas[1]["confianza_despues"] == 0.8765
    with pytest.raises(ValueError):
        exportar_detalle.filas_detalle(ejemplos, ["negativo"], [0.1], ["negativo"], [0.1])


def test_exportar_detalle_escribe_jsonl_con_permisos_600(tmp_path, monkeypatch):
    conjunto = tmp_path / "conjunto.jsonl"
    escribir_privado(
        conjunto,
        json.dumps({"codigo": "R001", "texto": "x", "etiqueta": "negativo", "origen": "u"}) + "\n"
        + json.dumps({"codigo": "R002", "texto": "y", "etiqueta": "positivo", "origen": "u"}) + "\n",
    )
    monkeypatch.setattr(
        exportar_detalle,
        "predecir_original",
        lambda textos: (["negativo", "neutro"], [0.9, 0.8]),
    )
    monkeypatch.setattr(evaluar_checkpoint, "dispositivo_actual", lambda: "cpu")
    monkeypatch.setattr(
        reentrenar,
        "validacion_cruzada",
        lambda *args, **kwargs: (["negativo", "positivo"], [0.7, 0.6], [0.5, 0.5]),
    )
    salida = tmp_path / "detalle.jsonl"
    exportar_detalle.main([str(conjunto), "--salida", str(salida)])
    filas = [json.loads(linea) for linea in salida.read_text(encoding="utf-8").splitlines()]
    assert len(filas) == 2
    assert filas[1]["prediccion_despues"] == "positivo"
    assert filas[1]["confianza_antes"] == 0.8
    assert stat.S_IMODE(salida.stat().st_mode) == 0o600


def test_evaluar_checkpoint_compara_con_produccion_y_no_escribe_texto(tmp_path, monkeypatch):
    bateria = tmp_path / "frases.json"
    bateria.write_text(
        json.dumps(
            {
                "frases": [
                    {"id": "s1", "texto": "x", "polaridad": "negativo"},
                    {"id": "s2", "texto": "y", "polaridad": "positivo"},
                ]
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setattr(evaluar_checkpoint, "dispositivo_actual", lambda: "cpu")
    monkeypatch.setattr(
        evaluar_checkpoint,
        "predecir_checkpoint",
        lambda ruta, textos, lote=32: (["negativo", "negativo"], [0.9, 0.8]),
    )
    monkeypatch.setattr(
        evaluar_checkpoint,
        "predecir_original",
        lambda textos: (["negativo", "positivo"], [0.7, 0.6]),
    )
    salida = tmp_path / "reporte.json"
    evaluar_checkpoint.main([str(tmp_path / "checkpoint"), str(bateria), "--salida", str(salida)])
    reporte = json.loads(salida.read_text(encoding="utf-8"))
    assert reporte["checkpoint"]["n"] == 2
    assert reporte["original"]["exactitud"] == 1.0
    assert reporte["cambios"]["cambiaron"] == 1
    assert "texto" not in salida.read_text(encoding="utf-8")
