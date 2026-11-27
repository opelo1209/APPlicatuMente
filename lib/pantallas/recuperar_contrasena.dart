import 'package:flutter/material.dart';
import 'restablecer_contrasena.dart';

/// «¿Olvidaste tu contraseña?».
///
/// Semana 8: el proyecto no tendrá cuenta de correo, así que la contraseña se
/// recupera solo con el código que genera el administrador (pantalla
/// Cuentas → «Código»). Antes, el botón principal era «Enviar correo de
/// recuperación»: sin cuenta configurada, al estudiante nunca le llegaba
/// nada. El servidor conserva el envío por correo, sin usarse.
class RecuperarContrasena extends StatelessWidget {
  const RecuperarContrasena({super.key});

  static const _azul = Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5);
    final texto = isDark ? Colors.white : Colors.black87;
    final suave = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: texto),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _azul.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: _azul,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Recuperar contraseña',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: texto,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pide a tu escuela un código de recuperación. '
                  'El administrador de la app lo genera para tu cuenta; '
                  'sirve una sola vez y dura 24 horas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: suave, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _azul,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RestablecerContrasena(),
                      ),
                    ),
                    child: const Text(
                      'Tengo un código',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
