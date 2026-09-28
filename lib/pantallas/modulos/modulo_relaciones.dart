import 'package:flutter/material.dart';
import 'package:aptm/text_utils.dart';
import '../cuestionarios/cuestionario_relaciones.dart';
import '../servicios/personalizacion.dart';
import '../servicios/user.dart';
import 'parent_triptych.dart';
import 'teen_info_carousel.dart';

class ModuloRelaciones extends StatefulWidget {
  const ModuloRelaciones({super.key});

  @override
  State<ModuloRelaciones> createState() => _ModuloRelacionesState();
}

class _ModuloRelacionesState extends State<ModuloRelaciones> {
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
    // ===========================================
    // INFORMACIÓN SEPARADA PARA PADRES Y JÓVENES
    // ===========================================
    final teenPalette = AppPersonalizacion.palette(_accentColor);
    final String heroTitle = _isForTeens //Titulo
      ? '¿Tienes relaciones sanas con las personas que te rodean?'
      : '¿Cómo reconocer relaciones sanas y señales de alerta en la vida de sus hijos?';

    final String heroDescription = _isForTeens //Contexto
      ? 'Escuchar, apoyar y poner límites saludables son parte de una relación sana. Tú también mereces respeto y buen trato.'
      : 'Las relaciones sanas se basan en el respeto, la comunicación y la confianza. Conocer las señales de riesgo puede ayudarle a brindar apoyo y orientación a sus hijos.';

    final String economicContent = _isForTeens //Abuso economico
      ? 'El abuso económico o financiero ocurre cuando alguien controla cómo ganas o gastas el dinero, o restringir tu acceso a bienes y/o servicios.'
      : 'El abuso económico o financiero ocurre cuando una persona controla, limita o manipula el acceso de otra a dinero, recursos, bienes o servicios. Es importante reconocer estas conductas para ayudar a los adolescentes a identificar relaciones poco saludables.';

    final String emotionalContent = _isForTeens //Abuso psicologico emocional
      ? 'El abuso psicológico o emocional ocurre cuando alguien usa palabras y acciones (sin llegar a la violencia física) para asustarte, herirte o controlarte.'
      : 'El abuso psicológico o emocional ocurre cuando alguien utiliza palabras, actitudes o comportamientos para humillar, intimidar, manipular o controlar a otra persona. Estas conductas pueden afectar significativamente el bienestar emocional de los adolescentes.';

    final String phisicalContent = _isForTeens  //Abuso físico
      ? 'El abuso físico ocurre cuando alguien te lastima o te lesiona a propósito.'
      : 'El abuso físico ocurre cuando una persona utiliza la fuerza para causar daño, dolor o lesiones a otra. Reconocer estas situaciones de manera temprana puede favorecer la búsqueda de apoyo y protección.';

    final String abuseContent = _isForTeens //Abuso sexual
      ? 'El abuso sexual ocurre cuando alguien te obliga a realizar actos sexuales sin tu consentimiento. \nPuede ser físico, psicológico o digital.'
      : 'El abuso sexual ocurre cuando una persona participa o intenta involucrar a otra en actividades de carácter sexual sin su consentimiento. Puede presentarse de forma física, psicológica o mediante medios digitales.';

    final String controlContent = _isForTeens //Control coercitivo
      ? 'El control coercitivo es un patrón de comportamiento utilizado para ganar poder y control sobre otra persona mediante la humillación, la degradación y el aislamiento.\n\nEsto suele comenzar de manera muy sutil, se acumula con el tiempo y a menudo se ve diferente en cada relación.'
      : 'El control coercitivo es un patrón de conductas destinadas a ejercer poder sobre otra persona mediante la vigilancia, el aislamiento, las amenazas, la manipulación o la restricción de su autonomía. Estas conductas suelen desarrollarse gradualmente y pueden ser difíciles de identificar al inicio.';

    final String digitalContent = _isForTeens //Abuso digital
      ? 'El abuso digital ocurre cuando alguien utiliza la tecnología para vigilarte, controlarte, amenazarte o acosarte.'
      : 'El abuso digital ocurre cuando una persona utiliza teléfonos, redes sociales, aplicaciones o dispositivos electrónicos para vigilar, controlar, amenazar o acosar a otra persona. Conocer estas prácticas puede ayudar a promover un uso más seguro de la tecnología.';

    final String stalkContent = _isForTeens   //Acoso
      ? 'El acoso ocurre cuando alguien se comporta repetidamente de una manera que te hace sentir incómodo(a) o asustado(a). \nEl acecho es más extremo; ocurre cuando están obsesionados o fijados contigo y se comportan regularmente de una manera que te hace sentir molesto(a) o amenazado(a).'
      : 'El acoso ocurre cuando una persona realiza conductas repetidas que generan incomodidad, miedo o preocupación en otra. El acecho implica una vigilancia persistente o una atención no deseada que puede hacer que la persona se sienta amenazada o insegura.';

    // ===========================================
    //  TARJETAS DE INFORMACIÓN PARA JÓVENES
    // ===========================================
    final List<TeenInfoCardData> teenCards = [
      TeenInfoCardData(
        title: 'Abuso económico',
        body: '',
        icon: Icons.attach_money,
        color: _accentColor,
        imagePath: 'assets/imagenes/relaciones/1-economico.png',
      ),
      TeenInfoCardData(
        title: 'Abuso psicológico emocional',
        body: '',
        icon: Icons.psychology,
        color: teenPalette[1],
        imagePath: 'assets/imagenes/relaciones/2-psicologico_emocional.png',
      ),
      TeenInfoCardData(
        title: 'Abuso físico',
        body: '',
        icon: Icons.front_hand,
        color: teenPalette[2],
        imagePath: 'assets/imagenes/relaciones/3-fisico.png',
      ),
      TeenInfoCardData(
        title: 'Abuso sexual',
        body: '',
        icon: Icons.security,
        color: Colors.deepOrange,
        imagePath: 'assets/imagenes/relaciones/4-sexual.png',
      ),
      TeenInfoCardData(
        title: 'Control coercitivo',
        body: '',
        icon: Icons.link_off,
        color: teenPalette[2],
        imagePath: 'assets/imagenes/relaciones/5-coercitivo.png',
      ),
      TeenInfoCardData(
        title: 'Abuso digital',
        body: '',
        icon: Icons.devices,
        color: teenPalette[4],
        imagePath: 'assets/imagenes/relaciones/6-digital.png',
      ),
      TeenInfoCardData(
        title: 'Acoso',
        body: '',
        icon: Icons.campaign,
        color: Colors.deepOrange,
        imagePath: 'assets/imagenes/relaciones/7-Acoso.png',
      ),
    ];

    // ===========================================
    //    TARJETAS DE INFORMACIÓN PARA PADRES
    // ===========================================
    final List<ParentTriptychPanel> parentPanels = [
      ParentTriptychPanel(
        title: 'Entender',
        subtitle: 'Cómo cambia el cerebro adolescente',
        body: '',
        icon: Icons.psychology_rounded,
        color: Colors.teal,
      ),
      ParentTriptychPanel(
        title: 'Abusos',
        subtitle: '¿Qué abusos existen?',
        body:
            '$economicContent\n\n$emotionalContent\n\n$phisicalContent\n\n$abuseContent\n\n$controlContent\n\n$digitalContent\n\n$stalkContent',
        icon: Icons.health_and_safety_rounded,
        color: Colors.deepOrange,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Uso de sustancias',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
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
                            Icons.diversity_2,
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
                      bottom: -30,
                      child: Image.asset(
                        'assets/imagenes/quetzal_11.png',
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
                TeenInfoCarousel(cards: teenCards, height: 420),
              ] else ...[
                ParentTriptych(panels: parentPanels, height: 520),
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
                        builder: (context) => const CuestionarioRelaciones(),
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

  Widget _buildWarningCard(String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74), width: 1.5),
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
              content,
              style: const TextStyle(
                fontSize: 14.5,
                color: Color(0xFF9A3412),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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