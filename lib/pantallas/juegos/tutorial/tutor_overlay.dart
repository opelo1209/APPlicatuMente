import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'tutor_step.dart';
import 'tutor_service.dart';

class TutorOverlay extends StatelessWidget {
  final TutorService service;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const TutorOverlay({
    super.key,
    required this.service,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final step = service.currentStep;
    if (step == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _SmallPanel(
        key: ValueKey(step.id),
        step: step,
        onSkip: onSkip,
        onNext: onNext,
        progress: service.progress,
        isLast: service.isLastStep,
        stepIndex: service.currentStepIndex,
        totalSteps: service.stepsLength,
      ),
    );
  }
}

class _SmallPanel extends StatefulWidget {
  final TutorStep step;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final double progress;
  final bool isLast;
  final int stepIndex;
  final int totalSteps;

  const _SmallPanel({
    super.key,
    required this.step,
    required this.onSkip,
    required this.onNext,
    required this.progress,
    required this.isLast,
    required this.stepIndex,
    required this.totalSteps,
  });

  @override
  State<_SmallPanel> createState() => _SmallPanelState();
}

class _SmallPanelState extends State<_SmallPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void didUpdateWidget(_SmallPanel old) {
    super.didUpdateWidget(old);
    if (old.step.id != widget.step.id) {
      _animCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF1E272E) : Colors.white)
                  .withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: const Color(0xFF66BB6A).withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF66BB6A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.step.instruction,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF263238),
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onSkip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Omitir',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.step.detail != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      widget.step.detail!,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? Colors.white60 : Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStepDots(),
                    const Spacer(),
                    if (widget.step.requiredAction == TutorAction.tap)
                      GestureDetector(
                        onTap: widget.onNext,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.isLast ? '¡Entendido!' : 'Siguiente',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    else if (widget.step.requiredAction ==
                        TutorAction.dropCard)
                      Row(
                        children: [
                          const Icon(Icons.touch_app_rounded,
                              size: 16, color: Color(0xFF66BB6A)),
                          const SizedBox(width: 4),
                          Text(
                            'Arrastra una carta al slot',
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF66BB6A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF66BB6A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Observa...',
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF66BB6A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepDots() {
    return Row(
      children: List.generate(
        math.min(widget.totalSteps, 8),
        (i) {
          final isActive = i <= widget.stepIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isActive ? 14 : 5,
            height: 5,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF66BB6A)
                  : const Color(0xFFBDBDBD).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        },
      ),
    );
  }
}
