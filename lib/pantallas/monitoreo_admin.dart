import 'dart:convert';

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
          final estudiantes = _asList(data['estudiantes']);
          final padres = _asList(data['padres']);

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                _SummaryHeader(
                  total: data['total'] ?? estudiantes.length + padres.length,
                  estudiantes: estudiantes.length,
                  padres: padres.length,
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Respuestas de estudiantes',
                  icon: Icons.school_outlined,
                  color: const Color(0xFF43A047),
                  items: estudiantes,
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Respuestas de padres',
                  icon: Icons.family_restroom_outlined,
                  color: const Color(0xFFFB8C00),
                  items: padres,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.total,
    required this.estudiantes,
    required this.padres,
  });

  final Object total;
  final int estudiantes;
  final int padres;

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
      child: Row(
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
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total respuestas · $estudiantes estudiantes · $padres padres',
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
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          _EmptyCard(color: color)
        else
          ...items.map((item) => _ResponseCard(item: item, color: color)),
      ],
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({required this.item, required this.color});

  final Map<String, dynamic> item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final respuestas = item['respuestas'];
    final formatted = const JsonEncoder.withIndent(
      '  ',
    ).convert(respuestas ?? {});
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(Icons.assignment_outlined, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['nombre_completo']?.toString().isNotEmpty == true
                          ? item['nombre_completo'].toString()
                          : item['nombre_usuario']?.toString() ?? 'Usuario',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      item['correo']?.toString() ?? '',
                      style: TextStyle(
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(text: item['tipo_cuestionario']?.toString() ?? 'Sin tipo'),
              _Tag(
                text: item['completado'] == true ? 'Completado' : 'Pendiente',
              ),
              _Tag(text: item['fecha_de_registro']?.toString() ?? 'Sin fecha'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.black.withValues(alpha: 0.24)
                  : const Color(0xFFF7F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              formatted,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
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
