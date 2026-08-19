import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'instalar_pwa_tipos.dart';

export 'instalar_pwa_tipos.dart';

/// Puente `window.aptmPwa`, definido en `web/index.html`.
///
/// La captura del evento `beforeinstallprompt` ocurre en JavaScript y no aquí
/// a propósito: el navegador lo emite mucho antes de que `main.dart.js`
/// termine de cargar, así que si Dart fuera el que escucha, el evento se
/// perdería y el botón jamás se habilitaría.
@JS('aptmPwa')
external JSObject? get _puenteJs;

extension type _PuentePwa._(JSObject _) implements JSObject {
  external bool sePuedeInstalar();
  external bool yaInstalada();
  external String navegador();
  external JSPromise<JSString> instalar();
  external void alCambiar(JSFunction callback);
}

_PuentePwa? get _puente {
  final crudo = _puenteJs;
  return crudo == null ? null : _PuentePwa._(crudo);
}

/// Estado de instalación de la app como PWA en el navegador actual.
class InstalarPwa {
  const InstalarPwa._();

  /// `true` cuando el navegador ya ofreció un prompt nativo de instalación.
  ///
  /// La interfaz escucha este notificador porque `beforeinstallprompt` puede
  /// llegar segundos después del arranque, cuando el botón ya está pintado.
  static final ValueNotifier<bool> promptDisponible = ValueNotifier<bool>(
    false,
  );

  static bool _inicializado = false;

  static bool get esWeb => true;

  /// `true` si la app se está ejecutando ya instalada (ventana propia).
  static bool get yaInstalada => _puente?.yaInstalada() ?? false;

  static NavegadorPwa get navegador =>
      navegadorDesdeEtiqueta(_puente?.navegador() ?? 'otro');

  /// Sincroniza el estado inicial y se suscribe a los cambios del puente.
  /// Es idempotente: puede llamarse desde varias pantallas sin duplicar nada.
  static void inicializar() {
    if (_inicializado) return;
    final puente = _puente;
    if (puente == null) {
      // index.html no cargó el puente (build web antiguo cacheado, por
      // ejemplo). La app funciona igual, sólo sin botón de instalación.
      return;
    }
    _inicializado = true;
    _sincronizar();
    puente.alCambiar(_sincronizar.toJS);
  }

  static void _sincronizar() {
    promptDisponible.value = _puente?.sePuedeInstalar() ?? false;
  }

  /// Dispara el diálogo nativo de instalación del navegador.
  static Future<ResultadoInstalacion> instalar() async {
    final puente = _puente;
    if (puente == null) return ResultadoInstalacion.noDisponible;

    final String desenlace;
    try {
      desenlace = (await puente.instalar().toDart).toDart;
    } catch (e) {
      debugPrint('[APTM PWA] fallo al invocar la instalación: $e');
      return ResultadoInstalacion.noDisponible;
    } finally {
      _sincronizar();
    }

    switch (desenlace) {
      case 'accepted':
        return ResultadoInstalacion.aceptada;
      case 'dismissed':
        return ResultadoInstalacion.rechazada;
      default:
        return ResultadoInstalacion.noDisponible;
    }
  }
}
