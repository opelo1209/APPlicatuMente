// Semana 4 (asesor): «Mi semana» muestra la evolución del analizador.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aptm/pantallas/diario/diario_catalogo.dart';
import 'package:aptm/pantallas/diario/diario_historial.dart';
import 'package:aptm/pantallas/diario/diario_modelos.dart';

DiaHistorial _dia(int d, Polaridad? marco, Polaridad? analizador, String? c) =>
    DiaHistorial(
      '$d',
      marco,
      null,
      fecha: DateTime(2026, 10, d),
      polaridadAnalizador: analizador,
      confianza: analizador == null ? null : 0.8,
      emocionAnalizador: analizador == null ? null : 'tristeza',
      concordancia: c,
    );

void main() {
  testWidgets('resume cuántos días coincidió el analizador', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EvolucionAnalizador(
              dias: [
                _dia(12, Polaridad.negativo, Polaridad.negativo, 'coincide'),
                _dia(13, Polaridad.neutro, null, null),
                _dia(14, Polaridad.positivo, Polaridad.negativo, 'difiere'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Escribiste 2 días. En 1'), findsOneWidget);
    expect(find.textContaining('Negativo (80 %) · Tristeza'), findsNWidgets(2));
  });

  testWidgets('sin textos invita a escribir', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvolucionAnalizador(
            dias: [_dia(13, Polaridad.neutro, null, null)],
          ),
        ),
      ),
    );
    expect(find.textContaining('Cuando escribas algo'), findsOneWidget);
  });

  testWidgets('el selector cambia a 30 días', (tester) async {
    int? pedido;
    await tester.pumpWidget(
      MaterialApp(
        home: DiarioHistorialPantalla(
          rango: '10 al 16 de octubre',
          dias: [for (var d = 10; d <= 16; d++) _dia(d, null, null, null)],
          onAbrirSerena: () {},
          onCambiarPeriodo: (d) => pedido = d,
        ),
      ),
    );
    await tester.tap(find.text('30 días'));
    expect(pedido, 30);
  });
}
