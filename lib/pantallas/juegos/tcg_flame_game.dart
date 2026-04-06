import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

enum MentalCardType { cognitivo, emocional, conductual }

extension MentalCardTypeX on MentalCardType {
  String get label {
    switch (this) {
      case MentalCardType.cognitivo:
        return 'Cognitivo';
      case MentalCardType.emocional:
        return 'Emocional';
      case MentalCardType.conductual:
        return 'Conductual';
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
    }
  }
}

const String _boardAssetPath = 'assets/imagenes/tcg/tcg-tablero.jpg';
const List<String> _cardArtPaths = <String>[
  'assets/imagenes/tcg/tcg1.jpeg',
  'assets/imagenes/tcg/tcg2.jpeg',
  'assets/imagenes/tcg/tcg3.jpeg',
  'assets/imagenes/tcg/tcg4.jpeg',
  'assets/imagenes/tcg/tcg5.jpeg',
  'assets/imagenes/tcg/tcg6.jpeg',
  'assets/imagenes/tcg/tcg7.jpeg',
  'assets/imagenes/tcg/tcg8.jpeg',
  'assets/imagenes/tcg/tcg9.jpeg',
  'assets/imagenes/tcg/tcg10.jpeg',
  'assets/imagenes/tcg/tcg11.jpeg',
  'assets/imagenes/tcg/tcg12.jpeg',
  'assets/imagenes/tcg/tcg13.jpeg',
  'assets/imagenes/tcg/tcg14.jpeg',
];

const double _fieldCardWidth = 124;
const double _fieldCardHeight = 176;
const double _handCardWidth = 86;
const double _handCardHeight = 124;

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
  late final TextComponent _statsText;

  final List<DraggableCardComponent> _handCards = <DraggableCardComponent>[];
  final List<MentalCard> _drawPile = <MentalCard>[];
  final ValueNotifier<String?> previewArtPath = ValueNotifier<String?>(null);

  CardFaceComponent? _bossCardView;
  CardFaceComponent? _playerFieldCardView;
  MentalCard? _bossCard;

  int playerHp = 20;
  int bossHp = 20;
  int turn = 1;
  int manaCap = 1;
  int mana = 1;
  bool _isFinished = false;

  bool get isFinished => _isFinished;

  @override
  Future<void> onLoad() async {
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

    _statsText = TextComponent(
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(color: Colors.black87, blurRadius: 6),
          ],
        ),
      ),
      priority: 40,
    );
    add(_statsText);

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

    _bossCardView?.removeFromParent();
    _bossCardView = null;

    _playerFieldCardView?.removeFromParent();
    _playerFieldCardView = null;

    playerHp = 20;
    bossHp = 20;
    turn = 1;
    manaCap = 1;
    mana = 1;
    _isFinished = false;

    _refillDrawPile();
    _drawUntilHandSize(4);
    _spawnBossCard();

    _setHint(
      'Arrastra una carta al campo. Cognitivo > Emocional > Conductual > Cognitivo.',
    );
    _layoutBoard();
  }

  void _drawUntilHandSize(int targetSize) {
    while (_handCards.length < targetSize) {
      final card = _takeToolCard();
      final cardView = DraggableCardComponent(
        card: card,
        onDropped: _handleDrop,
        cardSize: Vector2(_handCardWidth, _handCardHeight),
      );
      _handCards.add(cardView);
      add(cardView);
    }
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
      ..shuffle(_random);
  }

  void _spawnBossCard() {
    _bossCard = _bossCardPool[_random.nextInt(_bossCardPool.length)];
    _bossCardView?.removeFromParent();
    _bossCardView = CardFaceComponent(
      card: _bossCard!,
      cardSize: Vector2(_fieldCardWidth, _fieldCardHeight),
    );
    add(_bossCardView!);
    _animateEnemyDeploy(_bossCardView!);
  }

  void _handleDrop(DraggableCardComponent cardView) {
    if (_isFinished) {
      cardView.returnToHome();
      return;
    }

    final droppedInZone = cardView.toRect().overlaps(_dropZone.toRect());
    if (!droppedInZone) {
      cardView.returnToHome();
      return;
    }

    final card = cardView.card;
    if (mana < card.energyCost) {
      _setHint(
        'No hay energia suficiente para ${card.name}. Costo ${card.energyCost}.',
      );
      cardView.returnToHome();
      return;
    }

    _handCards.remove(cardView);
    cardView.removeFromParent();

    mana -= card.energyCost;
    _placeOnField(card);

    final bossCard = _bossCard!;
    final playerMultiplier = _multiplier(card.type, bossCard.type);
    final playerDamage = _scaledDamage(card.power, playerMultiplier);
    bossHp = max(0, bossHp - playerDamage);

    var turnLog =
        '${card.name} pega $playerDamage a ${bossCard.name} (${_multiplierLabel(playerMultiplier)}).';

    if (bossHp <= 0) {
      _isFinished = true;
      _setHint('Ganaste el round. El Boss quedo sin bienestar.');
      _layoutBoard();
      return;
    }

    final bossMultiplier = _multiplier(bossCard.type, card.type);
    final bossDamage = _scaledDamage(bossCard.power, bossMultiplier);
    playerHp = max(0, playerHp - bossDamage);

    turnLog +=
        ' ${bossCard.name} responde con $bossDamage (${_multiplierLabel(bossMultiplier)}).';

    if (playerHp <= 0) {
      _isFinished = true;
      _setHint('Perdiste este round. Reinicia para intentar de nuevo.');
      _layoutBoard();
      return;
    }

    _advanceTurn();
    _setHint(turnLog);
    _layoutBoard();
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
    manaCap = min(10, manaCap + 1);
    mana = manaCap;
    _drawUntilHandSize(4);
    _spawnBossCard();
  }

  void _placeOnField(MentalCard card) {
    _playerFieldCardView?.removeFromParent();
    _playerFieldCardView = CardFaceComponent(
      card: card,
      cardSize: Vector2(_fieldCardWidth, _fieldCardHeight),
    );
    add(_playerFieldCardView!);
    _animatePlayerDeploy(_playerFieldCardView!);
  }

  void _animateEnemyDeploy(CardFaceComponent cardView) {
    cardView.scale = Vector2.all(0.9);
    cardView.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.05),
          EffectController(duration: 0.16, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2.all(1),
          EffectController(duration: 0.14, curve: Curves.easeInOut),
        ),
      ]),
    );
  }

  void _animatePlayerDeploy(CardFaceComponent cardView) {
    cardView.scale = Vector2.all(0.86);
    cardView.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.09),
          EffectController(duration: 0.18, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2.all(1),
          EffectController(duration: 0.16, curve: Curves.easeInOut),
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

  void _setHint(String _) {}

  void _layoutBoard() {
    _background
      ..position = Vector2.zero()
      ..size = size;

    _backgroundTint
      ..position = Vector2.zero()
      ..size = size;

    const dropPadding = 9.0;
    final centerX = (size.x - _fieldCardWidth) / 2;
    final bossY = size.y * 0.24;
    final playerY = size.y * 0.465;
    _dropZone
      ..position = Vector2(centerX - dropPadding, playerY - dropPadding)
      ..size = Vector2(
        _fieldCardWidth + (dropPadding * 2),
        _fieldCardHeight + (dropPadding * 2),
      )
      ..refreshLayout();

    _statsText.position = Vector2(12, 42);

    _bossCardView?.position = Vector2(centerX, bossY);
    _playerFieldCardView?.position = Vector2(centerX, playerY);

    _layoutHand();
  }

  void _layoutHand() {
    if (_handCards.isEmpty) {
      return;
    }

    const cardWidth = _handCardWidth;
    const cardHeight = _handCardHeight;
    const gap = 8.0;
    final totalWidth = (_handCards.length * cardWidth) +
        ((_handCards.length - 1) * gap);
    final startX = (size.x - totalWidth) / 2;
    final y = size.y - cardHeight - 12;

    for (var i = 0; i < _handCards.length; i++) {
      final home = Vector2(startX + (i * (cardWidth + gap)), y);
      _handCards[i].setHomePosition(home, moveNow: !_handCards[i].isDragging);
    }
  }
}

class DropZoneComponent extends PositionComponent {
  late final RectangleComponent _glow;
  late final RectangleComponent _border;
  var _ready = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _glow = RectangleComponent(
      paint: Paint()..color = const Color(0x224FC3F7),
    );
    add(_glow);

    _border = RectangleComponent(
      paint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white70,
    );
    add(_border);
    _ready = true;
    refreshLayout();
  }

  void refreshLayout() {
    if (!_ready) {
      return;
    }
    _glow.size = size;
    _border.size = size;
  }
}

class CardFaceComponent extends PositionComponent
    with HasGameReference<MentalTcgGame>, TapCallbacks {
  CardFaceComponent({
    required this.card,
    required Vector2 cardSize,
  }) : super(size: cardSize);

  final MentalCard card;
  static const double _previewHoldDelay = 0.22;

  bool _isPressing = false;
  double _pressElapsed = 0;
  bool _previewVisible = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(
      RectangleComponent(
        position: Vector2(3, 4),
        size: size,
        paint: Paint()..color = const Color(0x33000000),
      ),
    );

    final imagePath = _artPathForCard(card);
    Sprite sprite;
    try {
      sprite = Sprite(game.images.fromCache(imagePath));
    } catch (_) {
      sprite = await Sprite.load(imagePath);
    }

    add(
      SpriteComponent(
        sprite: sprite,
        size: size,
      ),
    );

    add(
      RectangleComponent(
        size: size,
        paint: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = card.type.color.withValues(alpha: 0.9),
      ),
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
    required super.cardSize,
  });

  final void Function(DraggableCardComponent card) onDropped;
  Vector2 _homePosition = Vector2.zero();
  bool _isDragging = false;

  bool get isDragging => _isDragging;

  void setHomePosition(Vector2 nextHome, {bool moveNow = true}) {
    _homePosition = nextHome.clone();
    if (moveNow) {
      position.setFrom(nextHome);
    }
  }

  void returnToHome() {
    position.setFrom(_homePosition);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    cancelPreviewFromExternalGesture();
    _isDragging = true;
    scale = Vector2.all(1.03);
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
    scale = Vector2.all(1);
    priority = 20;
    onDropped(this);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _isDragging = false;
    scale = Vector2.all(1);
    priority = 20;
    returnToHome();
  }
}

String _artPathForCard(MentalCard card) {
  final cardNumber = int.tryParse(card.id.split('_').last) ?? 1;
  final bossOffset = card.id.startsWith('boss_') ? 6 : 0;
  final index = (cardNumber - 1 + bossOffset) % _cardArtPaths.length;
  return _cardArtPaths[index];
}

const List<MentalCard> _toolCardPool = <MentalCard>[
  MentalCard(
    id: 'tool_01',
    name: 'Checar Pruebas',
    type: MentalCardType.cognitivo,
    energyCost: 1,
    power: 3,
  ),
  MentalCard(
    id: 'tool_02',
    name: 'Reenfocar Idea',
    type: MentalCardType.cognitivo,
    energyCost: 2,
    power: 4,
  ),
  MentalCard(
    id: 'tool_03',
    name: 'Detectar Trampa',
    type: MentalCardType.cognitivo,
    energyCost: 2,
    power: 3,
  ),
  MentalCard(
    id: 'tool_04',
    name: 'Reencuadre Amable',
    type: MentalCardType.cognitivo,
    energyCost: 3,
    power: 5,
  ),
  MentalCard(
    id: 'tool_05',
    name: 'Diario Pensado',
    type: MentalCardType.cognitivo,
    energyCost: 1,
    power: 2,
  ),
  MentalCard(
    id: 'tool_06',
    name: 'Nombrar Emocion',
    type: MentalCardType.emocional,
    energyCost: 1,
    power: 3,
  ),
  MentalCard(
    id: 'tool_07',
    name: 'Respirar 4x4',
    type: MentalCardType.emocional,
    energyCost: 2,
    power: 4,
  ),
  MentalCard(
    id: 'tool_08',
    name: 'Pausa de Calma',
    type: MentalCardType.emocional,
    energyCost: 2,
    power: 3,
  ),
  MentalCard(
    id: 'tool_09',
    name: 'Validar Sentir',
    type: MentalCardType.emocional,
    energyCost: 3,
    power: 5,
  ),
  MentalCard(
    id: 'tool_10',
    name: 'Autohabla Apoyo',
    type: MentalCardType.emocional,
    energyCost: 1,
    power: 2,
  ),
  MentalCard(
    id: 'tool_11',
    name: 'Mini Metas',
    type: MentalCardType.conductual,
    energyCost: 1,
    power: 3,
  ),
  MentalCard(
    id: 'tool_12',
    name: 'Activacion',
    type: MentalCardType.conductual,
    energyCost: 2,
    power: 4,
  ),
  MentalCard(
    id: 'tool_13',
    name: 'Paso 2 Min',
    type: MentalCardType.conductual,
    energyCost: 1,
    power: 2,
  ),
  MentalCard(
    id: 'tool_14',
    name: 'Romper Aislar',
    type: MentalCardType.conductual,
    energyCost: 3,
    power: 5,
  ),
  MentalCard(
    id: 'tool_15',
    name: 'Rutina Sueno',
    type: MentalCardType.conductual,
    energyCost: 2,
    power: 4,
  ),
];

const List<MentalCard> _bossCardPool = <MentalCard>[
  MentalCard(
    id: 'boss_01',
    name: 'Ansiedad Pico',
    type: MentalCardType.emocional,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_02',
    name: 'Filtro Negativo',
    type: MentalCardType.cognitivo,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_03',
    name: 'Procrastinar',
    type: MentalCardType.conductual,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_04',
    name: 'Aislamiento',
    type: MentalCardType.conductual,
    energyCost: 0,
    power: 2,
  ),
  MentalCard(
    id: 'boss_05',
    name: 'Catastrofismo',
    type: MentalCardType.cognitivo,
    energyCost: 0,
    power: 4,
  ),
  MentalCard(
    id: 'boss_06',
    name: 'Verguenza',
    type: MentalCardType.emocional,
    energyCost: 0,
    power: 4,
  ),
  MentalCard(
    id: 'boss_07',
    name: 'Todo o Nada',
    type: MentalCardType.cognitivo,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_08',
    name: 'Evitacion',
    type: MentalCardType.conductual,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_09',
    name: 'Culpa Excesiva',
    type: MentalCardType.emocional,
    energyCost: 0,
    power: 2,
  ),
  MentalCard(
    id: 'boss_10',
    name: 'Rumia Mental',
    type: MentalCardType.cognitivo,
    energyCost: 0,
    power: 4,
  ),
  MentalCard(
    id: 'boss_11',
    name: 'Ira Impulsiva',
    type: MentalCardType.emocional,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_12',
    name: 'Desorden Rutina',
    type: MentalCardType.conductual,
    energyCost: 0,
    power: 2,
  ),
  MentalCard(
    id: 'boss_13',
    name: 'Autocritica',
    type: MentalCardType.cognitivo,
    energyCost: 0,
    power: 4,
  ),
  MentalCard(
    id: 'boss_14',
    name: 'Miedo Social',
    type: MentalCardType.emocional,
    energyCost: 0,
    power: 3,
  ),
  MentalCard(
    id: 'boss_15',
    name: 'Bloqueo Activo',
    type: MentalCardType.conductual,
    energyCost: 0,
    power: 4,
  ),
];