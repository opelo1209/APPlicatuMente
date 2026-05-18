import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aptm/text_utils.dart';

import '../principal.dart';
import '../theme_provider.dart';
import 'dart:convert';
import '../servicios/user.dart';

class CuestionarioAutolesion extends StatefulWidget {
  const CuestionarioAutolesion({super.key});

  @override
  State<CuestionarioAutolesion> createState() => _CuestionarioAutolesionState();
}

class _CuestionarioAutolesionState extends State<CuestionarioAutolesion> {
  bool _enviando = false;
  bool _cargandoPreguntas = true;
  final _formKey = GlobalKey<FormState>();
  Map<String, String> _preguntas = const {
    'cortado_piel':
        '¿Alguna vez te has hecho cortadas en la piel, pero sin querer hacerte daño grave ni quitarte la vida?',
    'primera_vez': '¿Cuándo fue la primera vez que lo hiciste?',
    'cuantas_veces': '¿Cuántas veces lo has hecho?',
    'donde_aprendiste': '¿Dónde o cómo te enteraste de hacerlo?',
  };
  Map<String, int> _puntajes = const {
    'cortado_piel': 1,
    'primera_vez': 0,
    'cuantas_veces': 0,
    'donde_aprendiste': 0,
  };

  // Respuestas
  bool? _q1Respuesta; // true = Sí, false = No
  final _primeraVezCtrl = TextEditingController();
  int _cuantasVeces = 1;
  final _dondeCtrl = TextEditingController();

  static const Color _teal = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _loadPreguntas();
  }

  Future<void> _loadPreguntas() async {
    final result = await User().getCuestionarioConfig(modulo: 'autolesion');
    if (!mounted) return;

    final data = result['data'];
    final rawQuestions = data is Map ? data['preguntas'] : null;
    if (result['success'] == true &&
        rawQuestions is List &&
        rawQuestions.isNotEmpty) {
      final preguntas = Map<String, String>.from(_preguntas);
      final puntajes = Map<String, int>.from(_puntajes);
      for (final raw in rawQuestions.whereType<Map>()) {
        final codigo = raw['codigo']?.toString() ?? '';
        if (codigo.isEmpty) continue;
        preguntas[codigo] =
            raw['pregunta']?.toString() ?? preguntas[codigo] ?? '';
        puntajes[codigo] = raw['puntaje'] is int
            ? raw['puntaje'] as int
            : int.tryParse(raw['puntaje']?.toString() ?? '') ??
                  puntajes[codigo] ??
                  0;
      }

      setState(() {
        _preguntas = preguntas;
        _puntajes = puntajes;
        _cargandoPreguntas = false;
      });
      return;
    }

    setState(() => _cargandoPreguntas = false);
  }

  @override
  void dispose() {
    _primeraVezCtrl.dispose();
    _dondeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_q1Respuesta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, responde la primera pregunta.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_q1Respuesta == true && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _enviando = true);

    final reactivos = <Map<String, dynamic>>[
      {
        'numero': 1,
        'id': 'cortado_piel',
        'pregunta': _preguntas['cortado_piel'],
        'tipo_respuesta': 'binario',
        'puntaje_configurado': _puntajes['cortado_piel'] ?? 1,
        'respuesta_valor': _q1Respuesta == true ? 1 : 0,
        'respuesta_etiqueta': _q1Respuesta == true ? 'Sí' : 'No',
      },
    ];

    if (_q1Respuesta == true) {
      reactivos.addAll([
        {
          'numero': 2,
          'id': 'primera_vez',
          'pregunta': _preguntas['primera_vez'],
          'tipo_respuesta': 'texto',
          'puntaje_configurado': _puntajes['primera_vez'] ?? 0,
          'respuesta_valor': null,
          'respuesta_etiqueta': _primeraVezCtrl.text.trim(),
        },
        {
          'numero': 3,
          'id': 'cuantas_veces',
          'pregunta': _preguntas['cuantas_veces'],
          'tipo_respuesta': 'numero',
          'puntaje_configurado': _puntajes['cuantas_veces'] ?? 0,
          'respuesta_valor': _cuantasVeces,
          'respuesta_etiqueta': '$_cuantasVeces',
        },
        {
          'numero': 4,
          'id': 'donde_aprendiste',
          'pregunta': _preguntas['donde_aprendiste'],
          'tipo_respuesta': 'texto',
          'puntaje_configurado': _puntajes['donde_aprendiste'] ?? 0,
          'respuesta_valor': null,
          'respuesta_etiqueta': _dondeCtrl.text.trim(),
        },
      ]);
    }

    final payload = {
      'tipo_cuestionario': 'autolesion',
      'fecha_aplicacion': DateTime.now().toUtc().toIso8601String(),
      'bloques': [
        {
          'bloque': 'NSSI',
          'nombre': 'Autolesión No Suicida (NSSI)',
          'puntuacion_total': _q1Respuesta == true
              ? (_puntajes['cortado_piel'] ?? 1)
              : 0,
          'reactivos': reactivos,
        },
      ],
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cuestionario_autolesion', jsonEncode(payload));
    await prefs.setBool('cuestionario_autolesion_completado', true);
    await prefs.setBool('modulo_autolesion_completado', true);
    final perfilTipo = prefs.getString('perfil_tipo') ?? 'estudiante';
    final idUsuario = prefs.getInt('id_usuario');
    if (idUsuario != null) {
      await prefs.setBool(
        'modulo_autolesion_completado_${perfilTipo}_$idUsuario',
        true,
      );
    }

    // Enviar al backend
    final userService = User();
    final resultado = await userService.updateCuestionario(
      tipoCuestionario: 'autolesion',
      respuestas: payload,
    );
    print('Backend cuestionario autolesion: $resultado');

    if (!mounted) return;
    setState(() => _enviando = false);

    _mostrarResultado();
  }

  void _mostrarResultado() {
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E272E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: _teal, size: 56),
            const SizedBox(height: 12),
            Text(
              'Cuestionario enviado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tus respuestas han sido registradas correctamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const Principal()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
              ),
              child: const Text('Finalizar'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  InputDecoration _inputDec(bool isDark) => InputDecoration(
    filled: true,
    fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: _teal, width: 2),
    ),
  );

  Widget _buildInfo(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: _teal),
              const SizedBox(width: 8),
              Text(
                'Información de la sección',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(
            italicAcronyms(
              'La auto lesión no suicida (NSSI) se refiere a la conducta deliberada de causar daño directo al propio cuerpo sin la intención de morir.\n\nA continuación, responde con honestidad las preguntas relacionadas.',
              TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);

    final labelStyle = TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white54 : Colors.black54,
    );
    final questionStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      height: 1.35,
      color: isDark ? Colors.white : Colors.black87,
    );
    final textStyle = TextStyle(color: isDark ? Colors.white : Colors.black87);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          'Cuestionario de Autolesión',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _cargandoPreguntas
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : _enviando
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfo(isDark),
                  Text('Pregunta 1', style: labelStyle),
                  const SizedBox(height: 6),
                  Text(_preguntas['cortado_piel'] ?? '', style: questionStyle),
                  const SizedBox(height: 16),

                  // Botones Sí / No
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _q1Respuesta = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _q1Respuesta == true
                                  ? _teal
                                  : (isDark
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white),
                              border: Border.all(
                                color: _q1Respuesta == true
                                    ? _teal
                                    : (isDark
                                          ? Colors.white24
                                          : Colors.black26),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Sí',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _q1Respuesta == true
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() {
                            _q1Respuesta = false;
                            // reset
                            _primeraVezCtrl.clear();
                            _cuantasVeces = 1;
                            _dondeCtrl.clear();
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _q1Respuesta == false
                                  ? Colors.redAccent
                                  : (isDark
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white),
                              border: Border.all(
                                color: _q1Respuesta == false
                                    ? Colors.redAccent
                                    : (isDark
                                          ? Colors.white24
                                          : Colors.black26),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'No',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _q1Respuesta == false
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_q1Respuesta == true) ...[
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pregunta 2', style: labelStyle),
                          const SizedBox(height: 6),
                          Text(
                            _preguntas['primera_vez'] ?? '',
                            style: questionStyle,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _primeraVezCtrl,
                            style: textStyle,
                            decoration: _inputDec(isDark).copyWith(
                              hintText: 'Ej: hace 2 años, a los 14...',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Campo requerido'
                                : null,
                          ),
                          const SizedBox(height: 28),

                          Text('Pregunta 3', style: labelStyle),
                          const SizedBox(height: 6),
                          Text(
                            _preguntas['cuantas_veces'] ?? '',
                            style: questionStyle,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: _cuantasVeces > 1
                                      ? () => setState(() => _cuantasVeces--)
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: _teal,
                                  iconSize: 30,
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '$_cuantasVeces',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _cuantasVeces++),
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: _teal,
                                  iconSize: 30,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          Text('Pregunta 4', style: labelStyle),
                          const SizedBox(height: 6),
                          Text(
                            _preguntas['donde_aprendiste'] ?? '',
                            style: questionStyle,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _dondeCtrl,
                            style: textStyle,
                            decoration: _inputDec(
                              isDark,
                            ).copyWith(hintText: 'Ej: amigos, internet...'),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Campo requerido'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _enviar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Enviar cuestionario',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
