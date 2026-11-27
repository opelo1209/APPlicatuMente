import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aptm/pantallas/cuestionarios/envio_cuestionario.dart';

/// Pruebas de la cola de reenvío: lo que garantiza que una respuesta no se
/// pierda cuando el servidor no la recibe.
///
/// No se prueba el envío real (requiere red); se prueba lo que ocurre con lo
/// guardado en el dispositivo, que es donde estaba el defecto: la app daba
/// por completado un cuestionario que nunca llegó al servidor.
/// Clave de la cola de un usuario (la misma regla que usa la app).
String colaDe(String perfil, int id) => 'cuestionarios_pendientes_${perfil}_$id';

void main() {
  const payload = {
    'tipo_cuestionario': 'suicidio',
    'cssrs_nivel_dominio': 'planConcreto',
    'phq9_score': 18,
  };

  // Sesión del estudiante 7 sin token: el envío falla igual que sin red.
  const sesionA = {'perfil_tipo': 'estudiante', 'id_usuario': 7};

  setUp(() => SharedPreferences.setMockInitialValues(sesionA));

  test('sin conexión, el módulo NO se marca como completado', () async {
    // Sin token guardado, el envío falla igual que sin internet.
    final enviado = await EnvioCuestionario.enviar(
      tipo: 'suicidio',
      payload: payload,
    );

    expect(enviado, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('modulo_suicidio_completado'),
      isNull,
      reason:
          'un cuestionario que no llegó al servidor no puede darse por completado',
    );
    expect(prefs.getBool('cuestionario_suicidio_completado'), isNull);
  });

  test('sin conexión, la respuesta se conserva en el dispositivo', () async {
    await EnvioCuestionario.enviar(tipo: 'suicidio', payload: payload);

    final prefs = await SharedPreferences.getInstance();
    final cola =
        jsonDecode(prefs.getString(colaDe('estudiante', 7))!) as List;
    expect(cola.single['payload']['phq9_score'], 18);
  });

  test('la respuesta queda en la cola de reenvío', () async {
    await EnvioCuestionario.enviar(tipo: 'suicidio', payload: payload);

    expect(await EnvioCuestionario.cuantasPendientes(), 1);
  });

  test(
    'contestar dos veces el mismo cuestionario deja una sola pendiente, la última',
    () async {
      await EnvioCuestionario.enviar(tipo: 'suicidio', payload: payload);
      await EnvioCuestionario.enviar(
        tipo: 'suicidio',
        payload: {...payload, 'phq9_score': 22},
      );

      expect(await EnvioCuestionario.cuantasPendientes(), 1);

      final prefs = await SharedPreferences.getInstance();
      final cola =
          jsonDecode(prefs.getString(colaDe('estudiante', 7))!) as List;
      expect(cola.single['payload']['phq9_score'], 22);
    },
  );

  test('cuestionarios distintos se encolan por separado', () async {
    await EnvioCuestionario.enviar(tipo: 'suicidio', payload: payload);
    await EnvioCuestionario.enviar(
      tipo: 'ansiedad',
      payload: const {'gad7_score': 12},
    );

    expect(await EnvioCuestionario.cuantasPendientes(), 2);
  });

  test('una cola corrupta no rompe la app ni borra la respuesta', () async {
    SharedPreferences.setMockInitialValues({
      ...sesionA,
      colaDe('estudiante', 7): 'esto no es json',
    });

    expect(await EnvioCuestionario.cuantasPendientes(), 0);
    expect(await EnvioCuestionario.reintentarPendientes(), 0);

    final enviado = await EnvioCuestionario.enviar(
      tipo: 'ansiedad',
      payload: const {'gad7_score': 9},
    );
    expect(enviado, isFalse);
    expect(await EnvioCuestionario.cuantasPendientes(), 1);
  });

  test('reintentar sin conexión no marca nada como completado', () async {
    await EnvioCuestionario.enviar(tipo: 'suicidio', payload: payload);

    expect(await EnvioCuestionario.reintentarPendientes(), 0);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('modulo_suicidio_completado'), isNull);
    expect(
      await EnvioCuestionario.cuantasPendientes(),
      1,
      reason:
          'la respuesta debe seguir en la cola hasta que el servidor la reciba',
    );
  });

  // ------------------------------------------------------------------
  // Semana 4, T1 (H1): la cola es de cada usuario, no del dispositivo.
  // ------------------------------------------------------------------
  group('dispositivo compartido', () {
    Future<void> entraB() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('perfil_tipo', 'estudiante');
      await prefs.setInt('id_usuario', 8);
    }

    test('lo que A dejó pendiente no lo ve B', () async {
      await EnvioCuestionario.enviar(tipo: 'suicidio', payload: payload);
      expect(await EnvioCuestionario.cuantasPendientes(), 1);

      await entraB();

      expect(await EnvioCuestionario.cuantasPendientes(), 0);
      expect(await EnvioCuestionario.reintentarPendientes(), 0);
    });

    test('borrarDelUsuarioActual elimina lo pendiente de quien sale', () async {
      await EnvioCuestionario.enviar(tipo: 'suicidio', payload: payload);

      await EnvioCuestionario.borrarDelUsuarioActual();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(colaDe('estudiante', 7)), isNull);
      expect(await EnvioCuestionario.cuantasPendientes(), 0);
    });

    test('al salir sin red, lo de A se conserva para A y B no lo ve', () async {
      await EnvioCuestionario.enviar(tipo: 'suicidio', payload: payload);

      // Lo que hace el cierre de sesión: reintento (falla) y limpieza.
      await EnvioCuestionario.alCerrarSesion();
      await entraB();
      expect(await EnvioCuestionario.cuantasPendientes(), 0);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('id_usuario', 7);
      expect(
        await EnvioCuestionario.cuantasPendientes(),
        1,
        reason: 'una respuesta de riesgo no se pierde en silencio al salir',
      );
    });

    test('al abrir la app se limpia la cola global antigua', () async {
      SharedPreferences.setMockInitialValues({
        ...sesionA,
        'cuestionarios_pendientes': jsonEncode([
          {'tipo': 'suicidio', 'payload': payload},
        ]),
        'cuestionario_ansiedad': '{}',
      });

      await EnvioCuestionario.reintentarPendientes();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cuestionarios_pendientes'), isNull);
      expect(prefs.getString('cuestionario_ansiedad'), isNull);
    });

    test('cerrar sesión no toca lo pendiente de otro usuario', () async {
      SharedPreferences.setMockInitialValues({
        ...sesionA,
        colaDe('estudiante', 8): jsonEncode([
          {'tipo': 'ansiedad', 'payload': {'gad7_score': 3}, 'dueno': 'estudiante_8'},
        ]),
      });

      await EnvioCuestionario.borrarDelUsuarioActual();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(colaDe('estudiante', 8)), isNotNull);
    });

    test('se borra la cola global de versiones anteriores y sus copias', () async {
      SharedPreferences.setMockInitialValues({
        ...sesionA,
        'cuestionarios_pendientes': jsonEncode([
          {'tipo': 'suicidio', 'payload': payload},
        ]),
        'cuestionario_suicidio': jsonEncode(payload),
      });

      // La cola global no tiene dueño: nunca se envía con la cuenta actual.
      expect(await EnvioCuestionario.cuantasPendientes(), 0);
      await EnvioCuestionario.borrarDelUsuarioActual();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cuestionarios_pendientes'), isNull);
      expect(prefs.getString('cuestionario_suicidio'), isNull);
    });

    test('no se guarda una copia del cuestionario fuera de la cola', () async {
      await EnvioCuestionario.enviar(tipo: 'suicidio', payload: payload);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cuestionario_suicidio'), isNull);
    });

    test('un pendiente con otro dueño en la cola no se envía', () async {
      SharedPreferences.setMockInitialValues({
        ...sesionA,
        colaDe('estudiante', 7): jsonEncode([
          {'tipo': 'suicidio', 'payload': payload, 'dueno': 'estudiante_8'},
        ]),
      });

      expect(await EnvioCuestionario.cuantasPendientes(), 0);
    });

    test('sin sesión no se guarda nada en el dispositivo', () async {
      SharedPreferences.setMockInitialValues({});

      final enviado = await EnvioCuestionario.enviar(
        tipo: 'suicidio',
        payload: payload,
      );

      expect(enviado, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });
  });
}
