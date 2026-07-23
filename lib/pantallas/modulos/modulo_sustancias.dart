import 'package:flutter/material.dart';
import '../servicios/personalizacion.dart';
import '../servicios/user.dart';
import 'parent_triptych.dart';
import 'teen_info_carousel.dart';

class ModuloSustancias extends StatefulWidget {
  const ModuloSustancias({super.key});

  @override
  State<ModuloSustancias> createState() => _ModuloSustanciasState();
}

class _ModuloSustanciasState extends State<ModuloSustancias> {
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
        ? '¿Cómo afectan las\ndrogas a tu cerebro?'
        : 'Sustancias y adolescencia';
    final String heroDescription = _isForTeens
        ? 'Tu cerebro sigue creciendo. Conocer cómo actúan las sustancias puede ayudarte a tomar decisiones informadas y cuidar tu futuro.'
        : 'Información para comprender cómo las sustancias afectan el desarrollo cerebral adolescente y cómo acompañar con prevención.';

    final String brainContent = _isForTeens
        ? 'Tu cerebro sigue construyéndose hasta aprox. los 25 años.\n\n• Aprende a decidir, controlar impulsos y manejar emociones.\n• Las drogas alteran la comunicación entre neuronas.\n• La dopamina puede dar placer al inicio, pero después el cerebro pide más para sentir lo mismo.'
        : 'Aunque un adolescente parezca maduro, su cerebro sigue desarrollando autocontrol, toma de decisiones y regulación emocional.\n\nLas sustancias modifican la comunicación neuronal y el sistema de recompensa. Con el tiempo pueden reducir el interés por actividades cotidianas y aumentar la necesidad de consumir.';

    final String brainAreasContent = _isForTeens
        ? 'Tres zonas clave:\n\n• Recompensa: deja de disfrutar cosas normales.\n• Amígdala: aumenta ansiedad, irritabilidad o estrés.\n• Corteza prefrontal: cuesta más frenar impulsos y medir riesgos.\n\nPor eso empezar en la adolescencia aumenta la vulnerabilidad.'
        : 'Áreas más afectadas:\n\n• Sistema de recompensa: puede desplazar actividades saludables.\n• Amígdala: favorece ansiedad, irritabilidad y malestar.\n• Corteza prefrontal: dificulta evaluar riesgos y resistir presión social.\n\nEl inicio temprano aumenta el riesgo de dependencia.';

    final String marijuanaContent = _isForTeens
        ? 'Contiene THC.\n\nPuede causar:\n• Problemas de memoria y concentración.\n• Cambios de percepción y del tiempo.\n• Menor coordinación.\n• Cambios de humor, paranoia o alucinaciones en dosis altas.\n\nEn adolescentes puede afectar aprendizaje y resolución de problemas.'
        : 'La marihuana contiene THC.\n\nRiesgos principales:\n• Concentración y memoria más débiles.\n• Alteraciones de percepción y coordinación.\n• Paranoia o episodios psicóticos en algunos casos.\n• Mayor riesgo si el consumo inicia temprano.\n\nUso médico supervisado no equivale a consumo recreativo seguro.';

    final String nicotineContent = _isForTeens
        ? 'La nicotina engancha rápido.\n\n• Está en cigarros y muchos vapeadores.\n• El efecto de placer dura poco.\n• Después puede aparecer ansiedad, irritabilidad o ganas fuertes de repetir.\n• Vapear también puede dañar pulmones y generar dependencia.'
        : 'La nicotina activa rápido el sistema de recompensa y favorece dependencia.\n\nSeñales comunes: ansiedad, irritabilidad, dificultad para concentrarse y deseo intenso de consumir.\n\nEl vapeo puede parecer menos riesgoso por sabores y diseño, pero también puede contener nicotina, THC u otras sustancias.';

    final String inhalantsContent = _isForTeens
        ? 'Son productos comunes: pegamentos, pinturas, aerosoles, gasolina o solventes.\n\nPueden provocar mareos, euforia, pérdida de equilibrio, dificultad para hablar o alucinaciones.\n\nRiesgo importante: pueden causar daño permanente o una emergencia grave incluso desde el primer consumo.'
        : 'Pegamentos, solventes, pinturas, aerosoles o gasolina pueden ser inhalantes.\n\nEfectos: mareos, euforia, mala coordinación, dificultad para hablar y alucinaciones.\n\nRiesgo alto: daño neurológico, hepático o renal, además de muerte súbita. Conviene supervisar almacenamiento y uso.';

    final String otherDrugsContent = _isForTeens
        ? 'Otras sustancias de alto riesgo:\n\n• Opioides: pueden causar dependencia y sobredosis.\n• Metanfetamina: afecta memoria, ánimo y conducta.\n• Cocaína: eleva riesgo de infarto y adicción.\n• Sintéticas: sus efectos son impredecibles.\n• Estimulantes sin receta: pueden dañar corazón y cerebro.'
        : 'Sustancias a vigilar:\n\n• Opioides: dependencia y sobredosis respiratoria.\n• Metanfetamina: daño cerebral y agresividad.\n• Cocaína: adicción, infartos y eventos cerebrovasculares.\n• K2, Spice y sales de baño: efectos impredecibles.\n• Estimulantes recetados sin indicación: riesgo cardiovascular y dependencia.';

    const String parentActionsContent =
        'Acciones útiles:\n\n• Hablar seguido, sin juicio.\n• Escuchar antes de corregir.\n• Conocer amistades y rutinas.\n• Poner límites claros.\n• Observar cambios de ánimo, escuela o relaciones.\n• Buscar ayuda profesional ante señales de consumo o malestar.';

    final String footerTitle = _isForTeens
        ? 'Lo más importante'
        : 'Prevenir también es acompañar';
    final String footerMsg = _isForTeens
        ? 'No se trata de asustarte: se trata de decidir con información.\n\nCuidar tu cerebro hoy protege tu memoria, emociones, relaciones y metas.'
        : 'La prevención funciona mejor con información clara, diálogo frecuente y acompañamiento emocional.\n\nUn ambiente seguro ayuda a que los adolescentes hablen, pidan apoyo y tomen decisiones más saludables.';

    final List<TeenInfoCardData> teenCards = [
      TeenInfoCardData(
        title: 'Tu cerebro en desarrollo',
        body: '',
        icon: Icons.auto_awesome_rounded,
        color: _accentColor,
        imagePath: 'assets/imagenes/sustancias/1-cerebro.png',
      ),
      TeenInfoCardData(
        title: 'Zonas que se afectan',
        body: brainAreasContent,
        icon: Icons.warning_amber_rounded,
        color: teenPalette[1],
        imagePath: 'assets/imagenes/sustancias/2-cerebro_zonas.png',
      ),
      TeenInfoCardData(
        title: 'Marihuana',
        body: '',
        icon: Icons.grass_rounded,
        color: teenPalette[2],
        imagePath: 'assets/imagenes/sustancias/3-marihuana.png',
      ),
      TeenInfoCardData(
        title: 'Nicotina y vapeo',
        body: '',
        icon: Icons.smoke_free_rounded,
        color: teenPalette[3],
        imagePath: 'assets/imagenes/sustancias/4-nicotina.png',
      ),
      TeenInfoCardData(
        title: 'Inhalantes',
        body: '',
        icon: Icons.science_rounded,
        color: Colors.deepOrange,
        imagePath: 'assets/imagenes/sustancias/5-inhalantes.png',
      ),
      TeenInfoCardData(
        title: 'Otras drogas',
        body: '',
        icon: Icons.medication_rounded,
        color: teenPalette[4],
        imagePath: 'assets/imagenes/sustancias/6-varios.png',
      ),
      TeenInfoCardData(
        title: footerTitle,
        body: '',
        icon: Icons.volunteer_activism_rounded,
        color: _accentColor,
        imagePath: 'assets/imagenes/sustancias/7-info.png',
      ),
    ];

    final List<ParentTriptychPanel> parentPanels = [
      ParentTriptychPanel(
        title: 'Entender',
        subtitle: 'Cómo cambia el cerebro adolescente',
        body: '$brainContent\n\n$brainAreasContent',
        icon: Icons.psychology_rounded,
        color: Colors.teal,
      ),
      ParentTriptychPanel(
        title: 'Riesgos',
        subtitle: 'Sustancias que conviene reconocer',
        body:
            '$marijuanaContent\n\n$nicotineContent\n\n$inhalantsContent\n\n$otherDrugsContent',
        icon: Icons.health_and_safety_rounded,
        color: Colors.deepOrange,
      ),
      ParentTriptychPanel(
        title: 'Acompañar',
        subtitle: 'Prevención desde casa',
        body: '$parentActionsContent\n\n$footerMsg',
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
                            Icons.psychology_rounded,
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
                        'assets/imagenes/quetzal_7.png',
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
