import 'package:flutter/material.dart';

class AppPersonalizacion {
  static const Color defaultAccent = Color(0xFF43A047);

  static Color accentFromPreferences(Map<String, dynamic> preferences) {
    final colores = preferences['colores_favoritos'];
    final colorName = colores is List && colores.isNotEmpty
        ? colores.first.toString()
        : preferences['color_favorito']?.toString() ?? '';
    return colorFromName(colorName);
  }

  static Color colorFromName(String value) {
    switch (value.trim().toLowerCase()) {
      case 'rojo':
        return const Color(0xFFE53935);
      case 'rosa':
        return const Color(0xFFEC407A);
      case 'morado':
        return const Color(0xFF9C27B0);
      case 'azul':
        return const Color(0xFF2196F3);
      case 'cyan':
        return const Color(0xFF00BCD4);
      case 'verde':
        return const Color(0xFF4CAF50);
      case 'amarillo':
        return const Color(0xFFF9A825);
      case 'naranja':
        return const Color(0xFFFF9800);
      case 'negro':
        return const Color(0xFF212121);
      case 'blanco':
        return const Color(0xFF78909C);
      default:
        return defaultAccent;
    }
  }

  static Color darken(Color color, [double amount = 0.18]) {
    return Color.lerp(color, Colors.black, amount) ?? color;
  }

  static Color lighten(Color color, [double amount = 0.24]) {
    return Color.lerp(color, Colors.white, amount) ?? color;
  }

  static Color soft(Color color, [double amount = 0.9]) {
    return Color.lerp(color, Colors.white, amount) ?? color;
  }

  static List<Color> gradient(Color accent, {bool dark = false}) {
    if (dark) {
      return [darken(accent, 0.48), darken(accent, 0.28)];
    }
    return [accent, lighten(accent, 0.28)];
  }

  static List<Color> palette(Color accent) {
    return [
      accent,
      lighten(accent, 0.18),
      darken(accent, 0.12),
      lighten(accent, 0.34),
      darken(accent, 0.26),
      lighten(accent, 0.48),
    ];
  }

  static Color readableTextOn(Color color) {
    return color.computeLuminance() > 0.52
        ? const Color(0xFF1F2937)
        : Colors.white;
  }
}
