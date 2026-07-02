import 'dart:ui' show Color;

import 'card_effect.dart';

enum CardType { cognitivo, emocional, conductual, especial }

extension CardTypeX on CardType {
  String get label {
    switch (this) {
      case CardType.cognitivo:
        return 'Cognitivo';
      case CardType.emocional:
        return 'Emocional';
      case CardType.conductual:
        return 'Conductual';
      case CardType.especial:
        return 'Comodín';
    }
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
      case CardType.especial:
        return const Color(0xFFFFD700);
    }
  }
}

class CardData {
  final String id;
  final String name;
  final String imagePath;
  final int cost;
  final int attack;
  final CardType type;
  final bool isBossCard;
  final String? effectText;
  final List<CardEffect> effects;

  const CardData({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.attack,
    required this.type,
    int? cost,
    this.isBossCard = false,
    this.effectText,
    this.effects = const [],
  }) : cost = cost ?? attack;
}
