// Pruebas del prototipo del diario emocional (Semana 2).
import 'package:aptm/pantallas/diario/diario_catalogo.dart';
import 'package:aptm/pantallas/diario/diario_entrada.dart';
import 'package:aptm/pantallas/diario/diario_modelos.dart';
import 'package:aptm/pantallas/diario/diario_resultado.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget hoja) => MaterialApp(home: hoja);

Future<void> _pantallaAlta(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

ResultadoDiario _resultado({
  String accion = 'normal',
  bool serena = false,
  bool lineas = false,
  Map<String, dynamic>? analisis,
}) => ResultadoDiario.fromJson({
  'texto': 'x',
  'polaridad_registrada': 'negativo',
  'emociones_registradas': [
    {'clave': 'tristeza', 'nombre': 'Tristeza'},
  ],
  'analisis': analisis,
  'concordancia': analisis == null ? 'sin_analisis' : 'coincide',
  'mensaje_concordancia': '',
  'accion': accion,
  'consejos': ['Un consejo'],
  'ofrecer_serena': serena,
  'mensaje_serena': serena ? 'Platica con Serena' : '',
  'mostrar_lineas_ayuda': lineas,
});

void main() {
  group('DiarioEntradaPantalla', () {
    testWidgets('las emociones aparecen solo despues de elegir polaridad', (
      tester,
    ) async {
      await _pantallaAlta(tester);
      await tester.pumpWidget(
        _app(DiarioEntradaPantalla(fecha: 'hoy', onGuardar: (_) {})),
      );

      expect(find.text('Tristeza'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Día negativo'));
      await tester.pumpAndSettle();

      expect(find.text('Tristeza'), findsOneWidget);
      expect(
        find.text('Alegría'),
        findsNothing,
        reason: 'una emocion positiva no se ofrece en un dia negativo',
      );
    });

    testWidgets('cambiar de polaridad borra las emociones elegidas', (
      tester,
    ) async {
      await _pantallaAlta(tester);
      EntradaDiarioDatos? guardado;
      await tester.pumpWidget(
        _app(
          DiarioEntradaPantalla(fecha: 'hoy', onGuardar: (d) => guardado = d),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Día negativo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tristeza'));
      await tester.tap(find.bySemanticsLabel('Día positivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alegría'));
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar y ver mi análisis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar y ver mi análisis'));

      expect(guardado?.polaridad, Polaridad.positivo);
      expect(guardado?.emociones, ['alegria']);
    });

    testWidgets('no se puede guardar sin al menos una emocion', (tester) async {
      await _pantallaAlta(tester);
      var llamadas = 0;
      await tester.pumpWidget(
        _app(DiarioEntradaPantalla(fecha: 'hoy', onGuardar: (_) => llamadas++)),
      );

      await tester.tap(find.bySemanticsLabel('Día neutro'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar y ver mi análisis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar y ver mi análisis'));

      expect(llamadas, 0);
    });
  });

  group('DiarioResultadoPantalla', () {
    testWidgets('un dia sin senales no muestra Serena ni lineas', (
      tester,
    ) async {
      await _pantallaAlta(tester);
      await tester.pumpWidget(
        _app(
          DiarioResultadoPantalla(
            resultado: _resultado(),
            onAbrirSerena: () {},
          ),
        ),
      );

      expect(find.text('Platicar con Serena'), findsNothing);
      expect(find.text('Llamar'), findsNothing);
      expect(find.text('Un consejo'), findsOneWidget);
    });

    testWidgets('el boton de Serena abre el chat', (tester) async {
      await _pantallaAlta(tester);
      var abierto = false;
      await tester.pumpWidget(
        _app(
          DiarioResultadoPantalla(
            resultado: _resultado(serena: true),
            onAbrirSerena: () => abierto = true,
          ),
        ),
      );

      await tester.tap(find.text('Platicar con Serena'));
      expect(abierto, isTrue);
    });

    testWidgets('las lineas de ayuda muestran sus numeros', (tester) async {
      await _pantallaAlta(tester);
      LineaAyuda? llamada;
      await tester.pumpWidget(
        _app(
          DiarioResultadoPantalla(
            resultado: _resultado(accion: 'explorar_con_cuidado', lineas: true),
            onAbrirSerena: () {},
            onLlamar: (l) => llamada = l,
          ),
        ),
      );

      expect(find.textContaining('800 911 2000'), findsOneWidget);
      await tester.tap(find.text('Llamar').first);
      expect(llamada?.nombre, 'Línea de la Vida');
    });

    testWidgets('sin texto se explica que solo se guardo el semaforo', (
      tester,
    ) async {
      await _pantallaAlta(tester);
      await tester.pumpWidget(
        _app(
          DiarioResultadoPantalla(
            resultado: _resultado(),
            onAbrirSerena: () {},
          ),
        ),
      );
      expect(find.textContaining('solo se guardó tu semáforo'), findsOneWidget);
    });

    testWidgets('con analisis incierto no muestra la polaridad del modelo', (
      tester,
    ) async {
      // Si el modelo no esta seguro (menos de 60 %), la app no contradice
      // al estudiante: tampoco debe ponerle en grande "Negativo".
      await _pantallaAlta(tester);
      final json = {
        'texto': 'x',
        'polaridad_registrada': 'positivo',
        'emociones_registradas': [
          {'clave': 'calma', 'nombre': 'Calma'},
        ],
        'analisis': {
          'polaridad': 'negativo',
          'confianza': 0.47,
          'emociones': [
            ['tristeza', 0.65],
          ],
        },
        'concordancia': 'incierto',
        'mensaje_concordancia': 'Gracias por escribir.',
        'accion': 'normal',
        'consejos': <String>[],
        'ofrecer_serena': false,
        'mensaje_serena': '',
        'mostrar_lineas_ayuda': false,
      };
      await tester.pumpWidget(
        _app(
          DiarioResultadoPantalla(
            resultado: ResultadoDiario.fromJson(json),
            onAbrirSerena: () {},
          ),
        ),
      );
      expect(find.text('Negativo'), findsNothing);
      expect(find.textContaining('no fue concluyente'), findsOneWidget);
    });

    testWidgets('muestra la polaridad y emociones del analizador', (
      tester,
    ) async {
      await _pantallaAlta(tester);
      await tester.pumpWidget(
        _app(
          DiarioResultadoPantalla(
            resultado: _resultado(
              analisis: {
                'polaridad': 'negativo',
                'confianza': 0.96,
                'emociones': [
                  ['tristeza', 0.81],
                  ['enojo', 0.1],
                ],
              },
            ),
            onAbrirSerena: () {},
          ),
        ),
      );
      expect(find.text('confianza 96 %'), findsOneWidget);
      expect(find.text('81 %'), findsOneWidget);
    });
  });
}
