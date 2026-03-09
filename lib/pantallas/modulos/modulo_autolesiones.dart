import 'package:flutter/material.dart';
import 'package:aptm/text_utils.dart';
import '../cuestionarios/cuestionario_autolesion.dart';

class ModuloAutolesiones extends StatelessWidget {
  const ModuloAutolesiones({super.key});

  @override
  Widget build(BuildContext context) {
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
                      color: const Color(0xFF00897B).withOpacity(0.3),
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
                            child: const Text(
                              'A veces, el dolor emocional es tan fuerte que buscamos apagarlo. Aquí aprenderemos qué pasa y cómo pedir ayuda.',
                              style: TextStyle(
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
                        'assets/imagenes/quetzal_8.png', // Imagen del quetzal acompañando
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 38),

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
                title: '¿Qué es y qué NO es?',
                content: '• Es causar daño al propio cuerpo a propósito (rasguñarse, cortarse, golpearse).\n• NO es un intento de suicidio. Quien lo hace no busca morir, sino intentar apagar o calmar un malestar emocional que parece imposible de controlar.\n ⚠️ Aunque no se busque esto, si se vuelve costumbre sí aumenta el riesgo a futuro.',
                icon: Icons.info_outline_rounded,
                color: Colors.teal,
              ),

              _buildSection(
                title: '¿Por qué sucede?',
                content: 'Generalmente a las personas les resulta una forma (poco saludable) de:\n\n1. Bajarle el volumen a emociones intensas como ansiedad, enojo o culpa.\n2. Castigarse por sentirse insuficientes o culpables por algo.\n3. Sentir que tienen "control" sobre algo cuando todo lo de afuera es un caos.\n4. Expresar un grito de ayuda cuando las palabras fallan.',
                icon: Icons.psychology_alt_rounded,
                color: Colors.blue,
              ),

              _buildSection(
                title: 'Cosas que pueden influir (Riesgos)',
                content: '• Pasar por momentos largos de tristeza, estrés o depresión.\n• Haber pasado por bullying o sentirse muy solo/a y rechazado.\n• Traumas del pasado o muchos problemas en casa.\n • Sentir esto no te obliga a hacerlo, pero sí hace que necesites más apoyo emocional).',
                icon: Icons.report_problem_rounded,
                color: Colors.orange,
              ),

              _buildSection(
                title: 'Señales a las que prestar atención',
                content: 'Preocúpate o pide ayuda si notas:\n• Uso de suéteres/manga larga, incluso cuando hace mucho calor, para esconder marcas.\n• Te sientes frecuentemente "vacío/a" o desconectado/a.\n• Rasguños o cortes sin una explicación lógica y frecuente.',
                icon: Icons.search_rounded,
                color: Colors.purple,
              ),

              _buildSection(
                title: '¿Qué pasa si no se detiene?',
                content: '• El problema real no desaparece, solo se pone en "pausa" un rato y el dolor vuelve más fuerte.\n• Riesgo a causarse daños médicos mayores o cicatrices permanentes.\n• Con el tiempo, se siente como la única forma de aliviar el estrés. ¡Y eso te limita a aprender otras maneras más sanas!',
                icon: Icons.trending_down_rounded,
                color: Colors.redAccent,
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
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
                        children: const [
                          Text(
                            '¡No estás solo/a!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00897B),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Pedir ayuda es el acto más grande de valentía. Hablar con alguien de confianza puede cambiarlo todo.',
                            style: TextStyle(
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

  static Widget _buildSection({
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
            color: color.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
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
                    color: color.withOpacity(0.1),
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
                      color: color.withOpacity(0.9),
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
