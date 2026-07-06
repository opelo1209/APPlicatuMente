import 'package:flutter/material.dart';
import 'package:aptm/text_utils.dart';
import '../cuestionarios/cuestionario_ansiedad.dart';
import '../servicios/user.dart';

class ModuloAnsiedad extends StatefulWidget {
  const ModuloAnsiedad({super.key});

  @override
  State<ModuloAnsiedad> createState() => _ModuloAnsiedadState();
}

class _ModuloAnsiedadState extends State<ModuloAnsiedad> {
  bool _isForTeens = true;

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
      }
    }
    if (!mounted) return;
    setState(() {
      _isForTeens = perfilTipo == 'estudiante';
    });
  }

  @override
  Widget build(BuildContext context) {
    final String heroTitle = _isForTeens
      ? '¿Me preocupa la\nAnsiedad?'
      : 'Ansiedad en jóvenes';
    final String heroDescription = _isForTeens
      ? 'La ansiedad puede sentirse en tus pensamientos, emociones, cuerpo y acciones. Aquí aprenderás cuándo es normal y cuándo conviene pedir ayuda.'
      : 'La ansiedad es común y tratable. Esta sección ayuda a reconocer señales, opciones de apoyo y cuándo buscar evaluación profesional.';

    final String introTitle = _isForTeens
      ? '¿Qué es la ansiedad?'
      : '¿Qué deben saber las familias?';
    final Widget introContent = _isForTeens
      ? Image.asset(
          'assets/imagenes/ansiedad/1-que_es.png',
          fit: BoxFit.contain,
        )
      : const Text(
          'La ansiedad es una reacción normal ante estrés, incertidumbre o sensación de amenaza. Puede manifestarse con preocupaciones frecuentes, nerviosismo, cambios físicos como sudoración o tensión muscular, y conductas de evitación.'
        );

    final String warningMsg = _isForTeens
      ? 'Puede convertirse en un problema cuando el miedo o la preocupación son muy intensos, duran varios meses o afectan tu escuela, amistades, familia o actividades diarias.'
      : 'Debe preocuparnos cuando la intensidad es desproporcionada, los síntomas persisten durante varios meses o impactan la escuela, la convivencia familiar, las relaciones sociales o el bienestar emocional.';

    final Widget typesContent = _isForTeens
      ? Image.asset(
        'assets/imagenes/ansiedad/2-tipos_de_trastornos.png',
        fit: BoxFit.contain,
      )
      : const Text(
        '• Ansiedad generalizada: preocupación excesiva sobre múltiples aspectos de la vida diaria.\n• Ansiedad social: miedo intenso a ser observado, evaluado o rechazado.\n• Trastorno de pánico: episodios repentinos de miedo intenso con síntomas físicos.\n• Agorafobia: temor a situaciones donde escapar o recibir ayuda podría ser difícil.\n• Fobias específicas: miedo intenso a objetos o situaciones concretas.'
      );

    final String diagnosisTitle = _isForTeens
      ? '¿Cómo se diagnostica?'
      : 'Evaluación profesional';
    final Widget diagnosisContent = _isForTeens
      ? Image.asset(
        'assets/imagenes/ansiedad/3-diagnostico.png',
        fit: BoxFit.contain,
      )
      : const Text(
        'La evaluación debe realizarla un profesional de la salud. Puede explorar síntomas, antecedentes y funcionamiento diario del joven, además de usar cuestionarios o evaluaciones médicas complementarias.'
      );
        
    final Widget treatmentContent = _isForTeens
      ? Image.asset(
        'assets/imagenes/ansiedad/4-tratamiento.png',
        fit: BoxFit.contain,
      )
      : const Text(
        'La evidencia indica que las intervenciones más efectivas suelen incluir psicoterapia, estrategias de autocuidado y manejo emocional, y medicación cuando está clínicamente indicada. En algunos casos, combinar terapia y medicación ofrece mejores resultados.'
      );

    final Widget therapyContent = _isForTeens
      ? Image.asset(
        'assets/imagenes/ansiedad/5-terapia.png',
        fit: BoxFit.contain,
      )
      : const Text(
        'La Terapia Cognitivo-Conductual (TCC) tiene amplio respaldo científico. Ayuda a los jóvenes a identificar patrones de pensamiento y conducta que mantienen la ansiedad, y a desarrollar herramientas para afrontarla de manera saludable.'
      );

    final String actionTitle = _isForTeens
      ? '¿Qué puedes hacer por tu cuenta?'
      : '¿Cómo apoyar desde casa?';

    final Widget actionContent = _isForTeens
      ? Image.asset(
        'assets/imagenes/ansiedad/6-actividades.png',
        fit: BoxFit.contain,
      )
      : const Text(
        '• Fomentar rutinas saludables.\n• Promover respiración y relajación.\n• Practicar mindfulness o atención plena.\n• Escuchar sin minimizar sus emociones.\n• Buscar apoyo profesional si los síntomas persisten o aumentan.'
      );
    
    final Widget medicationMsg = _isForTeens
      ? Image.asset(
        'assets/imagenes/ansiedad/7-medicamentos.png',
        fit: BoxFit.contain,
      )
      : const Text(
        'Algunos medicamentos pueden ayudar, pero suelen tardar entre 4 y 6 semanas en alcanzar su máximo beneficio. No deben suspenderse sin supervisión médica. En menores de 24 años se debe vigilar cualquier señal de alarma al iniciar ciertos tratamientos.'
      );
      
    final String footerTitle = _isForTeens
      ? 'Pedir ayuda cuenta'
      : 'Acompañar hace diferencia';
    
    final Widget footerMsg = _isForTeens
      ? Image.asset(
        'assets/imagenes/ansiedad/8-ayuda.png',
        fit: BoxFit.contain,
      )
      : const Text(
        'La detección temprana, el acompañamiento familiar y el acceso a apoyo profesional pueden mejorar significativamente la calidad de vida de adolescentes y jóvenes.'
      );
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00897B).withValues(alpha: 0.3),
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

              _buildSection(
                title: introTitle,
                content: introContent,
                icon: Icons.info_outline_rounded,
                color: Colors.teal,
              ),

              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED), // Fondo naranja muy suave
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFDBA74),
                    width: 1.5,
                  ), // Borde naranja pastel
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF97316),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        warningMsg,
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFF9A3412),
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _buildSection(
                title: 'Tipos de trastornos de ansiedad',
                content: typesContent,
                icon: Icons.category_rounded,
                color: Colors.blue,
              ),

              _buildSection(
                title: diagnosisTitle,
                content: diagnosisContent,
                icon: Icons.medical_information_rounded,
                color: Colors.indigo,
              ),

              _buildSection(
                title: '¿Cómo se trata?',
                content: treatmentContent,
                icon: Icons.health_and_safety_rounded,
                color: Colors.green,
              ),

              _buildSection(
                title: 'El papel de la terapia',
                content: therapyContent,
                icon: Icons.psychology_alt_rounded,
                color: Colors.purple,
              ),

              _buildSection(
                title: actionTitle,
                content: actionContent,
                icon: Icons.self_improvement_rounded,
                color: Colors.orange,
              ),

              _buildSection(
                title: 'Sobre los medicamentos',
                content: medicationMsg,
                icon: Icons.medication_rounded,
                color: Colors.deepOrange,
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.volunteer_activism_rounded,
                      color: Color(0xFF00897B),
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            footerTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00897B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          footerMsg,
                        ],
                      ),
                    ),
                  ],
                ),
              ),

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
                    backgroundColor: const Color(0xFF00897B),
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
