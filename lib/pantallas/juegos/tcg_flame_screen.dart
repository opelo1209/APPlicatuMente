import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'tcg_flame_game.dart';

import 'package:just_audio/just_audio.dart';

enum _GameMenuAction { toggleSound, continueGame, exitGame }

class TcgFlameScreen extends StatefulWidget {
  const TcgFlameScreen({super.key});
  @override
  State<TcgFlameScreen> createState() => _TcgFlameScreenState();
}

class _TcgFlameScreenState extends State<TcgFlameScreen> {
  late final MentalTcgGame _game;
  bool _soundEnabled = true;
  late final AudioPlayer player;

  @override
  void initState() {
    super.initState();
    _game = MentalTcgGame();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    player = AudioPlayer();
    await player.setAsset( 'assets/musica/tcg/The_Keeper_s_Ledger.mp3');
    player.setLoopMode(LoopMode.all);
    player.play();
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
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    _soundEnabled ? 'Quitar sonido' : 'Activar sonido',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_GameMenuAction.toggleSound),
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
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_GameMenuAction.continueGame),
                ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                  title: const Text(
                    'Salir de la partida',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => {
                    player.stop(),
                    Navigator.of(context).pop(_GameMenuAction.exitGame)},
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (action == null || action == _GameMenuAction.continueGame) {
      _game.resumeEngine();
      return;
    }

    if (action == _GameMenuAction.toggleSound) {
      setState(() {
        _soundEnabled = !_soundEnabled;
        if (_soundEnabled) {
          player.play();
        } else {
          player.pause();
        }
      });
      _game.resumeEngine();
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 104, 112, 109),
      body: SafeArea(
        child: Column(
          children: [
            // 1. COMPONENTE 1: La Barra de Estado de Juego
            Container(
              padding: const EdgeInsets.symmetric(horizontal:18, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF280705), // Un rojo oscuro profundo con estilo madera
                border: const Border(
                  bottom: BorderSide(color: Color(0xFF4A1010), width: 2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 83, 11, 7).withValues(alpha: 1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // MENU
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _openGameMenu,
                          tooltip: 'Menú',
                          icon: const Icon(Icons.menu_rounded),
                          color: Colors.white,
                          iconSize: 18,
                        ),
                      ),
                      
                      // BARRA CENTRAL DE ESTADO (PUNTOS Y ELIXIR)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ValueListenableBuilder<int>(
                            valueListenable: _game.playerHpNotifier,
                            builder: (context, playerHp, _) {
                              return ValueListenableBuilder<int>(
                                valueListenable: _game.bossHpNotifier,
                                builder: (context, bossHp, _) {
                                  return ValueListenableBuilder<int>(
                                    valueListenable: _game.manaNotifier,
                                    builder: (context, mana, _) {
                                      return ValueListenableBuilder<int>(
                                        valueListenable: _game.manaCapNotifier,
                                        builder: (context, manaCap, _) {
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Tú: $playerHp',
                                                    style: const TextStyle(color: Color.fromARGB(255, 121, 185, 231), fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                  Text(
                                                    'Elixir: $mana/$manaCap',
                                                    style: const TextStyle(color: Color.fromARGB(255, 232, 235, 235), fontWeight: FontWeight.bold, fontSize: 17),
                                                  ),
                                                  Text(
                                                    'Boss: $bossHp',
                                                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              // BARRA DE ELIXIR CON 10 DIVISIONES
                                              Row(
                                                children: List.generate(_game.maxManaPerTurn, (index) {
                                                  final isUnlocked = index < manaCap;
                                                  final isAvailable = index < mana;
                                                  return Expanded(
                                                    child: Container(
                                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                                      height: 10,
                                                      decoration: BoxDecoration(
                                                        color: isAvailable
                                                            ? const Color.fromARGB(255, 101, 216, 136)
                                                            : (isUnlocked
                                                                  ? const Color.fromARGB(255, 46, 104, 67)
                                                                  : Colors.black38),
                                                        borderRadius: BorderRadius.circular(2),
                                                      ),
                                                    ),
                                                  );
                                                }),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),

                      // REINICIAR
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () {
                            _game.resetMatch();
                          },
                          tooltip: 'Reiniciar',
                          icon: const Icon(Icons.refresh_rounded),
                          color: Colors.white,
                          iconSize: 21,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 2. COMPONENTE 2: El Tablero del Juego (Flame)
            Expanded(
              child: Stack(
                children: [
                  GameWidget<MentalTcgGame>(
                    game: _game,
                    overlayBuilderMap: {
                      'preview': (context, game) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: game.previewArtPath,
                          builder: (context, imagePath, child) {
                            if (imagePath == null) return const SizedBox.shrink();
                            return GestureDetector(
                              onTap: game.hideCardPreview,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.72),
                                child: Center(
                                  child: Container(
                                    width: MediaQuery.of(context).size.width * 0.82,
                                    constraints: const BoxConstraints(maxWidth: 360),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black54,
                                          blurRadius: 20,
                                          offset: Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.asset(
                                        imagePath,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    },
                    initialActiveOverlays: const ['preview'],
                  ),
                  
                  // MENSAJES / INDICACIONES FLOTANTES (MODAL CENTRADO/ARRIBA)
                  Positioned(
                    top: 100,
                    left: 24,
                    right: 24,
                    child: IgnorePointer(
                      child: ValueListenableBuilder<String>(
                        valueListenable: _game.hintTextNotifier,
                        builder: (context, hint, _) {
                          if (hint.isEmpty) return const SizedBox.shrink();
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24, width: 1.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                )
                              ]
                            ),
                            child: Text(
                              hint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 16, 
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // BOTON RENDONDO PARA FINALIZAR TURNO (INFERIOR DERECHO)
                  Positioned(
                    bottom: 24,
                    right: 20,
                    child: Semantics(
                      label: 'Jugar cartas',
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            )
                          ]
                        ),
                        child: FloatingActionButton(
                          mini: true,
                          heroTag: 'btn_pass_turn',
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.black87,
                          elevation: 10,
                          onPressed: () {
                            if (!_game.isFinished) {
                              _game.passTurn();
                            }
                          },
                          child: const Icon(Icons.double_arrow_rounded, size: 28),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}