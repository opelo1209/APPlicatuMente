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
