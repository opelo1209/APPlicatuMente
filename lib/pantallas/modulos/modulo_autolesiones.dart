import 'package:flutter/material.dart';
import 'package:aptm/text_utils.dart';
import '../cuestionarios/cuestionario_autolesion.dart';
import '../servicios/personalizacion.dart';
import '../servicios/user.dart';
import 'parent_triptych.dart';
import 'teen_info_carousel.dart';

class ModuloAutolesiones extends StatefulWidget {
  const ModuloAutolesiones({super.key});

  @override
  State<ModuloAutolesiones> createState() => _ModuloAutolesionesState();
}

class _ModuloAutolesionesState extends State<ModuloAutolesiones> {
  bool _isForTeens = true;
  Color _accentColor = AppPersonalizacion.defaultAccent;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await User().getSessionContext();
    String perfilTipo = 'estudiante';
    if (result['success'] == true) {
      final data = result['data'];
      if (data is Map) {
        perfilTipo = data['perfil_tipo']?.toString() ?? perfilTipo;
        final preferences = data['preferences'];
        if (perfilTipo == 'estudiante' && preferences is Map) {
          _accentColor = AppPersonalizacion.accentFromPreferences(
            Map<String, dynamic>.from(preferences),
          );
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _isForTeens = perfilTipo == 'estudiante';
    });
  }

  @override
  Widget build(BuildContext context) {
    final teenPalette = AppPersonalizacion.palette(_accentColor);
    final String heroDescription = _isForTeens
        ? 'A veces, el dolor emocional es tan fuerte que buscamos apagarlo. Aquí aprenderemos qué pasa y cómo pedir ayuda.'
        : 'Comprender la autolesión no suicida (NSSI) es clave para brindar apoyo. Aquí aprenderá sus causas, factores de riesgo y cómo actuar.';

    final String qyaContent = _isForTeens
        ? '• Es hacerse daño a propósito, sin querer morir.\n• Suele aparecer cuando las emociones se sienten demasiado intensas.\n• No es una forma segura de manejar el dolor.'
        : '• Daño deliberado del cuerpo sin intención suicida.\n• Suele funcionar como intento de regular emociones intensas.\n• Requiere escucha, contención y evaluación profesional.';

    final String warningMsg = _isForTeens
        ? 'Aunque no es para morir, hacerlo mucho sí aumenta el riesgo de tener pensamientos o conductas mucho más peligrosas.'
        : 'Aunque el objetivo inicial no es terminar con la vida, la repetición de autolesiones incrementa significativamente el riesgo de conducta suicida futura.';

    final String pkTitle = _isForTeens
        ? '¿Por qué lo hacen?'
        : '¿Por qué sucede?';
    final String pkContent = _isForTeens
        ? 'Puede pasar por:\n\n• Calmar tristeza, enojo o ansiedad.\n• Castigarse por culpa o vergüenza.\n• Sentir control cuando hay vacío.\n• Mostrar dolor cuando faltan palabras.'
        : 'Funciones frecuentes:\n\n• Regular angustia o tensión.\n• Expresar culpa o vergüenza.\n• Contrarrestar desconexión emocional.\n• Comunicar sufrimiento sin palabras.';

    final String riskContent = _isForTeens
        ? 'Puede aumentar con:\n\n• Tristeza o ansiedad intensa.\n• Bullying o conflictos familiares.\n• Experiencias traumáticas.\n• Alcohol o drogas.\n\nNada de esto define a una persona; solo indica que necesita apoyo.'
        : 'Factores a observar:\n\n• Depresión o ansiedad intensa.\n• Bullying, acoso o conflicto familiar.\n• Trauma o abuso.\n• Consumo de sustancias.\n\nNo determinan la conducta, pero aumentan vulnerabilidad.';

    final String actionTitle = _isForTeens
        ? '¿Qué más puedo hacer?'
        : '¿Cómo puedo ayudar?';
    final String actionContent = _isForTeens
        ? 'Prueba algo más seguro:\n\n• Habla con alguien de confianza.\n• Escribe o dibuja lo que sientes.\n• Muévete, respira o escucha música.\n• Pide ayuda profesional si vuelve a pasar.'
        : 'Cómo responder:\n\n• Mantener la calma.\n• Escuchar sin regaños ni juicio.\n• Validar el dolor sin justificar la lesión.\n• Buscar apoyo profesional.';

    final String footerTitle = _isForTeens
        ? '¡No estás solo/a!'
        : 'El apoyo es fundamental';
    final String footerMsg = _isForTeens
        ? 'Pedir ayuda es el acto más grande de valentía. Hablar con alguien de confianza puede cambiarlo todo.'
        : 'Abordar el tema con empatía, contención y sin juicios de valor, es el primer paso vital para su recuperación.';

    final List<TeenInfoCardData> teenCards = [
      TeenInfoCardData(
        title: '¿Qué es y qué no es?',
        body: '',
        icon: Icons.info_outline_rounded,
        color: teenPalette[0],
        imagePath: 'assets/imagenes/autolesiones/1-que_es.png',
      ),
      TeenInfoCardData(
        title: 'Dato importante',
        body: '',
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
        imagePath: 'assets/imagenes/autolesiones/2-advertencia.png',
      ),
      TeenInfoCardData(
        title: pkTitle,
        body: '',
        icon: Icons.psychology_alt_rounded,
        color: teenPalette[1],
        imagePath: 'assets/imagenes/autolesiones/3-por_que.png',
      ),
      TeenInfoCardData(
        title: 'Situaciones de riesgo',
        body: '',
        icon: Icons.report_problem_rounded,
        color: Colors.deepOrange,
        imagePath: 'assets/imagenes/autolesiones/4-situaciones_de_riesgo.png',
      ),
      TeenInfoCardData(
        title: actionTitle,
        body: '',
        icon: Icons.favorite_border_rounded,
        color: teenPalette[4],
        imagePath: 'assets/imagenes/autolesiones/5-que_hacer.png',
      ),
      TeenInfoCardData(
        title: footerTitle,
        body: '',
        icon: Icons.volunteer_activism_rounded,
        color: teenPalette[0],
        imagePath: 'assets/imagenes/autolesiones/6-ayuda.png',
      ),
    ];

    final List<ParentTriptychPanel> parentPanels = [
      ParentTriptychPanel(
        title: 'Entender',
        subtitle: 'Qué es la autolesión no suicida',
        body: '$qyaContent\n\n$warningMsg',
        icon: Icons.info_outline_rounded,
        color: Colors.teal,
      ),
      ParentTriptychPanel(
        title: 'Riesgos',
        subtitle: 'Por qué sucede y qué la vuelve más probable',
        body: '$pkContent\n\n$riskContent',
        icon: Icons.psychology_alt_rounded,
        color: Colors.deepOrange,
      ),
      ParentTriptychPanel(
        title: 'Acompañar',
        subtitle: 'Cómo responder desde casa',
        body: '$actionContent\n\n$footerMsg',
        icon: Icons.family_restroom_rounded,
        color: Colors.indigo,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text.rich(
          italicAcronyms(
            'Autolesiones (NSSI)',
            const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Principal con el Quetzal
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isForTeens
                        ? AppPersonalizacion.gradient(_accentColor)
                        : const [Color(0xFF00897B), Color(0xFF26A69A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: (_isForTeens
                              ? _accentColor
                              : const Color(0xFF00897B))
                          .withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.healing_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Entendiendo las\nAutolesiones',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.55,
                            child: Text(
                              heroDescription,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: -10,
                      bottom: -15,
                      child: Image.asset(
                        'assets/imagenes/quetzal_8.png',
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'Información Clave',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),

              if (_isForTeens) ...[
                TeenInfoCarousel(cards: teenCards),
              ] else ...[
                ParentTriptych(panels: parentPanels),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CuestionarioAutolesion(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.touch_app, color: Colors.white),
                  label: const Text(
                    'Entendido, empezar cuestionario',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isForTeens ? _accentColor : const Color(0xFF00897B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: color.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
