import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'peticiones.dart';

class Auth {
  bool _googleInitialized = false;

  void _initGoogle() {
    if (!_googleInitialized) {
      GoogleSignIn.instance.initialize(
        // Es obligatorio en Android para poder obtener el idToken
        serverClientId:
            '773970807427-dqu2tgcoq7sbklofmlr9bbhmv48g9631.apps.googleusercontent.com',
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
      print('Error al leer claims del token: $e');
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

      print('Login Status Code: ${response.statusCode}');
      print('Login Response: ${response.body}');

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
      print('Error en login: $e');
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
    List<int> estudiantesIds = const [],
    String parentesco = 'padre/madre/tutor',
    String apellidoMaterno = '',
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
          'estudiantes_ids': estudiantesIds,
          'parentesco': parentesco,
        }),
      );

      print('Register Status Code: ${response.statusCode}');
      print('Register Response: ${response.body}');

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
          'message': 'El usuario o correo ya está registrado',
        };
      } else {
        return {
          'success': false,
          'message': 'Error al registrar usuario',
          'error': response.body,
        };
      }
    } catch (e) {
      print('Error en register: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Verificar si el usuario está autenticado
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Login con Google usando backend
  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      _initGoogle();
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance
          .authenticate();
      if (googleUser == null) {
        return {
          'success': false,
          'message': 'Login con Google cancelado por el usuario',
        };
      }

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        return {
          'success': false,
          'message': 'No se pudo obtener el token de identidad de Google',
        };
      }

      // Enviar idToken a nuestro endpoint de FastAPI
      final response = await http.post(
        Uri.parse(Peticiones.loginGoogle),
        headers: Peticiones.headers,
        body: jsonEncode({'token': idToken}),
      );

      print('Google Login Backend Status: ${response.statusCode}');
      print('Google Login Backend Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await _saveSessionData(data);

        return {
          'success': true,
          'data': data,
          'message': 'Login con Google exitoso',
        };
      } else {
        return {
          'success': false,
          'message': 'Credenciales de Google no aceptadas por el backend',
          'error': response.body,
        };
      }
    } catch (e) {
      print('Error en loginWithGoogle: $e');
      return {
        'success': false,
        'message': 'Error en autenticación con Google: $e',
      };
    }
  }
}
