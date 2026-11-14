// Semana 8 (pregunta 6 de la Dra. González): el tutor ve en su cuenta el
// resumen mensual: días buenos, regulares y difíciles.
import 'package:aptm/pantallas/vinculacion/resumen_mensual_tutor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _respuesta(
  String mes,
  String periodo, {
  int dificiles = 2,
}) => {
  'success': true,
  'data': {
    'mes': mes,
    'periodo': periodo,
    'resumenes': [
      {
        'estudiante': 'Ana',
        'texto': 'En $periodo Ana escribió en su diario 5 días.',
        'positivos': 2,
        'neutros': 1,
        'dificiles': dificiles,
      },
    ],
  },
};

void main() {
  test('meses vecinos', () {
    expect(mesAnteriorDe('2026-01'), '2025-12');
    expect(mesAnteriorDe('2026-10'), '2026-09');
    expect(mesSiguienteDe('2025-12'), '2026-01');
    expect(mesSiguienteDe('2026-09'), '2026-10');
  });

  testWidgets('muestra los días de cada estudiante y el texto', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResumenMensualTutor(
          cargar: (_) async => _respuesta('2026-10', 'octubre de 2026'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Octubre de 2026'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('buenos'), findsOneWidget);
    expect(find.text('regulares'), findsOneWidget);
    expect(find.text('difíciles'), findsOneWidget);
    expect(find.textContaining('escribió en su diario 5 días'), findsOneWidget);
    expect(
      find.textContaining('Nunca incluye lo que escribió'),
      findsOneWidget,
    );
  });

  testWidgets('va al mes anterior y no deja pasar del más reciente', (
    tester,
  ) async {
    final pedidos = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ResumenMensualTutor(
          cargar: (mes) async {
            pedidos.add(mes);
            return mes == null
                ? _respuesta('2026-10', 'octubre de 2026')
                : _respuesta(mes, 'septiembre de 2026');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final siguiente = find.widgetWithIcon(
      IconButton,
      Icons.chevron_right_rounded,
    );
    expect(tester.widget<IconButton>(siguiente).onPressed, isNull);

    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.chevron_left_rounded),
    );
    await tester.pumpAndSettle();

    expect(pedidos, [null, '2026-09']);
    expect(find.text('Septiembre de 2026'), findsOneWidget);
    expect(tester.widget<IconButton>(siguiente).onPressed, isNotNull);
  });

  testWidgets('sin estudiantes vinculados lo explica', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResumenMensualTutor(
          cargar: (_) async => {
            'success': true,
            'data': {
              'mes': '2026-10',
              'periodo': 'octubre de 2026',
              'resumenes': [],
            },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Todavía no tienes estudiantes'),
      findsOneWidget,
    );
  });

  testWidgets('si falla la conexión muestra el mensaje', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResumenMensualTutor(
          cargar: (_) async => {'success': false, 'message': 'Sin conexión.'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión.'), findsOneWidget);
  });
}
