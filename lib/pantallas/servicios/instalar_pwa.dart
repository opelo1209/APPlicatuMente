/// Punto de entrada del servicio de instalación PWA.
///
/// En web resuelve a la implementación con `dart:js_interop`; en Android, iOS y
/// escritorio resuelve al stub, que siempre reporta "no instalable" para que la
/// interfaz oculte el botón sin necesidad de comprobar `kIsWeb` en cada lugar.
library;

export 'instalar_pwa_stub.dart'
    if (dart.library.js_interop) 'instalar_pwa_web.dart';
