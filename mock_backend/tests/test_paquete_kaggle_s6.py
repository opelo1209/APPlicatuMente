"""Semana 6: el zip para Kaggle no lleva datos privados y basta para correr
bateria.comparar_modelos."""

import json
import subprocess
import sys
import zipfile

from bateria import paquete_kaggle

REVISION = {
    "formato": "revision-clinica-serena/v2",
    "nota": "nota privada",
    "revisor": "Nombre de la revisora",
    "fecha": "2026-10-09",
    "contenido": [
        {"id": "a.b", "estado": "rechazado", "comentario": "comentario privado", "referencia": "ref", "texto_corregido": None},
        {"id": "ansiedad.teenImgTerapia.adolescente", "estado": "cambios", "comentario": "x", "referencia": "r",
         "texto_corregido": "terapia cognitivo conductual"},
        {"id": "c.d", "estado": "cambios", "comentario": "y", "referencia": "r", "texto_corregido": "cambia el sentido"},
    ],
}


def test_la_revision_minima_solo_lleva_id_y_estado():
    minima = paquete_kaggle.revision_minima(REVISION)
    plano = json.dumps(minima, ensure_ascii=False)
    for privado in ("Nombre de la revisora", "2026-10-09", "comentario privado", "nota privada", "cambia el sentido"):
        assert privado not in plano
    assert minima["contenido"][0] == {"id": "a.b", "estado": "rechazado"}
    # Solo se conserva la correccion ya aplicada en la app (sigla TCC).
    assert minima["contenido"][1]["texto_corregido"] == "terapia cognitivo conductual"


def test_el_zip_no_lleva_la_revision_completa_ni_basura(tmp_path):
    revision = tmp_path / "revision.json"
    revision.write_text(json.dumps(REVISION), encoding="utf-8")
    salida = tmp_path / "p.zip"
    paquete_kaggle.armar(salida, revision=revision)
    with zipfile.ZipFile(salida) as zf:
        nombres = zf.namelist()
        assert "mock_backend/bateria/comparar_modelos.py" in nombres
        assert "mock_backend/app/serena_pipeline.py" in nombres
        assert "mock_backend/bateria/conversaciones_s6.json" in nombres
        assert not [n for n in nombres if "__pycache__" in n or n.endswith((".ipynb", ".pyc"))]
        revisiones = [n for n in nombres if n.endswith("revision_clinica.json")]
        assert revisiones == ["mock_backend/app/datos/revision_clinica.json"]
        datos = json.loads(zf.read(revisiones[0]))
        assert set(datos) == {"formato", "contenido"}
        assert all(set(i) <= {"id", "estado", "texto_corregido"} for i in datos["contenido"])
        assert "Nombre de la revisora" not in json.dumps(datos, ensure_ascii=False)


def test_desde_el_zip_se_puede_importar_el_comparador(tmp_path):
    salida = tmp_path / "p.zip"
    paquete_kaggle.armar(salida)
    with zipfile.ZipFile(salida) as zf:
        zf.extractall(tmp_path / "kaggle")
    r = subprocess.run(
        [sys.executable, "-c", "import bateria.comparar_modelos as c; print(len(c.cargar_conversaciones()))"],
        cwd=tmp_path / "kaggle" / "mock_backend",
        capture_output=True,
        text=True,
    )
    assert r.returncode == 0, r.stderr
    assert int(r.stdout.strip()) == 23
