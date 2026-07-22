import 'package:flutter/material.dart';
import 'package:aptm/text_utils.dart';
import '../cuestionarios/cuestionarios_modulo1.dart';
import '../servicios/personalizacion.dart';
import '../servicios/user.dart';
import 'parent_triptych.dart';
import 'teen_info_carousel.dart';

class ModuloSuicidio extends StatefulWidget {
  const ModuloSuicidio({super.key});

  @override
  State<ModuloSuicidio> createState() => _ModuloSuicidioState();
}

class _ModuloSuicidioState extends State<ModuloSuicidio> {
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
    final heroAccent = _isForTeens ? _accentColor : Colors.redAccent;
    // Textos dinámicos basados en la selección
    final String bloque1Title = 'Bloque 1: Depresión (PHQ-9)';
    final String bloque1Content = _isForTeens
        ? 'Revisa señales recientes como:\n\n• Tristeza fuerte.\n• Pocas ganas de hacer cosas.\n• Cambios de sueño o apetito.\n• Cansancio.\n• Culpa o sentirte mal contigo.'
        : 'Explora señales recientes de depresión: tristeza, pérdida de interés, sueño o apetito alterado, cansancio y culpa.';

    final String bloque2Title = _isForTeens
        ? 'Bloque 2: Pensamientos sobre morir (C-SSRS)'
        : 'Bloque 2: Ideación (C-SSRS)';
    final String bloque2Content = _isForTeens
        ? 'Ayuda a ubicar pensamientos como:\n\n• Querer desaparecer.\n• Sentir que no quieres existir.\n• Pensar en hacerte daño.\n\nResponder con honestidad ayuda a pedir apoyo adecuado.'
        : 'Identifica el nivel de ideación: desde deseo de no existir hasta pensamientos con intención o plan.';

    final String factoresTitle = _isForTeens
        ? 'Comprendiendo lo que pasa en tu cuerpo y mente'
        : 'Comprendiendo los Factores Clínicos';

    final String devCerebralTitle = _isForTeens
        ? 'Desarrollo del cerebro'
        : 'Desarrollo Cerebral';
    final String devCerebralDesc = _isForTeens
        ? 'Tu cerebro aún está aprendiendo a decidir y frenar impulsos. Por eso algunas emociones pueden sentirse enormes.'
        : 'El córtex prefrontal aún está en desarrollo, lo que puede dificultar controlar impulsos durante crisis emocionales.';

    final String quimicaTitle = _isForTeens
        ? 'Química del cerebro'
        : 'Química del Cerebro';
    final String quimicaDesc = _isForTeens
        ? 'Sustancias como serotonina y dopamina influyen en tu ánimo. Si se desbalancean, el dolor emocional puede sentirse más fuerte.'
        : 'Cambios en neurotransmisores pueden intensificar el dolor emocional y alterar la percepción del problema.';

    final String estresTitle = _isForTeens
        ? 'Estrés y sobrecarga'
        : 'Estrés y Sobrecarga';
    final String estresDesc = _isForTeens
        ? 'Mucho estrés por mucho tiempo cansa al cuerpo y vuelve más difícil manejar lo que sientes.'
        : 'Estrés prolongado o trauma puede agotar la capacidad del cuerpo para regularse.';

    final String esperanzaMsg = _isForTeens
        ? 'No tienes que cargar esto solo.\n\nHabla con alguien de confianza o con un profesional. Pedir ayuda cuenta.'
        : 'La evaluación temprana orienta el apoyo. Escuchar, creer y actuar a tiempo puede marcar la diferencia.';

    final List<TeenInfoCardData> teenCards = [
      TeenInfoCardData(
        title: bloque1Title,
        body: '',
        icon: Icons.quiz_rounded,
        color: teenPalette[0],
        imagePath: 'assets/imagenes/suicidio/1-bloque_1.png',
      ),
      TeenInfoCardData(
        title: bloque2Title,
        body: '',
        icon: Icons.fact_check_rounded,
        color: Colors.deepOrange,
        imagePath: 'assets/imagenes/suicidio/2-bloque_2.png',
      ),
      TeenInfoCardData(
        title: devCerebralTitle,
        body: '',
        icon: Icons.psychology_rounded,
        color: teenPalette[1],
        imagePath: 'assets/imagenes/suicidio/3-desarrollo_cerebro.png',
      ),
      TeenInfoCardData(
        title: quimicaTitle,
        body: '',
        icon: Icons.science_rounded,
        color: teenPalette[2],
        imagePath: 'assets/imagenes/suicidio/4-quimica_cerebro.png',
      ),
      TeenInfoCardData(
        title: estresTitle,
        body: '',
        icon: Icons.monitor_heart_rounded,
        color: teenPalette[3],
        imagePath: 'assets/imagenes/suicidio/5-estrés.png',
      ),
      TeenInfoCardData(
        title: 'Hay ayuda disponible',
        body: '',
        icon: Icons.volunteer_activism_rounded,
        color: teenPalette[0],
        imagePath: 'assets/imagenes/suicidio/6-carga.png',
      ),
    ];

    final List<ParentTriptychPanel> parentPanels = [
      ParentTriptychPanel(
        title: 'Evaluar',
        subtitle: 'Qué revisa el cuestionario',
        body: '$bloque1Content\n\n$bloque2Content',
        icon: Icons.fact_check_rounded,
        color: Colors.indigo,
      ),
      ParentTriptychPanel(
        title: 'Factores',
        subtitle: 'Qué puede estar pasando en cuerpo y mente',
        body:
            '$devCerebralDesc\n\n$quimicaDesc\n\n$estresDesc',
        icon: Icons.psychology_rounded,
        color: Colors.purple,
      ),
      ParentTriptychPanel(
        title: 'Acompañar',
        subtitle: 'La evaluación temprana abre caminos de apoyo',
        body: esperanzaMsg,
        icon: Icons.volunteer_activism_rounded,
        color: Colors.teal,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Fondo suave y minimalista
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Riesgo de Suicidio',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección Hero rediseñada
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      child: Image.asset(
                        'assets/imagenes/imagen_riesgo_suicida.jpeg',
                        width: double.infinity,
                        fit: BoxFit
                            .contain, // Changed from cover to contain to prevent cropping
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: heroAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.medical_information_rounded,
                                  color: heroAccent,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Importancia de la Evaluación',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2D3748),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text.rich(
                            italicAcronyms(
                              'Esta sección integra la evaluación de depresión y riesgo (PHQ-9) junto con ideación suicida reciente (C-SSRS). El objetivo es detectar a tiempo el malestar emocional, los pensamientos de muerte y la posible planificación para orientar el apoyo necesario.',
                              const TextStyle(
                                fontSize: 15,
                                height: 1.6,
                                color: Color(0xFF4A5568),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              if (_isForTeens) ...[
                const Text(
                  'Información Clave',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 16),
                TeenInfoCarousel(cards: teenCards),
              ] else ...[
                const Text(
                  'Guía para familias',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 16),
                ParentTriptych(panels: parentPanels),
              ],

              const SizedBox(height: 40),

              // Botón Principal
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (_isForTeens
                              ? _accentColor
                              : const Color(0xFFE53935))
                          .withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Cuestionario(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.assignment_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    label: const Text(
                      'Comenzar evaluación ahora',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isForTeens
                          ? _accentColor
                          : const Color.fromARGB(255, 62, 53, 229),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Tarjeta de sección grande (Similar a autolesiones pero más limpia)
  Widget _buildSection({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text.rich(
                    italicAcronyms(
                      title,
                      TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color.withValues(alpha: 0.9),
                      ),
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
                color: Color(0xFF4A5568),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tarjeta pequeña para los factores clínicos
  Widget _buildModernCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A5568),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
