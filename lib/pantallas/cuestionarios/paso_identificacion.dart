import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';

class PasoIdentificacion extends StatefulWidget {
  final Function(Map<String, bool>) onCompleted;
  final List<Map<String, dynamic>>? questions;
  final String headerTitle;
  final String instructionTitle;
  final String instructionDescription;
  final String readyButtonText;
  final String rightSwipeLabel;
  final String leftSwipeLabel;
  final String rightMeaning;
  final String leftMeaning;
  final Color accentColor;
  final String completionMessage;

  const PasoIdentificacion({
    super.key,
    required this.onCompleted,
    this.questions,
    this.headerTitle = 'Desliza las tarjetas',
    this.instructionTitle = '¿Cómo responder?',
    this.instructionDescription =
        'Desliza cada tarjeta según qué tanto te identifique la pregunta.',
    this.readyButtonText = '¡Entendido!',
    this.rightSwipeLabel = 'DERECHA',
    this.leftSwipeLabel = 'IZQUIERDA',
    this.rightMeaning = 'Sí me identifica',
    this.leftMeaning = 'No me identifica',
    this.accentColor = const Color(0xFF43A047),
    this.completionMessage = 'Guardando y continuando...',
  });

  @override
  State<PasoIdentificacion> createState() => _PasoIdentificacionState();
}

class _PasoIdentificacionState extends State<PasoIdentificacion> {
  final Map<String, bool> _resultados = {};
  int _currentIndex = 0;

  // Posición horizontal de arrastre (px)
  double _dragX = 0;

  // Preguntas por defecto si no se pasan externas
  List<Map<String, dynamic>> get _questions =>
      widget.questions ??
      [
        {
          'id': 'abrumado',
          'text': 'Me siento abrumado con frecuencia.',
          'gradient': [const Color(0xFFFF9A9E), const Color(0xFFFECFEF)],
        },
        {
          'id': 'concentracion',
          'text': 'Tengo dificultades para concentrarme.',
          'gradient': [const Color(0xFF84FAB0), const Color(0xFF8FD3F4)],
        },
        {
          'id': 'solitud',
          'text': 'Disfruto pasar tiempo a solas.',
          'gradient': [const Color(0xFFE0C3FC), const Color(0xFF8EC5FC)],
        },
        {
          'id': 'sueno',
          'text': 'Me cuesta conciliar el sueño.',
          'gradient': [const Color(0xFFFCCB90), const Color(0xFFD57EEB)],
        },
        {
          'id': 'comprension',
          'text': 'Siento que nadie me entiende.',
          'gradient': [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)],
        },
        {
          'id': 'esperanza',
          'text': 'Tengo esperanza en el futuro.',
          'gradient': [const Color(0xFF43A047), const Color(0xFF80CBC4)],
        },
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showInstructions();
    });
  }

  // ── Respuesta (sin animación bloqueante) ─────────────────────────────────
  void _processAnswer(bool isRight) {
    if (_currentIndex >= _questions.length) return;
    final id = _questions[_currentIndex]['id'] as String;
    _resultados[id] = isRight;
    final isLast = _currentIndex + 1 >= _questions.length;
    setState(() {
      _currentIndex++;
      _dragX = 0;
    });
    if (isLast) {
      // Post-frame para asegurar que el setState de arriba se confirme antes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCompleted(_resultados);
      });
    }
  }

  // ── Drag handlers ────────────────────────────────────────────────────────
  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _dragX += d.delta.dx);
  }

  void _onDragEnd(DragEndDetails d) {
    final w = MediaQuery.of(context).size.width;
    final velocity = d.primaryVelocity ?? 0;
    if (_dragX > w * 0.25 || velocity > 700) {
      _processAnswer(true);
    } else if (_dragX < -w * 0.25 || velocity < -700) {
      _processAnswer(false);
    } else {
      setState(() => _dragX = 0);
    }
  }

  void _handleManualSwipe(bool isRight) {
    if (_currentIndex >= _questions.length) return;
    _processAnswer(isRight);
  }

  // ── Instruction dialog ───────────────────────────────────────────────────
  void _showInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDarkMode =
            Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            widget.instructionTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 150,
                width: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/gif/swipe.gif',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.instructionDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              _buildInstructionRow(Icons.swipe_right_alt_rounded,
                  widget.rightSwipeLabel, widget.rightMeaning,
                  widget.accentColor, isDarkMode),
              const SizedBox(height: 5),
              _buildInstructionRow(Icons.swipe_left_alt_rounded,
                  widget.leftSwipeLabel, widget.leftMeaning,
                  Colors.redAccent, isDarkMode),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 12),
                ),
                child: Text(widget.readyButtonText),
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildInstructionRow(IconData icon, String direction, String meaning,
      Color color, bool isDarkMode) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          "$direction: ",
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 12, color: color),
        ),
        Expanded(
          child: Text(
            meaning,
            style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
      ],
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final primaryGreen = widget.accentColor;

    // Si ya se respondieron todas, muestra pantalla de transición
    if (_currentIndex >= _questions.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: primaryGreen),
            const SizedBox(height: 20),
            Text(
              '¡Gracias por tus respuestas!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.completionMessage,
              style: TextStyle(
                  color: isDarkMode ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final swipeProgress =
        (_dragX.abs() / (screenWidth * 0.3)).clamp(0.0, 1.0);

    return Column(
      children: [
        const SizedBox(height: 20),

        // ── Header ──────────────────────────────────────────────────────
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swipe_rounded, size: 22, color: primaryGreen),
              const SizedBox(width: 10),
              Text(
                widget.headerTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? Colors.white
                      : primaryGreen.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // ── Tarjeta ──────────────────────────────────────────────────────
        SizedBox(
          height: 420,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Indicador SÍ
              if (_dragX > 20)
                Positioned(
                  left: 30,
                  child: Opacity(
                    opacity: swipeProgress,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded,
                              color: Colors.white, size: 32),
                          const SizedBox(height: 4),
                          Text(
                            widget.rightMeaning,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Indicador NO
              if (_dragX < -20)
                Positioned(
                  right: 30,
                  child: Opacity(
                    opacity: swipeProgress,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.close_rounded,
                              color: Colors.white, size: 32),
                          const SizedBox(height: 4),
                          Text(
                            widget.leftMeaning,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Tarjeta arrastrable
              GestureDetector(
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: Transform(
                  transform: Matrix4.identity()
                    ..translate(_dragX, 0.0)
                    ..rotateZ(_dragX * 0.0008),
                  alignment: Alignment.center,
                  child: _buildCard(
                      _questions[_currentIndex], isDarkMode),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // ── Botones manuales ─────────────────────────────────────────────
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionButton(Icons.close, Colors.redAccent,
                  () => _handleManualSwipe(false)),
              _buildActionButton(Icons.check, primaryGreen,
                  () => _handleManualSwipe(true)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Card widget ──────────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> question, bool isDarkMode) {
    final text = question['text'] as String;
    final section = question['section'] as String?;
    final fontSize = text.length > 140
        ? 18.0
        : text.length > 90
            ? 21.0
            : 24.0;

    return Container(
      width: 330,
      height: 420,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color:
            isDarkMode ? const Color(0xFF1B1F24) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(isDarkMode ? 0.28 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _cardAccentColor(question, isDarkMode)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                section,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _cardAccentColor(question, isDarkMode),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _cardAccentColor(question, isDarkMode)
                  .withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.question_answer_rounded,
              color: _cardAccentColor(question, isDarkMode),
              size: 28,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    height: 1.3,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentIndex + 1} de ${_questions.length}',
              style: TextStyle(
                color: isDarkMode
                    ? Colors.white70
                    : Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _cardAccentColor(
      Map<String, dynamic> question, bool isDarkMode) {
    final gradient = question['gradient'] as List<Color>?;
    if (gradient != null && gradient.isNotEmpty) return gradient.first;
    return isDarkMode ? Colors.white70 : widget.accentColor;
  }

  Widget _buildActionButton(
      IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.24),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
          border:
              Border.all(color: color.withOpacity(0.16), width: 1.5),
        ),
        child: Icon(icon, color: color, size: 34),
      ),
    );
  }
}
