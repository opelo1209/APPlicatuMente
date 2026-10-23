// Semana 5 (H8): la preferencia de modo oscuro sobrevive al reinicio.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aptm/pantallas/servicios/auth.dart';
import 'package:aptm/pantallas/theme_provider.dart';

/// Lo mismo que hace main() al arrancar.
Future<ThemeProvider> arrancar() async => ThemeProvider(
  modoOscuro: ThemeProvider.preferenciaGuardada(
    await SharedPreferences.getInstance(),
  ),
);

void main() {
  test('sin preferencia guardada arranca en modo claro', () async {
    SharedPreferences.setMockInitialValues({});
    expect((await arrancar()).isDarkMode, isFalse);
  });

  test('activar el modo oscuro se conserva al reiniciar', () async {
    SharedPreferences.setMockInitialValues({});
    await (await arrancar()).toogleTheme(true);
    expect((await arrancar()).isDarkMode, isTrue);
  });

  test('arrancar no sobrescribe la preferencia guardada', () async {
    SharedPreferences.setMockInitialValues({ThemeProvider.claveModoOscuro: true});
    await arrancar();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ThemeProvider.claveModoOscuro), isTrue);
  });

  test('regresar al modo claro también se conserva', () async {
    SharedPreferences.setMockInitialValues({ThemeProvider.claveModoOscuro: true});
    await (await arrancar()).toogleTheme(false);
    expect((await arrancar()).isDarkMode, isFalse);
  });

  group('mensaje de inicio de sesión (H5, H6)', () {
    test('un bloqueo muestra la espera que manda el servidor', () {
      expect(
        mensajeDeLogin(
          429,
          '{"detail": "Demasiados intentos. Espera 15 minutos e inténtalo de nuevo."}',
        ),
        startsWith('Demasiados intentos'),
      );
    });

    test('una cuenta desactivada dice a quién pedir ayuda', () {
      expect(
        mensajeDeLogin(403, '{"detail": "Tu cuenta está desactivada."}'),
        'Tu cuenta está desactivada.',
      );
    });

    test('cualquier otro error no revela nada', () {
      expect(
        mensajeDeLogin(401, '{"detail": "Credenciales incorrectas"}'),
        'Credenciales incorrectas',
      );
      expect(mensajeDeLogin(429, 'no es json'), 'Credenciales incorrectas');
    });
  });
}
