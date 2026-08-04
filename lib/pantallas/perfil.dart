import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'configuracion.dart';
import 'servicios/auth.dart';
import 'servicios/personalizacion.dart';
import 'servicios/user.dart';
import 'theme_provider.dart';

class Perfil extends StatefulWidget {
  const Perfil({super.key});

  @override
  State<Perfil> createState() => _PerfilState();
}

class _PerfilState extends State<Perfil> {
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  bool _cargando = true;
  bool _guardandoPass = false;
  String? _errorPass;
  String? _exitoPass;

  String _perfilTipo = '';
  String _perfilLabel = '';
  String _nombreCompleto = 'Usuario';
  String _nombreUsuario = '';
  String _correo = '';
  String _curp = '';
  bool _activo = true;
  String _fechaCreacion = '';
  String _ultimaConexion = '';
  Map<String, dynamic> _preferences = const {};

  List<Map<String, dynamic>> _vinculados = [];
  bool _cargandoVinculados = true;

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
    setState(() => _cargando = true);
    final res = await User().getSessionContext();
    if (!mounted) return;

    if (res['success'] == true) {
      final data = res['data'];
      if (data is Map) {
        final userData = data['user'];
        final dbInfo = userData is Map ? userData['db_info'] : null;
        final info = dbInfo is Map
            ? Map<String, dynamic>.from(dbInfo)
            : <String, dynamic>{};
        final prefs = data['preferences'];
        setState(() {
          _perfilTipo = data['perfil_tipo']?.toString() ?? '';
          _perfilLabel = data['perfil_label']?.toString() ?? _perfilTipo;
          _nombreCompleto = info['nombre_completo']?.toString() ??
              info['nombre_usuario']?.toString() ??
              'Usuario';
          _nombreUsuario = info['nombre_usuario']?.toString() ?? '';
          _correo = info['correo']?.toString() ?? '';
          _curp = info['curp']?.toString() ?? '';
          _activo = info['activo'] != false;
          _fechaCreacion = info['fecha_de_creacion']?.toString() ?? '';
          _ultimaConexion = info['ultima_conexion']?.toString() ?? '';
          _preferences = prefs is Map
              ? Map<String, dynamic>.from(prefs)
              : const {};
          _cargando = false;
        });
      } else {
        setState(() => _cargando = false);
      }
    } else {
      setState(() => _cargando = false);
    }

    if (_perfilTipo == 'padre') {
      await _cargarVinculados();
    } else {
      setState(() => _cargandoVinculados = false);
    }
  }

  Future<void> _cargarVinculados() async {
    setState(() => _cargandoVinculados = true);
    final res = await User().getEstudiantesVinculados();
    if (!mounted) return;
    final data = res['data'];
    final students = res['success'] == true && data is Map
        ? data['estudiantes_vinculados']
        : const [];
    setState(() {
      _vinculados = students is List
          ? students
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : [];
      _cargandoVinculados = false;
    });
  }

  Future<void> _abrirConfiguracion() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const Configuracion()),
    );
    if (!mounted) return;
    await _cargarPerfil();
    if (_perfilTipo == 'padre') {
      await _cargarVinculados();
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
    final accent = _perfilTipo == 'estudiante'
        ? AppPersonalizacion.accentFromPreferences(_preferences)
        : const Color(0xFF43A047);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mi Perfil',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark, accent),
                  const SizedBox(height: 24),
                  _buildDatosPersonales(isDark),
                  const SizedBox(height: 24),
                  if (_perfilTipo == 'padre') ...[
                    _buildEstudiantesVinculados(isDark),
                    const SizedBox(height: 24),
                  ] else ...[
                    _buildPreferencias(isDark),
                    const SizedBox(height: 24),
                  ],
                  _buildCambiarPass(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppPersonalizacion.gradient(accent, dark: isDark),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _buildAvatar(accent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombreCompleto,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (_nombreUsuario.isNotEmpty)
                  Text(
                    '@$_nombreUsuario',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                if (_correo.isNotEmpty)
                  Text(
                    _correo,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                if (_perfilLabel.isNotEmpty)
                  Text(
                    '"$_perfilLabel"',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Color accent) {
    final initial = _nombreCompleto.isNotEmpty ? _nombreCompleto[0] : '?';
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.white,
      child: Text(
        initial.toUpperCase(),
        style: TextStyle(
          color: accent,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDatosPersonales(bool isDark) {
    return _buildSeccion(
      isDark: isDark,
      titulo: 'Datos personales',
      icono: Icons.badge_outlined,
      children: [
        _filaDato(
          Icons.alternate_email_rounded,
          'Usuario',
          _nombreUsuario,
          isDark,
        ),
        _filaDato(
          Icons.person_outline_rounded,
          'Nombre completo',
          _nombreCompleto,
          isDark,
        ),
        _filaDato(Icons.mail_outline_rounded, 'Correo', _correo, isDark),
        _filaDato(
          Icons.workspace_premium_outlined,
          'Rol',
          _perfilLabel,
          isDark,
        ),
        if (_perfilTipo == 'estudiante' && _curp.isNotEmpty)
          _filaDato(Icons.credit_card_rounded, 'CURP', _curp, isDark),
        _filaDato(
          Icons.check_circle_outline_rounded,
          'Estado',
          _activo ? 'Activo' : 'Inactivo',
          isDark,
        ),
        _filaDato(
          Icons.event_rounded,
          'Fecha de registro',
          _formatearFecha(_fechaCreacion),
          isDark,
        ),
        _filaDato(
          Icons.schedule_rounded,
          'Última conexión',
          _formatearFecha(_ultimaConexion),
          isDark,
        ),
      ],
    );
  }

  Widget _buildEstudiantesVinculados(bool isDark) {
    return _buildSeccion(
      isDark: isDark,
      titulo: 'Estudiantes vinculados',
      icono: Icons.school_outlined,
      children: [
        if (_cargandoVinculados)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_vinculados.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Todavía no hay estudiantes vinculados.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
            ),
          )
        else
          ..._vinculados.map((estudiante) {
            final nombre = estudiante['nombre_completo']?.toString() ??
                estudiante['nombre_usuario']?.toString() ??
                'Estudiante';
            final curp = estudiante['curp']?.toString() ?? '';
            final parentesco = estudiante['parentesco']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined,
                      size: 20, color: Color(0xFFFB8C00)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          [
                            if (curp.isNotEmpty) curp,
                            if (parentesco.isNotEmpty) parentesco,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 8),
        _buildEnlace('Administrar en Configuración', _abrirConfiguracion),
      ],
    );
  }

  Widget _buildPreferencias(bool isDark) {
    final colores = _preferences['colores_favoritos'];
    final colorName = colores is List && colores.isNotEmpty
        ? colores.first.toString()
        : _preferences['color_favorito']?.toString() ?? '';
    final mascota = _preferences['mascota']?.toString() ?? '';
    return _buildSeccion(
      isDark: isDark,
      titulo: 'Preferencias',
      icono: Icons.palette_outlined,
      children: [
        _filaDato(Icons.palette_outlined, 'Color favorito', colorName, isDark),
        _filaDato(Icons.pets_rounded, 'Mascota', mascota, isDark),
        const SizedBox(height: 8),
        _buildEnlace('Cambiar en Configuración', _abrirConfiguracion),
      ],
    );
  }

  Widget _buildCambiarPass(bool isDark) {
    return _buildSeccion(
      isDark: isDark,
      titulo: 'Cambiar contraseña',
      icono: Icons.lock_outline_rounded,
      children: [
        _buildPassField(_currentPwCtrl, 'Contraseña actual', isDark),
        const SizedBox(height: 14),
        _buildPassField(_newPwCtrl, 'Nueva contraseña', isDark),
        const SizedBox(height: 14),
        _buildPassField(_confirmPwCtrl, 'Confirmar nueva contraseña', isDark),
        if (_errorPass != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorPass!,
            style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13),
          ),
        ],
        if (_exitoPass != null) ...[
          const SizedBox(height: 10),
          Text(
            _exitoPass!,
            style: const TextStyle(color: Color(0xFF43A047), fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _guardandoPass ? null : _cambiarPass,
            child: _guardandoPass
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Guardar cambios',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPassField(
    TextEditingController ctrl,
    String hint,
    bool isDark,
  ) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 14),
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

  Widget _filaDato(
    IconData icono,
    String etiqueta,
    String valor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor.isEmpty ? '—' : valor,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnlace(String texto, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.chevron_right_rounded, size: 20),
      label: Text(texto),
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSeccion({
    required bool isDark,
    required String titulo,
    required IconData icono,
    required List<Widget> children,
  }) {
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
          _buildSeccionTitulo(titulo, icono, isDark),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
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

  String _formatearFecha(String raw) {
    if (raw.isEmpty) return '';
    return raw.length >= 16 ? raw.substring(0, 16).replaceAll('T', ' ') : raw;
  }
}
