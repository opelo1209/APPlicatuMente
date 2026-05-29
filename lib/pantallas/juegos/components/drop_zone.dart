import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class DropZone extends PositionComponent {
  bool _highlighted = false;
  bool _glowing = false;
  double _glowOpacity = 0;

  DropZone({required Vector2 size}) : super(size: size);

  void setHighlight(bool value) {
    if (_highlighted == value) return;
    _highlighted = value;
  }

  void triggerGlow() {
    _glowing = true;
    _glowOpacity = 0.8;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_glowing) {
      _glowOpacity -= dt * 0.8;
      if (_glowOpacity <= 0) {
        _glowOpacity = 0;
        _glowing = false;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();

    if (_highlighted) {
      final paint = Paint()
        ..color = const Color(0x6642A5F5)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)),
        paint,
      );
    }

    if (_glowing) {
      final glowPaint = Paint()
        ..color = const Color(0xFF42A5F5).withValues(alpha: _glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)),
        glowPaint,
      );
    }

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = _highlighted
          ? const Color(0xFF42A5F5)
          : const Color(0x44FFFFFF);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      borderPaint,
    );

    if (!_glowing && !_highlighted) {
      final dashPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x22FFFFFF);
      final dashRect = rect.deflate(8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(dashRect, const Radius.circular(12)),
        dashPaint,
      );
    }
  }
}
