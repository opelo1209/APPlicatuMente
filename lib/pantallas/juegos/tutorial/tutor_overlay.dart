import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'tutor_step.dart';
import 'tutor_service.dart';

class TutorOverlay extends StatelessWidget {
  final TutorService service;
  final Size gameAreaSize;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const TutorOverlay({
    super.key,
    required this.service,
    required this.gameAreaSize,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final step = service.currentStep;
    if (step == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _StepOverlay(
        key: ValueKey(step.id),
        step: step,
        gameAreaSize: gameAreaSize,
        onSkip: onSkip,
        onNext: onNext,
        progress: service.progress,
        isLast: service.isLastStep,
        stepIndex: service.currentStepIndex,
        totalSteps: service._stepCount(),
      ),
    );
  }
}

extension _ServiceHelper on TutorService {
  int _stepCount() => stepsLength; // ignore: invalid_use_of_protected_member
}

class _StepOverlay extends StatefulWidget {
  final TutorStep step;
  final Size gameAreaSize;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final double progress;
  final bool isLast;
  final int stepIndex;
  final int totalSteps;

  const _StepOverlay({
    super.key,
    required this.step,
    required this.gameAreaSize,
    required this.onSkip,
    required this.onNext,
    required this.progress,
    required this.isLast,
    required this.stepIndex,
    required this.totalSteps,
  });

  @override
  State<_StepOverlay> createState() => _StepOverlayState();
}

class _StepOverlayState extends State<_StepOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void didUpdateWidget(_StepOverlay old) {
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

  Rect? _computeHighlightRect(TutorHighlightTarget target, Size areaSize) {
    switch (target) {
      case TutorHighlightTarget.playerSlot:
        final slotW = math.min(areaSize.width * 0.5, 200.0);
        final slotH = math.min(areaSize.height * 0.38, 250.0);
        final cx = (areaSize.width - slotW) / 2;
        final cy = areaSize.height * 0.48 - slotH / 2;
        return Rect.fromLTWH(cx, cy, slotW, slotH).inflate(12);

      case TutorHighlightTarget.enemySlot:
        final slotW = math.min(areaSize.width * 0.5, 200.0);
        final slotH = math.min(areaSize.height * 0.38, 250.0);
        final cx = (areaSize.width - slotW) / 2;
        final cy = areaSize.height * 0.08;
        return Rect.fromLTWH(cx, cy, slotW, slotH).inflate(12);

      case TutorHighlightTarget.hand:
        final cardW = 90.0;
        final cardH = 130.0;
        final totalW = math.min(4 * cardW + 3 * 8, areaSize.width * 0.92);
        final cx = (areaSize.width - totalW) / 2;
        final cy = areaSize.height - cardH - 20;
        return Rect.fromLTWH(cx - 8, cy - 8, totalW + 16, cardH + 16);

      case TutorHighlightTarget.energyBar:
        final barW = math.min(areaSize.width * 0.55, 300.0);
        final cx = (areaSize.width - barW) / 2;
        return Rect.fromLTWH(cx, 6, barW, 26).inflate(8);

      case TutorHighlightTarget.combatResolve:
        final slotW = math.min(areaSize.width * 0.5, 200.0);
        final slotH = math.min(areaSize.height * 0.38, 250.0);
        final cx = (areaSize.width - slotW) / 2;
        final cy = areaSize.height * 0.10;
        return Rect.fromLTWH(cx - 20, cy - 20, slotW + 40, slotH + 40);

      case TutorHighlightTarget.none:
      case TutorHighlightTarget.wholeBoard:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final holeRect = _computeHighlightRect(
      widget.step.highlight,
      widget.gameAreaSize,
    );

    final bool panelBlocksPointer =
        widget.step.requiredAction == TutorAction.tap;

    final double handHeight = 150.0;
    final double safeBottomInset =
        MediaQuery.of(context).padding.bottom + handHeight + 12;

    return Stack(
      key: widget.key,
      children: [
        RepaintBoundary(child: _OverlayPainterWidget(holeRect: holeRect)),
        if (holeRect != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF66BB6A).withValues(alpha: 0.6),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF66BB6A).withValues(alpha: 0.35),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: safeBottomInset,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: panelBlocksPointer
                  ? _buildInstructionPanel(context)
                  : IgnorePointer(child: _buildInstructionPanel(context)),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 0,
          right: 0,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: _buildTopBar(context),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Spacer(),
          TextButton(
            onPressed: widget.onSkip,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              backgroundColor: Colors.black26,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Omitir tutorial',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionPanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
        left: 20,
        right: 20,
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E272E) : Colors.white)
            .withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF66BB6A).withValues(alpha: 0.3),
          width: 1.5,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF263238),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (widget.step.detail != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                widget.step.detail!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.3,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStepDots(),
              const Spacer(),
              if (widget.step.requiredAction == TutorAction.tap)
                FilledButton(
                  onPressed: widget.onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    widget.isLast ? '¡Entendido!' : 'Siguiente',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                )
              else if (widget.step.requiredAction == TutorAction.dropCard)
                Row(
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 18,
                      color: const Color(0xFF66BB6A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Arrastra una carta al slot',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF66BB6A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFF66BB6A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Observa...',
                      style: TextStyle(
                        fontSize: 12,
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
            width: isActive ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.only(right: 4),
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

class _OverlayPainterWidget extends StatelessWidget {
  final Rect? holeRect;

  const _OverlayPainterWidget({this.holeRect});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          child: CustomPaint(
            painter: _OverlayPainter(
              holeRect: holeRect,
              overlayColor: Colors.black.withValues(alpha: 0.55),
              glowColor: const Color(0xFF66BB6A),
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect? holeRect;
  final Color overlayColor;
  final Color glowColor;

  _OverlayPainter({
    required this.holeRect,
    required this.overlayColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final canvasRect = Offset.zero & size;

    if (holeRect == null) {
      canvas.drawRect(canvasRect, Paint()..color = overlayColor);
      return;
    }

    final holeRRect = RRect.fromRectAndRadius(
      holeRect!,
      const Radius.circular(16),
    );

    final fullPath = Path()..addRect(canvasRect);
    final holePath = Path()..addRRect(holeRRect);
    final visualPath = Path.combine(PathOperation.difference, fullPath, holePath);

    canvas.drawPath(visualPath, Paint()..color = overlayColor);

    canvas.save();
    canvas.clipPath(holePath);
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35);

    final inflatedRect = holeRect!.inflate(40);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inflatedRect, const Radius.circular(20)),
      glowPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.holeRect != holeRect ||
      old.overlayColor != overlayColor ||
      old.glowColor != glowColor;
}
