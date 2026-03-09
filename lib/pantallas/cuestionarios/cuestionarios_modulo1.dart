import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme_provider.dart';
import '../principal.dart';
import '../servicios/cuestionario_service.dart';
import 'paso_identificacion.dart'; // IMPORT PASO IDENTIFICACION

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

  // ── Definición de todas las preguntas ─────────────────────────────────────
  static const List<Map<String, dynamic>> _preguntas = [
    // PHQ-9 ── Preguntas 1-9 (Likert 0-3)
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 1,
      'id': 'deprimido_irritable',
      'tipo': 'likert4',
      'pregunta': '¿Te has sentido deprimido, irritado o sin esperanza?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 2,
      'id': 'poco_interes',
      'tipo': 'likert4',
      'pregunta': '¿Has sentido poco interés o placer para hacer cosas?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 3,
      'id': 'sueno',
      'tipo': 'likert4',
      'pregunta':
          '¿Tienes dificultad para dormirte, quedarte dormido, o duermes demasiado?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 4,
      'id': 'apetito',
      'tipo': 'likert4',
      'pregunta': '¿Tienes poco apetito, pérdida de peso, o comes demasiado?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 5,
      'id': 'cansancio',
      'tipo': 'likert4',
      'pregunta': '¿Te sientes cansado o tienes poca energía?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 6,
      'id': 'mal_consigo',
      'tipo': 'likert4',
      'pregunta':
          '¿Te sientes mal por ti mismo, o sientes que eres un fracasado, o que le has fallado a tu familia?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 7,
      'id': 'concentracion',
      'tipo': 'likert4',
      'pregunta':
          '¿Tienes problemas para concentrarte en tareas escolares, leer o ver televisión?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 8,
      'id': 'movimiento',
      'tipo': 'likert4',
      'pregunta':
          '¿Te mueves o hablas tan lentamente que otros pueden notarlo? ¿O al contrario, estás tan inquieto que te mueves más de lo usual?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 9,
      'id': 'mejor_muerto',
      'tipo': 'likert4',
      'pregunta':
          '¿Piensas que estarías mejor muerto o de hacerte daño a ti mismo de alguna manera?',
    },
    // PHQ-9 ── Preguntas 10-12 (binario)
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 10,
      'id': 'deprimido_anio',
      'tipo': 'binario',
      'pregunta':
          '¿En el año pasado te has sentido deprimido o triste la mayoría de los días?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 11,
      'id': 'pensar_terminar',
      'tipo': 'binario',
      'pregunta':
          '¿En el mes pasado hubo algún momento donde pensaste seriamente en terminar con tu vida?',
    },
    {
      'bloque': 'PHQ9',
      'bloque_nombre': 'Depresión y Riesgo (PHQ-9)',
      'numero': 12,
      'id': 'intento_suicidio',
      'tipo': 'binario',
      'pregunta': '¿Alguna vez en tu vida, trataste de matarte o suicidarte?',
    },
    // C-SSRS ── 5 preguntas (binario)
    {
      'bloque': 'CSSRS',
      'bloque_nombre': 'Ideación Suicida (C-SSRS)',
      'numero': 1,
      'id': 'desear_muerto',
      'tipo': 'binario',
      'pregunta':
          '¿Ha deseado estar muerto(a) o poder dormirse y no despertar?',
    },
    {
      'bloque': 'CSSRS',
      'bloque_nombre': 'Ideación Suicida (C-SSRS)',
      'numero': 2,
      'id': 'idea_suicidarse',
      'tipo': 'binario',
      'pregunta': '¿Ha tenido realmente la idea de suicidarse?',
    },
    {
      'bloque': 'CSSRS',
      'bloque_nombre': 'Ideación Suicida (C-SSRS)',
      'numero': 3,
      'id': 'como_lo_haria',
      'tipo': 'binario',
      'pregunta': '¿Ha pensado en cómo llevaría esto a cabo?',
    },
    {
      'bloque': 'CSSRS',
      'bloque_nombre': 'Ideación Suicida (C-SSRS)',
      'numero': 4,
      'id': 'intencion_llevarlo',
      'tipo': 'binario',
      'pregunta':
          '¿Ha tenido estas ideas y en cierto grado la intención de llevarlas a cabo?',
    },
    {
      'bloque': 'CSSRS',
      'bloque_nombre': 'Ideación Suicida (C-SSRS)',
      'numero': 5,
      'id': 'detalles_plan',
      'tipo': 'binario',
      'pregunta':
          '¿Ha comenzado a elaborar los detalles sobre cómo suicidarse? ¿Tiene intención de llevar a cabo ese plan?',
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
    {
      'valor': 3,
      'etiqueta': 'Casi todos los días',
      'color': Color(0xFFE53935),
    },
  ];

  // ── Lógica de respuesta ───────────────────────────────────────────────────
  void _responder(int valor, String etiqueta) {
    final p = _preguntas[_currentIndex];
    _respuestas[p['id'] as String] = {
      'numero': p['numero'],
      'bloque': p['bloque'],
      'id': p['id'],
      'pregunta': p['pregunta'],
      'tipo_respuesta': p['tipo'],
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

    final phq9Reactivos = _respuestas.values
        .where((r) => r['bloque'] == 'PHQ9')
        .toList()
      ..sort((a, b) =>
          (a['numero'] as int).compareTo(b['numero'] as int));

    final cssrsReactivos = _respuestas.values
        .where((r) => r['bloque'] == 'CSSRS')
        .toList()
      ..sort((a, b) =>
          (a['numero'] as int).compareTo(b['numero'] as int));

    // Puntuación PHQ-9: suma de preguntas 1-9 (likert4)
    final phq9Score = phq9Reactivos
        .where((r) => r['tipo_respuesta'] == 'likert4')
        .fold<int>(0, (sum, r) => sum + (r['respuesta_valor'] as int));

    // Puntuación C-SSRS: cantidad de "Sí"
    final cssrsScore = cssrsReactivos.fold<int>(
        0, (sum, r) => sum + (r['respuesta_valor'] as int));

    final bloques = [
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
        'reactivos': cssrsReactivos,
      },
    ];

    final result = await CuestionarioService().enviarCuestionario(
      tipoCuestionario: 'suicidio',
      bloques: bloques,
    );

    if (!mounted) return;
    setState(() => _enviando = false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cuestionario_completado', true);

    _mostrarResultado(result, phq9Score, cssrsScore);
  }

  void _mostrarResultado(
      Map<String, dynamic> result, int phq9Score, int cssrsScore) {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              extra: cssrsScore == 0 ? 'Sin ideación' : 'Con ideación',
              color: cssrsScore == 0
                  ? const Color(0xFF43A047)
                  : const Color(0xFFE53935),
              isDark: isDark,
            ),
            if (!result['success']) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin conexión al servidor. Los datos se guardaron localmente.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                    borderRadius: BorderRadius.circular(30)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
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
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF5C6BC0)),
              const SizedBox(height: 16),
              Text(
                'Enviando respuestas...',
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
    final binaryQuestions = _preguntas.sublist(9).map((p) {
      final idx = _preguntas.indexOf(p);
      final imgIndex = (idx % 6) + 7;
      final ext = imgIndex >= 9 ? 'PNG' : 'png';
      final imagePath = 'assets/imagenes/quetzal_$imgIndex.$ext';
      final bloque = p['bloque'] as String;
      final bloqueNombre = p['bloque_nombre'] as String;
      final numero = p['numero'];

      return {
        'id': p['id'],
        'text': p['pregunta'],
        'image': imagePath, // Imagen para transmitir calma
        'section': bloque == 'PHQ9'
            ? '$bloqueNombre · Pregunta $numero'
            : 'Ideación suicida (C-SSRS) · Intensidad / historia reciente · Pregunta $numero',
        'gradient': [const Color(0xFF84FAB0), const Color(0xFF8FD3F4)],
      };
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
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
        headerTitle: 'Bloque Sí / No',
        instructionTitle: 'Preguntas de Sí o No',
        instructionDescription: 'Aquí responderás las preguntas finales de PHQ-9 y luego el bloque de ideación suicida C-SSRS. Desliza a la derecha para Sí y a la izquierda para No.',
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
    if (_currentIndex >= 9) {
      return _buildSwipePhase(context);
    }

    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);
    final total = _preguntas.length;
    final pregunta = _preguntas[_currentIndex];
    final bloque = pregunta['bloque'] as String;
    final tipo = pregunta['tipo'] as String;
    final isCssrs = bloque == 'CSSRS';
    final bloqueColor =
        isCssrs ? const Color(0xFF5C6BC0) : const Color(0xFF43A047);

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
                  const CircularProgressIndicator(
                      color: Color(0xFF43A047)),
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
                  backgroundColor:
                      isDark ? Colors.white12 : Colors.black12,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(bloqueColor),
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
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: bloqueColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            pregunta['bloque_nombre'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: bloqueColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Pregunta ${pregunta['numero']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white38
                                : Colors.black38,
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
                              isSelected: _respuestas[
                                          pregunta['id']]?[
                                      'respuesta_valor'] ==
                                  op['valor'],
                              onTap: () => _responder(
                                  op['valor'] as int,
                                  op['etiqueta'] as String),
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
                                  isSelected: _respuestas[
                                              pregunta['id']]?[
                                          'respuesta_valor'] ==
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
                                  isSelected: _respuestas[
                                              pregunta['id']]?[
                                          'respuesta_valor'] ==
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
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? Colors.white12 : Colors.black12),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withOpacity(0.25)
                  : Colors.black.withOpacity(isDark ? 0 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
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
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
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
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? Colors.white12 : Colors.black12),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withOpacity(0.30)
                  : Colors.black.withOpacity(isDark ? 0 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
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
        color: color.withOpacity(0.08),
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
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                extra,
                style: TextStyle(fontSize: 11, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
