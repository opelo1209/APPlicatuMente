import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../admin/editor_cuestionarios_admin.dart';
import '../servicios/user.dart';
import '../theme_provider.dart';
import 'modulo_autolesiones.dart';
import 'modulo_ansiedad.dart';
import 'modulo_suicidio.dart';

class SelectorModuloCrisis extends StatefulWidget {
  const SelectorModuloCrisis({super.key});

  @override
  State<SelectorModuloCrisis> createState() => _SelectorModuloCrisisState();
}

class _SelectorModuloCrisisState extends State<SelectorModuloCrisis> {
  Map<String, dynamic> _permissions = const {};
  bool _loadingProgress = true;
  bool _autolesionCompletado = false;
  bool _suicidioCompletado = false;

  bool get _isAdmin => _permissions['can_edit_questionnaires'] == true;
  bool get _canAnswer => _permissions['can_answer_questionnaires'] == true;
  bool get _ansiedadDisponible =>
      _canAnswer && _autolesionCompletado && _suicidioCompletado;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final userService = User();
    final sessionResult = await userService.getSessionContext();

    Map<String, dynamic> permissions = const {};
    bool autolesionCompletado = false;
    bool suicidioCompletado = false;

    if (sessionResult['success'] == true) {
      final data = sessionResult['data'];
      if (data is Map) {
        final rawPermissions = data['permissions'];
        permissions = rawPermissions is Map
            ? Map<String, dynamic>.from(rawPermissions)
            : const {};
        final progress = data['progress'];
        if (progress is Map) {
          autolesionCompletado =
              progress['modulo_autolesion_completado'] == true;
          suicidioCompletado = progress['modulo_suicidio_completado'] == true;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _permissions = permissions;
      _autolesionCompletado = autolesionCompletado;
      _suicidioCompletado = suicidioCompletado;
      _loadingProgress = false;
    });
  }

  Future<void> _openModule(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    await _loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    // Mantenemos la paleta original para coherencia
    final backgroundColor = isDarkMode
        ? const Color(0xFF121212)
        : const Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: backgroundColor,
      // For real glassmorphism, a subtle background pattern or gradient is beautiful
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      '¿Qué deseas revisar?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _loadingProgress
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _InfoBox(isDarkMode: isDarkMode, isAdmin: _isAdmin),
                        const SizedBox(height: 30),

                        if (_isAdmin) ...[
                          _ModuleCard(
                            title: 'Editar cuestionarios',
                            subtitle:
                                'Ajusta preguntas y puntajes de los módulos. Los administradores no responden cuestionarios.',
                            icon: Icons.edit_note_rounded,
                            color: const Color(0xFF7B1FA2),
                            isDarkMode: isDarkMode,
                            statusLabel: 'Administración',
                            onTap: () =>
                                _openModule(const EditorCuestionariosAdmin()),
                          ),
                        ] else if (_canAnswer) ...[
                          _ModuleCard(
                            title: 'Autolesiones',
                            subtitle: _autolesionCompletado
                                ? 'Este cuestionario ya fue respondido. Continúa con el siguiente módulo.'
                                : 'Información clara sobre la autolesión no suicida, funciones y un breve cuestionario.',
                            icon: Icons.health_and_safety_outlined,
                            color: const Color(0xFF00897B),
                            isDarkMode: isDarkMode,
                            enabled: !_autolesionCompletado,
                            statusLabel: _autolesionCompletado
                                ? 'Completado'
                                : 'Leer y evaluar',
                            statusIcon: _autolesionCompletado
                                ? Icons.lock_outline_rounded
                                : Icons.arrow_forward_ios,
                            onTap: () =>
                                _openModule(const ModuloAutolesiones()),
                          ),
                          const SizedBox(height: 20),
                          _ModuleCard(
                            title: 'Riesgo de suicidio',
                            subtitle: _suicidioCompletado
                                ? 'Este cuestionario ya fue respondido. Continúa con el siguiente módulo.'
                                : 'Conoce las señales, comprende factores de riesgo y evalúa la situación de forma segura.',
                            icon: Icons.favorite_border_rounded,
                            color: const Color(0xFF43A047),
                            isDarkMode: isDarkMode,
                            enabled: !_suicidioCompletado,
                            statusLabel: _suicidioCompletado
                                ? 'Completado'
                                : 'Leer y evaluar',
                            statusIcon: _suicidioCompletado
                                ? Icons.lock_outline_rounded
                                : Icons.arrow_forward_ios,
                            onTap: () => _openModule(const ModuloSuicidio()),
                          ),
                          const SizedBox(height: 20),
                          _ModuleCard(
                            title: 'Ansiedad',
                            subtitle: _ansiedadDisponible
                                ? 'Módulo desbloqueado. La información y cuestionarios se agregarán después.'
                                : 'Se desbloquea al completar Autolesiones y Riesgo de suicidio.',
                            icon: Icons.self_improvement_rounded,
                            color: const Color(0xFF5C6BC0),
                            isDarkMode: isDarkMode,
                            enabled: _ansiedadDisponible,
                            statusLabel: _ansiedadDisponible
                                ? 'Desbloqueado'
                                : 'Bloqueado',
                            statusIcon: _ansiedadDisponible
                                ? Icons.arrow_forward_ios
                                : Icons.lock_outline_rounded,
                            onTap: () => _openModule(const ModuloAnsiedad()),
                          ),
                        ] else ...[
                          _ModuleCard(
                            title: 'Sin acceso a cuestionarios',
                            subtitle:
                                'Tu rol actual no tiene permiso para responder módulos.',
                            icon: Icons.lock_outline_rounded,
                            color: const Color(0xFF78909C),
                            isDarkMode: isDarkMode,
                            enabled: false,
                            statusLabel: 'Restringido',
                            statusIcon: Icons.lock_outline_rounded,
                            onTap: () {},
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info box (sin efectos de blur) ─────────────────────────────────────────
class _InfoBox extends StatelessWidget {
  final bool isDarkMode;
  final bool isAdmin;
  const _InfoBox({required this.isDarkMode, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF43A047),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Primero la información',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isAdmin
                ? 'Como administrador, puedes editar preguntas y puntajes. El monitoreo de respuestas está en el menú lateral.'
                : 'Este contenido cambia según tu rol y progreso consultado en Postgres.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDarkMode ? Colors.white70 : const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tarjeta de módulo (estilo sólido, igual que en principal.dart) ───────────
class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.onTap,
    this.enabled = true,
    this.statusLabel = 'Leer y evaluar',
    this.statusIcon = Icons.arrow_forward_ios,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final VoidCallback onTap;
  final bool enabled;
  final String statusLabel;
  final IconData statusIcon;

  @override
  Widget build(BuildContext context) {
    final cardColor = enabled
        ? (isDarkMode ? color.withValues(alpha: 0.25) : color)
        : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade400);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: Colors.white, size: 26),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(statusIcon, color: Colors.white, size: 11),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
