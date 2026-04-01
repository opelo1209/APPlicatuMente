import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'peticiones.dart';

class ServicioSerena {
  static Future<String?> _getSesionId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('serena_sesion_id');
    if (id == null) {
      id = 'sesion_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('serena_sesion_id', id);
    }
    return id;
  }

  static Future<Map<String, dynamic>> enviarMensaje(String mensaje) async {
    final sesionId = await _getSesionId();
    try {
      final response = await http.post(
        Uri.parse(Peticiones.serenaChat),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mensaje': mensaje,
          'sesion_id': sesionId,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {
          'respuesta': 'Hubo un error al conectar con Serena. Intenta de nuevo.',
          'tipo': 'error',
          'fuentes': [],
        };
      }
    } catch (e) {
      return {
        'respuesta': 'No pude conectarme. Verifica tu conexion a internet.',
        'tipo': 'error',
        'fuentes': [],
      };
    }
  }

  static Future<bool> verificarConexion() async {
    try {
      final response = await http.get(
        Uri.parse(Peticiones.serenaSalud),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<void> limpiarHistorial() async {
    final sesionId = await _getSesionId();
    try {
      await http.delete(
        Uri.parse('${Peticiones.serenaHistorial}?sesion_id=$sesionId'),
      ).timeout(const Duration(seconds: 5));
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('serena_sesion_id');
    } catch (_) {}
  }
}