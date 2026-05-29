import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'tcg_flame_game.dart';
import 'models/game_state.dart';
import 'tutorial/tutor_service.dart';
import 'tutorial/tutor_overlay.dart';
import 'tutorial/tutor_definitions.dart';
import 'tutorial/tutor_step.dart';

enum _GameMenuAction { toggleSound, continueGame, retutorial, exitGame }

class TcgFlameScreen extends StatefulWidget {
  const TcgFlameScreen({super.key});

  @override
  State<TcgFlameScreen> createState() => _TcgFlameScreenState();
}

class _TcgFlameScreenState extends State<TcgFlameScreen>
    with WidgetsBindingObserver {
  late final TcgGame _game;
  late final TutorService _tutorService;
  bool _soundEnabled = true;
  AudioPlayer? _player;
  bool _started = false;
  bool _disposed = false;
  Size _gameAreaSize = Size.zero;
  bool _tutorReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = TcgGame();
    _tutorService = TutorService();
    _tutorService.addListener(_onTutorChanged);
    _initTutor();
    _initAudio();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final p = _player;
    if (p == null) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_disposed && _soundEnabled && p.playing) {
        p.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_disposed && _soundEnabled && !p.playing) {
        p.play();
      }
    }
  }

  Future<void> _initTutor() async {
    await _tutorService.load();
    if (!mounted) return;
    setState(() => _tutorReady = true);
  }

  void _onTutorChanged() {
    if (!mounted) return;
    setState(() {});
    final step = _tutorService.currentStep;
    if (step == null) return;
    if (step.autoAdvance) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted &&
            _tutorService.active &&
            _tutorService.currentStep?.id == step.id) {
          _tutorService.nextStep();
        }
      });
    }
    if (step.requiredAction == TutorAction.dropCard) {
      _game.state.addListener(_onGameStateChanged);
    } else {
      _game.state.removeListener(_onGameStateChanged);
    }
  }

  void _initAudio() {
    final p = AudioPlayer();
    _player = p;
    p.setAsset('assets/musica/tcg/The_Keeper_s_Ledger.mp3').then((_) {
      if (_disposed) return;
      p.setLoopMode(LoopMode.all);
      if (_soundEnabled) p.play();
    }).catchError((_) {});
  }

  void _toggleSound() {
    _soundEnabled = !_soundEnabled;
    final p = _player;
    if (p == null) return;
    if (_soundEnabled) {
      p.play();
    } else {
      p.pause();
    }
  }

  Future<void> _openGameMenu() async {
    _game.pauseEngine();

    final action = await showModalBottomSheet<_GameMenuAction>(
      context: context,
      backgroundColor: const Color(0xFF17221E).withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(
                    _soundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    _soundEnabled ? 'Quitar sonido' : 'Activar sonido',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(_GameMenuAction.toggleSound),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Continuar partida',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(_GameMenuAction.continueGame),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.replay_rounded,
                    color: Color(0xFF66BB6A),
                  ),
                  title: const Text(
                    'Volver a ver tutorial',
                    style: TextStyle(
                      color: Color(0xFF66BB6A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.of(context)
                      .pop(_GameMenuAction.retutorial),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.exit_to_app,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Salir de la partida',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(_GameMenuAction.exitGame),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (action == null || action == _GameMenuAction.continueGame) {
      _game.resumeEngine();
      return;
    }

    if (action == _GameMenuAction.toggleSound) {
      setState(() => _toggleSound());
      _game.resumeEngine();
      return;
    }

    if (action == _GameMenuAction.retutorial) {
      _startTutorial();
      _game.resumeEngine();
      return;
    }

    _player?.stop();
    Navigator.of(context).pop();
  }

  void _startMatch() {
    setState(() => _started = true);
    _game.startGame();
    if (_tutorReady && !_tutorService.completed) {
      _startTutorial();
    }
  }

  void _startTutorial() {
    final steps = createTutorialSteps();
    if (_tutorService.completed) {
      _tutorService.restart(steps);
    } else {
      _tutorService.start(steps);
    }
  }

  void _onTutorNext() {
    final step = _tutorService.currentStep;
    if (step != null && step.requiredAction == TutorAction.tap) {
      _tutorService.nextStep();
    }
  }

  void _onTutorSkip() {
    _tutorService.skip();
  }

  void _onGameStateChanged() {
    if (!_tutorService.active) {
      _game.state.removeListener(_onGameStateChanged);
      return;
    }
    final step = _tutorService.currentStep;
    if (step == null) return;
    if (step.id == 'play_card' && _game.state.playerSlotCard != null) {
      _game.state.removeListener(_onGameStateChanged);
      _tutorService.nextStep();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _tutorService.removeListener(_onTutorChanged);
    _game.state.removeListener(_onGameStateChanged);
    _player?.stop();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF79B979),
      body: SafeArea(
        child: Column(
          children: [
            if (_started) _buildTopBar(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (_gameAreaSize != constraints.biggest) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() =>
                            _gameAreaSize = constraints.biggest);
                      }
                    });
                  }
                  return Stack(
                    children: [
                      GameWidget(
                        key: const ValueKey('game_widget'),
                        game: _game,
                      ),
                      if (!_started) _buildStartScreen(),
                      if (_started) _buildHudOverlay(),
                      if (_started && _tutorService.active)
                        TutorOverlay(
                          service: _tutorService,
                          gameAreaSize: _gameAreaSize,
                          onSkip: _onTutorSkip,
                          onNext: _onTutorNext,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/imagenes/quetzal_4.png',
            height: 160,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 24),
          Text(
            'TCG Salud Mental',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.green[900],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Coloca cartas y combate pensamientos negativos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.green[800],
            ),
          ),
          const SizedBox(height: 40),
          _buildGreenButton('Comenzar partida', _startMatch),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4E7852),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border.all(color: const Color(0xFF3B5E40), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF28402C).withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _openGameMenu,
                behavior: HitTestBehavior.opaque,
                child: Semantics(
                  label: 'Menú',
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.menu_rounded,
                          size: 26,
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        const Icon(
                          Icons.menu_rounded,
                          size: 24,
                          color: Color(0xFFF3E5AB),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStatusBars(),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _game.startGame();
                },
                behavior: HitTestBehavior.opaque,
                child: Semantics(
                  label: 'Reiniciar',
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 26,
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        const Icon(
                          Icons.refresh_rounded,
                          size: 24,
                          color: Color(0xFFF3E5AB),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBars() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: _game.playerHpNotifier,
          builder: (context, playerHp, _) {
            return ValueListenableBuilder<int>(
              valueListenable: _game.enemyHpNotifier,
              builder: (context, enemyHp, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: _game.turnNotifier,
                  builder: (context, turn, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFFA8D5BA),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            _buildSegmentedHp(
                                playerHp, const Color(0xFFA8D5BA)),
                          ],
                        ),
                        Text(
                          'Turno $turn',
                          style: const TextStyle(
                            color: Color(0xFFCFD8DC),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          children: [
                            _buildSegmentedHp(
                                enemyHp, const Color(0xFFD87D2F)),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.local_fire_department_rounded,
                              color: Color(0xFFD87D2F),
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder<int>(
          valueListenable: _game.energyNotifier,
          builder: (context, energy, _) {
            return ValueListenableBuilder<int>(
              valueListenable: _game.energyCapNotifier,
              builder: (context, energyCap, _) {
                return _buildEnergyBar(energy, energyCap);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSegmentedHp(int hp, Color activeColor) {
    final blocks = 10;
    final blocksActive = (hp / GameState.maxHp * blocks).ceil();
    return Row(
      children: List.generate(blocks, (index) {
        final isActive = index < blocksActive;
        return Container(
          width: 4,
          height: 10,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor
                : const Color(0xFF28402C).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(5),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.4),
                      blurRadius: 2,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildEnergyBar(int energy, int energyCap) {
    const totalSegments = 10;
    return Container(
      height: 14,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: List.generate(totalSegments, (index) {
          final isUnlocked = index < energyCap;
          final isAvailable = index < energy;
          const activeColor = Color(0xFF66BB6A);
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: isAvailable
                    ? activeColor
                    : (isUnlocked ? Colors.black26 : Colors.black12),
                border: Border.all(
                  color: isAvailable
                      ? activeColor.withValues(alpha: 0.5)
                      : Colors.black12,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHudOverlay() {
    return Stack(
      children: [
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: _game.isProcessing,
            builder: (context, processing, _) {
              final phase = _game.state.phase;
              String label;
              if (_game.state.isGameOver) {
                label = '';
              } else if (_tutorService.active) {
                label = '';
              } else if (processing) {
                label = 'Resolviendo...';
              } else if (phase == GamePhase.playerTurn) {
                label = 'Tu turno — Arrastra una carta';
              } else {
                label = 'Turno enemigo...';
              }
              if (label.isEmpty) return const SizedBox.shrink();
              return Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _buildCombatLog(),
        if (_game.state.isGameOver) _buildGameOverOverlay(),
      ],
    );
  }

  Widget _buildCombatLog() {
    return ValueListenableBuilder<String>(
      valueListenable: _game.combatLog,
      builder: (context, log, _) {
        if (log.isEmpty) return const SizedBox.shrink();
        return Positioned(
          bottom: 160,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: Text(
              log,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameOverOverlay() {
    final won = _game.state.playerWon;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                won
                    ? 'assets/imagenes/quetzal_3.png'
                    : 'assets/imagenes/quetzal_4.png',
                height: 140,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Text(
                won ? '¡Victoria!' : 'Derrota',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: won ? Colors.green[300] : Colors.red[300],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                won
                    ? 'Has vencido los pensamientos negativos'
                    : 'Los pensamientos negativos han ganado...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 32),
              _buildGreenButton('Jugar de nuevo', () {
                _game.startGame();
              }),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _player?.stop();
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Salir',
                  style: TextStyle(color: Colors.grey[500], fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreenButton(String text, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        minimumSize: const Size(220, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 6,
        shadowColor: const Color(0xFF2E7D32).withValues(alpha: 0.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
