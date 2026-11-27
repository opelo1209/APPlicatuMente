// Semana 5 (H9): el administrador marca una alerta como atendida.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aptm/pantallas/admin/alertas_riesgo_admin.dart';

Widget _envolver(Widget hijo) => MaterialApp(home: Scaffold(body: hijo));

void main() {
  testWidgets('una alerta pendiente pide la nota y avisa al guardar', (
    tester,
  ) async {
    bool? atendida;
    String? nota;
    await tester.pumpWidget(
      _envolver(
        EstadoAtencionAlerta(
          alerta: const {'id_alerta': 1, 'atendida': false},
          onAtender: (a, n) {
            atendida = a;
            nota = n;
          },
        ),
      ),
    );
    await tester.tap(find.text('Marcar como atendida'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Se llamó al tutor ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(atendida, isTrue);
    expect(nota, 'Se llamó al tutor');
  });

  testWidgets('cancelar no marca nada', (tester) async {
    var llamadas = 0;
    await tester.pumpWidget(
      _envolver(
        EstadoAtencionAlerta(
          alerta: const {'id_alerta': 1, 'atendida': false},
          onAtender: (_, _) => llamadas++,
        ),
      ),
    );
    await tester.tap(find.text('Marcar como atendida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(llamadas, 0);
  });

  testWidgets('una alerta atendida muestra quién, la nota y deja regresarla', (
    tester,
  ) async {
    bool? atendida;
    await tester.pumpWidget(
      _envolver(
        EstadoAtencionAlerta(
          alerta: const {
            'id_alerta': 1,
            'atendida': true,
            'atendida_por': 'Ana Prueba',
            'fecha_atendida': '2026-10-23T10:05:00+00:00',
            'nota_atencion': 'Se llamó al tutor',
          },
          onAtender: (a, _) => atendida = a,
        ),
      ),
    );
    expect(find.textContaining('Atendida por Ana Prueba'), findsOneWidget);
    expect(find.text('Se llamó al tutor'), findsOneWidget);
    expect(find.text('Marcar como atendida'), findsNothing);
    await tester.tap(find.text('Regresar a pendiente'));
    expect(atendida, isFalse);
  });
}
