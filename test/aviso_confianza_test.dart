// Semana 5 (reunión con el asesor): bienvenida de Serena y aviso de qué ven
// los papás.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aptm/pantallas/diario/aviso_confianza.dart';
import 'package:aptm/pantallas/modulos/chatbot_serena.dart';

Widget _app() => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => mostrarAvisoConfianzaSiHaceFalta(context),
        child: const Text('abrir'),
      ),
    ),
  ),
);

void main() {
  group('bienvenida de Serena', () {
    test('invita a platicarlo con un adulto desde el inicio', () {
      expect(mensajeBienvenidaSerena, contains('adulto de confianza'));
      expect(mensajeBienvenidaSerena, contains('tus papás'));
      expect(mensajeBienvenidaSerena, contains('especialista'));
    });

    test('no supone el género de quien escribe', () {
      expect(mensajeBienvenidaSerena, contains('Te doy la bienvenida'));
      expect(mensajeBienvenidaSerena, isNot(contains('Bienvenido')));
      expect(mensajeBienvenidaSerena, isNot(contains('Bienvenida')));
    });
  });

  group('aviso de confianza', () {
    test('dice que los papás reciben un resumen y no lo que escribió', () {
      final texto = puntosAvisoConfianza.join(' ');
      expect(texto, contains('no leen tus palabras'));
      expect(texto, contains('resumen general'));
      expect(texto, contains('Nunca se copia lo que escribiste'));
    });

    // Semana 8, pregunta 3 de la Dra.: sin el ejemplo de las palabras
    // altisonantes; el resumen solo cuenta días (pregunta 6).
    test('no menciona palabras altisonantes', () {
      expect(puntosAvisoConfianza.join(' '), isNot(contains('altisonantes')));
    });

    test('es honesto con la excepción: vida, salud o seguridad', () {
      expect(
        puntosAvisoConfianza.join(' '),
        contains('tu vida, tu salud o tu seguridad'),
      );
    });

    // Semana 8, pregunta 4b: también recibe el aviso el Hospital Infantil.
    test('dice quién recibe el aviso', () {
      final texto = puntosAvisoConfianza.join(' ');
      expect(texto, contains('equipo de apoyo de tu escuela'));
      expect(texto, contains('Hospital Infantil de México Federico Gómez'));
    });

    test('la versión nueva se vuelve a mostrar a quien vio la anterior', () {
      expect(claveAvisoConfianza, 'avisoConfianzaVisto_v2');
    });

    testWidgets('se muestra la primera vez y ya no la segunda', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_app());

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text(tituloAvisoConfianza), findsOneWidget);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.text(tituloAvisoConfianza), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(debeMostrarAvisoConfianza(prefs), isFalse);

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text(tituloAvisoConfianza), findsNothing);
    });

    testWidgets('no se cierra tocando fuera', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_app());
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text(tituloAvisoConfianza), findsOneWidget);
    });
  });
}
