import 'dart:math';
import 'package:flutter/foundation.dart';
import 'card_data.dart';

enum GamePhase {
  playerTurn,
  enemyTurn,
  combat,
  gameOver,
}

class GameState extends ChangeNotifier {
  static const int maxHp = 20;
  static const int handSize = 4;
  static const int energyPerTurn = 2;
  static const int maxEnergy = 10;

  int playerHp = maxHp;
  int enemyHp = maxHp;
  GamePhase phase = GamePhase.playerTurn;
  int turn = 1;
  bool playerWon = false;

  int energy = 0;
  int energyCap = 3;

  CardData? playerSlotCard;
  CardData? enemySlotCard;

  final List<CardData> playerHand = [];
  final List<CardData> enemyHand = [];
  final List<CardData> drawPile = [];
  final List<CardData> playerDeck = [];
  final List<CardData> enemyDeck = [];

  int bonusDamage = 0;
  bool attackCancelled = false;
  bool healBlocked = false;
  bool needsHandRebuild = false;

  final Random _random = Random();

  void startGame(
    List<CardData> playerCards,
    List<CardData> enemyCards,
  ) {
    drawPile.clear();
    playerDeck
      ..clear()
      ..addAll(playerCards)
      ..shuffle(_random);
    enemyDeck
      ..clear()
      ..addAll(enemyCards)
      ..shuffle(_random);
    playerHand.clear();
    enemyHand.clear();
    playerSlotCard = null;
    enemySlotCard = null;
    playerHp = maxHp;
    enemyHp = maxHp;
    turn = 1;
    phase = GamePhase.playerTurn;
    playerWon = false;
    energy = 3;
    energyCap = 3;
    bonusDamage = 0;
    attackCancelled = false;
    healBlocked = false;
    needsHandRebuild = false;
    _drawToHandSize(playerHand, playerDeck);
    _drawToHandSize(enemyHand, enemyDeck);
    notifyListeners();
  }

  void _drawToHandSize(List<CardData> hand, List<CardData> deck) {
    while (hand.length < handSize && deck.isNotEmpty) {
      hand.add(deck.removeLast());
    }
  }

  void returnCardToPile(CardData card) {
    drawPile.add(card);
    drawPile.shuffle(_random);
  }

  void refillHands() {
    _drawToHandSize(playerHand, playerDeck);
    _drawToHandSize(enemyHand, enemyDeck);
    notify();
  }

  void notify() => notifyListeners();

  void dealPlayerCard() {
    if (playerDeck.isNotEmpty) {
      playerHand.add(playerDeck.removeLast());
      notifyListeners();
    }
  }

  void dealEnemyCard() {
    if (enemyDeck.isNotEmpty) {
      enemyHand.add(enemyDeck.removeLast());
      notifyListeners();
    }
  }

  bool get isGameOver => phase == GamePhase.gameOver;

  void resetTurnFlags() {
    bonusDamage = 0;
    attackCancelled = false;
    healBlocked = false;
    needsHandRebuild = false;
  }

  void gainEnergy() {
    energy = min(maxEnergy, energy + energyPerTurn);
    energyCap = min(maxEnergy, energyCap + 1);
    notify();
  }

  bool canPlayCard(CardData card) => energy >= card.cost;

  void spendEnergy(int amount) {
    energy = max(0, energy - amount);
    notify();
  }
}
