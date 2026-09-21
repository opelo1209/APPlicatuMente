import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aptm/main.dart';
import 'package:aptm/pantallas/theme_provider.dart';

/// Prueba de arranque de la aplicación.
///
/// Sustituye a la plantilla que trae Flutter al crear un proyecto (un
/// contador que esta app nunca tuvo), que fallaba en cada ejecución desde el
/// inicio del proyecto y volvía inútil el resultado de `flutter test`.
void main() {
  setUpAll(cargarFuenteReal);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// La ventana de prueba por defecto (800x600) es más baja que cualquier
  /// teléfono actual y la pantalla de inicio de sesión se desborda ahí: usa
  /// una altura fija y no tiene desplazamiento (ver login.dart, Scaffold con
  /// resizeToAvoidBottomInset: false). Se prueba con un tamaño de teléfono
  /// real; el desbordamiento en pantallas cortas queda pendiente de arreglar
  /// en la pantalla, no en la prueba.
  Future<void> abrirApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Misma raíz que main(): MyApp lee el tema de un ThemeProvider.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la app arranca y muestra la pantalla de inicio de sesión', (
    WidgetTester tester,
  ) async {
    await abrirApp(tester);

    expect(find.text('Iniciar Sesión'), findsWidgets);
    expect(find.text('Usuario'), findsWidgets);
    expect(find.text('Contraseña'), findsWidgets);
  });

  testWidgets('la app arranca en español de México', (
    WidgetTester tester,
  ) async {
    await abrirApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.supportedLocales.first.languageCode, 'es');
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}

/// Carga la fuente Roboto real que trae el SDK de Flutter.
///
/// Por defecto las pruebas de widgets dibujan el texto con la fuente "Ahem",
/// en la que cada letra es un cuadro de 1 em: el texto sale mucho más ancho
/// que en un teléfono de verdad. Con ella, dos filas de login.dart (la del
/// saludo y la de "¿No tienes cuenta? Regístrate") se desbordaban 101 y 83 px
/// en un ancho de 390 px, aunque con la fuente real caben de sobra. Con
/// Roboto la prueba mide la pantalla como se ve realmente, así que un
/// desbordamiento que aparezca aquí sí es un defecto de la pantalla.
Future<void> cargarFuenteReal() async {
  final raizSdk = Platform.environment['FLUTTER_ROOT'];
  if (raizSdk == null) {
    throw StateError(
      'FLUTTER_ROOT no está definido: corre la prueba con '
      '`flutter test`.',
    );
  }
  final carpeta = '$raizSdk/bin/cache/artifacts/material_fonts';
  final cargador = FontLoader('Roboto');
  for (final archivo in const [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final bytes = File('$carpeta/$archivo').readAsBytesSync();
    cargador.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await cargador.load();
}
