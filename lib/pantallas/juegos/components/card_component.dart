import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../models/card_data.dart';

// ignore_for_file: deprecated_member_use
class CardComponent extends PositionComponent
    with HasGameRef, TapCallbacks
    implements OpacityProvider {
  double _opacity = 1.0;

  @override
  double get opacity => _opacity;

  @override
  set opacity(double value) => _opacity = value;
  final CardData cardData;
  final void Function(CardComponent)? onLongPress;
  final double cardScale;

  Sprite? _sprite;
  bool _previewVisible = false;
  double _pressTimer = 0;

  CardComponent({
    required this.cardData,
    required Vector2 size,
    this.onLongPress,
    this.cardScale = 1.0,
  }) : super(size: size) {
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final path = 'assets/imagenes/tcg/${cardData.imagePath}';
    try {
      _sprite = Sprite(gameRef.images.fromCache(path));
    } catch (_) {
      _sprite = await Sprite.load(path);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.saveLayer(null, Paint()..color = Colors.white.withOpacity(opacity));
    final w = size.x;
    final h = size.y;
    final cardRect = Rect.fromLTWH(0, 0, w, h);
    final cardRRect = RRect.fromRectAndRadius(cardRect, const Radius.circular(10));

    canvas.save();
    canvas.clipRRect(cardRRect);

    if (_sprite != null) {
      _sprite!.render(canvas, size: size);
    } else {
      canvas.drawRect(cardRect, Paint()..color = const Color(0xFF2C3E50));
    }

    canvas.restore();

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = cardData.type.color;
    canvas.drawRRect(cardRRect, paint);

    final atkPaint = Paint()..color = const Color(0xCC000000);
    final atkRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.55, h * 0.74, w * 0.40, h * 0.20),
      const Radius.circular(6),
    );
    canvas.drawRRect(atkRect, atkPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'ATK ${cardData.attack}',
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: w * 0.38);
    textPainter.paint(
      canvas,
      Offset(w * 0.57, h * 0.76),
    );

    final namePainter = TextPainter(
      text: TextSpan(
        text: cardData.name,
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.09,
          fontWeight: FontWeight.w600,
          shadows: const [
            Shadow(color: Color(0xCC000000), blurRadius: 3),
          ],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: w * 0.85);
    namePainter.paint(
      canvas,
      Offset(w * 0.075, h * 0.03),
    );
    canvas.restore();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_pressTimer > 0) {
      _pressTimer += dt;
      if (_pressTimer >= 0.3 && !_previewVisible) {
        _previewVisible = true;
        onLongPress?.call(this);
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    _pressTimer = 0.01;
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    _pressTimer = 0;
    _previewVisible = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    super.onTapCancel(event);
    _pressTimer = 0;
    _previewVisible = false;
  }
}

extension CardTypeColor on CardType {
  Color get color {
    switch (this) {
      case CardType.cognitivo:
        return const Color(0xFF42A5F5);
      case CardType.emocional:
        return const Color(0xFFEF5350);
      case CardType.conductual:
        return const Color(0xFF66BB6A);
    }
  }
}
