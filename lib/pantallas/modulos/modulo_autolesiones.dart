import 'package:flutter/material.dart';

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
        title: const Text(
          'Autolesiones',
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.health_and_safety_outlined,
                      color: Colors.white,
                      size: 44,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Módulo de autolesión',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'La auto lesión no suicida (NSSI) es la conducta deliberada de causar daño directo al propio cuerpo sin la intención consciente de morir. Aquí encontrarás información breve y después el cuestionario con las preguntas que compartiste.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Información clave',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                icon: Icons.info_outline_rounded,
                title: 'Definición y manifestaciones',
                description:
                    'La NSSI puede incluir cortarse la piel, quemarse, golpearse, rascarse hasta sangrar o interferir con la cicatrización de heridas. Se asocia con dificultades para regular emociones intensas.',
                color: Colors.teal,
              ),
              _buildInfoCard(
                icon: Icons.compare_arrows_rounded,
                title: 'Diferencia con conducta suicida',
                description:
                    'La principal diferencia radica en la intención: en la auto lesión no existe un deseo explícito de morir, aunque puede coexistir con pensamientos suicidas y aumentar el riesgo futuro.',
                color: Colors.orange,
              ),
              _buildInfoCard(
                icon: Icons.psychology_alt_rounded,
                title: 'Funciones psicológicas',
                description:
                    'Puede funcionar como regulación emocional, autocastigo, sensación de control o una forma indirecta de comunicar sufrimiento cuando cuesta expresarlo con palabras.',
                color: Colors.blue,
              ),
              _buildInfoCard(
                icon: Icons.warning_amber_rounded,
                title: 'Factores de riesgo',
                description:
                    'Depresión, ansiedad, trauma, acoso escolar, conflictos familiares, consumo de sustancias y dificultades para manejar emociones intensas pueden aumentar el malestar emocional.',
                color: Colors.purple,
              ),
              const SizedBox(height: 28),
              const Text(
                'Preguntas del cuestionario',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                icon: Icons.content_cut_rounded,
                title: 'Pregunta 1',
                description:
                    '¿Alguna vez te has cortado la piel sin la intención de terminar con tu vida?',
                color: Colors.teal,
              ),
              _buildInfoCard(
                icon: Icons.history_toggle_off_rounded,
                title: 'Pregunta 2',
                description:
                    '¿Cuándo fue la primera vez que lo hiciste?',
                color: Colors.orange,
              ),
              _buildInfoCard(
                icon: Icons.repeat_rounded,
                title: 'Pregunta 3',
                description:
                    '¿Cuántas veces lo has hecho?',
                color: Colors.blue,
              ),
              _buildInfoCard(
                icon: Icons.language_rounded,
                title: 'Pregunta 4',
                description:
                    '¿Dónde aprendiste?',
                color: Colors.purple,
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Importante',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00897B),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'La auto lesión no es un intento de suicidio, pero sí es una señal de alerta que necesita atención. Pedir ayuda es un acto de valentía. Hablar con alguien de confianza y buscar apoyo psicológico puede marcar una diferencia importante.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Color(0xFF4B5563),
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
                    'Continuar al cuestionario de autolesión',
                    style: TextStyle(
                      fontSize: 13,
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

  static Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
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
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
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
