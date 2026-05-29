import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';

class PasoEscalaSuicida extends StatefulWidget {
  final Function(Map<String, int>) onCompleted;

  const PasoEscalaSuicida({super.key, required this.onCompleted});

  @override
  State<PasoEscalaSuicida> createState() => _PasoEscalaSuicidaState();
}

class _PasoEscalaSuicidaState extends State<PasoEscalaSuicida> {
  int _currentQuestionIndex = 0;
  final Map<String, int> _respuestas = {};

  // Preguntas C-SSRS compartidas por el usuario
  final List<Map<String, dynamic>> _preguntas = [
    {
      'id': 'desear_muerto',
      'pregunta': '¿Ha deseado estar muerto(a) o poder dormirse y no despertar?',
      'emoji': '🌫️',
      'color': const Color(0xFF6A1B9A),
    },
    {
      'id': 'idea_suicidarse',
      'pregunta': '¿Ha tenido realmente la idea de suicidarse?',
      'emoji': '💭',
      'color': const Color(0xFF5E35B1),
    },
    {
      'id': 'como_lo_haria',
      'pregunta': '¿Ha pensado en cómo llevaría esto a cabo?',
      'emoji': '🧭',
      'color': const Color(0xFF3949AB),
    },
    {
      'id': 'intencion_llevarlo',
      'pregunta': '¿Ha tenido estas ideas y en cierto grado la intención de llevarlas a cabo?',
      'emoji': '⚠️',
      'color': const Color(0xFF1E88E5),
    },
    {
      'id': 'detalles_plan',
      'pregunta': '¿Ha comenzado a elaborar los detalles sobre cómo suicidarse? ¿Tiene intención de llevar a cabo ese plan?',
      'emoji': '🚨',
      'color': const Color(0xFFE53935),
    },
  ];

  // Opciones de respuesta con escala 0-4
  final List<Map<String, dynamic>> _opciones = [
    {'valor': 0, 'texto': 'Nunca', 'emoji': '🌤️', 'color': const Color(0xFF4CAF50)},
    {'valor': 1, 'texto': 'Casi nunca', 'emoji': '🟢', 'color': const Color(0xFF8BC34A)},
    {'valor': 2, 'texto': 'A veces', 'emoji': '🟡', 'color': const Color(0xFFFFC107)},
    {'valor': 3, 'texto': 'Muchas veces', 'emoji': '🟠', 'color': const Color(0xFFFF9800)},
    {'valor': 4, 'texto': 'Casi siempre', 'emoji': '🔴', 'color': const Color(0xFFF44336)},
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
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        final isDarkMode = themeProvider.isDarkMode;
        
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 40,
                  color: Color(0xFF43A047),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                "Un momento importante",
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
                "Este segundo bloque profundiza en la ideación suicida reciente con preguntas más directas.",
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
                  color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: Color(0xFF2196F3), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Tus respuestas son confidenciales y ayudan a valorar mejor el nivel de urgencia.",
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
                "Responde pensando en lo más reciente.",
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
                  backgroundColor: const Color(0xFF43A047),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  elevation: 3,
                ),
                child: const Text(
                  "Estoy listo/a",
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
    // Calcular puntuación total
    int puntuacionTotal = _respuestas.values.fold(0, (sum, value) => sum + value);
    
    // Mostrar mensaje de finalización con el nivel de riesgo
    _mostrarMensajeFinal(puntuacionTotal);
  }

  void _mostrarMensajeFinal(int puntuacion) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    String nivel;
    String mensaje;
    Color color;
    IconData icono;

    if (puntuacion == 0) {
      nivel = "Sin riesgo detectado";
      mensaje = "¡Excelente! No identificamos señales de riesgo.";
      color = const Color(0xFF4CAF50);
      icono = Icons.check_circle;
    } else if (puntuacion <= 4) {
      nivel = "Riesgo bajo";
      mensaje = "Es normal tener altibajos. Estamos aquí para apoyarte.";
      color = const Color(0xFF8BC34A);
      icono = Icons.info;
    } else if (puntuacion <= 9) {
      nivel = "Riesgo moderado";
      mensaje = "Te recomendamos hablar con alguien de confianza.";
      color = const Color(0xFFFFC107);
      icono = Icons.warning;
    } else if (puntuacion <= 15) {
      nivel = "Riesgo alto";
      mensaje = "Es importante que busques apoyo profesional pronto.";
      color = const Color(0xFFFF9800);
      icono = Icons.priority_high;
    } else {
      nivel = "Riesgo muy alto";
      mensaje = "Por favor, busca ayuda profesional de inmediato.";
      color = const Color(0xFFF44336);
      icono = Icons.emergency;
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
                child: Icon(
                  icono,
                  size: 50,
                  color: color,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                "Gracias por tu honestidad",
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
              if (puntuacion > 4) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.phone, color: const Color(0xFF2196F3), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "Líneas de ayuda 24/7:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                          "• Línea de la Vida: 800 911 2000\n• SAPTEL: 55 5259 8121\n• WhatsApp SAPTEL: 55 1997 3337",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
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
                  Navigator.of(context).pop();
                  widget.onCompleted(_respuestas);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  elevation: 3,
                ),
                child: const Text(
                  "Continuar",
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final preguntaActual = _preguntas[_currentQuestionIndex];
    final progreso = (_currentQuestionIndex + 1) / _preguntas.length;
    final colorPregunta = preguntaActual['color'] as Color;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de progreso
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Pregunta ${_currentQuestionIndex + 1} de ${_preguntas.length}",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      Text(
                        "${(progreso * 100).toInt()}%",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorPregunta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progreso,
                      backgroundColor: isDarkMode ? Colors.white12 : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(colorPregunta),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Tarjeta de pregunta - SIMPLIFICADA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey(preguntaActual['id'] as String),
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [const Color(0xFF2C3E50), const Color(0xFF1E272E)]
                          : [colorPregunta.withValues(alpha: 0.92), colorPregunta.withValues(alpha: 0.65)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: colorPregunta.withValues(alpha: isDarkMode ? 0.15 : 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          preguntaActual['emoji'] as String,
                          style: const TextStyle(fontSize: 52),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        preguntaActual['pregunta'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Responde según lo más reciente',
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Opciones de respuesta
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: _opciones.map((opcion) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildOptionButton(
                        texto: opcion['texto'] as String,
                        emoji: opcion['emoji'] as String,
                        color: opcion['color'] as Color,
                        valor: opcion['valor'] as int,
                        isDarkMode: isDarkMode,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String texto,
    required String emoji,
    required Color color,
    required int valor,
    required bool isDarkMode,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectOption(valor),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C3E50) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.5),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}