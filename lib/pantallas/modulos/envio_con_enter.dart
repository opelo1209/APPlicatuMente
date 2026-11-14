// PROTOTIPO Semana 8 (asesor, 12 de noviembre): en Serena se puede escribir
// en varias líneas, como en cualquier chat. Con teclado físico, Enter envía
// y Shift+Enter hace un salto de línea. En el celular, la tecla de salto del
// teclado escribe un salto de línea y se envía con el botón.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Envuelve el campo de texto: Enter (sin Shift) llama a [onEnviar] y no
/// escribe el salto de línea; Shift+Enter se deja pasar al campo.
class EnvioConEnter extends StatelessWidget {
  const EnvioConEnter({super.key, required this.onEnviar, required this.child});

  final VoidCallback onEnviar;
  final Widget child;

  static bool esEnter(LogicalKeyboardKey tecla) =>
      tecla == LogicalKeyboardKey.enter ||
      tecla == LogicalKeyboardKey.numpadEnter;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, evento) {
        if (evento is! KeyDownEvent || !esEnter(evento.logicalKey)) {
          return KeyEventResult.ignored;
        }
        if (HardwareKeyboard.instance.isShiftPressed) {
          return KeyEventResult.ignored;
        }
        onEnviar();
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
