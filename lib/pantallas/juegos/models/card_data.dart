import 'card_effect.dart';

enum CardType { cognitivo, emocional, conductual }

extension CardTypeX on CardType {
  String get label {
    switch (this) {
      case CardType.cognitivo:
        return 'Cognitivo';
      case CardType.emocional:
        return 'Emocional';
      case CardType.conductual:
        return 'Conductual';
    }
  }
}

class CardData {
  final String id;
  final String name;
  final String imagePath;
  final int attack;
  final CardType type;
  final List<CardEffect> effects;

  const CardData({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.attack,
    required this.type,
    this.effects = const [],
  });
}
