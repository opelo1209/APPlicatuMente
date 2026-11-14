// Semana 8 (pregunta 13 de la Dra. González): los 10 textos rechazados no
// se muestran en la app.
import 'package:aptm/pantallas/modulos/modulo_autolesiones.dart';
import 'package:aptm/pantallas/modulos/modulo_suicidio.dart';
import 'package:aptm/pantallas/modulos/teen_info_carousel.dart';
import 'package:aptm/pantallas/modulos/textos_retirados.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Todas las tarjetas del carrusel, no solo las que se ven en pantalla.
Set<String?> _imagenesDelCarrusel(WidgetTester tester) => {
  for (final carrusel in tester.widgetList<TeenInfoCarousel>(
    find.byType(TeenInfoCarousel),
  ))
    for (final tarjeta in carrusel.cards) tarjeta.imagePath,
};

Future<void> _montar(WidgetTester tester, Widget modulo) async {
  SharedPreferences.setMockInitialValues({}); // sin sesión: vista de estudiante
  await tester.pumpWidget(MaterialApp(home: modulo));
  await tester.pumpAndSettle();
}

void main() {
  test('son exactamente los 10 textos de la revisión', () {
    expect(textosRetirados, hasLength(10));
    expect(estaRetirado('suicidio.quimicaDesc.adolescente'), isTrue);
    expect(estaRetirado('suicidio.quimicaDesc.familia'), isTrue);
    expect(estaRetirado('suicidio.devCerebralDesc.familia'), isFalse);
  });

  test('unirVisibles omite los retirados', () {
    final texto = unirVisibles([
      ('suicidio.devCerebralDesc.familia', 'cerebro'),
      ('suicidio.quimicaDesc.familia', 'serotonina'),
      ('suicidio.estresDesc.familia', 'estrés'),
    ]);
    expect(texto, 'cerebro');
  });

  test('para la familia, el estrés y la química salen; el resto queda', () {
    final texto = unirVisibles([
      ('suicidio.bloque1Content.familia', 'depresión'),
      ('suicidio.bloque2Content.familia', 'ideación'),
    ]);
    expect(texto, 'depresión\n\nideación');
  });

  test('sinRetirados quita los elementos retirados', () {
    final quedan = sinRetirados([
      ('suicidio.teenImgBloque1.adolescente', 1),
      ('suicidio.teenImgQuimicaCerebro.adolescente', 2),
      ('suicidio.teenImgEstres.adolescente', 3),
    ]);
    expect(quedan, [1]);
  });

  testWidgets('el módulo de suicidio no muestra química ni estrés', (
    tester,
  ) async {
    await _montar(tester, const ModuloSuicidio());

    final imagenes = _imagenesDelCarrusel(tester);
    expect(imagenes, contains('assets/imagenes/suicidio/1-bloque_1.png'));
    expect(
      imagenes,
      isNot(contains('assets/imagenes/suicidio/4-quimica_cerebro.png')),
    );
    expect(imagenes, isNot(contains('assets/imagenes/suicidio/5-estrés.png')));
    expect(find.textContaining('serotonina'), findsNothing);
  });

  testWidgets('el módulo de autolesiones no muestra advertencia ni qué hacer', (
    tester,
  ) async {
    await _montar(tester, const ModuloAutolesiones());

    final imagenes = _imagenesDelCarrusel(tester);
    expect(imagenes, contains('assets/imagenes/autolesiones/1-que_es.png'));
    expect(
      imagenes,
      isNot(contains('assets/imagenes/autolesiones/2-advertencia.png')),
    );
    expect(
      imagenes,
      isNot(contains('assets/imagenes/autolesiones/5-que_hacer.png')),
    );
    expect(find.textContaining('Prueba algo más seguro'), findsNothing);
  });
}
