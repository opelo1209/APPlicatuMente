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
void main() {
  const payload = {
    'tipo_cuestionario': 'suicidio',
    'cssrs_nivel_dominio': 'planConcreto',
    'phq9_score': 18,
  };

  setUp(() => SharedPreferences.setMockInitialValues({}));

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
    final guardado = prefs.getString('cuestionario_suicidio');
    expect(guardado, isNotNull);
    expect(jsonDecode(guardado!)['phq9_score'], 18);
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
          jsonDecode(prefs.getString('cuestionarios_pendientes')!) as List;
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
      'cuestionarios_pendientes': 'esto no es json',
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
}
