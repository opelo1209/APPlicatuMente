import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'peticiones.dart';

class Auth {
  // Almacenar token en SharedPreferences
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
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
    await prefs.remove('cuestionario_completado');
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
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      print('Login Status Code: ${response.statusCode}');
      print('Login Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Guardar el access_token
        if (data['access_token'] != null) {
          await _saveToken(data['access_token']);
        }
        
        return {
          'success': true,
          'data': data,
          'message': 'Login exitoso',
        };
      } else {
        return {
          'success': false,
          'message': 'Credenciales incorrectas',
          'error': response.body,
        };
      }
    } catch (e) {
      print('Error en login: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  // REGISTER
  Future<Map<String, dynamic>> register({
    required String nombreUsuario,
    required String correo,
    required String password,
    required String nombres,
    required String apellidoPaterno,
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
          'nombres': nombres,
          'apellido_paterno': apellidoPaterno,
          'apellido_materno': apellidoMaterno,
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
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  // Verificar si el usuario está autenticado
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}