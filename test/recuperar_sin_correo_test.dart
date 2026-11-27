// Semana 8: la recuperación de contraseña queda solo con el código del
// administrador. El proyecto no tendrá cuenta de correo, así que la pantalla
// ya no ofrece «Enviar correo de recuperación»: el estudiante oprimiría el
// botón y nunca le llegaría nada.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aptm/pantallas/recuperar_contrasena.dart';
import 'package:aptm/pantallas/restablecer_contrasena.dart';

void main() {
  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RecuperarContrasena()));
    await tester.pumpAndSettle();
  }

  testWidgets('no ofrece enviar un correo', (tester) async {
    await abrir(tester);
    expect(find.textContaining('correo'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('explica que el código lo da el administrador', (tester) async {
    await abrir(tester);
    expect(find.textContaining('administrador'), findsWidgets);
  });

  testWidgets('el botón principal abre la pantalla del código', (tester) async {
    await abrir(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tengo un código'));
    await tester.pumpAndSettle();
    expect(find.byType(RestablecerContrasena), findsOneWidget);
  });
}
