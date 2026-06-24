import 'package:flutter/material.dart';

import 'servicios/user.dart';

class MonitoreoAdmin extends StatefulWidget {
  const MonitoreoAdmin({super.key});

  @override
  State<MonitoreoAdmin> createState() => _MonitoreoAdminState();
}

class _MonitoreoAdminState extends State<MonitoreoAdmin> {
  late Future<Map<String, dynamic>> _future;
  final User _userService = User();

  @override
  void initState() {
    super.initState();
    _future = _userService.getMonitoreoAdmin();
  }

  void _refresh() {
    setState(() {
      _future = _userService.getMonitoreoAdmin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Monitorear'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?['success'] != true) {
            return _ErrorState(
              message:
                  snapshot.data?['message'] ??
                  'No se pudieron cargar las respuestas',
              onRetry: _refresh,
            );
          }

          final data = snapshot.data!['data'] as Map<String, dynamic>;
          final estudiantes = _asResponses(data['estudiantes']);
          final padres = _asResponses(data['padres']);
          final total = data['total'] is int
              ? data['total'] as int
              : estudiantes.length + padres.length;

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                _SummaryHeader(
                  total: total,
                  estudiantes: _uniqueUsers(estudiantes),
                  padres: _uniqueUsers(padres),
                  modulos: _allModuleCount(estudiantes, padres),
                ),
                const SizedBox(height: 18),
                _ProfileSection(
                  title: 'Estudiantes',
                  subtitle: 'Respuestas agrupadas por módulo',
                  icon: Icons.school_outlined,
                  color: const Color(0xFF43A047),
                  responses: estudiantes,
                ),
                const SizedBox(height: 20),
                _ProfileSection(
                  title: 'Padres',
                  subtitle: 'Respuestas agrupadas por módulo',
                  icon: Icons.family_restroom_outlined,
                  color: const Color(0xFFFB8C00),
                  responses: padres,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_MonitoringResponse> _asResponses(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => _MonitoringResponse.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  int _uniqueUsers(List<_MonitoringResponse> responses) {
    return responses.map((response) => response.userKey).toSet().length;
  }

  int _allModuleCount(
    List<_MonitoringResponse> estudiantes,
    List<_MonitoringResponse> padres,
  ) {
    return {
      ...estudiantes.map((response) => response.moduleKey),
      ...padres.map((response) => response.moduleKey),
    }.length;
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.total,
    required this.estudiantes,
    required this.padres,
    required this.modulos,
  });

  final int total;
  final int estudiantes;
  final int padres;
  final int modulos;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.18 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: Color(0xFF43A047),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monitoreo de respuestas',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$total respuestas registradas',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.64),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(
                icon: Icons.school_outlined,
                label: 'Estudiantes',
                value: '$estudiantes',
                color: const Color(0xFF43A047),
              ),
              _MetricPill(
                icon: Icons.family_restroom_outlined,
                label: 'Padres',
                value: '$padres',
                color: const Color(0xFFFB8C00),
              ),
              _MetricPill(
                icon: Icons.dashboard_customize_outlined,
                label: 'Módulos',
                value: '$modulos',
                color: const Color(0xFF1E88E5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.responses,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_MonitoringResponse> responses;

  @override
  Widget build(BuildContext context) {
    final groups = _ModuleGroup.fromResponses(responses);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _SmallCounter(text: '${responses.length}', color: color),
          ],
        ),
        const SizedBox(height: 12),
        if (responses.isEmpty)
          _EmptyCard(color: color)
        else ...[
          _ModuleOverview(groups: groups, color: color),
          const SizedBox(height: 12),
          ...groups.map((group) => _ModuleSection(group: group, color: color)),
        ],
      ],
    );
  }
}

class _ModuleOverview extends StatelessWidget {
  const _ModuleOverview({required this.groups, required this.color});

  final List<_ModuleGroup> groups;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: groups
          .map(
            (group) => _ModuleStatChip(
              title: group.title,
              count: group.responses.length,
              average: group.averageScore,
              color: group.color,
            ),
          )
          .toList(),
    );
  }
}

class _ModuleSection extends StatelessWidget {
  const _ModuleSection({required this.group, required this.color});

  final _ModuleGroup group;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: group.color.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: group.color.withValues(alpha: 0.13),
            child: Icon(group.icon, color: group.color),
          ),
          title: Text(
            group.title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '${group.responses.length} respuestas · promedio ${group.averageScoreText}',
          ),
          children: [
            _ModuleStatsBar(group: group),
            const SizedBox(height: 12),
            ...group.responses.map(
              (response) => _ResponseCard(response: response, color: group.color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleStatsBar extends StatelessWidget {
  const _ModuleStatsBar({required this.group});

  final _ModuleGroup group;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InlineStat(
            label: 'Completados',
            value: '${group.completedCount}/${group.responses.length}',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF43A047),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InlineStat(
            label: 'Promedio',
            value: group.averageScoreText,
            icon: Icons.insights_outlined,
            color: group.color,
          ),
        ),
      ],
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({required this.response, required this.color});

  final _MonitoringResponse response;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.black.withValues(alpha: 0.16)
            : const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(Icons.person_outline_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      response.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      response.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(text: response.moduleTitle),
              _Tag(text: response.completed ? 'Completado' : 'Pendiente'),
              _Tag(text: response.formattedDate),
            ],
          ),
          const SizedBox(height: 12),
          _ScorePanel(response: response, color: color),
          if (response.blocks.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...response.blocks.map(
              (block) => _BlockPanel(block: block, accent: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.response, required this.color});

  final _MonitoringResponse response;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final score = response.score;
    final maxScore = response.maxScore;
    final percent = maxScore <= 0 ? 0.0 : (score / maxScore).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: response.levelColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: response.levelColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  response.levelLabel,
                  style: TextStyle(
                    color: response.levelColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                maxScore > 0 ? '$score/$maxScore pts' : '$score pts',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressBar(value: percent, color: response.levelColor),
        ],
      ),
    );
  }
}

class _BlockPanel extends StatelessWidget {
  const _BlockPanel({required this.block, required this.accent});

  final _BlockSummary block;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final maxScore = block.maxScore;
    final percent = maxScore <= 0
        ? 0.0
        : (block.score / maxScore).clamp(0.0, 1.0);
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  block.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                maxScore > 0 ? '${block.score}/$maxScore' : '${block.score}',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ProgressBar(value: percent, color: accent),
          const SizedBox(height: 10),
          ...block.answers.map((answer) => _AnswerRow(answer: answer)),
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.answer});

  final _AnswerSummary answer;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            answer.question,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  answer.answer,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (answer.scoreText.isNotEmpty)
                Text(
                  answer.scoreText,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ModuleStatChip extends StatelessWidget {
  const _ModuleStatChip({
    required this.title,
    required this.count,
    required this.average,
    required this.color,
  });

  final String title;
  final int count;
  final double average;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 172,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '$count respuestas',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Promedio ${average.toStringAsFixed(1)} pts',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 9,
        backgroundColor: color.withValues(alpha: 0.14),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _SmallCounter extends StatelessWidget {
  const _SmallCounter({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Todavía no hay respuestas registradas.',
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.70),
          fontWeight: FontWeight.w600,
        ),
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
            const Icon(Icons.lock_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleGroup {
  const _ModuleGroup({
    required this.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.responses,
  });

  final String key;
  final String title;
  final IconData icon;
  final Color color;
  final List<_MonitoringResponse> responses;

  int get completedCount => responses.where((response) => response.completed).length;

  double get averageScore {
    if (responses.isEmpty) return 0;
    final total = responses.fold<int>(0, (sum, response) => sum + response.score);
    return total / responses.length;
  }

  String get averageScoreText => '${averageScore.toStringAsFixed(1)} pts';

  static List<_ModuleGroup> fromResponses(List<_MonitoringResponse> responses) {
    final grouped = <String, List<_MonitoringResponse>>{};
    for (final response in responses) {
      grouped.putIfAbsent(response.moduleKey, () => []).add(response);
    }

    final groups = grouped.entries.map((entry) {
      final meta = _moduleMeta(entry.key);
      return _ModuleGroup(
        key: entry.key,
        title: meta.title,
        icon: meta.icon,
        color: meta.color,
        responses: entry.value,
      );
    }).toList();

    groups.sort((a, b) => a.title.compareTo(b.title));
    return groups;
  }
}

class _MonitoringResponse {
  _MonitoringResponse({
    required this.raw,
    required this.moduleKey,
    required this.moduleTitle,
    required this.name,
    required this.email,
    required this.userKey,
    required this.completed,
    required this.formattedDate,
    required this.blocks,
  });

  final Map<String, dynamic> raw;
  final String moduleKey;
  final String moduleTitle;
  final String name;
  final String email;
  final String userKey;
  final bool completed;
  final String formattedDate;
  final List<_BlockSummary> blocks;

  int get score => blocks.fold<int>(0, (sum, block) => sum + block.score);

  int get maxScore => blocks.fold<int>(0, (sum, block) => sum + block.maxScore);

  String get levelLabel => _levelFor(moduleKey, score);

  Color get levelColor => _levelColorFor(moduleKey, score);

  factory _MonitoringResponse.fromMap(Map<String, dynamic> item) {
    final moduleKey = item['tipo_cuestionario']?.toString() ?? 'sin_modulo';
    final meta = _moduleMeta(moduleKey);
    final respuestas = item['respuestas'];
    final responseMap = respuestas is Map
        ? Map<String, dynamic>.from(respuestas)
        : <String, dynamic>{};
    final rawBlocks = responseMap['bloques'];
    final blocks = rawBlocks is List
        ? rawBlocks
              .whereType<Map>()
              .map((block) => _BlockSummary.fromMap(Map<String, dynamic>.from(block)))
              .toList()
        : <_BlockSummary>[];
    final completeName = item['nombre_completo']?.toString().trim();
    final username = item['nombre_usuario']?.toString().trim();
    final email = item['correo']?.toString().trim();
    final id = item['id_usuario']?.toString();

    return _MonitoringResponse(
      raw: item,
      moduleKey: moduleKey,
      moduleTitle: meta.title,
      name: completeName?.isNotEmpty == true
          ? completeName!
          : username?.isNotEmpty == true
          ? username!
          : 'Usuario',
      email: email?.isNotEmpty == true ? email! : 'Sin correo',
      userKey: id?.isNotEmpty == true ? id! : email ?? username ?? 'usuario',
      completed: item['completado'] == true,
      formattedDate: _formatDate(item['fecha_de_registro']?.toString()),
      blocks: blocks,
    );
  }
}

class _BlockSummary {
  const _BlockSummary({
    required this.key,
    required this.name,
    required this.score,
    required this.answers,
  });

  final String key;
  final String name;
  final int score;
  final List<_AnswerSummary> answers;

  int get maxScore {
    final estimated = answers.fold<int>(
      0,
      (sum, answer) => sum + answer.maxScore,
    );
    if (estimated > 0) return estimated;
    return _knownMaxScore(key);
  }

  factory _BlockSummary.fromMap(Map<String, dynamic> block) {
    final rawAnswers = block['reactivos'];
    final answers = rawAnswers is List
        ? rawAnswers
              .whereType<Map>()
              .map((answer) => _AnswerSummary.fromMap(Map<String, dynamic>.from(answer)))
              .toList()
        : <_AnswerSummary>[];
    answers.sort((a, b) => a.number.compareTo(b.number));

    return _BlockSummary(
      key: block['bloque']?.toString() ?? 'bloque',
      name: block['nombre']?.toString() ?? block['bloque']?.toString() ?? 'Bloque',
      score: _asInt(block['puntuacion_total']),
      answers: answers,
    );
  }
}

class _AnswerSummary {
  const _AnswerSummary({
    required this.number,
    required this.question,
    required this.answer,
    required this.value,
    required this.type,
    required this.configuredScore,
  });

  final int number;
  final String question;
  final String answer;
  final int? value;
  final String type;
  final int configuredScore;

  int get maxScore {
    if (type == 'likert4') return 3;
    if (type == 'binario') return configuredScore > 0 ? configuredScore : 1;
    return 0;
  }

  String get scoreText {
    if (value == null || maxScore <= 0) return '';
    return '$value/$maxScore';
  }

  factory _AnswerSummary.fromMap(Map<String, dynamic> answer) {
    final label = answer['respuesta_etiqueta']?.toString();
    final value = _nullableInt(answer['respuesta_valor']);
    return _AnswerSummary(
      number: _asInt(answer['numero']),
      question: answer['pregunta']?.toString() ?? 'Pregunta sin texto',
      answer: label?.isNotEmpty == true ? label! : value?.toString() ?? 'Sin respuesta',
      value: value,
      type: answer['tipo_respuesta']?.toString() ?? 'texto',
      configuredScore: _asInt(answer['puntaje_configurado']),
    );
  }
}

class _ModuleMeta {
  const _ModuleMeta({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;
}

_ModuleMeta _moduleMeta(String key) {
  switch (key.toLowerCase()) {
    case 'suicidio':
    case 'depresion':
      return const _ModuleMeta(
        title: 'Depresión y riesgo',
        icon: Icons.favorite_border_rounded,
        color: Color(0xFFE53935),
      );
    case 'autolesion':
      return const _ModuleMeta(
        title: 'Autolesiones',
        icon: Icons.healing_outlined,
        color: Color(0xFF8E24AA),
      );
    case 'ansiedad':
      return const _ModuleMeta(
        title: 'Ansiedad',
        icon: Icons.psychology_alt_outlined,
        color: Color(0xFF1E88E5),
      );
    case 'sustancias':
      return const _ModuleMeta(
        title: 'Uso de sustancias',
        icon: Icons.science_outlined,
        color: Color(0xFF00897B),
      );
    default:
      return const _ModuleMeta(
        title: 'Cuestionario inicial',
        icon: Icons.assignment_outlined,
        color: Color(0xFF546E7A),
      );
  }
}

String _levelFor(String moduleKey, int score) {
  switch (moduleKey.toLowerCase()) {
    case 'ansiedad':
      if (score >= 14) return 'Ansiedad severa';
      if (score >= 10) return 'Ansiedad moderada';
      if (score >= 5) return 'Ansiedad leve';
      return 'Ansiedad mínima';
    case 'suicidio':
    case 'depresion':
      if (score >= 20) return 'Riesgo alto';
      if (score >= 10) return 'Seguimiento recomendado';
      if (score >= 5) return 'Síntomas leves';
      return 'Sin indicadores altos';
    case 'autolesion':
      if (score > 0) return 'Requiere seguimiento';
      return 'Sin indicadores reportados';
    default:
      if (score > 0) return 'Con puntaje registrado';
      return 'Sin puntaje';
  }
}

Color _levelColorFor(String moduleKey, int score) {
  switch (moduleKey.toLowerCase()) {
    case 'ansiedad':
      if (score >= 14) return const Color(0xFFE53935);
      if (score >= 10) return const Color(0xFFFF7043);
      if (score >= 5) return const Color(0xFFFFB300);
      return const Color(0xFF43A047);
    case 'suicidio':
    case 'depresion':
      if (score >= 20) return const Color(0xFFE53935);
      if (score >= 10) return const Color(0xFFFF7043);
      if (score >= 5) return const Color(0xFFFFB300);
      return const Color(0xFF43A047);
    case 'autolesion':
      return score > 0 ? const Color(0xFFE53935) : const Color(0xFF43A047);
    default:
      return score > 0 ? const Color(0xFF1E88E5) : const Color(0xFF78909C);
  }
}

int _knownMaxScore(String blockKey) {
  switch (blockKey.toUpperCase()) {
    case 'GAD7':
      return 21;
    case 'PHQ9':
      return 27;
    case 'CSSRS':
      return 5;
    case 'NSSI':
      return 1;
    default:
      return 0;
  }
}

int _asInt(dynamic value) => _nullableInt(value) ?? 0;

int? _nullableInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

String _formatDate(String? value) {
  if (value == null || value.isEmpty) return 'Sin fecha';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}
