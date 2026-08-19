import 'package:flutter/foundation.dart';

import 'instalar_pwa_tipos.dart';

export 'instalar_pwa_tipos.dart';

/// Implementación vacía para las compilaciones nativas (Android, iOS,
/// escritorio), donde la app ya está instalada por definición.
class InstalarPwa {
  const InstalarPwa._();

  /// Siempre `false`: nunca hay un prompt de instalación nativo que ofrecer.
  static final ValueNotifier<bool> promptDisponible = ValueNotifier<bool>(
    false,
  );

  static bool get esWeb => false;

  static bool get yaInstalada => true;

  static NavegadorPwa get navegador => NavegadorPwa.otro;

  static void inicializar() {}

  static Future<ResultadoInstalacion> instalar() async =>
      ResultadoInstalacion.noDisponible;
}
