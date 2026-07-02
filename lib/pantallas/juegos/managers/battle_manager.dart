import 'dart:math';
import '../models/card_data.dart';
import '../models/game_state.dart';

class BattleManager {
  final GameState state;

  BattleManager(this.state);

  double typeMultiplier(CardType attacker, CardType defender) {
    if (attacker == CardType.especial || defender == CardType.especial) {
      return 1.0;
    }
    // Triángulo de Poder: Cog > Emo > Con > Cog
    if (attacker == CardType.cognitivo && defender == CardType.emocional) {
      return 2.0;
    }
    if (attacker == CardType.emocional && defender == CardType.conductual) {
      return 2.0;
    }
    if (attacker == CardType.conductual && defender == CardType.cognitivo) {
      return 2.0;
    }
    // Desventaja: inverso
    if (attacker == CardType.emocional && defender == CardType.cognitivo) {
      return 0.5;
    }
    if (attacker == CardType.conductual && defender == CardType.emocional) {
      return 0.5;
    }
    if (attacker == CardType.cognitivo && defender == CardType.conductual) {
      return 0.5;
    }
    return 1.0;
  }

  int resolveCombat(CardData playerCard, CardData enemyCard) {
    state.phase = GamePhase.combat;

    for (final effect in playerCard.effects) {
      effect.onAttack(this, playerCard, enemyCard);
    }
    for (final effect in enemyCard.effects) {
      effect.onAttack(this, enemyCard, playerCard);
    }

    if (state.attackCancelled) {
      state.attackCancelled = false;
      state.phase = GamePhase.playerTurn;
      state.notify();
      return 0;
    }

    int playerDamage = 0;
    int enemyDamage = 0;

    if (state.playerHp > 0 && state.enemyHp > 0) {
      final baseDmg = playerCard.attack + state.bonusDamage;
      enemyDamage = (typeMultiplier(playerCard.type, enemyCard.type) * baseDmg)
          .round();
      state.enemyHp = max(0, state.enemyHp - enemyDamage);
    }

    state.bonusDamage = 0;

    if (state.playerHp > 0 && state.enemyHp > 0) {
      playerDamage =
          (typeMultiplier(enemyCard.type, playerCard.type) * enemyCard.attack)
              .round();
      state.playerHp = max(0, state.playerHp - playerDamage);
    }

    for (final effect in playerCard.effects) {
      effect.onDamageDealt(this, playerCard, enemyDamage);
      effect.onDamageTaken(this, enemyCard, playerDamage);
      if (state.enemyHp <= 0) effect.onDeath(this, enemyCard);
    }
    for (final effect in enemyCard.effects) {
      effect.onDamageDealt(this, enemyCard, playerDamage);
      effect.onDamageTaken(this, playerCard, playerDamage);
      if (state.playerHp <= 0) effect.onDeath(this, playerCard);
    }

    state.returnCardToPile(playerCard);
    state.returnCardToPile(enemyCard);
    state.playerSlotCard = null;
    state.enemySlotCard = null;

    if (state.enemyHp <= 0) {
      state.playerWon = true;
      state.phase = GamePhase.gameOver;
    } else if (state.playerHp <= 0) {
      state.playerWon = false;
      state.phase = GamePhase.gameOver;
    }

    state.notify();
    return enemyDamage;
  }

  void triggerOnPlay(CardData card) {
    for (final effect in card.effects) {
      effect.onPlay(this, card);
    }
  }

  void triggerOnTurnStart() {
    for (final effect in state.playerSlotCard?.effects ?? []) {
      effect.onTurnStart(this);
    }
    for (final effect in state.enemySlotCard?.effects ?? []) {
      effect.onTurnStart(this);
    }
  }

  void triggerOnTurnEnd() {
    for (final effect in state.playerSlotCard?.effects ?? []) {
      effect.onTurnEnd(this);
    }
    for (final effect in state.enemySlotCard?.effects ?? []) {
      effect.onTurnEnd(this);
    }
  }
}
