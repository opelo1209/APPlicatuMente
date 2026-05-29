import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'login.dart';
// Importar con el nombre CORRECTO
import 'servicios/auth.dart';

class Registro extends StatefulWidget {
  const Registro({super.key});

  @override
  State<Registro> createState() => _RegistroState();
}

class _RegistroState extends State<Registro> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _perfilTipo = 'estudiante';

  // Controladores para los campos
  final TextEditingController _nombreUsuarioController =
      TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _nombresController = TextEditingController();
  final TextEditingController _apellidoPaternoController =
      TextEditingController();
  final TextEditingController _apellidoMaternoController =
      TextEditingController();
  final TextEditingController _estudiantesIdsController =
      TextEditingController();
  final TextEditingController _parentescoController = TextEditingController(
    text: 'padre/madre/tutor',
  );
  final TextEditingController _curpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Servicio con el nombre CORRECTO: Auth (NO AuthService)
  final Auth _auth = Auth();

  @override
  void dispose() {
    _nombreUsuarioController.dispose();
    _correoController.dispose();
    _nombresController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
    _estudiantesIdsController.dispose();
    _parentescoController.dispose();
    _curpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  // Validar email
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidCurp(String curp) {
    final curpRegex = RegExp(
      r'^[A-Z][AEIOU][A-Z]{2}\d{6}[HM][A-Z]{5}\d{2}$',
    );
    return curpRegex.hasMatch(curp.toUpperCase());
  }

  // Función de registro
  Future<void> _handleRegistro() async {
    // Validaciones
    if (_nombreUsuarioController.text.trim().isEmpty ||
        _correoController.text.trim().isEmpty ||
        _nombresController.text.trim().isEmpty ||
        _apellidoPaternoController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty) {
      _showMessage(
        'Por favor completa todos los campos obligatorios',
        isError: true,
      );
      return;
    }

    if (_perfilTipo == 'estudiante') {
      if (_curpController.text.trim().isEmpty) {
        _showMessage('El CURP es obligatorio para estudiantes', isError: true);
        return;
      }
      if (!_isValidCurp(_curpController.text.trim())) {
        _showMessage('El CURP no tiene un formato válido', isError: true);
        return;
      }
    }

    if (!_isValidEmail(_correoController.text.trim())) {
      _showMessage('Por favor ingresa un correo válido', isError: true);
      return;
    }

    if (_passwordController.text.trim().length < 6) {
      _showMessage(
        'La contraseña debe tener al menos 6 caracteres',
        isError: true,
      );
      return;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _showMessage('Las contraseñas no coinciden', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final estudiantesIds = _parseEstudiantesIds();
      if (estudiantesIds == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Usar _auth (NO _authService)
      final result = await _auth.register(
        nombreUsuario: _nombreUsuarioController.text.trim(),
        correo: _correoController.text.trim(),
        password: _passwordController.text.trim(),
        nombres: _nombresController.text.trim(),
        apellidoPaterno: _apellidoPaternoController.text.trim(),
        apellidoMaterno: _apellidoMaternoController.text.trim(),
        perfilTipo: _perfilTipo,
        estudiantesIds: estudiantesIds,
        parentesco: _parentescoController.text.trim().isEmpty
            ? 'padre/madre/tutor'
            : _parentescoController.text.trim(),
        curp: _curpController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        _showMessage('¡Registro exitoso! Ahora puedes iniciar sesión');

        // Esperar un momento y regresar al login
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Login()),
        );
      } else {
        _showMessage(
          result['message'] ?? 'Error al registrar usuario',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('Error en registro: $e');
      _showMessage('Error de conexión. Verifica tu red', isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<int>? _parseEstudiantesIds() {
    if (_perfilTipo != 'padre') return const [];

    final rawValue = _estudiantesIdsController.text.trim();
    if (rawValue.isEmpty) return const [];

    final ids = <int>[];
    for (final part in rawValue.split(',')) {
      final parsed = int.tryParse(part.trim());
      if (parsed == null || parsed <= 0) {
        _showMessage(
          'Los IDs de estudiantes deben ser números separados por coma',
          isError: true,
        );
        return null;
      }
      ids.add(parsed);
    }
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final isDarkMode = themeProvider.isDarkMode;
    final size = MediaQuery.of(context).size;

    final primaryGreen = const Color(0xFF43A047);
    final buttonColor = const Color(0xFF2E7D32);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Imagen de Fondo
          Positioned.fill(
            child: Image.asset(
              'assets/imagenes/fondoLogin.png',
              fit: BoxFit.cover,
            ),
          ),

          // Overlay para modo oscuro
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

          // Contenido Principal
          SafeArea(
            child: SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(
                  minHeight: size.height - MediaQuery.of(context).padding.top,
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: isDarkMode ? Colors.white : primaryGreen,
                            ),
                            onPressed: () => Navigator.pop(context),
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
                    ),

                    // Formulario
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Color.fromARGB(255, 29, 54, 39).withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Título
                          Text(
                            "Crear Cuenta",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Completa tus datos para registrarte",
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withValues(alpha: 
                                0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          _buildPerfilSelector(theme, isDarkMode, primaryGreen),
                          const SizedBox(height: 20),

                          if (_perfilTipo == 'estudiante') ...[
                            _buildInput(
                              theme,
                              isDarkMode,
                              label: "CURP *",
                              icon: Icons.badge_outlined,
                              accentColor: primaryGreen,
                              controller: _curpController,
                              keyboardType: TextInputType.text,
                            ),
                            const SizedBox(height: 15),
                          ],

                          if (_perfilTipo == 'padre') ...[
                            _buildInput(
                              theme,
                              isDarkMode,
                              label: "IDs de estudiantes vinculados",
                              icon: Icons.group_add_outlined,
                              accentColor: primaryGreen,
                              controller: _estudiantesIdsController,
                              keyboardType: TextInputType.text,
                            ),
                            const SizedBox(height: 15),
                            _buildInput(
                              theme,
                              isDarkMode,
                              label: "Parentesco",
                              icon: Icons.diversity_1_outlined,
                              accentColor: primaryGreen,
                              controller: _parentescoController,
                            ),
                            const SizedBox(height: 15),
                          ],

                          // Campos del formulario
                          _buildInput(
                            theme,
                            isDarkMode,
                            label: "Nombre de usuario *",
                            icon: Icons.person_outline,
                            accentColor: primaryGreen,
                            controller: _nombreUsuarioController,
                          ),
                          const SizedBox(height: 15),

                          _buildInput(
                            theme,
                            isDarkMode,
                            label: "Correo electrónico *",
                            icon: Icons.email_outlined,
                            accentColor: primaryGreen,
                            controller: _correoController,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 15),

                          _buildInput(
                            theme,
                            isDarkMode,
                            label: "Nombre(s) *",
                            icon: Icons.badge_outlined,
                            accentColor: primaryGreen,
                            controller: _nombresController,
                          ),
                          const SizedBox(height: 15),

                          _buildInput(
                            theme,
                            isDarkMode,
                            label: "Apellido Paterno *",
                            icon: Icons.family_restroom_outlined,
                            accentColor: primaryGreen,
                            controller: _apellidoPaternoController,
                          ),
                          const SizedBox(height: 15),

                          _buildInput(
                            theme,
                            isDarkMode,
                            label: "Apellido Materno",
                            icon: Icons.family_restroom_outlined,
                            accentColor: primaryGreen,
                            controller: _apellidoMaternoController,
                          ),
                          const SizedBox(height: 15),

                          _buildInput(
                            theme,
                            isDarkMode,
                            label: "Contraseña *",
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
                          const SizedBox(height: 15),

                          _buildInput(
                            theme,
                            isDarkMode,
                            label: "Confirmar contraseña *",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            isObscure: _obscureConfirmPassword,
                            accentColor: primaryGreen,
                            controller: _confirmPasswordController,
                            onToggleVisibility: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          const SizedBox(height: 30),

                          // Botón de registro
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegistro,
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
                                    "Registrarse",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 20),

                          // Link a login
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "¿Ya tienes cuenta? ",
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const Login(),
                                    ),
                                  );
                                },
                                child: Text(
                                  "Inicia sesión",
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(
    ThemeData theme,
    bool isDarkMode, {
    required String label,
    required IconData icon,
    required Color accentColor,
    required TextEditingController controller,
    bool isPassword = false,
    bool isObscure = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
  }) {
    final fillColor = isDarkMode
        ? const Color(0xFF1C222B)
        : const Color(0xFFF1F8E9);

    return TextField(
      controller: controller,
      obscureText: isPassword ? isObscure : false,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
        labelText: label,
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : accentColor.withValues(alpha: 0.8),
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

  Widget _buildPerfilSelector(
    ThemeData theme,
    bool isDarkMode,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Tipo de cuenta *",
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildPerfilChip(
              value: 'estudiante',
              label: 'Estudiante',
              icon: Icons.school_outlined,
              isDarkMode: isDarkMode,
              accentColor: accentColor,
            ),
            _buildPerfilChip(
              value: 'padre',
              label: 'Padre/Madre',
              icon: Icons.family_restroom_outlined,
              isDarkMode: isDarkMode,
              accentColor: accentColor,
            ),
            _buildPerfilChip(
              value: 'administrador',
              label: 'Admin',
              icon: Icons.admin_panel_settings_outlined,
              isDarkMode: isDarkMode,
              accentColor: accentColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerfilChip({
    required String value,
    required String label,
    required IconData icon,
    required bool isDarkMode,
    required Color accentColor,
  }) {
    final isSelected = _perfilTipo == value;
    return ChoiceChip(
      selected: isSelected,
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : accentColor,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDarkMode ? Colors.white70 : const Color(0xFF263238)),
        fontWeight: FontWeight.w700,
      ),
      selectedColor: accentColor,
      backgroundColor: isDarkMode
          ? const Color(0xFF1C222B)
          : const Color(0xFFF1F8E9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? accentColor : accentColor.withValues(alpha: 0.25),
        ),
      ),
      onSelected: (_) => setState(() => _perfilTipo = value),
    );
  }
}
