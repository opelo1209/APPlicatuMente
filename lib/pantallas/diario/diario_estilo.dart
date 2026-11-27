// Paleta y tipografía del diario, en modo claro y oscuro.
//
// Antes cada pantalla fijaba colores claros (fondos blancos, texto gris) y en
// modo oscuro el texto de la app quedaba claro sobre fondo claro. Aquí se
// resuelven una sola vez según el tema. Los pares texto/fondo cumplen al
// menos 4.5:1 (WCAG AA); el texto de apoyo nunca baja de 13 px.
import 'package:flutter/material.dart';

import 'diario_catalogo.dart';

@immutable
class DiarioColores {
  const DiarioColores({
    required this.oscuro,
    required this.fondo,
    required this.superficie,
    required this.texto,
    required this.textoSuave,
    required this.borde,
    required this.ayudaFondo,
    required this.ayudaBorde,
    required this.ayudaTitulo,
    required this.serenaFondo,
    required this.avisoFondo,
    required this.crisisFondo,
    required this.crisisCirculo,
    required this.crisisTitulo,
  });

  final bool oscuro;
  final Color fondo;
  final Color superficie;
  final Color texto;
  final Color textoSuave;
  final Color borde;
  final Color ayudaFondo;
  final Color ayudaBorde;
  final Color ayudaTitulo;
  final List<Color> serenaFondo;
  final Color avisoFondo;
  final Color crisisFondo;
  final Color crisisCirculo;
  final Color crisisTitulo;

  /// Carcasa del semáforo y de la tira semanal: oscura en ambos temas.
  static const Color carcasa = Color(0xFF22303A);
  static const Color azulAyuda = Color(0xFF1565C0);
  static const Color moradoSerena = Color(0xFF6A4FB3);

  static const claro = DiarioColores(
    oscuro: false,
    fondo: Color(0xFFF6F8F5),
    superficie: Color(0xFFFFFFFF),
    texto: Color(0xFF1F2A24),
    textoSuave: Color(0xFF4E5B54),
    borde: Color(0xFFDCE3DE),
    ayudaFondo: Color(0xFFE8F1FB),
    ayudaBorde: Color(0x401565C0),
    ayudaTitulo: Color(0xFF0D3C78),
    serenaFondo: [Color(0xFFF1ECFB), Color(0xFFE7F4EE)],
    avisoFondo: Color(0xFFFFF1EC),
    crisisFondo: Color(0xFFF3F7FC),
    crisisCirculo: Color(0xFFDCE9F8),
    crisisTitulo: Color(0xFF0D3C78),
  );

  static const oscuroTema = DiarioColores(
    oscuro: true,
    fondo: Color(0xFF121614),
    superficie: Color(0xFF1C2420),
    texto: Color(0xFFE8EEEA),
    textoSuave: Color(0xFFAEBCB4),
    borde: Color(0xFF34423B),
    ayudaFondo: Color(0xFF14243A),
    ayudaBorde: Color(0xFF2B4A70),
    ayudaTitulo: Color(0xFF9CC3F5),
    serenaFondo: [Color(0xFF261F38), Color(0xFF1A2A23)],
    avisoFondo: Color(0xFF3A221C),
    crisisFondo: Color(0xFF0F1722),
    crisisCirculo: Color(0xFF1E3350),
    crisisTitulo: Color(0xFF9CC3F5),
  );

  static DiarioColores de(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? oscuroTema : claro;

  /// Color de texto de una polaridad sobre la superficie del tema. El color
  /// de la luz (verde, ámbar, coral) es demasiado claro para texto.
  Color tinta(Polaridad p) => (oscuro ? _tintaOscuro : _tintaClaro)[p]!;

  /// Relleno de una emoción elegida y el color de su texto.
  Color rellenoElegido(Polaridad p) => tinta(p);
  Color textoSobreElegido(Polaridad p) =>
      oscuro ? const Color(0xFF10241A) : Colors.white;

  /// Color del ícono sobre la luz encendida del semáforo.
  static Color sobreLuz(Polaridad p) =>
      p == Polaridad.neutro ? const Color(0xFF3D2C00) : Colors.white;

  static const Map<Polaridad, Color> _tintaClaro = {
    Polaridad.positivo: Color(0xFF2E7D32),
    Polaridad.neutro: Color(0xFF8A5A00),
    Polaridad.negativo: Color(0xFFB5402B),
  };
  static const Map<Polaridad, Color> _tintaOscuro = {
    Polaridad.positivo: Color(0xFF81C784),
    Polaridad.neutro: Color(0xFFFFD54F),
    Polaridad.negativo: Color(0xFFFF9E86),
  };
}

/// Escala tipográfica del diario (cuatro tamaños de lectura).
abstract final class DiarioTexto {
  static const double titulo = 18;
  static const double cuerpo = 15;
  static const double apoyo = 13.5;
  static const double etiqueta = 13;
}
