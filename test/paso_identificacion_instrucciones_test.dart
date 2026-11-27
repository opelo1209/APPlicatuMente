import 'package:aptm/pantallas/cuestionarios/paso_identificacion.dart';
import 'package:aptm/pantallas/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(bool mostrar) => ChangeNotifierProvider(
  create: (_) => ThemeProvider(),
  child: MaterialApp(
    home: Scaffold(
      body: PasoIdentificacion(
        questions: const [
          {'id': 'p1', 'text': '¿Pregunta?', 'bloque_nombre': 'B', 'numero': 1},
        ],
        instructionTitle: 'Preguntas de Sí o No',
        mostrarInstrucciones: mostrar,
        onCompleted: (_) {},
      ),
    ),
  ),
);

// Tamaño de teléfono (412×870), como en la app.
void _telefono(WidgetTester tester) {
  tester.view.physicalSize = const Size(824, 1740);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('muestra las instrucciones la primera vez', (tester) async {
    _telefono(tester);
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();
    expect(find.text('Preguntas de Sí o No'), findsOneWidget);
  });

  testWidgets('no tapa el resultado al volver de «Enviando…»', (tester) async {
    _telefono(tester);
    await tester.pumpWidget(_app(false));
    await tester.pumpAndSettle();
    expect(find.text('Preguntas de Sí o No'), findsNothing);
  });
}
