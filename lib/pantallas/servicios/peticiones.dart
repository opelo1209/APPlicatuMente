/// Configuración de la API
class Peticiones {
  // Cambia esta URL según tu entorno
  // Para emulador Android: http://10.0.2.2:8000
  // Para iOS Simulator: http://localhost:8000
  // Para dispositivo físico: http://127.0.0.1:8001
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8001',
  );

  // Endpoints
  static const String login = '$baseUrl/auth/login';
  static const String loginGoogle = '$baseUrl/auth/google';
  static const String register = '$baseUrl/auth/register';
  static const String getUserMe = '$baseUrl/users/me';
  static const String getSessionContext = '$baseUrl/users/session';
  static const String syncUser = '$baseUrl/users/sync';
  static const String updateCuestionario = '$baseUrl/users/cuestionario';
  static const String cuestionariosConfig = '$baseUrl/cuestionarios/config';
  static const String getCuestionarioStatus =
      '$baseUrl/users/cuestionario/status';
  static const String getPerfil = '$baseUrl/users/perfil';
  static const String activarUsuario = '$baseUrl/users/activar';
  static const String desactivarUsuario = '$baseUrl/users/desactivar';
  static const String padresEstudiantes = '$baseUrl/users/padres/estudiantes';
  static const String adminMonitoreo = '$baseUrl/admin/monitoreo';
  static const String adminCuestionarios = '$baseUrl/admin/cuestionarios';

  // Serena chatbot
  static const String serenaChat = '$baseUrl/chat';
  static const String serenaHistorial = '$baseUrl/chat/historial';
  static const String serenaSalud = '$baseUrl/salud';

  // Análisis médico — endpoint externo
  static const String postCuestionario = '$baseUrl/users/cuestionario';

  // Headers comunes
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
