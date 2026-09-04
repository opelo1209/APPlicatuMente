import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aptm/text_utils.dart';
import '../theme_provider.dart';
import '../principal.dart';
import 'dart:convert';
import 'paso_identificacion.dart'; // IMPORT PASO IDENTIFICACION
import '../servicios/user.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cuestionario de Riesgo Suicida
//   Bloque 1 — PHQ-9 Depresión y Riesgo  (12 preguntas)
//     • Preguntas 1-9 : escala Likert 0-3
//     • Preguntas 10-12: binario Sí/No (Manejado con SWIPE)
//   Bloque 2 — C-SSRS Ideación Suicida (5 preguntas, binario Sí/No) (Manejado con SWIPE)
// ─────────────────────────────────────────────────────────────────────────────

class Cuestionario extends StatefulWidget {
  const Cuestionario({super.key});

  @override
  State<Cuestionario> createState() => _CuestionarioState();
}

class _CuestionarioState extends State<Cuestionario> {
  int _currentIndex = 0;
  final Map<String, Map<String, dynamic>> _respuestas = {};
  bool _enviando = false;
  bool _cargandoPreguntas = true;
  late List<Map<String, dynamic>> _preguntas = List<Map<String, dynamic>>.from(
    _defaultPreguntas,
  );

  // ── Definición de todas las preguntas ─────────────────────────────────────
  static const List<Map<String, dynamic>> _defaultPreguntas = [
    // PHQ-9 ── Preguntas 1-9 (Likert 0-3)
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 1,
      'id': 'deprimido_irritable',
      'tipo': 'likert4',
      'pregunta':
          '¿Has estado sintiéndote triste, irritado(a) o sin ganas de nada?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 2,
      'id': 'poco_interes',
      'tipo': 'likert4',
      'pregunta':
          '¿Has sentido falta de interés en las cosas, o que ya casi nada te da placer o gusto, aunque antes sí te gustaran?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 3,
      'id': 'sueno',
      'tipo': 'likert4',
      'pregunta':
          '¿Tienes problemas con el sueño? Por ejemplo: ¿te cuesta mucho trabajo dormirte o te despiertas en la madrugada y ya no puedes volver a dormir? O al contrario, ¿duermes tanto que igual sientes que no descansas?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 4,
      'id': 'apetito',
      'tipo': 'likert4',
      'pregunta':
          '¿Tu apetito ha cambiado mucho? ¿Comes muy poco o demasiado, o has bajado o subido de peso sin querer?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 5,
      'id': 'cansancio',
      'tipo': 'likert4',
      'pregunta': '¿Te sientes cansado(a) o sin energía casi todo el tiempo?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 6,
      'id': 'mal_consigo',
      'tipo': 'likert4',
      'pregunta':
          '¿Te sientes mal contigo mismo(a), como si fueras un fracaso o como que les has fallado a las personas que quieres?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 7,
      'id': 'concentracion',
      'tipo': 'likert4',
      'pregunta':
          '¿Te cuesta concentrarte en la escuela, al leer o incluso al ver una película o serie?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 8,
      'id': 'movimiento',
      'tipo': 'likert4',
      'pregunta':
          '¿Te mueves o hablas más lento de lo normal y los demás lo notan? O al revés, ¿estás tan inquieto(a) que no puedes quedarte quieto(a)?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 9,
      'id': 'mejor_muerto',
      'tipo': 'likert4',
      'pregunta':
          '¿Has tenido pensamientos de que estarías mejor muerto(a) o de hacerte daño de alguna forma?',
    },
    // PHQ-9 ── Preguntas 10-12 (binario)
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 10,
      'id': 'deprimido_anio',
      'tipo': 'binario',
      'pregunta':
          '¿En el último año te has sentido triste o deprimido(a) la mayor parte del tiempo?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 11,
      'id': 'pensar_terminar',
      'tipo': 'binario',
      'pregunta':
          '¿En el último mes hubo algún momento en que pensaste en serio en quitarte la vida?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 12,
      'id': 'intento_suicidio',
      'tipo': 'binario',
      'pregunta':
          '¿Alguna vez en tu vida intentaste suicidarte o hacerte daño para morir?',
    },
    // C-SSRS ── 5 preguntas (binario)
    {
      'bloque': 'CSSRS',
      'bloque_nombre': 'Ideación Suicida (C-SSRS)',
      'numero': 1,
      'id': 'desear_muerto',
      'tipo': 'binario',
      'pregunta':
          '¿Has deseado estar muerto(a), o sentido que quisieras dormirte y simplemente no despertar?',
    },
    {
      'bloque': 'CSSRS',
      'bloque_nombre': 'Ideación Suicida (C-SSRS)',
      'numero': 2,
      'id': 'idea_suicidarse',
      'tipo': 'binario',
      'pregunta':
          '¿Has tenido pensamientos de suicidarte, aunque sea por un momento?',
    },
    {
      'bloque': 'CSSRS',
      'bloque_nombre': 'Ideación Suicida (C-SSRS)',
      'numero': 3,
      'id': 'como_lo_haria',
      'tipo': 'binario',
      'pregunta': '¿Has pensado en cómo lo harías?',
    },
    {
      'bloque': 'CSSRS',
      'bloque_nombre': 'Ideación Suicida (C-SSRS)',
      'numero': 4,
      'id': 'intencion_llevarlo',
      'tipo': 'binario',
      'pregunta':
          '¿Has tenido esos pensamientos y sientes que en parte sí querrías llevarlos a cabo?',
    },
    {
      'bloque': 'CSSRS',
      'bloque_nombre': 'Ideación Suicida (C-SSRS)',
      'numero': 5,
      'id': 'detalles_plan',
      'tipo': 'binario',
      'pregunta':
          '¿Has empezado a pensar en los detalles de cómo hacerlo? ¿Sientes que de verdad quieres o planeas llevarlo a cabo?',
    },
  ];

  // Opciones Likert estándar PHQ-9
  static const List<Map<String, dynamic>> _likert4 = [
    {'valor': 0, 'etiqueta': 'Ningún día', 'color': Color(0xFF43A047)},
    {'valor': 1, 'etiqueta': 'Varios días', 'color': Color(0xFFFDD835)},
    {
      'valor': 2,
      'etiqueta': 'Más de la mitad de los días',
      'color': Color(0xFFFF7043),
    },
    {'valor': 3, 'etiqueta': 'Casi todos los días', 'color': Color(0xFFE53935)},
  ];

  @override
  void initState() {
    super.initState();
    _loadPreguntas();
  }

  Future<void> _loadPreguntas() async {
    final result = await User().getCuestionarioConfig(modulo: 'suicidio');
    if (!mounted) return;

    final data = result['data'];
    final rawQuestions = data is Map ? data['preguntas'] : null;
    if (result['success'] == true &&
        rawQuestions is List &&
        rawQuestions.isNotEmpty) {
      final defaultsById = {
        for (final question in _defaultPreguntas)
          question['id'] as String: Map<String, dynamic>.from(question),
      };
      final loaded = rawQuestions
          .whereType<Map>()
          .map((raw) {
            final codigo = raw['codigo']?.toString() ?? '';
            final base = defaultsById[codigo] ?? <String, dynamic>{};
            return {
              ...base,
              'bloque': raw['bloque']?.toString() ?? base['bloque'] ?? 'PHQ9',
              'bloque_nombre':
                  base['bloque_nombre'] ??
                  (raw['bloque'] == 'CSSRS'
                      ? 'Ideación Suicida (C-SSRS)'
                      : 'Depresión y Riesgo (PHQ-9)'),
              'numero': raw['numero'] is int
                  ? raw['numero']
                  : int.tryParse(raw['numero']?.toString() ?? '') ??
                        base['numero'] ??
                        0,
              'id': codigo,
              'tipo':
                  raw['tipo_respuesta']?.toString() ??
                  base['tipo'] ??
                  'binario',
              'pregunta': raw['pregunta']?.toString() ?? base['pregunta'] ?? '',
              'puntaje': raw['puntaje'] is int
                  ? raw['puntaje']
                  : int.tryParse(raw['puntaje']?.toString() ?? '') ?? 0,
            };
          })
          .where((question) => (question['id'] as String).isNotEmpty)
          .toList();

      loaded.sort((a, b) => (a['numero'] as int).compareTo(b['numero'] as int));
      setState(() {
        _preguntas = loaded;
        _cargandoPreguntas = false;
      });
      return;
    }

    setState(() => _cargandoPreguntas = false);
  }

  // ── Lógica de respuesta ───────────────────────────────────────────────────
  void _responder(int valor, String etiqueta) {
    final p = _preguntas[_currentIndex];
    _respuestas[p['id'] as String] = {
      'numero': p['numero'],
      'bloque': p['bloque'],
      'id': p['id'],
      'pregunta': p['pregunta'],
      'tipo_respuesta': p['tipo'],
      'puntaje_configurado': p['puntaje'] ?? 0,
      'respuesta_valor': valor,
      'respuesta_etiqueta': etiqueta,
    };

    if (_currentIndex < 8) {
      // Avanzar al siguiente de PHQ-9 Likert
      setState(() => _currentIndex++);
    } else {
      // Llegamos al índice 8 (última pregunta Likert).
      // Al responder, avanzamos a 9 y activamos la fase de swipe.
      setState(() => _currentIndex++);
    }
  }

  Future<void> _finalizarYEnviar() async {
    setState(() => _enviando = true);

    final phq9Reactivos =
        _respuestas.values.where((r) => r['bloque'] == 'PHQ9').toList()
          ..sort((a, b) => (a['numero'] as int).compareTo(b['numero'] as int));

    final cssrsReactivos =
        _respuestas.values.where((r) => r['bloque'] == 'CSSRS').toList()
          ..sort((a, b) => (a['numero'] as int).compareTo(b['numero'] as int));

    // Puntuación PHQ-9: suma de preguntas 1-9 (likert4)
    final phq9Score = phq9Reactivos
        .where((r) => r['tipo_respuesta'] == 'likert4')
        .fold<int>(0, (sum, r) => sum + (r['respuesta_valor'] as int));

    // Puntuación C-SSRS: cantidad de "Sí" (se conserva como referencia, pero
    // el nivel de riesgo real NO se decide por este conteo, ver más abajo).
    final cssrsScore = cssrsReactivos.fold<int>(
      0,
      (sum, r) =>
          sum +
          ((r['respuesta_valor'] as int) *
              ((r['puntaje_configurado'] as int?) ?? 1)),
    );
    final nivelCssrs = nivelCssrsPorDominio(cssrsReactivos);

    final payload = {
      'tipo_cuestionario': 'suicidio',
      'fecha_aplicacion': DateTime.now().toUtc().toIso8601String(),
      'phq9_score': phq9Score,
      'cssrs_score': cssrsScore,
      'cssrs_nivel_dominio': nivelCssrs.name,
      'bloques': [
        {
          'bloque': 'PHQ9',
          'nombre': 'Depresión y Riesgo (PHQ-9)',
          'puntuacion_total': phq9Score,
          'reactivos': phq9Reactivos,
        },
        {
          'bloque': 'CSSRS',
          'nombre': 'Ideación Suicida (C-SSRS)',
          'puntuacion_total': cssrsScore,
          'nivel_dominio': nivelCssrs.name,
          'reactivos': cssrsReactivos,
        },
      ],
    };

    // Guardar localmente
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cuestionario_suicidio', jsonEncode(payload));
    await prefs.setBool('cuestionario_suicidio_completado', true);
    await prefs.setBool('modulo_suicidio_completado', true);
    final perfilTipo = prefs.getString('perfil_tipo') ?? 'estudiante';
    final idUsuario = prefs.getInt('id_usuario');
    if (idUsuario != null) {
      await prefs.setBool(
        'modulo_suicidio_completado_${perfilTipo}_$idUsuario',
        true,
      );
    }

    // Enviar al backend
    final userService = User();
    final resultado = await userService.updateCuestionario(
      tipoCuestionario: 'suicidio',
      respuestas: payload,
    );
    debugPrint('Backend cuestionario suicidio: $resultado');

    if (!mounted) return;
    setState(() => _enviando = false);

    _mostrarResultado(phq9Score, cssrsScore, nivelCssrs);
  }

  void _mostrarResultado(
    int phq9Score,
    int cssrsScore,
    NivelCssrs nivelCssrs,
  ) {
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    String nivel = 'Mínimo';
    Color nivelColor = const Color(0xFF43A047);
    if (phq9Score >= 20) {
      nivel = 'Severo';
      nivelColor = const Color(0xFFE53935);
    } else if (phq9Score >= 15) {
      nivel = 'Moderadamente severo';
      nivelColor = const Color(0xFFFF7043);
    } else if (phq9Score >= 10) {
      nivel = 'Moderado';
      nivelColor = const Color(0xFFFDD835);
    } else if (phq9Score >= 5) {
      nivel = 'Leve';
      nivelColor = const Color(0xFF8BC34A);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E272E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF43A047),
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              'Cuestionario completado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _ScoreRow(
              label: 'PHQ-9',
              score: '$phq9Score / 27',
              extra: nivel,
              color: nivelColor,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _ScoreRow(
              label: 'C-SSRS',
              score: '$cssrsScore / 5',
              extra: nivelCssrs.etiqueta,
              color: nivelCssrs.color,
              isDark: isDark,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const Principal()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
              ),
              child: const Text('Finalizar'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSwipePhase(BuildContext context) {
    if (_enviando) {
      final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFFAFAFA),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF5C6BC0)),
              const SizedBox(height: 16),
              Text(
                'Guardando respuestas...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    const cardGradients = [
      [Color(0xFF1565C0), Color(0xFF42A5F5)], // azul profundo
      [Color(0xFF283593), Color(0xFF5C6BC0)], // índigo
      [Color(0xFF00695C), Color(0xFF26A69A)], // teal
      [Color(0xFF6A1B9A), Color(0xFFAB47BC)], // violeta
      [Color(0xFF37474F), Color(0xFF78909C)], // gris azulado
      [Color(0xFF1B5E20), Color(0xFF66BB6A)], // verde oscuro
      [Color(0xFF4A148C), Color(0xFF7E57C2)], // púrpura
      [Color(0xFF0D47A1), Color(0xFF29B6F6)], // azul cielo
    ];
    final binaryQuestions = _preguntas.sublist(9).map((p) {
      final idx = _preguntas.indexOf(p);
      final bloque = p['bloque'] as String;
      final bloqueNombre = p['bloque_nombre'] as String;
      final numero = p['numero'];
      final grad = cardGradients[idx % cardGradients.length];

      return {
        'id': p['id'],
        'text': p['pregunta'],
        'section': bloque == 'PHQ9'
            ? '$bloqueNombre · Pregunta $numero'
            : 'C-SSRS · Ideación suicida · Pregunta $numero',
        'gradient': grad,
      };
    }).toList();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => setState(() => _currentIndex = 8),
        ),
      ),
      body: PasoIdentificacion(
        questions: binaryQuestions,
        headerTitle: '',
        instructionTitle: 'Preguntas de Sí o No',
        instructionDescription:
            'Aquí responderás las preguntas finales de PHQ-9 y luego el bloque de ideación suicida C-SSRS. Desliza a la derecha para Sí y a la izquierda para No.',
        readyButtonText: '¡Entendido!',
        rightSwipeLabel: 'SÍ',
        leftSwipeLabel: 'NO',
        rightMeaning: 'Sí, me ha pasado',
        leftMeaning: 'No, nunca',
        accentColor: const Color(0xFF5C6BC0),
        completionMessage: 'Procesando resultados...',
        onCompleted: (resultados) {
          // Llenar _respuestas con los resultados del swipe
          for (int i = 9; i < _preguntas.length; i++) {
            final p = _preguntas[i];
            final pId = p['id'] as String;
            final valor = resultados[pId] == true ? 1 : 0;
            final etiqueta = resultados[pId] == true ? 'Sí' : 'No';

            _respuestas[pId] = {
              'numero': p['numero'],
              'bloque': p['bloque'],
              'id': pId,
              'pregunta': p['pregunta'],
              'tipo_respuesta': p['tipo'],
              'puntaje_configurado': p['puntaje'] ?? 0,
              'respuesta_valor': valor,
              'respuesta_etiqueta': etiqueta,
            };
          }
          _finalizarYEnviar();
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_cargandoPreguntas) {
      final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFFAFAFA),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentIndex >= 9) {
      return _buildSwipePhase(context);
    }

    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);
    final total = _preguntas.length;
    final pregunta = _preguntas[_currentIndex];
    final bloque = pregunta['bloque'] as String;
    final tipo = pregunta['tipo'] as String;
    final isCssrs = bloque == 'CSSRS';
    final bloqueColor = isCssrs
        ? const Color(0xFF5C6BC0)
        : const Color(0xFF43A047);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentIndex > 0
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () => setState(() => _currentIndex--),
              )
            : null,
        title: Text(
          '$bloque  ·  ${_currentIndex + 1} / $total',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        centerTitle: true,
      ),
      body: _enviando
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF43A047)),
                  const SizedBox(height: 16),
                  Text(
                    'Enviando respuestas...',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Barra de progreso
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / total,
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  valueColor: AlwaysStoppedAnimation<Color>(bloqueColor),
                  minHeight: 4,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Chip de bloque
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: bloqueColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text.rich(
                            italicAcronyms(
                              pregunta['bloque_nombre'] as String,
                              TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: bloqueColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Pregunta ${pregunta['numero']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pregunta['pregunta'] as String,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Opciones de respuesta
                        if (tipo == 'likert4')
                          ..._likert4.map(
                            (op) => _OptionButton(
                              label: op['etiqueta'] as String,
                              value: op['valor'] as int,
                              color: op['color'] as Color,
                              isDark: isDark,
                              isSelected:
                                  _respuestas[pregunta['id']]?['respuesta_valor'] ==
                                  op['valor'],
                              onTap: () => _responder(
                                op['valor'] as int,
                                op['etiqueta'] as String,
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: _BinaryButton(
                                  label: 'No',
                                  color: const Color(0xFF5C6BC0),
                                  isDark: isDark,
                                  isSelected:
                                      _respuestas[pregunta['id']]?['respuesta_valor'] ==
                                      0,
                                  onTap: () => _responder(0, 'No'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _BinaryButton(
                                  label: 'Sí',
                                  color: const Color(0xFF43A047),
                                  isDark: isDark,
                                  isSelected:
                                      _respuestas[pregunta['id']]?['respuesta_valor'] ==
                                      1,
                                  onTap: () => _responder(1, 'Sí'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Widgets reutilizables ────────────────────────────────────────────────────

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (isDark ? const Color(0xFF1E272E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _BinaryButton extends StatelessWidget {
  const _BinaryButton({
    required this.label,
    required this.color,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (isDark ? const Color(0xFF1E272E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}

enum NivelCssrs { sinRiesgo, ideacion, planeacion, planConcreto }

extension NivelCssrsUi on NivelCssrs {
  String get etiqueta {
    switch (this) {
      case NivelCssrs.sinRiesgo:
        return 'Sin indicadores';
      case NivelCssrs.ideacion:
        return 'Ideación';
      case NivelCssrs.planeacion:
        return 'Riesgo alto: planeación';
      case NivelCssrs.planConcreto:
        return 'Riesgo alto: plan concreto';
    }
  }

  Color get color {
    switch (this) {
      case NivelCssrs.sinRiesgo:
        return const Color(0xFF43A047);
      case NivelCssrs.ideacion:
        return const Color(0xFFFDD835);
      case NivelCssrs.planeacion:
      case NivelCssrs.planConcreto:
        return const Color(0xFFE53935);
    }
  }
}

// C-SSRS validado en población mexicana (Austria-Corrales et al., 2023): la
// severidad la determina cuál dominio jerárquico se activa (ideación <
// planeación < plan concreto), no la cantidad de reactivos marcados "Sí".
// Cualquier respuesta afirmativa en planeación o plan concreto escala
// directo a riesgo alto, sin importar cómo se respondan las demás preguntas.
NivelCssrs nivelCssrsPorDominio(List<Map<String, dynamic>> cssrsReactivos) {
  bool endosado(String id) => cssrsReactivos.any(
    (r) => r['id'] == id && (r['respuesta_valor'] as int) > 0,
  );

  if (endosado('detalles_plan')) return NivelCssrs.planConcreto;
  if (endosado('como_lo_haria') || endosado('intencion_llevarlo')) {
    return NivelCssrs.planeacion;
  }
  if (endosado('desear_muerto') || endosado('idea_suicidarse')) {
    return NivelCssrs.ideacion;
  }
  return NivelCssrs.sinRiesgo;
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.score,
    required this.extra,
    required this.color,
    required this.isDark,
  });

  final String label;
  final String score;
  final String extra;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              Text(extra, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
