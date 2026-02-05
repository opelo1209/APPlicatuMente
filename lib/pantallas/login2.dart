import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'registro.dart';
import 'principal.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  bool _obscurePassword = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  
  // SlideAnimation is no longer used, we can remove it or suppress the warning
  // late Animation<Offset> _slideAnimation; 

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );

    // Removed slide animation as layout structure changed to fixed Expanded widgets
    // which don't support simple Offset transitions as cleanly inside a Column in this specific context
    // without causing overflow during the transition.
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Para evitar que el teclado redimensione y cause overflow en layout fijo
      resizeToAvoidBottomInset: false, 
      body: Stack(
        children: [
          // Fondo superior curvo
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.45,
            child: ClipPath(
              clipper: HeaderClipper(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      // Usamos los colores originales sin oscurecer tanto
                      // para mantener la vitalidad del diseño
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -50,
                      left: -50,
                      child: CircleAvatar(
                        radius: 100,
                        backgroundColor: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    Positioned(
                      bottom: 50,
                      right: -20,
                      child: CircleAvatar(
                        radius: 80,
                        backgroundColor: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contenido Fijo (Sin Scroll)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10), // Pequeño margen superior
                  
                  // Header con Logo y Título
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: CurvedAnimation(
                            parent: _controller, 
                            curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: CircleAvatar(
                              radius: 60, // Ligeramente más pequeño para ajustar al fijo
                              backgroundColor: Colors.white,
                              backgroundImage: const AssetImage('assets/imagenes/logo.JPG'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: const Text(
                            'Bienvenido',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tarjeta de Formulario
                  Expanded(
                    flex: 5, // Más espacio para el formulario
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        decoration: BoxDecoration(
                          // Un tono un poco más claro y vivo para que la tarjeta no se pierda
                          color: isDarkMode 
                                ? const Color(0xFF252538) // Un gris azulado un poco más claro
                                : theme.cardColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Iniciar Sesión",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.white70 : theme.colorScheme.onSurface,
                                  ),
                                ),
                                // Botón de tema movido aquí dentro
                                IconButton(
                                  icon: Icon(
                                    isDarkMode ? Icons.light_mode : Icons.dark_mode,
                                    color: isDarkMode ? Colors.amber : theme.colorScheme.primary,
                                  ),
                                  onPressed: () => themeProvider.toogleTheme(!isDarkMode),
                                ),
                              ],
                            ),
                            
                            // Input Usuario
                            _buildModernInput(
                              theme, 
                              label: "Usuario", 
                              icon: Icons.person_outline,
                              isDarkMode: isDarkMode,
                            ),

                            // Input Password
                            _buildModernInput(
                              theme, 
                              label: "Contraseña", 
                              icon: Icons.lock_outline,
                              isPassword: true,
                              isObscure: _obscurePassword,
                              isDarkMode: isDarkMode,
                              onToggleVisibility: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),

                            ElevatedButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const Principal()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDarkMode 
                                    ? Color.lerp(theme.colorScheme.primary, Colors.black, 0.2) // Un poco mas oscuro
                                    : theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: const Text(
                                'Ingresar',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Footer login
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '¿Nuevo usuario? ',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white60 : theme.colorScheme.onSurface.withOpacity(0.6)
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const Registro()),
                            );
                          },
                          child: Text(
                            'Regístrate',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildModernInput(
    ThemeData theme, {
    required String label, 
    required IconData icon,
    bool isPassword = false,
    bool isObscure = false,
    required bool isDarkMode,
    VoidCallback? onToggleVisibility,
  }) {
    // Definimos un color de fondo menos "negro" para los inputs en dark mode
    final inputFillColor = isDarkMode 
        ? const Color(0xFF2A2A35) // Más claro que el fondo de la tarjeta
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3);

    return Container(
      decoration: BoxDecoration(
        color: inputFillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode 
              ? Colors.white12 
              : theme.dividerColor.withOpacity(0.1),
        ),
      ),
      child: TextField(
        obscureText: isPassword ? isObscure : false,
        style: TextStyle(
          fontWeight: FontWeight.w500, 
          color: isDarkMode ? Colors.white.withOpacity(0.9) : theme.colorScheme.onSurface
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.white54 : theme.colorScheme.onSurface.withOpacity(0.5)
          ),
          prefixIcon: Icon(icon, color: theme.colorScheme.primary),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: isDarkMode ? Colors.white38 : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
    );
  }
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 80);
    path.cubicTo(
      size.width / 4, size.height,
      3 * size.width / 4, size.height - 120,
      size.width, size.height - 50,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
