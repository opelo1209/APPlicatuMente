import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'peticiones.dart';

class Auth {
  bool _googleInitialized = false;

  static const String _googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  Future<void> _initGoogle() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize(
        clientId: _googleClientId,
        serverClientId: _googleClientId,
      );
      _googleInitialized = true;
    }
  }

  Future<void> _saveSessionData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['access_token'] != null) {
      await prefs.setString('access_token', data['access_token']);
    }
    if (data['perfil_tipo'] != null) {
      await prefs.setString('perfil_tipo', data['perfil_tipo']);
    }

    final user = data['user'];
    if (user is Map<String, dynamic>) {
      if (user['id_usuario'] != null) {
        await prefs.setInt('id_usuario', user['id_usuario']);
      }
      if (user['nombre_usuario'] != null) {
        await prefs.setString('nombre_usuario', user['nombre_usuario']);
      }
    }
  }

  // Obtener token guardado
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Eliminar token (logout)
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('id_token');
    await prefs.remove('refresh_token');
    await prefs.remove('cuestionario_completado');
    await prefs.remove('perfil_tipo');
    await prefs.remove('id_usuario');
    await prefs.remove('nombre_usuario');
  }

  String _normalizeBase64(String value) {
    final output = value.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        return output;
      case 2:
        return '$output==';
      case 3:
        return '$output=';
      default:
        return output;
    }
  }

  Future<Map<String, dynamic>?> getTokenClaims() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return null;

      final parts = token.split('.');
      if (parts.length < 2) return null;

      final payload = utf8.decode(base64Decode(_normalizeBase64(parts[1])));
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error al leer claims del token: $e');
      return null;
    }
  }

  // LOGIN
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(Peticiones.login),
        headers: Peticiones.headers,
        body: jsonEncode({'username': username, 'password': password}),
      );

      debugPrint('Login Status Code: ${response.statusCode}');
      debugPrint('Login Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await _saveSessionData(data);

        return {'success': true, 'data': data, 'message': 'Login exitoso'};
      } else {
        return {
          'success': false,
          'message': 'Credenciales incorrectas',
          'error': response.body,
        };
      }
    } catch (e) {
      debugPrint('Error en login: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // REGISTER
  Future<Map<String, dynamic>> register({
    required String nombreUsuario,
    required String correo,
    required String password,
    required String nombres,
    required String apellidoPaterno,
    required String perfilTipo,
    List<String> estudiantesCurps = const [],
    String parentesco = 'padre/madre/tutor',
    String apellidoMaterno = '',
    String curp = '',
    DateTime? fechaNacimiento,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(Peticiones.register),
        headers: Peticiones.headers,
        body: jsonEncode({
          'nombre_usuario': nombreUsuario,
          'correo': correo,
          'password': password,
          'perfil_tipo': perfilTipo,
          'nombres': nombres,
          'apellido_paterno': apellidoPaterno,
          'apellido_materno': apellidoMaterno,
          'estudiantes_curps': estudiantesCurps,
          'parentesco': parentesco,
          if (curp.isNotEmpty) 'curp': curp,
          if (fechaNacimiento != null)
            'fecha_nacimiento':
                '${fechaNacimiento.year.toString().padLeft(4, '0')}-${fechaNacimiento.month.toString().padLeft(2, '0')}-${fechaNacimiento.day.toString().padLeft(2, '0')}',
        }),
      );

      debugPrint('Register Status Code: ${response.statusCode}');
      debugPrint('Register Response: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
          'message': 'Usuario registrado exitosamente',
        };
      } else if (response.statusCode == 409) {
        return {
          'success': false,
          'message': _extractErrorMessage(
            response.body,
            fallback: 'El usuario, correo o CURP ya está registrado',
          ),
        };
      } else {
        return {
          'success': false,
          'message': _extractErrorMessage(
            response.body,
            fallback: 'Error al registrar usuario',
          ),
          'error': response.body,
        };
      }
    } catch (e) {
      debugPrint('Error en register: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // PASSWORD RESET REQUEST
  static Future<Map<String, dynamic>> requestPasswordReset(
    String emailOrUsername,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(Peticiones.passwordResetRequest),
        headers: Peticiones.headers,
        body: jsonEncode({'email_or_username': emailOrUsername}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Correo enviado'};
      }
      return {
        'success': false,
        'message': data['detail'] ?? 'Error al solicitar recuperacion',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // PASSWORD RESET CONFIRM
  static Future<Map<String, dynamic>> resetPasswordConfirm(
    String token,
    String newPassword,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(Peticiones.passwordResetConfirm),
        headers: Peticiones.headers,
        body: jsonEncode({'token': token, 'new_password': newPassword}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Contraseña actualizada'};
      }
      return {
        'success': false,
        'message': data['detail'] ?? 'Error al restablecer contraseña',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // CHANGE PASSWORD (authenticated)
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay sesión activa'};
      }
      final response = await http.post(
        Uri.parse(Peticiones.changePassword),
        headers: Peticiones.getAuthHeaders(token),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Contraseña cambiada'};
      }
      return {
        'success': false,
        'message': data['detail'] ?? 'Error al cambiar contraseña',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  String _extractErrorMessage(String body, {required String fallback}) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }
        }
      }
    } catch (_) {
      // Usar fallback si el backend no responde JSON.
    }
    return fallback;
  }

  // Verificar si el usuario está autenticado
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  bool get isGoogleConfigured => _googleClientId.isNotEmpty;

  /// En Flutter Web, `GoogleSignIn.instance.authenticate()` no está
  /// soportado: hay que inicializar y luego escuchar [googleAuthEvents]
  /// mientras se muestra el botón nativo de Google (`renderButton`).
  Future<void> ensureGoogleInitialized() => _initGoogle();

  Stream<GoogleSignInAuthenticationEvent> get googleAuthEvents =>
      GoogleSignIn.instance.authenticationEvents;

  /// Envía el idToken de Google al backend y guarda la sesión si es válido.
  Future<Map<String, dynamic>> completeGoogleSignIn(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse(Peticiones.loginGoogle),
        headers: Peticiones.headers,
        body: jsonEncode({'token': idToken}),
      );

      debugPrint('Google Login Backend Status: ${response.statusCode}');
      debugPrint('Google Login Backend Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await _saveSessionData(data);

        return {
          'success': true,
          'data': data,
          'message': 'Login con Google exitoso',
        };
      }
      return {
        'success': false,
        'message': 'Credenciales de Google no aceptadas por el backend',
        'error': response.body,
      };
    } catch (e) {
      debugPrint('Error en completeGoogleSignIn: $e');
      return {
        'success': false,
        'message': 'Error en autenticación con Google: $e',
      };
    }
  }

  /// Login con Google fuera de la web (Android/iOS). En Web usa el botón
  /// nativo (ver [googleAuthEvents]) en vez de este método.
  Future<Map<String, dynamic>> loginWithGoogle() async {
    if (kIsWeb) {
      return {
        'success': false,
        'message': 'En la web usa el botón de Google para iniciar sesión.',
      };
    }
    if (_googleClientId.isEmpty) {
      return {
        'success': false,
        'message':
            'Google Sign-In no esta configurado (falta GOOGLE_CLIENT_ID en el build)',
      };
    }
    try {
      await _initGoogle();
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        return {
          'success': false,
          'message': 'No se pudo obtener el token de identidad de Google',
        };
      }

      return completeGoogleSignIn(idToken);
    } catch (e) {
      debugPrint('Error en loginWithGoogle: $e');
      return {
        'success': false,
        'message': 'Error en autenticación con Google: $e',
      };
    }
  }
}
