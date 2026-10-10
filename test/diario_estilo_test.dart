// Pulido visual del diario (10 de octubre): contraste y modo oscuro.
//
// Antes cada pantalla fijaba fondos claros: con el tema oscuro de la app el
// texto quedaba claro sobre claro. Y el ámbar del día neutro, usado como
// texto, no llegaba a 2:1 de contraste.
import 'package:aptm/pantallas/diario/diario_catalogo.dart';
import 'package:aptm/pantallas/diario/diario_entrada.dart';
import 'package:aptm/pantallas/diario/diario_estilo.dart';
import 'package:aptm/pantallas/diario/diario_historial.dart';
import 'package:aptm/pantallas/diario/diario_modelos.dart';
import 'package:aptm/pantallas/diario/diario_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (oscuro + 0.05);
}

Future<void> _pantallaAlta(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

void main() {
  group('Paleta del diario', () {
    for (final c in [DiarioColores.claro, DiarioColores.oscuroTema]) {
      final nombre = c.oscuro ? 'oscuro' : 'claro';

      test('texto legible sobre fondo y superficie ($nombre)', () {
        for (final fondo in [c.fondo, c.superficie]) {
          expect(_contraste(c.texto, fondo), greaterThanOrEqualTo(4.5));
          expect(_contraste(c.textoSuave, fondo), greaterThanOrEqualTo(4.5));
        }
      });

      test('tinta de cada polaridad legible ($nombre)', () {
        for (final p in Polaridad.values) {
          expect(
            _contraste(c.tinta(p), c.superficie),
            greaterThanOrEqualTo(4.5),
          );
          expect(_contraste(c.tinta(p), c.fondo), greaterThanOrEqualTo(4.5));
          expect(
            _contraste(c.textoSobreElegido(p), c.rellenoElegido(p)),
            greaterThanOrEqualTo(4.5),
          );
        }
      });
    }

    test('el ícono sobre la luz encendida se distingue', () {
      for (final p in Polaridad.values) {
        expect(
          _contraste(DiarioColores.sobreLuz(p), kPolaridades[p]!.color),
          greaterThanOrEqualTo(3),
        );
      }
    });
  });

  testWidgets('en modo oscuro el diario usa fondo oscuro', (tester) async {
    await _pantallaAlta(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: DiarioEntradaPantalla(fecha: 'hoy', onGuardar: (_) {}),
      ),
    );
    final fondo = tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor;
    expect(fondo, isNotNull);
    expect(fondo!.computeLuminance(), lessThan(0.05));
  });

  testWidgets('el conteo del día neutro tiene contraste suficiente', (
    tester,
  ) async {
    await _pantallaAlta(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DiarioHistorialPantalla(
          rango: 'semana',
          dias: const [
            DiaHistorial('L', Polaridad.neutro, null),
            DiaHistorial('M', Polaridad.positivo, null),
            DiaHistorial('X', Polaridad.positivo, null),
          ],
          onAbrirSerena: () {},
        ),
      ),
    );
    final numero = tester.widget<Text>(find.text('1'));
    expect(
      _contraste(numero.style!.color!, DiarioColores.claro.fondo),
      greaterThanOrEqualTo(4.5),
    );
  });

  // Antes el aviso «Analizando tu día...» se dibujaba sobre la pantalla sin
  // un Material: Flutter lo mostraba en rojo subrayado (estilo de error).
  testWidgets('el aviso de guardado tiene estilo propio, no el de error', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Stack(children: [DiarioGuardando()])),
    );
    final aviso = find.text('Guardando tu día');
    expect(aviso, findsOneWidget);
    expect(
      find.ancestor(of: aviso, matching: find.byType(Material)),
      findsWidgets,
    );
    final estilo = DefaultTextStyle.of(tester.element(aviso)).style;
    expect(estilo.decoration, isNot(TextDecoration.underline));
  });
}
