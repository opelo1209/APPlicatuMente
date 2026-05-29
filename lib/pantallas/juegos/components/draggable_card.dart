import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'card_component.dart';

class DraggableCard extends CardComponent with DragCallbacks {
  final VoidCallback? onDragStarted;
  final void Function(DraggableCard)? onDragEnded;

  Vector2 _homePosition = Vector2.zero();
  bool _isDragging = false;
  bool _returning = false;

  DraggableCard({
    required super.cardData,
    required super.size,
    super.onLongPress,
    this.onDragStarted,
    this.onDragEnded,
  }) {
    anchor = Anchor.center;
  }

  bool get isDragging => _isDragging;

  void setHome(Vector2 pos) {
    _homePosition = pos.clone();
    if (!_isDragging && !_returning) {
      position.setFrom(pos);
    }
  }

  void returnToHome() {
    _isDragging = false;
    _returning = true;
    add(MoveEffect.to(
      _homePosition,
      EffectController(duration: 0.3, curve: Curves.easeOut),
    ));
    add(ScaleEffect.to(
      Vector2.all(1.0),
      EffectController(duration: 0.2),
    ));
    priority = 10;
  }

  void animateToSlot(Vector2 slotPos) {
    _isDragging = false;
    _returning = false;
    add(MoveEffect.to(
      slotPos,
      EffectController(duration: 0.3, curve: Curves.easeOutBack),
    ));
    add(ScaleEffect.to(
      Vector2.all(1.15),
      EffectController(duration: 0.25, curve: Curves.easeOutBack),
    ));
    priority = 50;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _isDragging = true;
    _returning = false;
    priority = 100;
    scale = Vector2.all(1.08);
    onDragStarted?.call();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (_isDragging) {
      position.add(event.localDelta);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (_isDragging) {
      _isDragging = false;
      onDragEnded?.call(this);
    }
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (_isDragging) {
      _isDragging = false;
      returnToHome();
    }
  }
}
