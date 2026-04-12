/// Configuración de la API de Serena
class Peticiones {
  static const String baseUrlAuth   = 'http://killerbytes.space:8001';
  static const String baseUrlSerena = 'http://127.0.0.1:8000';

  static const String login    = '$baseUrlAuth/auth/login';
  static const String register = '$baseUrlAuth/auth/register';

  static const String getUserMe             = '$baseUrlAuth/users/me';
  static const String syncUser              = '$baseUrlAuth/users/sync';
  static const String updateCuestionario    = '$baseUrlAuth/users/cuestionario';
  static const String getCuestionarioStatus = '$baseUrlAuth/users/cuestionario/status';
  static const String getPerfil             = '$baseUrlAuth/users/perfil';
  static const String activarUsuario        = '$baseUrlAuth/users/activar';
  static const String desactivarUsuario     = '$baseUrlAuth/users/desactivar';

  static const String serenaChat      = '$baseUrlSerena/chat';
  static const String serenaHistorial = '$baseUrlSerena/chat/historial';
  static const String salud           = '$baseUrlSerena/salud';

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept':       'application/json',
  };

  static Map<String, String> getAuthHeaders(String token) => {
    'Content-Type':  'application/json',
    'Accept':        'application/json',
    'Authorization': 'Bearer $token',
  };
}
