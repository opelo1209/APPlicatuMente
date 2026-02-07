import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';

class PasoIdentificacion extends StatefulWidget {
  final Function(Map<String, bool>) onCompleted;

  const PasoIdentificacion({super.key, required this.onCompleted});

  @override
  State<PasoIdentificacion> createState() => _PasoIdentificacionState();
}

class _PasoIdentificacionState extends State<PasoIdentificacion> {
  // Lista de afirmaciones para el cuestionario
  final List<String> _afirmaciones = [
    "Me siento abrumado con frecuencia.",
    "Tengo dificultades para concentrarme.",
    "Disfruto pasar tiempo a solas.",
    "Me cuesta conciliar el sueño.",
    "Siento que nadie me entiende.",
    "Tengo esperanza en el futuro.",
  ];

  final Map<String, bool> _resultados = {};
  int _currentIndex = 0;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInstructions();
    });
  }

  void _showInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false, // Obliga a dar click en Entendido
      builder: (context) {
        // En dialogs, necesitamos obtener el provider con listen:false o usar un Consumer si queremos reactividad,
        // pero para leer solo el modo actual basta con listen: false.
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        final isDarkMode = themeProvider.isDarkMode;
        
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "¿Cómo responder?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gif de Swipe
              Container(
                height: 150,
                width: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey[200], // Fondo por si tarda en cargar
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/gif/swipe.gif', 
                    fit: BoxFit.contain, // Ajuste para que se vea completo
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Desliza las tarjetas así:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              _buildInstructionRow(Icons.arrow_forward, "DERECHA", "Te identifica", const Color(0xFF43A047), isDarkMode),
              const SizedBox(height: 5),
              _buildInstructionRow(Icons.arrow_back, "IZQUIERDA", "No te identifica", Colors.redAccent, isDarkMode),
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
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                child: const Text("¡Entendido!"),
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
  
  Widget _buildInstructionRow(IconData icon, String direction, String meaning, Color color, bool isDarkMode) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          "$direction: ",
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 12,
            color: color
          )
        ),
        Expanded(
          child: Text(
            meaning,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : Colors.black87
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final primaryGreen = const Color(0xFF43A047);

    // Estado completado: Muestra mensaje antes de navegar
    if (_isFinished) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: primaryGreen),
            const SizedBox(height: 20),
            Text(
              "¡Gracias por tus respuestas!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Guardando y continuando...",
              style: TextStyle(
                color: isDarkMode ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        
        // --- Leyenda de Instrucciones Mejorada ---
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 20),
        //   child: Row(
        //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //     children: [
        //       _buildLegendItem(Icons.arrow_back, "No me identifica", Colors.redAccent, isDarkMode),
        //       _buildLegendItem(Icons.arrow_forward, "Me identifica", primaryGreen, isDarkMode, isRight: true),
        //     ],
        //   ),
        // ),
        
        const Spacer(),
        
        // Área de Tarjetas
        SizedBox(
          height: 420,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Fondo visual de "pila"
               if (_currentIndex + 1 < _afirmaciones.length)
                Transform.translate(
                  offset: const Offset(0, 15),
                  child: Transform.scale(
                    scale: 0.9,
                    child: Opacity(
                      opacity: 0.5,
                      child: _buildCard(_afirmaciones[_currentIndex + 1], isDarkMode),
                    ),
                  ),
                ),

              if (_currentIndex < _afirmaciones.length)
                Dismissible(
                  key: Key(_afirmaciones[_currentIndex]),
                  direction: DismissDirection.horizontal,
                  onDismissed: (direction) {
                    bool identified = direction == DismissDirection.startToEnd; // Derecha: Sí
                    if (direction == DismissDirection.endToStart) identified = false; // Izquierda: No

                    _processAnswer(identified);
                  },
                  background: _buildSwipeBackground(Alignment.centerLeft, primaryGreen, Icons.check_circle_outline, "¡Sí, soy yo!"),
                  secondaryBackground: _buildSwipeBackground(Alignment.centerRight, Colors.redAccent, Icons.cancel_outlined, "No me pasa"),
                  child: _buildCard(_afirmaciones[_currentIndex], isDarkMode),
                )
              else 
                const SizedBox(), // No debería verse, pero por seguridad
            ],
          ),
        ),
        
        const Spacer(),
        
        // Botones de control manual
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionButton(Icons.close, Colors.redAccent, () => _handleManualSwipe(false)),
              _buildActionButton(Icons.check, primaryGreen, () => _handleManualSwipe(true)),
            ],
          ),
        ),
      ],
    );
  }

  void _handleManualSwipe(bool identified) {
    // Pequeño hack para simular animacion visual si se quisiera, 
    // pero por ahora solo procesamos la logica
    _processAnswer(identified);
  }

  void _processAnswer(bool identified) {
    setState(() {
      _resultados[_afirmaciones[_currentIndex]] = identified;
      _currentIndex++;
    });

    if (_currentIndex >= _afirmaciones.length) {
      setState(() {
        _isFinished = true;
      });
      // Retraso para que el usuario vea el mensaje de éxito antes de cambiar
      Future.delayed(const Duration(milliseconds: 1500), () {
        widget.onCompleted(_resultados);
      });
    }
  }

  Widget _buildLegendItem(IconData icon, String text, Color color, bool isDarkMode, {bool isRight = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isRight) Icon(icon, size: 16, color: color),
        if (!isRight) const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color.withOpacity(0.8),
          ),
        ),
        if (isRight) const SizedBox(width: 4),
        if (isRight) Icon(icon, size: 16, color: color),
      ],
    );
  }

  Widget _buildCard(String text, bool isDarkMode) {
    return Container(
      width: 320,
      height: 400,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology, // Icono diferente
            size: 70,
            color: isDarkMode ? Colors.white12 : Colors.grey[200],
          ),
          const Spacer(),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
              height: 1.3,
            ),
          ),
          const Spacer(),
          Text(
            "${_currentIndex + 1} de ${_afirmaciones.length}",
            style: TextStyle(
              color: isDarkMode ? Colors.white24 : Colors.grey[400],
              fontSize: 12,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSwipeBackground(Alignment alignment, Color color, IconData icon, String label) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Icon(icon, color: Colors.white, size: 50),
          const SizedBox(height: 10),
          Text(
            label, 
            style: const TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.bold, 
              fontSize: 22
            )
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ],
            border: Border.all(color: color.withOpacity(0.1), width: 1),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
      ),
    );
  }
}
