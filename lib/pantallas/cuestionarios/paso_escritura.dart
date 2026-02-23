import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';

class PasoEscritura extends StatefulWidget {
  final Function(String, String, String) onCompleted;

  const PasoEscritura({super.key, required this.onCompleted});

  @override
  State<PasoEscritura> createState() => _PasoEscrituraState();
}

class _PasoEscrituraState extends State<PasoEscritura> {
  final _sentimientosController = TextEditingController();
  final _gustosController = TextEditingController();
  final _datosController = TextEditingController(); // Edad, Ocupación, etc.
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final primaryGreen = const Color(0xFF43A047);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Cuéntanos un poco más sobre ti...",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Esta información nos ayuda a personalizar tu experiencia.",
              style: TextStyle(
                color: isDarkMode ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 30),

            _buildLabel("¿Cómo te sientes en general últimamente?", isDarkMode),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _sentimientosController,
              hint: "Ej: Me siento un poco ansioso por la escuela...",
              isDarkMode: isDarkMode,
              maxLines: 4,
            ),
            const SizedBox(height: 25),
            _buildLabel("¿Qué cosas te gustan o te relajan?", isDarkMode),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _gustosController,
              hint: "Ej: Leer, pasear al perro, la música clásica...",
              isDarkMode: isDarkMode,
              maxLines: 3,
            ),
            const SizedBox(height: 25),

            _buildLabel("Datos Generales (Edad, pasatiempos, gustos)", isDarkMode),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _datosController,
              hint: "Ej: 15 años, Estudiante, escuchar música...",
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 40),
            
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onCompleted(
                    _sentimientosController.text,
                    _gustosController.text,
                    _datosController.text,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 4,
              ),
              child: const Text(
                "Finalizar",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDarkMode) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDarkMode,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
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
        contentPadding: const EdgeInsets.all(20),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor completa este campo';
        }
        return null;
      },
    );
  }
}
