import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aptm/pantallas/diario/diario_catalogo.dart';
import 'package:aptm/pantallas/diario/diario_widgets.dart';

Widget _envolver(Widget hijo) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: hijo)));

void main() {
  testWidgets('sin líneas propias muestra las de siempre', (tester) async {
    await tester.pumpWidget(
      _envolver(const TarjetaLineasAyuda(titulo: 'Ayuda')),
    );
    expect(find.text('Línea de la Vida'), findsOneWidget);
    expect(find.text('SAPTEL'), findsOneWidget);
  });

  testWidgets('el chat puede mandar sus propias líneas (CIJ)', (
    tester,
  ) async {
    LineaAyuda? llamada;
    await tester.pumpWidget(
      _envolver(
        TarjetaLineasAyuda(
          titulo: 'Si lo necesitas, puedes llamar',
          lineas: const [
            LineaAyuda('CIJ Contigo', '55 5212 1212', 'orientación'),
          ],
          onLlamar: (l) => llamada = l,
        ),
      ),
    );
    expect(find.text('CIJ Contigo'), findsOneWidget);
    expect(find.text('SAPTEL'), findsNothing);
    await tester.tap(find.text('Llamar'));
    expect(llamada?.telefono, '55 5212 1212');
  });
}
