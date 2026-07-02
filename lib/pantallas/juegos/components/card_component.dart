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
