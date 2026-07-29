import 'package:flutter/material.dart';
import 'servicios/auth.dart';

class RecuperarContrasena extends StatefulWidget {
  const RecuperarContrasena({super.key});

  @override
  State<RecuperarContrasena> createState() => _RecuperarContrasenaState();
}

class _RecuperarContrasenaState extends State<RecuperarContrasena> {
  final _ctrl = TextEditingController();
  bool _cargando = false;
  bool _enviado = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final valor = _ctrl.text.trim();
    if (valor.isEmpty) {
      setState(() => _error = 'Ingresá tu correo electrónico o nombre de usuario.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    final res = await Auth.requestPasswordReset(valor);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (res['success'] == true) {
        _enviado = true;
      } else {
        _error = res['message'] as String?;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _enviado ? _buildExito(isDark) : _buildFormulario(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildFormulario(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1976D2), size: 36),
        ),
        const SizedBox(height: 24),
        Text(
          'Recuperar contraseña',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ingresá tu correo electrónico o nombre\nde usuario y te enviaremos un enlace\npara restablecer tu contraseña.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _ctrl,
          enabled: !_cargando,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _enviar(),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Correo electrónico o usuario',
            hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _cargando ? null : _enviar,
            child: _cargando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text(
                    'Enviar correo de recuperación',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildExito(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF43A047).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF43A047), size: 52),
        ),
        const SizedBox(height: 24),
        Text(
          'Correo enviado',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Revisá tu bandeja de entrada.\nTe enviamos un enlace para restablecer\ntu contraseña.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Volver al inicio de sesión',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
