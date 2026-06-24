import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

class FadingTextComponent extends TextComponent implements OpacityProvider {
  double _opacity = 1.0;

  @override
  double get opacity => _opacity;

  @override
  set opacity(double value) => _opacity = value;

  FadingTextComponent({
    super.text,
    super.textRenderer,
    super.position,
    super.size,
    super.scale,
    super.angle,
    super.anchor,
    super.children,
    super.priority,
    super.key,
  });

  @override
  void render(Canvas canvas) {
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    super.render(canvas);
    canvas.restore();
  }
}
