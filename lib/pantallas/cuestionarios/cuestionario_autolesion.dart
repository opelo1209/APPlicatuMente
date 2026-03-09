import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../principal.dart';
import '../theme_provider.dart';
import '../servicios/cuestionario_service.dart';
import 'paso_identificacion.dart'; // IMPORT PASO IDENTIFICACION

// ─────────────────────────────────────────────────────────────────────────────
// Cuestionario NSSI — Autolesión No Suicida
//   Pregunta 1 : ¿Te has cortado sin intención suicida? (binario, SWIPE)
//   Si Sí → Preguntas 2-4 (cuándo, cuántas veces, dónde aprendiste) (FORM)
//   Si No → Envío directo
// ─────────────────────────────────────────────────────────────────────────────

class CuestionarioAutolesion extends StatefulWidget {
  const CuestionarioAutolesion({super.key});

  @override
  State<CuestionarioAutolesion> createState() =>
      _CuestionarioAutolesionState();
}

class _CuestionarioAutolesionState extends State<CuestionarioAutolesion> {
  int _phase = 0; // 0 = Q1,  1 = formulario follow-up
  bool? _q1Respuesta; // null → sin responder, true → Sí, false → No
  bool _enviando = false;

  // Controladores para Q2-Q4
  final _primeraVezCtrl = TextEditingController();
  int _cuantasVeces = 1;
  final _dondeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const Color _teal = Color(0xFF00897B);

  @override
  void dispose() {
    _primeraVezCtrl.dispose();
    _dondeCtrl.dispose();
    super.dispose();
  }

  // ── Envío al servidor ────────────────────────────────────────────────────
  Future<void> _enviar() async {
    setState(() => _enviando = true);

    final reactivos = <Map<String, dynamic>>[
      {
        'numero': 1,
        'id': 'cortado_piel',
        'pregunta':
            '¿Alguna vez te has cortado la piel sin la intención de terminar con tu vida?',
        'tipo_respuesta': 'binario',
        'respuesta_valor': _q1Respuesta == true ? 1 : 0,
        'respuesta_etiqueta': _q1Respuesta == true ? 'Sí' : 'No',
      },
    ];

    if (_q1Respuesta == true) {
      reactivos.addAll([
        {
          'numero': 2,
          'id': 'primera_vez',
          'pregunta': '¿Cuándo fue la primera vez que lo hiciste?',
          'tipo_respuesta': 'texto',
          'respuesta_valor': null,
          'respuesta_etiqueta': _primeraVezCtrl.text.trim(),
        },
        {
          'numero': 3,
          'id': 'cuantas_veces',
          'pregunta': '¿Cuántas veces lo has hecho?',
          'tipo_respuesta': 'numero',
          'respuesta_valor': _cuantasVeces,
          'respuesta_etiqueta': '$_cuantasVeces',
        },
        {
          'numero': 4,
          'id': 'donde_aprendiste',
          'pregunta': '¿Dónde aprendiste?',
          'tipo_respuesta': 'texto',
          'respuesta_valor': null,
          'respuesta_etiqueta': _dondeCtrl.text.trim(),
        },
      ]);
    }

    final result = await CuestionarioService().enviarCuestionario(
      tipoCuestionario: 'autolesion',
      bloques: [
        {
          'bloque': 'NSSI',
          'nombre': 'Autolesión No Suicida (NSSI)',
          'puntuacion_total': _q1Respuesta == true ? 1 : 0,
          'reactivos': reactivos,
        },
      ],
    );

    if (!mounted) return;
    setState(() => _enviando = false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cuestionario_autolesion_completado', true);

    _mostrarResultado(result);
  }

  void _mostrarResultado(Map<String, dynamic> result) {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E272E) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: _teal,
              size: 56,
            ),
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
            if (!result['success']) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin conexión al servidor. Se guardaron localmente.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                    borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 12),
              ),
              child: const Text('Finalizar'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _phase > 0
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () => setState(() => _phase = 0),
              )
            : null,
        title: Text(
          'Autolesión (NSSI)',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: _enviando
          ? const Center(
              child: CircularProgressIndicator(color: _teal),
            )
          : _phase == 0
              ? PasoIdentificacion(
                  questions: const [
                    {
                      'id': 'cortado_piel',
                      'text': '¿Alguna vez te has cortado la piel sin la intención de terminar con tu vida?',
                      'image': 'assets/imagenes/quetzal_7.png',
                      'gradient': [Color(0xFF84FAB0), Color(0xFF8FD3F4)],
                    }
                  ],
                  headerTitle: 'Autolesión No Suicida',
                  instructionTitle: 'Pregunta Inicial',
                  instructionDescription: 'Desliza hacia la derecha si es un Sí, y a la izquierda si es un No.',
                  readyButtonText: 'Comenzar',
                  rightSwipeLabel: 'SÍ',
                  leftSwipeLabel: 'NO',
                  rightMeaning: 'Sí, me ha pasado',
                  leftMeaning: 'No, nunca',
                  accentColor: _teal,
                  completionMessage: 'Procesando...',
                  onCompleted: (resultados) {
                    final res = resultados['cortado_piel'];
                    if (res == true) {
                      setState(() {
                        _q1Respuesta = true;
                        _phase = 1;
                      });
                    } else {
                      setState(() => _q1Respuesta = false);
                      _enviar();
                    }
                  },
                )
              : _FollowUpForm(
                  isDark: isDark,
                  primeraVezCtrl: _primeraVezCtrl,
                  cuantasVeces: _cuantasVeces,
                  dondeCtrl: _dondeCtrl,
                  formKey: _formKey,
                  onCuantasChanged: (v) =>
                      setState(() => _cuantasVeces = v),
                  onSubmit: () {
                    if (_formKey.currentState!.validate()) _enviar();
                  },
                ),
    );
  }
}

// ── Formulario follow-up (Q2, Q3, Q4) ───────────────────────────────────────

class _FollowUpForm extends StatelessWidget {
  const _FollowUpForm({
    required this.isDark,
    required this.primeraVezCtrl,
    required this.cuantasVeces,
    required this.dondeCtrl,
    required this.formKey,
    required this.onCuantasChanged,
    required this.onSubmit,
  });

  final bool isDark;
  final TextEditingController primeraVezCtrl;
  final int cuantasVeces;
  final TextEditingController dondeCtrl;
  final GlobalKey<FormState> formKey;
  final ValueChanged<int> onCuantasChanged;
  final VoidCallback onSubmit;

  static const Color _teal = Color(0xFF00897B);

  InputDecoration get _inputDec => InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark ? Colors.white12 : Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark ? Colors.white12 : Colors.black12),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: _teal, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white38 : Colors.black38,
    );
    final questionStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      height: 1.35,
      color: isDark ? Colors.white : Colors.black87,
    );
    final textStyle =
        TextStyle(color: isDark ? Colors.white : Colors.black87);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LinearProgressIndicator(
              value: 1.0,
              backgroundColor: Color(0x1F000000),
              valueColor: AlwaysStoppedAnimation<Color>(_teal),
              minHeight: 4,
            ),
            const SizedBox(height: 24),
            // Chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Preguntas de seguimiento',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _teal,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Q2 ─────────────────────────────────────────────────────
            Text('Pregunta 2', style: labelStyle),
            const SizedBox(height: 6),
            Text('¿Cuándo fue la primera vez que lo hiciste?',
                style: questionStyle),
            const SizedBox(height: 12),
            TextFormField(
              controller: primeraVezCtrl,
              style: textStyle,
              decoration: _inputDec.copyWith(
                  hintText: 'Ej: hace 2 años, cuando tenía 14…'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 28),

            // ── Q3 ─────────────────────────────────────────────────────
            Text('Pregunta 3', style: labelStyle),
            const SizedBox(height: 6),
            Text('¿Cuántas veces lo has hecho?', style: questionStyle),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: cuantasVeces > 1
                        ? () => onCuantasChanged(cuantasVeces - 1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: _teal,
                    iconSize: 30,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '$cuantasVeces',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => onCuantasChanged(cuantasVeces + 1),
                    icon: const Icon(Icons.add_circle_outline),
                    color: _teal,
                    iconSize: 30,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Q4 ─────────────────────────────────────────────────────
            Text('Pregunta 4', style: labelStyle),
            const SizedBox(height: 6),
            Text('¿Dónde aprendiste?', style: questionStyle),
            const SizedBox(height: 12),
            TextFormField(
              controller: dondeCtrl,
              style: textStyle,
              decoration: _inputDec.copyWith(
                  hintText: 'Ej: amigos, redes sociales, internet…'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 36),

            // ── Botón enviar ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Enviar respuestas',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


