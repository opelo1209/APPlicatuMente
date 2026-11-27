// Semana 8 (asesor): recuperación de contraseña con el enlace del correo o
// con el código del administrador.
import 'package:aptm/pantallas/admin/cuentas_admin.dart';
import 'package:aptm/pantallas/restablecer_contrasena.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _token = 'Zx9_abcDEF-0123456789abcdEFGH';

void main() {
  group('enlace del correo', () {
    test('lee el token de /restablecer', () {
      final uri = Uri.parse(
        'https://ml.izt.uam.mx/aptm/#/restablecer?token=$_token',
      );
      expect(tokenDeEnlace(uri), _token);
    });

    test('ignora otras rutas y tokens con caracteres raros', () {
      expect(
        tokenDeEnlace(Uri.parse('https://x/aptm/#/otra?token=$_token')),
        isNull,
      );
      expect(tokenDeEnlace(Uri.parse('https://x/aptm/')), isNull);
      expect(
        tokenDeEnlace(Uri.parse('https://x/aptm/#/restablecer?token=<script>')),
        isNull,
      );
      expect(
        tokenDeEnlace(Uri.parse('https://x/aptm/#/restablecer?token=corto')),
        isNull,
      );
    });
  });

  group('pantalla de contraseña nueva', () {
    testWidgets('con el código del administrador envía código y contraseña', (
      tester,
    ) async {
      String? enviado;
      await tester.pumpWidget(
        MaterialApp(
          home: RestablecerContrasena(
            enviar: (codigo, nueva) async {
              enviado = '$codigo|$nueva';
              return {'success': true};
            },
          ),
        ),
      );
      final campos = find.byType(TextField);
      expect(campos, findsNWidgets(3));
      await tester.enterText(campos.at(0), ' abcd-2345 ');
      await tester.enterText(campos.at(1), 'nueva-clave');
      await tester.enterText(campos.at(2), 'nueva-clave');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();

      expect(enviado, 'abcd-2345|nueva-clave');
      expect(find.textContaining('tu contraseña cambió'), findsOneWidget);
    });

    testWidgets('con el enlace solo pide la contraseña y manda el token', (
      tester,
    ) async {
      String? enviado;
      await tester.pumpWidget(
        MaterialApp(
          home: RestablecerContrasena(
            token: _token,
            enviar: (token, _) async {
              enviado = token;
              return {'success': true};
            },
          ),
        ),
      );
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).at(0), 'nueva-clave');
      await tester.enterText(find.byType(TextField).at(1), 'nueva-clave');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();

      expect(enviado, _token);
    });

    testWidgets('valida antes de enviar', (tester) async {
      var envios = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RestablecerContrasena(
            token: _token,
            enviar: (_, _) async {
              envios++;
              return {'success': true};
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), 'corta');
      await tester.enterText(find.byType(TextField).at(1), 'corta');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pump();
      expect(find.textContaining('al menos 8 caracteres'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'nueva-clave');
      await tester.enterText(find.byType(TextField).at(1), 'otra-clave');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pump();
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(envios, 0);
    });

    testWidgets('muestra el error del servidor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RestablecerContrasena(
            token: _token,
            enviar: (_, _) async => {
              'success': false,
              'message': 'El enlace o el código no es válido o ya venció.',
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), 'nueva-clave');
      await tester.enterText(find.byType(TextField).at(1), 'nueva-clave');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no es válido'), findsOneWidget);
    });
  });

  testWidgets('el administrador ve el código una vez, con cómo usarlo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DialogoCodigoRecuperacion(
            usuario: 'ana_demo',
            codigo: 'ABCD-2345',
            horas: 24,
          ),
        ),
      ),
    );
    expect(find.text('ABCD-2345'), findsOneWidget);
    expect(find.textContaining('Sirve una sola vez'), findsOneWidget);
    expect(find.textContaining('24 horas'), findsOneWidget);
  });
}
