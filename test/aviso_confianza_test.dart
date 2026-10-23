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
      expect(texto, contains('palabras altisonantes'));
      expect(texto, contains('Nunca se copia lo que escribiste'));
    });

    test('es honesto con la excepción por seguridad', () {
      expect(puntosAvisoConfianza.join(' '), contains('vida o tu seguridad'));
    });

    testWidgets('se muestra la primera vez y ya no la segunda',
        (tester) async {
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
