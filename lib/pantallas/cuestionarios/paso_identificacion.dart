import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aptm/text_utils.dart';
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
    final accentColor = widget.accentColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 48.0).clamp(0.0, 380.0);
    final swipeProgress = (_dragX.abs() / (screenWidth * 0.28)).clamp(0.0, 1.0);

    if (_currentIndex >= _questions.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: accentColor),
            const SizedBox(height: 20),
            Text(
              '¡Listo!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.completionMessage,
              style: TextStyle(
                  color: isDarkMode ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 20),

        // ── Barra de progreso ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _currentIndex / _questions.length,
                    minHeight: 5,
                    backgroundColor: isDarkMode ? Colors.white12 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_currentIndex + 1} / ${_questions.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white54 : Colors.black38,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // ── Stack de tarjetas ───────────────────────────────────────────
        SizedBox(
          height: 460,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              // Tarjeta fantasma (siguiente)
              if (_currentIndex + 1 < _questions.length)
                Positioned(
                  bottom: 0,
                  child: Transform.scale(
                    scale: 0.94,
                    alignment: Alignment.bottomCenter,
                    child: Opacity(
                      opacity: 0.6,
                      child: _buildCard(
                        _questions[_currentIndex + 1],
                        isDarkMode,
                        cardWidth,
                        0.0,
                        0.0,
                      ),
                    ),
                  ),
                ),

              // Tarjeta activa
              Positioned(
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..translateByDouble(_dragX, -_dragX.abs() * 0.04, 0.0, 1.0)
                      ..rotateZ(_dragX * 0.0014),
                    alignment: Alignment.bottomCenter,
                    child: _buildCard(
                      _questions[_currentIndex],
                      isDarkMode,
                      cardWidth,
                      swipeProgress,
                      _dragX,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // ── Botones manuales ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
          child: Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: widget.leftMeaning,
                  icon: Icons.close_rounded,
                  color: const Color(0xFFEF5350),
                  isDark: isDarkMode,
                  onTap: () => _handleManualSwipe(false),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  label: widget.rightMeaning,
                  icon: Icons.check_rounded,
                  color: accentColor,
                  isDark: isDarkMode,
                  onTap: () => _handleManualSwipe(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Card widget ──────────────────────────────────────────────────────────
  Widget _buildCard(
    Map<String, dynamic> question,
    bool isDarkMode,
    double cardWidth,
    double swipeProgress,
    double dragX,
  ) {
    final rawGradient = question['gradient'] as List<dynamic>?;
    final gradColors = rawGradient != null && rawGradient.length >= 2
        ? rawGradient.cast<Color>()
        : [widget.accentColor, widget.accentColor.withValues(alpha: 0.6)];

    final text = question['text'] as String;
    final section = question['section'] as String?;
    final fontSize = text.length > 140
        ? 17.0
        : text.length > 90
            ? 20.0
            : 23.0;

    final overlayColor = dragX > 0
        ? const Color(0xFF4CAF50).withValues(alpha: swipeProgress * 0.45)
        : dragX < 0
            ? const Color(0xFFEF5350).withValues(alpha: swipeProgress * 0.45)
            : Colors.transparent;

    return Container(
      width: cardWidth,
      height: 460,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradColors,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: gradColors.first.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Overlay de color al deslizar
            Positioned.fill(
              child: ColoredBox(color: overlayColor),
            ),

            // Sello SÍ
            if (dragX > 10)
              Positioned(
                top: 40,
                left: 24,
                child: Transform.rotate(
                  angle: -0.35,
                  child: Opacity(
                    opacity: swipeProgress,
                    child: _buildStamp(
                        widget.rightSwipeLabel, const Color(0xFF4CAF50)),
                  ),
                ),
              ),

            // Sello NO
            if (dragX < -10)
              Positioned(
                top: 40,
                right: 24,
                child: Transform.rotate(
                  angle: 0.35,
                  child: Opacity(
                    opacity: swipeProgress,
                    child: _buildStamp(
                        widget.leftSwipeLabel, const Color(0xFFEF5350)),
                  ),
                ),
              ),

            // Contenido
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (section != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text.rich(
                        italicAcronyms(
                          section,
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Expanded(
                    child: Center(
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.45,
                          shadows: const [
                            Shadow(
                              color: Color(0x44000000),
                              offset: Offset(0, 2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Hint de swipe
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.swipe_rounded,
                          color: Colors.white54, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Desliza para responder',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStamp(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 3),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
