// Semana 5: pantalla de cuentas del administrador.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aptm/pantallas/admin/cuentas_admin.dart';

Widget _app(Widget hijo) => MaterialApp(home: Scaffold(body: hijo));

void main() {
  test('borrar solo se confirma con el nombre de usuario exacto', () {
    expect(confirmacionDeBorrado('ana_demo', 'ana_demo'), isTrue);
    expect(confirmacionDeBorrado('  ana_demo ', 'ana_demo'), isTrue);
    expect(confirmacionDeBorrado('Ana_demo', 'ana_demo'), isFalse);
    expect(confirmacionDeBorrado('', ''), isFalse);
  });

  test('el aviso de borrado dice qué pasa con las alertas y los respaldos', () {
    expect(textoBorradoCuenta, contains('alertas de riesgo se conservan'));
    expect(textoBorradoCuenta, contains('14 días'));
    expect(textoBorradoCuenta, contains('No se puede deshacer'));
  });

  testWidgets('el botón de borrar se habilita al escribir el usuario',
      (tester) async {
    bool? resultado;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () async => resultado = await showDialog<bool>(
          context: context,
          builder: (_) => const DialogoBorrarCuenta(usuario: 'luis_demo'),
        ),
        child: const Text('abrir'),
      ),
    )));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    FilledButton boton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Borrar'));
    expect(boton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'luis_dem');
    await tester.pump();
    expect(boton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'luis_demo');
    await tester.pump();
    expect(boton().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();
    expect(resultado, isTrue);
  });

  testWidgets('la tarjeta muestra si la cuenta está desactivada y si es de Google',
      (tester) async {
    await tester.pumpWidget(_app(TarjetaCuenta(
      cuenta: const {
        'perfil_tipo': 'estudiante',
        'id_usuario': 7,
        'nombre_usuario': 'ana_demo',
        'nombre_completo': 'Ana Demo',
        'correo': 'ana@demo.local',
        'activo': false,
        'google': true,
        'ultima_conexion': '2026-10-23T10:00:00+00:00',
      },
      onCambio: () {},
    )));
    expect(find.text('Desactivada'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Reactivar'), findsOneWidget);
  });
}
