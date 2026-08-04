import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';
import 'login.dart';
import 'monitoreo_admin.dart';
import 'admin/editor_cuestionarios_admin.dart';
import 'juegos/tcg_flame_screen.dart';
import 'modulos/selector_modulo_crisis.dart';
import 'modulos/chatbot_serena.dart';
import 'modulos/ejercicio_respiracion.dart';
import 'acerca_de.dart';
import 'configuracion.dart';
import 'perfil.dart';
import 'servicios/auth.dart';
import 'servicios/personalizacion.dart';
import 'servicios/user.dart';

class Principal extends StatefulWidget {
  const Principal({super.key});

  @override
  State<Principal> createState() => _PrincipalState();
}

class _PrincipalState extends State<Principal>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 1;
  String _title = 'Inicio';
  String _nombreUsuario = 'Usuario';
  String _perfilTipo = '';
  String _perfilLabel = 'Usuario';
  Map<String, dynamic> _permissions = const {};
  Map<String, dynamic> _progress = const {};
  Map<String, dynamic> _studentPreferences = const {};
  bool _loadingSession = true;
  String? _sessionError;
  int _unreadAlerts = 0;
  String? _lastShownHighRiskAlertSignature;
  late final AnimationController _welcomeAnimationController;

  static const List<String> _studentDailyPhrases = [
    'Hoy no tienes que resolver toda tu vida; solo dar el siguiente paso.',
    'Aunque ahora no lo parezca, las cosas pueden mejorar más de lo que imaginas.',
    'Tu valor no depende de una calificación, una opinión o un error.',
    'Sobrevivir a los días difíciles también es una forma de ser fuerte.',
    'No tienes que ser perfecto para merecer cariño y respeto.',
    'Lo que hoy te duele no definirá quién serás mañana.',
    'Está bien avanzar despacio; seguir avanzando es lo importante.',
    'Hay personas que se alegran de que existas, incluso si hoy no lo notas.',
    'Un mal día no significa una mala vida.',
    'Cada vez que te levantas después de caer, te vuelves más fuerte.',
    'Tu historia aún tiene capítulos que valdrá la pena leer.',
    'No te compares con quien parece estar bien; todos libran batallas invisibles.',
    'A veces el progreso es simplemente no rendirse.',
    'No tienes que cargar con todo tú solo.',
    'La persona que serás en unos años te agradecerá que sigas aquí.',
    'Las tormentas más fuertes también terminan.',
    'Tu voz importa y tus sentimientos también.',
    'Equivocarte no te hace un fracaso; te hace humano.',
    'No eres el problema; eres una persona enfrentando problemas.',
    'Mereces darte la misma comprensión que das a los demás.',
    'A veces el acto más valiente es pedir ayuda.',
    'No todos entenderán tu camino, y está bien.',
    'Lo que hoy parece imposible puede convertirse en algo cotidiano.',
    'No necesitas demostrar tu valor; ya lo tienes.',
    'Tu futuro no está escrito por tus peores momentos.',
    'Respira. Ya has superado días que pensabas que no podrías soportar.',
    'Ser diferente no es un defecto; es una fortaleza.',
    'Nunca subestimes lo lejos que puedes llegar con pequeños esfuerzos diarios.',
    'Está bien descansar; no está mal necesitar una pausa.',
    'Las cicatrices cuentan historias de supervivencia.',
    'No todo tiene que salir bien para que algo bueno ocurra.',
    'Todavía hay personas, lugares y experiencias maravillosas esperando conocerte.',
    'No eres una carga por tener emociones.',
    'La esperanza también se construye poco a poco.',
    'A veces el primer paso es simplemente levantarse de la cama.',
    'Tú mereces oportunidades nuevas, sin importar tus errores pasados.',
    'No te castigues por estar aprendiendo.',
    'El mundo es mejor porque tú formas parte de él.',
    'No todas las batallas se ganan rápido.',
    'Lo que sientes hoy no será para siempre.',
    'Tu valor permanece incluso en los días en que no lo ves.',
    'Las personas más fuertes también lloran.',
    'No necesitas tener todas las respuestas ahora mismo.',
    'La vida cambia más rápido de lo que imaginamos.',
    'Cada nuevo día es una oportunidad para empezar otra vez.',
    'No eres menos importante porque alguien no supo valorarte.',
    'Los errores son lecciones, no condenas.',
    'Hay luz incluso cuando el cielo parece completamente gris.',
    'Tu esfuerzo cuenta, aunque nadie más lo vea.',
    'Nadie puede reemplazar la persona única que eres.',
    'No dejes que un momento difícil defina toda tu historia.',
    'A veces sanar significa darte tiempo.',
    'Tu presencia tiene más impacto del que imaginas.',
    'Los sueños grandes empiezan con pasos pequeños.',
    'No tienes que cargar el peso del mundo.',
  ];

  @override
  void initState() {
    super.initState();
    _welcomeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _welcomeAnimationController.dispose();
    super.dispose();
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
        _studentPreferences = const {};
        _unreadAlerts = 0;
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
        _studentPreferences = const {};
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
    final preferences = data['preferences'];
    final loadedPreferences = preferences is Map
        ? Map<String, dynamic>.from(preferences)
        : <String, dynamic>{};
    final idUsuario = userData is Map
        ? int.tryParse(userData['id_usuario']?.toString() ?? '')
        : null;
    if (perfilTipo == 'estudiante' && idUsuario != null) {
      final prefs = await SharedPreferences.getInstance();
      final localColor = prefs.getString('student_favorite_color_$idUsuario');
      final localAnimal = prefs.getString('student_favorite_animal_$idUsuario');
      if (!loadedPreferences.containsKey('colores_favoritos') &&
          localColor?.isNotEmpty == true) {
        loadedPreferences['colores_favoritos'] = [localColor!];
      }
      if (!loadedPreferences.containsKey('mascota') &&
          localAnimal?.isNotEmpty == true) {
        loadedPreferences['mascota'] = localAnimal!;
      }
    }

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
      _studentPreferences = perfilTipo == 'estudiante'
          ? loadedPreferences
          : const {};
      _loadingSession = false;
      _sessionError = null;
    });

    if (_can('can_manage_linked_students')) {
      _loadUnreadAlerts();
    }
  }

  Future<void> _loadUnreadAlerts() async {
    final result = await User().getAlertas();
    if (!mounted || result['success'] != true) return;

    final data = result['data'];
    if (data is! Map) return;

    final noLeidas = int.tryParse(data['no_leidas']?.toString() ?? '') ?? 0;
    setState(() {
      _unreadAlerts = noLeidas;
    });

    final alertas = data['alertas'];
    if (_perfilTipo == 'padre' && alertas is List) {
      _showHighRiskAlertNoticeIfNeeded(alertas);
    }
  }

  void _showHighRiskAlertNoticeIfNeeded(List<dynamic> alertas) {
    final highRiskAlerts = alertas
        .whereType<Map>()
        .where(
          (alerta) =>
              alerta['leida'] != true && alerta['tipo']?.toString() == 'riesgo_alto',
        )
        .toList();
    if (highRiskAlerts.isEmpty) return;

    final ids = highRiskAlerts
        .map((alerta) => alerta['id_alerta']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort();
    final signature = ids.join('|');
    if (signature.isEmpty || signature == _lastShownHighRiskAlertSignature) {
      return;
    }

    _lastShownHighRiskAlertSignature = signature;
    final nombres = highRiskAlerts
        .map(_studentNameFromAlert)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final nombresTexto = _joinNames(nombres);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _perfilTipo != 'padre') return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final isDarkMode =
              Provider.of<ThemeProvider>(dialogContext).isDarkMode;
          final alertColor = const Color(0xFFE53935);
          return AlertDialog(
            backgroundColor: isDarkMode
                ? const Color(0xFF2A1717)
                : const Color(0xFFFFF4F4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: alertColor.withValues(alpha: 0.55)),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: alertColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFE53935),
                    size: 52,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  nombresTexto.isEmpty
                      ? 'Alerta importante'
                      : 'Alerta de $nombresTexto',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : alertColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            content: Text(
              nombresTexto.isEmpty
                  ? 'Tienes alertas importantes sin revisar en tu bandeja.'
                  : 'Tienes alertas importantes sin revisar de $nombresTexto. '
                        'Revísalas en la bandeja de alertas para saber qué puedes hacer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : const Color(0xFF4A1E1E),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: alertColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Aceptar',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  String _studentNameFromAlert(Map<dynamic, dynamic> alerta) {
    final estudiante = alerta['estudiante'];
    if (estudiante is! Map) return 'tu hijo/a';
    final nombreCompleto = estudiante['nombre_completo']?.toString().trim();
    if (nombreCompleto?.isNotEmpty == true) return nombreCompleto!;
    final nombreUsuario = estudiante['nombre_usuario']?.toString().trim();
    if (nombreUsuario?.isNotEmpty == true) return nombreUsuario!;
    return 'tu hijo/a';
  }

  String _joinNames(List<String> nombres) {
    if (nombres.isEmpty) return '';
    if (nombres.length == 1) return nombres.first;
    if (nombres.length == 2) return '${nombres.first} y ${nombres.last}';
    return '${nombres.sublist(0, nombres.length - 1).join(', ')} y ${nombres.last}';
  }

  bool _can(String permission) => _permissions[permission] == true;

  bool get _isStudentProfile => _perfilTipo == 'estudiante';

  Color get _studentAccentColor {
    if (!_isStudentProfile) return AppPersonalizacion.defaultAccent;
    return AppPersonalizacion.accentFromPreferences(_studentPreferences);
  }

  String get _studentFavoriteAnimal {
    if (!_isStudentProfile) return 'Pájaro';
    final animal = _studentPreferences['mascota']?.toString().trim() ?? '';
    return animal.isNotEmpty ? animal : 'Pájaro';
  }

  String _animalEmoji(String value) {
    switch (value.trim().toLowerCase()) {
      case 'perro':
        return '🐶';
      case 'gato':
        return '🐱';
      case 'pájaro':
      case 'pajaro':
        return '🦜';
      case 'pez':
        return '🐠';
      case 'conejo':
        return '🐰';
      case 'hámster':
      case 'hamster':
        return '🐹';
      case 'no tengo/no me gustan':
        return '🌿';
      default:
        return '🐾';
    }
  }

  Widget _buildStudentAnimalAvatar({
    required double radius,
    required Color accentColor,
    String fallbackAsset = 'assets/imagenes/quetzal_1.png',
  }) {
    final animal = _studentFavoriteAnimal;
    final normalized = animal.trim().toLowerCase();
    if (normalized == 'pájaro' || normalized == 'pajaro') {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(radius * 0.14),
          child: Image.asset(fallbackAsset, fit: BoxFit.contain),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color.lerp(Colors.white, accentColor, 0.08),
      child: Text(
        _animalEmoji(animal),
        style: TextStyle(fontSize: radius * 1.05),
      ),
    );
  }

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
        return ChatbotSerena(
          accentColor: _isStudentProfile ? _studentAccentColor : null,
        );
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
          : (_isStudentProfile ? _studentAccentColor : const Color(0xFF2E7D32)),
      height: 1.2,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con el Quetzal grande
          _buildWelcomeHeader(headerStyle),

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
            ...[
              ..._homeCardsForRole(context),
              if (_showHomeDailyBanners) ...[
                const SizedBox(height: 8),
                _HomeDailyBannersSection(
                  perfilTipo: _perfilTipo,
                  isDarkMode: isDarkMode,
                  accentColor: _isStudentProfile
                      ? _studentAccentColor
                      : const Color(0xFF2E7D32),
                ),
              ],
            ],

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

  String get _dailyStudentPhrase {
    final today = DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final mixedSeed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return _studentDailyPhrases[mixedSeed % _studentDailyPhrases.length];
  }

  bool get _showHomeDailyBanners =>
      _perfilTipo == 'estudiante' || _perfilTipo == 'padre';

  Widget _buildWelcomeHeader(TextStyle headerStyle) {
    final isStudent = _perfilTipo == 'estudiante' || _perfilTipo.isEmpty;
    final message = isStudent
        ? _dailyStudentPhrase
        : 'Hola, estoy\naquí contigo.';

    return AnimatedBuilder(
      animation: _welcomeAnimationController,
      builder: (context, child) {
        final wave = math.sin(_welcomeAnimationController.value * math.pi * 2);
        final birdOffset = Offset(0, wave * 7);
        final textOffset = Offset(wave * 2, 0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Transform.translate(
                offset: textOffset,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    message,
                    key: ValueKey(message),
                    style: headerStyle.copyWith(
                      fontSize: isStudent ? 24 : headerStyle.fontSize,
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: birdOffset,
              child: Transform.rotate(
                angle: wave * 0.035,
                child: _isStudentProfile
                    ? Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          color: _studentAccentColor.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _studentAccentColor.withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _buildStudentAnimalAvatar(
                            radius: 49,
                            accentColor: _studentAccentColor,
                            fallbackAsset: 'assets/imagenes/quetzal_3.png',
                          ),
                        ),
                      )
                    : Image.asset(
                        'assets/imagenes/quetzal_3.png',
                        height: 140,
                        width: 140,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _homeCardsForRole(BuildContext context) {
    final cards = <Widget>[];
    final studentPalette = AppPersonalizacion.palette(_studentAccentColor);

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
          color: _isStudentProfile ? _studentAccentColor : const Color(0xFF66BB6A),
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
      cards.add(
        _buildOptionCard(
          context,
          imagePath: 'assets/imagenes/quetzal_3.png',
          title: "Bandeja de alertas",
          subtitle: "Notificaciones de tus hijos vinculados",
          color: const Color(0xFF42A5F5),
          badgeCount: _unreadAlerts,
          onTap: _showMailbox,
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
          color: _isStudentProfile
              ? AppPersonalizacion.lighten(studentPalette[0], 0.52)
              : const Color(0xFFA5D6A7),
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
                    final curp = student['curp']?.toString() ?? '';
                    final parentesco = student['parentesco']?.toString() ?? '';
                    return ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: Text(name),
                      subtitle: Text(
                        [
                          if (curp.isNotEmpty) curp,
                          if (parentesco.isNotEmpty) parentesco,
                        ].join(' · ') +
                            (curp.isEmpty && parentesco.isEmpty ? 'vinculado' : ''),
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

  Future<void> _showMailbox() async {
    final result = await User().getAlertas();
    if (!mounted) return;

    final data = result['data'];
    final alertas = result['success'] == true && data is Map
        ? data['alertas']
        : const [];
    final items = alertas is List ? alertas : const [];
    final localItems = items
        .map((item) => item is Map
            ? Map<String, dynamic>.from(item)
            : <String, dynamic>{})
        .toList();
    final noLeidas = int.tryParse(data is Map
            ? data['no_leidas']?.toString() ?? ''
            : '') ??
        localItems.where((item) => item['leida'] != true).length;
    if (_unreadAlerts != noLeidas) {
      setState(() {
        _unreadAlerts = noLeidas;
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                final isDarkMode =
                    Provider.of<ThemeProvider>(context).isDarkMode;
                return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(
                        Icons.inbox_rounded,
                        color: isDarkMode ? Colors.white : Colors.black87,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Bandeja de alertas',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Notificaciones de tus hijos vinculados',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white60 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  ),
                  if (localItems.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: isDarkMode
                                  ? Colors.white24
                                  : Colors.black26,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay alertas nuevas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.black45,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Las notificaciones de tus hijos\naparecerán aquí',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white38
                                    : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: localItems.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        ),
                        itemBuilder: (context, index) {
                          final alerta = localItems[index];
                          final estudiante = alerta['estudiante'] is Map
                              ? alerta['estudiante'] as Map
                              : null;
                          final nombreEstudiante =
                              estudiante?['nombre_completo']?.toString() ??
                              estudiante?['nombre_usuario']?.toString() ??
                              'Estudiante';
                          final tipo = alerta['tipo']?.toString() ?? '';
                          final mensaje =
                              alerta['mensaje']?.toString() ?? '';
                          final leida = alerta['leida'] == true;
                          final fechaRaw = alerta['fecha']?.toString() ?? '';
                          final fecha = fechaRaw.length >= 16
                              ? fechaRaw.substring(0, 16).replaceAll('T', ' ')
                              : fechaRaw;

                          IconData tipoIcon;
                          Color tipoColor;
                          switch (tipo) {
                            case 'cuestionario_completado':
                              tipoIcon = Icons.checklist_rounded;
                              tipoColor = const Color(0xFF43A047);
                              break;
                            case 'riesgo_alto':
                              tipoIcon = Icons.warning_amber_rounded;
                              tipoColor = const Color(0xFFE53935);
                              break;
                            case 'mensaje':
                              tipoIcon = Icons.chat_bubble_outline_rounded;
                              tipoColor = const Color(0xFF42A5F5);
                              break;
                            default:
                              tipoIcon = Icons.notifications_outlined;
                              tipoColor = const Color(0xFFFB8C00);
                          }

                          return ListTile(
                            onTap: () async {
                              final idAlerta =
                                  int.tryParse(
                                    alerta['id_alerta']?.toString() ?? '',
                                  ) ??
                                  0;
                              if (idAlerta > 0 && alerta['leida'] != true) {
                                await User().marcarAlertaVista(idAlerta);
                                if (mounted) {
                                  setSheetState(() {
                                    alerta['leida'] = true;
                                  });
                                  setState(() {
                                    _unreadAlerts = localItems
                                        .where((item) => item['leida'] != true)
                                        .length;
                                  });
                                }
                              }
                              if (!mounted) return;
                              _showAlertDetail(alerta);
                            },
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: tipoColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(tipoIcon, color: tipoColor, size: 22),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    nombreEstudiante,
                                    style: TextStyle(
                                      fontWeight: leida
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (!leida)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF43A047),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  mensaje,
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white60
                                        : Colors.black54,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (fecha.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    fecha,
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white38
                                          : Colors.black38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAlertDetail(Map<String, dynamic> alerta) {
    final estudiante = alerta['estudiante'] is Map
        ? alerta['estudiante'] as Map
        : null;
    final nombreEstudiante =
        estudiante?['nombre_completo']?.toString() ??
        estudiante?['nombre_usuario']?.toString() ??
        'Estudiante';
    final titulo = alerta['titulo']?.toString() ?? 'Alerta';
    final mensaje = alerta['mensaje']?.toString() ?? '';
    final recomendacion = alerta['recomendacion']?.toString() ?? '';
    final tipo = alerta['tipo']?.toString() ?? '';
    final isRisk = tipo == 'riesgo_alto';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nombreEstudiante,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(mensaje),
              if (recomendacion.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(
                      isRisk
                          ? Icons.warning_amber_rounded
                          : Icons.volunteer_activism_rounded,
                      color: isRisk
                          ? const Color(0xFFE53935)
                          : const Color(0xFF43A047),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Qué puedes hacer como padre/madre',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(recomendacion),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
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
    int badgeCount = 0,
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
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
        ),
        if (badgeCount > 0)
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final primaryGreen = _isStudentProfile
        ? _studentAccentColor
        : const Color(0xFF43A047);
    final drawerPalette = AppPersonalizacion.palette(primaryGreen);
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
                colors: _isStudentProfile
                    ? AppPersonalizacion.gradient(
                        primaryGreen,
                        dark: isDarkMode,
                      )
                    : (isDarkMode
                        ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                        : [
                            primaryGreen,
                            Color.lerp(primaryGreen, Colors.white, 0.28) ??
                                primaryGreen,
                          ]),
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
                  child: _isStudentProfile
                      ? _buildStudentAnimalAvatar(
                          radius: 35,
                          accentColor: primaryGreen,
                        )
                      : const CircleAvatar(
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
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Perfil()),
                    );
                  },
                  color: primaryGreen,
                ),
                _buildDrawerItem(
                  icon: Icons.settings_outlined,
                  title: "Configuración",
                  onTap: () async {
                    Navigator.pop(context);
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const Configuracion()),
                    );
                    if (changed == true && mounted) {
                      _loadCurrentUser();
                    }
                  },
                  color: _isStudentProfile ? drawerPalette[1] : Colors.orange,
                ),
                _buildDrawerItem(
                  icon: Icons.notifications_none_rounded,
                  title: "Notificaciones",
                  onTap: () {
                    Navigator.pop(context);
                    _showMailbox();
                  },
                  color: _isStudentProfile ? drawerPalette[2] : Colors.blue,
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
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AcercaDe()),
                    );
                  },
                  color: _isStudentProfile ? drawerPalette[4] : Colors.purple,
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
    final primaryGreen = _isStudentProfile
        ? _studentAccentColor
        : const Color(0xFF43A047);
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

class _HomeDailyBannersSection extends StatelessWidget {
  const _HomeDailyBannersSection({
    required this.perfilTipo,
    required this.isDarkMode,
    required this.accentColor,
  });

  final String perfilTipo;
  final bool isDarkMode;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final banners = _homeDailyBannersFor(perfilTipo);
    final title = perfilTipo == 'padre'
        ? 'Consejos para acompañar · hoy'
        : 'Mis consejos diarios · hoy';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: isDarkMode ? Colors.white70 : accentColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : const Color(0xFF102F1B),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 238,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: banners.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) => _HomeDailyBannerCard(
              banner: banners[index],
              isDarkMode: isDarkMode,
              accentColor: perfilTipo == 'estudiante' ? accentColor : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeDailyBannerCard extends StatelessWidget {
  const _HomeDailyBannerCard({
    required this.banner,
    required this.isDarkMode,
    this.accentColor,
  });

  final _HomeDailyBanner banner;
  final bool isDarkMode;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor == null
        ? banner.color
        : Color.lerp(banner.color, accentColor, banner.featured ? 0.45 : 0.28)!;
    final background = isDarkMode
        ? color.withValues(alpha: 0.20)
        : banner.featured
        ? color.withValues(alpha: 0.18)
        : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF102F1B);
    final mutedColor = isDarkMode ? Colors.white70 : const Color(0xFF4B6354);

    return SizedBox(
      width: banner.featured ? 224 : 206,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            if (banner.label == 'RESPIRA 1 MINUTO') {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const EjercicioRespiracion(),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${banner.title}: contenido próximamente.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: color.withValues(alpha: isDarkMode ? 0.30 : 0.22),
              ),
              boxShadow: isDarkMode
                  ? []
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: banner.featured
                        ? banner.color.withValues(alpha: 0.78)
                        : banner.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    banner.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: banner.featured ? Colors.white : color,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                Center(
                  child: Container(
                    height: 72,
                    width: 72,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(banner.icon, color: color, size: 42),
                  ),
                ),
                const Spacer(),
                Text(
                  banner.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: banner.featured ? 20 : 18,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: mutedColor, size: 16),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        banner.footer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mutedColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeDailyBanner {
  const _HomeDailyBanner({
    required this.label,
    required this.title,
    required this.footer,
    required this.icon,
    required this.color,
    this.featured = false,
  });

  final String label;
  final String title;
  final String footer;
  final IconData icon;
  final Color color;
  final bool featured;
}

List<_HomeDailyBanner> _homeDailyBannersFor(String perfilTipo) {
  final source = perfilTipo == 'padre'
      ? _homeParentDailyBanners
      : _homeStudentDailyBanners;
  final today = DateTime.now();
  final seed = today.year * 10000 + today.month * 100 + today.day;
  final start = source.isEmpty ? 0 : seed % source.length;
  final ordered = <_HomeDailyBanner>[];
  for (var index = 0; index < source.length; index++) {
    ordered.add(source[(start + index) % source.length]);
  }
  return ordered;
}

const List<_HomeDailyBanner> _homeStudentDailyBanners = [
  _HomeDailyBanner(
    label: 'CONSEJO DEL DÍA',
    title: 'Da un paso pequeño y suficiente.',
    footer: 'Tema diario',
    icon: Icons.local_florist_rounded,
    color: Color(0xFF43A047),
    featured: true,
  ),
  _HomeDailyBanner(
    label: 'RESPIRA 1 MINUTO',
    title: 'Inhala, sostén y exhala con calma.',
    footer: 'Ejercicio breve',
    icon: Icons.air_rounded,
    color: Color(0xFF2E7D32),
  ),
  _HomeDailyBanner(
    label: 'DATO DE BIENESTAR',
    title: 'Nombrar lo que sientes ayuda a entenderlo.',
    footer: 'Bienestar emocional',
    icon: Icons.psychology_alt_rounded,
    color: Color(0xFF00897B),
  ),
  _HomeDailyBanner(
    label: 'MOTIVACIÓN',
    title: 'Tu esfuerzo cuenta aunque nadie lo vea.',
    footer: 'Para hoy',
    icon: Icons.star_rounded,
    color: Color(0xFF5C6BC0),
  ),
  _HomeDailyBanner(
    label: 'HÁBITO SUAVE',
    title: 'Toma agua y descansa unos minutos.',
    footer: 'Autocuidado',
    icon: Icons.favorite_rounded,
    color: Color(0xFFFF7043),
  ),
];

const List<_HomeDailyBanner> _homeParentDailyBanners = [
  _HomeDailyBanner(
    label: 'PARA PADRES',
    title: 'Escuchar sin juzgar también acompaña.',
    footer: 'Consejo del día',
    icon: Icons.diversity_1_rounded,
    color: Color(0xFF43A047),
    featured: true,
  ),
  _HomeDailyBanner(
    label: 'PREGUNTA SUAVE',
    title: 'Pregunta cómo se siente, no solo qué hizo.',
    footer: 'Comunicación',
    icon: Icons.chat_bubble_outline_rounded,
    color: Color(0xFF1E88E5),
  ),
  _HomeDailyBanner(
    label: 'ACOMPAÑAMIENTO',
    title: 'Valida su emoción antes de dar consejos.',
    footer: 'Vínculo familiar',
    icon: Icons.volunteer_activism_rounded,
    color: Color(0xFF00897B),
  ),
  _HomeDailyBanner(
    label: 'SEÑALES',
    title: 'Observa cambios de sueño, ánimo o aislamiento.',
    footer: 'Cuidado atento',
    icon: Icons.visibility_outlined,
    color: Color(0xFFFF7043),
  ),
  _HomeDailyBanner(
    label: 'CALMA EN CASA',
    title: 'Una pausa tranquila puede abrir conversación.',
    footer: 'Bienestar familiar',
    icon: Icons.home_rounded,
    color: Color(0xFF7B1FA2),
  ),
];
