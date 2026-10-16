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
///
/// Semana 4 (H1): la cola es de cada usuario. Antes era una sola clave para
/// todo el dispositivo y no se borraba al cerrar sesión: en un equipo
/// compartido, las respuestas de suicidio del estudiante A se enviaban con la
/// cuenta de B y la alerta le llegaba al tutor de B. Ahora cada usuario tiene
/// su propia cola, cada pendiente lleva a su dueño y al cerrar sesión se
/// borra lo del usuario que sale.
class EnvioCuestionario {
  /// Prefijo de la cola de cada usuario: `cuestionarios_pendientes_<dueño>`.
  static const String _prefijoCola = 'cuestionarios_pendientes_';

  /// Cola global de versiones anteriores: no tiene dueño, nunca se envía.
  static const String _colaGlobalAntigua = 'cuestionarios_pendientes';

  /// Copias en texto plano que guardaban las versiones anteriores.
  static const List<String> _copiasAntiguas = [
    'cuestionario_suicidio',
    'cuestionario_ansiedad',
    'cuestionario_autolesion',
    'cuestionario_sustancias',
    'cuestionario_relaciones',
  ];

  /// Guarda la respuesta en el dispositivo y trata de enviarla.
  ///
  /// Devuelve `true` solo si el servidor confirmó que la recibió. Si devuelve
  /// `false`, la respuesta quedó en la cola y NO debe darse por completada.
  static Future<bool> enviar({
    required String tipo,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();

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
    // Sin sesión no hay a quién atribuir la respuesta: no se guarda.
    if (_dueno(prefs) != null) await _agregarALaCola(prefs, tipo, payload);
    return false;
  }

  /// Reintenta los cuestionarios que quedaron pendientes.
  ///
  /// Se llama al abrir la pantalla principal: si el estudiante contestó sin
  /// conexión, sus respuestas se envían en cuanto vuelva a entrar con datos.
  /// Devuelve cuántos se enviaron en este intento.
  static Future<int> reintentarPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    await _borrarAntiguos(prefs);
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

  /// Cuántas respuestas del usuario actual siguen sin llegar al servidor.
  static Future<int> cuantasPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    return _leerCola(prefs).length;
  }

  /// Al cerrar sesión (antes de borrar el token y `id_usuario`): último
  /// intento de envío, con tiempo máximo para no trabar la salida.
  ///
  /// Lo que no se pudo enviar NO se borra: queda en la cola de quien sale,
  /// que ningún otro usuario lee, y se envía cuando vuelva a entrar. Borrarlo
  /// perdería en silencio, por ejemplo, la alerta de un cuestionario de
  /// suicidio contestado sin red.
  static Future<void> alCerrarSesion() async {
    try {
      await reintentarPendientes().timeout(_tiempoMaximoAlSalir);
    } catch (e) {
      debugPrint('No se pudieron enviar los pendientes al salir: $e');
    }
    await _borrarAntiguos(await SharedPreferences.getInstance());
  }

  static const Duration _tiempoMaximoAlSalir = Duration(seconds: 8);

  /// Borra todo lo pendiente del usuario actual (y lo antiguo sin dueño).
  /// No toca las colas de otros usuarios.
  static Future<void> borrarDelUsuarioActual() async {
    final prefs = await SharedPreferences.getInstance();
    final dueno = _dueno(prefs);
    if (dueno != null) await prefs.remove('$_prefijoCola$dueno');
    await _borrarAntiguos(prefs);
  }

  /// La cola global y las copias en texto plano de versiones anteriores no
  /// tienen dueño: no se pueden enviar sin arriesgar la cuenta equivocada.
  static Future<void> _borrarAntiguos(SharedPreferences prefs) async {
    await prefs.remove(_colaGlobalAntigua);
    for (final clave in _copiasAntiguas) {
      await prefs.remove(clave);
    }
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

  /// Dueño de la sesión actual (`perfil_id`), o null si no hay sesión.
  static String? _dueno(SharedPreferences prefs) {
    final idUsuario = prefs.getInt('id_usuario');
    if (idUsuario == null) return null;
    final perfilTipo = prefs.getString('perfil_tipo') ?? 'estudiante';
    return '${perfilTipo}_$idUsuario';
  }

  /// Pendientes del usuario actual. Un pendiente con otro dueño se descarta:
  /// nunca se envía una respuesta con la cuenta de otra persona.
  static List<Map<String, dynamic>> _leerCola(SharedPreferences prefs) {
    final dueno = _dueno(prefs);
    if (dueno == null) return const [];
    final crudo = prefs.getString('$_prefijoCola$dueno');
    if (crudo == null || crudo.isEmpty) return const [];
    try {
      final datos = jsonDecode(crudo);
      if (datos is! List) return const [];
      return datos
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .where((p) => p['dueno'] == dueno)
          .toList();
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
    final dueno = _dueno(prefs);
    if (dueno == null) return;
    final clave = '$_prefijoCola$dueno';
    if (cola.isEmpty) {
      await prefs.remove(clave);
      return;
    }
    await prefs.setString(clave, jsonEncode(cola));
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
        'dueno': _dueno(prefs),
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
