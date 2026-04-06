import 'package:flutter/material.dart';
import 'package:aptm/text_utils.dart';
import '../cuestionarios/cuestionarios_modulo1.dart';

class ModuloSuicidio extends StatefulWidget {
  const ModuloSuicidio({super.key});

  @override
  State<ModuloSuicidio> createState() => _ModuloSuicidioState();
}

class _ModuloSuicidioState extends State<ModuloSuicidio> {
  bool _isForTeens = true; // Empieza en modo para adolescentes por defecto

  @override
  Widget build(BuildContext context) {
    // Textos dinámicos basados en la selección
    final String bloque1Title = 'Bloque 1: Depresión (PHQ-9)';
    final String bloque1Content = _isForTeens 
      ? 'Este bloque sirve para ver si has tenido señales de depresión en las últimas semanas, como:\n\n• Sentirte muy triste o sin ganas de hacer cosas\n• Perder el interés en lo que antes te gustaba\n• Dormir mal o tener cambios en el apetito\n• Sentirte sin energía\n• Tener pensamientos de culpa o sentirte mal contigo mismo'
      : 'Identifica la presencia y severidad de síntomas depresivos como tristeza profunda, pérdida de interés, problemas de sueño o apetito, falta de energía y sentimientos de culpa durante las últimas semanas.';

    final String bloque2Title = _isForTeens ? 'Bloque 2: Pensamientos sobre morir (C-SSRS)' : 'Bloque 2: Ideación (C-SSRS)';
    final String bloque2Content = _isForTeens
      ? 'Ayuda a entender qué tan fuertes son los pensamientos sobre la muerte. Puede ir desde pensar que quisieras desaparecer o no existir, hasta tener ideas más claras de hacerte daño o incluso pensar en cómo hacerlo.'
      : 'Analiza, de forma escalonada, la severidad de pensamientos suicidas: desde el simple deseo de estar muerto, hasta la ideación activa con intención y planes estructurados.';

    final String factoresTitle = _isForTeens ? 'Comprendiendo lo que pasa en tu cuerpo y mente' : 'Comprendiendo los Factores Clínicos';

    final String devCerebralTitle = _isForTeens ? 'Desarrollo del cerebro' : 'Desarrollo Cerebral';
    final String devCerebralDesc = _isForTeens
      ? 'Durante la adolescencia, tu cerebro todavía se está formando. La parte que ayuda a tomar decisiones y controlar impulsos aún no está completamente desarrollada, por eso a veces las emociones pueden sentirse muy intensas o difíciles de controlar.'
      : 'En la adolescencia y juventud temprana, el córtex prefrontal aún está en desarrollo, lo que puede limitar el control de impulsos frente al desbordamiento emocional.';

    final String quimicaTitle = _isForTeens ? 'Química del cerebro' : 'Química del Cerebro';
    final String quimicaDesc = _isForTeens
      ? 'En el cerebro hay sustancias (como serotonina y dopamina) que influyen en cómo te sientes. Cuando hay un desbalance, las emociones pueden sentirse mucho más fuertes, especialmente el dolor emocional.'
      : 'Desequilibrios en neurotransmisores (como serotonina y dopamina) alteran la percepción y hacen que el dolor emocional se experimente de forma mucho más intensa.';

    final String estresTitle = _isForTeens ? 'Estrés y sobrecarga' : 'Estrés y Sobrecarga';
    final String estresDesc = _isForTeens
      ? 'Cuando pasas por mucho estrés o situaciones difíciles por mucho tiempo, tu cuerpo se cansa y le cuesta más trabajo manejar lo que sientes.'
      : 'Situaciones prolongadas de estrés o traumas agotan la capacidad natural del cuerpo (Eje HPA) para regularse y manejar la adversidad.';

    final String esperanzaMsg = _isForTeens
      ? 'No tienes que pasar por esto solo.\nHablar con alguien de confianza, como un familiar, amigo o profesional, puede ayudarte a sentirte mejor. Ser honesto sobre lo que sientes es un paso importante para encontrar apoyo.'
      : 'La evaluación temprana salva vidas. Responder con honestidad ayuda a encontrar el mejor camino hacia el bienestar de sus seres queridos.';

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
                      color: Colors.black.withOpacity(0.06),
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
                        fit: BoxFit.contain, // Changed from cover to contain to prevent cropping
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
                                  color: Colors.redAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.medical_information_rounded,
                                  color: Colors.redAccent,
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

              // Toggle Adolescentes / Padres
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isForTeens = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isForTeens ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _isForTeens
                                ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              'Para ti (Adolescente)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isForTeens ? Colors.indigo : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isForTeens = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isForTeens ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !_isForTeens
                                ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              'Para padres',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !_isForTeens ? Colors.deepOrange : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'Estructura del Cuestionario',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: bloque1Title,
                content: bloque1Content,
                icon: Icons.quiz_rounded,
                color: Colors.indigo,
              ),
              _buildSection(
                title: bloque2Title,
                content: bloque2Content,
                icon: Icons.fact_check_rounded,
                color: Colors.deepOrange,
              ),

              const SizedBox(height: 32),

              Text(
                factoresTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 16),
              
              _buildModernCard(
                title: devCerebralTitle,
                description: devCerebralDesc,
                icon: Icons.psychology_rounded,
                color: Colors.purple,
              ),
              _buildModernCard(
                title: quimicaTitle,
                description: quimicaDesc,
                icon: Icons.science_rounded,
                color: Colors.blueAccent,
              ),
              _buildModernCard(
                title: estresTitle,
                description: estresDesc,
                icon: Icons.monitor_heart_rounded,
                color: Colors.teal,
              ),

              const SizedBox(height: 32),

              // Mensaje de Esperanza
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.indigo.shade100, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.volunteer_activism_rounded, color: Colors.indigo, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hay ayuda disponible',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            esperanzaMsg,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Color(0xFF4A5568),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Botón Principal
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE53935).withOpacity(0.3),
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
                        MaterialPageRoute(builder: (context) => const Cuestionario()),
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
                      backgroundColor: const Color.fromARGB(255, 62, 53, 229), // Rojo intenso para la acción
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
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
                    color: color.withOpacity(0.1),
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
                        color: color.withOpacity(0.9),
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
            color: color.withOpacity(0.06),
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
              color: color.withOpacity(0.1),
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
