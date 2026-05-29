import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme_provider.dart';

class PasoPreferencias extends StatefulWidget {
  final Function(Map<String, dynamic>) onCompleted;

  const PasoPreferencias({super.key, required this.onCompleted});

  @override
  State<PasoPreferencias> createState() => _PasoPreferenciasState();
}

class _PasoPreferenciasState extends State<PasoPreferencias> with SingleTickerProviderStateMixin {
  int _currentSection = 0;
  final Map<String, dynamic> _respuestas = {
    'musica': <String>[],
    'actividades': <String>[],
    'colores_favoritos': <String>[],
    'momento_dia': '',
    'clima_preferido': '',
    'forma_relajacion': <String>[],
    'persona_confianza': '',
    'red_social_favorita': '',
    'mascota': '',
    'comida_favorita': '',
  };

  // Datos del usuario
  final _nombreController = TextEditingController();
  final _edadController = TextEditingController();
  final _ocupacionController = TextEditingController();
  
  // Mapa para controladores de inputs dinámicos
  final Map<String, TextEditingController> _textControllers = {};

  final List<Map<String, dynamic>> _secciones = [];
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void dispose() {
    _nombreController.dispose();
    _edadController.dispose();
    _ocupacionController.dispose();
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeSecciones();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showIntroDialog();
    });
  }

  void _initializeSecciones() {
    _secciones.addAll([
      // Sección 1: Datos básicos
      {
        'tipo': 'formulario',
        'titulo': '¡Empecemos! 👋',
        'subtitulo': 'Cuéntanos un poco sobre ti',
        'emoji': '🎯',
        'color': const Color(0xFF43A047),
      },
      
      // Sección 2: Música
      {
        'tipo': 'multiple_seleccion',
        'key': 'musica',
        'titulo': '¿Qué tipo de música te gusta?',
        'subtitulo': 'Selecciona todos los que quieras',
        'emoji': '🎵',
        'color': const Color(0xFF9C27B0),
        'opciones': [
          {'valor': 'Pop', 'emoji': '🎤'},
          {'valor': 'Rock', 'emoji': '🎸'},
          {'valor': 'Reggaetón', 'emoji': '🔥'},
          {'valor': 'Electrónica', 'emoji': '🎧'},
          {'valor': 'Indie', 'emoji': '🌙'},
          {'valor': 'Hip Hop', 'emoji': '🎪'},
          {'valor': 'Clásica', 'emoji': '🎻'},
          {'valor': 'K-Pop', 'emoji': '✨'},
          {'valor': 'Regional Mexicana', 'emoji': '🤠'},
          {'valor': 'Jazz', 'emoji': '🎺'},
        ],
      },

      // Sección 3: Actividades
      {
        'tipo': 'multiple_seleccion',
        'key': 'actividades',
        'titulo': '¿Qué te gusta hacer en tu tiempo libre?',
        'subtitulo': 'Elige tus favoritas',
        'emoji': '🎮',
        'color': const Color(0xFF2196F3),
        'opciones': [
          {'valor': 'Videojuegos', 'emoji': '🎮'},
          {'valor': 'Leer', 'emoji': '📚'},
          {'valor': 'Ver series/películas', 'emoji': '🎬'},
          {'valor': 'Hacer ejercicio', 'emoji': '💪'},
          {'valor': 'Dibujar/Pintar', 'emoji': '🎨'},
          {'valor': 'Cocinar', 'emoji': '🍳'},
          {'valor': 'Bailar', 'emoji': '💃'},
          {'valor': 'Tocar instrumento', 'emoji': '🎹'},
          {'valor': 'Salir con amigos', 'emoji': '👥'},
          {'valor': 'Estar en redes sociales', 'emoji': '📱'},
        ],
      },

      // Sección 4: Colores
      {
        'tipo': 'colores',
        'key': 'colores_favoritos',
        'titulo': '¿Cuáles son tus colores favoritos?',
        'subtitulo': 'Elige hasta 3 colores',
        'emoji': '🎨',
        'color': const Color(0xFFFF9800),
        'opciones': [
          {'valor': 'Rojo', 'color': const Color(0xFFE53935)},
          {'valor': 'Rosa', 'color': const Color(0xFFEC407A)},
          {'valor': 'Morado', 'color': const Color(0xFF9C27B0)},
          {'valor': 'Azul', 'color': const Color(0xFF2196F3)},
          {'valor': 'Cyan', 'color': const Color(0xFF00BCD4)},
          {'valor': 'Verde', 'color': const Color(0xFF4CAF50)},
          {'valor': 'Amarillo', 'color': const Color(0xFFFFC107)},
          {'valor': 'Naranja', 'color': const Color(0xFFFF9800)},
          {'valor': 'Negro', 'color': const Color(0xFF212121)},
          {'valor': 'Blanco', 'color': const Color(0xFFFFFFFF)},
        ],
      },

      // Sección 5: Momento del día
      {
        'tipo': 'seleccion_unica',
        'key': 'momento_dia',
        'titulo': '¿Cuál es tu momento favorito del día?',
        'subtitulo': 'Elige solo uno',
        'emoji': '⏰',
        'color': const Color(0xFFFF5722),
        'opciones': [
          {'valor': 'Mañana temprano', 'emoji': '🌅'},
          {'valor': 'Mediodía', 'emoji': '☀️'},
          {'valor': 'Tarde', 'emoji': '🌤️'},
          {'valor': 'Atardecer', 'emoji': '🌆'},
          {'valor': 'Noche', 'emoji': '🌙'},
          {'valor': 'Madrugada', 'emoji': '🌃'},
        ],
      },

      // Sección 6: Clima
      {
        'tipo': 'seleccion_unica',
        'key': 'clima_preferido',
        'titulo': '¿Qué clima prefieres?',
        'subtitulo': 'Selecciona tu favorito',
        'emoji': '🌈',
        'color': const Color(0xFF00BCD4),
        'opciones': [
          {'valor': 'Soleado y caluroso', 'emoji': '☀️'},
          {'valor': 'Nublado y fresco', 'emoji': '☁️'},
          {'valor': 'Lluvioso', 'emoji': '🌧️'},
          {'valor': 'Frío', 'emoji': '❄️'},
          {'valor': 'Ventoso', 'emoji': '💨'},
        ],
      },

      // Sección 7: Formas de relajación
      {
        'tipo': 'multiple_seleccion',
        'key': 'forma_relajacion',
        'titulo': '¿Cómo te relajas cuando estás estresado/a?',
        'subtitulo': 'Puedes elegir varias',
        'emoji': '😌',
        'color': const Color(0xFF8BC34A),
        'opciones': [
          {'valor': 'Escuchar música', 'emoji': '🎵'},
          {'valor': 'Dormir', 'emoji': '😴'},
          {'valor': 'Hablar con alguien', 'emoji': '💬'},
          {'valor': 'Hacer ejercicio', 'emoji': '🏃'},
          {'valor': 'Meditar', 'emoji': '🧘'},
          {'valor': 'Ver videos', 'emoji': '📺'},
          {'valor': 'Jugar videojuegos', 'emoji': '🎮'},
          {'valor': 'Caminar', 'emoji': '🚶'},
          {'valor': 'Estar solo/a', 'emoji': '🤫'},
          {'valor': 'Comer algo rico', 'emoji': '🍕'},
        ],
      },

      // Sección 8: Red social
      {
        'tipo': 'seleccion_unica',
        'key': 'red_social_favorita',
        'titulo': '¿Cuál es tu red social favorita?',
        'subtitulo': 'La que más usas',
        'emoji': '📱',
        'color': const Color(0xFFE91E63),
        'opciones': [
          {'valor': 'Instagram', 'icon': FontAwesomeIcons.instagram, 'iconColor': const Color(0xFFE1306C)},
          {'valor': 'TikTok', 'icon': FontAwesomeIcons.tiktok},
          {'valor': 'Twitter/X', 'icon': FontAwesomeIcons.xTwitter},
          {'valor': 'Facebook', 'icon': FontAwesomeIcons.facebook, 'iconColor': const Color(0xFF1877F2)},
          {'valor': 'WhatsApp', 'icon': FontAwesomeIcons.whatsapp, 'iconColor': const Color(0xFF25D366)},
          {'valor': 'Discord', 'icon': FontAwesomeIcons.discord, 'iconColor': const Color(0xFF5865F2)},
          {'valor': 'Snapchat', 'icon': FontAwesomeIcons.snapchat, 'iconColor': const Color(0xFFFFFC00)},
          {'valor': 'YouTube', 'icon': FontAwesomeIcons.youtube, 'iconColor': const Color(0xFFFF0000)},
          {'valor': 'No uso redes', 'emoji': '🚫'},
        ],
      },

      // Sección 9: Mascotas
      {
        'tipo': 'seleccion_unica',
        'key': 'mascota',
        'titulo': '¿Tienes mascotas? ¿Cuál prefieres?',
        'subtitulo': 'Tu favorita',
        'emoji': '🐾',
        'color': const Color(0xFFFF6F00),
        'opciones': [
          {'valor': 'Perro', 'emoji': '🐕'},
          {'valor': 'Gato', 'emoji': '🐈'},
          {'valor': 'Pájaro', 'emoji': '🦜'},
          {'valor': 'Pez', 'emoji': '🐠'},
          {'valor': 'Conejo', 'emoji': '🐰'},
          {'valor': 'Hámster', 'emoji': '🐹'},
          {'valor': 'Otro', 'emoji': '🐾'},
          {'valor': 'No tengo/No me gustan', 'emoji': '❌'},
        ],
      },

      // Sección 10: Comida
      {
        'tipo': 'text_input',
        'key': 'comida_favorita',
        'titulo': '¿Cuál es tu comida favorita?',
        'subtitulo': 'Escribe lo que más te gusta comer',
        'emoji': '🍕',
        'color': const Color(0xFFFF5252),
        'hint': 'Ej: Pizza, Tacos, Sushi...',
      },

      // Sección 11: Persona de confianza
      {
        'tipo': 'text_input',
        'key': 'persona_confianza',
        'titulo': '¿Con quién hablas cuando necesitas apoyo?',
        'subtitulo': 'Puede ser un familiar, amigo, o nadie',
        'emoji': '🤝',
        'color': const Color(0xFF3F51B5),
        'hint': 'Ej: Mi mamá, mi mejor amigo, nadie...',
      },
    ]);
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
                child: const Text('✨', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(height: 15),
              Text(
                "¡Conociéndonos mejor!",
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
                "Queremos conocer tus gustos y preferencias para hacer que tu experiencia sea única.",
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
                  color: const Color(0xFF43A047).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Text('🎨', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "¡No hay respuestas correctas o incorrectas!",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
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
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  elevation: 3,
                ),
                child: const Text(
                  "¡Vamos!",
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

  void _nextSection() async {
    if (_currentSection < _secciones.length - 1) {
      await _animationController.reverse();
      setState(() {
        _currentSection++;
      });
      _animationController.forward();
    } else {
      _finalizar();
    }
  }

  void _previousSection() async {
    if (_currentSection > 0) {
      await _animationController.reverse();
      setState(() {
        _currentSection--;
      });
      _animationController.forward();
    }
  }

  void _finalizar() {
    // Agregar datos básicos
    _respuestas['nombre'] = _nombreController.text;
    _respuestas['edad'] = _edadController.text;
    _respuestas['ocupacion'] = _ocupacionController.text;
    
    widget.onCompleted(_respuestas);
  }

  bool _canContinue() {
    final seccion = _secciones[_currentSection];
    
    if (seccion['tipo'] == 'formulario') {
      return _nombreController.text.isNotEmpty && 
             _edadController.text.isNotEmpty;
    } else if (seccion['tipo'] == 'multiple_seleccion') {
      final key = seccion['key'] as String;
      return (_respuestas[key] as List).isNotEmpty;
    } else if (seccion['tipo'] == 'seleccion_unica') {
      final key = seccion['key'] as String;
      return (_respuestas[key] as String).isNotEmpty;
    } else if (seccion['tipo'] == 'colores') {
      final key = seccion['key'] as String;
      return (_respuestas[key] as List).isNotEmpty;
    } else if (seccion['tipo'] == 'text_input') {
      final key = seccion['key'] as String;
      return (_respuestas[key] as String).isNotEmpty;
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final seccion = _secciones[_currentSection];
    final progreso = (_currentSection + 1) / _secciones.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progreso,
                      backgroundColor: isDarkMode ? Colors.white12 : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(seccion['color'] as Color),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Text(
                  "${_currentSection + 1}/${_secciones.length}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // Contenido
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    children: [
                      // Encabezado de sección
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF2C3A47) : Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: (seccion['color'] as Color).withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: (seccion['color'] as Color).withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.elasticOut,
                              builder: (context, double value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: child,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: (seccion['color'] as Color).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  seccion['emoji'] as String,
                                  style: const TextStyle(fontSize: 50),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              seccion['titulo'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: isDarkMode ? Colors.white : Colors.black87,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: (seccion['color'] as Color).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                seccion['subtitulo'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: seccion['color'] as Color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Contenido según tipo
                      if (seccion['tipo'] == 'formulario') _buildFormulario(isDarkMode),
                      if (seccion['tipo'] == 'multiple_seleccion') _buildMultipleSeleccion(seccion, isDarkMode),
                      if (seccion['tipo'] == 'seleccion_unica') _buildSeleccionUnica(seccion, isDarkMode),
                      if (seccion['tipo'] == 'colores') _buildColores(seccion, isDarkMode),
                      if (seccion['tipo'] == 'text_input') _buildTextInput(seccion, isDarkMode),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Botones de navegación
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentSection > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 15),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white10 : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded, 
                        color: isDarkMode ? Colors.white : Colors.black87
                      ),
                      onPressed: _previousSection,
                    ),
                  ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canContinue() ? _nextSection : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: seccion['color'] as Color,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDarkMode ? Colors.white12 : Colors.grey[300],
                      disabledForegroundColor: isDarkMode ? Colors.white30 : Colors.grey[500],
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: _canContinue() ? 5 : 0,
                      shadowColor: (seccion['color'] as Color).withValues(alpha: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentSection < _secciones.length - 1 ? "Continuar" : "Siguiente Paso",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _currentSection < _secciones.length - 1 
                              ? Icons.arrow_forward_rounded 
                              : Icons.check_circle_outline_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulario(bool isDarkMode) {
    return Column(
      children: [
        _buildTextField(
          controller: _nombreController,
          label: "Tu nombre",
          hint: "¿Cómo te llamas?",
          icon: Icons.person_outline_rounded,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _edadController,
          label: "Tu edad",
          hint: "¿Cuántos años tienes?",
          icon: Icons.cake_outlined,
          isDarkMode: isDarkMode,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _ocupacionController,
          label: "Ocupación (opcional)",
          hint: "Ej: Estudiante, Trabajo en...",
          icon: Icons.work_outline_rounded,
          isDarkMode: isDarkMode,
          isRequired: false,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDarkMode,
    TextInputType? keyboardType,
    bool isRequired = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (value) {
          setState(() {});
        },
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.white60 : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.white30 : Colors.grey[400],
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(icon, color: const Color(0xFF43A047), size: 26),
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFF43A047), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        ),
      ),
    );
  }

  Widget _buildMultipleSeleccion(Map<String, dynamic> seccion, bool isDarkMode) {
    final key = seccion['key'] as String;
    final opciones = seccion['opciones'] as List<Map<String, dynamic>>;
    final seleccionadas = _respuestas[key] as List<String>;
    final color = seccion['color'] as Color;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: opciones.length,
      itemBuilder: (context, index) {
        final opcion = opciones[index];
        final valor = opcion['valor'] as String;
        final emoji = opcion['emoji'] as String?;
        final icon = opcion['icon'] as FaIconData?;
        final iconColor = opcion['iconColor'] as Color?;
        final isSelected = seleccionadas.contains(valor);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                seleccionadas.remove(valor);
              } else {
                seleccionadas.add(valor);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 6),
            transform: Matrix4.translationValues(0, isSelected ? 6 : 0, 0),
            decoration: BoxDecoration(
              color: isSelected
                  ? color
                  : (isDarkMode ? const Color(0xFF2C3A47) : Colors.white),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? color
                    : (isDarkMode ? Colors.white10 : Colors.grey.shade300),
                width: 2,
              ),
              boxShadow: [
                if (!isSelected)
                  BoxShadow(
                    color: isDarkMode ? Colors.black54 : Colors.grey.shade300,
                    offset: const Offset(0, 6),
                  ),
                if (isSelected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.elasticOut,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: icon != null
                      ? FaIcon(icon, size: 32, color: isSelected ? Colors.white : (iconColor ?? (isDarkMode ? Colors.white : Colors.black87)))
                      : Text(emoji ?? '', style: const TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    valor,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDarkMode ? Colors.white : Colors.black87),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeleccionUnica(Map<String, dynamic> seccion, bool isDarkMode) {
    final key = seccion['key'] as String;
    final opciones = seccion['opciones'] as List<Map<String, dynamic>>;
    final seleccionada = _respuestas[key] as String;
    final color = seccion['color'] as Color;

    return Column(
      children: opciones.map((opcion) {
        final valor = opcion['valor'] as String;
        final emoji = opcion['emoji'] as String?;
        final icon = opcion['icon'] as FaIconData?;
        final iconColor = opcion['iconColor'] as Color?;
        final isSelected = seleccionada == valor;

        return GestureDetector(
          onTap: () {
            setState(() {
              _respuestas[key] = valor;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 16),
            transform: Matrix4.translationValues(0, isSelected ? 4 : 0, 0),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: isSelected
                  ? color
                  : (isDarkMode ? const Color(0xFF2C3A47) : Colors.white),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? color
                    : (isDarkMode ? Colors.white10 : Colors.grey.shade300),
                width: 2,
              ),
              boxShadow: [
                if (!isSelected)
                  BoxShadow(
                    color: isDarkMode ? Colors.black54 : Colors.grey.shade300,
                    offset: const Offset(0, 6),
                  ),
                if (isSelected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.elasticOut,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.2) : (isDarkMode ? Colors.white10 : Colors.grey[100]),
                      shape: BoxShape.circle,
                    ),
                    child: icon != null 
                        ? FaIcon(icon, size: 24, color: isSelected ? Colors.white : (iconColor ?? (isDarkMode ? Colors.white : Colors.black87)))
                        : Text(emoji ?? '', style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    valor,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDarkMode ? Colors.white : Colors.black87),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColores(Map<String, dynamic> seccion, bool isDarkMode) {
    final key = seccion['key'] as String;
    final opciones = seccion['opciones'] as List<Map<String, dynamic>>;
    final seleccionadas = _respuestas[key] as List<String>;
    const maxSeleccion = 4;

    return Column(
      children: [
        if (seleccionadas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                "${seleccionadas.length} de $maxSeleccion colores seleccionados",
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: opciones.map((opcion) {
            final valor = opcion['valor'] as String;
            final color = opcion['color'] as Color;
            final isSelected = seleccionadas.contains(valor);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    seleccionadas.remove(valor);
                  } else if (seleccionadas.length < maxSeleccion) {
                    seleccionadas.add(valor);
                  }
                });
              },
              child: AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.elasticOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? (isDarkMode ? Colors.white : Colors.black87) : Colors.transparent,
                      width: isSelected ? 4 : 0,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 20,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        )
                      else
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isSelected ? 1.0 : 0.0,
                      child: Icon(
                        Icons.check_rounded,
                        color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextInput(Map<String, dynamic> seccion, bool isDarkMode) {
    final key = seccion['key'] as String;
    final hint = seccion['hint'] as String;
    final color = seccion['color'] as Color;

    if (!_textControllers.containsKey(key)) {
      _textControllers[key] = TextEditingController(text: _respuestas[key] as String? ?? '');
    }

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: TextField(
        key: ValueKey(key),
        controller: _textControllers[key],
        onChanged: (value) {
          _respuestas[key] = value;
          setState(() {});
        },
        maxLines: 3,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.white30 : Colors.grey[400],
            fontWeight: FontWeight.normal,
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: color, width: 2),
          ),
          contentPadding: const EdgeInsets.all(24),
        ),
      ),
    );
  }
}