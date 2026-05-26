import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme_provider.dart';

class PasoEscalaAutolesion extends StatefulWidget {
  final Function(Map<String, int>) onCompleted;

  const PasoEscalaAutolesion({super.key, required this.onCompleted});

  @override
  State<PasoEscalaAutolesion> createState() => _PasoEscalaAutolesionState();
}

class _PasoEscalaAutolesionState extends State<PasoEscalaAutolesion> {
  int _currentQuestionIndex = 0;
  final Map<String, int> _respuestas = {};

  final List<Map<String, dynamic>> _preguntas = [
    {
      'id': 'alivio_emocional',
      'pregunta':
          '¿Has sentido ganas de lastimarte para aliviar emociones intensas?',
      'emoji': '🌧️',
      'color': const Color(0xFF00897B),
    },
    {
      'id': 'danio_sin_intencion',
      'pregunta':
          '¿Te has hecho daño sin intención de morir, pero buscando calmarte?',
      'emoji': '🩹',
      'color': const Color(0xFF26A69A),
    },
    {
      'id': 'impulso_recurrente',
      'pregunta': '¿Te cuesta detener el impulso de hacerte daño?',
      'emoji': '⚡',
      'color': const Color(0xFF00ACC1),
    },
    {
      'id': 'ocultar_senales',
      'pregunta': '¿Has intentado ocultar heridas, marcas o moretones?',
      'emoji': '🫥',
      'color': const Color(0xFF5C6BC0),
    },
    {
      'id': 'alivio_momentaneo',
      'pregunta':
          '¿Después de lastimarte sientes alivio momentáneo y luego malestar?',
      'emoji': '🔄',
      'color': const Color(0xFF7E57C2),
    },
    {
      'id': 'apoyo',
      'pregunta':
          '¿Sientes que te ayudaría hablar con alguien de confianza o buscar apoyo profesional?',
      'emoji': '🤝',
      'color': const Color(0xFF8E24AA),
    },
  ];

  final List<Map<String, dynamic>> _opciones = [
    {'valor': 0, 'texto': 'Nunca', 'emoji': '✅', 'color': const Color(0xFF4CAF50)},
    {'valor': 1, 'texto': 'Rara vez', 'emoji': '🟢', 'color': const Color(0xFF8BC34A)},
    {'valor': 2, 'texto': 'A veces', 'emoji': '🟡', 'color': const Color(0xFFFFC107)},
    {'valor': 3, 'texto': 'Frecuentemente', 'emoji': '🟠', 'color': const Color(0xFFFF9800)},
    {'valor': 4, 'texto': 'Muy frecuentemente', 'emoji': '🔴', 'color': const Color(0xFFF44336)},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showIntroDialog();
    });
  }

  void _showIntroDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDarkMode =
            Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.volunteer_activism,
                  size: 40,
                  color: Color(0xFF00897B),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Respira y responde con calma',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Estas preguntas nos ayudan a entender si has estado usando el daño físico como una forma de manejar emociones difíciles.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF26A69A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: Color(0xFF26A69A), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tus respuestas son privadas y sirven para orientarte mejor.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Piensa en cómo te has sentido recientemente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white60 : Colors.black45,
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  elevation: 3,
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  void _selectOption(int valor) {
    setState(() {
      _respuestas[_preguntas[_currentQuestionIndex]['id']] = valor;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_currentQuestionIndex < _preguntas.length - 1) {
        setState(() {
          _currentQuestionIndex++;
        });
      } else {
        _finalizarCuestionario();
      }
    });
  }

  void _finalizarCuestionario() {
    final puntuacionTotal =
        _respuestas.values.fold(0, (sum, value) => sum + value);
    _mostrarMensajeFinal(puntuacionTotal);
  }

  void _mostrarMensajeFinal(int puntuacion) {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    String nivel;
    String mensaje;
    Color color;
    IconData icono;

    if (puntuacion <= 4) {
      nivel = 'Malestar bajo';
      mensaje =
          'No se observan señales intensas en este momento. Aun así, cuidar tus emociones sigue siendo importante.';
      color = const Color(0xFF4CAF50);
      icono = Icons.check_circle;
    } else if (puntuacion <= 9) {
      nivel = 'Atención temprana';
      mensaje =
          'Hay señales que merecen escucha y acompañamiento. Hablar con alguien de confianza puede ayudarte.';
      color = const Color(0xFFFFC107);
      icono = Icons.info;
    } else if (puntuacion <= 15) {
      nivel = 'Apoyo recomendado';
      mensaje =
          'Sería valioso buscar apoyo psicológico para aprender formas más seguras de manejar el malestar.';
      color = const Color(0xFFFF9800);
      icono = Icons.support_agent;
    } else {
      nivel = 'Atención prioritaria';
      mensaje =
          'Es importante buscar ayuda profesional lo antes posible. Si existe riesgo inmediato, acude a emergencias.';
      color = const Color(0xFFF44336);
      icono = Icons.warning_amber_rounded;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, size: 50, color: color),
              ),
              const SizedBox(height: 15),
              Text(
                'Gracias por responder',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Text(
                      nivel,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mensaje,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onCompleted(_respuestas);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text(
                  'Finalizar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final question = _preguntas[_currentQuestionIndex];
    final color = question['color'] as Color;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _preguntas.length,
            backgroundColor: isDarkMode ? Colors.white12 : Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(10),
            minHeight: 10,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  if (!isDarkMode)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${question['emoji']}  Pregunta ${_currentQuestionIndex + 1}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    question['pregunta'] as String,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const Spacer(),
                  ..._opciones.map(
                    (opcion) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _selectOption(opcion['valor'] as int),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: (opcion['color'] as Color).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color:
                                  (opcion['color'] as Color).withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                opcion['emoji'] as String,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  opcion['texto'] as String,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 18,
                                color: (opcion['color'] as Color),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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