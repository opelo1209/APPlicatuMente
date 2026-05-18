import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'login.dart';
import 'monitoreo_admin.dart';
import 'admin/editor_cuestionarios_admin.dart';
import 'juegos/tcg_flame_screen.dart';
import 'modulos/selector_modulo_crisis.dart';
import 'modulos/chatbot_serena.dart';
import 'servicios/auth.dart';
import 'servicios/user.dart';

class Principal extends StatefulWidget {
  const Principal({super.key});

  @override
  State<Principal> createState() => _PrincipalState();
}

class _PrincipalState extends State<Principal> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 1;
  String _title = 'Inicio';
  String _nombreUsuario = 'Usuario';
  String _perfilTipo = '';
  String _perfilLabel = 'Usuario';
  Map<String, dynamic> _permissions = const {};
  Map<String, dynamic> _progress = const {};
  bool _loadingSession = true;
  String? _sessionError;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    if (mounted) {
      setState(() {
        _loadingSession = true;
        _sessionError = null;
      });
    }

    final result = await User().getSessionContext();
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _nombreUsuario = 'Sin sesión';
        _perfilTipo = '';
        _perfilLabel = 'Sin conexión';
        _permissions = const {};
        _progress = const {};
        _loadingSession = false;
        _sessionError =
            result['message']?.toString() ??
            'No se pudo consultar /users/session';
      });
      return;
    }

    final data = result['data'];
    if (data is! Map) {
      setState(() {
        _loadingSession = false;
        _sessionError = 'Respuesta inesperada de /users/session';
      });
      return;
    }

    final userData = data['user'];
    final dbInfo = userData is Map ? userData['db_info'] : null;
    final nombreUsuario = dbInfo is Map
        ? dbInfo['nombre_usuario']?.toString()
        : userData is Map
        ? userData['nombre_usuario']?.toString()
        : null;
    final perfilTipo = data['perfil_tipo']?.toString();
    final perfilLabel = data['perfil_label']?.toString();
    final permissions = data['permissions'];
    final progress = data['progress'];

    setState(() {
      _nombreUsuario = nombreUsuario?.isNotEmpty == true
          ? nombreUsuario!
          : 'Usuario';
      _perfilTipo = perfilTipo?.isNotEmpty == true ? perfilTipo! : '';
      _perfilLabel = perfilLabel?.isNotEmpty == true
          ? perfilLabel!
          : _roleLabel(_perfilTipo);
      _permissions = permissions is Map
          ? Map<String, dynamic>.from(permissions)
          : const {};
      _progress = progress is Map
          ? Map<String, dynamic>.from(progress)
          : const {};
      _loadingSession = false;
      _sessionError = null;
    });
  }

  bool _can(String permission) => _permissions[permission] == true;

  String get _crisisSubtitle {
    if (_progress['ansiedad_desbloqueado'] == true) {
      return 'Ansiedad ya está desbloqueado según la base';
    }
    return _perfilTipo == 'padre'
        ? "Revisa módulos y cuestionarios para padres"
        : "Vamos a entender qué está pasando";
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      switch (index) {
        case 0:
          _title = 'Serena';
          break;
        case 1:
          _title = 'Inicio';
          break;
        // case 2:
        //   _title = 'TCG Salud Mental';
        //   break;
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
    final backgroundColor = isDarkMode
        ? const Color(0xFF121212)
        : const Color(0xFFFAFAFA);

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
            onPressed: () async {
              await _loadCurrentUser();
              if (!mounted) return;
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // --- Widgets Auxiliares ---

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const ChatbotSerena();
      case 1:
        return SingleChildScrollView(child: _buildInicio(context));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInicio(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // Estilos de texto
    final headerStyle = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: isDarkMode
          ? Colors.white
          : const Color(0xFF2E7D32), // Verde oscuro
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
                child: Text("Hola, estoy\naquí contigo.", style: headerStyle),
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
          if (_loadingSession)
            const Center(child: CircularProgressIndicator())
          else if (_sessionError != null)
            _buildOptionCard(
              context,
              imagePath: 'assets/imagenes/quetzal_4.png',
              title: "No se pudo consultar tu sesión",
              subtitle: _sessionError!,
              color: const Color(0xFFD32F2F),
              onTap: _loadCurrentUser,
            )
          else
            ..._homeCardsForRole(context),

          // _buildOptionCard(
          //   context,
          //   imagePath: 'assets/imagenes/quetzal_2.png', // Quetzal pensando
          //   title: "Mis pensamientos me preocupan",
          //   subtitle: "Hablemos de lo que ronda por tu cabeza",
          //   color:  const Color(0xFFA5D6A7), // Verde claro
          //   textColor: Colors.black87,
          //   onTap: () {
          //     // Navegar al cuestionario
          //   },
          // ),

          // _buildOptionCard(
          //   context,
          //   imagePath: 'assets/imagenes/quetzal_5.png', // Corazón o emoción
          //   title: "Quiero saber cómo estoy emocionalmente",
          //   subtitle: "Un espacio para conocerte mejor",
          //   color: const Color(0xFFC8E6C9), // Verde muy claro
          //   textColor: Colors.black87,
          //   onTap: () {
          //     // Navegar al cuestionario
          //   },
          // ),

          // _buildOptionCard(
          //   context,
          //   imagePath: 'assets/imagenes/quetzal_6.png', // Quetzal cantando/feliz
          //   title: "Solo quiero hablar un poco",
          //   subtitle: "No tienes que saber qué responder",
          //   color: const Color(0xFFFFF3E0), // Naranja/Beige muy suave
          //   textColor: Colors.black87,
          //    onTap: () {
          //     // Navegar al cuestionario
          //   },
          // ),
          const SizedBox(height: 80), // Espacio para el BottomNav
        ],
      ),
    );
  }

  List<Widget> _homeCardsForRole(BuildContext context) {
    final cards = <Widget>[];

    if (_can('can_monitor_responses')) {
      cards.add(
        _buildOptionCard(
          context,
          imagePath: 'assets/imagenes/quetzal_4.png',
          title: "Monitorear respuestas",
          subtitle: "Revisa respuestas reales de padres y estudiantes",
          color: const Color(0xFF00897B),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MonitoreoAdmin()),
            );
          },
        ),
      );
    }

    if (_can('can_edit_questionnaires')) {
      cards.add(
        _buildOptionCard(
          context,
          imagePath: 'assets/imagenes/quetzal_6.png',
          title: "Editar cuestionarios",
          subtitle: "Ajusta preguntas y puntajes por módulo",
          color: const Color(0xFF7B1FA2),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditorCuestionariosAdmin(),
              ),
            );
          },
        ),
      );
    }

    if (_can('can_answer_questionnaires')) {
      cards.add(
        _buildOptionCard(
          context,
          imagePath: 'assets/imagenes/quetzal_4.png',
          title: _perfilTipo == 'padre'
              ? "Acompañamiento familiar"
              : "¿Pensamientos suicidas?",
          subtitle: _crisisSubtitle,
          color: const Color(0xFF66BB6A),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SelectorModuloCrisis(),
              ),
            ).then((_) => _loadCurrentUser());
          },
        ),
      );
    }

    if (_can('can_manage_linked_students')) {
      cards.add(
        _buildOptionCard(
          context,
          imagePath: 'assets/imagenes/quetzal_1.png',
          title: "Mis estudiantes",
          subtitle: "Consulta estudiantes vinculados desde Postgres",
          color: const Color(0xFFFB8C00),
          onTap: _showLinkedStudents,
        ),
      );
    }

    if (_can('can_play_tcg')) {
      cards.add(
        _buildOptionCard(
          context,
          imagePath: 'assets/imagenes/quetzal_8.png',
          title: "TCG Salud Mental",
          subtitle: "Usa tu conocimiento y enfrentate al Boss",
          color: const Color(0xFFA5D6A7),
          textColor: Colors.black87,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TcgFlameScreen()),
            );
          },
        ),
      );
    }

    if (cards.isEmpty) {
      cards.add(
        _buildOptionCard(
          context,
          imagePath: 'assets/imagenes/quetzal_3.png',
          title: "Sesión sin permisos",
          subtitle: "Vuelve a iniciar sesión para consultar tu rol actualizado",
          color: const Color(0xFF78909C),
          onTap: _loadCurrentUser,
        ),
      );
    }

    return cards;
  }

  Future<void> _showLinkedStudents() async {
    final result = await User().getEstudiantesVinculados();
    if (!mounted) return;

    final data = result['data'];
    final students = result['success'] == true && data is Map
        ? data['estudiantes_vinculados']
        : const [];
    final items = students is List ? students : const [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mis estudiantes'),
        content: SizedBox(
          width: double.maxFinite,
          child: items.isEmpty
              ? Text(
                  result['success'] == true
                      ? 'Todavía no hay estudiantes vinculados.'
                      : result['message']?.toString() ??
                            'No se pudieron consultar estudiantes.',
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final student = item is Map ? item : const {};
                    final name =
                        student['nombre_completo']?.toString() ??
                        student['nombre_usuario']?.toString() ??
                        'Estudiante';
                    return ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: Text(name),
                      subtitle: Text(
                        'ID ${student['id_usuario'] ?? '-'} · ${student['parentesco'] ?? 'vinculado'}',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
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
    final cardColor = isDarkMode ? color.withValues(alpha: 0.25) : color;
    final resolvedTitleColor = isDarkMode
        ? Colors.white
        : (textColor == Colors.white ? Colors.white : Colors.black87);
    final resolvedSubtitleColor = isDarkMode
        ? Colors.white70
        : (textColor == Colors.white
              ? Colors.white.withValues(alpha: 0.85)
              : Colors.black54);
    final resolvedArrowColor = isDarkMode
        ? Colors.white54
        : (textColor == Colors.white
              ? Colors.white.withValues(alpha: 0.7)
              : Colors.black38);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
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
    final isAdmin = _can('can_monitor_responses');
    final roleLabel = _perfilLabel.isEmpty
        ? _roleLabel(_perfilTipo)
        : _perfilLabel;

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
                    color: Colors.white.withValues(alpha: 0.3),
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
                Text(
                  'Hola, $_nombreUsuario',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '"$roleLabel"',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                if (_sessionError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _sessionError!,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
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
                if (isAdmin) ...[
                  Divider(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    height: 30,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'Administración',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.black45,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    icon: Icons.monitor_heart_outlined,
                    title: "Monitorear",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MonitoreoAdmin(),
                        ),
                      );
                    },
                    color: const Color(0xFF00897B),
                  ),
                ],
                Divider(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  height: 30,
                ),
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
                color: isDarkMode
                    ? const Color(0xFF2C2C2C)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFD32F2F),
                ),
                title: const Text(
                  "Cerrar Sesión",
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  await Auth().clearToken();
                  if (!context.mounted) return;
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
            color: color.withValues(alpha: 0.1),
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
          size: 20,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'administrador':
        return 'Administrador';
      case 'padre':
        return 'Padre/Madre';
      case 'estudiante':
        return 'Estudiante';
      default:
        return role.isEmpty ? 'Usuario' : role;
    }
  }

  Widget _buildBottomNav(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF121212)
            : Colors.white, // Neutro en dark
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              _buildNavBarItem(0, Icons.chat_bubble_outline, "Serena"),
              _buildNavBarItem(1, Icons.home_outlined, "Inicio"),
              // _buildNavBarItem(2, Icons.videogame_asset_outlined, "TCG"),
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
              ? primaryGreen.withValues(alpha: isDarkMode ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? primaryGreen
                  : (isDarkMode ? Colors.grey : Colors.grey[400]),
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
