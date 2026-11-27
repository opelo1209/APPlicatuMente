import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'peticiones.dart';

class ServicioSerena {
  // La identidad de la sesion la asigna el backend a partir del token de
  // autenticacion (ver chat_session_id en main.py); ya no se genera ni se
  // confia en un id creado por el cliente, que era adivinable.
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, dynamic>> enviarMensaje(String mensaje) async {
    final token = await _getToken();
    if (token == null) {
      return {
        'respuesta': 'Inicia sesion para hablar con Serena.',
        'tipo': 'error',
        'fuentes': <Map<String, String>>[],
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(Peticiones.serenaChat),
            headers: Peticiones.getAuthHeaders(token),
            body: jsonEncode({'mensaje': mensaje}),
          )
          // PROTOTIPO Semana 3: el modelo local del servidor tarda de 40 a
          // 65 s por respuesta; con 60 s algunas llegaban tarde.
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        return jsonDecode(body) as Map<String, dynamic>;
      }

      return {
        'respuesta': 'No pude procesar tu mensaje. Intenta de nuevo.',
        'tipo': 'error',
        'fuentes': <Map<String, String>>[],
      };
    } catch (_) {
      return {
        'respuesta': 'No hay conexion con Serena en este momento.',
        'tipo': 'error',
        'fuentes': <Map<String, String>>[],
      };
    }
  }

  /// PROTOTIPO Semana 3, fase 5: la respuesta por partes. Emite eventos
  /// {'evento': 'parcial', 'texto': ...} (texto ya revisado por la guardia)
  /// y al final {'evento': 'final', ...} con lo mismo que [enviarMensaje].
  ///
  /// Solo se vuelve a /chat si el servidor no tiene /chat/stream (codigo
  /// distinto de 200). Si la conexion se corta a la mitad NO se reenvia: el
  /// mensaje ya se proceso y se duplicaria en la memoria o en una alerta.
  static Stream<Map<String, dynamic>> enviarMensajeStream(
    String mensaje,
  ) async* {
    final token = await _getToken();
    if (token == null) {
      yield {'evento': 'final', ...await enviarMensaje(mensaje)};
      return;
    }
    final cliente = http.Client();
    try {
      final peticion =
          http.Request('POST', Uri.parse(Peticiones.serenaChatStream))
            ..headers.addAll(Peticiones.getAuthHeaders(token))
            ..body = jsonEncode({'mensaje': mensaje});
      final respuesta = await cliente
          .send(peticion)
          .timeout(const Duration(seconds: 20));
      if (respuesta.statusCode != 200) {
        yield {'evento': 'final', ...await enviarMensaje(mensaje)};
        return;
      }
      final lineas = respuesta.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 120));
      await for (final linea in lineas) {
        if (linea.trim().isEmpty) continue;
        final evento = jsonDecode(linea) as Map<String, dynamic>;
        yield evento['evento'] == 'error'
            ? {
                ..._error('No pude procesar tu mensaje. Intenta de nuevo.'),
                'evento': 'final',
              }
            : evento;
      }
    } catch (_) {
      yield {
        ..._error('No hay conexion con Serena en este momento.'),
        'evento': 'final',
      };
    } finally {
      cliente.close();
    }
  }

  static Map<String, dynamic> _error(String texto) => {
    'respuesta': texto,
    'tipo': 'error',
    'fuentes': <Map<String, String>>[],
  };

  static Future<bool> verificarConexion() async {
    try {
      final response = await http
          .get(Uri.parse(Peticiones.serenaSalud))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<void> limpiarHistorial() async {
    final token = await _getToken();
    if (token == null) return;

    try {
      await http
          .delete(
            Uri.parse(Peticiones.serenaHistorial),
            headers: Peticiones.getAuthHeaders(token),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // No-op: si falla, la proxima conversacion sigue funcionando igual,
      // solo no se limpio el historial del lado del servidor.
    }
  }
}
