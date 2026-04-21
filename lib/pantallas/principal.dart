import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'servicios/auth.dart';
import 'servicios/peticiones.dart';
import 'login.dart';
import 'juegos/tcg_flame_screen.dart';
import 'modulos/selector_modulo_crisis.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MODELOS
// ─────────────────────────────────────────────────────────────────────────────
class FuenteDoc {
  final String titulo;
  final String categoria;
  final String archivo;

  const FuenteDoc({required this.titulo, required this.categoria, required this.archivo});

  factory FuenteDoc.fromJson(Map<String, dynamic> j) => FuenteDoc(
        titulo:    j['titulo']    ?? '',
        categoria: j['categoria'] ?? '',
        archivo:   j['archivo']   ?? '',
      );
}

enum TipoRespuesta { normal, crisis, sinInfo, fueraTema }

TipoRespuesta _parseTipo(String t) {
  switch (t) {
    case 'crisis':     return TipoRespuesta.crisis;
    case 'sin_info':   return TipoRespuesta.sinInfo;
    case 'fuera_tema': return TipoRespuesta.fueraTema;
    default:           return TipoRespuesta.normal;
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final List<FuenteDoc> fuentes;
  final TipoRespuesta tipo;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.fuentes = const [],
    this.tipo    = TipoRespuesta.normal,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
//  SERVICIO SERENA
//  Nota: /chat es un endpoint PÚBLICO en tu backend (sin auth requerida).
//  Usa headers comunes sin token. Cuando añadas auth al backend, cambia
//  Peticiones.headers por Peticiones.getAuthHeaders(token).
// ─────────────────────────────────────────────────────────────────────────────
class SerenaService {
  static Future<Map<String, dynamic>?> enviarMensaje({
    required String mensaje,
    required String sesionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(Peticiones.serenaChat),
        headers: Peticiones.headers,           // ← sin Bearer token (endpoint público)
        body: jsonEncode({
          'mensaje':   mensaje,
          'sesion_id': sesionId,
        }),
      );

      debugPrint('Serena [${response.statusCode}]: ${response.body.substring(0, response.body.length.clamp(0, 200))}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('SerenaService error ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('SerenaService excepción: $e');
      return null;
    }
  }

  static Future<void> limpiarHistorial({required String sesionId}) async {
    try {
      await http.delete(
        Uri.parse('${Peticiones.serenaHistorial}?sesion_id=$sesionId'),
        headers: Peticiones.headers,
      );
    } catch (e) {
      debugPrint('LimpiarHistorial error: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class Principal extends StatefulWidget {
  const Principal({super.key});

  @override
  State<Principal> createState() => _PrincipalState();
}

class _PrincipalState extends State<Principal> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int    _selectedIndex = 1;
  String _title         = 'Inicio';

  final TextEditingController _chatCtrl   = TextEditingController();
  final ScrollController      _scrollCtrl = ScrollController();
  final List<ChatMessage>     _messages   = [];

  // ID de sesión: usa el nombre de usuario guardado en SharedPreferences
  // para que el historial del backend sea por usuario.
  String _sesionId = 'default';

  bool _isTyping = false;

  final Auth _auth = Auth();

  late AnimationController _typingAnimCtrl;

  static const _green      = Color(0xFF43A047);
  static const _greenLight = Color(0xFF66BB6A);
  static const _crisis     = Color(0xFFD32F2F);

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _typingAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _messages.add(ChatMessage(
      text: '¡Hola! Soy Serena, tu acompañante de bienestar emocional 💚\n'
            '¿Cómo te sientes hoy? Cuéntame, estoy aquí para escucharte.',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    _typingAnimCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ENVÍO DE MENSAJE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final texto = _chatCtrl.text.trim();
    if (texto.isEmpty || _isTyping) return;

    _chatCtrl.clear();
    setState(() {
      _messages.add(ChatMessage(text: texto, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();

    // Llama al backend SIN token (endpoint público /chat)
    final data = await SerenaService.enviarMensaje(
      mensaje:  texto,
      sesionId: _sesionId,
    );

    if (data != null) {
      final fuentes = (data['fuentes'] as List? ?? [])
          .map((f) => FuenteDoc.fromJson(f as Map<String, dynamic>))
          .toList();
      _addBotMessage(
        data['respuesta'] ?? 'Sin respuesta',
        fuentes: fuentes,
        tipo:    _parseTipo(data['tipo'] ?? 'normal'),
      );
    } else {
      _addBotMessage('Parece que tuve un problema de conexión. ¿Puedes intentarlo de nuevo? 💚');
    }
  }

  void _addBotMessage(String text, {
    List<FuenteDoc> fuentes = const [],
    TipoRespuesta tipo      = TipoRespuesta.normal,
  }) {
    setState(() {
      _isTyping = false;
      _messages.add(ChatMessage(text: text, isUser: false, fuentes: fuentes, tipo: tipo));
    });
    _scrollToBottom();
  }

  Future<void> _limpiarHistorial() async {
    await SerenaService.limpiarHistorial(sesionId: _sesionId);
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        text: 'Conversación reiniciada. ¿En qué puedo ayudarte? 💚',
        isUser: false,
      ));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      switch (index) {
        case 0:
          _title = 'Chatbot';
          break;
        case 1:
          _title = 'Inicio';
          break;
        default:
          _title = 'Inicio';
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    // Paleta Verde (Solo para elementos activos light, no para fondos oscuros)
    final primaryGreen = const Color(0xFF43A047); 
    
    // Configuración de fondo plano (Flat Colors)
    // Dark Mode: Gris Oscuro Material (Neutral) para evitar tonos verdes
    // Light Mode: Blanco puro o gris muy suave
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor, 
      resizeToAvoidBottomInset: false,
      endDrawer: _buildDrawer(context),
      extendBodyBehindAppBar: false, // Desactivado para fondo plano
      extendBody: true,
      appBar: AppBar(
        title: _selectedIndex == 0
            ? _serenaAppBarTitle(isDarkMode)
            : Text(_title,
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87)),
        centerTitle:     true,
        backgroundColor: Colors.transparent,
        elevation:       0,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black87),
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDarkMode ? Colors.white : primaryGreen, 
              size: 26,
            ),
            onPressed: () => themeProvider.toogleTheme(!isDarkMode),
          ),
          IconButton(
            icon:      const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      // Cuerpo directo, sin Stack ni Imagen de fondo
      body: SafeArea(
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _serenaAppBarTitle(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _serenaAvatar(radius: 18),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Serena',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _green)),
            Row(children: [
              Container(width: 7, height: 7,
                  decoration: const BoxDecoration(color: _greenLight, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(_isTyping ? 'escribiendo...' : 'En línea',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
          ],
        ),
      ],
    );
  }

  void _confirmarLimpiarHistorial() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:   const Text('Limpiar conversación'),
        content: const Text('¿Quieres borrar el historial de esta conversación con Serena?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _crisis,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _limpiarHistorial();
            },
            child: const Text('Borrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BODY
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:  return _buildChat();
      case 1:  return SingleChildScrollView(child: _buildInicio(context));
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildTCG() {
    return const TcgFlameScreen();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CHAT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildChat() {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount:  _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (_isTyping && i == _messages.length) return _typingIndicator(isDark);
              return _messageBubble(_messages[i], isDark);
            },
          ),
        ),
        _chatInputBar(isDark),
      ],
    );
  }

  Widget _messageBubble(ChatMessage msg, bool isDark) {
    final isUser = msg.isUser;

    Color bubbleColor;
    if (!isUser && msg.tipo == TipoRespuesta.crisis) {
      bubbleColor = isDark ? const Color(0xFF4A1010) : const Color(0xFFFFEBEE);
    } else {
      bubbleColor = isUser ? _green : (isDark ? const Color(0xFF2A2A2A) : Colors.white);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 2),
                  child: _serenaAvatar(radius: 15),
                ),
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(22),
                    topRight:    const Radius.circular(22),
                    bottomLeft:  isUser ? const Radius.circular(22) : const Radius.circular(4),
                    bottomRight: isUser ? const Radius.circular(4)  : const Radius.circular(22),
                  ),
                  border: (!isUser && msg.tipo == TipoRespuesta.crisis)
                      ? Border.all(color: _crisis.withOpacity(0.4), width: 1.2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color:     (isUser ? _green : Colors.black).withOpacity(isDark ? 0.2 : 0.07),
                      blurRadius: 8,
                      offset:    const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isUser && msg.tipo == TipoRespuesta.crisis)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Icon(Icons.favorite_rounded, color: _crisis, size: 14),
                          const SizedBox(width: 6),
                          Text('Línea de apoyo disponible',
                              style: TextStyle(color: _crisis, fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    Text(msg.text,
                        style: TextStyle(
                          color:  isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                          fontSize: 15,
                          height:   1.45,
                        )),
                  ],
                ),
              ),
              if (!isUser) const SizedBox(width: 30),
            ],
          ),

          // Chips de fuentes
          if (!isUser && msg.fuentes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 46, top: 6),
              child: Wrap(
                spacing: 6, runSpacing: 4,
                children: msg.fuentes.map((f) => _fuenteChip(f, isDark)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fuenteChip(FuenteDoc f, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        _green.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: _green.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, color: _green, size: 11),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              f.titulo.length > 30 ? '${f.titulo.substring(0, 30)}…' : f.titulo,
              style: TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(padding: const EdgeInsets.only(right: 8, bottom: 2), child: _serenaAvatar(radius: 15)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22), topRight: Radius.circular(22),
                bottomLeft: Radius.circular(4), bottomRight: Radius.circular(22),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: AnimatedBuilder(
              animation: _typingAnimCtrl,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final t = (_typingAnimCtrl.value - i * 0.33).clamp(0.0, 1.0);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color:  _green.withOpacity(0.35 + t * 0.65),
                      shape:  BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                _chatCtrl.text = '¿Cómo puedo manejar la ansiedad?';
                _chatCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _chatCtrl.text.length));
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _green.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.lightbulb_outline, color: _green, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller:      _chatCtrl,
                style:           TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                maxLines:        4,
                minLines:        1,
                textInputAction: TextInputAction.send,
                onSubmitted:     (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText:  'Cuéntame cómo te sientes...',
                  hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  filled:    true,
                  fillColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48, width: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isTyping
                        ? [Colors.grey.shade400, Colors.grey.shade300]
                        : [_green, _greenLight],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: _isTyping ? [] : [BoxShadow(color: _green.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  INICIO
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildInicio(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:  MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  "Hola, estoy\naquí contigo.",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Image.asset(
                'assets/imagenes/quetzal_3.png', // Usamos uno alegre para el saludo
                height: 140,
                width: 140,
                fit: BoxFit.contain,
              ),
            ],
          ),
          
          const SizedBox(height: 30),

          // Lista de opciones
          _buildOptionCard(
            context,
            imagePath: 'assets/imagenes/quetzal_2.png', // Quetzal preocupado/triste
            title: "Últimamente me siento abrumado",
            subtitle: "Vamos a entender qué está pasando",
            color: const Color(0xFF66BB6A), // Verde medio
            onTap: () {
              // Navegar al cuestionario correspondiente
            },
          ),
          
          _buildOptionCard(
            context,
            imagePath: 'assets/imagenes/quetzal_4.png', // Quetzal pensando
            title: "Mis pensamientos me preocupan",
            subtitle: "Hablemos de lo que ronda por tu cabeza",
            color: const Color(0xFFA5D6A7), // Verde claro
            textColor: Colors.black87,
            onTap: () {
              // Navegar al cuestionario
            },
          ),
          
           _buildOptionCard(
            context,
            imagePath: 'assets/imagenes/quetzal_5.png', // Corazón o emoción
            title: "Quiero saber cómo estoy emocionalmente",
            subtitle: "Un espacio para conocerte mejor",
            color: const Color(0xFFC8E6C9), // Verde muy claro
            textColor: Colors.black87,
             onTap: () {
              // Navegar al cuestionario
            },
          ),

          _buildOptionCard(
            context,
            imagePath: 'assets/imagenes/quetzal_6.png', // Quetzal cantando/feliz
            title: "Solo quiero hablar un poco",
            subtitle: "No tienes que saber qué responder",
            color: const Color(0xFFFFF3E0), // Naranja/Beige muy suave
            textColor: Colors.black87,
             onTap: () {
              // Navegar al cuestionario
            },
          ),
          
          const SizedBox(height: 80), // Espacio para el BottomNav
        ],
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, {
    required String imagePath, required String title,
    required String subtitle,  required Color  color,
    required VoidCallback onTap, Color textColor = Colors.white,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // Ajuste de colores para modo oscuro si es necesario
    final cardColor = isDarkMode ? color.withOpacity(0.2) : color;
    final titleColor = isDarkMode ? Colors.white : (textColor == Colors.white ? Colors.white : const Color(0xFF1B5E20));
    final subTitleColor = isDarkMode ? Colors.white70 : (textColor == Colors.white ? Colors.white70 : const Color(0xFF2E7D32));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDarkMode ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Imagen del quetzal
                Image.asset(
                  imagePath,
                  height: 70,
                  width: 70,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 16),
                
                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: subTitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Flecha
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: titleColor.withOpacity(0.5),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  DRAWER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30), bottomLeft: Radius.circular(30))),
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode 
                    ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                    : [_green, _greenLight],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Image.asset(
                        'assets/imagenes/quetzal_1.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text('Hola, Usuario',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const Text('Bienvenido de nuevo',
                    style: TextStyle(fontSize: 14, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _drawerItem(icon: Icons.person_outline_rounded,     title: 'Mi Perfil',      color: _green,        onTap: () => Navigator.pop(context)),
                _drawerItem(icon: Icons.settings_outlined,          title: 'Configuración',   color: Colors.orange, onTap: () => Navigator.pop(context)),
                _drawerItem(icon: Icons.notifications_none_rounded, title: 'Notificaciones', color: Colors.blue,   onTap: () => Navigator.pop(context)),
                Divider(color: isDarkMode ? Colors.grey[800] : Colors.grey[200], height: 30),
                _drawerItem(icon: Icons.info_outline_rounded,       title: 'Acerca de',      color: Colors.purple, onTap: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: Color(0xFFD32F2F)),
                title:   const Text('Cerrar Sesión',
                    style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w600)),
                onTap: () async {
                  await _auth.clearToken();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const Login()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: TextStyle(
            color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500, fontSize: 16)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: isDark ? Colors.grey[600] : Colors.grey[400], size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BOTTOM NAV
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.chat_bubble_outline, "Chatbot"),
              _navItem(1, Icons.home_outlined, "Inicio"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final isDark     = Provider.of<ThemeProvider>(context).isDarkMode;
    return InkWell(
      onTap:        () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color:        isSelected ? _green.withOpacity(isDark ? 0.2 : 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? _green : (isDark ? Colors.grey : Colors.grey[400])),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: _green, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _serenaAvatar({double radius = 20, Color? borderColor}) {
    return Container(
      width: radius * 2, height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [_green, _greenLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: borderColor != null ? Border.all(color: borderColor, width: 2) : null,
        boxShadow: [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Center(
        child: Text('S',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.85)),
      ),
    );
  }
}