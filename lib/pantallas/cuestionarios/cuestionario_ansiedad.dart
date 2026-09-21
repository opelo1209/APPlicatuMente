import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aptm/text_utils.dart';
import '../theme_provider.dart';
import '../principal.dart';
import 'dart:convert';

import '../servicios/user.dart';

class CuestionarioAnsiedad extends StatefulWidget {
  const CuestionarioAnsiedad({super.key});

  @override
  State<CuestionarioAnsiedad> createState() => _CuestionarioAnsiedadState();
}

class _CuestionarioAnsiedadState extends State<CuestionarioAnsiedad> {
  int _currentIndex = 0;
  final Map<String, Map<String, dynamic>> _respuestas = {};
  bool _enviando = false;
  bool _cargandoPreguntas = true;
  late List<Map<String, dynamic>> _preguntas = List<Map<String, dynamic>>.from(
    _defaultPreguntas,
  );

  // ── Definición de todas las preguntas ─────────────────────────────────────
  static const List<Map<String, dynamic>> _defaultPreguntas = [
    {
      'bloque': 'GAD7',
      'bloque_nombre': 'Ansiedad',
      'numero': 1,
      'id': 'nervioso',
      'tipo': 'likert4',
      'pregunta':
          '¿Te has sentido nervioso(a), ansioso(a) o con los nervios de punta?',
    },
    {
      'bloque': 'GAD7',
      'bloque_nombre': 'Ansiedad',
      'numero': 2,
      'id': 'no_controlar_preocupacion',
      'tipo': 'likert4',
      'pregunta':
          '¿No has podido parar o controlar tus preocupaciones?',
    },
    {
      'bloque': 'GAD7',
      'bloque_nombre': 'Ansiedad',
      'numero': 3,
      'id': 'preocupacion_excesiva',
      'tipo': 'likert4',
      'pregunta':
          '¿Te has preocupado demasiado por diferentes cosas?',
    },
    {
      'bloque': 'GAD7',
      'bloque_nombre': 'Ansiedad',
      'numero': 4,
      'id': 'dificil_relajarse',
      'tipo': 'likert4',
      'pregunta':
          '¿Te ha costado trabajo relajarte?',
    },
    {
      'bloque': 'GAD7',
      'bloque_nombre': 'Ansiedad',
      'numero': 5,
      'id': 'inquietud',
      'tipo': 'likert4',
      'pregunta': '¿Has estado tan inquieto(a) que te cuesta quedarte quieto(a)?',
    },
    {
      'bloque': 'GAD7',
      'bloque_nombre': 'Ansiedad',
      'numero': 6,
      'id': 'irritabilidad',
      'tipo': 'likert4',
      'pregunta':
          '¿Te has molestado o irritado fácilmente?',
    },
    {
      'bloque': 'GAD7',
      'bloque_nombre': 'Ansiedad',
      'numero': 7,
      'id': 'miedo',
      'tipo': 'likert4',
      'pregunta':
          '¿¿Has sentido miedo como si algo terrible pudiera pasar?',
    },
  ];

  // Opciones Likert estándar PHQ-9
  static const List<Map<String, dynamic>> _likert4 = [
    {
      'valor': 0,
      'etiqueta': 'Casi nunca o nunca es cierto',
      'color': Color(0xFF43A047)
      },
    {
      'valor': 1,
      'etiqueta': 'Es cierto algunas veces',
      'color': Color(0xFFFDD835)
    },
    {
      'valor': 2,
      'etiqueta': 'Casi siempre es cierto  ',
      'color': Color(0xFFFF7043),
    },{
      'valor': 3,
      'etiqueta': 'Siempre es cierto  ',
      'color': Color(0xFFE53935),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPreguntas();
  }

  Future<void> _loadPreguntas() async {
    final result = await User().getCuestionarioConfig(modulo: 'ansiedad');
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

    if (_currentIndex < _preguntas.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _finalizarYEnviar();
    }
  }

  //Conteo de puntaje 
  Future<void> _finalizarYEnviar() async {
    setState(() => _enviando = true);

    final gad7Reactivos =
        _respuestas.values.where((r) => r['bloque'] == 'GAD7').toList()
          ..sort((a, b) => (a['numero'] as int).compareTo(b['numero'] as int));

    // Puntuación GAD7: suma de preguntas (likert4)
    final gad7Score = gad7Reactivos
        .where((r) => r['tipo_respuesta'] == 'likert4')
        .fold<int>(0, (sum, r) => sum + (r['respuesta_valor'] as int));


    final payload = {
      'tipo_cuestionario': 'ansiedad',
      'fecha_aplicacion': DateTime.now().toUtc().toIso8601String(),
      'gad7_score': gad7Score,
      'bloques': [
        {
          'bloque': 'GAD7',
          'nombre': 'Ansiedad',
          'puntuacion_total': gad7Score,
          'reactivos': gad7Reactivos,
        },
      ],
    };

    // Guardar localmente
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cuestionario_ansiedad', jsonEncode(payload));
    await prefs.setBool('cuestionario_ansiedad_completado', true);
    await prefs.setBool('modulo_ansiedad_completado', true);
    final perfilTipo = prefs.getString('perfil_tipo') ?? 'estudiante';
    final idUsuario = prefs.getInt('id_usuario');
    if (idUsuario != null) {
      await prefs.setBool(
        'modulo_ansiedad_completado_${perfilTipo}_$idUsuario',
        true,
      );
    }

    // Enviar al backend
    final userService = User();
    final resultado = await userService.updateCuestionario(
      tipoCuestionario: 'ansiedad',
      respuestas: payload,
    );
    debugPrint('Backend cuestionario ansiedad: $resultado');

    if (!mounted) return;
    setState(() => _enviando = false);

    _mostrarResultado(gad7Score);
  }

  void _mostrarResultado(int gad7Score) {
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    //FALTA AJUSTAR ESTA ESCALA
    String nivel = 'Mínimo';
    Color nivelColor = const Color(0xFF43A047);
    if (gad7Score >= 14) {
      nivel = 'Severo';
      nivelColor = const Color(0xFFE53935);
    } else if (gad7Score >= 10) {
      nivel = 'Moderadamente severo';
      nivelColor = const Color(0xFFFF7043);
    } else if (gad7Score >= 5) {
      nivel = 'Moderado';
      nivelColor = const Color(0xFFFDD835);
    } else if (gad7Score >= 1) {
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
              label: 'GAD7',
              //FALTA AJUSTAR ESTE PARÁMETRO
              score: '$gad7Score / 27',
              extra: nivel,
              color: nivelColor,
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
  @override
  Widget build(BuildContext context) {
    if (_cargandoPreguntas) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final pregunta = _preguntas[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pregunta ${_currentIndex + 1} de ${_preguntas.length}',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              pregunta['pregunta'],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

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
            ),
          ],
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