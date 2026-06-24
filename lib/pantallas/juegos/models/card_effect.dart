import 'card_data.dart';

abstract class CardEffect {
  final String name;

  const CardEffect({this.name = ''});

  void onPlay(dynamic manager, CardData source) {}

  void onAttack(dynamic manager, CardData source, CardData target) {}

  void onDamageDealt(dynamic manager, CardData source, int damage) {}

  void onDamageTaken(dynamic manager, CardData target, int damage) {}

  void onDeath(dynamic manager, CardData source) {}

  void onTurnStart(dynamic manager) {}

  void onTurnEnd(dynamic manager) {}
}
