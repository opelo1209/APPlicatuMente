import 'package:flutter/material.dart';

import '../servicios/user.dart';

class ModuloAnsiedad extends StatefulWidget {
  const ModuloAnsiedad({super.key});

  @override
  State<ModuloAnsiedad> createState() => _ModuloAnsiedadState();
}

class _ModuloAnsiedadState extends State<ModuloAnsiedad> {
  bool _loading = true;
  List<Map<String, dynamic>> _questions = const [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final result = await User().getCuestionarioConfig(modulo: 'ansiedad');
    if (!mounted) return;

    final data = result['data'];
    final rawQuestions = data is Map ? data['preguntas'] : null;
    setState(() {
      _questions = rawQuestions is List
          ? rawQuestions
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : const [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF6F8F7),
      appBar: AppBar(title: const Text('Ansiedad')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDarkMode ? 0.18 : 0.06,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF5C6BC0,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.self_improvement_rounded,
                          color: Color(0xFF5C6BC0),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Módulo de ansiedad desbloqueado',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Las preguntas siguientes vienen de Postgres temporal y pueden ser editadas por administrador.',
                        style: TextStyle(
                          height: 1.5,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ..._questions.map(
                  (question) => _QuestionPreview(question: question),
                ),
              ],
            ),
    );
  }
}

class _QuestionPreview extends StatelessWidget {
  const _QuestionPreview({required this.question});

  final Map<String, dynamic> question;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: const Color(0xFF5C6BC0).withValues(alpha: 0.12),
            child: Text('${question['numero'] ?? '-'}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question['pregunta']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '${question['tipo_respuesta'] ?? 'likert4'} · puntaje ${question['puntaje'] ?? 0}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.58),
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
