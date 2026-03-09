import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'login.dart';
import 'modulos/selector_modulo_crisis.dart';

class Principal extends StatefulWidget {
  const Principal({super.key});

  @override
  State<Principal> createState() => _PrincipalState();
}

class _PrincipalState extends State<Principal> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 1;
  String _title = 'Inicio';

  // Variables para el Chatbot
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [
    {'sender': 'bot', 'text': '¡Hola! Soy tu asistente emocional.\n¿Cómo te sientes hoy?'},
  ];

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty) return;
    setState(() {
      _messages.add({'sender': 'user', 'text': _chatController.text});
    });
    _chatController.clear();
    _scrollToBottom();
    
    // Simular respuesta simple
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'bot', 'text': 'Gracias por compartirlo. Estoy aquí para escucharte.'});
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    // Configuración de fondo plano (Flat Colors)
    // Dark Mode: Gris Oscuro Material (Neutral) para evitar tonos verdes
    // Light Mode: Blanco puro o gris muy suave
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor, 
      resizeToAvoidBottomInset: false,
      endDrawer: _buildDrawer(context),
      extendBodyBehindAppBar: false,
      extendBody: true,
      appBar: AppBar(
        title: Text(
          _title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // --- Widgets Auxiliares ---

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
         return _buildChatbot(); 
      case 1:
        return SingleChildScrollView(child: _buildInicio(context));
      default:
        return Container();
    }
  }

  Widget _buildChatbot() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final primaryGreen = const Color(0xFF43A047);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg['sender'] == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isUser ? primaryGreen : (isDarkMode ? const Color(0xFF2C2C2C) : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(24),
                      topRight: const Radius.circular(24),
                      bottomLeft: isUser ? const Radius.circular(24) : const Radius.circular(4),
                      bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(24),
                    ),
                     boxShadow: [
                      if (!isDarkMode)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  child: Text(
                    msg['text']!,
                    style: TextStyle(
                      color: isUser ? Colors.white : (isDarkMode ? Colors.white : Colors.black87),
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      hintStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[500]),
                      filled: true,
                      fillColor: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryGreen, const Color(0xFF66BB6A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInicio(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    // Estilos de texto
    final headerStyle = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: isDarkMode ? Colors.white : const Color(0xFF2E7D32), // Verde oscuro
      height: 1.2,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con el Quetzal grande
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  "Hola, estoy\naquí contigo.",
                  style: headerStyle,
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
            imagePath: 'assets/imagenes/quetzal_4.png', // Quetzal preocupado/triste
            title: "¿Pensamientos suicidas?",
            subtitle: "Vamos a entender qué está pasando",
            color: const Color(0xFF66BB6A), // Verde medio
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SelectorModuloCrisis(),
                ),
              );
            },
          ),
          
          _buildOptionCard(
            context,
            imagePath: 'assets/imagenes/quetzal_2.png', // Quetzal pensando
            title: "Mis pensamientos me preocupan",
            subtitle: "Hablemos de lo que ronda por tu cabeza",
            color:  const Color(0xFFA5D6A7), // Verde claro
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

  Widget _buildOptionCard(
    BuildContext context, {
    required String imagePath,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    Color textColor = Colors.white,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // Usamos el textColor para decidir colores en modo claro, en modo oscuro siempre blanco
    final cardColor = isDarkMode ? color.withOpacity(0.25) : color;
    final resolvedTitleColor = isDarkMode ? Colors.white : (textColor == Colors.white ? Colors.white : Colors.black87);
    final resolvedSubtitleColor = isDarkMode ? Colors.white70 : (textColor == Colors.white ? Colors.white.withOpacity(0.85) : Colors.black54);
    final resolvedArrowColor = isDarkMode ? Colors.white54 : (textColor == Colors.white ? Colors.white.withOpacity(0.7) : Colors.black38);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDarkMode ? [] : [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Image.asset(
                  imagePath,
                  height: 70,
                  width: 70,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: resolvedTitleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: resolvedSubtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: resolvedArrowColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final primaryGreen = const Color(0xFF43A047);
    
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          bottomLeft: Radius.circular(30),
        ),
      ),
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
                    : [const Color(0xFF43A047), const Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
              ),
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
                  child: const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(5.0),
                      child: Image(
                        image: AssetImage('assets/imagenes/quetzal_1.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Hola, Usuario',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Bienvenido de nuevo',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Items del menú
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildDrawerItem(
                  icon: Icons.person_outline_rounded, 
                  title: "Mi Perfil", 
                  onTap: () => Navigator.pop(context),
                  color: primaryGreen,
                ),
                _buildDrawerItem(
                  icon: Icons.settings_outlined, 
                  title: "Configuración", 
                  onTap: () => Navigator.pop(context),
                  color: Colors.orange,
                ),
                _buildDrawerItem(
                  icon: Icons.notifications_none_rounded, 
                  title: "Notificaciones", 
                  onTap: () => Navigator.pop(context),
                  color: Colors.blue,
                ),
                Divider(color: isDarkMode ? Colors.grey[800] : Colors.grey[200], height: 30),
                _buildDrawerItem(
                  icon: Icons.info_outline_rounded, 
                  title: "Acerca de", 
                  onTap: () => Navigator.pop(context),
                  color: Colors.purple,
                ),
              ],
            ),
          ),
          
          // Botón de Cerrar Sesión
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: Color(0xFFD32F2F)),
                title: const Text(
                  "Cerrar Sesión",
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                   Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const Login()),
                      (Route<dynamic> route) => false,
                    );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon, 
    required String title, 
    required VoidCallback onTap,
    required Color color,
  }) {
     final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
     
     return Container(
       margin: const EdgeInsets.only(bottom: 8),
       decoration: BoxDecoration(
         color: isDarkMode ? Colors.transparent : Colors.transparent,
         borderRadius: BorderRadius.circular(15),
       ),
       child: ListTile(
         leading: Container(
           padding: const EdgeInsets.all(8),
           decoration: BoxDecoration(
             color: color.withOpacity(0.1),
             borderRadius: BorderRadius.circular(10),
           ),
           child: Icon(icon, color: color, size: 22),
         ),
         title: Text(
           title,
           style: TextStyle(
             color: isDarkMode ? Colors.white : Colors.black87,
             fontWeight: FontWeight.w500,
             fontSize: 16,
           ),
         ),
         trailing: Icon(
           Icons.chevron_right_rounded, 
           color: isDarkMode ? Colors.grey[600] : Colors.grey[400], 
           size: 20
         ),
         onTap: onTap,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
         contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
       ),
     );
  }

  Widget _buildBottomNav(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF121212) : Colors.white, // Neutro en dark
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavBarItem(0, Icons.chat_bubble_outline, "Chatbot"),
              _buildNavBarItem(1, Icons.home_outlined, "Inicio"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final primaryGreen = const Color(0xFF43A047); 
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
             ? primaryGreen.withOpacity(isDarkMode ? 0.2 : 0.1) 
             : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryGreen : (isDarkMode ? Colors.grey : Colors.grey[400]),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

