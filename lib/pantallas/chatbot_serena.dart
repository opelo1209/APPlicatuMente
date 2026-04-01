import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modelos/mensaje_serena.dart';
import '../servicios/servicio_serena.dart';
import 'theme_provider.dart';

class ChatbotSerena extends StatefulWidget {
  const ChatbotSerena({super.key});

  @override
  State<ChatbotSerena> createState() => _ChatbotSerenaState();
}

class _ChatbotSerenaState extends State<ChatbotSerena> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<MensajeSerena> _mensajes = [];
  bool _cargando = false;
  bool _conectado = false;
  bool _mostrarBienvenida = true;

  static const _verde = Color(0xFF43A047);
  static const _verdeOsc = Color(0xFF2E7D32);

  static const _sugerencias = [
    'Como calmar la ansiedad',
    'Que es el mindfulness',
    'Tecnica 5-4-3-2-1',
    'Identificar mis emociones',
    'Como manejar el enojo',
    'Emocion vs sentimiento',
  ];

  @override
  void initState() {
    super.initState();
    _chequearConexion();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _chequearConexion() async {
    final ok = await ServicioSerena.verificarConexion();
    if (mounted) setState(() => _conectado = ok);
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
    if (texto.trim().isEmpty || _cargando) return;

    setState(() {
      _mostrarBienvenida = false;
      _mensajes.add(MensajeSerena(texto: texto.trim(), esUsuario: true));
      _cargando = true;
    });
    _ctrl.clear();
    _irAlFinal();

    final resultado = await ServicioSerena.enviarMensaje(texto.trim());

    if (mounted) {
      setState(() {
        _mensajes.add(MensajeSerena(
          texto: resultado['respuesta'] ?? '',
          esUsuario: false,
          tipo: resultado['tipo'] ?? 'normal',
          fuentes: List<Map<String, String>>.from(
            (resultado['fuentes'] ?? []).map((f) => {
              'titulo': f['titulo']?.toString() ?? '',
              'categoria': f['categoria']?.toString() ?? '',
            }),
          ),
        ));
        _cargando = false;
      });
      _irAlFinal();
      if (resultado['tipo'] == 'crisis') _mostrarBannerCrisis();
    }
  }

  void _confirmarLimpiar() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nueva conversacion', style: TextStyle(fontWeight: FontWeight.bold)),
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
              if (mounted) {
                setState(() {
                  _mensajes.clear();
                  _mostrarBienvenida = true;
                  _cargando = false;
                });
              }
            },
            child: const Text('Si, limpiar', style: TextStyle(color: _verde, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _mostrarBannerCrisis() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🕊', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Si tu o alguien que conoces esta en un momento dificil, hay apoyo gratuito disponible.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.phone, color: Colors.white),
                label: const Text(
                  'Llamar ahora — 800 290 0024',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'SAPTEL · Gratis · 24 horas',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Column(
      children: [
        _barraEstado(isDark),
        Expanded(
          child: _mostrarBienvenida && _mensajes.isEmpty
              ? _pantallaInicio(isDark)
              : _listaMensajes(isDark),
        ),
        _campoEntrada(isDark),
      ],
    );
  }

  Widget _barraEstado(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 28,
      color: _conectado
          ? (_verde.withOpacity(isDark ? 0.15 : 0.08))
          : Colors.orange.withOpacity(isDark ? 0.15 : 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: _conectado ? _verde : Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _conectado ? 'Serena lista para ayudarte' : 'Sin conexion con el servidor',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _conectado
                  ? (_verde)
                  : Colors.orange[800]!,
            ),
          ),
          const Spacer(),
          if (_mensajes.isNotEmpty)
            GestureDetector(
              onTap: _confirmarLimpiar,
              child: Text(
                'Nueva',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pantallaInicio(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          CircleAvatar(
            radius: 34,
            backgroundColor: _verde,
            child: const Text('S', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Text(
            'Hola, soy Serena',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tu espacio seguro para hablar\nde como te sientes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Text(
              'Soy un apoyo educativo, no reemplazo a un especialista.\nEn crisis llama al 800 290 0024 (SAPTEL, 24h).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.amber[300] : Colors.amber[900],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Por donde quieres empezar?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ..._sugerencias.map((s) => _chipSugerencia(s, isDark)),
        ],
      ),
    );
  }

  Widget _chipSugerencia(String texto, bool isDark) {
    return GestureDetector(
      onTap: () => _enviar(texto),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          ),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _verdeOsc,
          ),
        ),
      ),
    );
  }

  Widget _listaMensajes(bool isDark) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _mensajes.length + (_cargando ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _mensajes.length) return _indicadorEscribiendo(isDark);
        return _burbuja(_mensajes[i], isDark);
      },
    );
  }

  Widget _burbuja(MensajeSerena msg, bool isDark) {
    if (msg.esUsuario) return _burbujaUsuario(msg, isDark);
    return _burbujaBot(msg, isDark);
  }

  Widget _burbujaUsuario(MensajeSerena msg, bool isDark) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _verde,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          msg.texto,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        ),
      ),
    );
  }

  Widget _burbujaBot(MensajeSerena msg, bool isDark) {
    Color fondo;
    Color texto;
    Color borde;

    if (msg.esCrisis) {
      fondo = isDark ? const Color(0xFF3D1515) : const Color(0xFFFFF5F5);
      texto = isDark ? const Color(0xFFFFAAAA) : const Color(0xFF7B2D2D);
      borde = const Color(0xFFFEB2B2);
    } else {
      fondo = isDark ? const Color(0xFF2C2C2C) : Colors.white;
      texto = isDark ? Colors.white : Colors.black87;
      borde = isDark ? Colors.grey[700]! : const Color(0xFFE8EDF5);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 52),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: borde),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.esCrisis) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: const Text(
                  'Esto es importante',
                  style: TextStyle(color: Color(0xFFC53030), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFFEB2B2)),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(msg.texto, style: TextStyle(color: texto, fontSize: 14, height: 1.5)),
            ),
            if (msg.fuentes.isNotEmpty) ...[
              Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[200]),
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
                        color: _verdeOsc,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...msg.fuentes.map((f) {
                      final nombre = f['titulo'] ?? '';
                      final cat = f['categoria'] ?? '';
                      return Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$nombre${cat.isNotEmpty ? ' · $cat' : ''}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _indicadorEscribiendo(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: isDark ? Colors.grey[700]! : const Color(0xFFE8EDF5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _punto(i, isDark)),
        ),
      ),
    );
  }

  Widget _punto(int i, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + i * 150),
      builder: (_, v, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 7, height: 7,
        decoration: BoxDecoration(
          color: _verde.withOpacity(0.4 + 0.6 * v),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _campoEntrada(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
            Expanded(
              child: TextField(
                controller: _ctrl,
                enabled: !_cargando,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: _enviar,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Escribeme como te sientes...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: _verde, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: _cargando ? null : () => _enviar(_ctrl.text),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _cargando ? Colors.grey[300] : _verde,
                    shape: BoxShape.circle,
                    boxShadow: _cargando ? [] : [
                      BoxShadow(
                        color: _verde.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: _cargando ? Colors.grey[500] : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}