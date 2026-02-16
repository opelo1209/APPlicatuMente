import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'theme_provider.dart';
import 'registro.dart';
import 'principal.dart';
import 'cuestionarios/cuestionario_wrapper.dart';
// Importar con los nombres CORRECTOS
import 'servicios/auth.dart';
import 'servicios/user.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  
  // Controladores para los campos de texto
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Servicios con los nombres CORRECTOS: Auth y User
  final Auth _auth = Auth();
  final User _user = User();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Función para mostrar mensajes
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Función de login
  Future<void> _handleLogin() async {
    // Validar campos
    if (_usernameController.text.trim().isEmpty || 
        _passwordController.text.trim().isEmpty) {
      _showMessage('Por favor completa todos los campos', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Hacer login usando _auth (NO _authService)
      final loginResult = await _auth.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!loginResult['success']) {
        _showMessage(loginResult['message'] ?? 'Error al iniciar sesión', isError: true);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 2. Obtener información del usuario usando _user (NO _userService)
      final userResult = await _user.getUserMe();
      
      if (!userResult['success']) {
        _showMessage('Error al obtener información del usuario', isError: true);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 3. Verificar si completó el cuestionario
      final prefs = await SharedPreferences.getInstance();
      final bool cuestionarioCompletado = prefs.getBool('cuestionario_completado') ?? false;

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // 4. Navegar a la pantalla correspondiente
      if (cuestionarioCompletado) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Principal()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CuestionarioWrapper()),
        );
      }

    } catch (e) {
      print('Error en login: $e');
      _showMessage('Error de conexión. Verifica tu red', isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final isDarkMode = themeProvider.isDarkMode;
    final size = MediaQuery.of(context).size;

    // Colores basados en la imagen (Verdes)
    final primaryGreen = const Color(0xFF43A047); 
    final buttonColor = const Color(0xFF2E7D32);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Imagen de Fondo (Full Screen)
          Positioned.fill(
            child: Image.asset(
              'assets/imagenes/fondoLogin.png',
              fit: BoxFit.cover,
            ),
          ),

          // 1.1 Overlay para modo oscuro
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

          // 2. Contenedor del Formulario
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: size.height * 0.75,
                width: double.infinity,
                color: isDarkMode
                    ? Color.fromARGB(255, 29, 54, 39)
                    : Colors.white.withOpacity(0.95),
                padding: const EdgeInsets.only(top: 80, left: 30, right: 30, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Encabezado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Hola,",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              "¡Bienvenido de nuevo!",
                              style: TextStyle(
                                fontSize: 18,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
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

                    // Input Usuario
                    _buildModernInput(
                      theme,
                      isDarkMode,
                      label: "Usuario",
                      icon: Icons.person_outline,
                      accentColor: primaryGreen,
                      controller: _usernameController,
                    ),
                    
                    const SizedBox(height: 15),

                    // Input Contraseña
                    _buildModernInput(
                      theme,
                      isDarkMode,
                      label: "Contraseña",
                      icon: Icons.lock_outline,
                      isPassword: true,
                      isObscure: _obscurePassword,
                      accentColor: primaryGreen,
                      controller: _passwordController,
                      onToggleVisibility: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),

                    // Olvidaste contraseña
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {},
                          child: Text(
                            "¿Olvidaste tu contraseña?",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Botón Principal
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: buttonColor.withOpacity(0.5),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Iniciar Sesión",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),

                    const Spacer(flex: 1),

                    // Separador
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
                            "o inicia con",
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

                    const SizedBox(height: 15),

                    // Redes Sociales
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

                    const Spacer(flex: 2),

                    // Registro
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "¿No tienes cuenta? ",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
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
                            "Regístrate",
                            style: TextStyle(
                              color: primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
    required TextEditingController controller,
    bool isPassword = false,
    bool isObscure = false,
    VoidCallback? onToggleVisibility,
  }) {
    final fillColor = isDarkMode ? const Color(0xFF1C222B) : const Color(0xFFF1F8E9);

    return TextField(
      controller: controller,
      obscureText: isPassword ? isObscure : false,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
        labelText: label,
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : accentColor.withOpacity(0.8),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: accentColor,
          size: 20,
        ),
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
            color: accentColor.withOpacity(0.55),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
    );
  }

  Widget _socialButton({
    required IconData icon, 
    required Color color, 
    required bool isDarkMode,
    required VoidCallback onTap
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

// Clipper para efecto de ola suave
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