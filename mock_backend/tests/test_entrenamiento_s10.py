"""Semana 10: corpus público balanceado, VADER y comparación de 4 modelos.

Solo funciones sin dependencias pesadas; las corridas con modelos reales se
documentan en el reporte de la Semana 10.
"""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from entrenamiento import corpus_publico as cp  # noqa: E402
from entrenamiento import vader  # noqa: E402
from entrenamiento.datos import Ejemplo, cargar_conjunto  # noqa: E402


def _filas(n_neg, n_neu, n_pos):
    filas = []
    for etiqueta, n in (("negativo", n_neg), ("neutro", n_neu), ("positivo", n_pos)):
        filas += [{"texto": f"texto {etiqueta} numero {i}", "etiqueta": etiqueta, "origen": "x"} for i in range(n)]
    return filas


# --- corpus_publico ---------------------------------------------------------

def test_normalizar_quita_espacio_antes_de_puntuacion():
    assert cp.normalizar("  thầy  dạy hay .  ") == "thầy dạy hay."
    assert cp.normalizar("a , b !") == "a, b!"


def test_filtrar_descarta_cortos_anonimizados_duplicados_y_sin_etiqueta():
    filas = [
        {"texto": "muy corto", "etiqueta": "neutro"},
        {"texto": "el profe wzjwz12 explica bien", "etiqueta": "positivo"},
        {"texto": "la clase fue buena hoy", "etiqueta": "positivo"},
        {"texto": "La clase fue buena  hoy", "etiqueta": "positivo"},
        {"texto": "sin etiqueta valida aqui", "etiqueta": "no_claro"},
    ]
    salida, descartes = cp.filtrar(filas)
    assert [f["texto"] for f in salida] == ["la clase fue buena hoy"]
    assert descartes == {"sin_etiqueta": 1, "corto": 1, "anonimizado": 1, "duplicado": 1}


def test_filtrar_no_muta_la_entrada():
    filas = [{"texto": " la clase   fue buena ", "etiqueta": "positivo"}]
    cp.filtrar(filas)
    assert filas[0]["texto"] == " la clase   fue buena "


def test_balancear_da_exactamente_n_por_clase_y_es_reproducible():
    filas = _filas(30, 12, 40)
    a = cp.balancear(filas, 10, semilla=1)
    b = cp.balancear(filas, 10, semilla=1)
    assert a == b
    assert cp.resumen_balance([f["etiqueta"] for f in a])["conteo"] == {"negativo": 10, "neutro": 10, "positivo": 10}


def test_balancear_falla_si_una_clase_no_alcanza():
    with pytest.raises(ValueError, match="neutro"):
        cp.balancear(_filas(30, 5, 40), 10)


def test_dividir_estratificado_conserva_proporciones_sin_solapar():
    filas = cp.balancear(_filas(50, 50, 50), 50)
    entrenamiento, prueba = cp.dividir_estratificado(filas, 0.2, semilla=3)
    assert len(entrenamiento) == 120 and len(prueba) == 30
    assert cp.resumen_balance([f["etiqueta"] for f in prueba])["conteo"] == {
        "negativo": 10, "neutro": 10, "positivo": 10}
    assert not {f["texto"] for f in entrenamiento} & {f["texto"] for f in prueba}
    with pytest.raises(ValueError):
        cp.dividir_estratificado(filas, 1.0)


def test_resumen_balance_reporta_razon_de_desbalance():
    r = cp.resumen_balance(["negativo"] * 132 + ["neutro"] * 133 + ["positivo"] * 9)
    assert r["n"] == 274
    assert r["razon_desbalance"] == 14.78
    assert cp.resumen_balance(["negativo", "neutro", "positivo"])["razon_desbalance"] == 1.0


def test_jsonl_con_texto_en_se_vuelve_a_cargar(tmp_path):
    filas = [{"texto_es": "me fue bien", "texto_en": "it went well", "etiqueta": "positivo", "origen": "vsfc_train"}]
    ruta = tmp_path / "c.jsonl"
    cp.escribir_jsonl(ruta, cp.a_ejemplos(filas, "E"))
    (ejemplo,) = cargar_conjunto(ruta)
    assert ejemplo == Ejemplo("E0001", "me fue bien", "positivo", "vsfc_train", "it went well")
    assert json.loads(ruta.read_text().splitlines()[0])["texto_en"] == "it went well"


def test_ejemplo_sin_texto_en_sigue_siendo_compatible():
    assert Ejemplo("R001", "t", "neutro").texto_en == ""


# --- vader ------------------------------------------------------------------

@pytest.mark.parametrize("compound,esperada", [
    (0.06, "positivo"), (0.05, "neutro"), (0.0, "neutro"), (-0.05, "neutro"), (-0.051, "negativo")])
def test_etiqueta_por_compound_usa_umbrales_de_la_presentacion(compound, esperada):
    assert vader.etiqueta_por_compound(compound) == esperada


def test_ajustar_umbrales_encuentra_la_zona_neutra_de_los_datos():
    compounds = [-0.8, -0.6, -0.3, -0.2, 0.1, 0.2, 0.5, 0.7]
    etiquetas = ["negativo", "negativo", "neutro", "neutro", "neutro", "neutro", "positivo", "positivo"]
    neg, pos, f1 = vader.ajustar_umbrales(compounds, etiquetas)
    assert f1 == 1.0
    assert -0.6 < neg <= -0.3 and 0.2 <= pos < 0.5


def test_ajustar_umbrales_prefiere_los_clasicos_en_empate():
    neg, pos, _ = vader.ajustar_umbrales([-0.9, 0.0, 0.9], ["negativo", "neutro", "positivo"])
    assert (neg, pos) == (-0.05, 0.05)


def test_caracteristicas_lexicas_cuentan_palabras_e_intensificadores():
    lexico = {"good": 1.9, "bad": -2.5, "sad": -2.1}
    r = vader.caracteristicas_lexicas("Very good, not bad... sad sad", lexico, {"very": 0.29}, ["not"])
    assert r == {"palabras_positivas": 1.0, "palabras_negativas": 3.0, "intensificadores": 1.0,
                 "negaciones": 1.0, "longitud": 6.0, "palabras_unicas": 5.0}


def test_vader_exige_traduccion():
    with pytest.raises(ValueError, match="texto_en"):
        vader.VaderClasico().predecir([Ejemplo("R1", "me fue bien", "positivo")])


def test_vader_ajustado_sin_ajustar_falla():
    with pytest.raises(RuntimeError):
        vader.VaderAjustado().predecir([Ejemplo("R1", "t", "neutro", "", "t")])


# --- experimentos_s10 -------------------------------------------------------

from entrenamiento import experimentos_s10 as ex  # noqa: E402
from entrenamiento.metricas_clases import exactitud  # noqa: E402


def test_exactitud_por_clase_es_el_recall_de_cada_clase():
    reales = ["negativo", "negativo", "neutro", "positivo", "positivo", "positivo"]
    predichas = ["negativo", "neutro", "neutro", "positivo", "neutro", "negativo"]
    assert ex.exactitud_por_clase(reales, predichas) == {"negativo": 0.5, "neutro": 1.0, "positivo": 0.3333}


def test_exactitud_por_clase_sin_ejemplos_de_una_clase_da_cero():
    assert ex.exactitud_por_clase(["negativo"], ["negativo"])["positivo"] == 0.0


def test_intervalo_bootstrap_contiene_el_valor_y_es_reproducible():
    reales = ["negativo", "neutro", "positivo"] * 20
    predichas = ["negativo", "neutro", "neutro"] * 20
    bajo, alto = ex.intervalo_bootstrap(reales, predichas, exactitud, remuestreos=200)
    assert bajo <= exactitud(reales, predichas) <= alto
    assert (bajo, alto) == ex.intervalo_bootstrap(reales, predichas, exactitud, remuestreos=200)


def test_evaluar_agrega_exactitud_por_clase_e_intervalos():
    r = ex.evaluar(["negativo", "neutro", "positivo"] * 4, ["negativo", "neutro", "positivo"] * 4, remuestreos=50)
    assert r["exactitud"] == 1.0 and r["ic95_f1_macro"] == (1.0, 1.0)
    assert set(r["exactitud_por_clase"]) == {"negativo", "neutro", "positivo"}


def test_main_rechaza_modelos_desconocidos(tmp_path):
    with pytest.raises(SystemExit, match="desconocidos"):
        ex.main(["holdout", "--modelos", "bert_inventado", "--salida", str(tmp_path / "r.json")])


# --- traducir ---------------------------------------------------------------

from entrenamiento import traducir as tr  # noqa: E402


def test_orden_por_longitud_agrupa_textos_parecidos():
    assert tr.orden_por_longitud(["largo texto aqui", "a", "medio"]) == [1, 2, 0]


def test_limite_salida_crece_con_la_entrada_y_tiene_tope():
    assert tr.limite_salida(10) == 36
    assert tr.limite_salida(500) == tr.MAX_TOKENS


def test_traducir_usa_la_cache_sin_cargar_modelo():
    cache = {"hola": "hello"}
    assert tr.traducir(["hola", "", "hola"], "es-en", cache=cache) == ["hello", "", "hello"]


def test_variante_secuencial_solo_acepta_robertuito():
    with pytest.raises(ValueError, match="secuencial"):
        ex._ajustar("tfidf", [Ejemplo("E1", "t", "neutro")], base="/tmp/checkpoint")


def test_robertuito_reentrenado_parte_de_produccion_por_omision():
    assert ex.RobertuitoReentrenado().base == "pysentimiento/robertuito-sentiment-analysis"


# --- correcciones de la revisión de código ----------------------------------

def test_conjuntos_fuera_de_la_lista_publica_son_privados_por_omision():
    assert ex.privados(["educativo", "clinico", "italiano"], []) == {"clinico"}
    assert ex.privados(["educativo", "bateria"], ["bateria"]) == {"bateria"}


def test_privado_con_nombre_inexistente_falla():
    with pytest.raises(SystemExit, match="no existen"):
        ex.privados(["educativo", "clinico"], ["clinco"])


def test_secuencial_sin_checkpoint_falla_antes_de_entrenar():
    with pytest.raises(ValueError, match="base-robertuito"):
        ex.mixto([], [], ["robertuito_reentrenado"], variantes=("secuencial",))
    with pytest.raises(ValueError, match="solo aplica"):
        ex.mixto([], [], ["tfidf"], variantes=("secuencial",), base_robertuito="/tmp/x")


def test_prueba_sin_igual_da_error_claro():
    with pytest.raises(SystemExit, match="nombre=ruta"):
        ex._pares(["clinico.jsonl"])


def test_holdout_sin_entrenamiento_da_error_de_uso(tmp_path):
    with pytest.raises(SystemExit):
        ex.main(["holdout", "--salida", str(tmp_path / "r.json")])


def test_tfidf_sin_ajustar_falla_con_mensaje():
    with pytest.raises(RuntimeError, match="ajustar"):
        ex.Tfidf().predecir([Ejemplo("E1", "t", "neutro")])


def test_escribir_privado_corrige_permisos_de_un_archivo_existente(tmp_path):
    import stat

    from entrenamiento.datos import escribir_privado

    ruta = tmp_path / "p.jsonl"
    ruta.write_text("viejo")
    ruta.chmod(0o644)
    escribir_privado(ruta, "nuevo")
    assert ruta.read_text() == "nuevo"
    assert stat.S_IMODE(ruta.stat().st_mode) == 0o600


def test_pesos_por_clase_son_inversos_a_la_frecuencia():
    from entrenamiento.reentrenar import pesos_por_clase

    pesos = pesos_por_clase(["negativo"] * 132 + ["neutro"] * 133 + ["positivo"] * 9)
    assert pesos["positivo"] == round(274 / (3 * 9), 4)
    assert pesos["positivo"] > pesos["negativo"] > 0
    assert pesos_por_clase(["neutro", "positivo"]) == {"neutro": 1.0, "positivo": 1.0}


def test_reentrenado_sin_pesos_por_omision():
    assert ex.RobertuitoReentrenado().pesos_clase is False


def test_final_exige_checkpoint_base_y_carpeta(tmp_path):
    with pytest.raises(SystemExit):
        ex.main(["final", "--clinico", "x.jsonl", "--salida", str(tmp_path / "r.json")])


def test_guardar_checkpoint_privado_deja_permisos_700_y_600(tmp_path):
    import stat

    class Falso:
        def __init__(self, nombre):
            self.nombre = nombre

        def save_pretrained(self, carpeta):
            (Path(carpeta) / self.nombre).write_text("x")

    modelo = ex.RobertuitoReentrenado(estado=(Falso("tokenizer.json"), Falso("model.safetensors")))
    carpeta = tmp_path / "ckpt"
    ex.guardar_checkpoint_privado(modelo, carpeta)
    assert stat.S_IMODE(carpeta.stat().st_mode) == 0o700
    assert {stat.S_IMODE(a.stat().st_mode) for a in carpeta.iterdir()} == {0o600}


def test_muestra_repaso_es_balanceada_y_reproducible():
    educativo = [Ejemplo(f"E{c}{i}", f"t {c} {i}", c) for c in ("negativo", "neutro", "positivo") for i in range(20)]
    a = ex.muestra_repaso(educativo, 5)
    assert a == ex.muestra_repaso(educativo, 5)
    assert sorted(e.etiqueta for e in a) == ["negativo"] * 5 + ["neutro"] * 5 + ["positivo"] * 5
    assert ex.muestra_repaso(educativo, 0) == []
    with pytest.raises(ValueError):
        ex.muestra_repaso(educativo, 50)


# --- congelado de capas -----------------------------------------------------

class _Param:
    def __init__(self, n):
        self.n, self.requires_grad = n, True

    def numel(self):
        return self.n


class _Bloque:
    def __init__(self, n):
        self.ps = [_Param(n)]

    def parameters(self):
        return self.ps


class _Encoder:
    def __init__(self):
        self.layer = [_Bloque(10) for _ in range(12)]


class _Cuerpo:
    def __init__(self):
        self.embeddings, self.encoder = _Bloque(100), _Encoder()


class _ModeloFalso:
    base_model_prefix = "roberta"

    def __init__(self):
        self.roberta, self.clasificador = _Cuerpo(), _Bloque(5)

    def parameters(self):
        yield from self.roberta.embeddings.parameters()
        for capa in self.roberta.encoder.layer:
            yield from capa.parameters()
        yield from self.clasificador.parameters()


def test_congelar_capas_deja_entrenables_solo_las_superiores_y_el_clasificador():
    from entrenamiento.reentrenar import congelar_capas

    modelo = _ModeloFalso()
    assert congelar_capas(modelo, 9) == 3 * 10 + 5
    assert not modelo.roberta.embeddings.ps[0].requires_grad
    assert [c.ps[0].requires_grad for c in modelo.roberta.encoder.layer] == [False] * 9 + [True] * 3


def test_congelar_cero_no_cambia_nada_y_demasiadas_capas_falla():
    from entrenamiento.reentrenar import congelar_capas

    assert congelar_capas(_ModeloFalso(), 0) == 100 + 12 * 10 + 5
    with pytest.raises(ValueError):
        congelar_capas(_ModeloFalso(), 13)


def test_congelar_solo_aplica_a_robertuito():
    with pytest.raises(ValueError, match="robertuito"):
        ex._ajustar("tfidf", [Ejemplo("E1", "t", "neutro")], congelar=9)


# --- modelos adicionales de la presentación -----------------------------------

def _juguete():
    frases = {"negativo": ["me siento muy triste hoy", "todo salio mal y lloré", "odio este dia horrible"],
              "neutro": ["fui a la escuela en camion", "hoy es martes", "comi en casa con mi tia"],
              "positivo": ["estoy muy feliz con mi examen", "me encanto la fiesta", "que alegria ver a mis amigos"]}
    return [Ejemplo(f"J{i}", t, c) for c, ts in frases.items() for i, t in enumerate(ts)]


@pytest.mark.parametrize("clase_modelo", ["SvmTfidf", "BayesIngenuo"])
def test_modelos_tfidf_adicionales_aprenden_y_no_mutan(clase_modelo):
    pytest.importorskip("sklearn")
    vacio = getattr(ex, clase_modelo)()
    ajustado = vacio.ajustar(_juguete())
    assert vacio.modelo is None and ajustado.modelo is not None
    pred = ajustado.predecir(_juguete())
    assert set(pred) <= {"negativo", "neutro", "positivo"}
    assert sum(p == e.etiqueta for p, e in zip(pred, _juguete())) >= 7


@pytest.mark.parametrize("clase_modelo", ["SvmTfidf", "BayesIngenuo", "SbertLogistica"])
def test_modelos_adicionales_sin_ajustar_fallan(clase_modelo):
    with pytest.raises(RuntimeError, match="ajustar"):
        getattr(ex, clase_modelo)().predecir([Ejemplo("E1", "t", "neutro")])


def test_modelos_adicionales_registrados():
    assert {"svm_tfidf", "bayes_ingenuo", "sbert_logistica"} <= set(ex.MODELOS)


def test_cache_de_vectores_separa_codificadores(monkeypatch):
    """La caché distingue el codificador: el mismo texto con MiniLM (384) y
    con mpnet (768) no debe devolver el vector del otro."""
    np = pytest.importorskip("numpy")

    class Falso:
        def __init__(self, dim):
            self.dim, self.llamadas = dim, 0

        def encode(self, textos, **_):
            self.llamadas += 1
            return [np.full(self.dim, float(len(t))) for t in textos]

    falsos = {ex.MODELO_EMBEDDINGS: Falso(768), ex.MODELO_EMBEDDINGS_LIGERO: Falso(384)}
    monkeypatch.setattr(ex, "_codificador", lambda nombre=ex.MODELO_EMBEDDINGS: falsos[nombre])
    monkeypatch.setattr(ex, "_CACHE_VECTORES", {})
    grande = ex._vectores_cache(("hola", "adiós"))
    chico = ex._vectores_cache(("hola", "adiós"), ex.MODELO_EMBEDDINGS_LIGERO)
    ex._vectores_cache(("hola",), ex.MODELO_EMBEDDINGS_LIGERO)  # ya en caché
    assert grande.shape == (2, 768) and chico.shape == (2, 384)
    assert falsos[ex.MODELO_EMBEDDINGS_LIGERO].llamadas == 1
    assert ex.sbert_ligero().codificador == ex.MODELO_EMBEDDINGS_LIGERO
    assert "sbert_minilm" in ex.MODELOS


# --- evaluación robusta -------------------------------------------------------

from entrenamiento import evaluacion_robusta as er  # noqa: E402


def _etiquetas_grupos():
    etiquetas = ["negativo"] * 40 + ["neutro"] * 40 + ["positivo"] * 6
    grupos = [f"p{i // 2}" if i < 20 else f"q{i}" for i in range(86)]  # 10 personas con 2 respuestas
    return etiquetas, grupos


def test_pliegues_por_grupo_no_parten_participantes_y_cubren_todo():
    etiquetas, grupos = _etiquetas_grupos()
    pliegues = er.pliegues_por_grupo(etiquetas, grupos, 5, semilla=3)
    assert sorted(i for p in pliegues for i in p) == list(range(86))
    pliegue_de = {i: n for n, p in enumerate(pliegues) for i in p}
    for g in set(grupos):
        assert len({pliegue_de[i] for i, x in enumerate(grupos) if x == g}) == 1


def test_pliegues_por_grupo_reparten_la_clase_escasa_y_son_reproducibles():
    etiquetas, grupos = _etiquetas_grupos()
    pliegues = er.pliegues_por_grupo(etiquetas, grupos, 5, semilla=3)
    positivos = [sum(etiquetas[i] == "positivo" for i in p) for p in pliegues]
    assert max(positivos) - min(positivos) <= 1
    assert pliegues == er.pliegues_por_grupo(etiquetas, grupos, 5, semilla=3)
    with pytest.raises(ValueError):
        er.pliegues_por_grupo(etiquetas, grupos[:-1], 5)


def test_regla_e1_solo_cambia_neutro_a_positivo_cuando_vader_dice_positivo():
    assert er.regla_e1(["neutro", "neutro", "negativo", "positivo"],
                       ["positivo", "negativo", "positivo", "neutro"]) == ["positivo", "neutro", "negativo", "positivo"]


def test_promedio_y_argmax():
    a = [{"negativo": 0.6, "neutro": 0.3, "positivo": 0.1}]
    b = [{"negativo": 0.0, "neutro": 0.3, "positivo": 0.7}]
    assert er.promedio_probas(a, b) == [{"negativo": 0.3, "neutro": 0.3, "positivo": 0.4}]
    assert er.argmax(er.promedio_probas(a, b)) == ["positivo"]


def test_agregar_cuenta_victorias_y_resume():
    rep = [{"metricas": {"produccion": {"f1_macro": 0.5}, "secuencial": {"f1_macro": 0.6}}},
           {"metricas": {"produccion": {"f1_macro": 0.55}, "secuencial": {"f1_macro": 0.52}}}]
    r = er.agregar(rep)
    assert r["veces_mejor_f1"] == {"secuencial": 1, "produccion": 1}
    assert r["secuencial_supera_produccion"] == "1/2"
    assert r["resumen"]["secuencial"]["f1_macro"]["media"] == 0.56


# --- análisis de cierre ---------------------------------------------------------

from entrenamiento import analisis_s10 as an  # noqa: E402


def test_kappa_perfecto_azar_e_interpretacion():
    assert an.kappa_cohen(["a", "b", "a", "b"], ["a", "b", "a", "b"]) == 1.0
    assert an.kappa_cohen(["a", "a", "b", "b"], ["a", "b", "a", "b"]) == 0.0
    assert an.interpretar_kappa(0.1) == "leve" and an.interpretar_kappa(0.9) == "casi perfecto"
    with pytest.raises(ValueError):
        an.kappa_cohen([], [])


def test_curva_cobertura_baja_cobertura_al_subir_umbral():
    reales = ["negativo", "neutro", "positivo", "negativo"]
    probas = [{"negativo": 0.9, "neutro": 0.05, "positivo": 0.05}, {"negativo": 0.3, "neutro": 0.4, "positivo": 0.3},
              {"negativo": 0.1, "neutro": 0.2, "positivo": 0.7}, {"negativo": 0.2, "neutro": 0.5, "positivo": 0.3}]
    curva = an.curva_cobertura(reales, probas, (0.34, 0.6, 0.95))
    assert [f["cobertura"] for f in curva] == [1.0, 0.5, 0.0]
    assert curva[0]["exactitud"] == 0.75 and curva[1]["exactitud"] == 1.0


def test_comparar_confianzas_auc():
    r = an.comparar_confianzas([0.9, 0.8], [0.5, 0.6])
    assert r["auc_claro_mayor"] == 1.0 and r["no_claro"]["n"] == 2


def test_categorias_y_error_por_categoria():
    cat = an.categorias_texto("no me gusta pero está bien", "preocupacion_actual")
    assert cat == {"origen": "preocupacion_actual", "longitud": "6-15 palabras",
                   "negacion": "con negación", "contraste": "con «pero/aunque»"}
    r = an.error_por_categoria(["neutro", "neutro"], ["neutro", "negativo"],
                               [an.categorias_texto("hola mundo", "x"), an.categorias_texto("no sé", "x")])
    assert r["negacion"]["con negación"] == {"n": 1, "tasa_error": 1.0}


def test_curva_cobertura_sin_textos_cubiertos_da_none():
    curva = an.curva_cobertura(["negativo"], [{"negativo": 0.4, "neutro": 0.3, "positivo": 0.3}], (0.9,))
    assert curva[0]["cobertura"] == 0.0 and curva[0]["exactitud"] is None
