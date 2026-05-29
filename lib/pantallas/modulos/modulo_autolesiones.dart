import 'package:flutter/material.dart';
import 'package:aptm/text_utils.dart';
import '../cuestionarios/cuestionario_autolesion.dart';
import '../servicios/user.dart';

class ModuloAutolesiones extends StatefulWidget {
  const ModuloAutolesiones({super.key});

  @override
  State<ModuloAutolesiones> createState() => _ModuloAutolesionesState();
}

class _ModuloAutolesionesState extends State<ModuloAutolesiones> {
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
    final String heroDescription = _isForTeens
        ? 'A veces, el dolor emocional es tan fuerte que buscamos apagarlo. Aquí aprenderemos qué pasa y cómo pedir ayuda.'
        : 'Comprender la autolesión no suicida (NSSI) es clave para brindar apoyo. Aquí aprenderá sus causas, factores de riesgo y cómo actuar.';

    final String qyaContent = _isForTeens
        ? '• Es lastimarse a propósito (cortarse, quemarse, rascarse), pero SIN querer morir.\n• NO es saludable ni normal, ocurre por emociones muy fuertes que no sabemos cómo manejar.'
        : '• Consiste en el daño deliberado del propio cuerpo (cortes, quemaduras, golpes) sin intención suicida.\n• Suele ser un mecanismo de afrontamiento disfuncional ante un desbordamiento emocional severo.';

    final String warningMsg = _isForTeens
        ? 'Aunque no es para morir, hacerlo mucho sí aumenta el riesgo de tener pensamientos o conductas mucho más peligrosas.'
        : 'Aunque el objetivo inicial no es terminar con la vida, la repetición de autolesiones incrementa significativamente el riesgo de conducta suicida futura.';

    final String pkTitle = _isForTeens
        ? '¿Por qué lo hacen?'
        : '¿Por qué sucede?';
    final String pkContent = _isForTeens
        ? 'Las personas pueden lastimarse por varias razones:\n\n1. Para calmar emociones fuertes (tristeza, enojo, ansiedad).\n2. Para castigarse por sentir mucha culpa o creer que hicieron algo mal.\n3. Para sentir "algo" o sentir control cuando se sienten muy vacíos.\n4. Para mostrar que están sufriendo cuando es difícil usar palabras.'
        : 'Principales funciones de la conducta:\n\n1. Regulación emocional: Aliviar tensión, ansiedad o angustia severa.\n2. Autocastigo: Asociado a sentimientos profundos de culpa o vergüenza.\n3. Anti-disociación: Sentir dolor físico para contrarrestar gran desconexión.\n4. Comunicación: Expresar de forma no verbal un sufrimiento profundo.';

    final String riskContent = _isForTeens
        ? 'Cosas que pueden hacer que pase:\n• Estar muy triste o con mucha ansiedad.\n• Problemas familiares o bullying.\n• Haber pasado por cosas muy difíciles o traumáticas.\n• Tomar alcohol o drogas.\n\nTener estos problemas no significa que alguien se lastimará.'
        : 'Factores de vulnerabilidad asociados:\n• Trastornos de estado de ánimo (depresión, ansiedad extrema).\n• Conflictos familiares, situaciones de bullying o acoso escolar.\n• Historial de trauma o abuso.\n• Consumo de sustancias.\n\nLa presencia de estos factores no determina la conducta, pero incrementa el riesgo.';

    final String actionTitle = _isForTeens
        ? '¿Qué más puedo hacer?'
        : '¿Cómo puedo ayudar?';
    final String actionContent = _isForTeens
        ? 'Sentirse triste o enojado es parte de la vida, pero hay formas sanas de manejarlo como:\n• Hablar con alguien de confianza o un psicólogo.\n• Escribir o dibujar lo que sientes.\n• Hacer ejercicio o escuchar música.\n\nPedir ayuda no es debilidad. Es de valientes.'
        : '• Mantenga la calma: Una reacción de pánico o reprensión puede empeorar la situación y generar asilamiento.\n• Escuche sin juzgar: Valide su malestar emocional sin justificar la conducta autolesiva.\n• Busque ayuda profesional: Requiere evaluación y acompañamiento clínico adecuado.';

    final String footerTitle = _isForTeens
        ? '¡No estás solo/a!'
        : 'El apoyo es fundamental';
    final String footerMsg = _isForTeens
        ? 'Pedir ayuda es el acto más grande de valentía. Hablar con alguien de confianza puede cambiarlo todo.'
        : 'Abordar el tema con empatía, contención y sin juicios de valor, es el primer paso vital para su recuperación.';

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

              _buildSection(
                title: '¿Qué es y qué no es?',
                content: qyaContent,
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
                          color: Color(0xFF9A3412), // Texto naranja oscuro
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _buildSection(
                title: pkTitle,
                content: pkContent,
                icon: Icons.psychology_alt_rounded,
                color: Colors.blue,
              ),

              _buildSection(
                title: 'Situaciones de riesgo',
                content: riskContent,
                icon: Icons.report_problem_rounded,
                color: Colors.orange,
              ),

              _buildSection(
                title: actionTitle,
                content: actionContent,
                icon: Icons.favorite_border_rounded,
                color: Colors.purple,
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
                          Text(
                            footerMsg,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Color(0xFF4B5563),
                            ),
                          ),
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
