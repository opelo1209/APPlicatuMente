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
  static const String logout = '$baseUrl/auth/logout';
  static const String register = '$baseUrl/auth/register';
  // Acceso rapido de la demo: 404 en un despliegue normal, por lo que el
  // boton de la pantalla de acceso se oculta solo.
  static const String demoDisponibilidad = '$baseUrl/auth/demo';
  static const String demoLogin = '$baseUrl/auth/demo';
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
  static String padreEstudianteUnlink(String curp) =>
      '$baseUrl/users/padres/estudiantes/${Uri.encodeComponent(curp)}';
  static const String adminMonitoreo = '$baseUrl/admin/monitoreo';
  static const String adminCuestionarios = '$baseUrl/admin/cuestionarios';

  // Serena chatbot
  static const String serenaChat = '$baseUrl/chat';
  // PROTOTIPO Semana 3, fase 5: la misma respuesta en lineas JSON (NDJSON).
  static const String serenaChatStream = '$baseUrl/chat/stream';
  static const String serenaHistorial = '$baseUrl/chat/historial';
  static const String serenaSalud = '$baseUrl/salud';

  // PROTOTIPO Semana 2: diario, vinculación en dos sentidos y alertas.
  static const String diarioEntradas = '$baseUrl/diario/entradas';
  static const String vinculacionSolicitudes =
      '$baseUrl/vinculacion/solicitudes';
  static const String vinculacionEstudiante = '$baseUrl/vinculacion/estudiante';
  static const String vinculacionTutor = '$baseUrl/vinculacion/tutor';
  static const String vinculacionTutorSolicitudes =
      '$baseUrl/vinculacion/tutor/solicitudes';
  static String vinculacionRespuesta(int id) =>
      '$baseUrl/vinculacion/solicitudes/$id/respuesta';
  static String vinculacionConfirmar(int id) =>
      '$baseUrl/vinculacion/solicitudes/$id/confirmar';
  static const String adminAlertasRiesgo = '$baseUrl/admin/alertas-riesgo';
  static String adminResumenRiesgo(int idUsuario) =>
      '$baseUrl/admin/resumen-riesgo/$idUsuario';

  // Password recovery
  static const String passwordResetRequest =
      '$baseUrl/auth/password-reset-request';
  static const String passwordResetConfirm =
      '$baseUrl/auth/password-reset-confirm';
  static const String changePassword = '$baseUrl/auth/change-password';

  // Alertas para padres
  static const String padresAlertas = '$baseUrl/users/padres/alertas';
  static String padreAlertaVista(int idAlerta) =>
      '$baseUrl/users/padres/alertas/$idAlerta/vista';

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
