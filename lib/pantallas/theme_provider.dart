import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  /// Semana 5 (H8): antes main.dart leía la clave 'darkMode' (que nunca se
  /// guardaba), llamaba a toogleTheme(false) al arrancar y eso sobrescribía
  /// la preferencia mientras el constructor la intentaba leer. Ahora hay una
  /// sola clave, se lee una vez antes de crear el proveedor y arrancar no
  /// escribe nada.
  static const claveModoOscuro = 'isDarkMode';

  ThemeProvider({bool modoOscuro = false}) : _isDarkMode = modoOscuro;

  bool _isDarkMode;
  bool get isDarkMode => _isDarkMode;

  static bool preferenciaGuardada(SharedPreferences prefs) =>
      prefs.getBool(claveModoOscuro) ?? false;

  Future<void> toogleTheme(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(claveModoOscuro, value);
  }
}
