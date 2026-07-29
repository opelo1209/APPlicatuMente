import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'servicios/auth.dart';
import 'servicios/user.dart';
import 'theme_provider.dart';

class Configuracion extends StatefulWidget {
  const Configuracion({super.key});

  @override
  State<Configuracion> createState() => _ConfiguracionState();
}

class _ConfiguracionState extends State<Configuracion> {
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  bool _cargandoPerfil = true;
  bool _guardandoPass = false;
  bool _guardandoPrefs = false;
  String? _nombreUsuario;
  String? _correo;
  int? _idUsuario;

  String? _errorPass;
  String? _exitoPass;

  List<String> _coloresSeleccionados = [];
  String _mascotaSeleccionada = '';

  static const List<Map<String, dynamic>> _opcionesColor = [
    {'valor': 'Rojo', 'color': Color(0xFFE53935)},
    {'valor': 'Rosa', 'color': Color(0xFFEC407A)},
    {'valor': 'Morado', 'color': Color(0xFF9C27B0)},
    {'valor': 'Azul', 'color': Color(0xFF2196F3)},
    {'valor': 'Cyan', 'color': Color(0xFF00BCD4)},
    {'valor': 'Verde', 'color': Color(0xFF4CAF50)},
    {'valor': 'Amarillo', 'color': Color(0xFFFFC107)},
    {'valor': 'Naranja', 'color': Color(0xFFFF9800)},
    {'valor': 'Negro', 'color': Color(0xFF212121)},
    {'valor': 'Blanco', 'color': Color(0xFFFFFFFF)},
  ];

  static const List<Map<String, String>> _opcionesAnimal = [
    {'valor': 'Perro', 'emoji': '🐕'},
    {'valor': 'Gato', 'emoji': '🐈'},
    {'valor': 'Pajaro', 'emoji': '🦜'},
    {'valor': 'Pez', 'emoji': '🐠'},
    {'valor': 'Conejo', 'emoji': '🐰'},
    {'valor': 'Hamster', 'emoji': '🐹'},
    {'valor': 'Otro', 'emoji': '🐾'},
    {'valor': 'No tengo/No me gustan', 'emoji': '🌿'},
  ];

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    setState(() => _cargandoPerfil = true);
    final prefs = await SharedPreferences.getInstance();
    _idUsuario = prefs.getInt('id_usuario');

    final res = await User().getSessionContext();
    if (!mounted) return;
    if (res['success'] == true) {
      final data = res['data'] as Map<String, dynamic>;
      final user = data['user']?['db_info'] as Map<String, dynamic>?;
      _nombreUsuario = user?['nombre_completo']?.toString() ?? user?['nombre_usuario']?.toString() ?? 'Usuario';
      _correo = user?['correo']?.toString() ?? '';

      final prefsData = data['preferences'] as Map<String, dynamic>? ?? {};
      final colores = prefsData['colores_favoritos'];
      _coloresSeleccionados = colores is List ? colores.cast<String>() : [];
      _mascotaSeleccionada = prefsData['mascota']?.toString() ?? '';
    } else {
      _nombreUsuario = 'Usuario';
    }

    if (_coloresSeleccionados.isEmpty && _idUsuario != null) {
      final localColor = prefs.getString('student_favorite_color_$_idUsuario');
      if (localColor != null && localColor.isNotEmpty) {
        _coloresSeleccionados = [localColor];
      }
    }
    if (_mascotaSeleccionada.isEmpty && _idUsuario != null) {
      final localAnimal = prefs.getString('student_favorite_animal_$_idUsuario');
      if (localAnimal != null && localAnimal.isNotEmpty) {
        _mascotaSeleccionada = localAnimal;
      }
    }

    setState(() => _cargandoPerfil = false);
  }

  Future<void> _guardarPreferencias() async {
    if (_idUsuario == null) return;
    setState(() {
      _guardandoPrefs = true;
      _errorPass = null;
      _exitoPass = null;
    });

    final prefs = await SharedPreferences.getInstance();
    if (_coloresSeleccionados.isNotEmpty) {
      await prefs.setString('student_favorite_color_$_idUsuario', _coloresSeleccionados.first);
    }
    if (_mascotaSeleccionada.isNotEmpty) {
      await prefs.setString('student_favorite_animal_$_idUsuario', _mascotaSeleccionada);
    }

    await User().updateCuestionario(
      tipoCuestionario: 'informacion_general',
      respuestas: {
        'preferencias': {
          'colores_favoritos': _coloresSeleccionados,
          'mascota': _mascotaSeleccionada,
        },
      },
    );

    if (!mounted) return;
    setState(() => _guardandoPrefs = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferencias guardadas correctamente'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cambiarPass() async {
    final current = _currentPwCtrl.text.trim();
    final newPw = _newPwCtrl.text.trim();
    final confirm = _confirmPwCtrl.text.trim();

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      setState(() => _errorPass = 'Completá todos los campos.');
      return;
    }
    if (newPw.length < 6) {
      setState(() => _errorPass = 'La nueva contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (newPw != confirm) {
      setState(() => _errorPass = 'Las contraseñas nuevas no coinciden.');
      return;
    }

    setState(() {
      _guardandoPass = true;
      _errorPass = null;
      _exitoPass = null;
    });

    final res = await Auth().changePassword(current, newPw);
    if (!mounted) return;
    setState(() {
      _guardandoPass = false;
      if (res['success'] == true) {
        _exitoPass = 'Contraseña actualizada correctamente.';
        _currentPwCtrl.clear();
        _newPwCtrl.clear();
        _confirmPwCtrl.clear();
      } else {
        _errorPass = res['message'] as String?;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context, _huboCambios()),
        ),
        title: Text(
          'Configuración',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: _cargandoPerfil
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPerfil(isDark),
                  const SizedBox(height: 24),
                  _buildColorPicker(isDark),
                  const SizedBox(height: 24),
                  _buildAnimalPicker(isDark),
                  const SizedBox(height: 24),
                  _buildCambiarPass(isDark),
                ],
              ),
            ),
    );
  }

  bool _huboCambios() {
    return _coloresSeleccionados.isNotEmpty || _mascotaSeleccionada.isNotEmpty;
  }

  Widget _buildSeccionTitulo(String titulo, IconData icono, bool isDark) {
    return Row(
      children: [
        Icon(icono, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPerfil(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionTitulo('Mi Perfil', Icons.person_outline_rounded, isDark),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF1976D2).withValues(alpha: 0.15),
                child: Text(
                  (_nombreUsuario?.isNotEmpty == true ? _nombreUsuario![0] : '?').toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF1976D2),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nombreUsuario ?? 'Usuario',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (_correo != null && _correo!.isNotEmpty)
                      Text(
                        _correo!,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionTitulo('Paleta de colores', Icons.palette_outlined, isDark),
          const SizedBox(height: 6),
          Text(
            'Elegí tu color favorito',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            alignment: WrapAlignment.center,
            children: _opcionesColor.map((opcion) {
              final valor = opcion['valor'] as String;
              final color = opcion['color'] as Color;
              final isSelected = _coloresSeleccionados.contains(valor);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _coloresSeleccionados = [valor];
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.transparent,
                      width: isSelected ? 3 : 0,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)]
                        : [],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                          size: 28,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildGuardarPrefsBtn(isDark),
        ],
      ),
    );
  }

  Widget _buildAnimalPicker(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionTitulo('Mascota', Icons.pets_rounded, isDark),
          const SizedBox(height: 6),
          Text(
            'Elegí tu animal preferido',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _opcionesAnimal.map((opcion) {
              final valor = opcion['valor']!;
              final emoji = opcion['emoji']!;
              final isSelected = _mascotaSeleccionada == valor;
              return GestureDetector(
                onTap: () {
                  setState(() => _mascotaSeleccionada = valor);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? Colors.white12 : const Color(0xFF1976D2).withValues(alpha: 0.1))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1976D2)
                          : (isDark ? Colors.white12 : Colors.grey.shade300),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 6),
                      Text(
                        valor,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? (isDark ? Colors.white : const Color(0xFF1976D2))
                              : (isDark ? Colors.grey[300] : Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildGuardarPrefsBtn(isDark),
        ],
      ),
    );
  }

  Widget _buildGuardarPrefsBtn(bool isDark) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: _guardandoPrefs ? null : _guardarPreferencias,
        child: _guardandoPrefs
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCambiarPass(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionTitulo('Cambiar contraseña', Icons.lock_outline_rounded, isDark),
          const SizedBox(height: 16),
          _buildPassField(_currentPwCtrl, 'Contraseña actual', isDark),
          const SizedBox(height: 14),
          _buildPassField(_newPwCtrl, 'Nueva contraseña', isDark),
          const SizedBox(height: 14),
          _buildPassField(_confirmPwCtrl, 'Confirmar nueva contraseña', isDark),
          if (_errorPass != null) ...[
            const SizedBox(height: 10),
            Text(_errorPass!, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13)),
          ],
          if (_exitoPass != null) ...[
            const SizedBox(height: 10),
            Text(_exitoPass!, style: const TextStyle(color: Color(0xFF43A047), fontSize: 13)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _guardandoPass ? null : _cambiarPass,
              child: _guardandoPass
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text(
                      'Guardar cambios',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassField(TextEditingController ctrl, String hint, bool isDark) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 14),
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F2F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
