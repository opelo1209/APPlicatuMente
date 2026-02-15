import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';

class PasoPreferencias extends StatefulWidget {
  final Function(Map<String, dynamic>) onCompleted;

  const PasoPreferencias({super.key, required this.onCompleted});

  @override
  State<PasoPreferencias> createState() => _PasoPreferenciasState();
}

class _PasoPreferenciasState extends State<PasoPreferencias> {
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

  final List<Map<String, dynamic>> _secciones = [];

  @override
  void initState() {
    super.initState();
    _initializeSecciones();
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
          {'valor': 'Instagram', 'emoji': '📸'},
          {'valor': 'TikTok', 'emoji': '🎵'},
          {'valor': 'Twitter/X', 'emoji': '🐦'},
          {'valor': 'Facebook', 'emoji': '👍'},
          {'valor': 'WhatsApp', 'emoji': '💬'},
          {'valor': 'Discord', 'emoji': '🎮'},
          {'valor': 'Snapchat', 'emoji': '👻'},
          {'valor': 'YouTube', 'emoji': '▶️'},
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
                  color: const Color(0xFF43A047).withOpacity(0.1),
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
                  color: const Color(0xFF43A047).withOpacity(0.1),
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

  void _nextSection() {
    if (_currentSection < _secciones.length - 1) {
      setState(() {
        _currentSection++;
      });
    } else {
      _finalizar();
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
                        "Sección ${_currentSection + 1} de ${_secciones.length}",
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
                          color: seccion['color'] as Color,
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
                      valueColor: AlwaysStoppedAnimation<Color>(seccion['color'] as Color),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),

            // Contenido
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Encabezado de sección
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF2C3E50) : Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            seccion['emoji'] as String,
                            style: const TextStyle(fontSize: 50),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            seccion['titulo'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            seccion['subtitulo'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white60 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Contenido según tipo
                    if (seccion['tipo'] == 'formulario') _buildFormulario(isDarkMode),
                    if (seccion['tipo'] == 'multiple_seleccion') _buildMultipleSeleccion(seccion, isDarkMode),
                    if (seccion['tipo'] == 'seleccion_unica') _buildSeleccionUnica(seccion, isDarkMode),
                    if (seccion['tipo'] == 'colores') _buildColores(seccion, isDarkMode),
                    if (seccion['tipo'] == 'text_input') _buildTextInput(seccion, isDarkMode),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Botón continuar
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _canContinue() ? _nextSection : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: seccion['color'] as Color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[400],
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: _canContinue() ? 5 : 0,
                ),
                child: Text(
                  _currentSection < _secciones.length - 1 ? "Continuar" : "Finalizar",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
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
          icon: Icons.person,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          controller: _edadController,
          label: "Tu edad",
          hint: "¿Cuántos años tienes?",
          icon: Icons.cake,
          isDarkMode: isDarkMode,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          controller: _ocupacionController,
          label: "Ocupación (opcional)",
          hint: "Ej: Estudiante, Trabajo en...",
          icon: Icons.school,
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
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (value) {
        setState(() {}); // Actualizar estado para habilitar/deshabilitar botón
      },
      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF43A047)),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF1E272E) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF43A047), width: 2),
        ),
      ),
    );
  }

  Widget _buildMultipleSeleccion(Map<String, dynamic> seccion, bool isDarkMode) {
    final key = seccion['key'] as String;
    final opciones = seccion['opciones'] as List<Map<String, dynamic>>;
    final seleccionadas = _respuestas[key] as List<String>;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: opciones.map((opcion) {
        final valor = opcion['valor'] as String;
        final emoji = opcion['emoji'] as String;
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? (seccion['color'] as Color)
                  : (isDarkMode ? const Color(0xFF2C3E50) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? (seccion['color'] as Color)
                    : (isDarkMode ? Colors.white24 : Colors.grey[300]!),
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (seccion['color'] as Color).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  valor,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDarkMode ? Colors.white : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSeleccionUnica(Map<String, dynamic> seccion, bool isDarkMode) {
    final key = seccion['key'] as String;
    final opciones = seccion['opciones'] as List<Map<String, dynamic>>;
    final seleccionada = _respuestas[key] as String;

    return Column(
      children: opciones.map((opcion) {
        final valor = opcion['valor'] as String;
        final emoji = opcion['emoji'] as String;
        final isSelected = seleccionada == valor;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _respuestas[key] = valor;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? (seccion['color'] as Color)
                    : (isDarkMode ? const Color(0xFF2C3E50) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? (seccion['color'] as Color)
                      : (isDarkMode ? Colors.white24 : Colors.grey[300]!),
                  width: 2.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: (seccion['color'] as Color).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.2)
                          : (seccion['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      valor,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDarkMode ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Colors.white, size: 24),
                ],
              ),
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
    const maxSeleccion = 3;

    return Column(
      children: [
        if (seleccionadas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Text(
              "${seleccionadas.length} de $maxSeleccion colores seleccionados",
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Wrap(
          spacing: 15,
          runSpacing: 15,
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: isSelected ? 15 : 5,
                      spreadRadius: isSelected ? 2 : 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isSelected)
                        const Icon(Icons.check, color: Colors.white, size: 30),
                      const SizedBox(height: 4),
                      Text(
                        valor,
                        style: TextStyle(
                          color: color.computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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

    return TextField(
      onChanged: (value) {
        setState(() {
          _respuestas[key] = value;
        });
      },
      maxLines: 3,
      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDarkMode ? Colors.white30 : Colors.grey[400]),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF1E272E) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: seccion['color'] as Color, width: 2),
        ),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }
}