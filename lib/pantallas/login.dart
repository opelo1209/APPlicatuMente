import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'theme_provider.dart';
import 'registro.dart';
import 'principal.dart';
import 'cuestionarios/cuestionario_wrapper.dart';
import 'recuperar_contrasena.dart';
// Importar con los nombres CORRECTOS
import 'servicios/auth.dart';
import 'servicios/prototipo.dart';
import 'servicios/boton_instalar_app.dart';
import 'servicios/google_web_button.dart';
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

  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleAuthSub;
  Widget? _googleWebButton;

  // Acceso rapido de la demo. Se consulta si el backend lo tiene activo: si
  // devuelve 404 (un despliegue normal), el boton no se dibuja nunca.
  final TextEditingController _demoClaveController = TextEditingController();
  // En la compilación del prototipo el panel se dibuja desde el primer
  // cuadro: si apareciera cuando responde el servidor, empujaría los campos
  // mientras la persona escribe (pasó al probarlo). Si el servidor dice que
  // no hay demo, se oculta.
  bool _demoActivo = kEsPrototipo;
  bool _demoRequiereClave = !kEsPrototipo;
  bool _demoOculto = true;
  bool _entrandoEnDemo = false;
  String? _errorDemo;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && _auth.isGoogleConfigured) {
      unawaited(_initGoogleWebButton());
    }
    unawaited(_consultarDemo());
  }

  Future<void> _consultarDemo() async {
    final demo = await _auth.demoActivo();
    if (!mounted) return;
    setState(() {
      _demoActivo = demo.activo;
      _demoRequiereClave = demo.requiereClave;
      _demoOculto = false;
    });
  }

  Future<void> _entrarComoDemo(String perfil) async {
    if (_entrandoEnDemo) return;
    setState(() {
      _entrandoEnDemo = true;
      _errorDemo = null;
    });

    final resultado = await _auth.entrarDemo(
      perfil: perfil,
      clave: _demoClaveController.text.trim(),
    );

    if (!mounted) return;

    if (resultado['success'] == true) {
      // Mismo criterio de navegación que el login normal: si el estudiante no
      // ha terminado el cuestionario se le manda a CuestionarioWrapper, y no a
      // Principal. Sin esto, entrar por la demo lo dejaría en una pantalla
      // donde no puede escribir en el diario.
      try {
        final sessionResult = await _user.getSessionContext();
        if (!mounted) return;
        if (sessionResult['success'] != true) {
          setState(() {
            _entrandoEnDemo = false;
            _errorDemo = 'Error al obtener información del usuario';
          });
          return;
        }

        final sessionData = sessionResult['data'];
        final String perfilTipo = sessionData is Map
            ? sessionData['perfil_tipo']?.toString() ?? 'estudiante'
            : 'estudiante';
        final progress = sessionData is Map ? sessionData['progress'] : null;
        final bool cuestionarioCompletado =
            progress is Map && progress['cuestionario_completado'] == true;

        if (perfilTipo != 'estudiante' || cuestionarioCompletado) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const Principal()),
            (Route<dynamic> route) => false,
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const CuestionarioWrapper(),
            ),
          );
        }
        return;
      } catch (e) {
        debugPrint('Error al navegar tras el acceso demo: $e');
      }
    }

    setState(() {
      _entrandoEnDemo = false;
      _errorDemo = resultado['message']?.toString() ?? 'No se pudo entrar';
    });
  }

  // El botón nativo de Google solo se puede crear DESPUÉS de que el SDK de
  // Google termine de inicializarse (ensureGoogleInitialized es async); si
  // se crea antes, lanza una excepción que rompe el arranque de toda la
  // pantalla (pantalla en blanco). Por eso todo va envuelto en try/catch:
  // un fallo aquí nunca debe tumbar el login por usuario/contraseña.
  Future<void> _initGoogleWebButton() async {
    try {
      await _auth.ensureGoogleInitialized();
      if (!mounted) return;
      setState(() {
        _googleWebButton = renderGoogleWebButton();
      });
      _googleAuthSub = _auth.googleAuthEvents.listen(
        _handleGoogleAuthEvent,
        onError: (Object e) {
          if (!mounted) return;
          _showMessage('Error de Google: $e', isError: true);
        },
      );
    } catch (e) {
      debugPrint('No se pudo inicializar el botón de Google: $e');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _demoClaveController.dispose();
    _googleAuthSub?.cancel();
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
        _showMessage(
          loginResult['message'] ?? 'Error al iniciar sesión',
          isError: true,
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 2. Obtener contexto vivo del usuario usando permisos del backend
      final sessionResult = await _user.getSessionContext();

      if (!sessionResult['success']) {
        _showMessage('Error al obtener información del usuario', isError: true);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 3. Verificar en Postgres temporal si completó el cuestionario
      final sessionData = sessionResult['data'];
      final String perfilTipo = sessionData is Map
          ? sessionData['perfil_tipo']?.toString() ?? 'estudiante'
          : 'estudiante';
      final progress = sessionData is Map ? sessionData['progress'] : null;
      final bool cuestionarioCompletado =
          progress is Map && progress['cuestionario_completado'] == true;

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // 4. Navegar a la pantalla correspondiente

      if (perfilTipo != 'estudiante' || cuestionarioCompletado) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const Principal()),
          (Route<dynamic> route) => false,
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CuestionarioWrapper()),
        );
      }
    } catch (e) {
      debugPrint('Error en login: $e');
      _showMessage('Error de conexión. Verifica tu red', isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Login con Google en Android/iOS (en Web se usa el botón nativo, ver
  // _handleGoogleAuthEvent).
  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final loginResult = await _auth.loginWithGoogle();
      if (!loginResult['success']) {
        _showMessage(
          loginResult['message'] ?? 'Error al iniciar sesión con Google',
          isError: true,
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      await _completeSessionAndNavigate();
    } catch (error) {
      debugPrint('Error en login Google: $error');
      _showMessage('Error al iniciar sesión con Google', isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Se dispara cuando el usuario completa el flujo del botón nativo de
  // Google en Web (GoogleSignIn.instance.authenticate() no existe en Web).
  Future<void> _handleGoogleAuthEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    final GoogleSignInAccount? user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
    if (user == null) return;

    final String? idToken = user.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      _showMessage(
        'No se pudo obtener el token de identidad de Google',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final loginResult = await _auth.completeGoogleSignIn(idToken);
    if (!mounted) return;
    if (!loginResult['success']) {
      _showMessage(
        loginResult['message'] ?? 'Error al iniciar sesión con Google',
        isError: true,
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    await _completeSessionAndNavigate();
  }

  // Con el nuevo endpoint del backend, la validación del token de Google y la
  // creación del usuario se realizan internamente y nos devuelve
  // directamente un token de acceso válido. Ya no necesitamos llamar a
  // syncUser porque ya se guarda en base de datos.
  Future<void> _completeSessionAndNavigate() async {
    final sessionResult = await _user.getSessionContext();
    final sessionData = sessionResult['data'];
    final String perfilTipo =
        sessionResult['success'] == true && sessionData is Map
        ? sessionData['perfil_tipo']?.toString() ?? 'estudiante'
        : 'estudiante';
    final progress = sessionData is Map ? sessionData['progress'] : null;
    final bool cuestionarioCompletado =
        progress is Map && progress['cuestionario_completado'] == true;
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // Navegar a la pantalla correspondiente limpiando el stack anterior
    if (perfilTipo != 'estudiante' || cuestionarioCompletado) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Principal()),
        (Route<dynamic> route) => false,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CuestionarioWrapper()),
      );
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
                            primaryGreen.withValues(alpha: 0.34),
                            Colors.black.withValues(alpha: 0.92),
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
                    : Colors.white.withValues(alpha: 0.95),
                padding: const EdgeInsets.only(
                  top: 80,
                  left: 30,
                  right: 30,
                  bottom: 20,
                ),
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
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            isDarkMode ? Icons.light_mode : Icons.dark_mode,
                            color: primaryGreen,
                          ),
                          onPressed: () =>
                              themeProvider.toogleTheme(!isDarkMode),
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
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RecuperarContrasena(),
                            ),
                          ),
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
                        shadowColor: buttonColor.withValues(alpha: 0.5),
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
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.grey[300],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "o inicia con",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.12)
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
                        if (kIsWeb && _googleWebButton != null)
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: _googleWebButton,
                          )
                        else if (!kIsWeb)
                          _socialButton(
                            icon: FontAwesomeIcons.google,
                            color: const Color(0xFFDB4437),
                            isDarkMode: isDarkMode,
                            onTap: _handleGoogleLogin,
                          ),
                      ],
                    ),

                    const Spacer(flex: 2),

                    // Acceso rapido de la demo. Solo aparece si el backend
                    // responde que lo tiene activo; en un despliegue normal
                    // esta seccion no se dibuja.
                    if (_demoActivo) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryGreen.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.science_outlined,
                                  size: 18,
                                  color: primaryGreen,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Prueba la demo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Es una demostración con datos de prueba. '
                              'Elige un perfil y entra sin registrarte, o usa '
                              'arriba ana_demo, luis_demo, maria_demo o admin_demo '
                              'con la contraseña Demo1234!',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                            if (_demoRequiereClave) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _demoClaveController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'Clave de la demo',
                                  prefixIcon: const Icon(Icons.key, size: 18),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  errorText: _errorDemo,
                                ),
                                onSubmitted: (_) =>
                                    _entrarComoDemo('estudiante'),
                              ),
                            ] else if (_errorDemo != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _errorDemo!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _botonDemo(
                                  'Estudiante',
                                  'estudiante',
                                  Icons.person,
                                ),
                                _botonDemo(
                                  'Padre',
                                  'padre',
                                  Icons.family_restroom,
                                ),
                                _botonDemo('Madre', 'madre', Icons.female),
                                _botonDemo(
                                  'Admin',
                                  'administrador',
                                  Icons.shield,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else if (!_demoOculto) ...[
                      const SizedBox(height: 20),
                    ],

                    // Registro
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "¿No tienes cuenta? ",
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const Registro(),
                              ),
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
                    const SizedBox(height: 14),

                    // Instalación como PWA. El widget se oculta solo en las
                    // compilaciones nativas y cuando ya está instalada.
                    const Center(child: BotonInstalarApp()),

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
    final fillColor = isDarkMode
        ? const Color(0xFF1C222B)
        : const Color(0xFFF1F8E9);

    return TextField(
      controller: controller,
      obscureText: isPassword ? isObscure : false,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
        labelText: label,
        labelStyle: TextStyle(
          color: isDarkMode
              ? Colors.white70
              : accentColor.withValues(alpha: 0.8),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: accentColor, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: accentColor.withValues(alpha: 0.6),
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
            color: accentColor.withValues(alpha: 0.55),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 15,
        ),
      ),
    );
  }

  // Boton de un personaje de la demo.
  Widget _botonDemo(String etiqueta, String perfil, IconData icono) {
    const verde = Color(0xFF43A047);
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: _entrandoEnDemo ? null : () => _entrarComoDemo(perfil),
        icon: _entrandoEnDemo
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icono, size: 16),
        label: Text(etiqueta, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: verde,
          side: BorderSide(color: verde.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required FaIconData icon,
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
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.grey[300]!,
          ),
          color: isDarkMode ? const Color(0xFF1C222B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.25 : 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: FaIcon(icon, color: color, size: 22),
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
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint = Offset(size.width - (size.width / 3.25), 65);
    var secondEndPoint = Offset(size.width, 20);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
