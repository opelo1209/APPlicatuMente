// PROTOTIPO Semana 8 (asesor, 12 de noviembre): poner una contraseña nueva.
// Se llega de dos formas:
//   - desde el enlace del correo (…/aptm/#/restablecer?token=…), que trae el
//     token: solo se pide la contraseña nueva;
//   - con el código de un solo uso que da el administrador cuando no hay
//     correo: se escribe el código y la contraseña nueva.
// Antes el enlace del correo no abría ninguna pantalla.
import 'package:flutter/material.dart';

import 'login.dart';
import 'servicios/auth.dart';

typedef EnviarContrasena =
    Future<Map<String, dynamic>> Function(String tokenOCodigo, String nueva);

const int longitudMinimaContrasena = 8;
final RegExp _tokenValido = RegExp(r'^[A-Za-z0-9_-]{16,128}$');

/// El token del enlace del correo, si la dirección lo trae. Solo se acepta
/// la ruta `/restablecer` y un token con los caracteres que genera el
/// servidor (`secrets.token_urlsafe`).
String? tokenDeEnlace(Uri direccion) {
  final fragmento = direccion.fragment;
  if (!fragmento.startsWith('/restablecer')) return null;
  final dentro = Uri.tryParse(fragmento);
  final token = dentro?.queryParameters['token'];
  if (token == null || !_tokenValido.hasMatch(token)) return null;
  return token;
}

class RestablecerContrasena extends StatefulWidget {
  const RestablecerContrasena({super.key, this.token, this.enviar});

  /// Token del enlace del correo; sin él se pide el código del administrador.
  final String? token;

  /// Para las pruebas; por omisión, el servidor.
  final EnviarContrasena? enviar;

  @override
  State<RestablecerContrasena> createState() => _RestablecerContrasenaState();
}

class _RestablecerContrasenaState extends State<RestablecerContrasena> {
  final _codigo = TextEditingController();
  final _nueva = TextEditingController();
  final _repetir = TextEditingController();
  bool _cargando = false;
  bool _listo = false;
  String? _error;

  bool get _conEnlace => widget.token != null;

  @override
  void dispose() {
    _codigo.dispose();
    _nueva.dispose();
    _repetir.dispose();
    super.dispose();
  }

  String? _validar() {
    if (!_conEnlace && _codigo.text.trim().isEmpty) {
      return 'Escribe el código que te dio el administrador.';
    }
    if (_nueva.text.length < longitudMinimaContrasena) {
      return 'La contraseña debe tener al menos '
          '$longitudMinimaContrasena caracteres.';
    }
    if (_nueva.text != _repetir.text) return 'Las contraseñas no coinciden.';
    return null;
  }

  Future<void> _guardar() async {
    final error = _validar();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    final enviar = widget.enviar ?? Auth.resetPasswordConfirm;
    final r = await enviar(widget.token ?? _codigo.text.trim(), _nueva.text);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (r['success'] == true) {
        _listo = true;
      } else {
        _error = r['message'] as String? ?? 'No se pudo cambiar la contraseña.';
      }
    });
  }

  Widget _campo(
    TextEditingController ctrl,
    String etiqueta, {
    bool oculto = false,
    TextCapitalization mayusculas = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        enabled: !_cargando,
        obscureText: oculto,
        textCapitalization: mayusculas,
        decoration: InputDecoration(
          labelText: etiqueta,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contraseña nueva')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: _listo ? _exito(context) : _formulario(context),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _formulario(BuildContext context) => [
    Text(
      _conEnlace
          ? 'Escribe tu contraseña nueva.'
          : 'Escribe el código que te dio el administrador de tu escuela y '
                'tu contraseña nueva. El código sirve una sola vez.',
      style: const TextStyle(height: 1.4),
    ),
    const SizedBox(height: 20),
    if (!_conEnlace)
      _campo(
        _codigo,
        'Código (por ejemplo, ABCD-2345)',
        mayusculas: TextCapitalization.characters,
      ),
    _campo(_nueva, 'Contraseña nueva', oculto: true),
    _campo(_repetir, 'Repite la contraseña nueva', oculto: true),
    if (_error != null)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(_error!, style: const TextStyle(color: Color(0xFFD32F2F))),
      ),
    FilledButton(
      onPressed: _cargando ? null : _guardar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: _cargando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Text('Guardar contraseña'),
      ),
    ),
  ];

  List<Widget> _exito(BuildContext context) => [
    const Icon(
      Icons.check_circle_outline_rounded,
      color: Color(0xFF43A047),
      size: 64,
    ),
    const SizedBox(height: 16),
    const Text(
      'Listo: tu contraseña cambió. Ya puedes iniciar sesión con la nueva.',
      textAlign: TextAlign.center,
      style: TextStyle(height: 1.4),
    ),
    const SizedBox(height: 20),
    FilledButton(
      onPressed: () {
        final nav = Navigator.of(context);
        // Desde el enlace del correo esta es la primera pantalla.
        if (nav.canPop()) {
          nav.popUntil((r) => r.isFirst);
        } else {
          nav.pushReplacement(MaterialPageRoute(builder: (_) => const Login()));
        }
      },
      child: const Text('Ir a iniciar sesión'),
    ),
  ];
}
