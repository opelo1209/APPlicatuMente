// Semana 10 (asesor, 25 nov): el analizador trabaja «por debajo del agua».
// El estudiante ve lo que él marcó y que su registro quedó guardado; no ve
// lo que leyó el analizador. Con una señal de riesgo ve las líneas de ayuda
// y un mensaje cálido, nunca «cambiamos tu respuesta».
import 'package:aptm/pantallas/diario/diario_catalogo.dart';
import 'package:aptm/pantallas/diario/diario_modelos.dart';
import 'package:aptm/pantallas/diario/diario_resultado.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({
  required String mensaje,
  bool lineas = false,
  String concordancia = 'difiere',
}) => {
  'texto': 'x',
  'polaridad_registrada': 'positivo',
  'polaridad_guardada': 'positivo',
  'emociones_registradas': [
    {'clave': 'alegria', 'nombre': 'Alegría'},
  ],
  'analisis': {
    'polaridad': 'negativo',
    'confianza': 0.96,
    'emociones': [
      ['tristeza', 0.81],
    ],
  },
  'concordancia': concordancia,
  'mensaje_concordancia': mensaje,
  'accion': 'normal',
  'consejos': <String>[],
  'ofrecer_serena': false,
  'mensaje_serena': '',
  'mostrar_lineas_ayuda': lineas,
};

Future<void> _mostrar(WidgetTester tester, Map<String, dynamic> json) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: DiarioResultadoPantalla(
        resultado: ResultadoDiario.fromJson(json),
        onAbrirSerena: () {},
      ),
    ),
  );
}

void main() {
  test('por omisión el analizador no se muestra al estudiante', () {
    expect(kMostrarAnalizadorAlEstudiante, isFalse);
  });

  testWidgets('el estudiante no ve lo que leyó el analizador', (tester) async {
    await _mostrar(
      tester,
      _json(mensaje: 'Gracias por escribir. Tu registro de hoy quedó guardado.'),
    );
    expect(find.text('TÚ MARCASTE'), findsOneWidget);
    expect(find.text('EN TU TEXTO NOTAMOS'), findsNothing);
    expect(find.textContaining('confianza'), findsNothing);
    expect(find.text('Negativo'), findsNothing);
    expect(find.textContaining('quedó guardado'), findsOneWidget);
  });

  testWidgets('con riesgo ve las líneas de ayuda y un mensaje cálido', (
    tester,
  ) async {
    await _mostrar(
      tester,
      _json(
        mensaje:
            'Gracias por contarlo. Lo que escribiste nos importa: si lo '
            'necesitas, aquí tienes a quién llamar ahora.',
        lineas: true,
      ),
    );
    expect(find.textContaining('nos importa'), findsOneWidget);
    expect(find.textContaining('800 911 2000'), findsOneWidget);
    expect(find.textContaining('negativ'), findsNothing);
  });
}
