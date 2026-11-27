// Semana 6: los saludos de la app no suponen el género de quien la usa.
import 'package:flutter_test/flutter_test.dart';

import 'package:aptm/pantallas/juegos/tutorial/tutor_definitions.dart';
import 'package:aptm/pantallas/login.dart';

// «Bienvenido/Bienvenida» como saludo supone el género; «la bienvenida»
// (sustantivo) no.
final _genero = RegExp(r'(?<!la )\bbienvenid[oa]s?\b', caseSensitive: false);

void main() {
  test('el patrón distingue el saludo del sustantivo', () {
    expect('¡Bienvenido de nuevo!', matches(_genero));
    expect('Bienvenida al TCG', matches(_genero));
    expect('Te damos la bienvenida', isNot(matches(_genero)));
  });

  test('el saludo del inicio de sesión no supone el género', () {
    expect(saludoInicioSesion, isNot(matches(_genero)));
  });

  test('la bienvenida del tutorial del TCG no supone el género', () {
    final textos = createTutorialSteps().expand(
      (p) => [p.instruction, p.detail],
    );
    for (final texto in textos) {
      expect(texto, isNot(matches(_genero)), reason: texto);
    }
  });
}
