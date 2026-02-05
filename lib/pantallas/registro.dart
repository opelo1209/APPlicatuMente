import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'theme_provider.dart';
import 'cuestionarios/cuestionario_wrapper.dart'; // Importar Cuestionarios

class Registro extends StatefulWidget {
  const Registro({super.key});

  @override
  _RegistroState createState() => _RegistroState();
}

class _RegistroState extends State<Registro> {
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final isDarkMode = themeProvider.isDarkMode;
    final size = MediaQuery.of(context).size;

    // Colores basados en la imagen (Igual que Login)
    final primaryGreen = const Color(0xFF43A047);
    final buttonColor = const Color(0xFF2E7D32);

    // Ajustes de color para un dark mode más agradable (menos morado)
    final panelColor = isDarkMode
      ? const Color.fromARGB(255, 29, 54, 39)
      : Colors.white.withOpacity(0.95);
    final inputFillColor =
      isDarkMode ? const Color(0xFF1C222B) : const Color(0xFFF1F8E9);
    final inputBorderColor = isDarkMode
      ? primaryGreen.withOpacity(0.25)
      : primaryGreen.withOpacity(0.20);

    return Scaffold(
      resizeToAvoidBottomInset: false, // Layout fijo similar al Login
      body: Stack(
        children: [
          // 1. Imagen de Fondo (Full Screen)
          Positioned.fill(
            child: Image.asset(
              'assets/imagenes/fondoLogin.png',
              fit: BoxFit.cover,
            ),
          ),

          // 1.1 Overlay para modo oscuro (oscurece y tiñe con el verde principal)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDarkMode
                        ? [
                            primaryGreen.withOpacity(0.34),
                            Colors.black.withOpacity(0.92),
                          ]
                        : const [Colors.transparent, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          // 2. Botón Atrás (Personalizado para visibilidad)
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: (isDarkMode ? const Color(0xFF0F1D15) : Colors.white)
                    .withOpacity(0.22),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 3. Panel Inferior con WaveClipper
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: size.height * 0.85, // Un poco más alto que el Login para los campos extra
                width: double.infinity,
                color: panelColor,
                padding: const EdgeInsets.only(top: 60, left: 30, right: 30, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Crear Cuenta",
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              "Empieza tu viaje con nosotros",
                              style: TextStyle(
                                fontSize: 16,
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            isDarkMode ? Icons.light_mode : Icons.dark_mode,
                            color: primaryGreen,
                          ),
                          onPressed: () => themeProvider.toogleTheme(!isDarkMode),
                        ),
                      ],
                    ),

                    const Spacer(flex: 2),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildModernInput(
                            theme,
                            isDarkMode,
                            label: "Nombre Completo",
                            icon: Icons.person_outline,
                            accentColor: primaryGreen,
                            fillColor: inputFillColor,
                            borderColor: inputBorderColor,
                            
                          ),
                          const SizedBox(height: 12),
                          _buildModernInput(
                            theme,
                            isDarkMode,
                            label: "Correo Electrónico",
                            icon: Icons.email_outlined,
                            accentColor: primaryGreen,
                            keyboardType: TextInputType.emailAddress,
                            fillColor: inputFillColor,
                            borderColor: inputBorderColor,
                          ),
                          const SizedBox(height: 12),
                          _buildModernInput(
                            theme,
                            isDarkMode,
                            label: "Contraseña",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            isObscure: !_passwordVisible,
                            accentColor: primaryGreen,
                            fillColor: inputFillColor,
                            borderColor: inputBorderColor,
                            onToggleVisibility: () {
                              setState(() {
                                _passwordVisible = !_passwordVisible;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildModernInput(
                            theme,
                            isDarkMode,
                            label: "Confirmar Contraseña",
                            icon: Icons.lock_reset,
                            isPassword: true,
                            isObscure: !_confirmPasswordVisible,
                            accentColor: primaryGreen,
                            fillColor: inputFillColor,
                            borderColor: inputBorderColor,
                            onToggleVisibility: () {
                              setState(() {
                                _confirmPasswordVisible = !_confirmPasswordVisible;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          // Navegar directamente al cuestionario tras registro exitoso
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const CuestionarioWrapper()),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 6,
                        shadowColor: buttonColor.withOpacity(0.45),
                      ),
                      child: const Text(
                        "Continuar",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.12)
                                : Colors.grey[300],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "o regístrate con",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.55),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.12)
                                : Colors.grey[300],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _socialButton(
                          icon: FontAwesomeIcons.google,
                          color: const Color(0xFFDB4437),
                          isDarkMode: isDarkMode,
                          onTap: () {},
                        ),
                        const SizedBox(width: 20),
                        _socialButton(
                          icon: FontAwesomeIcons.facebookF,
                          color: const Color(0xFF4267B2),
                          isDarkMode: isDarkMode,
                          onTap: () {},
                        ),
                      ],
                    ),

                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInput(
    ThemeData theme,
    bool isDarkMode, {
    required String label,
    required IconData icon,
    required Color accentColor,
    bool isPassword = false,
    bool isObscure = false,
    TextInputType? keyboardType,
    Color? fillColor,
    Color? borderColor,
    VoidCallback? onToggleVisibility,
  }) {
    final resolvedFill =
        fillColor ?? (isDarkMode ? const Color(0xFF1C222B) : const Color(0xFFF1F8E9));
    final resolvedBorder = borderColor ??
        (isDarkMode ? accentColor.withOpacity(0.25) : accentColor.withOpacity(0.20));

    return TextFormField(
      obscureText: isPassword ? isObscure : false,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: resolvedFill,
        labelText: label,
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : accentColor.withOpacity(0.8),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: accentColor, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: accentColor.withOpacity(0.6),
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: resolvedBorder.withOpacity(0.7),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Campo requerido';
        return null;
      },
    );
  }

  Widget _socialButton({
    required IconData icon,
    required Color color,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDarkMode ? Colors.white.withOpacity(0.10) : Colors.grey[300]!,
          ),
          color: isDarkMode ? const Color(0xFF1C222B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

// Reutilizamos el Clipper para consistencia visual
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(0, 40);
    
    var firstControlPoint = Offset(size.width / 4, 0);
    var firstEndPoint = Offset(size.width / 2.25, 30);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);

    var secondControlPoint = Offset(size.width - (size.width / 3.25), 65);
    var secondEndPoint = Offset(size.width, 20);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
