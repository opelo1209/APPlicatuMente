import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'data/card_pools.dart';
import 'models/card_data.dart';
import 'models/game_state.dart';
import 'managers/battle_manager.dart';
import 'components/card_component.dart';
import 'components/draggable_card.dart';
import 'components/drop_zone.dart';
import 'components/fading_text_component.dart';

class TcgGame extends FlameGame {
  TcgGame() : super();

  final GameState state = GameState();
  late final BattleManager battleManager;
  final Random _random = Random();

  late final DropZone _playerSlot;
  late final DropZone _enemySlot;
  final List<DraggableCard> _handCards = [];
  CardComponent? _playerCardView;
  CardComponent? _enemyCardView;

  final ValueNotifier<String> combatLog = ValueNotifier<String>('');
  final ValueNotifier<bool> isProcessing = ValueNotifier<bool>(false);

  final ValueNotifier<int> playerHpNotifier = ValueNotifier<int>(25);
  final ValueNotifier<int> enemyHpNotifier = ValueNotifier<int>(25);
  final ValueNotifier<int> energyNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> energyCapNotifier = ValueNotifier<int>(3);
  final ValueNotifier<int> turnNotifier = ValueNotifier<int>(1);

  SpriteComponent? _boardBg;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    images.prefix = '';
    battleManager = BattleManager(state);

    _playerSlot = DropZone(size: Vector2(180, 240));
    add(_playerSlot);

    _enemySlot = DropZone(size: Vector2(180, 240));
    add(_enemySlot);

    state.addListener(() {
      playerHpNotifier.value = state.playerHp;
      enemyHpNotifier.value = state.enemyHp;
      energyNotifier.value = state.energy;
      energyCapNotifier.value = state.energyCap;
      turnNotifier.value = state.turn;
    });
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isLoaded) return;
    _layoutBoard();
  }

  void _loadBoardBg() async {
    _boardBg?.removeFromParent();
    try {
      final sprite = await Sprite.load('assets/imagenes/tcg/tcg-tablero.png');
      _boardBg = SpriteComponent(
        sprite: sprite,
        size: size,
        position: Vector2.zero(),
        priority: -10,
      );
      add(_boardBg!);
    } catch (_) {}
  }

  void _layoutBoard() {
    final slotW = 180.0;
    final slotH = 240.0;
    final centerX = (size.x - slotW) / 2;

    _enemySlot
      ..position = Vector2(centerX, size.y * 0.10)
      ..size = Vector2(slotW, slotH);

    _playerSlot
      ..position = Vector2(centerX, size.y * 0.48)
      ..size = Vector2(slotW, slotH);

    _enemyCardView?.position =
        Vector2(centerX + slotW / 2, size.y * 0.10 + slotH / 2);
    _playerCardView?.position =
        Vector2(centerX + slotW / 2, size.y * 0.48 + slotH / 2);

    _layoutHand();
  }

  void _layoutHand() {
    if (_handCards.isEmpty) return;
    final count = _handCards.length;
    final cardW = 90.0;
    final cardH = 130.0;
    final gap = 8.0;
    final totalW = count * cardW + (count - 1) * gap;
    final startX = (size.x - totalW) / 2 + cardW / 2;
    final y = size.y - cardH / 2 - 16;

    for (var i = 0; i < count; i++) {
      final card = _handCards[i];
      final cx = startX + i * (cardW + gap);
      card.size = Vector2(cardW, cardH);
      card.setHome(Vector2(cx, y));
    }
  }

  void startGame() {
    final allCards = createCardPool();
    state.startGame(allCards);
    _loadBoardBg();
    _rebuildHand();
    _layoutBoard();
    _syncNotifiers();
  }

  void _syncNotifiers() {
    playerHpNotifier.value = state.playerHp;
    enemyHpNotifier.value = state.enemyHp;
    energyNotifier.value = state.energy;
    energyCapNotifier.value = state.energyCap;
    turnNotifier.value = state.turn;
  }

  void _rebuildHand() {
    for (final c in _handCards) {
      c.removeFromParent();
    }
    _handCards.clear();

    for (final cardData in state.playerHand) {
      final dc = DraggableCard(
        cardData: cardData,
        size: Vector2(90, 130),
        onLongPress: (c) => _showCardPreview(c.cardData),
        onDragEnded: _onCardDropped,
      );
      _handCards.add(dc);
      add(dc);
      dc.scale = Vector2.all(0.01);
      dc.add(
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.25, curve: Curves.easeOutBack),
        ),
      );
    }
    _layoutHand();
  }

  void _showCardPreview(CardData card) {
    combatLog.value = '${card.name} — ATK ${card.attack}';
    Future.delayed(const Duration(seconds: 3), () {
      if (combatLog.value.contains(card.name)) {
        combatLog.value = '';
      }
    });
  }

  void _onCardDropped(DraggableCard card) {
    if (state.phase != GamePhase.playerTurn || isProcessing.value) {
      card.returnToHome();
      return;
    }

    const cardCost = 2;
    if (state.energy < cardCost) {
      combatLog.value = 'Energía insuficiente (2 requerida)';
      card.returnToHome();
      return;
    }

    final slotRect = _playerSlot.toRect();
    final cardRect = card.toRect();

    if (!slotRect.overlaps(cardRect)) {
      card.returnToHome();
      return;
    }

    isProcessing.value = true;
    state.spendEnergy(2);

    final playerCard = card.cardData;
    final slotCenter = _playerSlot.position + _playerSlot.size / 2;
    card.animateToSlot(slotCenter);

    state.playerSlotCard = playerCard;
    _handCards.remove(card);
    state.playerHand.remove(playerCard);

    final hasEnemyCard = state.enemySlotCard != null;

    _delayed(400, () {
      card.removeFromParent();
      _playerCardView?.removeFromParent();
      _playerCardView = CardComponent(
        cardData: playerCard,
        size: Vector2(160, 215),
      );
      add(_playerCardView!);
      _playerCardView!.position = slotCenter;
      _animateCardEntry(_playerCardView!);

      if (hasEnemyCard) {
        _delayed(400, () => _runCombat(playerCard));
      } else {
        _logCombat('${playerCard.name} colocada. Esperando turno enemigo...');
        _endPlayerTurn();
      }
    });
  }

  void _endPlayerTurn() {
    isProcessing.value = false;
    state.phase = GamePhase.enemyTurn;
    state.notify();
    _delayed(100, () => _runEnemyTurn());
  }

  void _runCombat(CardData playerCard) {
    final enemyCard = state.enemySlotCard;
    if (enemyCard == null) {
      state.refillHands();
      _rebuildHand();
      _endPlayerTurn();
      return;
    }

    combatLog.value = '';
    battleManager.triggerOnPlay(playerCard);
    battleManager.triggerOnTurnStart();

    if (state.isGameOver) {
      isProcessing.value = false;
      return;
    }

    _playCombatFlash();

    _delayed(200, () {
      battleManager.resolveCombat(playerCard, enemyCard);

      _playerCardView?.add(_shakeEffect());
      _enemyCardView?.add(_shakeEffect());

      _spawnSlashEffect(_playerCardView?.position ?? Vector2.zero());
      _spawnSlashEffect(_enemyCardView?.position ?? Vector2.zero());
      _spawnDamageNumber(
          _enemyCardView?.position ?? Vector2.zero(), playerCard.attack, Colors.orangeAccent);
      _spawnDamageNumber(
          _playerCardView?.position ?? Vector2.zero(), enemyCard.attack, Colors.redAccent);

      _logCombat(
        '${playerCard.name} ATK ${playerCard.attack} → Enemigo -${playerCard.attack} HP\n'
        '${enemyCard.name} ATK ${enemyCard.attack} → Tú -${enemyCard.attack} HP',
      );

      _delayed(600, () {
        _animateCardRemoval(_playerCardView, () {
          _playerCardView?.removeFromParent();
          _playerCardView = null;
        });
        _animateCardRemoval(_enemyCardView, () {
          _enemyCardView?.removeFromParent();
          _enemyCardView = null;
        });

        _delayed(300, () {
          if (state.isGameOver) {
            _logCombat(state.playerWon ? '¡Victoria!' : 'Has perdido...');
            isProcessing.value = false;
            return;
          }

          state.refillHands();
          _rebuildHand();
          _endPlayerTurn();
        });
      });
    });
  }

  @override
  void pauseEngine() {
    paused = true;
  }

  @override
  void resumeEngine() {
    paused = false;
  }

  Future<void> _runEnemyTurn() async {
    if (state.isGameOver) return;
    if (state.phase != GamePhase.enemyTurn) return;

    state.gainEnergy();
    await _delay(600);
    if (state.isGameOver || state.phase != GamePhase.enemyTurn) return;

    if (state.enemyHand.isEmpty) {
      state.dealEnemyCard();
      if (state.enemyHand.isEmpty) return;
    }

    final enemyCard = state.enemyHand[_random.nextInt(state.enemyHand.length)];
    final slotCenter = _enemySlot.position + _enemySlot.size / 2;

    state.enemySlotCard = enemyCard;
    state.enemyHand.remove(enemyCard);

    _enemyCardView?.removeFromParent();
    _enemyCardView = CardComponent(
      cardData: enemyCard,
      size: Vector2(160, 215),
    );
    add(_enemyCardView!);
    _enemyCardView!.position = slotCenter;
    _enemyCardView!.scale = Vector2.all(0.01);
    _enemyCardView!.add(
      ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(duration: 0.4, curve: Curves.easeOutBack),
      ),
    );
    state.notify();

    if (state.playerSlotCard != null) {
      await _delay(500);
      if (state.isGameOver) return;
      final playerCard = state.playerSlotCard!;
      state.playerSlotCard = null;
      _runCombat(playerCard);
    } else {
      _logCombat('Enemigo colocó ${enemyCard.name}. Tu turno.');
      state.phase = GamePhase.playerTurn;
      state.notify();
    }
  }

  void _animateCardEntry(PositionComponent card) {
    card.scale = Vector2.all(0.01);
    card.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.15),
          EffectController(duration: 0.3, curve: Curves.easeOutBack),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.2),
        ),
      ]),
    );
  }

  void _animateCardRemoval(CardComponent? card, VoidCallback onDone) {
    if (card == null) {
      onDone();
      return;
    }
    card.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.1),
          EffectController(duration: 0.1),
        ),
        ScaleEffect.to(
          Vector2.all(0.01),
          EffectController(duration: 0.2, curve: Curves.easeIn),
        ),
      ]),
    );
    card.add(OpacityEffect.fadeOut(EffectController(duration: 0.3)));
    _delayed(350, onDone);
  }

  void _playCombatFlash() {
    final flash = RectangleComponent(
      position: Vector2.zero(),
      size: size,
      paint: Paint()..color = Colors.white.withValues(alpha: 0),
      priority: 100,
    );
    add(flash);
    flash.add(
      SequenceEffect([
        ColorEffect(
          Colors.white.withValues(alpha: 0.25),
          EffectController(duration: 0.08),
        ),
        ColorEffect(
          Colors.white.withValues(alpha: 0),
          EffectController(duration: 0.25),
        ),
      ]),
    );
    _delayed(400, () => flash.removeFromParent());
  }

  void _spawnSlashEffect(Vector2 pos) {
    final slash = FadingTextComponent(
      text: '⚔️',
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 48),
      ),
      position: pos - Vector2(24, 24),
      priority: 90,
    );
    add(slash);
    slash.add(
      MoveEffect.to(
        pos + Vector2(0, -60),
        EffectController(duration: 0.5, curve: Curves.easeOut),
      ),
    );
    slash.add(OpacityEffect.fadeOut(EffectController(duration: 0.5)));
    _delayed(600, () => slash.removeFromParent());
  }

  SequenceEffect _shakeEffect() {
    final orig = Vector2.zero();
    return SequenceEffect([
      MoveEffect.to(orig + Vector2(8, 0), EffectController(duration: 0.06)),
      MoveEffect.to(orig - Vector2(8, 0), EffectController(duration: 0.06)),
      MoveEffect.to(orig + Vector2(5, 0), EffectController(duration: 0.06)),
      MoveEffect.to(orig - Vector2(5, 0), EffectController(duration: 0.06)),
      MoveEffect.to(orig + Vector2(3, 0), EffectController(duration: 0.06)),
      MoveEffect.to(orig - Vector2(3, 0), EffectController(duration: 0.06)),
      MoveEffect.to(orig, EffectController(duration: 0.06)),
    ]);
  }

  void _spawnDamageNumber(Vector2 pos, int damage, Color color) {
    final dmg = FadingTextComponent(
      text: '-$damage',
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      position: pos - Vector2(24, 24),
      priority: 90,
    );
    add(dmg);
    dmg.add(
      MoveEffect.to(
        pos + Vector2(0, -80),
        EffectController(duration: 0.6, curve: Curves.easeOut),
      ),
    );
    dmg.add(OpacityEffect.fadeOut(EffectController(duration: 0.6)));
    _delayed(700, () => dmg.removeFromParent());
  }

  void _logCombat(String msg) {
    combatLog.value = msg;
  }

  void _delayed(int ms, VoidCallback fn) {
    Future.delayed(Duration(milliseconds: ms), fn);
  }

  Future<void> _delay(int ms) => Future.delayed(Duration(milliseconds: ms));
}
