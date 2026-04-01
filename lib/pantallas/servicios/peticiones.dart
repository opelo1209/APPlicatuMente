class Peticiones {
  static const String baseUrl = 'http://killerbytes.space:8001';

  // Auth
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';

  // Usuarios
  static const String getUserMe = '$baseUrl/users/me';
  static const String syncUser = '$baseUrl/users/sync';
  static const String updateCuestionario = '$baseUrl/users/cuestionario';
  static const String getCuestionarioStatus = '$baseUrl/users/cuestionario/status';
  static const String getPerfil = '$baseUrl/users/perfil';
  static const String activarUsuario = '$baseUrl/users/activar';
  static const String desactivarUsuario = '$baseUrl/users/desactivar';

  // Serena chatbot
  static const String serenaChat = '$baseUrl/chat';
  static const String serenaSalud = '$baseUrl/salud';
  static const String serenaHistorial = '$baseUrl/chat/historial';

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> getAuthHeaders(String token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };
}