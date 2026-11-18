// Semana 8 (pregunta 13 de la Dra. González): los 10 textos rechazados
// salieron de la app. Semana 9: la Dra. los revisó; cuatro se quedan y seis
// cambian de texto, así que ya no hay retirados.
import 'dart:io';

import 'package:aptm/pantallas/modulos/modulo_autolesiones.dart';
import 'package:aptm/pantallas/modulos/modulo_suicidio.dart';
import 'package:aptm/pantallas/modulos/teen_info_carousel.dart';
import 'package:aptm/pantallas/modulos/textos_retirados.dart';
import 'package:aptm/pantallas/modulos/textos_revision_dra.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Todas las tarjetas del carrusel, no solo las que se ven en pantalla.
List<TeenInfoCardData> _tarjetas(WidgetTester tester) => [
  for (final carrusel in tester.widgetList<TeenInfoCarousel>(
    find.byType(TeenInfoCarousel),
  ))
    ...carrusel.cards,
];

TeenInfoCardData _tarjeta(WidgetTester tester, String titulo) =>
    _tarjetas(tester).singleWhere((t) => t.title == titulo);

Future<void> _montar(WidgetTester tester, Widget modulo) async {
  SharedPreferences.setMockInitialValues({}); // sin sesión: vista de estudiante
  await tester.pumpWidget(MaterialApp(home: modulo));
  await tester.pumpAndSettle();
}

String _fuente(String archivo) =>
    File('lib/pantallas/modulos/$archivo').readAsStringSync();

void main() {
  test('después de la revisión de la Semana 9 no queda ningún retirado', () {
    expect(textosRetirados, isEmpty);
    expect(estaRetirado('suicidio.quimicaDesc.adolescente'), isFalse);
    expect(estaRetirado('autolesiones.actionContent.familia'), isFalse);
  });

  test('unirVisibles y sinRetirados ya no quitan nada', () {
    final texto = unirVisibles([
      ('suicidio.devCerebralDesc.familia', 'cerebro'),
      ('suicidio.quimicaDesc.familia', 'química'),
      ('suicidio.estresDesc.familia', ''),
    ]);
    expect(texto, 'cerebro\n\nquímica');
    expect(
      sinRetirados([
        ('suicidio.teenImgQuimicaCerebro.adolescente', 1),
        ('suicidio.teenImgEstres.adolescente', 2),
      ]),
      [1, 2],
    );
  });

  test('los textos de la Dra. van tal cual, con punto final', () {
    expect(textoQuimicaAdolescente, startsWith('Tu cerebro produce unas'));
    expect(textoQuimicaAdolescente, endsWith('sentirse más intensos.'));
    expect(textoAdvertenciaAutolesion, endsWith('Tu vida importa.'));
    expect(textoEstresAdolescente, startsWith('El estrés es lo que siente'));
    expect(
      textoEstresAdolescente,
      endsWith('vuelve más difícil manejar lo que sientes.'),
    );
  });

  test('textos para la familia: sin «neurotransmisores» ni «trauma»', () {
    final suicidio = _fuente('modulo_suicidio.dart');
    expect(suicidio, isNot(contains('neurotransmisores')));
    expect(suicidio, isNot(contains('Estrés prolongado o trauma')));
    expect(
      suicidio,
      contains('Estrés prolongado puede agotar la capacidad del cuerpo'),
    );
    expect(suicidio, contains('sustancias químicas que produce el cerebro'));
    // Textos 2 y 3: se quedan sin cambios.
    expect(
      _fuente('modulo_autolesiones.dart'),
      contains('Validar el dolor sin justificar la lesión.'),
    );
    expect(suicidio, contains('Revisa señales recientes como:'));
  });

  testWidgets('suicidio: química y estrés vuelven como tarjetas de texto', (
    tester,
  ) async {
    await _montar(tester, const ModuloSuicidio());

    final quimica = _tarjeta(tester, 'Química del cerebro');
    expect(quimica.imagePath, isNull);
    expect(quimica.body, textoQuimicaAdolescente);

    final estres = _tarjeta(tester, 'Estrés y sobrecarga');
    expect(estres.imagePath, isNull);
    expect(estres.body, textoEstresAdolescente);

    // La ilustración del bloque 1 no cambió.
    expect(
      _tarjetas(tester).map((t) => t.imagePath),
      contains('assets/imagenes/suicidio/1-bloque_1.png'),
    );
  });

  testWidgets('autolesiones: «Dato importante» cambia y «¿Qué más puedo '
      'hacer?» vuelve igual', (tester) async {
    await _montar(tester, const ModuloAutolesiones());

    final dato = _tarjeta(tester, 'Dato importante');
    expect(dato.imagePath, isNull);
    expect(dato.body, textoAdvertenciaAutolesion);

    final queHacer = _tarjeta(tester, '¿Qué más puedo hacer?');
    expect(queHacer.imagePath, 'assets/imagenes/autolesiones/5-que_hacer.png');
  });

  test('autolesiones: la ayuda profesional va primero (texto 1)', () {
    final fuente = _fuente('modulo_autolesiones.dart');
    expect(
      fuente,
      contains(
        r"'Prueba algo más seguro:\n\n• Pide ayuda profesional si vuelve a "
        r"pasar.\n• Habla con alguien de confianza.",
      ),
    );
  });
}
