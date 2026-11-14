// Semana 8 (asesor): en Serena, Enter envía y Shift+Enter hace un salto de
// línea.
import 'package:aptm/pantallas/modulos/envio_con_enter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<TextEditingController> _montar(
  WidgetTester tester,
  VoidCallback onEnviar,
) async {
  final ctrl = TextEditingController();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EnvioConEnter(
          onEnviar: onEnviar,
          child: TextField(
            controller: ctrl,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byType(TextField));
  await tester.pump();
  return ctrl;
}

void main() {
  testWidgets('Enter envía el mensaje', (tester) async {
    var envios = 0;
    await _montar(tester, () => envios++);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(envios, 1);
  });

  testWidgets('Enter del teclado numérico también envía', (tester) async {
    var envios = 0;
    await _montar(tester, () => envios++);

    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);

    expect(envios, 1);
  });

  testWidgets('Shift+Enter no envía: deja escribir otra línea', (tester) async {
    var envios = 0;
    await _montar(tester, () => envios++);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(envios, 0);
  });

  testWidgets('otras teclas no envían', (tester) async {
    var envios = 0;
    await _montar(tester, () => envios++);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

    expect(envios, 0);
  });

  testWidgets('el campo acepta saltos de línea', (tester) async {
    final ctrl = await _montar(tester, () {});

    await tester.enterText(find.byType(TextField), 'hola\ncómo estás');

    expect(ctrl.text, 'hola\ncómo estás');
    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.textInputAction, TextInputAction.newline);
  });
}
