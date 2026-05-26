import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'peticiones.dart';

class User {
  // Obtener token guardado
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // GET /users/me - Obtener información del usuario actual
  Future<Map<String, dynamic>> getUserMe() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse(Peticiones.getUserMe),
        headers: Peticiones.getAuthHeaders(token),
      );

      debugPrint('Get User Me Status Code: ${response.statusCode}');
      debugPrint('Get User Me Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Token inválido o expirado',
          'unauthorized': true,
        };
      } else {
        return {
          'success': false,
          'message': 'Error al obtener información del usuario',
        };
      }
    } catch (e) {
      debugPrint('Error en getUserMe: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // GET /users/session - Contexto vivo del usuario, rol, permisos y progreso
  Future<Map<String, dynamic>> getSessionContext() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse(Peticiones.getSessionContext),
        headers: Peticiones.getAuthHeaders(token),
      );

      debugPrint('Get Session Context Status Code: ${response.statusCode}');
      debugPrint('Get Session Context Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Token inválido o expirado',
          'unauthorized': true,
        };
      }

      return {
        'success': false,
        'message': 'Error al obtener contexto de sesión',
        'body': response.body,
      };
    } catch (e) {
      debugPrint('Error en getSessionContext: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // POST /users/sync - Sincronizar usuario
  Future<Map<String, dynamic>> syncUser({
    required String keycloackId,
    required String correo,
    required String nombreUsuario,
    required String nombres,
    required String apellidoPaterno,
    String apellidoMaterno = '',
  }) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.post(
        Uri.parse(Peticiones.syncUser),
        headers: Peticiones.getAuthHeaders(token),
        body: jsonEncode({
          'keycloack_id': keycloackId,
          'correo': correo,
          'nombre_usuario': nombreUsuario,
          'nombres': nombres,
          'apellido_paterno': apellidoPaterno,
          'apellido_materno': apellidoMaterno,
        }),
      );

      debugPrint('Sync User Status Code: ${response.statusCode}');
      debugPrint('Sync User Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Error al sincronizar usuario'};
      }
    } catch (e) {
      debugPrint('Error en syncUser: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // PUT /users/cuestionario - Guardar sesión de cuestionario
  Future<Map<String, dynamic>> updateCuestionario({
    required String tipoCuestionario,
    required Map<String, dynamic> respuestas,
    bool completado = true,
  }) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.put(
        Uri.parse(Peticiones.updateCuestionario),
        headers: Peticiones.getAuthHeaders(token),
        body: jsonEncode({
          'tipo_cuestionario': tipoCuestionario,
          'respuestas': respuestas,
          'completado': completado,
        }),
      );

      debugPrint('Update Cuestionario Status Code: ${response.statusCode}');
      debugPrint('Update Cuestionario Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Error al guardar cuestionario (${response.statusCode})',
        'body': response.body,
      };
    } catch (e) {
      debugPrint('Error en updateCuestionario: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // GET /users/cuestionario/status - Obtener estado del cuestionario
  Future<Map<String, dynamic>> getCuestionarioStatus() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse(Peticiones.getCuestionarioStatus),
        headers: Peticiones.getAuthHeaders(token),
      );

      debugPrint('Get Cuestionario Status Code: ${response.statusCode}');
      debugPrint('Get Cuestionario Status Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': 'Error al obtener estado del cuestionario',
        };
      }
    } catch (e) {
      debugPrint('Error en getCuestionarioStatus: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // GET /cuestionarios/config?modulo=... - Preguntas activas por módulo
  Future<Map<String, dynamic>> getCuestionarioConfig({
    required String modulo,
  }) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final uri = Uri.parse(
        Peticiones.cuestionariosConfig,
      ).replace(queryParameters: {'modulo': modulo});
      final response = await http.get(
        uri,
        headers: Peticiones.getAuthHeaders(token),
      );

      debugPrint('Get Cuestionario Config Status Code: ${response.statusCode}');
      debugPrint('Get Cuestionario Config Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Error al obtener preguntas del cuestionario',
        'body': response.body,
      };
    } catch (e) {
      debugPrint('Error en getCuestionarioConfig: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // GET /users/perfil - Obtener perfil del usuario
  Future<Map<String, dynamic>> getPerfil() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse(Peticiones.getPerfil),
        headers: Peticiones.getAuthHeaders(token),
      );

      debugPrint('Get Perfil Status Code: ${response.statusCode}');
      debugPrint('Get Perfil Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Error al obtener perfil'};
      }
    } catch (e) {
      debugPrint('Error en getPerfil: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // GET /users/padres/estudiantes - Listar estudiantes vinculados al padre
  Future<Map<String, dynamic>> getEstudiantesVinculados() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse(Peticiones.padresEstudiantes),
        headers: Peticiones.getAuthHeaders(token),
      );

      debugPrint('Get Estudiantes Vinculados Status Code: ${response.statusCode}');
      debugPrint('Get Estudiantes Vinculados Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Error al obtener estudiantes vinculados',
        'body': response.body,
      };
    } catch (e) {
      debugPrint('Error en getEstudiantesVinculados: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // POST /users/padres/estudiantes - Vincular estudiante al padre
  Future<Map<String, dynamic>> vincularEstudiante({
    required int idEstudiante,
    String parentesco = 'padre/madre/tutor',
  }) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.post(
        Uri.parse(Peticiones.padresEstudiantes),
        headers: Peticiones.getAuthHeaders(token),
        body: jsonEncode({
          'id_estudiante': idEstudiante,
          'parentesco': parentesco,
        }),
      );

      debugPrint('Vincular Estudiante Status Code: ${response.statusCode}');
      debugPrint('Vincular Estudiante Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Error al vincular estudiante',
        'body': response.body,
      };
    } catch (e) {
      debugPrint('Error en vincularEstudiante: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // GET /admin/monitoreo - Respuestas de estudiantes y padres para administradores
  Future<Map<String, dynamic>> getMonitoreoAdmin() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse(Peticiones.adminMonitoreo),
        headers: Peticiones.getAuthHeaders(token),
      );

      debugPrint('Get Monitoreo Admin Status Code: ${response.statusCode}');
      debugPrint('Get Monitoreo Admin Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Error al obtener monitoreo',
        'body': response.body,
      };
    } catch (e) {
      debugPrint('Error en getMonitoreoAdmin: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // GET /admin/cuestionarios - Preguntas y puntajes editables por admin
  Future<Map<String, dynamic>> getAdminCuestionarios() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse(Peticiones.adminCuestionarios),
        headers: Peticiones.getAuthHeaders(token),
      );

      debugPrint('Get Admin Cuestionarios Status Code: ${response.statusCode}');
      debugPrint('Get Admin Cuestionarios Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Error al obtener preguntas',
        'body': response.body,
      };
    } catch (e) {
      debugPrint('Error en getAdminCuestionarios: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // PUT /admin/cuestionarios/{id} - Actualizar pregunta/puntaje
  Future<Map<String, dynamic>> updateAdminCuestionario({
    required int idPregunta,
    required String pregunta,
    required int puntaje,
    bool activo = true,
  }) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.put(
        Uri.parse('${Peticiones.adminCuestionarios}/$idPregunta'),
        headers: Peticiones.getAuthHeaders(token),
        body: jsonEncode({
          'pregunta': pregunta,
          'puntaje': puntaje,
          'activo': activo,
        }),
      );

      debugPrint('Update Admin Cuestionario Status Code: ${response.statusCode}');
      debugPrint('Update Admin Cuestionario Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Error al actualizar pregunta',
        'body': response.body,
      };
    } catch (e) {
      debugPrint('Error en updateAdminCuestionario: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // GET /users/padres/alertas - Obtener alertas de estudiantes vinculados
  Future<Map<String, dynamic>> getAlertas() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse(Peticiones.padresAlertas),
        headers: Peticiones.getAuthHeaders(token),
      );

      debugPrint('Get Alertas Status Code: ${response.statusCode}');
      debugPrint('Get Alertas Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Error al obtener alertas',
        'body': response.body,
      };
    } catch (e) {
      debugPrint('Error en getAlertas: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // PUT /users/activar - Activar usuario
  Future<Map<String, dynamic>> activarUsuario() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.put(
        Uri.parse(Peticiones.activarUsuario),
        headers: Peticiones.getAuthHeaders(token),
      );

      debugPrint('Activar Usuario Status Code: ${response.statusCode}');
      debugPrint('Activar Usuario Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Error al activar usuario'};
      }
    } catch (e) {
      debugPrint('Error en activarUsuario: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // PUT /users/desactivar - Desactivar usuario
  Future<Map<String, dynamic>> desactivarUsuario() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.put(
        Uri.parse(Peticiones.desactivarUsuario),
        headers: Peticiones.getAuthHeaders(token),
      );

      debugPrint('Desactivar Usuario Status Code: ${response.statusCode}');
      debugPrint('Desactivar Usuario Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Error al desactivar usuario'};
      }
    } catch (e) {
      debugPrint('Error en desactivarUsuario: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }
}
