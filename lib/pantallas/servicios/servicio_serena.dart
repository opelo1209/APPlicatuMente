import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'peticiones.dart';

class ServicioSerena {
  static Future<String> _getSesionId() async {
    final prefs = await SharedPreferences.getInstance();
    final actual = prefs.getString('serena_sesion_id');
    if (actual != null && actual.isNotEmpty) {
      return actual;
    }

    final nuevo = 'sesion_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('serena_sesion_id', nuevo);
    return nuevo;
  }

  static Future<Map<String, dynamic>> enviarMensaje(String mensaje) async {
    final sesionId = await _getSesionId();

    try {
      final response = await http
          .post(
            Uri.parse(Peticiones.serenaChat),
            headers: Peticiones.headers,
            body: jsonEncode({
              'mensaje': mensaje,
              'sesion_id': sesionId,
            }),
          )
          .timeout(const Duration(seconds: 60));

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
    final sesionId = await _getSesionId();

    try {
      await http
          .delete(
            Uri.parse('${Peticiones.serenaHistorial}?sesion_id=$sesionId'),
            headers: Peticiones.headers,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // No-op: si falla, igual limpiamos sesion local para empezar limpio.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('serena_sesion_id');
  }
}
