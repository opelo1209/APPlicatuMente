import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme_provider.dart';
import 'cuestionario_wrapper.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PasoTripticoNSSI
// Tríptico interactivo con mascota Quetzal + Quiz V/F
// ═══════════════════════════════════════════════════════════════════════════════

class PasoTripticoNSSI extends StatefulWidget {
  const PasoTripticoNSSI({super.key});

  @override
  State<PasoTripticoNSSI> createState() => _PasoTripticoNSSIState();
}

class _PasoTripticoNSSIState extends State<PasoTripticoNSSI>
    with TickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _bounceAnim;
  late Animation<double> _fadeAnim;

  int _paso = 0;
  bool _enQuiz = false;
  int _preguntaActual = 0;
  int _aciertos = 0;
  bool? _respuestaSeleccionada;
  bool _mostrarExplicacion = false;
  bool _quizTerminado = false;
  bool _mostrarBoton = false;

  // ── Diálogos ─────────────────────────────────────────────────────────────────
  static const List<_DialogoMascota> _dialogos = [
    _DialogoMascota(
      emoji: '👋',
      titulo: '¡Hola! Soy Quetzi',
      mensaje: 'Soy tu guía en esta app. Antes de comenzar, quiero platicarte algo importante sobre las emociones y cómo a veces nos afectan.',
      color: Color(0xFF66BB6A),
    ),
    _DialogoMascota(
      emoji: '🧠',
      titulo: '¿Qué es la NSSI?',
      mensaje: 'A veces las emociones se sienten tan intensas que algunas personas se lastiman a sí mismas para aliviarlas. Eso se llama auto lesión no suicida, o NSSI.',
      color: Color(0xFF42A5F5),
    ),
    _DialogoMascota(
      emoji: '💡',
      titulo: 'Importante saber',
      mensaje: 'La NSSI NO es un intento de suicidio. La persona no quiere morir; quiere dejar de sentir un dolor emocional muy grande. Es una señal de que necesita apoyo.',
      color: Color(0xFF7E57C2),
    ),
    _DialogoMascota(
      emoji: '💬',
      titulo: '¿Por qué ocurre?',
      mensaje: 'Puede pasar por varias razones:\n• Para aliviar ansiedad, tristeza o enojo intenso\n• Como autocastigo cuando hay mucha culpa\n• Para sentir algo cuando hay vacío emocional\n• Para comunicar un sufrimiento difícil de expresar',
      color: Color(0xFFFF8A65),
    ),
    _DialogoMascota(
      emoji: '🤝',
      titulo: '¿Qué puedes hacer tú?',
      mensaje: 'Si sientes esto, hablar con alguien de confianza, escribir lo que sientes o buscar apoyo psicológico son formas reales de ayudarte.\n\nPedir ayuda es un acto de valentía 💚',
      color: Color(0xFF26A69A),
    ),
    _DialogoMascota(
      emoji: '👨‍👩‍👧',
      titulo: 'Para familias',
      mensaje: 'Si eres padre, madre o cuidador: escuchar sin juzgar ni castigar marca una enorme diferencia. La detección oportuna y el acompañamiento respetuoso pueden cambiar la vida de un adolescente.',
      color: Color(0xFFEF5350),
    ),
    _DialogoMascota(
      emoji: '🌱',
      titulo: 'Recuerda siempre',
      mensaje: 'No estás solo o sola. Siempre hay alguien que puede ayudarte. Esta app es un espacio seguro para conocerte mejor y encontrar formas saludables de manejar lo que sientes.',
      color: Color(0xFF43A047),
    ),
    _DialogoMascota(
      emoji: '🎯',
      titulo: '¡Hagamos un pequeño juego!',
      mensaje: 'Para ver qué tanto entendiste lo que te platiqué, vamos a jugar un quiz rápido de Verdadero o Falso. ¿Listo o lista? 🚀',
      color: Color(0xFF66BB6A),
    ),
  ];

  // ── Preguntas ────────────────────────────────────────────────────────────────
  static const List<_PreguntaVF> _preguntas = [
    _PreguntaVF(
      texto: 'La auto lesión no suicida siempre significa que la persona quiere morir.',
      esVerdadero: false,
      explicacionCorrecta: '¡Exacto! La NSSI ocurre sin intención de morir. Es una forma de manejar emociones muy intensas.',
      explicacionIncorrecta: 'No es así. La NSSI NO implica querer morir; es una señal de dolor emocional que necesita atención.',
    ),
    _PreguntaVF(
      texto: 'La NSSI puede ser una forma de comunicar sufrimiento cuando las palabras no alcanzan.',
      esVerdadero: true,
      explicacionCorrecta: '¡Correcto! A veces es muy difícil expresar el dolor con palabras, y la conducta se convierte en una señal.',
      explicacionIncorrecta: 'En realidad sí. Muchas personas usan la NSSI para mostrar un dolor que no saben cómo expresar verbalmente.',
    ),
    _PreguntaVF(
      texto: 'Escuchar sin juzgar es una de las mejores formas de apoyar a alguien que se autolesiona.',
      esVerdadero: true,
      explicacionCorrecta: '¡Muy bien! La escucha empática hace que la persona se sienta segura para buscar ayuda.',
      explicacionIncorrecta: 'En realidad sí es clave. Juzgar o castigar cierra la comunicación y aleja a la persona del apoyo.',
    ),
    _PreguntaVF(
      texto: 'La presencia de factores de riesgo garantiza que una persona se autolesionará.',
      esVerdadero: false,
      explicacionCorrecta: '¡Muy bien! Los factores de riesgo aumentan la vulnerabilidad, pero el apoyo adecuado puede marcar una gran diferencia.',
      explicacionIncorrecta: 'Correcto sería Falso. Los factores de riesgo no determinan la conducta; el apoyo puede cambiar el camino.',
    ),
    _PreguntaVF(
      texto: 'Pedir ayuda cuando sientes emociones muy intensas es un acto de valentía.',
      esVerdadero: true,
      explicacionCorrecta: '¡100% verdadero! Reconocer que necesitas apoyo y pedirlo requiere mucha valentía.',
      explicacionIncorrecta: 'En realidad sí lo es. Pedir ayuda cuando más lo necesitas es uno de los actos más valientes que existen.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _bounceAnim = Tween<double>(begin: 0, end: -10).animate(
        CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
    Future.delayed(const Duration(milliseconds: 500),
        () { if (mounted) setState(() => _mostrarBoton = true); });
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _animarTransicion(VoidCallback cambio) {
    setState(() { _mostrarBoton = false; });
    _fadeCtrl.reset();
    cambio();
    _fadeCtrl.forward();
    Future.delayed(const Duration(milliseconds: 500),
        () { if (mounted) setState(() => _mostrarBoton = true); });
  }

  void _siguiente() {
    if (_paso < _dialogos.length - 1) {
      _animarTransicion(() => _paso++);
    } else {
      _animarTransicion(() => _enQuiz = true);
    }
  }

  void _responder(bool respuesta) {
    if (_mostrarExplicacion) return;
    final correcta = _preguntas[_preguntaActual].esVerdadero;
    setState(() {
      _respuestaSeleccionada = respuesta;
      _mostrarExplicacion = true;
      if (respuesta == correcta) _aciertos++;
    });
  }

  void _siguientePregunta() {
    if (_preguntaActual < _preguntas.length - 1) {
      _animarTransicion(() {
        _preguntaActual++;
        _respuestaSeleccionada = null;
        _mostrarExplicacion = false;
      });
    } else {
      _animarTransicion(() => _quizTerminado = true);
    }
  }

  Future<void> _continuar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cuestionario_completado', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CuestionarioWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_quizTerminado) return _buildResultado();
    if (_enQuiz) return _buildQuiz();
    return _buildDialogo();
  }

  // ═══════════════════════════════════════════════════════════════
  // DIÁLOGO MASCOTA
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDialogo() {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final dialogo = _dialogos[_paso];
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF0F4F8);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Progress + back
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  if (_paso > 0)
                    GestureDetector(
                      onTap: () => _animarTransicion(() => _paso--),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_back_ios_rounded,
                            size: 16,
                            color: isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  if (_paso > 0) const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (_paso + 1) / _dialogos.length,
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                        color: dialogo.color,
                        minHeight: 7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${_paso + 1}/${_dialogos.length}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white38 : Colors.black38)),
                ],
              ),
            ),

            const Spacer(),

            // Mascota animada
            AnimatedBuilder(
              animation: _bounceAnim,
              builder: (_, child) =>
                  Transform.translate(offset: Offset(0, _bounceAnim.value), child: child),
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      dialogo.color.withOpacity(0.3),
                      dialogo.color.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(dialogo.emoji, style: const TextStyle(fontSize: 72)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Burbuja de diálogo
            FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(28),
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: dialogo.color.withOpacity(0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                    border: Border.all(
                        color: dialogo.color.withOpacity(0.25), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Quetzi
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: dialogo.color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('🦜 Quetzi',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dialogo.titulo,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dialogo.mensaje,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_dialogos.length, (i) {
                final active = i == _paso;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: active
                        ? dialogo.color
                        : (isDark ? Colors.grey[700] : Colors.grey[300]),
                  ),
                );
              }),
            ),

            const SizedBox(height: 20),

            // Botón
            AnimatedOpacity(
              opacity: _mostrarBoton ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: GestureDetector(
                  onTap: _mostrarBoton ? _siguiente : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: dialogo.color,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: dialogo.color.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _paso < _dialogos.length - 1
                            ? 'Entendido, siguiente  →'
                            : '¡Vamos al quiz! 🎯',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // QUIZ
  // ═══════════════════════════════════════════════════════════════
  Widget _buildQuiz() {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF0F4F8);
    final pregunta = _preguntas[_preguntaActual];
    const green = Color(0xFF43A047);
    const red = Color(0xFFEF5350);
    final correcta = pregunta.esVerdadero;
    final acerto = _respuestaSeleccionada == correcta;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Pregunta ${_preguntaActual + 1} de ${_preguntas.length}',
                        style: const TextStyle(
                            color: green, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(children: [
                        const Text('⭐ '),
                        Text('$_aciertos',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_preguntaActual + 1) / _preguntas.length,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                    color: green,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 24),

                // Mascota mini + burbuja
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedBuilder(
                      animation: _bounceAnim,
                      builder: (_, child) => Transform.translate(
                          offset: Offset(0, _bounceAnim.value * 0.4), child: child),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: green.withOpacity(0.12),
                        ),
                        child: const Center(
                            child: Text('🦜', style: TextStyle(fontSize: 30))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          border: Border.all(color: green.withOpacity(0.25)),
                        ),
                        child: Text(
                          _mostrarExplicacion
                              ? (acerto ? '¡Excelente! 🎉' : '¡Casi! 💪')
                              : '¿Verdadero o falso?',
                          style: TextStyle(
                              color: green,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Tarjeta pregunta
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                  ),
                  child: Text(
                    pregunta.texto,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Botones V/F
                Row(
                  children: [
                    Expanded(
                      child: _VFButton(
                        label: '✓  Verdadero',
                        colorBase: green,
                        selected: _respuestaSeleccionada == true,
                        isCorrect: correcta,
                        revealed: _mostrarExplicacion,
                        onTap: () => _responder(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _VFButton(
                        label: '✗  Falso',
                        colorBase: red,
                        selected: _respuestaSeleccionada == false,
                        isCorrect: !correcta,
                        revealed: _mostrarExplicacion,
                        onTap: () => _responder(false),
                      ),
                    ),
                  ],
                ),

                // Explicación
                if (_mostrarExplicacion) ...[
                  const SizedBox(height: 16),
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: (acerto ? green : red)
                            .withOpacity(isDark ? 0.15 : 0.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: (acerto ? green : red).withOpacity(0.3)),
                      ),
                      child: Text(
                        acerto
                            ? pregunta.explicacionCorrecta
                            : pregunta.explicacionIncorrecta,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _siguientePregunta,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: green,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: green.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 5)),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _preguntaActual < _preguntas.length - 1
                              ? 'Siguiente pregunta  →'
                              : 'Ver resultados  🏁',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RESULTADOS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildResultado() {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF0F4F8);
    final pct = _aciertos / _preguntas.length;
    const green = Color(0xFF43A047);

    final emoji = pct == 1.0 ? '🏆' : pct >= 0.6 ? '🌟' : '💪';
    final titulo = pct == 1.0
        ? '¡Perfecto, campeón!'
        : pct >= 0.6
            ? '¡Muy bien hecho!'
            : '¡Buen intento!';
    final mensaje = pct == 1.0
        ? 'Entiendes muy bien el tema. ¡Estoy orgulloso de ti! 🦜'
        : pct >= 0.6
            ? 'Vas muy bien. Recuerda lo que platicamos.'
            : '¡Está bien! Lo importante es querer aprender. ¡Ya lo tienes!';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Mascota celebrando
                AnimatedBuilder(
                  animation: _bounceAnim,
                  builder: (_, child) =>
                      Transform.translate(offset: Offset(0, _bounceAnim.value), child: child),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        green.withOpacity(0.25),
                        green.withOpacity(0.05),
                      ]),
                    ),
                    child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 76))),
                  ),
                ),
                const SizedBox(height: 24),
                Text(titulo,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    '$_aciertos de ${_preguntas.length} correctas',
                    style: const TextStyle(
                        color: green, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 14),
                Text(mensaje,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.5)),
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                    color: green,
                    minHeight: 12,
                  ),
                ),
                const Spacer(),
                // Burbuja quetzi
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Text('🦜 ', style: TextStyle(fontSize: 24)),
                      Expanded(
                        child: Text(
                          'Ahora que ya sabes esto, vamos a conocerte mejor. Responde el siguiente cuestionario 💚',
                          style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _continuar,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: green.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: const Center(
                      child: Text('Continuar con el cuestionario  →',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODELOS
// ═══════════════════════════════════════════════════════════════════════════════

class _DialogoMascota {
  final String emoji;
  final String titulo;
  final String mensaje;
  final Color color;
  const _DialogoMascota({
    required this.emoji,
    required this.titulo,
    required this.mensaje,
    required this.color,
  });
}

class _PreguntaVF {
  final String texto;
  final bool esVerdadero;
  final String explicacionCorrecta;
  final String explicacionIncorrecta;
  const _PreguntaVF({
    required this.texto,
    required this.esVerdadero,
    required this.explicacionCorrecta,
    required this.explicacionIncorrecta,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: Botón V/F
// ═══════════════════════════════════════════════════════════════════════════════

class _VFButton extends StatelessWidget {
  final String label;
  final Color colorBase;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;

  const _VFButton({
    required this.label,
    required this.colorBase,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    const green = Color(0xFF43A047);
    const red = Color(0xFFEF5350);

    Color bg;
    Color borderColor;
    Color textColor;

    if (!revealed) {
      bg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
      borderColor = isDark ? Colors.grey[700]! : Colors.grey[200]!;
      textColor = isDark ? Colors.white : Colors.black87;
    } else if (isCorrect) {
      bg = green.withOpacity(isDark ? 0.2 : 0.1);
      borderColor = green;
      textColor = green;
    } else if (selected) {
      bg = red.withOpacity(isDark ? 0.2 : 0.1);
      borderColor = red;
      textColor = red;
    } else {
      bg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
      borderColor = isDark ? Colors.grey[700]! : Colors.grey[200]!;
      textColor = isDark ? Colors.white38 : Colors.black38;
    }

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
        ),
      ),
    );
  }
}