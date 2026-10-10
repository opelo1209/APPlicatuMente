import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../diario/diario_flujo.dart' show mostrarNumero;
import '../diario/diario_widgets.dart' show TarjetaLineasAyuda;
import '../modelos/mensaje_serena.dart';
import '../servicios/personalizacion.dart';
import '../servicios/prototipo.dart';
import '../servicios/servicio_serena.dart';
import '../theme_provider.dart';

class ChatbotSerena extends StatefulWidget {
  const ChatbotSerena({super.key, this.accentColor});

  final Color? accentColor;

  @override
  State<ChatbotSerena> createState() => _ChatbotSerenaState();
}

class _ChatbotSerenaState extends State<ChatbotSerena> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<MensajeSerena> _mensajes = [];

  bool _cargando = false;
  // PROTOTIPO Semana 3, fase 5: texto que ya llego mientras Serena termina.
  String? _parcial;
  // PROTOTIPO Semana 2: el backend detuvo la conversación por riesgo.
  bool _pausada = false;
  bool _conectado = false;

  static const Color _verde = Color(0xFF43A047);

  Color get _accentColor => widget.accentColor ?? _verde;
  Color get _accentDark => AppPersonalizacion.darken(_accentColor, 0.22);

  static const String _mensajeBienvenida =
      '¡Hola! Soy Serena, tu acompañante de bienestar emocional 💚\n¿Cómo te sientes hoy? Cuéntame, estoy aquí para escucharte.';

  static const List<String> _recomendaciones = [
    'Como calmar la ansiedad',
    'Que es el mindfulness',
    'Tecnica 5-4-3-2-1',
    'Como identificar mis emociones',
    'Como manejar el enojo',
    'Como dormir mejor hoy',
    'Ejercicio de respiracion profunda',
    'Como hablar con alguien de confianza',
    'Que hacer cuando me siento abrumado',
    'Como practicar la autocompasion',
  ];

  int _recomendacionIdx = 0;

  void _sugerirRecomendacion() {
    final texto = _recomendaciones[_recomendacionIdx % _recomendaciones.length];
    _recomendacionIdx++;
    _ctrl.text = texto;
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: texto.length),
    );
  }

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    final ok = await ServicioSerena.verificarConexion();
    if (!mounted) return;
    setState(() {
      _conectado = ok;
      _mensajes.add(MensajeSerena(texto: _mensajeBienvenida, esUsuario: false));
    });
    _irAlFinal();
  }

  void _irAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviar(String texto) async {
    final limpio = texto.trim();
    if (limpio.isEmpty || _cargando || _pausada) return;

    setState(() {
      _mensajes.add(MensajeSerena(texto: limpio, esUsuario: true));
      _cargando = true;
    });
    _ctrl.clear();
    _irAlFinal();

    // PROTOTIPO Semana 3, fase 5: el texto parcial (material aprobado u
    // oracion ya revisada) se muestra en la burbuja de "escribiendo".
    var resultado = <String, dynamic>{};
    await for (final evento in ServicioSerena.enviarMensajeStream(limpio)) {
      if (!mounted) return;
      if (evento['evento'] == 'parcial') {
        setState(() => _parcial = evento['texto']?.toString());
        _irAlFinal();
      } else {
        resultado = evento;
      }
    }
    final fuentesRaw = resultado['fuentes'];
    final fuentes = <Map<String, String>>[];

    if (fuentesRaw is List) {
      for (final item in fuentesRaw) {
        if (item is Map) {
          fuentes.add({
            'titulo': item['titulo']?.toString() ?? '',
            'categoria': item['categoria']?.toString() ?? '',
            'revision': item['revision']?.toString() ?? 'pendiente',
            'revisor': item['revisor']?.toString() ?? '',
          });
        }
      }
    }

    if (!mounted) return;

    final tipo = resultado['tipo']?.toString() ?? 'normal';
    final detener = resultado['detener'] == true;
    final respuesta =
        resultado['respuesta']?.toString() ?? 'Sin respuesta por ahora.';

    setState(() {
      _mensajes.add(
        MensajeSerena(
          texto: respuesta,
          esUsuario: false,
          tipo: tipo,
          fuentes: fuentes,
        ),
      );
      _cargando = false;
      _parcial = null;
      _pausada = _pausada || detener;
    });
    _irAlFinal();

    if (tipo == 'crisis') _mostrarBannerCrisis();
  }

  void _confirmarLimpiar() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Nueva conversacion',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Se borrara el historial actual.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ServicioSerena.limpiarHistorial();
              if (!mounted) return;
              setState(() {
                _mensajes.clear();
                _mensajes.add(
                  MensajeSerena(texto: _mensajeBienvenida, esUsuario: false),
                );
                _cargando = false;
              });
            },
            child: Text(
              'Si, limpiar',
              style: TextStyle(
                color: _accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarBannerCrisis() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_rounded,
                color: _accentColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Hay apoyo disponible para ti',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Si estas pasando por un momento dificil, no tienes que estar solo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            // PROTOTIPO Semana 2: antes decía «Llamar al 800 290 0024» con la
            // etiqueta SAPTEL, que no corresponde. Mismas líneas que el diario.
            TarjetaLineasAyuda(
              titulo: _pausada
                  ? 'La conversación se pausó. Habla ahora con alguien preparado'
                  : 'Habla ahora con alguien preparado',
              onLlamar: (linea) => mostrarNumero(ctx, linea),
            ),
          ],
        ),
      ),
    );
  }

  // PROTOTIPO Semana 3: (icono, etiqueta, color, fondo) del encabezado de
  // cada tipo de respuesta; null = sin encabezado.
  (IconData, String, Color, Color)? _encabezado(String tipo) => switch (tipo) {
    'crisis' => (
      Icons.favorite_rounded,
      'Estoy aquí contigo',
      const Color(0xFF7C5CBF),
      const Color(0xFFEDE8FA),
    ),
    'limite' => (
      Icons.block_rounded,
      'Esto no lo puedo hacer',
      const Color(0xFF1565C0),
      const Color(0xFFE8F1FB),
    ),
    'bloqueada' => (
      Icons.shield_outlined,
      'Revisé mi respuesta por seguridad',
      const Color(0xFF8D6E00),
      const Color(0xFFFFF8E1),
    ),
    'explorar' => (
      Icons.support_agent_rounded,
      'Si lo necesitas, hay ayuda',
      const Color(0xFF00796B),
      const Color(0xFFE0F2F1),
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5);

    return Column(
      children: [
        _header(isDark),
        Expanded(
          child: Container(color: bg, child: _listaMensajes(isDark)),
        ),
        _campoEntrada(isDark),
      ],
    );
  }

  Widget _header(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _accentColor,
                child: const Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _conectado ? const Color(0xFF4CAF50) : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Serena',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  _conectado ? '• En línea' : '• Sin conexión',
                  style: TextStyle(
                    fontSize: 11,
                    color: _conectado ? _accentColor : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              size: 20,
            ),
            onPressed: _mensajes.length > 1 ? _confirmarLimpiar : null,
          ),
        ],
      ),
    );
  }

  Widget _listaMensajes(bool isDark) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _mensajes.length + (_cargando ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _mensajes.length) {
          return _indicadorEscribiendo(isDark, parcial: _parcial);
        }
        return _burbuja(_mensajes[i], isDark);
      },
    );
  }

  Widget _burbuja(MensajeSerena msg, bool isDark) {
    if (msg.esUsuario) return _burbujaUsuario(msg);
    return _burbujaBot(msg, isDark);
  }

  Widget _burbujaUsuario(MensajeSerena msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 56),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _accentColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.texto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _burbujaBot(MensajeSerena msg, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _accentColor,
            child: const Text(
              'S',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: isDark
                    ? const []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PROTOTIPO Semana 3: encabezado según cómo se decidió la
                  // respuesta (crisis, límite o respuesta revisada por la
                  // guardia), como los avisos de los asistentes comerciales.
                  if (_encabezado(msg.tipo) case (
                    final icono,
                    final etiqueta,
                    final color,
                    final fondo,
                  )) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF32324A) : fondo,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icono,
                            size: 12,
                            color: isDark ? Colors.purple[200] : color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            etiqueta,
                            style: TextStyle(
                              color: isDark ? Colors.purple[200] : color,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.grey[700]!
                          : color.withValues(alpha: 0.25),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Text(
                      msg.texto,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  if (msg.fuentes.isNotEmpty) ...[
                    Divider(
                      height: 1,
                      color: isDark ? Colors.grey[700] : Colors.grey[200],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Del material del programa:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _accentDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          for (final fuente in msg.fuentes)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]
                                    : const Color(0xFFF0F4FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${fuente['titulo'] ?? ''}${(fuente['categoria'] ?? '').isNotEmpty ? ' - ${fuente['categoria']}' : ''}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  _etiquetaRevision(fuente),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cierre de la Semana 3: si psicología ya revisó el texto citado.
  Widget _etiquetaRevision(Map<String, String> fuente) {
    final revisor = fuente['revisor'] ?? '';
    final (icono, texto, color) = switch (fuente['revision']) {
      'aprobado' => (
        Icons.verified,
        revisor.isEmpty ? 'Revisado por psicología' : 'Revisado por psicología ($revisor)',
        const Color(0xFF2E7D32),
      ),
      'corregido' => (
        Icons.edit_note,
        'Corregido por psicología',
        const Color(0xFF2E7D32),
      ),
      'cambios' => (
        Icons.rate_review_outlined,
        'Con observaciones de psicología',
        const Color(0xFFB26A00),
      ),
      _ => (
        Icons.hourglass_empty,
        'Pendiente de revisión clínica',
        const Color(0xFF757575),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 11, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicadorEscribiendo(bool isDark, {String? parcial}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _accentColor,
            child: const Text(
              'S',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: isDark
                    ? const []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (parcial != null) ...[
                    Text(
                      parcial,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PuntoEscribiendo(delayMs: 0, color: _accentColor),
                      _PuntoEscribiendo(delayMs: 150, color: _accentColor),
                      _PuntoEscribiendo(delayMs: 300, color: _accentColor),
                    ],
                  ),
                  // PROTOTIPO Semana 3: la respuesta la redacta un modelo
                  // local; en el servidor tarda unos 20 s (fase 4).
                  if (kEsPrototipo) ...[
                    const SizedBox(height: 6),
                    Text(
                      parcial == null
                          ? 'Serena está pensando; en el prototipo puede tardar hasta medio minuto.'
                          : 'Serena está terminando su respuesta…',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoEntrada(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: GestureDetector(
                onTap: _cargando ? null : _sugerirRecomendacion,
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: _cargando
                      ? (isDark ? Colors.grey[700] : Colors.grey[300])
                      : (isDark ? Colors.grey[400] : Colors.grey[500]),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                enabled: !_cargando && !_pausada,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: _enviar,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: _pausada
                      ? 'La conversación está en pausa'
                      : 'Cuéntame cómo te sientes...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFF0F2F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: _accentColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _cargando || _pausada ? null : () => _enviar(_ctrl.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _cargando || _pausada
                      ? Colors.grey[300]
                      : _accentColor,
                  shape: BoxShape.circle,
                  boxShadow: _cargando || _pausada
                      ? const []
                      : [
                          BoxShadow(
                            color: _accentColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: _cargando || _pausada
                      ? Colors.grey[500]
                      : Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PuntoEscribiendo extends StatelessWidget {
  final int delayMs;
  final Color color;

  const _PuntoEscribiendo({required this.delayMs, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.25, end: 1),
      duration: Duration(milliseconds: 650 + delayMs),
      curve: Curves.easeInOut,
      builder: (context, value, child) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: color.withValues(alpha: value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
