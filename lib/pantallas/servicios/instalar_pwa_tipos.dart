/// Tipos compartidos entre la implementación web de la instalación PWA y su
/// stub para plataformas nativas. Viven aparte para que ambas variantes hablen
/// exactamente del mismo tipo y el widget no dependa de cuál se compiló.
library;

/// Navegador detectado, usado para dar instrucciones manuales de instalación
/// en los navegadores que no exponen `beforeinstallprompt`.
enum NavegadorPwa { ios, safari, firefox, chrome, edge, opera, samsung, otro }

/// Desenlace del diálogo nativo de instalación.
enum ResultadoInstalacion {
  /// El usuario aceptó instalar la app.
  aceptada,

  /// El usuario cerró o descartó el diálogo.
  rechazada,

  /// El navegador no ofreció el diálogo nativo (hay que instalar a mano).
  noDisponible,
}

NavegadorPwa navegadorDesdeEtiqueta(String etiqueta) {
  switch (etiqueta) {
    case 'ios':
      return NavegadorPwa.ios;
    case 'safari':
      return NavegadorPwa.safari;
    case 'firefox':
      return NavegadorPwa.firefox;
    case 'chrome':
      return NavegadorPwa.chrome;
    case 'edge':
      return NavegadorPwa.edge;
    case 'opera':
      return NavegadorPwa.opera;
    case 'samsung':
      return NavegadorPwa.samsung;
    default:
      return NavegadorPwa.otro;
  }
}
