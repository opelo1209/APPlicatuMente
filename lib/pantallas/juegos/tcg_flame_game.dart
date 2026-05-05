import 'dart:async' as async;
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MentalCardType { cognitivo, emocional, conductual, comodin, bossSoporte }

extension MentalCardTypeX on MentalCardType {
  String get label {
    switch (this) {
      case MentalCardType.cognitivo:
        return 'Cognitivo';
      case MentalCardType.emocional:
        return 'Emocional';
      case MentalCardType.conductual:
        return 'Conductual';
      case MentalCardType.comodin:
        return 'Comodín';
      case MentalCardType.bossSoporte:
        return 'Soporte';
    }
  }

  Color get color {
    switch (this) {
      case MentalCardType.cognitivo:
        return const Color(0xFF42A5F5);
      case MentalCardType.emocional:
        return const Color(0xFFEF5350);
      case MentalCardType.conductual:
        return const Color(0xFF66BB6A);
      case MentalCardType.comodin:
        return const Color(0xFFAB47BC);
      case MentalCardType.bossSoporte:
        return const Color(0xFF6A0DAD);
    }
  }
}

const String _boardAssetPath = 'assets/imagenes/tcg/tcg-tablero3.png';
const List<String> _cardArtPaths = <String>[
  'assets/imagenes/tcg/tcg0.jpg',
  'assets/imagenes/tcg/tcg1.jpg',
  'assets/imagenes/tcg/tcg2.jpg',
  'assets/imagenes/tcg/tcg3.jpg',
  'assets/imagenes/tcg/tcg4.jpg',
  'assets/imagenes/tcg/tcg5.jpg',
  'assets/imagenes/tcg/tcg6.jpg',
  'assets/imagenes/tcg/tcg7.jpg',
  'assets/imagenes/tcg/tcg8.jpg',
  'assets/imagenes/tcg/tcg9.jpg',
  'assets/imagenes/tcg/tcg10.jpg',
  'assets/imagenes/tcg/tcg11.jpg',
  'assets/imagenes/tcg/tcg12.jpg',
  'assets/imagenes/tcg/tcg13.jpg',
  'assets/imagenes/tcg/tcg14.jpg',
  'assets/imagenes/tcg/tcg16.jpg',
  'assets/imagenes/tcg/tcg17.jpg',
  'assets/imagenes/tcg/tcg18.jpg',
  'assets/imagenes/tcg/tcg19.jpg',
  'assets/imagenes/tcg/tcg20.jpg',
  'assets/imagenes/tcg/tcg21.jpg',
  'assets/imagenes/tcg/tcg22.jpg',
  'assets/imagenes/tcg/tcg23.jpg',
  'assets/imagenes/tcg/tcg24.jpg',
  'assets/imagenes/tcg/tcg25.jpg',
  'assets/imagenes/tcg/tcg26.jpg',
  'assets/imagenes/tcg/tcg27.jpg',
  'assets/imagenes/tcg/tcg28.jpg',
  'assets/imagenes/tcg/tcg29.jpg',
  'assets/imagenes/tcg/tcg30.jpg',
  'assets/imagenes/tcg/tcg31.jpg',
  'assets/imagenes/tcg/tcg32.jpg',
  'assets/imagenes/tcg/tcg33.jpg',
  'assets/imagenes/tcg/tcg34.jpg',
  'assets/imagenes/tcg/tcg35.jpg',
  'assets/imagenes/tcg/tcg36.jpg',
  'assets/imagenes/tcg/tcg37.jpg',
  'assets/imagenes/tcg/tcg38.jpg',
  'assets/imagenes/tcg/tcg39.jpg',
  'assets/imagenes/tcg/tcg40.jpg',
];

// --- ZONA DE CONFIGURACIÓN ---
// 1. Jefe (Boss) - No tiene zona de drop, solo posición visual
const double _bossCardWidth = 122.0;
const double _bossCardHeight = 148.0;
const double _bossPosYRatio =
    0.255; // Altura (0.0 es arriba del todo, 1.0 es abajo del todo)

// 2. Jugador (Carta central) y su Zona de Drop
const double _playerCardWidth = 128.0;
const double _playerCardHeight = 175.0;
const double _playerPosYRatio = 0.470; // Altura

//Que tan grande es la caja invisible para soltar la carta central.
const double _mainDropZoneWidth = 160.0;
const double _mainDropZoneHeight = 220.0;

// 2b. Cartas de Soporte del Boss (slots superiores)
const double _bossSupportCardWidth = 80.6;
const double _bossSupportCardHeight = 100.0;
const double _bossSupportPosYRatio = 0.115;
const double _bossSupportGap = 10.7;

// 3. Cartas Inferiores (Poder) y sus Zonas de Drop
const double _powerCardWidth = 83.0;
const double _powerCardHeight = 119.0;
const double _powerPosYRatio = 0.709; // Altura de la línea de 3 cartas
const double _powerDropGap = 22.0; // Espacio (hueco) entre las 3 cartas

// Qué tan grandes son los rectángulos invisibles para soltar cartas abajo.
const double _powerDropZoneWidth = 110.0;
const double _powerDropZoneHeight = 150.0;

// 4. Cartas en la mano
const double _handCardWidth = 92.0;
const double _handCardHeight = 132.0;
const double _handCardOverlapRatio = 0.40;
const double _handSidePadding = 12.0;
const double _handFanMaxAngleDeg = 25.0; // inclinacion
const double _handFanCenterLift = 8.0;
const double _handFanCurveDrop = 14.0; //curvatura
const double _handSelectedLift = 42.0;
const double _handSelectedScale = 1.16;
const double _handSelectedAngleFactor =
    0.0; // Hace que la carta se ponga recta al seleccionarla
const double _handBottomMargin = 6.0;
const int _handSelectedPriority = 80;
const int _handBasePriority = 20;
const int _powerSlotCount = 3;
const int _baseHealthPoints = 25;
const int _initialMana = 3;
const int _maxManaPerTurn = 10;
// -----------------------------------------------------------------

class MentalCard {
  const MentalCard({
    required this.id,
    required this.name,
    required this.type,
    required this.energyCost,
    required this.power,
  });

  final String id;
  final String name;
  final MentalCardType type;
  final int energyCost;
  final int power;
}

class MentalTcgGame extends FlameGame {
  MentalTcgGame();

  final Random _random = Random();

  late final PositionComponent _background;
  late final RectangleComponent _backgroundTint;
  late final DropZoneComponent _dropZone;
  late final List<PowerDropZoneComponent> _powerZones;

  final List<DraggableCardComponent> _handCards = <DraggableCardComponent>[];
  final List<MentalCard> _drawPile = <MentalCard>[];
  final List<CardFaceComponent?> _powerCardViews =
      List<CardFaceComponent?>.filled(_powerSlotCount, null);
  final List<CardFaceComponent?> _bossSupportCardViews =
      List<CardFaceComponent?>.filled(_powerSlotCount, null);
  final ValueNotifier<String?> previewArtPath = ValueNotifier<String?>(null);
  final ValueNotifier<int> playerScore = ValueNotifier<int>(0);
  final ValueNotifier<int> bossScore = ValueNotifier<int>(0);
  final ValueNotifier<int> playerHpNotifier = ValueNotifier<int>(
    _baseHealthPoints,
  );
  final ValueNotifier<int> bossHpNotifier = ValueNotifier<int>(
    _baseHealthPoints,
  );
  final ValueNotifier<String> hintTextNotifier = ValueNotifier<String>('');
  final ValueNotifier<int> manaNotifier = ValueNotifier<int>(_initialMana);
  final ValueNotifier<int> manaCapNotifier = ValueNotifier<int>(_initialMana);
  final ValueNotifier<int> bossManaNotifier = ValueNotifier<int>(_initialMana);
  final ValueNotifier<int> bossManaCapNotifier = ValueNotifier<int>(
    _initialMana,
  );
  final ValueNotifier<String?> coinTossNotifier = ValueNotifier<String?>(null);
  async.Timer? _hintTimer;

  DraggableCardComponent? _selectedHandCard;

  CardFaceComponent? _bossCardView;
  CardFaceComponent? _playerFieldCardView;
  MentalCard? _bossCard;

  int get playerHp => playerHpNotifier.value;
  set playerHp(int value) => playerHpNotifier.value = value;

  int get bossHp => bossHpNotifier.value;
  set bossHp(int value) => bossHpNotifier.value = value;

  int get mana => manaNotifier.value;
  set mana(int value) => manaNotifier.value = value;

  int get manaCap => manaCapNotifier.value;
  set manaCap(int value) => manaCapNotifier.value = value;

  int get bossMana => bossManaNotifier.value;
  set bossMana(int value) => bossManaNotifier.value = value;

  int get bossManaCap => bossManaCapNotifier.value;
  set bossManaCap(int value) => bossManaCapNotifier.value = value;

  int get baseHealthPoints => _baseHealthPoints;
  int get maxManaPerTurn => _maxManaPerTurn;

  int turn = 1;
  bool _isFinished = false;

  int _nextAttackBonus = 0;
  bool _bossAttackCancelled = false;
  bool _playerHealBlocked = false;
  bool _playerHealCancelledThisTurn = false;
  bool? playerGoesFirst;
  bool turnSummaryActive = false;
  final canPassTurnNotifier = ValueNotifier<bool>(false);

  bool get isFinished => _isFinished;

  void _updateCanPassTurn() {
    canPassTurnNotifier.value = !_isFinished &&
                                coinTossNotifier.value == null && 
                                playerGoesFirst != null && 
                                !turnSummaryActive &&
                                _playerFieldCardView != null;
  }

  @override
  Future<void> onLoad() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await super.onLoad();

    images.prefix = '';

    await images.load(_boardAssetPath);
    for (final artPath in _cardArtPaths) {
      await images.load(artPath);
    }

    try {
      _background = SpriteComponent(
        sprite: Sprite(images.fromCache(_boardAssetPath)),
        priority: -100,
      );
    } catch (_) {
      _background = RectangleComponent(
        paint: Paint()..color = const Color(0xFF10261E),
        priority: -100,
      );
    }
    add(_background);

    _backgroundTint = RectangleComponent(
      paint: Paint()..color = const Color(0x22000000),
      priority: -90,
    );
    add(_backgroundTint);

    _dropZone = DropZoneComponent();
    add(_dropZone);

    _powerZones = List<PowerDropZoneComponent>.generate(
      _powerSlotCount,
      (_) => PowerDropZoneComponent(),
    );
    for (final zone in _powerZones) {
      add(zone);
    }

    resetMatch();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isLoaded) {
      return;
    }
    _layoutBoard();
  }

  void resetMatch() {
    hideCardPreview();

    for (final card in _handCards) {
      card.removeFromParent();
    }
    _handCards.clear();
    _selectedHandCard = null;

    _bossCardView?.removeFromParent();
    _bossCardView = null;

    _playerFieldCardView?.removeFromParent();
    _playerFieldCardView = null;

    for (var i = 0; i < _powerCardViews.length; i++) {
      _powerCardViews[i]?.removeFromParent();
      _powerCardViews[i] = null;
    }

    for (var i = 0; i < _bossSupportCardViews.length; i++) {
      _bossSupportCardViews[i]?.removeFromParent();
      _bossSupportCardViews[i] = null;
    }

    playerHp = _baseHealthPoints;
    bossHp = _baseHealthPoints;
    turn = 1;
    manaCap = _initialMana;
    mana = _initialMana;
    bossManaCap = _initialMana;
    bossMana = _initialMana;
    _isFinished = false;
    _nextAttackBonus = 0;
    _bossAttackCancelled = false;
    _playerHealBlocked = false;
    _playerHealCancelledThisTurn = false;
    playerGoesFirst = null;
    turnSummaryActive = false;
    hintTextNotifier.value = '';
    _hintTimer?.cancel();
    _updateCanPassTurn();

    _refillDrawPile();
    _drawUntilHandSize(4);

    _layoutBoard();
    _startCoinToss(isFirstTurn: true);
  }

  void newSession() {
    playerScore.value = 0;
    bossScore.value = 0;
    resetMatch();
  }

  void _drawUntilHandSize(int targetSize) {
    while (_handCards.length < targetSize) {
      final card = _takeToolCard();
      final cardView = DraggableCardComponent(
        card: card,
        onDropped: _handleDrop,
        onFocused: _focusHandCard,
        cardSize: Vector2(_handCardWidth, _handCardHeight),
      );
      _handCards.add(cardView);
      add(cardView);
    }
  }

  void _focusHandCard(DraggableCardComponent cardView) {
    if (_isFinished || !_handCards.contains(cardView)) {
      return;
    }
    if (_selectedHandCard == cardView) {
      return;
    }
    _selectedHandCard = cardView;
    _layoutHand();
  }

  MentalCard _takeToolCard() {
    if (_drawPile.isEmpty) {
      _refillDrawPile();
    }
    return _drawPile.removeLast();
  }

  void _refillDrawPile() {
    _drawPile
      ..clear()
      ..addAll(_toolCardPool)
      ..addAll(_comodinesCardPool)
      ..shuffle(_random);
  }

  void _spawnBossCard() {
    _bossCard = _bossCardPool[_random.nextInt(_bossCardPool.length)];
    _bossCardView?.removeFromParent();
    _bossCardView = CardFaceComponent(
      card: _bossCard!,
      cardSize: Vector2(_bossCardWidth, _bossCardHeight),
    );
    add(_bossCardView!);
    _animateEnemyDeploy(_bossCardView!);

    // Spawn boss support cards (1-2 random from pool)
    for (var i = 0; i < _bossSupportCardViews.length; i++) {
      _bossSupportCardViews[i]?.removeFromParent();
      _bossSupportCardViews[i] = null;
    }
    _playerHealBlocked = false;
    _playerHealCancelledThisTurn = false;

    final available = List<MentalCard>.from(_bossSoporteCardPool)
      ..shuffle(_random);
    int count = 1;
    if (bossManaCap >= 5) count = 1 + _random.nextInt(2);
    if (bossManaCap >= 8) count = 1 + _random.nextInt(3);
    final slots = [0, 1, 2]..shuffle(_random);

    int currentBossMana = bossMana;
    int cardsPlayed = 0;

    for (var k = 0; k < count; k++) {
      final card = available[k];
      if (currentBossMana >= card.energyCost) {
        currentBossMana -= card.energyCost;

        final view = CardFaceComponent(
          card: card,
          cardSize: Vector2(_bossSupportCardWidth, _bossSupportCardHeight),
        );
        _bossSupportCardViews[slots[cardsPlayed]] = view;
        add(view);
        _animateSupportDeploy(view, cardsPlayed);

        if (card.id == 'bsoporte_37') _playerHealBlocked = true;
        if (card.id == 'bsoporte_38') _playerHealCancelledThisTurn = true;

        cardsPlayed++;
      }
    }

    bossMana = currentBossMana;
  }

  void _handleDrop(DraggableCardComponent cardView) {
    if (_isFinished || coinTossNotifier.value != null || playerGoesFirst == null || turnSummaryActive) {
      cardView.returnToHome();
      return;
    }

    final powerSlotIndex = _findPowerSlotAt(cardView);
    if (powerSlotIndex != -1) {
      _dropOnPowerSlot(cardView, powerSlotIndex);
      return;
    }

    final droppedInZone = _dropZone.toRect().overlaps(cardView.toRect());
    if (!droppedInZone) {
      cardView.returnToHome();
      return;
    }

    final card = cardView.card;
    if (card.type == MentalCardType.comodin) {
      cardView.returnToHome();
      return;
    }

    if (_playerFieldCardView != null) {
      cardView.returnToHome();
      return;
    }

    if (mana < card.energyCost) {
      _setHint(
        'No hay energia suficiente para ${card.name}. Costo ${card.energyCost}.',
      );
      cardView.returnToHome();
      return;
    }

    if (_selectedHandCard == cardView) {
      _selectedHandCard = null;
    }
    _handCards.remove(cardView);
    cardView.removeFromParent();

    mana -= card.energyCost;
    _placeOnField(card);
    _layoutBoard();
    _updateCanPassTurn();
  }

  int _findPowerSlotAt(DraggableCardComponent cardView) {
    for (var i = 0; i < _powerZones.length; i++) {
      if (_powerZones[i].toRect().overlaps(cardView.toRect())) {
        return i;
      }
    }
    return -1;
  }

  void _dropOnPowerSlot(DraggableCardComponent cardView, int slotIndex) {
    if (_powerCardViews[slotIndex] != null) {
      cardView.returnToHome();
      return;
    }

    final card = cardView.card;
    if (card.type != MentalCardType.comodin) {
      cardView.returnToHome();
      return;
    }

    if (mana < card.energyCost) {
      _setHint(
        'No hay energia suficiente para ${card.name}. Costo ${card.energyCost}.',
      );
      cardView.returnToHome();
      return;
    }

    if (_selectedHandCard == cardView) {
      _selectedHandCard = null;
    }
    _handCards.remove(cardView);
    cardView.removeFromParent();

    mana -= card.energyCost;

    final powerCardView = CardFaceComponent(
      card: card,
      cardSize: Vector2(_powerCardWidth, _powerCardHeight),
    );
    _powerCardViews[slotIndex] = powerCardView;
    add(powerCardView);
    _animatePowerDeploy(powerCardView);

    // Ejecutar efecto del comodín
    if (card.type == MentalCardType.comodin) {
    if (card.id == 'comodin_31') {
        // Pausa de Respiración
        if (_playerHealBlocked) {
          _setHint(
            'Culpa y Vergüenza bloquea la recuperación de ${card.name}.',
          );
        } else if (_playerHealCancelledThisTurn) {
          _playerHealCancelledThisTurn = false;
          _setHint('Gaslighting cancela la recuperación de ${card.name}.');
        } else {
          playerHp = min(_baseHealthPoints, playerHp + 4);
          _setHint('Pausa de Respiración: +4 HP');
        }
      } else if (card.id == 'comodin_32') {
        // Red de Apoyo Activa
        if (_playerHealBlocked) {
          _setHint(
            'Culpa y Vergüenza bloquea la recuperación de ${card.name}.',
          );
        } else if (_playerHealCancelledThisTurn) {
          _playerHealCancelledThisTurn = false;
          _setHint('Gaslighting cancela la recuperación de ${card.name}.');
        } else {
          playerHp = min(_baseHealthPoints, playerHp + 6);
          _setHint('Red de Apoyo Activa: +6 HP');
        }
      } else if (card.id == 'comodin_33') {
        // Enfoque con Intención
        _nextAttackBonus += 3;
        _setHint('Enfoque con Intención: Próximo ataque +3');
      } else if (card.id == 'comodin_34') {
        // Romper el Bucle
        _bossAttackCancelled = true;
        _setHint('Romper el Bucle: Ataque de Boss cancelado');
      } else if (card.id == 'comodin_35') {
        // Tablero Organizado
        if (_handCards.isNotEmpty) {
          final randomCard = _handCards[_random.nextInt(_handCards.length)];
          _handCards.remove(randomCard);
          randomCard.removeFromParent();
        }
        // Robar 2 (El máximo es irrelevante si es un efecto especial, podemos forzar dibujo)
        for (var i = 0; i < 2; i++) {
          if (_handCards.length < 10) {
            // Un pequeño cap de mano
            final c = _takeToolCard();
            final cView = DraggableCardComponent(
              card: c,
              onDropped: _handleDrop,
              onFocused: _focusHandCard,
              cardSize: Vector2(_handCardWidth, _handCardHeight),
            );
            _handCards.add(cView);
            add(cView);
          }
        }
        _setHint('Tablero Organizado: Cambiaste 1 carta por 2');
      }
    }

    _layoutBoard();
  }

  void passTurn() {
    if (!canPassTurnNotifier.value) return;
    
    // El boss juega sus cartas después de que el usuario finaliza su turno si el jugador tiene la iniciativa
    turnSummaryActive = true;
    _updateCanPassTurn();

    if (playerGoesFirst == true) {
      _spawnBossCard();
      _layoutBoard();

      // Esperamos 3 segundos para que el usuario vea qué cartas tiró el boss
      Future.delayed(const Duration(seconds: 3), () {
        if (_isFinished || playerGoesFirst == null) return;
        _resolveTurnFromBoard(playerGoesFirst!);
      });
    } else {
      // El Boss ya tiró sus cartas al inicio del turno
      _resolveTurnFromBoard(playerGoesFirst!);
    }
  }

  void _startCoinToss({bool isFirstTurn = false}) {
    coinTossNotifier.value = 'flip';
    final tossResult = _random.nextBool();
    
    Future.delayed(const Duration(seconds: 2), () {
      if (_isFinished) return;
      coinTossNotifier.value = tossResult ? 'player' : 'boss';
      _updateCanPassTurn();
      
      Future.delayed(const Duration(seconds: 2), () {
        if (_isFinished) return;
        coinTossNotifier.value = null;
        playerGoesFirst = tossResult;

        if (isFirstTurn) {
          if (playerGoesFirst == false) {
             _spawnBossCard();
          }
          _layoutBoard();
        }
        _updateCanPassTurn();
      });
    });
  }

  void _resolveTurnFromBoard(bool playerGoesFirstTurn) {
    final bossCard = _bossCard!;
    final playerCard = _playerFieldCardView?.card;
    final logParts = <String>[];

    void playerAttack() {
      if (playerCard != null) {
        final playerMultiplier = _multiplier(playerCard.type, bossCard.type);
        final playerDamage =
            _scaledDamage(playerCard.power, playerMultiplier) + _nextAttackBonus;
        _nextAttackBonus = 0;
        bossHp = max(0, bossHp - playerDamage);

        logParts.add(
          'Tú: $playerDamage Daño (${_multiplierLabel(playerMultiplier)})',
        );
      } else {
        logParts.add('Tú: 0 Daño');
      }
    }

    void bossAttack() {
      if (_bossAttackCancelled) {
        _bossAttackCancelled = false;
        logParts.add('Boss: Atac. Cancelado');
      } else {
        final bossMultiplier = playerCard == null
            ? 1.0
            : _multiplier(bossCard.type, playerCard.type);
        final bossDamage = _scaledDamage(bossCard.power, bossMultiplier);
        playerHp = max(0, playerHp - bossDamage);

        logParts.add(
          'Boss: $bossDamage Daño (${_multiplierLabel(bossMultiplier)})',
        );
      }
    }

    void bossSupports() {
      for (var i = 0; i < _bossSupportCardViews.length; i++) {
        final supportView = _bossSupportCardViews[i];
        if (supportView == null) continue;
        final sc = supportView.card;
        if (sc.id == 'bsoporte_36') {
          playerHp = max(0, playerHp - 6);
          logParts.add('Sobrecarga Tóxica: -6 HP');
        } else if (sc.id == 'bsoporte_37') {
          logParts.add('Culpa y Vergüenza activa');
        } else if (sc.id == 'bsoporte_38') {
          logParts.add('Gaslighting activo');
        } else if (sc.id == 'bsoporte_39') {
          if (_handCards.isNotEmpty) {
            final discarded = _handCards[_random.nextInt(_handCards.length)];
            _handCards.remove(discarded);
            discarded.removeFromParent();
            logParts.add('Manipulación: Pierdes 1 carta');
          }
        } else if (sc.id == 'bsoporte_40') {
          final steal = min(2, playerHp);
          playerHp = max(0, playerHp - steal);
          bossHp = min(_baseHealthPoints, bossHp + steal);
          logParts.add('Drenaje: Roba $steal HP');
        }
      }
    }

    if (playerGoesFirstTurn) {
      playerAttack();
      if (bossHp <= 0) {
        _isFinished = true;
        _setHint('¡Ganaste!', isTurnSummary: true);
        _layoutBoard();
        return;
      }
      bossSupports();
      if (playerHp <= 0) {
        _isFinished = true;
        _setHint('${logParts.join('\n')}\nPerdiste.', isTurnSummary: true);
        _layoutBoard();
        return;
      }
      bossAttack();
    } else {
      bossSupports();
      if (playerHp <= 0) {
        _isFinished = true;
        _setHint('${logParts.join('\n')}\nPerdiste.', isTurnSummary: true);
        _layoutBoard();
        return;
      }
      bossAttack();
      if (playerHp <= 0) {
        _isFinished = true;
        _setHint('${logParts.join('\n')}\nPerdiste.', isTurnSummary: true);
        _layoutBoard();
        return;
      }
      playerAttack();
    }

    if (playerHp <= 0) {
      _isFinished = true;
      _setHint('${logParts.join('\n')}\nPerdiste.', isTurnSummary: true);
      _layoutBoard();
      return;
    }

    if (bossHp <= 0) {
      _isFinished = true;
      _setHint('${logParts.join('\n')}\n¡Ganaste!', isTurnSummary: true);
      _layoutBoard();
      return;
    }

    _setHint(logParts.join('\n'), isTurnSummary: true);
    _layoutBoard();

    Future.delayed(const Duration(milliseconds: 3500), () {
      if (_isFinished) return;
      _advanceTurn();
      _layoutBoard();
    });
  }

  int _scaledDamage(int basePower, double factor) {
    final raw = (basePower * factor).round();
    return max(1, raw);
  }

  double _multiplier(MentalCardType attacker, MentalCardType defender) {
    if (attacker == defender) {
      return 1;
    }
    if (attacker == MentalCardType.cognitivo &&
        defender == MentalCardType.emocional) {
      return 2;
    }
    if (attacker == MentalCardType.emocional &&
        defender == MentalCardType.conductual) {
      return 2;
    }
    if (attacker == MentalCardType.conductual &&
        defender == MentalCardType.cognitivo) {
      return 2;
    }
    return 0.5;
  }

  String _multiplierLabel(double value) {
    if (value == 2) {
      return 'x2';
    }
    if (value == 0.5) {
      return 'x0.5';
    }
    return 'x1';
  }

  void _advanceTurn() {
    turn += 1;
    _playerFieldCardView?.removeFromParent();
    _playerFieldCardView = null;

    for (var i = 0; i < _powerCardViews.length; i++) {
      _powerCardViews[i]?.removeFromParent();
      _powerCardViews[i] = null;
    }

    for (var i = 0; i < _bossSupportCardViews.length; i++) {
      _bossSupportCardViews[i]?.removeFromParent();
      _bossSupportCardViews[i] = null;
    }
    _playerHealBlocked = false;
    _playerHealCancelledThisTurn = false;

    manaCap = min(_maxManaPerTurn, manaCap + 1);
    mana = manaCap;
    bossManaCap = min(_maxManaPerTurn, bossManaCap + 1);
    bossMana = bossManaCap;
    _drawUntilHandSize(4);
    
    if (playerGoesFirst == false) {
      _spawnBossCard();
    }
    _updateCanPassTurn();
  }

  void _placeOnField(MentalCard card) {
    _playerFieldCardView?.removeFromParent();
    _playerFieldCardView = CardFaceComponent(
      card: card,
      cardSize: Vector2(_playerCardWidth, _playerCardHeight),
    );
    add(_playerFieldCardView!);
    _animatePlayerDeploy(_playerFieldCardView!);
  }

  void _animateEnemyDeploy(CardFaceComponent cardView) {
    cardView.scale = Vector2.all(0.6);
    cardView.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.15),
          EffectController(duration: 0.25, curve: Curves.easeOutBack),
        ),
        ScaleEffect.to(
          Vector2.all(1),
          EffectController(duration: 0.20, curve: Curves.easeInOut),
        ),
      ]),
    );
  }

  void _animateSupportDeploy(CardFaceComponent cardView, int index) {
    cardView.scale = Vector2.all(0.1);
    
    Future.delayed(Duration(milliseconds: 250 * index), () {
      cardView.add(
        SequenceEffect([
          ScaleEffect.to(
            Vector2.all(1.15),
            EffectController(duration: 0.35, curve: Curves.easeOutBack),
          ),
          ScaleEffect.to(
            Vector2.all(1.0),
            EffectController(duration: 0.20, curve: Curves.easeInOut),
          ),
        ]),
      );

      final targetY = cardView.position.y;
      cardView.position.y -= 250;
      cardView.add(
        MoveEffect.to(
          Vector2(cardView.position.x, targetY),
          EffectController(duration: 0.55, curve: Curves.bounceOut),
        ),
      );
    });
  }

  void _animatePlayerDeploy(CardFaceComponent cardView) {
    cardView.scale = Vector2.all(0.6);
    cardView.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.20),
          EffectController(duration: 0.30, curve: Curves.easeOutBack),
        ),
        ScaleEffect.to(
          Vector2.all(1),
          EffectController(duration: 0.20, curve: Curves.easeInOut),
        ),
      ]),
    );
  }

  void _animatePowerDeploy(CardFaceComponent cardView) {
    cardView.scale = Vector2.all(0.6);
    cardView.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.15),
          EffectController(duration: 0.25, curve: Curves.easeOutBack),
        ),
        ScaleEffect.to(
          Vector2.all(1),
          EffectController(duration: 0.18, curve: Curves.easeInOut),
        ),
      ]),
    );
  }

  void showCardPreview(MentalCard card) {
    previewArtPath.value = _artPathForCard(card);
  }

  void hideCardPreview() {
    if (previewArtPath.value == null) {
      return;
    }
    previewArtPath.value = null;
  }

  void _setHint(String text, {bool isTurnSummary = false}) {
    hintTextNotifier.value = text;
    turnSummaryActive = isTurnSummary;
    _updateCanPassTurn();
    _hintTimer?.cancel();
    if (text.isNotEmpty) {
      _hintTimer = async.Timer(const Duration(milliseconds: 3500), () {
        hintTextNotifier.value = '';
        turnSummaryActive = false;
        _updateCanPassTurn();
      });
    }
  }

  void _layoutBoard() {
    _background
      ..position = Vector2.zero()
      ..size = size;

    _backgroundTint
      ..position = Vector2.zero()
      ..size = size;

    // --- POSICIONES X e Y CALCULADAS SEGÚN EL ESPACIO ---
    final bossY = size.y * _bossPosYRatio;
    final playerY = size.y * _playerPosYRatio;
    final powerY = size.y * _powerPosYRatio;

    // Centros X visuales para las cartas de arriba
    final bossCenterX = (size.x - _bossCardWidth) / 2;
    final playerCenterX = (size.x - _playerCardWidth) / 2;

    // 1. DIBUJAR CAJA DE DROP PRINCIPAL INDEPENDIENTE
    // La ubicamos exactamente en el mismo centro X e Y que dibujamos la carta del jugador
    final mainDropCenterX = playerCenterX + (_playerCardWidth / 2);
    final mainDropCenterY = playerY + (_playerCardHeight / 2);
    _dropZone
      ..position = Vector2(
        mainDropCenterX - (_mainDropZoneWidth / 2),
        mainDropCenterY - (_mainDropZoneHeight / 2),
      )
      ..size = Vector2(_mainDropZoneWidth, _mainDropZoneHeight)
      ..refreshLayout();

    // Boss support cards row (above boss card)
    final totalSupportWidth =
        (_bossSupportCardWidth * _powerSlotCount) +
        (_bossSupportGap * (_powerSlotCount - 1));
    final supportStartX = (size.x - totalSupportWidth) / 2;
    final supportY = size.y * _bossSupportPosYRatio;
    for (var i = 0; i < _bossSupportCardViews.length; i++) {
      final cardX =
          supportStartX + (i * (_bossSupportCardWidth + _bossSupportGap));
      _bossSupportCardViews[i]?.position = Vector2(cardX, supportY);
    }

    _bossCardView?.position = Vector2(bossCenterX, bossY);
    _playerFieldCardView?.position = Vector2(playerCenterX, playerY);

    // 2. DIBUJAR CAJAS DE DROP INFERIORES INDEPENDIENTES
    final totalPowerWidth =
        (_powerCardWidth * _powerSlotCount) +
        (_powerDropGap * (_powerSlotCount - 1));
    final powerStartX = (size.x - totalPowerWidth) / 2;

    for (var i = 0; i < _powerZones.length; i++) {
      // Posición final de la carta si es colocada aquí
      final cardX = powerStartX + (i * (_powerCardWidth + _powerDropGap));

      // Posición del RECÚADRO que detecta cuando la sueltas (centrado alrededor del 'slot' de la carta)
      final dropX = cardX + (_powerCardWidth / 2) - (_powerDropZoneWidth / 2);
      final dropY =
          powerY + (_powerCardHeight / 2) - (_powerDropZoneHeight / 2);

      _powerZones[i]
        ..position = Vector2(dropX, dropY)
        ..size = Vector2(_powerDropZoneWidth, _powerDropZoneHeight)
        ..refreshLayout();

      _powerCardViews[i]?.position = Vector2(cardX, powerY);
    }

    _layoutHand();
  }

  void _layoutHand() {
    if (_handCards.isEmpty) {
      _selectedHandCard = null;
      return;
    }

    if (_selectedHandCard == null || !_handCards.contains(_selectedHandCard)) {
      _selectedHandCard = _handCards[_handCards.length ~/ 2];
    }

    final count = _handCards.length;
    final overlap = _handCardOverlapRatio.clamp(0.15, 0.75).toDouble();
    final nominalStep = _handCardWidth * (1 - overlap);
    final availableWidth = max(0.0, size.x - (_handSidePadding * 2));
    final maxStepByScreen = count > 1
        ? max(0.0, (availableWidth - _handCardWidth) / (count - 1))
        : 0.0;
    final step = count > 1 ? min(nominalStep, maxStepByScreen) : 0.0;
    final fanWidth = _handCardWidth + (step * (count - 1));
    final startCenterX = (size.x - fanWidth) / 2 + (_handCardWidth / 2);
    final maxAngleRad = _handFanMaxAngleDeg * pi / 180;
    final baseCenterY =
        size.y - (_handCardHeight / 2) - _handBottomMargin - _handFanCurveDrop;

    for (var i = 0; i < count; i++) {
      final cardView = _handCards[i];
      final t = count == 1 ? 0.0 : ((i / (count - 1)) * 2) - 1;
      final arcDrop = pow(t.abs(), 1.8).toDouble() * _handFanCurveDrop;
      final centerLift = (1 - t.abs()) * _handFanCenterLift;
      final isSelected = identical(cardView, _selectedHandCard);
      final selectedLift = isSelected ? _handSelectedLift : 0.0;
      final baseAngle = t * maxAngleRad;
      final handAngle = isSelected
          ? baseAngle * _handSelectedAngleFactor
          : baseAngle;

      final homeCenter = Vector2(
        startCenterX + (i * step),
        baseCenterY + arcDrop - centerLift - selectedLift,
      );

      cardView.setHomeLayout(
        homeCenter,
        angle: handAngle,
        scale: isSelected ? _handSelectedScale : 1.0,
        priority: isSelected ? _handSelectedPriority : (_handBasePriority + i),
        moveNow: !cardView.isDragging,
      );
    }
  }
}

class DropZoneComponent extends PositionComponent {
  var _ready = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Las zonas de drop ahora son invisibles (transparentes). No hay glow ni border blanco de guía
    _ready = true;
    refreshLayout();
  }

  void refreshLayout() {
    if (!_ready) {
      return;
    }
  }
}

class PowerDropZoneComponent extends PositionComponent {
  var _ready = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Las zonas de drop ahora son invisibles (transparentes). No hay glow ni border blanco de guía
    _ready = true;
    refreshLayout();
  }

  void refreshLayout() {
    if (!_ready) {
      return;
    }
  }
}

class CardFaceComponent extends PositionComponent
    with HasGameReference<MentalTcgGame>, TapCallbacks {
  CardFaceComponent({required this.card, required Vector2 cardSize})
    : super(size: cardSize);

  final MentalCard card;
  static const double _previewHoldDelay = 0.22;

  bool _isPressing = false;
  double _pressElapsed = 0;
  bool _previewVisible = false;
  Sprite? _sprite;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final imagePath = _artPathForCard(card);
    try {
      _sprite = Sprite(game.images.fromCache(imagePath));
    } catch (_) {
      _sprite = await Sprite.load(imagePath);
    }
  }

  @override
  void render(Canvas canvas) {
    final cardRadius = Radius.circular(8.0); // Ajusta el radio según tus cartas
    final cardRRect = RRect.fromRectAndRadius(size.toRect(), cardRadius);

    // 1. Sombra redondeada
    final shadowRRect = RRect.fromRectAndRadius(
      size.toRect().shift(const Offset(6, 10)),
      cardRadius,
    );
    canvas.drawRRect(
      shadowRRect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0),
    );

    // 2. Imagen de la carta (Usando ClipRRect en Canvas es posible haciendo save() y clipRRect())
    canvas.save();
    canvas.clipRRect(cardRRect);
    _sprite?.render(canvas, size: size);
    canvas.restore();

    // 3. Borde de color redondeado
    canvas.drawRRect(
      cardRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = card.type.color.withValues(alpha: 0.9),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isPressing || _previewVisible) {
      return;
    }

    _pressElapsed += dt;
    if (_pressElapsed >= _previewHoldDelay) {
      _previewVisible = true;
      game.showCardPreview(card);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    _isPressing = true;
    _pressElapsed = 0;
  }

  @override
  void onLongTapDown(TapDownEvent event) {
    super.onLongTapDown(event);
    _previewVisible = true;
    game.showCardPreview(card);
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    _cancelPressPreview();
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    super.onTapCancel(event);
    _cancelPressPreview();
  }

  void _cancelPressPreview() {
    _isPressing = false;
    _pressElapsed = 0;
    if (_previewVisible) {
      game.hideCardPreview();
    }
    _previewVisible = false;
  }

  void cancelPreviewFromExternalGesture() {
    _cancelPressPreview();
  }

  @override
  void onRemove() {
    _cancelPressPreview();
    super.onRemove();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _cancelPressPreview();
    game.hideCardPreview();
  }
}

class DraggableCardComponent extends CardFaceComponent with DragCallbacks {
  DraggableCardComponent({
    required super.card,
    required this.onDropped,
    required this.onFocused,
    required super.cardSize,
  }) {
    anchor = Anchor.center;
  }

  final void Function(DraggableCardComponent card) onDropped;
  final void Function(DraggableCardComponent card) onFocused;
  Vector2 _homePosition = Vector2.zero();
  double _homeAngle = 0;
  double _homeScale = 1;
  int _homePriority = _handBasePriority;
  bool _isDragging = false;

  bool get isDragging => _isDragging;

  void setHomeLayout(
    Vector2 nextHome, {
    required double angle,
    required double scale,
    required int priority,
    bool moveNow = true,
  }) {
    _homePosition = nextHome.clone();
    _homeAngle = angle;
    _homeScale = scale;
    _homePriority = priority;
    if (moveNow) {
      position.setFrom(nextHome);
      this.angle = angle;
      this.scale = Vector2.all(scale);
      this.priority = priority;
    }
  }

  void returnToHome() {
    position.setFrom(_homePosition);
    angle = _homeAngle;
    scale = Vector2.all(_homeScale);
    priority = _homePriority;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (!_isDragging) {
      onFocused(this);
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    onFocused(this);
    cancelPreviewFromExternalGesture();
    _isDragging = true;
    angle = 0;
    scale = Vector2.all(1.04);
    priority = 100;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    position.add(event.localDelta);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _isDragging = false;
    onDropped(this);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _isDragging = false;
    returnToHome();
  }
}

String _artPathForCard(MentalCard card) {
  final cardNumber = int.tryParse(card.id.split('_').last) ?? 0;
  final index = _cardArtPaths.indexWhere(
    (path) => path.contains('tcg$cardNumber.jpg'),
  );
  return index != -1 ? _cardArtPaths[index] : _cardArtPaths.first;
}

const List<MentalCard> _toolCardPool = <MentalCard>[
  MentalCard(
    id: 'tool_16',
    name: 'Checar las Pruebas',
    type: MentalCardType.cognitivo,
    energyCost: 2,
    power: 3,
  ),
  MentalCard(
    id: 'tool_17',
    name: 'Pensamiento Alterno',
    type: MentalCardType.cognitivo,
    energyCost: 3,
    power: 4,
  ),
  MentalCard(
    id: 'tool_18',
    name: 'Ponerle Nombre al Pensamiento',
    type: MentalCardType.cognitivo,
    energyCost: 1,
    power: 2,
  ),
  MentalCard(
    id: 'tool_19',
    name: 'Diario Rápido de Ideas',
    type: MentalCardType.cognitivo,
    energyCost: 2,
    power: 3,
  ),
  MentalCard(
    id: 'tool_20',
    name: 'Frase Ancla',
    type: MentalCardType.cognitivo,
    energyCost: 2,
    power: 3,
  ),
  MentalCard(
    id: 'tool_21',
    name: 'Nombrar la Emoción',
    type: MentalCardType.emocional,
    energyCost: 2,
    power: 3,
  ),
  MentalCard(
    id: 'tool_22',
    name: 'Darse Chance de Sentir',
    type: MentalCardType.emocional,
    energyCost: 2,
    power: 3,
  ),
  MentalCard(
    id: 'tool_23',
    name: 'Respirar en 4 Tiempos',
    type: MentalCardType.emocional,
    energyCost: 1,
    power: 2,
  ),
  MentalCard(
    id: 'tool_24',
    name: 'Anclarse a los Sentidos',
    type: MentalCardType.emocional,
    energyCost: 2,
    power: 3,
  ),
  MentalCard(
    id: 'tool_25',
    name: 'Hablarlo con Alguien Seguro',
    type: MentalCardType.emocional,
    energyCost: 3,
    power: 4,
  ),
  MentalCard(
    id: 'tool_26',
    name: 'Un Paso Muy Pequeño',
    type: MentalCardType.conductual,
    energyCost: 1,
    power: 2,
  ),
  MentalCard(
    id: 'tool_27',
    name: 'Plan de Mini-Metas',
    type: MentalCardType.conductual,
    energyCost: 3,
    power: 4,
  ),
  MentalCard(
    id: 'tool_28',
    name: 'Actividad que Sí Disfruto',
    type: MentalCardType.conductual,
    energyCost: 2,
    power: 3,
  ),
  MentalCard(
    id: 'tool_29',
    name: 'Higiene de Sueño',
    type: MentalCardType.conductual,
    energyCost: 2,
    power: 3,
  ),
    MentalCard(
    id: 'tool_30',
    name: 'Pedir Ayuda Profesional',
    type: MentalCardType.conductual,
    energyCost: 3,
    power: 4,
  ),
];

const List<MentalCard> _comodinesCardPool = <MentalCard>[
  MentalCard(
    id: 'comodin_31',
    name: 'Pausa de Respiración',
    type: MentalCardType.comodin,
    energyCost: 2,
    power: 0,
  ),
  MentalCard(
    id: 'comodin_32',
    name: 'Red de Apoyo Activa',
    type: MentalCardType.comodin,
    energyCost: 3,
    power: 0,
  ),
  MentalCard(
    id: 'comodin_33',
    name: 'Enfoque con Intención',
    type: MentalCardType.comodin,
    energyCost: 2,
    power: 0,
  ),
  MentalCard(
    id: 'comodin_34',
    name: 'Romper el Bucle',
    type: MentalCardType.comodin,
    energyCost: 2,
    power: 0,
  ),
  MentalCard(
    id: 'comodin_35',
    name: 'Tablero Organizado',
    type: MentalCardType.comodin,
    energyCost: 3,
    power: 0,
  ),
];

const List<MentalCard> _bossSoporteCardPool = <MentalCard>[
  MentalCard(
    id: 'bsoporte_36',
    name: 'Sobrecarga Tóxica',
    type: MentalCardType.bossSoporte,
    energyCost: 3,
    power: 6,
  ),
  MentalCard(
    id: 'bsoporte_37',
    name: 'Culpa y Vergüenza',
    type: MentalCardType.bossSoporte,
    energyCost: 2,
    power: 0,
  ),
  MentalCard(
    id: 'bsoporte_38',
    name: 'Gaslighting',
    type: MentalCardType.bossSoporte,
    energyCost: 2,
    power: 0,
  ),
  MentalCard(
    id: 'bsoporte_39',
    name: 'Manipulación Mental',
    type: MentalCardType.bossSoporte,
    energyCost: 3,
    power: 0,
  ),
  MentalCard(
    id: 'bsoporte_40',
    name: 'Drenaje Emocional',
    type: MentalCardType.bossSoporte,
    energyCost: 2,
    power: 2,
  ),
];

const List<MentalCard> _bossCardPool = <MentalCard>[
  MentalCard(
    id: 'boss_00',
    name: 'Ansiedad Pico',
    type: MentalCardType.emocional,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_01',
    name: 'Filtro Negativo',
    type: MentalCardType.cognitivo,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_02',
    name: 'Procrastinar',
    type: MentalCardType.conductual,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_03',
    name: 'Aislamiento',
    type: MentalCardType.conductual,
    energyCost: 0,
    power: 2,
  ),
  MentalCard(
    id: 'boss_04',
    name: 'Catastrofismo',
    type: MentalCardType.cognitivo,
    energyCost: 0,
    power: 4,
  ),
  MentalCard(
    id: 'boss_05',
    name: 'Verguenza',
    type: MentalCardType.emocional,
    energyCost: 0,
    power: 4,
  ),
  MentalCard(
    id: 'boss_06',
    name: 'Todo o Nada',
    type: MentalCardType.cognitivo,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_07',
    name: 'Evitacion',
    type: MentalCardType.conductual,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_08',
    name: 'Culpa Excesiva',
    type: MentalCardType.emocional,
    energyCost: 0,
    power: 2,
  ),
  MentalCard(
    id: 'boss_09',
    name: 'Rumia Mental',
    type: MentalCardType.cognitivo,
    energyCost: 0,
    power: 4,
  ),
  MentalCard(
    id: 'boss_10',
    name: 'Ira Impulsiva',
    type: MentalCardType.emocional,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_11',
    name: 'Desorden Rutina',
    type: MentalCardType.conductual,
    energyCost: 0,
    power: 2,
  ),
  MentalCard(
    id: 'boss_12',
    name: 'Autocritica',
    type: MentalCardType.cognitivo,
    energyCost: 0,
    power: 4,
  ),
  MentalCard(
    id: 'boss_13',
    name: 'Miedo Social',
    type: MentalCardType.emocional,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_14',
    name: 'Bloqueo Activo',
    type: MentalCardType.conductual,
    energyCost: 0,
    power: 4,
  ),
];
