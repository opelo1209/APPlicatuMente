// PROTOTIPO (Semana 2): llamadas al backend del diario, la vinculación en
// dos sentidos y las alertas de riesgo (mock_backend/app/prototipo_api.py).
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'peticiones.dart';

/// Resultado de una llamada: o trae datos, o un mensaje para mostrar.
class RespuestaApi {
  const RespuestaApi._(this.datos, this.mensaje, this.codigo);
  const RespuestaApi.ok(Map<String, dynamic> datos, int codigo)
    : this._(datos, null, codigo);
  const RespuestaApi.error(String mensaje, int codigo)
    : this._(null, mensaje, codigo);

  final Map<String, dynamic>? datos;
  final String? mensaje;
  final int codigo;

  bool get ok => datos != null;
}

class ServicioPrototipo {
  static const _espera = Duration(seconds: 60);

  static Future<RespuestaApi> _llamar(
    String metodo,
    String url, [
    Map<String, dynamic>? cuerpo,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      return const RespuestaApi.error('Inicia sesión de nuevo.', 401);
    }
    final headers = Peticiones.getAuthHeaders(token);
    try {
      final uri = Uri.parse(url);
      final respuesta = await switch (metodo) {
        'GET' => http.get(uri, headers: headers),
        _ => http.post(uri, headers: headers, body: jsonEncode(cuerpo ?? {})),
      }.timeout(_espera);
      final texto = utf8.decode(respuesta.bodyBytes);
      final json = texto.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(texto) as Map<String, dynamic>;
      if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
        return RespuestaApi.ok(json, respuesta.statusCode);
      }
      return RespuestaApi.error(_mensaje(json), respuesta.statusCode);
    } on TimeoutException {
      return const RespuestaApi.error(
        'El servidor tardó demasiado. Intenta de nuevo.',
        0,
      );
    } on http.ClientException {
      return const RespuestaApi.error('No hay conexión con el servidor.', 0);
    } on FormatException {
      return const RespuestaApi.error('Respuesta inesperada del servidor.', 0);
    }
  }

  static String _mensaje(Map<String, dynamic> json) {
    final detalle = json['detail'];
    if (detalle is String) return detalle;
    if (detalle is Map && detalle['mensaje'] is String) {
      final restantes = detalle['intentos_restantes'];
      return restantes == null
          ? detalle['mensaje'] as String
          : '${detalle['mensaje']} Te quedan $restantes intentos.';
    }
    if (detalle is List && detalle.isNotEmpty) {
      return 'Revisa los datos: ${(detalle.first as Map)['msg'] ?? ''}';
    }
    return 'Algo salió mal. Intenta de nuevo.';
  }

  // ------------------------------ Diario ---------------------------------

  static Future<RespuestaApi> guardarEntrada({
    required String polaridad,
    required List<String> emociones,
    required String texto,
  }) => _llamar('POST', Peticiones.diarioEntradas, {
    'polaridad': polaridad,
    'emociones': emociones,
    'texto': texto,
  });

  static Future<RespuestaApi> listarEntradas({int dias = 7}) =>
      _llamar('GET', '${Peticiones.diarioEntradas}?dias=$dias');

  // ---------------------------- Vinculación -------------------------------

  static Future<RespuestaApi> estudianteRegistraTutor({
    required String nombre,
    required String curp,
    required String correo,
    required String parentesco,
  }) => _llamar('POST', Peticiones.vinculacionSolicitudes, {
    'nombre': nombre,
    'curp': curp,
    'correo': correo,
    'parentesco': parentesco,
  });

  static Future<RespuestaApi> estudianteSolicitudes() =>
      _llamar('GET', Peticiones.vinculacionEstudiante);

  static Future<RespuestaApi> estudianteResponde(int id, bool acepta) =>
      _llamar('POST', Peticiones.vinculacionRespuesta(id), {'acepta': acepta});

  static Future<RespuestaApi> tutorPendientes() =>
      _llamar('GET', Peticiones.vinculacionTutor);

  static Future<RespuestaApi> tutorConfirma(
    int id, {
    required String curpPropia,
    required String curpEstudiante,
    required String fechaNacimiento,
    required String codigo,
  }) => _llamar('POST', Peticiones.vinculacionConfirmar(id), {
    'curp_propia': curpPropia,
    'curp_estudiante': curpEstudiante,
    'fecha_nacimiento': fechaNacimiento,
    'codigo': codigo,
  });

  static Future<RespuestaApi> tutorSolicita({
    required String curpEstudiante,
    required String fechaNacimiento,
    required String parentesco,
  }) => _llamar('POST', Peticiones.vinculacionTutorSolicitudes, {
    'curp_estudiante': curpEstudiante,
    'fecha_nacimiento': fechaNacimiento,
    'parentesco': parentesco,
  });

  // ------------------------------ Alertas ---------------------------------

  static Future<RespuestaApi> alertasRiesgo({bool soloPendientes = false}) =>
      _llamar(
        'GET',
        soloPendientes
            ? '${Peticiones.adminAlertasRiesgo}?pendientes=true'
            : Peticiones.adminAlertasRiesgo,
      );

  /// Semana 5 (H9): marca la alerta como atendida o la regresa a pendiente.
  static Future<RespuestaApi> atenderAlerta(
    int idAlerta, {
    required bool atendida,
    String nota = '',
  }) => _llamar('POST', Peticiones.adminAtenderAlerta(idAlerta), {
    'atendida': atendida,
    'nota': nota,
  });

  static Future<RespuestaApi> resumenRiesgo(int idUsuario, {int dias = 30}) =>
      _llamar('GET', '${Peticiones.adminResumenRiesgo(idUsuario)}?dias=$dias');
}
