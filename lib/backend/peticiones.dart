import 'dart:convert';
import 'package:http/http.dart' as http;

class Peticiones {
  // Aquí puedes definir las funciones que necesites para manejar las peticiones
  // Por ejemplo, una función para obtener datos de una API

  Future<void> obtenerDatos() async {
    // Lógica para obtener datos
  }

  Future<void> enviarDatos() async {
    // Lógica para enviar datos
  }

  Future<http.Response> enviarChat(String jsonString) async {
    final response = await http.post(
      Uri.parse('https://60cc-201-102-248-168.ngrok-free.app/chat'),
      headers: {
        'Content-Type': 'application/json', // Indica que el cuerpo es JSON
      },
      body: jsonString, // Convierte el mapa a un JSON
    );
    return response;
  }

  Future<http.Response> botonEmergencia() async {
    Map<String, dynamic> jsonBody = {
      "user_id": "web_user",
      "name": "Usuario Web",
      "message": "Me siento mal",
      "location": "desde navegador",
      "emergency_contacts": [
        {"email": "metaknight445@gmail.com", "name": "Contacto 1"},
        {"email": "akane8264@gmail.com", "name": "Contacto 2"},
      ],
    };

    final response = http.post(
      Uri.parse('https://14c4-78-12-15-152.ngrok-free.app/start'),
      headers: {
        'Content-Type': 'application/json', // Indica que el cuerpo es JSON
      },
      body: jsonEncode(jsonBody), // Convierte el mapa a un JSON
    );
    return response;
  }

  Future<http.Response> registrarUsuario(
    String usuario,
    String nombre,
    String correo,
    String password,
  ) async {
    Map<String, dynamic> jsonBody = {
      "usuario": usuario,
      "nombre": nombre,
      "correo": correo,
      "contrasena": password,
    };

    final response = await http.post(
      Uri.parse('https://14c4-78-12-15-152.ngrok-free.app/registrar_usuario'),
      headers: {
        'Content-Type': 'application/json', // Indica que el cuerpo es JSON
      },
      body: jsonEncode(jsonBody), // Convierte el mapa a un JSON
    );
    return response;
  }

  Future<http.Response> iniciarSesion(String usuario) async {
    final uri = Uri.parse(
      'https://14c4-78-12-15-152.ngrok-free.app/consultar_usuario?usuario=$usuario',
    );

    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    return response;
  }
}
