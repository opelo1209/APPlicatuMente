import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../servicios/user.dart';

/// Envío de cuestionarios al servidor, con garantía de que nada se pierda.
///
/// Antes, los tres cuestionarios (suicidio, ansiedad y autolesión) guardaban
/// el módulo como completado ANTES de enviarlo y no revisaban el resultado
/// del envío: si fallaba, la app mostraba "Cuestionario completado", las
/// respuestas no llegaban a ningún lado y la alerta al padre o tutor -que la
/// genera el servidor al recibirlas- nunca se enviaba. El estudiante quedaba
/// convencido de que había pedido ayuda.
///
/// Aquí el orden es el contrario:
///   1. Las respuestas se guardan SIEMPRE en el dispositivo, pase lo que pase.
///   2. Se intenta enviarlas.
///   3. El módulo se marca como completado SOLO si el servidor las recibió.
///   4. Si falla, quedan en una cola que se reintenta sola al abrir la app.
class EnvioCuestionario {
  /// Cola de cuestionarios que no se pudieron enviar todavía.
  static const String _clavePendientes = 'cuestionarios_pendientes';

  /// Guarda la respuesta en el dispositivo y trata de enviarla.
  ///
  /// Devuelve `true` solo si el servidor confirmó que la recibió. Si devuelve
  /// `false`, la respuesta quedó en la cola y NO debe darse por completada.
  static Future<bool> enviar({
    required String tipo,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // Copia local: aunque falle el envío y el estudiante cierre la app, su
    // respuesta sigue aquí.
    await prefs.setString('cuestionario_$tipo', jsonEncode(payload));

    final resultado = await User().updateCuestionario(
      tipoCuestionario: tipo,
      respuestas: payload,
    );

    if (resultado['success'] == true) {
      await _marcarCompletado(prefs, tipo);
      await _quitarDeLaCola(prefs, tipo);
      return true;
    }

    debugPrint(
      'No se pudo enviar el cuestionario $tipo: ${resultado['message']}',
    );
    await _agregarALaCola(prefs, tipo, payload);
    return false;
  }

  /// Reintenta los cuestionarios que quedaron pendientes.
  ///
  /// Se llama al abrir la pantalla principal: si el estudiante contestó sin
  /// conexión, sus respuestas se envían en cuanto vuelva a entrar con datos.
  /// Devuelve cuántos se enviaron en este intento.
  static Future<int> reintentarPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final pendientes = _leerCola(prefs);
    if (pendientes.isEmpty) return 0;

    var enviados = 0;
    for (final pendiente in List<Map<String, dynamic>>.from(pendientes)) {
      final tipo = pendiente['tipo'] as String?;
      final payload = pendiente['payload'];
      if (tipo == null || payload is! Map) continue;

      final resultado = await User().updateCuestionario(
        tipoCuestionario: tipo,
        respuestas: Map<String, dynamic>.from(payload),
      );
      if (resultado['success'] == true) {
        await _marcarCompletado(prefs, tipo);
        await _quitarDeLaCola(prefs, tipo);
        enviados++;
      }
    }
    return enviados;
  }

  /// Cuántas respuestas siguen sin llegar al servidor.
  static Future<int> cuantasPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    return _leerCola(prefs).length;
  }

  // ------------------------------------------------------------------
  // Interno
  // ------------------------------------------------------------------

  /// Marca el módulo como completado. Solo se llama cuando el servidor ya
  /// tiene las respuestas.
  static Future<void> _marcarCompletado(
    SharedPreferences prefs,
    String tipo,
  ) async {
    await prefs.setBool('cuestionario_${tipo}_completado', true);
    await prefs.setBool('modulo_${tipo}_completado', true);

    final perfilTipo = prefs.getString('perfil_tipo') ?? 'estudiante';
    final idUsuario = prefs.getInt('id_usuario');
    if (idUsuario != null) {
      await prefs.setBool(
        'modulo_${tipo}_completado_${perfilTipo}_$idUsuario',
        true,
      );
    }
  }

  static List<Map<String, dynamic>> _leerCola(SharedPreferences prefs) {
    final crudo = prefs.getString(_clavePendientes);
    if (crudo == null || crudo.isEmpty) return const [];
    try {
      final datos = jsonDecode(crudo);
      if (datos is! List) return const [];
      return datos.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (e) {
      // Una cola corrupta no debe impedir que la app funcione.
      debugPrint('Cola de cuestionarios pendientes ilegible: $e');
      return const [];
    }
  }

  static Future<void> _guardarCola(
    SharedPreferences prefs,
    List<Map<String, dynamic>> cola,
  ) async {
    if (cola.isEmpty) {
      await prefs.remove(_clavePendientes);
      return;
    }
    await prefs.setString(_clavePendientes, jsonEncode(cola));
  }

  static Future<void> _agregarALaCola(
    SharedPreferences prefs,
    String tipo,
    Map<String, dynamic> payload,
  ) async {
    // Un solo pendiente por tipo: si contesta otra vez el mismo cuestionario,
    // vale la respuesta más reciente.
    final cola = [
      ..._leerCola(prefs).where((p) => p['tipo'] != tipo),
      {
        'tipo': tipo,
        'payload': payload,
        'fecha': DateTime.now().toUtc().toIso8601String(),
      },
    ];
    await _guardarCola(prefs, cola);
  }

  static Future<void> _quitarDeLaCola(
    SharedPreferences prefs,
    String tipo,
  ) async {
    await _guardarCola(
      prefs,
      _leerCola(prefs).where((p) => p['tipo'] != tipo).toList(),
    );
  }
}
