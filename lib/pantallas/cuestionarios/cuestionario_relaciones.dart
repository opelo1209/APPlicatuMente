import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import 'aviso_envio_fallido.dart';
import 'envio_cuestionario.dart';
import '../principal.dart';

import '../servicios/user.dart';

class CuestionarioRelaciones extends StatefulWidget {
  const CuestionarioRelaciones({super.key});

  @override
  State<CuestionarioRelaciones> createState() => _CuestionarioRelacionesState();
}

class _CuestionarioRelacionesState extends State<CuestionarioRelaciones> {
  int _currentIndex = 0;
  final Map<String, Map<String, dynamic>> _respuestas = {};
  bool _enviando = false;
  bool _cargandoPreguntas = true;
  late List<Map<String, dynamic>> _preguntas = List<Map<String, dynamic>>.from(
    _defaultPreguntas,
  );

  // ── Definición de todas las preguntas ─────────────────────────────────────
  static const List<Map<String, dynamic>> _defaultPreguntas = [
    {
      'bloque': 'relaciones_sanas',
      'bloque_nombre': 'Abuso económico',
      'numero': 1,
      'id': 'economico',
      'tipo': 'likert3',
      'pregunta':
          '• Solo te visitan cuando te corresponde recibir el pago de tu salario o beneficios.\n'
          '• Afectan regularmente tu capacidad para trabajar, por ejemplo, impidiendo que llegues a tu lugar de trabajo a tiempo o causando problemas entre tú y tus compañeros.\n'
          '• Han provocado directamente que recibas una acción disciplinaria o que seas despedido de tu trabajo.\n'
          '• Te dan dinero de bolsillo ("mesada") o te exigen recibos o el cambio de las compras.\n'
          '• Gastan la mayor parte de los ingresos del hogar, dejando poco para que te cuides a ti mismo y/o a tus hijos.\n'
          '• No te permiten tener acceso a un teléfono o a una cuenta bancaria.\n'
          '• Han roto tus pertenencias, por ejemplo, tu teléfono, computadora portátil, o han dañado cosas dentro de tu casa que tendrás que pagar para reemplazar.\n'
          '• Han acumulado deudas intencionalmente a tu nombre, por ejemplo, atrasos en el alquiler o facturas del hogar no pagadas.\n'
          '• Te obligan a trabajar en uno o múltiples empleos.\n'
          '• Controlan tu acceso al dinero, tarjetas bancarias u otros recursos como alimentos y vivienda.\n'
          '• Deciden cuánto puedes o no puedes gastar porque ganan todo el dinero del hogar.\n'
          '• Alternativamente, toman tu salario y deciden cuánto puedes o no puedes gastar.\n'
          '• Han solicitado préstamos o tarjetas de crédito a tu nombre sin tu consentimiento.\n'
          '• Se enojan contigo por la forma en que gastas el dinero.\n',
    },{
      'bloque': 'relaciones_sanas',
      'bloque_nombre': 'Abuso psicológico emocional',
      'numero': 2,
      'id': 'psicologico_emocional',
      'tipo': 'likert3',
      'pregunta':
          '• Te hacen sentir que las cosas que haces no son lo suficientemente buenas. Critican tus acciones, a solas con ellos o frente a otras personas.\n'
          '• Te menosprecian y/o te insultan o te llaman por nombres ofensivos.\n'
          '• Te hacen sentir inseguro(a) sobre si puedes cuidar de ti mismo(a), de tus hijos o de otras personas a tu cargo.\n'
          '• Cuestionan tu juicio y tu capacidad para tomar decisiones.\n'
          '• Te dicen que eres "demasiado sensible" o que "no aguantas un chiste".\n'
          '• Te dicen qué puedes y qué no puedes usar de ropa.\n'
          '• Te avergüenzan o te humillan frente a otras personas.\n'
          '• Sacan a relucir cosas que quieres mantener en privado.\n'
          '• Te amenazan o te manipulan.\n'
          '• Te culpan por las acciones de ellos.\n'
          '• A menudo comentan, critican o te piden que cambies tu aspecto físico.\n',
    },{
      'bloque': 'relaciones_sanas',
      'bloque_nombre': 'Abuso físico',
      'numero': 3,
      'id': 'fisico',
      'tipo': 'likert3',
      'pregunta':
          '• Te han golpeado.\n'
          '• Te han retenido físicamente (por ejemplo, sujetándote contra el suelo o amarrándote) sin tu consentimiento.\n'
          '• Te han lanzado objetos.\n'
          '• Te han pellizcado o empujado.\n'
          '• Han dañado físicamente a un niño o a una mascota.\n'
          '• Han manipulado tu medicación de alguna manera, por ejemplo, al no dártela o darte los medicamentos incorrectos.\n'
          '• Han mostrado regularmente cualquiera de los comportamientos mencionados anteriormente y te han dicho que era un "chiste" o un "accidente".\n'
          '• Te han quemado o escaldado.\n'
          '• Han usado la fuerza física para castigarte.\n',
    },{
      'bloque': 'relaciones_sanas',
      'bloque_nombre': 'Abuso sexual',
      'numero': 4,
      'id': 'sexual',
      'tipo': 'likert3',
      'pregunta':
          '• Te obligan a tener relaciones sexuales o a realizar cualquier acto sexual cuando no quieres (incluyendo con otras personas).\n'
          '• Utilizan un lenguaje sexualmente degradante (como llamarte "zorra" o "prostituta").\n'
          '• Te graban en cualquier situación sexual sin tu consentimiento.\n'
          '• Mienten sobre los métodos anticonceptivos que están usando o los manipulan (como decir que usarán un condón y luego no usarlo, o perforar condones que tú usarás más adelante).\n'
          '• No te sientes capaz de decir no a los actos sexuales.\n'
          '• Te muestran sus genitales sin tu consentimiento.\n'
          '• Te obligan a ver pornografía.\n'
          '• Te obligan a realizar trabajo sexual.\n',
    },{
      'bloque': 'relaciones_sanas',
      'bloque_nombre': 'Control coercitivo',
      'numero': 5,
      'id': 'coercitivo',
      'tipo': 'likert3',
      'pregunta': 
          'Ponen reglas que debes seguir; de lo contrario, habrá un castigo u otra consecuencia negativa.\n'
          '• Toman el control de partes de tu vida, como a quién puedes ver, a dónde puedes ir, etc.\n'
          '• Te hacen "gaslighting" (manipulación que te hace dudar de tus propios recuerdos y de la realidad, o te hace sentir que no experimentaste las cosas que hiciste).\n'
          '• Sientes que tienes que cambiar la forma en que vives tu vida para intentar evitar que tu pareja o familiar se enoje contigo.\n'
          '• Te han amenazado con lastimarte a ti, a sí mismos o a otros (incluyendo mascotas).\n'
          '• Te privan de necesidades básicas como alimentos o medicamentos.\n'
          '• Te aíslan de amigos y familiares.\n'
          '• Amenazan con irse.\n'
          '• Te dicen que no eres bueno(a) cuidando a los niños, o amenazan con reportarte a los servicios infantiles.\n'
          '• Te impiden acceder a servicios básicos como la atención médica.\n'
          '• Te humillan o te degradan.\n'
          '• Actúan de una manera que hace que otras personas piensen mal de ti.\n'
          '• Actúan de manera diferente a tu alrededor en comparación con la familia, amigos, profesionales, colegas, etc. \n',
    },{
      'bloque': 'relaciones_sanas',
      'bloque_nombre': 'Abuso digital',
      'numero': 6,
      'id': 'digital',
      'tipo': 'likert3',
      'pregunta':
          '• Te envían mensajes o te llaman constantemente.\n'
          '• Publican "pornovenganza" (contenido sexual) de ti en internet sin tu consentimiento.\n'
          '• Controlan tus dispositivos digitales, por ejemplo, revisando tu teléfono inteligente o tu computadora todo el tiempo.\n'
          '• Instalan software espía (spyware) en tus dispositivos para obtener información sobre ti en secreto.\n'
          '• Utilizan la tecnología para rastrear dónde estás.\n'
          '• Controlan tus cuentas bancarias a través de la banca en línea.\n'
          '• Crean cuentas falsas haciéndose pasar por ti en las redes sociales.\n'
          '• Te "trolean" a través de las redes sociales publicando comentarios insultantes o degradantes sobre ti.\n'
          '• Utilizan dispositivos domésticos inteligentes (como cámaras de videoportero, altavoces inteligentes o termostatos inteligentes) para controlarte o hacerte daño.\n',
    },{
      'bloque': 'relaciones_sanas',
      'bloque_nombre': 'Abuso',
      'numero': 7,
      'id': 'Acoso',
      'tipo': 'likert3',
      'pregunta':
          '• Te siguen regularmente.\n'
          '• Intentan interactuar contigo repetidamente cuando no quieres que lo hagan.\n'
          '• Utilizan métodos digitales para rastrearte (como usar los servicios de ubicación de tu teléfono inteligente) cuando no quieres que lo hagan.\n'
          '• Te envían comunicaciones no deseadas (como a través de mensajes de texto, correo electrónico, llamadas telefónicas, correo postal, mensajes instantáneos, etc.).\n'
          '• Suelen merodear por lugares donde saben que vas a estar (como tu lugar de trabajo).\n',
    },
  ];

  // Opciones Likert estándar PHQ-9
  static const List<Map<String, dynamic>> _likert3 = [
    {
      'valor': 0,
      'etiqueta': 'No',
      'color': Color(0xFF43A047)
      },
    {
      'valor': 1,
      'etiqueta': 'No estoy seguro',
      'color': Color(0xFFFDD835)
    },{
      'valor': 3,
      'etiqueta': 'Sí',
      'color': Color(0xFFE53935),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPreguntas();
  }

  Future<void> _loadPreguntas() async {
    final result = await User().getCuestionarioConfig(modulo: 'relaciones');
    if (!mounted) return;

    final data = result['data'];
    final rawQuestions = data is Map ? data['preguntas'] : null;
    if (result['success'] == true &&
        rawQuestions is List &&
        rawQuestions.isNotEmpty) {
      final defaultsById = {
        for (final question in _defaultPreguntas)
          question['id'] as String: Map<String, dynamic>.from(question),
      };
      final loaded = rawQuestions
          .whereType<Map>()
          .map((raw) {
            final codigo = raw['codigo']?.toString() ?? '';
            final base = defaultsById[codigo] ?? <String, dynamic>{};
            return {
              ...base,
              'bloque': raw['bloque']?.toString() ?? base['bloque'],
              'bloque_nombre': raw['bloque_nombre']?.toString() ?? base['bloque_nombre'],
              'id': codigo,
                'numero': raw['numero'] is int
                  ? raw['numero']
                  : int.tryParse(raw['numero']?.toString() ?? '') ??
                base['numero'] ??
                  0,
              'tipo':
                  raw['tipo_respuesta']?.toString() ??
                  base['tipo'] ??
                  'binario',
              'puntaje': raw['puntaje'] is int
                  ? raw['puntaje']
                  : int.tryParse(raw['puntaje']?.toString() ?? '') ?? 0,
            };
          })
          .where((question) => (question['id'] as String).isNotEmpty)
          .toList();

      loaded.sort((a, b) => (a['numero'] as int).compareTo(b['numero'] as int));
      setState(() {
        _preguntas = loaded;
        _cargandoPreguntas = false;
      });
      return;
    }

    setState(() => _cargandoPreguntas = false);
  }

  // ── Lógica de respuesta ───────────────────────────────────────────────────
  void _responder(int valor, String etiqueta) {
    final p = _preguntas[_currentIndex];

    _respuestas[p['id'] as String] = {
      'numero': p['numero'],
      'bloque': p['bloque'],
      'bloque_nombre': p['bloque_nombre'],
      'id': p['id'],
      'pregunta': p['pregunta'],
      'tipo_respuesta': p['tipo'],
      'puntaje_configurado': p['puntaje'] ?? 0,
      'respuesta_valor': valor,
      'respuesta_etiqueta': etiqueta,
    };

    if (_currentIndex < _preguntas.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _finalizarYEnviar();
    }
  }

  //Conteo de puntaje 
  Future<void> _finalizarYEnviar() async {
    setState(() => _enviando = true);

    final relaciones_sanasReactivos =
        _respuestas.values.where((r) => r['bloque'] == 'relaciones_sanas').toList()
          ..sort((a, b) => (a['numero'] as int).compareTo(b['numero'] as int));

    // Puntuación relaciones_sanas: suma de preguntas (likert3)
    final relaciones_sanasScore = relaciones_sanasReactivos
        .where((r) => r['tipo_respuesta'] == 'likert3')
        .fold<int>(0, (sum, r) => sum + (r['respuesta_valor'] as int));


    final payload = {
      'tipo_cuestionario': 'relaciones',
      'fecha_aplicacion': DateTime.now().toUtc().toIso8601String(),
      'relaciones_sanas_score': relaciones_sanasScore,
      'bloques': [
        {
          'bloque': 'relaciones_sanas',
          'nombre': 'Relaciones',
          'puntuacion_total': relaciones_sanasScore,
          'reactivos': relaciones_sanasReactivos,
        },
      ],
    };
    // El envío guarda la respuesta en el dispositivo, la manda al servidor y
    // solo marca el módulo como completado si el servidor la recibió. Antes
    // se daba por completado antes de enviar y sin revisar el resultado: si
    // fallaba, la respuesta no llegaba a ningún lado y nadie se enteraba.
    var enviado = await EnvioCuestionario.enviar(
      tipo: 'relaciones',
      payload: payload,
    );

    if (!mounted) return;

    while (!enviado) {
      final esDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
      final accion = await mostrarAvisoEnvioFallido(context, esDark: esDark);
      if (accion == AccionEnvioFallido.continuar) break;

      if (!mounted) return;
      setState(() => _enviando = true);
      enviado = await EnvioCuestionario.enviar(
        tipo: 'relaciones',
        payload: payload,
      );
    }

    if (!mounted) return;
    setState(() => _enviando = false);

    _mostrarResultado(relaciones_sanasScore);
  }

  void _mostrarResultado(int relaciones_sanasScore) {
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    //FALTA AJUSTAR ESTA ESCALA
    String nivel = 'Mínimo';
    Color nivelColor = const Color(0xFF43A047);
    if (relaciones_sanasScore >= 14) {
      nivel = 'Severo';
      nivelColor = const Color(0xFFE53935);
    } else if (relaciones_sanasScore >= 10) {
      nivel = 'Moderadamente severo';
      nivelColor = const Color(0xFFFF7043);
    } else if (relaciones_sanasScore >= 5) {
      nivel = 'Moderado';
      nivelColor = const Color(0xFFFDD835);
    } else if (relaciones_sanasScore >= 1) {
      nivel = 'Leve';
      nivelColor = const Color(0xFF8BC34A);
    }

  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E272E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF43A047),
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              'Cuestionario completado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _ScoreRow(
              label: 'relaciones_sanas',
              //FALTA AJUSTAR ESTE PARÁMETRO
              score: '$relaciones_sanasScore / 21',
              extra: nivel,
              color: nivelColor,
              isDark: isDark,
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
                backgroundColor: const Color(0xFF43A047),
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
  @override
  Widget build(BuildContext context) {
    if (_cargandoPreguntas) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Mientras se envía (y en cada reintento) se avisa que está guardando, en
    // vez de dejar la pantalla como si nada estuviera pasando.
    if (_enviando) {
      final esDark = Provider.of<ThemeProvider>(context).isDarkMode;
      return Scaffold(
        backgroundColor: esDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF5C6BC0)),
              const SizedBox(height: 16),
              Text(
                'Guardando respuestas...',
                style: TextStyle(color: esDark ? Colors.white70 : Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final pregunta = _preguntas[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pregunta ${_currentIndex + 1} de ${_preguntas.length}',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                pregunta['bloque_nombre'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¿Has experimentado alguno de los siguientes puntos?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        pregunta['pregunta'],
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ..._likert3.map(
                (op) => _OptionButton(
                  label: op['etiqueta'] as String,
                  value: op['valor'] as int,
                  color: op['color'] as Color,
                  isDark: isDark,
                  isSelected:
                      _respuestas[pregunta['id']]?['respuesta_valor'] ==
                      op['valor'],
                  onTap: () => _responder(
                    op['valor'] as int,
                    op['etiqueta'] as String,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.score,
    required this.extra,
    required this.color,
    required this.isDark,
  });

  final String label;
  final String score;
  final String extra;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              Text(extra, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (isDark ? const Color(0xFF1E272E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}