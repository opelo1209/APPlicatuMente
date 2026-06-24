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
  static const int maxHp = 25;
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

  final Random _random = Random();

  void startGame(List<CardData> allCards) {
    drawPile
      ..clear()
      ..addAll(allCards)
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
    _drawToHandSize(playerHand);
    _drawToHandSize(enemyHand);
    notifyListeners();
  }

  void _drawToHandSize(List<CardData> hand) {
    while (hand.length < handSize && drawPile.isNotEmpty) {
      hand.add(drawPile.removeLast());
    }
  }

  void returnCardToPile(CardData card) {
    drawPile.add(card);
    drawPile.shuffle(_random);
  }

  void refillHands() {
    _drawToHandSize(playerHand);
    _drawToHandSize(enemyHand);
    notify();
  }

  void notify() => notifyListeners();

  void dealPlayerCard() {
    if (drawPile.isNotEmpty) {
      playerHand.add(drawPile.removeLast());
      notifyListeners();
    }
  }

  void dealEnemyCard() {
    if (drawPile.isNotEmpty) {
      enemyHand.add(drawPile.removeLast());
      notifyListeners();
    }
  }

  bool get isGameOver => phase == GamePhase.gameOver;

  void gainEnergy() {
    energy = min(maxEnergy, energy + energyPerTurn);
    energyCap = min(maxEnergy, energyCap + 1);
    notify();
  }

  bool canPlayCard(CardData card) => energy >= card.attack;

  void spendEnergy(int amount) {
    energy = max(0, energy - amount);
    notify();
  }
}
