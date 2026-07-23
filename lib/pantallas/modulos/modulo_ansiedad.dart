import 'package:flutter/material.dart';
import 'package:aptm/text_utils.dart';
import '../cuestionarios/cuestionario_ansiedad.dart';
import '../servicios/personalizacion.dart';
import '../servicios/user.dart';
import 'parent_triptych.dart';
import 'teen_info_carousel.dart';

class ModuloAnsiedad extends StatefulWidget {
  const ModuloAnsiedad({super.key});

  @override
  State<ModuloAnsiedad> createState() => _ModuloAnsiedadState();
}

class _ModuloAnsiedadState extends State<ModuloAnsiedad> {
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
    final String heroTitle = _isForTeens
      ? '¿Me preocupa la\nAnsiedad?'
      : 'Ansiedad en jóvenes';
    final String heroDescription = _isForTeens
      ? 'La ansiedad puede sentirse en tus pensamientos, emociones, cuerpo y acciones. Aquí aprenderás cuándo es normal y cuándo conviene pedir ayuda.'
      : 'La ansiedad es común y tratable. Esta sección ayuda a reconocer señales, opciones de apoyo y cuándo buscar evaluación profesional.';

    final String introTitle = _isForTeens
      ? '¿Qué es la ansiedad?'
      : '¿Qué deben saber las familias?';
    const String parentIntroContent =
      'La ansiedad puede ser normal, pero preocupa cuando domina la vida diaria.\n\nSe puede notar en:\n• Preocupación frecuente.\n• Nerviosismo o tensión.\n• Evitación.\n• Cambios físicos como sudoración o tensión muscular.';

    final String warningMsg = _isForTeens
      ? 'Pide apoyo si el miedo es muy intenso, dura mucho o afecta escuela, amistades, familia o actividades.'
      : 'Atención si los síntomas persisten, son muy intensos o afectan escuela, familia, amistades o bienestar.';

    const String parentTypesContent =
      'Tipos frecuentes:\n\n• Generalizada: preocupación excesiva.\n• Social: miedo a juicio o rechazo.\n• Pánico: miedo intenso repentino.\n• Fobias: miedo fuerte a algo específico.';

    final String diagnosisTitle = _isForTeens
      ? '¿Cómo se diagnostica?'
      : 'Evaluación profesional';
    const String parentDiagnosisContent =
      'La evaluación debe hacerla un profesional. Revisa síntomas, antecedentes, funcionamiento diario y puede usar cuestionarios.';
        
    const String parentTreatmentContent =
      'El tratamiento suele combinar psicoterapia, autocuidado, manejo emocional y medicación cuando está indicada.';

    const String parentTherapyContent =
      'La TCC ayuda a identificar pensamientos y conductas que mantienen la ansiedad, y enseña herramientas para afrontarla.';

    final String actionTitle = _isForTeens
      ? '¿Qué puedes hacer por tu cuenta?'
      : '¿Cómo apoyar desde casa?';

    const String parentActionContent =
      '• Fomentar rutinas saludables.\n• Promover respiración y relajación.\n• Practicar mindfulness o atención plena.\n• Escuchar sin minimizar sus emociones.\n• Buscar apoyo profesional si los síntomas persisten o aumentan.';
    
    const String parentMedicationMsg =
      'Los medicamentos pueden ayudar, pero requieren seguimiento médico. No deben iniciarse ni suspenderse sin supervisión.';
      
    final String footerTitle = _isForTeens
      ? 'Pedir ayuda cuenta'
      : 'Acompañar hace diferencia';
    
    const String parentFooterMsg =
      'Detectar temprano, acompañar y buscar apoyo profesional mejora el pronóstico.';

    final List<TeenInfoCardData> teenCards = [
      TeenInfoCardData(
        title: introTitle,
        body: '',
        icon: Icons.info_outline_rounded,
        color: teenPalette[0],
        imagePath: 'assets/imagenes/ansiedad/1-que_es.png',
      ),
      TeenInfoCardData(
        title: 'Señal para pedir apoyo',
        body: '',
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
        imagePath: 'assets/imagenes/ansiedad/2-advertencia.png',
      ),
      TeenInfoCardData(
        title: 'Tipos de ansiedad',
        body: '',
        icon: Icons.category_rounded,
        color: teenPalette[1],
        imagePath: 'assets/imagenes/ansiedad/3-tipos_de_trastornos.png',
      ),
      TeenInfoCardData(
        title: diagnosisTitle,
        body: '',
        icon: Icons.medical_information_rounded,
        color: teenPalette[2],
        imagePath: 'assets/imagenes/ansiedad/4-diagnostico.png',
      ),
      TeenInfoCardData(
        title: '¿Cómo se trata?',
        body: '',
        icon: Icons.health_and_safety_rounded,
        color: teenPalette[3],
        imagePath: 'assets/imagenes/ansiedad/5-tratamiento.png',
      ),
      TeenInfoCardData(
        title: 'El papel de la terapia',
        body: '',
        icon: Icons.psychology_alt_rounded,
        color: teenPalette[4],
        imagePath: 'assets/imagenes/ansiedad/6-terapia.png',
      ),
      TeenInfoCardData(
        title: actionTitle,
        body: '',
        icon: Icons.self_improvement_rounded,
        color: teenPalette[1],
        imagePath: 'assets/imagenes/ansiedad/7-actividades.png',
      ),
      TeenInfoCardData(
        title: 'Sobre los medicamentos',
        body: '',
        icon: Icons.medication_rounded,
        color: Colors.deepOrange,
        imagePath: 'assets/imagenes/ansiedad/8-medicamentos.png',
      ),
      TeenInfoCardData(
        title: footerTitle,
        body: '',
        icon: Icons.volunteer_activism_rounded,
        color: teenPalette[0],
        imagePath: 'assets/imagenes/ansiedad/9-ayuda.png',
      ),
    ];

    final List<ParentTriptychPanel> parentPanels = [
      ParentTriptychPanel(
        title: 'Entender',
        subtitle: 'Reconocer cuándo la ansiedad pesa demasiado',
        body: '$parentIntroContent\n\n$warningMsg\n\n$parentTypesContent',
        icon: Icons.info_outline_rounded,
        color: Colors.teal,
      ),
      ParentTriptychPanel(
        title: 'Tratamiento',
        subtitle: 'Evaluación, terapia y medicamentos',
        body:
            '$parentDiagnosisContent\n\n$parentTreatmentContent\n\n$parentTherapyContent\n\n$parentMedicationMsg',
        icon: Icons.health_and_safety_rounded,
        color: Colors.indigo,
      ),
      ParentTriptychPanel(
        title: 'Acompañar',
        subtitle: 'Apoyo cotidiano desde casa',
        body: '$parentActionContent\n\n$parentFooterMsg',
        icon: Icons.family_restroom_rounded,
        color: Colors.orange,
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
            'Ansiedad (GAD7)',
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
                          const SizedBox(height: 12),
                          Text(
                            heroTitle,
                            style: const TextStyle(
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
                TeenInfoCarousel(cards: teenCards, height: 430),
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
                        builder: (context) => const CuestionarioAnsiedad(),
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

  Widget buildContentText(String text) {
    return Text.rich(
      italicAcronyms(
        text,
        const TextStyle(
          fontSize: 14,
          color: Color(0xFF374151),
          height: 1.6,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget content,
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
                  child: Text.rich(
                    italicAcronyms(
                      title,
                      TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: color.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            content,
          ],
        ),
      ),
    );
  }
}
