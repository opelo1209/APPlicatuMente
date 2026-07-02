import 'card_data.dart' show CardData;
import 'game_state.dart' show GameState;

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

class HealEffect extends CardEffect {
  final int amount;
  const HealEffect(this.amount, {super.name});

  @override
  void onPlay(dynamic manager, CardData source) {
    final bm = manager as dynamic;
    if (bm.state.healBlocked) {
      bm.state.healBlocked = false;
      bm.state.notify();
      return;
    }
    bm.state.playerHp =
        (bm.state.playerHp + amount).clamp(0, GameState.maxHp);
    bm.state.notify();
  }
}

class NextAttackBonusEffect extends CardEffect {
  final int bonus;
  const NextAttackBonusEffect(this.bonus, {super.name});

  @override
  void onTurnStart(dynamic manager) {
    final bm = manager as dynamic;
    bm.state.bonusDamage = bonus;
    bm.state.notify();
  }

  @override
  void onTurnEnd(dynamic manager) {
    final bm = manager as dynamic;
    bm.state.bonusDamage = 0;
    bm.state.notify();
  }
}

class CancelNextAttackEffect extends CardEffect {
  const CancelNextAttackEffect({super.name});

  @override
  void onTurnStart(dynamic manager) {
    final bm = manager as dynamic;
    bm.state.attackCancelled = true;
    bm.state.notify();
  }

  @override
  void onTurnEnd(dynamic manager) {
    final bm = manager as dynamic;
    bm.state.attackCancelled = false;
    bm.state.notify();
  }
}

class DrawAndDiscardEffect extends CardEffect {
  final int drawCount;
  final int discardCount;
  const DrawAndDiscardEffect(this.drawCount, this.discardCount, {super.name});

  @override
  void onPlay(dynamic manager, CardData source) {
    final bm = manager as dynamic;
    final state = bm.state as dynamic;
    for (var i = 0; i < drawCount; i++) {
      if (state.playerDeck.isNotEmpty) {
        state.playerHand.add(state.playerDeck.removeLast());
      }
    }
    for (var i = 0; i < discardCount; i++) {
      if (state.playerHand.isNotEmpty) {
        state.returnCardToPile(state.playerHand.removeAt(0));
      }
    }
    state.needsHandRebuild = true;
    state.notify();
  }
}

class BlockHealEffect extends CardEffect {
  const BlockHealEffect({super.name});

  @override
  void onAttack(dynamic manager, CardData source, CardData target) {
    final bm = manager as dynamic;
    bm.state.healBlocked = true;
    bm.state.notify();
  }
}

class StealHpEffect extends CardEffect {
  final int amount;
  const StealHpEffect(this.amount, {super.name});

  @override
  void onDamageDealt(dynamic manager, CardData source, int damage) {
    final bm = manager as dynamic;
    final stolen = amount.clamp(0, bm.state.playerHp);
    bm.state.playerHp -= stolen;
    bm.state.enemyHp =
        (bm.state.enemyHp + stolen).clamp(0, GameState.maxHp);
    bm.state.notify();
  }
}

class DiscardFromHandEffect extends CardEffect {
  const DiscardFromHandEffect({super.name});

  @override
  void onAttack(dynamic manager, CardData source, CardData target) {
    final bm = manager as dynamic;
    if (bm.state.playerHand.isNotEmpty) {
      bm.state.returnCardToPile(bm.state.playerHand.removeAt(0));
      bm.state.notify();
    }
  }
}
