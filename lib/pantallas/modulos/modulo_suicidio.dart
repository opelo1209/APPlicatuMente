import 'package:flutter/material.dart';
import '../cuestionarios/cuestionarios_modulo1.dart';
class ModuloSuicidio extends StatefulWidget {
  const ModuloSuicidio({super.key});

  @override
  _ModuloSuicidioState createState() => _ModuloSuicidioState();
}

class _ModuloSuicidioState extends State<ModuloSuicidio> {
  @override
  Widget build(BuildContext context) {
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
              // Sección Hero con Imagen Principal
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: //imagn de archivo local
                    Image.asset(
                  'assets/imagenes/imagen_riesgo_suicida.jpeg',
                  height: 400,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),

              ),
              const SizedBox(height: 24),
              const Text(
                'Evaluación del módulo',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D3748),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Este apartado integra dos bloques de evaluación: depresión y riesgo (PHQ-9) e ideación suicida reciente (C-SSRS). La idea es detectar malestar emocional, pensamientos de muerte, intención y posible planificación, para orientar mejor el apoyo.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF4A5568),
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                '¿Qué preguntas incluye?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                icon: Icons.quiz_outlined,
                title: 'Bloque 1: Depresión y riesgo (PHQ-9)',
                description:
                    'Incluye preguntas sobre tristeza, irritabilidad, falta de interés, sueño, apetito, energía, culpa, concentración, inquietud, ideas de muerte, tristeza persistente e intentos previos.',
                color: Colors.indigo,
              ),
              _buildInfoCard(
                icon: Icons.fact_check_outlined,
                title: 'Bloque 2: Ideación suicida (C-SSRS)',
                description:
                    'Incluye preguntas sobre deseo de estar muerto, ideas de suicidio, cómo llevarlo a cabo, intención y elaboración de un plan reciente.',
                color: Colors.redAccent,
              ),

              const SizedBox(height: 32),

              // Sección de Señales de Alerta
              const Text(
                'Factores de Riesgo Clínico',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                icon: Icons.psychology_rounded,
                title: 'Desarrollo del Córtex',
                description:
                    'En la adolescencia, el córtex prefrontal (responsable del control de impulsos) aún madura, aumentando la vulnerabilidad a decisiones precipitadas.',
                color: Colors.purpleAccent,
              ),
              _buildInfoCard(
                icon: Icons.science_rounded,
                title: 'Desregulación Neuroquímica',
                description:
                    'Alteraciones en neurotransmisores como la serotonina y dopamina distorsionan la percepción de la realidad y amplifican el dolor emocional.',
                color: Colors.blueAccent,
              ),
              _buildInfoCard(
                icon: Icons.monitor_heart_rounded,
                title: 'Sobrecarga Alostática',
                description:
                    'El estrés crónico y el trauma alteran el eje HPA (hipotálamo-pituitaria-adrenal), agotando la capacidad de respuesta al estrés del organismo.',
                color: Colors.teal,
              ),

              const SizedBox(height: 32),

              // Segunda Imagen (Apoyo/Esperanza)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=800&q=80', // Imagen clínica/médica
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),

              // Sección de Acción
              const Text(
                'Intervención Basada en Evidencia',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 16),
              _buildActionStep(
                number: '1',
                title: 'Detectar síntomas emocionales',
                description:
                  'El primer bloque ayuda a identificar síntomas de depresión y riesgo emocional que pueden requerir atención temprana.',
              ),
              _buildActionStep(
                number: '2',
                title: 'Valorar ideación suicida reciente',
                description:
                  'El segundo bloque explora si existen pensamientos de muerte, intención o planificación, para distinguir niveles de urgencia.',
              ),
              _buildActionStep(
                number: '3',
                title: 'Orientar apoyo y seguimiento',
                description:
                  'La información obtenida permite sugerir acompañamiento, ayuda profesional y medidas de protección cuando sea necesario.',
              ),

              const SizedBox(height: 40),

              // Botón de Emergencia
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                   Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Cuestionario()),
        );
                  },
                  icon: const Icon(
                    Icons.touch_app,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Realiza el cuestionario ahora mismo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 35, 162, 33), // Rojo para urgencia
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
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
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF718096),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF3182CE),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
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
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF4A5568),
                    height: 1.4,
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
