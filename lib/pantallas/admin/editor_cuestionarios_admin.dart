import 'package:flutter/material.dart';

import '../servicios/user.dart';

class EditorCuestionariosAdmin extends StatefulWidget {
  const EditorCuestionariosAdmin({super.key});

  @override
  State<EditorCuestionariosAdmin> createState() =>
      _EditorCuestionariosAdminState();
}

class _EditorCuestionariosAdminState extends State<EditorCuestionariosAdmin> {
  final User _userService = User();
  List<_EditableQuestion> _questions = const [];
  String _selectedModule = 'todos';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _userService.getAdminCuestionarios();
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = result['message']?.toString() ?? 'No se pudieron cargar';
      });
      return;
    }

    final data = result['data'];
    final rawQuestions = data is Map ? data['preguntas'] : const [];
    final questions = rawQuestions is List
        ? rawQuestions
              .whereType<Map>()
              .map((item) => _EditableQuestion.fromMap(item))
              .toList()
        : <_EditableQuestion>[];

    setState(() {
      _questions = questions;
      _loading = false;
    });
  }

  Future<void> _saveQuestion(_EditableQuestion question) async {
    final result = await _userService.updateAdminCuestionario(
      idPregunta: question.idPregunta,
      pregunta: question.pregunta,
      puntaje: question.puntaje,
      activo: question.activo,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Pregunta guardada en Postgres temporal.'
              : result['message']?.toString() ?? 'No se pudo guardar.',
        ),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ),
    );

    if (result['success'] == true) {
      await _loadQuestions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final visibleQuestions = _selectedModule == 'todos'
        ? _questions
        : _questions
              .where((question) => question.moduloKey == _selectedModule)
              .toList();

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Editar preguntas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loadQuestions,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _loadQuestions)
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _Header(isDarkMode: isDarkMode),
                const SizedBox(height: 18),
                _ModuleFilter(
                  selected: _selectedModule,
                  onSelected: (value) => setState(() {
                    _selectedModule = value;
                  }),
                ),
                const SizedBox(height: 18),
                ...visibleQuestions.asMap().entries.map(
                  (entry) => _QuestionEditorCard(
                    question: visibleQuestions[entry.key],
                    onChanged: (updated) {
                      setState(() {
                        _questions = _questions
                            .map(
                              (question) =>
                                  question.idPregunta == updated.idPregunta
                                  ? updated
                                  : question,
                            )
                            .toList();
                      });
                    },
                    onSave: () => _saveQuestion(visibleQuestions[entry.key]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ModuleFilter extends StatelessWidget {
  const _ModuleFilter({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final modules = const [
      ('todos', 'Todos'),
      ('autolesion', 'Autolesión'),
      ('suicidio', 'Suicidio'),
      ('ansiedad', 'Ansiedad'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modules.map((item) {
        return ChoiceChip(
          selected: selected == item.$1,
          label: Text(item.$2),
          onSelected: (_) => onSelected(item.$1),
        );
      }).toList(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings_outlined, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Los administradores no responden cuestionarios. Estas preguntas y puntajes vienen de Postgres temporal.',
              style: TextStyle(
                height: 1.4,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionEditorCard extends StatelessWidget {
  const _QuestionEditorCard({
    required this.question,
    required this.onChanged,
    required this.onSave,
  });

  final _EditableQuestion question;
  final ValueChanged<_EditableQuestion> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E272E)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.modulo,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${question.bloque} · ${question.tipoRespuesta} · ${question.codigo}',
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
              Switch(
                value: question.activo,
                onChanged: (value) =>
                    onChanged(question.copyWith(activo: value)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('pregunta-${question.idPregunta}'),
            initialValue: question.pregunta,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Pregunta'),
            onChanged: (value) => onChanged(question.copyWith(pregunta: value)),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('puntaje-${question.idPregunta}'),
            initialValue: question.puntaje.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Puntaje'),
            onChanged: (value) => onChanged(
              question.copyWith(
                puntaje: int.tryParse(value) ?? question.puntaje,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _EditableQuestion {
  const _EditableQuestion({
    required this.idPregunta,
    required this.moduloKey,
    required this.modulo,
    required this.bloque,
    required this.codigo,
    required this.tipoRespuesta,
    required this.numero,
    required this.pregunta,
    required this.puntaje,
    required this.activo,
  });

  factory _EditableQuestion.fromMap(Map<dynamic, dynamic> map) {
    return _EditableQuestion(
      idPregunta: map['id_pregunta'] as int,
      moduloKey: map['modulo_key']?.toString() ?? '',
      modulo: map['modulo']?.toString() ?? 'Sin módulo',
      bloque: map['bloque']?.toString() ?? 'General',
      codigo: map['codigo']?.toString() ?? '',
      tipoRespuesta: map['tipo_respuesta']?.toString() ?? 'texto',
      numero: map['numero'] is int
          ? map['numero'] as int
          : int.tryParse(map['numero']?.toString() ?? '') ?? 0,
      pregunta: map['pregunta']?.toString() ?? '',
      puntaje: map['puntaje'] is int
          ? map['puntaje'] as int
          : int.tryParse(map['puntaje']?.toString() ?? '') ?? 0,
      activo: map['activo'] == true,
    );
  }

  final int idPregunta;
  final String moduloKey;
  final String modulo;
  final String bloque;
  final String codigo;
  final String tipoRespuesta;
  final int numero;
  final String pregunta;
  final int puntaje;
  final bool activo;

  _EditableQuestion copyWith({String? pregunta, int? puntaje, bool? activo}) {
    return _EditableQuestion(
      idPregunta: idPregunta,
      moduloKey: moduloKey,
      modulo: modulo,
      bloque: bloque,
      codigo: codigo,
      tipoRespuesta: tipoRespuesta,
      numero: numero,
      pregunta: pregunta ?? this.pregunta,
      puntaje: puntaje ?? this.puntaje,
      activo: activo ?? this.activo,
    );
  }
}
