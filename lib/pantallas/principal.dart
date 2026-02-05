import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'login.dart';

class Principal extends StatefulWidget {
  const Principal({super.key});

  @override
  State<Principal> createState() => _PrincipalState();
}

class _PrincipalState extends State<Principal> with TickerProviderStateMixin {
  int _selectedIndex = 1;
  String _title = 'Inicio';
  
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
    
    // Paleta Verde (Solo para elementos activos light, no para fondos oscuros)
    final primaryGreen = const Color(0xFF43A047); 
    
    // Configuración de fondo plano (Flat Colors)
    // Dark Mode: Gris Oscuro Material (Neutral) para evitar tonos verdes
    // Light Mode: Blanco puro o gris muy suave
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: backgroundColor, 
      resizeToAvoidBottomInset: false,
      drawer: _buildDrawer(context),
      extendBodyBehindAppBar: false, // Desactivado para fondo plano
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
            icon: Icon(
              isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDarkMode ? Colors.white : primaryGreen, 
              size: 26,
            ),
            onPressed: () => themeProvider.toogleTheme(!isDarkMode),
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

  // --- Widgets Auxiliares ---

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
         return const Center(child: Text("Chatbot Proxy")); 
      case 1:
        return SingleChildScrollView(child: _buildInicio(context));
      default:
        return Container();
    }
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

    // Ajuste de colores para modo oscuro si es necesario
    final cardColor = isDarkMode ? color.withOpacity(0.2) : color;
    final titleColor = isDarkMode ? Colors.white : (textColor == Colors.white ? Colors.white : const Color(0xFF1B5E20));
    final subTitleColor = isDarkMode ? Colors.white70 : (textColor == Colors.white ? Colors.white70 : const Color(0xFF2E7D32));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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

  Widget _buildDrawer(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    // Drawer minimalista
    return Drawer(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white, // Fondo neutro en dark
      child: Column(
        children: [
          // Header personalizado para evitar overflows de la imagen
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 20), // Espacio seguro superior
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide.none),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Imagen directa sin recorte circular
                Image.asset(
                  'assets/imagenes/quetzal_1.png',
                  height: 140, // Un poco más grande ahora que tenemos espacio
                  fit: BoxFit.contain, 
                ),
                const SizedBox(height: 10),
                 Text(
                  'Usuario',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Divider(indent: 10, endIndent: 10),
          _buildDrawerItem(Icons.settings, "Configuración", () => Navigator.pop(context)),
          _buildDrawerItem(Icons.info_outline, "Acerca de", () => Navigator.pop(context)),
          const Spacer(),
          _buildDrawerItem(Icons.logout, "Cerrar Sesión", () {
             Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const Login()),
                (Route<dynamic> route) => false,
              );
          }, isDestructive: true),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
     final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
     final color = isDestructive ? const Color(0xFFEF5350) : (isDarkMode ? Colors.white70 : Colors.black87);
     
     return ListTile(
       leading: Icon(icon, color: color),
       title: Text(
         title,
         style: TextStyle(color: color, fontWeight: FontWeight.w500),
       ),
       onTap: onTap,
       contentPadding: const EdgeInsets.symmetric(horizontal: 24),
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

