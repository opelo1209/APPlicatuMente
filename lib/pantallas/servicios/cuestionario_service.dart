import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'peticiones.dart';

/// Servicio para enviar resultados de cuestionarios clínicos al servidor
/// de análisis médico (api.killerbytes.space).
class CuestionarioService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Envía un cuestionario completo 
  /// Estructura:
  /// ```json
  /// {
  ///   "bloque": "PHQ9",
  ///   "nombre": "Depresión y Riesgo (PHQ-9)",
  ///   "puntuacion_total": 14,
  ///   "reactivos": [
  ///     {
  ///       "numero": 1,
  ///       "id": "deprimido_irritable",
  ///       "pregunta": "¿Te has sentido deprimido...?",
  ///       "tipo_respuesta": "likert4",
  ///       "respuesta_valor": 2,
  ///       "respuesta_etiqueta": "Más de la mitad de los días"
  ///     }
  ///   ]
  /// }
  /// ```
  Future<Map<String, dynamic>> enviarCuestionario({
    required String tipoCuestionario,
    required List<Map<String, dynamic>> bloques,
  }) async {
    try {
      final token = await _getToken();
      final headers =
          token != null ? Peticiones.getAuthHeaders(token) : Peticiones.headers;

      final body = jsonEncode({
        'tipo_cuestionario': tipoCuestionario,
        'fecha_aplicacion': DateTime.now().toUtc().toIso8601String(),
        'bloques': bloques,
      });

      debugPrint('[CuestionarioService] POST ${Peticiones.postCuestionario}');
      debugPrint('[CuestionarioService] Body: $body');

      final response = await http
          .post(
            Uri.parse(Peticiones.postCuestionario),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[CuestionarioService] Status: ${response.statusCode}');
      debugPrint('[CuestionarioService] Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'message': 'Error ${response.statusCode}',
          'body': response.body,
        };
      }
    } catch (e) {
      debugPrint('[CuestionarioService] Error: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }
}
